extends Node2D
## Ten connected floors share one world and one player.

const RecoilPlayer = preload("res://player.gd")
const FLOOR_HEIGHT := 1376.0
const WIDTH := 2496.0
const BOUNDS := Rect2(0, -14080, WIDTH, 14800)
const LOOK_AHEAD := 120.0
const LOOK_SPEED := 3.0
const CAMERA_LIFT := 100.0
const FLOORS: Array[PackedScene] = [
	preload("res://levels/tower_floor_01.tscn"),
	preload("res://levels/tower_floor_02.tscn"),
	preload("res://levels/tower_floor_03.tscn"),
	preload("res://levels/tower_floor_04.tscn"),
	preload("res://levels/tower_floor_05.tscn"),
	preload("res://levels/tower_floor_06.tscn"),
	preload("res://levels/tower_floor_07.tscn"),
	preload("res://levels/tower_floor_08.tscn"),
	preload("res://levels/tower_floor_09.tscn"),
	preload("res://levels/tower_floor_10.tscn"),
]
const TITLES: Array[String] = ["Wake Up, You’re a Gun", "The Chain Lift", "Loose Shells", "Quiet Please", "Rotten Shelves", "Gargoyle Gallery", "The Stacks", "The Windward Stair", "The Bell Walk", "Morwen’s Crown"]
const HINTS: Array[String] = ["Hold left-click to charge. Release to recoil away from the mouse.", "Land on the striped lift to start its trip.", "Gold wisps refill your shells in midair.", "Blue walls bounce you back. Save a shell for the redirect.", "Brown shelves reload you, then crumble. Charge as soon as you land.", "Wait for the flash, then cross the firing lane.", "Use the moving shelf to line up the climb past the gargoyles.", "Move quickly across rotten shelves and use the gold wisps to recover.", "Watch the lift and the firing lanes before committing to the next jump.", "Climb to the summit. Aim at Morwen’s heart orb to break the curse."]
const ZONES := ["Cellar", "Library", "Tower"]
const TAUNTS := {0: "Still kicking? Cute.", 3: "Shhh. This is a library.", 7: "You're not supposed to be up here."}
const ZONE_COLORS := [Color("#d5c7b6"), Color("#bec0cf"), Color("#afbcca")]
const FLOOR_ENTRANCES := [360.0, 1600.0, 500.0, 1920.0, 550.0, 1890.0, 470.0, 2250.0, 290.0, 2270.0]

@onready var player: RecoilPlayer = $Player
@onready var camera: Camera2D = $Camera2D
@onready var level_root: Node2D = $Level
@onready var title_label: Label = $HUD/Title
@onready var instructions: Label = $HUD/Instructions
@onready var stats: Label = $HUD/Stats

var sections: Array[Node2D] = []
var checkpoints: Array[Checkpoint] = []
var refills: Array[ShellRefill] = []
var look := Vector2.ZERO
var floor_index := -1
var cleared := false
var elapsed := 0.0
var deaths := 0


func _ready() -> void:
	player.bounds = BOUNDS
	camera.limit_left = int(BOUNDS.position.x)
	camera.limit_right = int(BOUNDS.end.x)
	camera.limit_top = int(BOUNDS.position.y)
	camera.limit_bottom = int(BOUNDS.end.y)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 6.0
	$HUD/Keys.visible = OS.is_debug_build()
	for index in range(FLOORS.size()):
		var section := FLOORS[index].instantiate() as Node2D
		section.position.y = 560.0 - FLOOR_HEIGHT * index
		level_root.add_child(section)
		sections.append(section)
		for child in section.get_children():
			if child is Checkpoint:
				checkpoints.append(child)
			elif child is ShellRefill:
				refills.append(child)
			elif child is HexOrb:
				child.broken.connect(_on_orb_broken.bind(index))
	for x in [0.0, WIDTH - 24.0]:
		var wall := Block.new()
		wall.size = Vector2(24.0, BOUNDS.size.y)
		wall.position = Vector2(x + 12.0, BOUNDS.get_center().y)
		level_root.add_child(wall)
	var roof := Block.new()
	roof.size = Vector2(WIDTH, 24.0)
	roof.position = Vector2(WIDTH / 2.0, BOUNDS.position.y + 12.0)
	level_root.add_child(roof)
	player.died.connect(_on_player_died)
	player.shot_fired.connect(_on_shot)
	player.respawn_position = Vector2(360, 546)
	player.respawn("tower start")
	camera.position = player.position - Vector2(0.0, CAMERA_LIFT)
	camera.reset_smoothing()


func _draw() -> void:
	for index in range(FLOORS.size()):
		var zone := _zone(index)
		var bottom := 560.0 - FLOOR_HEIGHT * index
		var top := bottom - FLOOR_HEIGHT
		if index == FLOORS.size() - 1:
			top = BOUNDS.position.y
		if index == 0:
			bottom = BOUNDS.end.y
		draw_rect(Rect2(0.0, top, WIDTH, bottom - top), ZONE_COLORS[zone].lightened(0.05 if index % 2 == 0 else 0.0))
		var ink: Color = ZONE_COLORS[zone].darkened(0.12)
		for x in range(100, int(WIDTH), 224):
			match zone:
				0:
					for y in range(int(top) + 80, int(bottom), 144):
						draw_line(Vector2(x, y), Vector2(x + 144, y), ink, 2.0)
				1:
					draw_rect(Rect2(x, top + 96, 116, bottom - top - 192), ink, false, 4.0)
					for y in range(int(top) + 220, int(bottom) - 96, 164):
						draw_line(Vector2(x, y), Vector2(x + 116, y), ink, 3.0)
				2:
					for y in range(int(top) + 160, int(bottom) - 100, 360):
						draw_arc(Vector2(x + 50, y), 50, PI, TAU, 24, ink, 3.0, true)
						draw_rect(Rect2(x, y, 100, 172), ink, false, 3.0)


func _process(delta: float) -> void:
	if not player.is_air_charging():
		look = look.lerp((player.velocity * 0.2).limit_length(LOOK_AHEAD), minf(1.0, LOOK_SPEED * delta))
	camera.position = player.position + look - Vector2(0.0, CAMERA_LIFT)
	if camera.get_screen_center_position().distance_to(camera.position) > 900.0:
		camera.reset_smoothing()

	var current := clampi(floori((560.0 - player.position.y) / FLOOR_HEIGHT), 0, FLOORS.size() - 1)
	if current != floor_index:
		floor_index = current
		title_label.text = "%s  •  %02d/10  %s" % [ZONES[_zone(current)], current + 1, TITLES[current]]
		instructions.text = HINTS[current]
		if TAUNTS.has(current):
			instructions.text += "\nMorwen: “%s”" % TAUNTS[current]
	if not cleared:
		elapsed += delta
	if player.is_on_floor():
		var feet := player.global_position + Vector2(0.0, 13.0)
		for checkpoint in checkpoints:
			if checkpoint.world_rect().has_point(feet) and not checkpoint.reached:
				var spawn := Vector2(checkpoint.position.x, checkpoint.world_rect().position.y - 14.0)
				if spawn.y < player.respawn_position.y:
					checkpoint.reached = true
					player.respawn_position = spawn
					player.debug_event.emit("Brazier lit at %s" % spawn.round())
				break

	stats.text = "Time %.1fs   Deaths %d" % [elapsed, deaths]
	if cleared:
		instructions.text = "The curse breaks. Barrett is himself again. Morwen is a broom."
		stats.text = "TOWER CLEAR   " + stats.text


func _zone(index: int) -> int:
	return 0 if index < 3 else (1 if index < 7 else 2)


func _on_shot(blast_direction: Vector2) -> void:
	for index in range(sections.size()):
		var orb := sections[index].get_node("Orb") as HexOrb
		if orb.try_hit(player.global_position, blast_direction):
			return


func _on_orb_broken(index: int) -> void:
	player.debug_event.emit("Hex orb broken on floor %d" % (index + 1))
	if index == sections.size() - 1:
		cleared = true
	else:
		var hatch := sections[index].get_node("Hatch") as Block
		hatch.open_as_one_way()
		instructions.text = "The hatch opened. Shoot upward to keep climbing."


func _on_player_died() -> void:
	deaths += 1
	look = Vector2.ZERO
	camera.position = player.position - Vector2(0.0, CAMERA_LIFT)
	camera.reset_smoothing()
	for refill in refills:
		refill.reset()


func _unhandled_input(event: InputEvent) -> void:
	if not OS.is_debug_build() or not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode == KEY_R:
		player.die("restart key")
		return
	var index: int = 9 if event.keycode == KEY_0 else event.keycode - KEY_1
	if index >= 0 and index < sections.size():
		var start := Vector2(FLOOR_ENTRANCES[index], 546.0 - FLOOR_HEIGHT * index)
		if index > 0:
			var hatch := sections[index - 1].get_node("Hatch") as Block
			hatch.open_as_one_way()
		player.respawn_position = start
		player.respawn("debug floor %d" % (index + 1))
		look = Vector2.ZERO
		camera.position = player.position - Vector2(0.0, CAMERA_LIFT)
		camera.reset_smoothing()

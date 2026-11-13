extends Node2D
## Loads one level at a time. Number keys switch levels for testing.

const RecoilPlayer = preload("res://player.gd")
const LEVELS: Array[String] = [
	"res://levels/level_01_wake_up.tscn",
	"res://levels/level_1_basics.tscn",
	"res://levels/level_2_bounce.tscn",
	"res://levels/level_3_moving.tscn",
	"res://levels/level_4_turrets.tscn",
	"res://levels/level_5_mouths.tscn",
	"res://levels/level_6_flood.tscn",
	"res://levels/level_7_refills.tscn",
]

@onready var player: RecoilPlayer = $Player
@onready var camera: Camera2D = $Camera2D
@onready var title_label: Label = $HUD/Title
@onready var instructions: Label = $HUD/Instructions
@onready var stats: Label = $HUD/Stats
@onready var level_root: Node2D = $Level

## Camera: how far ahead it leads in the flight direction, and how fast the lead catches up.
const LOOK_AHEAD := 120.0
const LOOK_SPEED := 3.0
## The player sits this far below the screen centre, since the goal is usually above.
const CAMERA_LIFT := 100.0

var level: Level
var level_index := 0
var checkpoints: Array[Checkpoint] = []
var floods: Array[RisingHazard] = []
var refills: Array[ShellRefill] = []
var deaths := 0
var elapsed := 0.0
var cleared := false
var look := Vector2.ZERO


func _ready() -> void:
	player.died.connect(_on_player_died)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 6.0
	load_level(0)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	# Keys 1-9 load levels 1-9, key 0 loads level 10.
	var number: int = 9 if event.keycode == KEY_0 else event.keycode - KEY_1
	if number >= 0 and number < LEVELS.size():
		load_level(number)
	elif event.keycode == KEY_R:
		player.die("restart key")
	elif event.keycode == KEY_N:
		skip_to_next_checkpoint()


func load_level(index: int) -> void:
	if level != null:
		level_root.remove_child(level)
		level.queue_free()
	level_index = index
	level = load(LEVELS[index]).instantiate()
	level_root.add_child(level)

	checkpoints.clear()
	floods.clear()
	refills.clear()
	_collect(level)
	# Lowest first, so "next checkpoint" means the next one up.
	checkpoints.sort_custom(func(a: Checkpoint, b: Checkpoint) -> bool:
		return a.global_position.y > b.global_position.y)

	deaths = 0
	elapsed = 0.0
	cleared = false
	player.bounds = level.bounds
	_setup_camera()
	player.respawn_position = (level.get_node("Start") as Node2D).global_position
	player.respawn("level %d loaded" % (index + 1))
	title_label.text = "%d/%d  %s" % [index + 1, LEVELS.size(), level.title]
	instructions.text = level.hint
	look = Vector2.ZERO
	_update_camera(0.0)
	camera.reset_smoothing()


func _collect(node: Node) -> void:
	for child in node.get_children():
		if child is Checkpoint:
			checkpoints.append(child)
		elif child is RisingHazard:
			floods.append(child)
		elif child is ShellRefill:
			refills.append(child)
		_collect(child)


func _process(delta: float) -> void:
	_update_camera(delta)
	if not cleared:
		elapsed += delta

	if player.is_on_floor():
		var feet := player.global_position + Vector2(0, 13)
		for checkpoint in checkpoints:
			if checkpoint.world_rect().has_point(feet):
				_reach(checkpoint)
				break

	var saved := checkpoints.filter(func(c: Checkpoint) -> bool: return c.reached and not c.is_finish).size()
	var total := checkpoints.filter(func(c: Checkpoint) -> bool: return not c.is_finish).size()
	var status := "Time %s   Deaths %d   Checkpoints %d/%d" % [_format_time(elapsed), deaths, saved, total]
	if cleared:
		var next := "Press %d for the next level." % (level_index + 2) if level_index + 1 < LEVELS.size() else "That was the last level."
		status = "CLEAR!  " + status + "\n" + next
	stats.text = status


func _reach(checkpoint: Checkpoint) -> void:
	if checkpoint.is_finish:
		if not cleared:
			cleared = true
			checkpoint.reached = true
			player.debug_event.emit("Level clear at %s  time %s  deaths %d" % [
				player.position.round(), _format_time(elapsed), deaths])
			for flood in floods:
				flood.stop()
		return
	if checkpoint.reached:
		return
	var top := checkpoint.world_rect().position.y
	# Only move the respawn point upward.
	if top - 14.0 >= player.respawn_position.y:
		return
	checkpoint.reached = true
	player.respawn_position = Vector2(checkpoint.global_position.x, top - 14.0)
	player.debug_event.emit("Checkpoint at %s" % player.position.round())
	for flood in floods:
		flood.give_breathing_room(player.global_position.y)


func _setup_camera() -> void:
	var area := level.bounds
	camera.limit_left = int(area.position.x)
	camera.limit_top = int(area.position.y)
	camera.limit_right = int(area.end.x)
	camera.limit_bottom = int(area.end.y)


## Follows the player on both axes, leading a little in the flight direction.
func _update_camera(delta: float) -> void:
	# Hold the lead still while aiming in slow motion, so the view doesn't swing.
	if not player.is_air_charging():
		var target := (player.velocity * 0.2).limit_length(LOOK_AHEAD)
		look = look.lerp(target, minf(1.0, LOOK_SPEED * delta))
	var goal := player.position + look - Vector2(0, CAMERA_LIFT)
	camera.position = goal
	# Respawns and checkpoint skips teleport the player: cut instead of panning.
	if camera.get_screen_center_position().distance_to(goal) > 900.0:
		camera.reset_smoothing()


## Testing shortcut: jump to the next checkpoint up.
func skip_to_next_checkpoint() -> void:
	for checkpoint in checkpoints:
		if not checkpoint.reached and not checkpoint.is_finish:
			var top := checkpoint.world_rect().position.y
			checkpoint.reached = true
			player.respawn_position = Vector2(checkpoint.global_position.x, top - 14.0)
			player.respawn("skipped to checkpoint")
			for flood in floods:
				flood.reset()
			return


func _on_player_died() -> void:
	deaths += 1
	for flood in floods:
		flood.reset()
	for refill in refills:
		refill.reset()


func _format_time(seconds: float) -> String:
	return "%d:%04.1f" % [int(seconds) / 60, fmod(seconds, 60.0)]

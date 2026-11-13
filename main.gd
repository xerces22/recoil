extends Node2D
## Loads one level at a time. Number keys switch levels for testing.

const RecoilPlayer = preload("res://player.gd")
const LEVELS: Array[String] = [
	"res://levels/level_1_basics.tscn",
	"res://levels/level_2_bounce.tscn",
	"res://levels/level_3_moving.tscn",
	"res://levels/level_4_turrets.tscn",
	"res://levels/level_5_mouths.tscn",
	"res://levels/level_6_flood.tscn",
]

@onready var player: RecoilPlayer = $Player
@onready var camera: Camera2D = $Camera2D
@onready var title_label: Label = $HUD/Title
@onready var instructions: Label = $HUD/Instructions
@onready var stats: Label = $HUD/Stats
@onready var level_root: Node2D = $Level

var level: Level
var level_index := 0
var checkpoints: Array[Checkpoint] = []
var floods: Array[RisingHazard] = []
var deaths := 0
var elapsed := 0.0
var cleared := false


func _ready() -> void:
	player.died.connect(_on_player_died)
	load_level(0)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var number: int = event.keycode - KEY_1
	if number >= 0 and number < LEVELS.size():
		load_level(number)
	elif event.keycode == KEY_R:
		player.die()
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
	_collect(level)
	# Lowest first, so "next checkpoint" means the next one up.
	checkpoints.sort_custom(func(a: Checkpoint, b: Checkpoint) -> bool:
		return a.global_position.y > b.global_position.y)

	deaths = 0
	elapsed = 0.0
	cleared = false
	player.respawn_position = (level.get_node("Start") as Node2D).global_position
	player.respawn()
	title_label.text = "%d/%d  %s" % [index + 1, LEVELS.size(), level.title]
	instructions.text = level.hint


func _collect(node: Node) -> void:
	for child in node.get_children():
		if child is Checkpoint:
			checkpoints.append(child)
		elif child is RisingHazard:
			floods.append(child)
		_collect(child)


func _process(delta: float) -> void:
	camera.position.y = minf(360.0, player.position.y - 120.0)
	camera.force_update_scroll()
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
	for flood in floods:
		flood.give_breathing_room(player.global_position.y)


## Testing shortcut: jump to the next checkpoint up.
func skip_to_next_checkpoint() -> void:
	for checkpoint in checkpoints:
		if not checkpoint.reached and not checkpoint.is_finish:
			var top := checkpoint.world_rect().position.y
			checkpoint.reached = true
			player.respawn_position = Vector2(checkpoint.global_position.x, top - 14.0)
			player.respawn()
			for flood in floods:
				flood.reset()
			return


func _on_player_died() -> void:
	deaths += 1
	for flood in floods:
		flood.reset()


func _format_time(seconds: float) -> String:
	return "%d:%04.1f" % [int(seconds) / 60, fmod(seconds, 60.0)]

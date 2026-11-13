@tool
class_name Mouth
extends Node2D
## Jaws that snap shut across a gap on a fixed beat.
## By default the jaws close left-right and you fly up or down through it; rotate for other angles.
## Getting caught eats all your shells (until you land) and spits you back the way you came.

const CLOSE_TIME := 0.08
const OPEN_TIME := 0.2
const LIP := 6.0

## x = width of the opening, y = depth of the bite zone.
@export var gap := Vector2(150, 36):
	set(value):
		gap = value
		queue_redraw()
@export var open_time := 1.6
## Shaking warning before it snaps.
@export var warn_time := 0.5
@export var shut_time := 0.6
@export_range(0.0, 1.0) var phase := 0.0
@export var spit_speed := 380.0

var _time := 0.0
var _cooldown := 0.0


func _ready() -> void:
	_time = phase * _cycle()


func _cycle() -> float:
	return open_time + warn_time + CLOSE_TIME + shut_time + OPEN_TIME


## 0 = fully open, 1 = fully shut.
func closure() -> float:
	var t := _time - open_time - warn_time
	if t < 0.0:
		return 0.0
	if t < CLOSE_TIME:
		return t / CLOSE_TIME
	t -= CLOSE_TIME
	if t < shut_time:
		return 1.0
	return clampf(1.0 - (t - shut_time) / OPEN_TIME, 0.0, 1.0)


func is_warning() -> bool:
	return _time >= open_time and _time < open_time + warn_time


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_time = fmod(_time + delta, _cycle())
	_cooldown -= delta
	if closure() >= 0.6 and _cooldown <= 0.0:
		var player := get_tree().get_first_node_in_group("player") as CharacterBody2D
		if player != null:
			var local := to_local(player.global_position)
			if absf(local.x) <= gap.x / 2.0 + 10.0 and absf(local.y) <= gap.y / 2.0 + 12.0:
				_bite(player, local)
	queue_redraw()


func _bite(player: CharacterBody2D, local: Vector2) -> void:
	var local_velocity := player.velocity.rotated(-global_rotation)
	var side := -signf(local_velocity.y) if absf(local_velocity.y) > 1.0 else signf(local.y)
	if side == 0.0:
		side = 1.0
	player.lose_shells()
	player.velocity = Vector2(0, side * spit_speed).rotated(global_rotation)
	_cooldown = 0.4


func _draw() -> void:
	var half := gap / 2.0
	var shut := closure()
	var shake := randf_range(-2.0, 2.0) if is_warning() else 0.0
	var reach := LIP + (half.x - LIP) * shut
	var jaw := Color(0.45, 0.15, 0.55)
	var teeth := Color.RED if is_warning() else Color.WHITE

	if Engine.is_editor_hint():
		draw_rect(Rect2(-half, gap), Color(0.45, 0.15, 0.55, 0.2))

	for side in [-1.0, 1.0]:
		var outer: float = side * half.x
		var inner: float = outer - side * reach
		var left := minf(outer, inner)
		draw_rect(Rect2(left + shake, -half.y, absf(outer - inner), gap.y), jaw)
		var count := 3
		for index in range(count):
			var y0 := -half.y + gap.y * index / count
			var y1 := y0 + gap.y / count
			draw_colored_polygon(PackedVector2Array([
				Vector2(inner + shake, y0),
				Vector2(inner - side * 9.0 + shake, (y0 + y1) / 2.0),
				Vector2(inner + shake, y1),
			]), teeth)

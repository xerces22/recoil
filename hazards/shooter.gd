@tool
class_name Shooter
extends Node2D
## Wall turret. Fires along its rotation (0 = right), or at the player when `aimed`.
## Bolts knock the player off course; they don't kill.

const WARN_TIME := 0.35
const BARREL := 22.0
const Bullet = preload("res://hazards/bullet.gd")

@export var interval := 1.8
@export_range(0.0, 1.0) var phase := 0.0
@export var bullet_speed := 260.0
@export var burst := 1
@export var burst_gap := 0.15
@export var knockback := 420.0
@export var aimed := false:
	set(value):
		aimed = value
		queue_redraw()
## Aimed turrets only track and fire while the player is this close.
@export var reach := 650.0

var _clock := 0.0
var _burst_left := 0
var _burst_clock := 0.0
var _aim := Vector2.RIGHT


func _ready() -> void:
	_clock = phase * interval
	_aim = Vector2.RIGHT.rotated(global_rotation)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var tracking := true
	if aimed:
		var player := get_tree().get_first_node_in_group("player") as Node2D
		tracking = player != null and global_position.distance_to(player.global_position) <= reach
		if tracking:
			_aim = global_position.direction_to(player.global_position)
	if tracking:
		_clock += delta
	if _clock >= interval:
		_clock -= interval
		_burst_left = burst
		_burst_clock = 0.0
	if _burst_left > 0:
		_burst_clock -= delta
		if _burst_clock <= 0.0:
			_fire()
			_burst_left -= 1
			_burst_clock = burst_gap
	queue_redraw()


func _fire() -> void:
	var bullet := Bullet.new()
	bullet.direction = _aim
	bullet.speed = bullet_speed
	bullet.knockback = knockback
	get_parent().add_child(bullet)
	bullet.global_position = global_position + _aim * BARREL


func _draw() -> void:
	var warning := not Engine.is_editor_hint() and interval - _clock <= WARN_TIME
	var local_aim := Vector2.RIGHT if Engine.is_editor_hint() else _aim.rotated(-global_rotation)
	# Stone cannon housing with an iron barrel that glows red before it fires.
	var barrel := Color(1.0, 0.25, 0.1) if warning else Color(0.22, 0.2, 0.26)
	draw_line(Vector2.ZERO, local_aim * BARREL, Color(0.08, 0.05, 0.1), 11.0)
	draw_line(Vector2.ZERO, local_aim * BARREL, barrel, 7.0)
	Art.stone(self, Rect2(-14, -14, 28, 28))
	draw_circle(Vector2.ZERO, 6.0, Color(0.08, 0.05, 0.1))
	draw_circle(Vector2.ZERO, 4.0, Color(1, 0.85, 0.2) if aimed else Color(0.85, 0.2, 0.1))
	if Engine.is_editor_hint() and aimed:
		draw_arc(Vector2.ZERO, reach, 0, TAU, 64, Color(1, 0, 0, 0.15), 2.0)

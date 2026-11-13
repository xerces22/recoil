@tool
class_name MovingPlatform
extends AnimatableBody2D
## Platform that eases back and forth between its start and start + `travel`.
## With `wait_for_player`, it stays still until you land, makes one round trip, then waits again.

@export var size := Vector2(150, 16):
	set(value):
		size = value
		_update_shape()
@export var travel := Vector2(300, 0):
	set(value):
		travel = value
		queue_redraw()
## Seconds for a full round trip.
@export var period := 4.0
## Where in the cycle it starts (0 to 1). Offset neighbours so they move out of step.
@export_range(0.0, 1.0) var phase := 0.0
@export var wait_for_player := false

var _origin := Vector2.ZERO
var _time := 0.0
var _running := true
var _collision: CollisionShape2D


func _ready() -> void:
	_update_shape()
	_origin = position
	_running = not wait_for_player
	_time = 0.0 if wait_for_player else phase * period


func _update_shape() -> void:
	if _collision == null:
		_collision = CollisionShape2D.new()
		_collision.shape = RectangleShape2D.new()
		add_child(_collision, false, Node.INTERNAL_MODE_FRONT)
	(_collision.shape as RectangleShape2D).size = size
	queue_redraw()


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or not _running:
		return
	_time += delta
	if wait_for_player and _time >= period:
		_time = 0.0
		_running = false
	position = _origin + travel * (0.5 - 0.5 * cos(TAU * _time / period))
	queue_redraw()


func on_player_landed(_player: Node) -> void:
	if wait_for_player and not _running:
		_running = true


func _draw() -> void:
	var start := Vector2.ZERO if Engine.is_editor_hint() else _origin - position
	draw_dashed_line(start, start + travel, Color(1, 1, 1, 0.18), 2.0, 8.0)
	Art.plank(self, Art.PLANK_GREY, Rect2(-size / 2.0, size))
	if wait_for_player:
		draw_rect(Rect2(-size.x / 2.0 + 4, -3, size.x - 8, 6),
			Color(1, 0.8, 0.2) if not _running else Color(0.2, 0.9, 0.3))

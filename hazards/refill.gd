@tool
class_name ShellRefill
extends Node2D
## Floating shell pickup. Flying through it reloads shells mid-air without landing.
## It only gets used up if you were missing a shell, then comes back after `respawn_time`.
## Give it `travel` to make it drift, like a moving platform.

const RADIUS := 14.0
const PLAYER_RADIUS := 12.0

## Shells given. 1 = half refill, 2 = full.
@export_range(1, 2) var amount := 2:
	set(value):
		amount = value
		queue_redraw()
## Seconds until it comes back. 0 = only comes back when you die.
@export var respawn_time := 3.0
@export var travel := Vector2.ZERO:
	set(value):
		travel = value
		queue_redraw()
## Seconds for a full drift round trip.
@export var period := 3.0
@export_range(0.0, 1.0) var phase := 0.0

var available := true
var _origin := Vector2.ZERO
var _time := 0.0
var _cooldown := 0.0


func _ready() -> void:
	_origin = position
	_time = phase * period


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if travel != Vector2.ZERO:
		_time += delta
		position = _origin + travel * (0.5 - 0.5 * cos(TAU * _time / period))
	if not available:
		if respawn_time > 0.0:
			_cooldown -= delta
			if _cooldown <= 0.0:
				available = true
		queue_redraw()
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player != null and global_position.distance_to(player.global_position) <= RADIUS + PLAYER_RADIUS:
		if player.refill(amount):
			available = false
			_cooldown = respawn_time
	queue_redraw()


## Called when the player dies, so one-time refills come back.
func reset() -> void:
	available = true


func _draw() -> void:
	var start := Vector2.ZERO if Engine.is_editor_hint() else _origin - position
	if travel != Vector2.ZERO:
		draw_dashed_line(start, start + travel, Color(1, 1, 1, 0.18), 2.0, 8.0)
	var gold := Color(0.95, 0.7, 0.1)
	if not available:
		draw_arc(Vector2.ZERO, RADIUS, 0, TAU, 24, Color(gold, 0.35), 1.5)
		if respawn_time > 0.0:
			var left := clampf(_cooldown / respawn_time, 0.0, 1.0)
			draw_arc(Vector2.ZERO, RADIUS - 4, -PI / 2, -PI / 2 + TAU * (1.0 - left), 24, Color(gold, 0.5), 2.0)
		return
	draw_circle(Vector2.ZERO, RADIUS, Color(gold, 0.25))
	draw_arc(Vector2.ZERO, RADIUS, 0, TAU, 24, gold, 2.5)
	for index in range(amount):
		var x := -4.0 + index * 8.0 if amount == 2 else 0.0
		draw_rect(Rect2(x - 2.5, -6, 5, 9), Color(0.75, 0.1, 0.1))
		draw_rect(Rect2(x - 2.5, 3, 5, 3), Color(0.8, 0.65, 0.2))

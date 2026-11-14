@tool
class_name CrumblePlatform
extends Block
## Reloads like normal ground, then falls apart shortly after you land.

@export var delay := 0.5
@export var regrow := 2.5

enum State { SOLID, SHAKING, GONE }
var _state := State.SOLID
var _timer := 0.0


func on_player_landed(_player: Node) -> void:
	if _state == State.SOLID:
		_state = State.SHAKING
		_timer = delay


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or _state == State.SOLID:
		return
	_timer -= delta
	if _timer > 0.0:
		queue_redraw()
		return
	if _state == State.SHAKING:
		_state = State.GONE
		_timer = regrow
		_collision.set_deferred("disabled", true)
	else:
		_state = State.SOLID
		_collision.set_deferred("disabled", false)
	queue_redraw()


func fill_color() -> Color:
	var brown := Color(0.45, 0.28, 0.12)
	if _state == State.GONE:
		brown.a = 0.15
	return brown


func _draw() -> void:
	var shake := Vector2(randf_range(-2, 2), 0) if _state == State.SHAKING else Vector2.ZERO
	var rect := Rect2(-size / 2.0 + shake, size)
	draw_rect(rect, fill_color())
	if _state != State.GONE:
		var crack := Color(0, 0, 0, 0.5)
		for x in range(1, 4):
			var px := rect.position.x + rect.size.x * x / 4.0
			draw_line(Vector2(px, rect.position.y), Vector2(px + 5, rect.end.y), crack, 1.5)

@tool
class_name Bouncy
extends Block
## Blue surface. Reflects the player and never reloads shots.
## Rotate the node for angled bumpers.

## 1.0 keeps all speed, above 1.0 adds speed.
@export var strength := 1.0
## Every bounce leaves at least this fast, so you can never rest on it.
@export var min_speed := 420.0

var _pulse := 0.0


func pulse() -> void:
	_pulse = 1.0
	set_process(true)


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		set_process(false)
		return
	_pulse = maxf(0.0, _pulse - delta * 5.0)
	queue_redraw()
	if _pulse == 0.0:
		set_process(false)


func fill_color() -> Color:
	return Color(0.15, 0.45, 0.95).lerp(Color.WHITE, _pulse * 0.7)


func _draw() -> void:
	super()
	var half := size / 2.0
	var stripe := Color(1, 1, 1, 0.45)
	if size.x >= size.y:
		draw_line(Vector2(-half.x + 4, -half.y + 3), Vector2(half.x - 4, -half.y + 3), stripe, 2.0)
	else:
		draw_line(Vector2(-half.x + 3, -half.y + 4), Vector2(-half.x + 3, half.y - 4), stripe, 2.0)

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


func plank_texture() -> Texture2D:
	return Art.PLANK_BLUE


func show_brackets() -> bool:
	return false


func _draw() -> void:
	var glow := Color(0.75, 0.95, 1.6).lerp(Color(2.2, 2.2, 2.2), _pulse * 0.6)
	draw_body(Rect2(-size / 2.0, size), glow)

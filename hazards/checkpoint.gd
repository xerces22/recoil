@tool
class_name Checkpoint
extends Block
## Platform that saves your respawn point when you land on it.
## Tick `is_finish` for the level goal.

@export var is_finish := false:
	set(value):
		is_finish = value
		queue_redraw()

var reached := false:
	set(value):
		reached = value
		queue_redraw()


func fill_color() -> Color:
	if reached:
		return Color(0.1, 0.55, 0.25)
	return Color.BLACK


func _draw() -> void:
	super()
	var label := "FINISH" if is_finish else ("CHECKPOINT SET" if reached else "CHECKPOINT")
	draw_string(ThemeDB.fallback_font, -size / 2.0 + Vector2(12, -10),
		label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.BLACK)

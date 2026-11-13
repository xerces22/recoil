@tool
class_name Checkpoint
extends Block
## Platform that saves your respawn point when you land on it.
## Tick `is_finish` for the level goal.

## Bonfire frames per second once lit.
const FIRE_FPS := 10.0
## Bottom rows of the bonfire sprite: the unlit log pile and stone ring.
const UNLIT_ROWS := 22.0

@export var is_finish := false:
	set(value):
		is_finish = value
		queue_redraw()

var reached := false:
	set(value):
		reached = value
		set_process(reached and not Engine.is_editor_hint())
		queue_redraw()

var _time := 0.0


func _ready() -> void:
	super()
	set_process(false)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func plank_texture() -> Texture2D:
	return Art.PLANK_GREY


func bracket_texture() -> Texture2D:
	return Art.SHELF_GREY


func _draw() -> void:
	var top := -size.y / 2.0
	if is_finish:
		# Exit gate standing on the platform.
		Art.stand(self, Art.GATE, Vector2(0, top), Art.PX,
			Color(1.3, 1.2, 0.8) if reached else Color.WHITE)
	super()
	if is_finish:
		return
	var fire := Art.BONFIRE[0]
	var w := float(fire.get_width())
	var h := float(fire.get_height())
	if reached:
		var frame := Art.BONFIRE[int(_time * FIRE_FPS) % Art.BONFIRE.size()]
		draw_texture(frame, Vector2(-w / 2.0, top - h))
	else:
		draw_texture_rect_region(fire, Rect2(-w / 2.0, top - UNLIT_ROWS, w, UNLIT_ROWS),
			Rect2(0, h - UNLIT_ROWS, w, UNLIT_ROWS), Color(0.75, 0.7, 0.8))

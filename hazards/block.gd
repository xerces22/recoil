@tool
class_name Block
extends StaticBody2D
## Solid rectangle centred on the node. Change `size` in the Inspector.

@export var size := Vector2(160, 16):
	set(value):
		size = value
		_update_shape()

var _collision: CollisionShape2D


func _ready() -> void:
	_update_shape()


func _update_shape() -> void:
	if _collision == null:
		_collision = CollisionShape2D.new()
		_collision.shape = RectangleShape2D.new()
		add_child(_collision, false, Node.INTERNAL_MODE_FRONT)
	(_collision.shape as RectangleShape2D).size = size
	queue_redraw()


func _draw() -> void:
	draw_body(Rect2(-size / 2.0, size))


## Castle art for the block: stone for thick walls and wide floors,
## a wooden shelf with wall brackets for normal ledges.
func draw_body(rect: Rect2, modulate := Color.WHITE) -> void:
	if _plain_level():
		# Training room: flat box, light top edge, so the tutorial reads as a tutorial.
		draw_rect(rect, Color("3a3346") * modulate)
		draw_rect(Rect2(rect.position, Vector2(rect.size.x, minf(4.0, rect.size.y))), Color("8d82a3") * modulate)
		draw_rect(rect, Color("0d0a12"), false, 2.0)
		return
	if minf(rect.size.x, rect.size.y) > 24.0 or rect.size.x >= 600.0:
		Art.stone(self, rect, modulate * stone_tint())
	elif rect.size.y > rect.size.x:
		# Thin upright beam: draw the plank turned 90 degrees.
		draw_set_transform(rect.position + Vector2(rect.size.x, 0), PI / 2.0)
		Art.plank(self, plank_texture(), Rect2(Vector2.ZERO, Vector2(rect.size.y, rect.size.x)), modulate)
		draw_set_transform(Vector2.ZERO)
	else:
		if show_brackets() and rect.size.x <= 320.0:
			var under := rect.position.y + rect.size.y - 2.0
			Art.bracket(self, bracket_texture(), Vector2(rect.position.x + 4.0, under), false, modulate)
			Art.bracket(self, bracket_texture(), Vector2(rect.end.x - 4.0, under), true, modulate)
		Art.plank(self, plank_texture(), rect, modulate)


func plank_texture() -> Texture2D:
	return Art.PLANK_WOOD


func bracket_texture() -> Texture2D:
	return Art.SHELF_WOOD


func show_brackets() -> bool:
	return true


func stone_tint() -> Color:
	return Color.WHITE


func fill_color() -> Color:
	return Color.BLACK


## World-space rectangle, ignoring rotation.
func world_rect() -> Rect2:
	return Rect2(global_position - size / 2.0, size)


func _plain_level() -> bool:
	var root := get_parent() as Level
	return root != null and root.plain

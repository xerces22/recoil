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
	draw_rect(Rect2(-size / 2.0, size), fill_color())


func fill_color() -> Color:
	return Color.BLACK


## World-space rectangle, ignoring rotation.
func world_rect() -> Rect2:
	return Rect2(global_position - size / 2.0, size)

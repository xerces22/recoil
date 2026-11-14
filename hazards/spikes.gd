@tool
class_name Spikes
extends Area2D
## Row of spikes pointing up from the node's origin to the right.
## Rotate the node to point them another way. Touching them kills.

const TOOTH := 20.0

@export var width := 60.0:
	set(value):
		width = value
		_rebuild()
@export var height := 26.0:
	set(value):
		height = value
		_rebuild()

var _shapes: Array[Node] = []


func _ready() -> void:
	_rebuild()
	if not Engine.is_editor_hint():
		body_entered.connect(_on_body_entered)


func _rebuild() -> void:
	for shape in _shapes:
		shape.queue_free()
	_shapes.clear()

	# Cover the top surface continuously, including the seams between triangles.
	var strip := RectangleShape2D.new()
	strip.size = Vector2(width, 4.0)
	var strip_collision := CollisionShape2D.new()
	strip_collision.position = Vector2(width / 2.0, -1.0)
	strip_collision.shape = strip
	_add_shape(strip_collision)

	for points in _teeth():
		var collision := CollisionPolygon2D.new()
		collision.polygon = points
		_add_shape(collision)
	queue_redraw()


func _add_shape(node: Node) -> void:
	add_child(node, false, Node.INTERNAL_MODE_FRONT)
	_shapes.append(node)


func _teeth() -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	var count := maxi(1, ceili(width / TOOTH))
	var tooth := width / count
	for index in range(count):
		var left := index * tooth
		result.append(PackedVector2Array([
			Vector2(left, 0), Vector2(left + tooth / 2.0, -height), Vector2(left + tooth, 0),
		]))
	return result


func _draw() -> void:
	for points in _teeth():
		draw_colored_polygon(points, Color.BLACK)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		body.die.call_deferred("spikes")

extends Node2D
## Editor-only geometry guides. Gameplay nodes still draw their own art.

var floor_node: Level
var selected: Node2D
var camera: Camera2D
var snap := false
const GRID := 16.0
const ACCENT := Color("#ffda8d")


func object_rect(node: Node2D) -> Rect2:
	if node is Block or node is MovingPlatform:
		var dimensions: Vector2 = node.get("size")
		return Rect2(-dimensions / 2.0, dimensions)
	if node is Spikes:
		return Rect2(Vector2(0, -node.height), Vector2(node.width, node.height + 3.0))
	if node is Mouth:
		return Rect2(-node.gap / 2.0, node.gap)
	if node is Shooter:
		return Rect2(-16, -16, 42, 32)
	if node is ShellRefill:
		return Rect2(-14, -14, 28, 28)
	if node is RisingHazard:
		return Rect2(floor_node.bounds.position.x, node.trigger_y - 4, floor_node.bounds.size.x, 8)
	return Rect2(-12, -12, 24, 24)


func resize_point(node: Node2D) -> Vector2:
	if node is Spikes:
		return Vector2(node.width, -node.height)
	return object_rect(node).end


func can_resize(node: Node2D) -> bool:
	return node is Block or node is MovingPlatform or node is Spikes or node is Mouth


func _draw() -> void:
	if not is_instance_valid(floor_node):
		return
	var zoom := camera.zoom.x
	var line := 1.5 / zoom
	if snap and zoom >= 0.5:
		var view_size := get_viewport_rect().size / zoom
		var top_left := camera.position - view_size / 2.0
		var bottom_right := top_left + view_size
		var ink := Color(0.8, 0.78, 0.92, 0.13)
		for x in range(floori(top_left.x / GRID), ceili(bottom_right.x / GRID)):
			draw_line(Vector2(x * GRID, top_left.y), Vector2(x * GRID, bottom_right.y), ink, line / 2.0)
		for y in range(floori(top_left.y / GRID), ceili(bottom_right.y / GRID)):
			draw_line(Vector2(top_left.x, y * GRID), Vector2(bottom_right.x, y * GRID), ink, line / 2.0)
	draw_rect(floor_node.bounds, Color(0.57, 0.74, 0.95, 0.55), false, line)
	for child in floor_node.get_children():
		if child is Marker2D:
			var point: Vector2 = child.global_position
			var radius := 7.0 / zoom
			draw_colored_polygon(PackedVector2Array([
				point - Vector2(0, radius), point + Vector2(radius, 0),
				point + Vector2(0, radius), point - Vector2(radius, 0),
			]), Color("#9ae6df"))
			draw_string(ThemeDB.fallback_font, point + Vector2(11, -7) / zoom,
				str(child.name), HORIZONTAL_ALIGNMENT_LEFT, -1, roundi(14.0 / zoom), Color("#b7f4ef"))
		elif child is RisingHazard:
			var band := object_rect(child)
			draw_dashed_line(Vector2(band.position.x, band.get_center().y),
				Vector2(band.end.x, band.get_center().y), Color("#ff929c"), line, 8.0 / zoom)
	if is_instance_valid(selected):
		draw_set_transform_matrix(selected.global_transform)
		draw_rect(object_rect(selected), ACCENT, false, line)
		if can_resize(selected):
			draw_circle(resize_point(selected), 5.5 / zoom, ACCENT)

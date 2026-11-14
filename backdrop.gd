extends Node2D
## Castle wall behind every level. Follows the camera on both axes at half speed for depth,
## with windows, banners and statues in a staggered grid, so levels of any width are covered.

const PARALLAX := 0.5
## Spacing of the decoration grid, in background-layer pixels.
const DECOR_STEP := Vector2(560, 420)
const DIM := Color(0.45, 0.4, 0.52)

const WALL := preload("res://assets/sprites/tilesets/bg_wall_purple_2.png")
const DECOR: Array[Texture2D] = [
	preload("res://assets/sprites/props/stained_glass_tall.png"),
	preload("res://assets/sprites/banners/banner_2.png"),
	preload("res://assets/sprites/props/window_arch_1.png"),
	preload("res://assets/sprites/banners/banner_10.png"),
	preload("res://assets/sprites/props/knight_statue_2.png"),
	preload("res://assets/sprites/banners/banner_5.png"),
	preload("res://assets/sprites/props/stained_glass_wide.png"),
	preload("res://assets/sprites/banners/banner_7.png"),
	preload("res://assets/sprites/props/window_arch_3.png"),
]

var target_tint := DIM
var show_decor := true:
	set(value):
		show_decor = value
		queue_redraw()
var _tint := DIM


func _ready() -> void:
	z_index = -50


func _process(delta: float) -> void:
	_tint = _tint.lerp(target_tint, 1.0 - exp(-4.0 * delta))
	queue_redraw()


func _draw() -> void:
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return
	var view := get_viewport_rect().size / camera.zoom
	var center := camera.get_screen_center_position()
	var shift := center * PARALLAX
	# Visible area in background-layer coordinates.
	var area := Rect2(center - view / 2.0 - shift, view)
	draw_set_transform(shift)

	var tile := WALL.get_size() * Art.PX
	var start := (area.position / tile).floor() * tile
	Art.fill(self, WALL, Rect2(Vector2.ZERO, WALL.get_size()),
		Rect2(start, area.end - start + tile), Art.PX, _tint)

	if not show_decor:
		draw_set_transform(Vector2.ZERO)
		return

	var first := (area.position / DECOR_STEP).floor() - Vector2.ONE
	var last := (area.end / DECOR_STEP).ceil() + Vector2.ONE
	for i in range(int(first.x), int(last.x) + 1):
		for k in range(int(first.y), int(last.y) + 1):
			var tex := DECOR[posmod(k * 7 + i * 4, DECOR.size())]
			# Odd columns sit half a step lower so the pattern doesn't line up in rows.
			var y := k * DECOR_STEP.y + (DECOR_STEP.y / 2.0 if posmod(i, 2) == 1 else 0.0)
			Art.stand(self, tex, Vector2(i * DECOR_STEP.x + 70.0, y), Art.PX, _tint)
	draw_set_transform(Vector2.ZERO)

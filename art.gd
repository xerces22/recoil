class_name Art
## Shared pixel-art textures and drawing helpers. Every sprite is drawn at PX screen pixels per art pixel.

const PX := 2.0

const PLANK_WOOD := preload("res://assets/sprites/platforms/plank_wood.png")
const PLANK_DARK := preload("res://assets/sprites/platforms/plank_dark.png")
const PLANK_GREY := preload("res://assets/sprites/platforms/plank_grey.png")
const PLANK_BLUE := preload("res://assets/sprites/platforms/plank_blue.png")
const SHELF_WOOD := preload("res://assets/sprites/platforms/shelf_bracket_wood.png")
const SHELF_GREY := preload("res://assets/sprites/platforms/shelf_bracket_grey.png")
const STONE := preload("res://assets/sprites/tilesets/grey_stone_tileset.png")
const SPIKES_UP := preload("res://assets/sprites/hazards/spikes_up.png")
const WALL := preload("res://assets/sprites/tilesets/bg_wall_purple_2.png")
const SHOTGUN := preload("res://assets/sprites/player/shotgun_main.png")
const STETSON := preload("res://assets/sprites/player/stetson.png")
const STETSON_OFFSET := Vector2(4, -13)
const LANTERN_DARK := preload("res://assets/sprites/checkpoints/lantern_green_1.png")
const LANTERN_LIT: Array[Texture2D] = [
	preload("res://assets/sprites/checkpoints/lantern_lit_1.png"),
	preload("res://assets/sprites/checkpoints/lantern_lit_2.png"),
	preload("res://assets/sprites/checkpoints/lantern_lit_3.png"),
]
const BONFIRE: Array[Texture2D] = [
	preload("res://assets/sprites/checkpoints/bonfire_1.png"),
	preload("res://assets/sprites/checkpoints/bonfire_2.png"),
	preload("res://assets/sprites/checkpoints/bonfire_3.png"),
	preload("res://assets/sprites/checkpoints/bonfire_4.png"),
	preload("res://assets/sprites/checkpoints/bonfire_5.png"),
	preload("res://assets/sprites/checkpoints/bonfire_6.png"),
]
const GATE := preload("res://assets/sprites/props/gate_large.png")
const GARGOYLE := preload("res://assets/sprites/props/gargoyle_1.png")

## Region of the plank textures: 8 px end caps around an 8 px repeating middle.
const PLANK_CAP := 8.0
## Region of the stone tileset that repeats cleanly as a brick fill.
const STONE_FILL := Rect2(16, 24, 32, 16)
## Bracket under the shelf board in shelf_bracket_*.png.
const BRACKET := Rect2(0, 24, 18, 19)


## Tiles `src` of `tex` across `dest`, `scale` screen px per art px, clipping the last row and column.
static func fill(ci: CanvasItem, tex: Texture2D, src: Rect2, dest: Rect2, scale := PX, modulate := Color.WHITE) -> void:
	var step := src.size * scale
	var y := 0.0
	while y < dest.size.y:
		var h := minf(step.y, dest.size.y - y)
		var x := 0.0
		while x < dest.size.x:
			var w := minf(step.x, dest.size.x - x)
			ci.draw_texture_rect_region(tex, Rect2(dest.position + Vector2(x, y), Vector2(w, h)),
				Rect2(src.position, Vector2(w, h) / scale), modulate)
			x += step.x
		y += step.y


## Draws a plank texture across `dest`: fixed end caps and a repeating middle. Height sets the scale.
static func plank(ci: CanvasItem, tex: Texture2D, dest: Rect2, modulate := Color.WHITE) -> void:
	var th := float(tex.get_height())
	var scale := maxf(1.0, floorf(dest.size.y / th))
	var h := th * scale
	var cap := minf(PLANK_CAP * scale, dest.size.x / 2.0)
	var src_cap := cap / scale
	var tw := float(tex.get_width())
	var pos := dest.position
	ci.draw_texture_rect_region(tex, Rect2(pos, Vector2(cap, h)), Rect2(0, 0, src_cap, th), modulate)
	fill(ci, tex, Rect2(PLANK_CAP, 0, PLANK_CAP, th),
		Rect2(pos + Vector2(cap, 0), Vector2(dest.size.x - cap * 2.0, h)), scale, modulate)
	ci.draw_texture_rect_region(tex, Rect2(pos + Vector2(dest.size.x - cap, 0), Vector2(cap, h)),
		Rect2(tw - src_cap, 0, src_cap, th), modulate)
	# Thicker blocks than the plank: fill the rest with dark wood so the hitbox stays covered.
	if dest.size.y > h:
		ci.draw_rect(Rect2(pos + Vector2(0, h), Vector2(dest.size.x, dest.size.y - h)), Color(0.16, 0.08, 0.14) * modulate)


## Wall bracket under a shelf end. `flip` mirrors it for the right end.
static func bracket(ci: CanvasItem, tex: Texture2D, top_corner: Vector2, flip := false, modulate := Color.WHITE) -> void:
	var size := BRACKET.size * PX
	var x := top_corner.x - size.x if flip else top_corner.x
	var rect := Rect2(Vector2(x, top_corner.y), size)
	if flip:
		rect = Rect2(rect.position + Vector2(size.x, 0), Vector2(-size.x, size.y))
	ci.draw_texture_rect_region(tex, rect, BRACKET, modulate)


## Solid stone block (walls, pillars, wide floors).
static func stone(ci: CanvasItem, dest: Rect2, modulate := Color.WHITE) -> void:
	fill(ci, STONE, STONE_FILL, dest, PX, modulate)
	ci.draw_rect(dest, Color(0.09, 0.05, 0.12), false, 2.0)


## One spike in spikes_up.png (the strip repeats every 8 px with 3 px gaps).
const SPIKE := Rect2(0, 0, 5, 7)
## Width of one spike tooth in world pixels (matches Spikes.TOOTH).
const TOOTH := 20.0


## Row of spikes pointing up from (0, 0) to (width, 0). Each tooth is stretched to fill its slot.
static func spike_row(ci: CanvasItem, width: float, height: float, modulate := Color.WHITE) -> void:
	var count := maxi(1, ceili(width / TOOTH))
	var tooth := width / count
	for index in range(count):
		ci.draw_texture_rect_region(SPIKES_UP, Rect2(index * tooth, -height - 2.0, tooth, height + 2.0),
			SPIKE, modulate)


## Texture centred horizontally on `bottom_center`, standing on it.
static func stand(ci: CanvasItem, tex: Texture2D, bottom_center: Vector2, scale := PX, modulate := Color.WHITE) -> void:
	var size := tex.get_size() * scale
	ci.draw_texture_rect(tex, Rect2(bottom_center - Vector2(size.x / 2.0, size.y), size), false, modulate)

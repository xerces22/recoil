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
	if flip:
		ci.draw_set_transform(top_corner, 0.0, Vector2(-1, 1))
		ci.draw_texture_rect_region(tex, Rect2(Vector2.ZERO, size), BRACKET, modulate)
		ci.draw_set_transform(Vector2.ZERO)
	else:
		ci.draw_texture_rect_region(tex, Rect2(top_corner, size), BRACKET, modulate)


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


## Hex orb, one texture per crack stage (0 = whole, 5 = about to break). Recoloured from
## MSavioti's CC0 "Crystal Orbs 32x32"; cracks and curse swirl drawn for this game.
const ORB: Array[Texture2D] = [
	preload("res://assets/sprites/boss/orb_0.png"),
	preload("res://assets/sprites/boss/orb_1.png"),
	preload("res://assets/sprites/boss/orb_2.png"),
	preload("res://assets/sprites/boss/orb_3.png"),
	preload("res://assets/sprites/boss/orb_4.png"),
	preload("res://assets/sprites/boss/orb_5.png"),
]
## Bottom half left behind when the orb shatters.
const ORB_SHELL := preload("res://assets/sprites/boss/orb_shell.png")
const ORB_GLOW := Color("b46cff")


## Draws the hex orb centred on `center` with a soft glow. `flash` > 0 whitens it for a hit.
static func draw_orb(ci: CanvasItem, center: Vector2, cracks: int, scale := PX, flash := 0.0) -> void:
	var tex := ORB[clampi(cracks, 0, ORB.size() - 1)]
	var size := tex.get_size() * scale
	var r := size.x / 2.0
	ci.draw_circle(center, r + 14.0, Color(ORB_GLOW, 0.14))
	ci.draw_circle(center, r + 6.0, Color(ORB_GLOW, 0.22))
	var tint := Color.WHITE.lerp(Color(4, 4, 4), clampf(flash * 4.0, 0.0, 1.0))
	ci.draw_texture_rect(tex, Rect2(center - size / 2.0, size), false, tint)


## Swirling purple portal: ragged rim, then darker rings pulled to one side like a tunnel.
static func draw_portal(ci: CanvasItem, center: Vector2, radius: float, spin: float) -> void:
	# Below a few pixels the 36-point rim collapses and the polygon can't be triangulated.
	if radius < 4.0:
		return
	var rim := PackedVector2Array()
	for i in 36:
		var a := TAU * i / 36.0
		var r := radius * (1.0 + 0.13 * sin(a * 5.0 + spin * 9.0) + 0.07 * sin(a * 11.0 - spin * 13.0))
		rim.append(center + Vector2.from_angle(a) * r)
	ci.draw_colored_polygon(rim, Color(0.36, 0.2, 0.5))
	var tunnel := Vector2(radius * 0.16, -radius * 0.04)
	ci.draw_circle(center + tunnel * 0.5, radius * 0.8, Color(0.25, 0.12, 0.34))
	ci.draw_circle(center + tunnel, radius * 0.62, Color(0.12, 0.05, 0.17))
	ci.draw_circle(center + tunnel * 1.4, radius * 0.44, Color(0.04, 0.01, 0.06))
	for ring in 3:
		var r2 := radius * (0.3 + 0.17 * ring)
		var start := spin * (6.0 - ring) + ring * 1.7
		ci.draw_arc(center + tunnel * (1.4 - ring * 0.4), r2, start, start + 2.4, 12,
			Color(0.45, 0.25, 0.6, 0.8), 2.0)
	ci.draw_circle(center, radius * 1.25, Color(0.6, 0.35, 0.9, 0.08))


## Clean and shiny: an expanding ring, sparkles, and a bright glow on the fixed gun.
static func draw_shine(ci: CanvasItem, center: Vector2, f: float, scale := 1.0) -> void:
	var fade := 1.0 - f
	ci.draw_circle(center, (22.0 + 18.0 * f) * scale, Color(1.0, 0.95, 0.7, 0.18 * fade))
	ci.draw_arc(center, (14.0 + 40.0 * f) * scale, 0, TAU, 32, Color(1.0, 0.95, 0.75, 0.8 * fade), 2.0 * scale)
	for i in 6:
		var a := TAU * i / 6.0 + f * 1.5
		var p := center + Vector2.from_angle(a) * (16.0 + 26.0 * f) * scale
		var s := (4.0 * fade + 1.0) * scale
		var w := 1.5 * scale
		ci.draw_rect(Rect2(p - Vector2(w / 3.0, s), Vector2(w, s * 2.0)), Color(1, 1, 0.85, fade))
		ci.draw_rect(Rect2(p - Vector2(s, w / 3.0), Vector2(s * 2.0, w)), Color(1, 1, 0.85, fade))


## Pixel-art ">" chevron pointing along `direction`, rasterised on a `px` grid so it stays crisp
## at any angle. Same look as the player's aim chevron, any size and colour.
static func draw_chevron(ci: CanvasItem, centre: Vector2, direction: Vector2, px: float,
		fill_col := Color(1, 1, 1, 0.92), edge_col := Color(0.08, 0.04, 0.1, 0.85)) -> void:
	var depth := 5.0 * px
	var span := 5.5 * px
	var thick := 0.9 * px
	var outline := 1.9 * px
	var side := direction.orthogonal()
	centre = (centre / px).round() * px
	var tip := centre + direction * depth * 0.5
	var back := centre - direction * depth * 0.5
	var arm_a := back + side * span
	var arm_b := back - side * span
	var reach := int(ceil((span + outline) / px))
	var size := Vector2(px, px)
	var fill: Array[Vector2] = []
	for gx in range(-reach, reach + 1):
		for gy in range(-reach, reach + 1):
			var cell := centre + Vector2(gx, gy) * px
			var mid := cell + size * 0.5
			var dist := minf(mid.distance_to(Geometry2D.get_closest_point_to_segment(mid, tip, arm_a)),
				mid.distance_to(Geometry2D.get_closest_point_to_segment(mid, tip, arm_b)))
			if dist <= thick:
				fill.append(cell)
			elif dist <= outline:
				ci.draw_rect(Rect2(cell, size), edge_col)
	for cell in fill:
		ci.draw_rect(Rect2(cell, size), fill_col)


## A shotgun shell (red hull, brass base) like the ammo pips, `px` screen px per art pixel,
## pointing along `rot` (base at the back). 6 x 11 art pixels. `parent` is the canvas transform
## to draw inside (restored afterwards).
static func draw_shell(ci: CanvasItem, center: Vector2, rot: float, px: float,
		parent := Transform2D.IDENTITY) -> void:
	ci.draw_set_transform_matrix(parent * Transform2D(rot + PI / 2.0, Vector2(px, px), 0.0, center))
	var o := Vector2(-3, -5.5)
	ci.draw_rect(Rect2(o - Vector2(1, 1), Vector2(8, 13)), Color(0.09, 0.05, 0.12))
	ci.draw_rect(Rect2(o, Vector2(6, 7)), Color(0.82, 0.16, 0.12))
	ci.draw_rect(Rect2(o, Vector2(2, 7)), Color(1.0, 0.45, 0.35))
	ci.draw_rect(Rect2(o + Vector2(0, 7), Vector2(6, 4)), Color(0.9, 0.7, 0.25))
	ci.draw_rect(Rect2(o + Vector2(0, 9), Vector2(6, 1)), Color(0.65, 0.45, 0.15))
	ci.draw_set_transform_matrix(parent)

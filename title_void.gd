extends Control
## Title screen backdrop: the hatted shotgun tumbling slowly through a purple void, with
## shotgun shells falling and spinning around it and streaks rushing up to sell the fall.
## Everything is drawn at whole-pixel scales with nearest filtering so it stays crisp.

const SHOTGUN := preload("res://assets/sprites/player/shotgun_main.png")
const STETSON := preload("res://assets/sprites/player/stetson.png")
const STETSON_OFFSET := Vector2(4, -13)
## Gun pixel scale on screen.
const GUN_SCALE := 5.0
const SHELL_SCALE := 3.0
const SHELLS := 16
const STREAKS := 34

## Left edge of the void's visible area (the side panel covers the rest).
var left := 440.0
var _time := 0.0
var _shells: Array[Dictionary] = []
var _streaks: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_rng.seed = 7


func _new_shell(anywhere: bool) -> Dictionary:
	var depth := _rng.randf_range(0.5, 1.2)
	return {
		"pos": Vector2(_rng.randf_range(left + 20.0, size.x + 20.0),
			_rng.randf_range(-40.0, size.y) if anywhere else -40.0),
		"speed": _rng.randf_range(30.0, 90.0) * depth,
		"sway": _rng.randf_range(0.0, TAU),
		"angle": _rng.randf_range(0.0, TAU),
		"spin": _rng.randf_range(-2.0, 2.0),
		"depth": depth,
	}


func _new_streak(anywhere: bool) -> Dictionary:
	return {
		"pos": Vector2(_rng.randf_range(left, size.x),
			_rng.randf_range(0.0, size.y) if anywhere else size.y + 60.0),
		"speed": _rng.randf_range(500.0, 1100.0),
		"length": _rng.randf_range(30.0, 110.0),
		"alpha": _rng.randf_range(0.05, 0.18),
	}


func _process(delta: float) -> void:
	if not is_visible_in_tree() or size.x < 1.0:
		return
	if _shells.is_empty():
		for i in SHELLS:
			_shells.append(_new_shell(true))
		for i in STREAKS:
			_streaks.append(_new_streak(true))
	_time += delta
	for i in _shells.size():
		var shell := _shells[i]
		shell.pos.y += shell.speed * delta
		shell.pos.x += sin(_time * 0.8 + shell.sway) * 12.0 * delta
		shell.angle += shell.spin * delta
		if shell.pos.y > size.y + 40.0:
			_shells[i] = _new_shell(false)
	# Streaks rush upward: we're falling past them.
	for i in _streaks.size():
		var streak := _streaks[i]
		streak.pos.y -= streak.speed * delta
		if streak.pos.y + streak.length < 0.0:
			_streaks[i] = _new_streak(false)
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	# Void: near-black with just a hint of indigo, a little lighter through the middle.
	var top := Color("#060509")
	var mid := Color("#151123")
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h * 0.5), Vector2(0, h * 0.5)]),
		PackedColorArray([top, top, mid, mid]))
	draw_polygon(PackedVector2Array([Vector2(0, h * 0.5), Vector2(w, h * 0.5), Vector2(w, h), Vector2(0, h)]),
		PackedColorArray([mid, mid, top, top]))

	var centre := Vector2(left + (w - left) * 0.5, h * 0.5)
	_draw_shaft(w, h, mid)

	# Curse glow behind the gun, pulsing slowly between green and violet, kept faint.
	var pulse := (sin(_time * 0.9) + 1.0) / 2.0
	var glow := Color("#57e08f").lerp(Color("#8a5cc4"), pulse)
	for ring in 5:
		var r := 70.0 + ring * 34.0
		draw_circle(centre, r, Color(glow, 0.03))

	for streak: Dictionary in _streaks:
		draw_rect(Rect2(streak.pos.round(), Vector2(2, streak.length)), Color(0.85, 0.85, 0.95, streak.alpha * 0.7))

	# Shells behind the gun first (the small, far ones), then the gun, then the near ones.
	for shell: Dictionary in _shells:
		if shell.depth < 0.85:
			_draw_shell(shell)

	var fall := Vector2(sin(_time * 0.6) * 10.0, sin(_time * 0.8) * 14.0)
	var spin := _time * 0.45
	draw_set_transform((centre + fall).round(), spin, Vector2.ONE * GUN_SCALE)
	var gun_size := SHOTGUN.get_size()
	var origin := -gun_size / 2.0
	draw_texture(SHOTGUN, origin)
	draw_texture(STETSON, origin + STETSON_OFFSET)
	draw_set_transform(Vector2.ZERO)

	for shell: Dictionary in _shells:
		if shell.depth >= 0.85:
			_draw_shell(shell)


## The tower's sections, in the order you fall past them. Each has its own stone, mortar and
## wall decoration. They scroll up from below and blend into each other.
const SECTIONS := [
	{"name": "tower", "stone": Color("#1d1a28"), "mortar": Color("#0d0b13"), "decor": "torch"},
	{"name": "library", "stone": Color("#251b17"), "mortar": Color("#110c0a"), "decor": "books"},
	{"name": "boiler", "stone": Color("#2a1416"), "mortar": Color("#120809"), "decor": "cracks"},
	{"name": "cellar", "stone": Color("#18201b"), "mortar": Color("#0a0e0b"), "decor": "chains"},
]
const BRICK := Vector2(44, 22)
const SHAFT_DEPTH := 150.0
const FALL_SPEED := 160.0
## Rows per section (about 8 seconds of falling each), and rows spent blending into the next.
const SECTION_ROWS := 60
const BLEND_ROWS := 14


## Which section a brick row belongs to, and how far it has blended into the next one.
func _section_at(row: int) -> Array:
	var index := floori(float(row) / SECTION_ROWS)
	var into := posmod(row, SECTION_ROWS)
	var k := clampf(float(into - (SECTION_ROWS - BLEND_ROWS)) / BLEND_ROWS, 0.0, 1.0)
	var a: Dictionary = SECTIONS[posmod(index, SECTIONS.size())]
	var b: Dictionary = SECTIONS[posmod(index + 1, SECTIONS.size())]
	return [a, b, k]


## Tower-shaft brickwork on both edges, scrolling up: we're falling down the tower, past its
## tower rooms, library, boiler rooms and cellar. Fades into the dark toward the middle.
func _draw_shaft(w: float, h: float, bg: Color) -> void:
	var fallen := _time * FALL_SPEED
	var first_row := floori(fallen / BRICK.y)
	var offset := fmod(fallen, BRICK.y)
	var rows := int(h / BRICK.y) + 2
	for side: float in [left, w - SHAFT_DEPTH]:
		for i in rows:
			# World row grows downward as we fall, so new sections arrive from the bottom.
			var row := first_row + i
			var y := i * BRICK.y - offset
			var sec := _section_at(row)
			var stone: Color = (sec[0].stone as Color).lerp(sec[1].stone, sec[2])
			var mortar: Color = (sec[0].mortar as Color).lerp(sec[1].mortar, sec[2])
			draw_rect(Rect2(side, y, SHAFT_DEPTH, BRICK.y), mortar)
			var shift := BRICK.x * 0.5 if posmod(row, 2) == 0 else 0.0
			var x := side - shift
			while x < side + SHAFT_DEPTH:
				var r := Rect2(Vector2(maxf(x, side) + 1.0, y + 1.0),
					Vector2(minf(x + BRICK.x, side + SHAFT_DEPTH) - maxf(x, side) - 2.0, BRICK.y - 2.0))
				if r.size.x > 0.0:
					# A little per-brick variation so walls don't look flat.
					var n := posmod(row * 7 + int(x) * 3, 5)
					draw_rect(r, stone.lightened(n * 0.015))
				x += BRICK.x
			# Decoration every few rows, picked by whichever section this row mostly is.
			var decor: String = sec[0].decor if sec[2] < 0.5 else sec[1].decor
			if posmod(row, 9) == 0:
				_draw_decor(decor, side, y, row)
		# Fade the wall into the void, using the void's own colour at each height (dark at the
		# top and bottom, lighter in the middle) so there's no seam where the wall ends.
		var inner: float = side + SHAFT_DEPTH if side == left else side
		var outer: float = side if side == left else side + SHAFT_DEPTH
		var dark := Color("#060509")
		for half in 2:
			var y0 := h * 0.5 * half
			var y1 := y0 + h * 0.5
			var c0 := dark if half == 0 else bg
			var c1 := bg if half == 0 else dark
			draw_polygon(PackedVector2Array([Vector2(outer, y0), Vector2(inner, y0), Vector2(inner, y1), Vector2(outer, y1)]),
				PackedColorArray([Color(c0, 0.25), Color(c0, 1.0), Color(c1, 1.0), Color(c1, 0.25)]))


## One wall decoration near the outer edge of the shaft, sized in whole pixels.
func _draw_decor(kind: String, side: float, y: float, row: int) -> void:
	var x := side + 18.0 if side == left else side + SHAFT_DEPTH - 48.0
	match kind:
		"torch":
			draw_rect(Rect2(x + 12, y + 8, 6, 14), Color("#4a3426"))
			var f := 0.8 + 0.2 * sin(_time * 14.0 + row)
			draw_circle(Vector2(x + 15, y + 2), 16.0, Color(1.0, 0.55, 0.2, 0.08 * f))
			draw_rect(Rect2(x + 11, y - 4 - 3 * f, 8, 10 * f), Color("#ff9a3c"))
			draw_rect(Rect2(x + 13, y - 1 - 2 * f, 4, 6 * f), Color("#ffe08a"))
		"books":
			draw_rect(Rect2(x - 4, y + 18, 38, 4), Color("#3b2a1e"))
			var colours := [Color("#5a2d2d"), Color("#2d3f5a"), Color("#3f5a2d"), Color("#5a4a2d"), Color("#4a2d5a")]
			for b in 6:
				var hgt := 12 + posmod(row + b * 5, 6)
				draw_rect(Rect2(x - 2 + b * 6, y + 18 - hgt, 5, hgt), colours[posmod(row + b, colours.size())])
		"cracks":
			var glow := Color(1.0, 0.35, 0.1, 0.55 + 0.25 * sin(_time * 3.0 + row))
			var p := Vector2(x + 4, y + 2)
			for s in 4:
				var q := p + Vector2(6 + posmod(row + s, 3) * 2, 5)
				draw_line(p, q, glow, 2.0)
				p = q
		"chains":
			for l in 4:
				var ly := y - 10 + l * 9
				draw_rect(Rect2(x + 12, ly, 6, 7), Color("#3a3d42"), false, 2.0)
			draw_rect(Rect2(x + 4, y + 26, 20, 3), Color("#2c3a2c"))   # moss under the hook


## A shotgun shell: red hull with a brass base, drawn in pixels.
func _draw_shell(shell: Dictionary) -> void:
	var s: float = SHELL_SCALE * shell.depth
	var dim: float = clampf(shell.depth, 0.55, 1.0)
	draw_set_transform(shell.pos.round(), shell.angle, Vector2(s, s))
	draw_rect(Rect2(-2, -5, 4, 7), Color(0.78, 0.18, 0.22).darkened(1.0 - dim))
	draw_rect(Rect2(-2, -5, 1, 7), Color(0.95, 0.4, 0.4).darkened(1.0 - dim))
	draw_rect(Rect2(-2, 2, 4, 3), Color(0.88, 0.68, 0.28).darkened(1.0 - dim))
	draw_rect(Rect2(-2, 4, 4, 1), Color(0.6, 0.42, 0.15).darkened(1.0 - dim))
	draw_set_transform(Vector2.ZERO)

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
	_draw_sigil(centre)

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


## Faint tower-shaft brickwork on both edges, scrolling up: we're falling down the tower.
## Fades into the dark toward the middle so it stays in the background.
func _draw_shaft(w: float, h: float, bg: Color) -> void:
	const BRICK := Vector2(44, 22)
	const DEPTH := 150.0
	var scroll := fmod(_time * 160.0, BRICK.y * 2.0)
	var stone := Color("#1b1626")
	var mortar := Color("#0d0a14")
	for side: float in [left, w - DEPTH]:
		draw_rect(Rect2(side, 0, DEPTH, h), mortar)
		var rows := int(h / BRICK.y) + 3
		for row in rows:
			var y := row * BRICK.y - scroll
			var shift := BRICK.x * 0.5 if row % 2 == 0 else 0.0
			var x := side - shift
			while x < side + DEPTH:
				var r := Rect2(Vector2(maxf(x, side) + 1.0, y + 1.0),
					Vector2(minf(x + BRICK.x, side + DEPTH) - maxf(x, side) - 2.0, BRICK.y - 2.0))
				if r.size.x > 0.0:
					draw_rect(r, stone)
				x += BRICK.x
		# Fade the wall into the void, using the void's own colour at each height (dark at the
		# top and bottom, lighter in the middle) so there's no seam where the wall ends.
		var inner: float = side + DEPTH if side == left else side
		var outer: float = side if side == left else side + DEPTH
		var dark := Color("#060509")
		for half in 2:
			var y0 := h * 0.5 * half
			var y1 := y0 + h * 0.5
			var c0 := dark if half == 0 else bg
			var c1 := bg if half == 0 else dark
			draw_polygon(PackedVector2Array([Vector2(outer, y0), Vector2(inner, y0), Vector2(inner, y1), Vector2(outer, y1)]),
				PackedColorArray([Color(c0, 0.3), Color(c0, 1.0), Color(c1, 1.0), Color(c1, 0.3)]))


## A slow-turning curse sigil behind the gun: two rune rings and a hexagram, very faint.
func _draw_sigil(centre: Vector2) -> void:
	var colour := Color("#57e08f", 0.10 + 0.04 * sin(_time * 1.1))
	var spin := _time * 0.12
	draw_arc(centre, 205.0, 0.0, TAU, 96, colour, 2.0)
	draw_arc(centre, 172.0, 0.0, TAU, 96, Color(colour, colour.a * 0.7), 1.0)
	# Rune ticks between the rings, turning one way.
	for i in 24:
		var a := spin + i * TAU / 24.0
		var p := centre + Vector2.from_angle(a) * 188.0
		var len := 6.0 if i % 3 == 0 else 3.0
		draw_line(p - Vector2.from_angle(a) * len, p + Vector2.from_angle(a) * len, colour, 2.0)
		if i % 6 == 0:
			var d := Vector2.from_angle(a + PI / 4.0) * 5.0
			draw_colored_polygon(PackedVector2Array([p + d, p + d.orthogonal(), p - d, p - d.orthogonal()]), colour)
	# Hexagram, turning the other way.
	for tri in 2:
		var pts := PackedVector2Array()
		for k in 4:
			pts.append(centre + Vector2.from_angle(-spin * 1.5 + tri * PI / 3.0 + k * TAU / 3.0) * 165.0)
		draw_polyline(pts, Color(colour, colour.a * 0.8), 1.5)


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

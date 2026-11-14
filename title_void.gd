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
	# Void: deep purple, a little lighter through the middle.
	var top := Color("#0b0512")
	var mid := Color("#2a1140")
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h * 0.5), Vector2(0, h * 0.5)]),
		PackedColorArray([top, top, mid, mid]))
	draw_polygon(PackedVector2Array([Vector2(0, h * 0.5), Vector2(w, h * 0.5), Vector2(w, h), Vector2(0, h)]),
		PackedColorArray([mid, mid, top, top]))

	var centre := Vector2(left + (w - left) * 0.5, h * 0.5)
	# Curse glow behind the gun, pulsing slowly between green and violet.
	var pulse := (sin(_time * 0.9) + 1.0) / 2.0
	var glow := Color("#57e08f").lerp(Color("#b46cff"), pulse)
	for ring in 6:
		var r := 70.0 + ring * 34.0
		draw_circle(centre, r, Color(glow, 0.045))

	for streak: Dictionary in _streaks:
		draw_rect(Rect2(streak.pos.round(), Vector2(2, streak.length)), Color(0.85, 0.75, 1.0, streak.alpha))

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

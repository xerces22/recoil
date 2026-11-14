class_name StoryIntro
extends CanvasLayer
## The opening storyboard: Mr. Guy bumps into Mrs. Witch in the village and gets turned
## into a shotgun. Still panels drawn as chunky pixel art, one line of text each.
## Can't be skipped: a click only finishes the typing or turns the page once the line is
## fully shown, and every panel also turns by itself after a short hold.
## Same interface as StoryCards: play(), then wait for `finished`.

signal finished

const FONT := preload("res://assets/fonts/PressStart2P-Regular.ttf")
const SHOTGUN := preload("res://assets/sprites/player/shotgun_hat.png")
const SFX_BUMP := preload("res://assets/sfx/impactSoft_heavy_001.ogg")
const SFX_ZAP := preload("res://assets/sfx/portal.wav")
const SFX_BLAST := preload("res://assets/sfx/shotgun_blast_mossberg_1.wav")

const S := 5.0           # screen pixels per art pixel (256 x 144 art -> 1280 x 720)
const GROUND := 118      # where feet stand
const MIN_HOLD := 0.5    # seconds a finished line stays before a click can turn it
const AUTO_HOLD := 3.2   # seconds a finished line stays before it turns by itself

# Each panel: what to draw, who talks (empty = narrator) and the line.
const PANELS := [
	{"shot": "walk_in", "who": "", "text": "This is Mr. Guy."},
	{"shot": "walk_on", "who": "", "text": "Mr. Guy was taking his usual walk through the village..."},
	{"shot": "bump", "who": "", "text": "*BUMP*"},
	{"shot": "guy_mad", "who": "MR. GUY", "text": "HEY! Watch where you're going!"},
	{"shot": "witch_mad", "who": "MRS. WITCH", "text": "Excuse me?! You talk to ME like that?"},
	{"shot": "wand_up", "who": "MRS. WITCH", "text": "Let's see how tough you are... as a SHOTGUN!"},
	{"shot": "zap", "who": "", "text": "ZZZAP!"},
	{"shot": "shotgun", "who": "", "text": "...and that is how Mr. Guy became a shotgun."},
	{"shot": "tower", "who": "", "text": "To break the curse, he has to blast his way up her tower."},
]

# Close-up zoom per shot (others are the wide shot).
const ZOOM := {"bump": 1.6, "guy_mad": 2.0, "witch_mad": 2.0, "wand_up": 1.8, "zap": 1.6}

# Palette
const SKY := [Color("2a1c3f"), Color("3d2350"), Color("5a2d55"), Color("7e3b55"), Color("a8504f"), Color("d8774a")]
const HILL := Color("2b1f38")
const GROUND_C := Color("4a3a36")
const PATH_C := Color("6b574c")
const COBBLE := Color("806a5c")
const SKIN := Color("eebf98")
const DARK := Color("1a1220")
const HAT := Color("63271a")
const HAT_LIGHT := Color("8c5638")
const HAT_DARK := Color("3f2719")
const BAND := Color("153c35")
const SHIRT := Color("a6403a")
const PANTS := Color("3a3150")
const WITCH_SKIN := Color("8cbf5f")
const ROBE := Color("5b2a78")
const ROBE_DARK := Color("3c1a52")
const HAIR := Color("17101c")
const MAGIC := Color("ffe36b")

var _index := -1
var _t := 0.0            # time on the current panel
var _typed := false
var _stage: Node2D
var _box: Panel
var _who: Label
var _text: Label
var _prompt: Label
var _fade: ColorRect
var _sfx: AudioStreamPlayer
var _busy := false       # true while fading between panels
var _flash := 0.0


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	var back := ColorRect.new()
	back.color = Color.BLACK
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(back)

	_stage = Node2D.new()
	_stage.draw.connect(_draw_stage)
	add_child(_stage)

	# Comic-style speech box along the top, over the sky.
	_box = Panel.new()
	_box.position = Vector2(90, 26)
	_box.size = Vector2(1100, 132)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.03, 0.09, 0.92)
	style.border_color = Color(0.93, 0.88, 1.0)
	style.set_border_width_all(4)
	_box.add_theme_stylebox_override("panel", style)
	add_child(_box)

	_who = _label(14, MAGIC)
	_who.position = Vector2(24, 18)
	_box.add_child(_who)

	_text = _label(18, Color(0.95, 0.91, 1.0))
	_text.position = Vector2(24, 48)
	_text.size = Vector2(1052, 70)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.add_theme_constant_override("line_spacing", 8)
	_box.add_child(_text)

	_prompt = _label(10, Color(0.65, 0.55, 0.8))
	_prompt.text = "click"
	_prompt.position = Vector2(1020, 108)
	_box.add_child(_prompt)

	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)

	_sfx = AudioStreamPlayer.new()
	_sfx.bus = &"SFX"
	add_child(_sfx)


func _label(size_px: int, colour: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", size_px)
	label.add_theme_color_override("font_color", colour)
	return label


func play() -> void:
	visible = true
	get_tree().paused = true
	_index = -1
	_fade.modulate.a = 1.0
	_next()


func _next() -> void:
	_busy = true
	var tween := create_tween()
	if _index >= 0:
		tween.tween_property(_fade, "modulate:a", 1.0, 0.25)
	tween.tween_callback(func() -> void:
		_index += 1
		if _index >= PANELS.size():
			_close()
			return
		_show_panel())
	tween.tween_property(_fade, "modulate:a", 0.0, 0.25)
	tween.tween_callback(func() -> void: _busy = false)


func _show_panel() -> void:
	var panel: Dictionary = PANELS[_index]
	_t = 0.0
	_typed = false
	_who.text = panel.who
	_who.visible = panel.who != ""
	_text.text = panel.text
	_text.visible_ratio = 0.0
	_prompt.visible = false
	# Dialogue panels are a close-up on the two of them.
	var zoom: float = ZOOM.get(panel.shot, 1.0)
	_stage.scale = Vector2(zoom, zoom)
	_stage.position = Vector2(640, 470) - Vector2(128, 100) * S * zoom if zoom > 1.0 else Vector2.ZERO
	match panel.shot:
		"bump":
			_play(SFX_BUMP)
		"zap":
			_play(SFX_ZAP)
			_flash = 1.0
		"shotgun":
			_play(SFX_BLAST)


func _play(stream: AudioStream) -> void:
	_sfx.stream = stream
	_sfx.play()


func _process(delta: float) -> void:
	if not visible:
		return
	# Keep the game frozen even if a menu unpauses it under us.
	if not get_tree().paused:
		get_tree().paused = true
	_t += delta
	_flash = maxf(_flash - delta * 2.5, 0.0)
	if _index >= 0 and _index < PANELS.size():
		if not _typed:
			_text.visible_ratio = minf(_t / maxf(_text.text.length() * 0.035, 0.2), 1.0)
			if _text.visible_ratio >= 1.0:
				_typed = true
				_t = 0.0
		else:
			_prompt.visible = _t > MIN_HOLD
			_prompt.modulate.a = 0.55 + 0.45 * sin(_t * 5.0)
			if _t > AUTO_HOLD and not _busy:
				_next()
	_stage.queue_redraw()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	get_viewport().set_input_as_handled()
	var pressed: bool = (event is InputEventMouseButton and event.pressed) \
		or (event is InputEventKey and event.pressed and not event.echo \
			and event.keycode != KEY_ESCAPE)
	if not pressed or _busy:
		return
	if not _typed:
		_text.visible_ratio = 1.0
		_typed = true
		_t = 0.0
	elif _t > MIN_HOLD:
		_next()


func _close() -> void:
	visible = false
	get_tree().paused = false
	finished.emit()
	queue_free()


# ---------------------------------------------------------------- drawing

func _draw_stage() -> void:
	if _index < 0 or _index >= PANELS.size():
		return
	var shot: String = PANELS[_index].shot
	var walk := int(_t * 6.0) % 2   # walking frame
	match shot:
		"walk_in":
			_village()
			_guy(lerpf(10.0, 80.0, minf(_t / 4.0, 1.0)), walk, false)
		"walk_on":
			_village()
			var k := minf(_t / 3.5, 1.0)
			_guy(lerpf(80.0, 112.0, k), walk, false)
			_witch(lerpf(250.0, 150.0, k), walk, false, false)
		"bump":
			_village()
			var push := minf(_t * 8.0, 1.0) * 4.0
			_guy(120.0 - push, 0, false)
			_witch(138.0 + push, 0, false, false)
			_burst(Vector2(129, 102), 10.0 + sin(_t * 20.0) * 1.5)
			_word("BUMP!", Vector2(129, 80), 26, Color.WHITE)
		"guy_mad":
			_village()
			_guy(116.0, 0, true)
			_witch(142.0, 0, false, false)
			_steam(Vector2(116, 84))
		"witch_mad":
			_village(0.35)
			_guy(116.0, 0, true)
			_witch(142.0, 0, true, false)
			_steam(Vector2(142, 82))
		"wand_up":
			_village(0.55)
			_guy(116.0, 0, false)
			_witch(142.0, 0, true, true)
			_stage.draw_circle(_p(Vector2(128, 88)), (6.0 + sin(_t * 9.0) * 2.0) * S, Color(MAGIC, 0.25))
		"zap":
			_village(0.7)
			_witch(142.0, 0, true, true)
			_zap(Vector2(128, 88), Vector2(116, 100))
			_guy_glow(116.0)
		"shotgun":
			_village(0.3)
			_witch(196.0, 0, false, false)
			_smoke(Vector2(100, 110))
			var size := Vector2(SHOTGUN.get_size()) * 2.0
			var at := _p(Vector2(100, GROUND)) - Vector2(size.x * 0.5 * S, size.y * S)
			_stage.draw_texture_rect(SHOTGUN, Rect2(at, size * S), false)
		"tower":
			_tower()
	if _flash > 0.0:
		_stage.draw_rect(Rect2(-5000, -5000, 10000, 10000), Color(1, 1, 1, _flash))


func _p(v: Vector2) -> Vector2:
	return v * S


func _px(x: float, y: float, w: float, h: float, c: Color) -> void:
	_stage.draw_rect(Rect2(x * S, y * S, w * S, h * S), c)


func _poly(points: Array, c: Color) -> void:
	var packed := PackedVector2Array()
	for point: Vector2 in points:
		packed.append(point * S)
	_stage.draw_colored_polygon(packed, c)


func _word(text: String, centre: Vector2, size_px: int, c: Color) -> void:
	var width := FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
	var at := _p(centre) - Vector2(width * 0.5, 0)
	_stage.draw_string_outline(FONT, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, 8, DARK)
	_stage.draw_string(FONT, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, c)


## The village at dusk. `dread` darkens the sky toward purple as the witch gets angry.
func _village(dread := 0.0) -> void:
	for i in SKY.size():
		var c: Color = SKY[i].lerp(Color("1c1030"), dread * (0.4 + 0.1 * i))
		_px(0, i * 16, 256, 16, c)
	_stage.draw_circle(_p(Vector2(206, 84)), 16 * S, Color("f5c070").lerp(Color("b06a8a"), dread))
	_poly([Vector2(0, 92), Vector2(40, 82), Vector2(90, 90), Vector2(150, 80), Vector2(210, 88),
		Vector2(256, 82), Vector2(256, 110), Vector2(0, 110)], HILL)
	_house(8, 34, 26, Color("8a6a58"), Color("5a2d3a"))
	_house(56, 26, 20, Color("7a6a70"), Color("3a3050"))
	_tree(98)
	_house(170, 40, 30, Color("907060"), Color("4a2a40"))
	_house(222, 28, 22, Color("6e5a58"), Color("5a2d3a"))
	_px(0, 106, 256, 38, GROUND_C)
	_px(0, 110, 256, 12, PATH_C)
	for i in 22:
		_px(4 + i * 12 + (i % 2) * 5, 112 + (i % 3) * 3, 4, 1, COBBLE)


func _house(x: float, w: float, h: float, wall: Color, roof: Color) -> void:
	var base := 106.0
	_px(x, base - h, w, h, wall)
	_poly([Vector2(x - 3, base - h), Vector2(x + w * 0.5, base - h - w * 0.45),
		Vector2(x + w + 3, base - h)], roof)
	_px(x + w * 0.5 - 3, base - 9, 6, 9, DARK)
	_px(x + 4, base - h + 5, 5, 5, Color("ffd27a"))
	if w > 30:
		_px(x + w - 9, base - h + 5, 5, 5, Color("ffd27a"))


func _tree(x: float) -> void:
	_px(x - 1, 92, 3, 14, Color("3b2a22"))
	_stage.draw_circle(_p(Vector2(x, 86)), 9 * S, Color("2e4a3a"))
	_stage.draw_circle(_p(Vector2(x + 4, 82)), 6 * S, Color("3b5e46"))


## The stetson Mr. Guy wears (and later the shotgun). Mrs. Witch wears the same one.
func _hat(x: float, y: float, band: Color) -> void:
	_px(x - 7, y + 4, 14, 2, HAT_DARK)
	_px(x - 8, y + 3, 2, 1, HAT_DARK)
	_px(x + 6, y + 3, 2, 1, HAT_DARK)
	_px(x - 4, y - 1, 8, 5, HAT)
	_px(x - 3, y - 1, 3, 1, HAT_LIGHT)
	_px(x - 1, y - 2, 2, 1, HAT_DARK)
	_px(x - 4, y + 2, 8, 1, band)


## Mr. Guy faces right. x is his middle, feet on GROUND.
func _guy(x: float, frame: int, mad: bool) -> void:
	var g := GROUND
	var spread := 2 if frame == 1 else 0
	_px(x - 3 - spread, g - 8, 2, 8, PANTS)
	_px(x + 1 + spread, g - 8, 2, 8, PANTS)
	_px(x - 4 - spread, g - 1, 3, 1, DARK)
	_px(x + 1 + spread, g - 1, 3, 1, DARK)
	_px(x - 4, g - 19, 8, 11, SHIRT)
	_px(x - 4, g - 10, 8, 1, HAT_DARK)
	if mad:
		_px(x + 4, g - 20, 2, 5, SHIRT)          # raised fist
		_px(x + 4, g - 22, 2, 2, SKIN)
	else:
		_px(x - 5, g - 18, 1, 7, SHIRT)
		_px(x - 5, g - 11, 1, 1, SKIN)
	_px(x - 3, g - 26, 6, 7, SKIN)
	_px(x + 1, g - 23, 1, 1, DARK)                # eye
	_px(x, g - 21, 3, 1, Color("6b3a22"))         # moustache
	if mad:
		_px(x, g - 25, 1, 1, DARK)
		_px(x + 1, g - 24, 2, 1, DARK)            # angry brow
		_px(x + 1, g - 20, 2, 1, DARK)            # shouting mouth
	_hat(x, g - 32, BAND)


## Mrs. Witch faces left.
func _witch(x: float, frame: int, mad: bool, wand_up: bool) -> void:
	var g := GROUND
	var sway := 1.0 if frame == 1 else 0.0
	_poly([Vector2(x - 3, g - 19), Vector2(x + 3, g - 19), Vector2(x + 6 + sway, g),
		Vector2(x - 6 - sway, g)], ROBE)
	_px(x - 6 - sway, g - 2, 12 + sway * 2, 2, ROBE_DARK)
	_px(x + 1, g - 26, 4, 12, HAIR)
	var skin := WITCH_SKIN.lerp(Color("c46a4a"), 0.45) if mad else WITCH_SKIN
	_px(x - 3, g - 26, 5, 7, skin)
	_px(x - 5, g - 23, 2, 2, skin)                # long nose
	_px(x - 5, g - 22, 1, 1, Color("5a7a3a"))     # wart
	_px(x - 2, g - 24, 1, 1, Color("ff3030") if mad else DARK)
	if mad:
		_px(x - 2, g - 25, 2, 1, DARK)
		_px(x - 3, g - 26, 1, 1, DARK)
	if wand_up:
		_px(x - 5, g - 20, 3, 2, ROBE)            # arm up
		_stage.draw_line(_p(Vector2(x - 5, g - 20)), _p(Vector2(x - 13, g - 29)), Color("4a2e1e"), S)
		_star(Vector2(x - 14, g - 30), 2.5 + sin(_t * 12.0) * 0.5)
	else:
		_px(x - 5, g - 17, 3, 2, ROBE)
		_stage.draw_line(_p(Vector2(x - 5, g - 16)), _p(Vector2(x - 8, g - 10)), Color("4a2e1e"), S)
	_hat(x, g - 32, Color("7a3a9a"))


func _star(c: Vector2, r: float) -> void:
	var points: Array = []
	for i in 10:
		var radius := r if i % 2 == 0 else r * 0.45
		points.append(c + Vector2.from_angle(i * TAU / 10.0 - PI / 2) * radius)
	_poly(points, MAGIC)


func _burst(c: Vector2, r: float) -> void:
	var points: Array = []
	for i in 16:
		var radius := r if i % 2 == 0 else r * 0.5
		points.append(c + Vector2.from_angle(i * TAU / 16.0) * radius)
	_poly(points, Color("ffe8a0"))
	_stage.draw_circle(_p(c), r * 0.35 * S, Color.WHITE)


func _steam(c: Vector2) -> void:
	for i in 3:
		var rise := fmod(_t * 10.0 + i * 4.0, 12.0)
		var a := 1.0 - rise / 12.0
		_stage.draw_circle(_p(c + Vector2(-4 + i * 4, -rise)), 2.0 * S, Color(0.9, 0.9, 0.95, a * 0.8))


func _zap(from: Vector2, to: Vector2) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(_t * 20.0)
	var points := PackedVector2Array()
	for i in 7:
		var k := i / 6.0
		var jitter := Vector2(rng.randf_range(-3, 3), rng.randf_range(-3, 3)) if i in range(1, 6) else Vector2.ZERO
		points.append(_p(from.lerp(to, k) + jitter))
	_stage.draw_polyline(points, Color(MAGIC, 0.5), 4 * S)
	_stage.draw_polyline(points, Color.WHITE, 1.5 * S)


func _guy_glow(x: float) -> void:
	var c := Vector2(x, GROUND - 14)
	_stage.draw_circle(_p(c), (14.0 + sin(_t * 18.0) * 2.0) * S, Color(MAGIC, 0.35))
	_stage.draw_circle(_p(c), 9.0 * S, Color(1, 1, 1, 0.8))
	for i in 8:
		var a := i * TAU / 8.0 + _t * 3.0
		_star(c + Vector2.from_angle(a) * (16.0 + fmod(_t * 8.0, 6.0)), 1.5)


func _smoke(c: Vector2) -> void:
	for i in 6:
		var a := i * TAU / 6.0
		var r := 8.0 + _t * 6.0
		var alpha := clampf(1.0 - _t / 2.5, 0.0, 0.7)
		_stage.draw_circle(_p(c + Vector2.from_angle(a) * r * Vector2(1.4, 0.6)), 5.0 * S, Color(0.75, 0.7, 0.8, alpha))


## Last panel: the witch's tower against the night sky, the orb glowing at the top.
func _tower() -> void:
	for i in SKY.size():
		_px(0, i * 24, 256, 24, Color("150c22").lerp(Color("3a1f4a"), i / 6.0))
	for i in 30:
		_px(fmod(i * 53.0, 256.0), 34.0 + fmod(i * 29.0, 70.0), 1, 1, Color(1, 1, 1, 0.5 + 0.5 * sin(_t * 3.0 + i)))
	_px(108, 62, 40, 82, Color("2b2236"))
	_px(104, 58, 48, 6, Color("3a2e48"))
	for i in 5:
		_px(104 + i * 10, 54, 6, 4, Color("3a2e48"))
	for i in 4:
		_px(124, 72 + i * 16, 8, 9, Color("ffd27a") if i % 2 == 0 else Color("120a18"))
	var glow := 5.0 + sin(_t * 4.0) * 1.2
	_stage.draw_circle(_p(Vector2(128, 45)), glow * 1.8 * S, Color(0.6, 1.0, 0.5, 0.25))
	_stage.draw_circle(_p(Vector2(128, 45)), glow * S, Color("9cff7a"))
	_px(0, 136, 256, 8, HILL)
	# Our hero, waiting at the bottom.
	var size := Vector2(SHOTGUN.get_size())
	_stage.draw_texture_rect(SHOTGUN, Rect2(_p(Vector2(36, 136)) - Vector2(0, size.y * S), size * S), false)

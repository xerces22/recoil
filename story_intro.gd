class_name StoryIntro
extends CanvasLayer
## The opening storyboard: Mr. Guy bumps into Mrs. Sandwitch in the village, gets turned into
## a shotgun, carried to her castle and thrown into the cellar. Panels are drawn as chunky
## pixel art with one line of text each.
##
## Can't be skipped. A click finishes the typing, or turns the page once the line is shown
## and the panel's action has played out. Panels also turn by themselves after a hold.
## Panels in the same place flow into each other with a camera move; a change of place
## fades through black. Same interface as StoryCards: play(), then wait for `finished`.

signal finished

const FONT := preload("res://assets/fonts/PressStart2P-Regular.ttf")
const SHOTGUN := preload("res://assets/sprites/player/shotgun_hat.png")
const STETSON := preload("res://assets/sprites/player/stetson.png")   # the hat the shotgun wears
const SFX_BUMP := preload("res://assets/sfx/impactSoft_heavy_001.ogg")
const SFX_ZAP := preload("res://assets/sfx/portal.wav")
const SFX_BLAST := preload("res://assets/sfx/shotgun_blast_mossberg_1.wav")
const SFX_WHOOSH := preload("res://assets/sfx/fall_wind_loop.ogg")

const S := 5.0             # screen pixels per art pixel (256 x 144 art -> 1280 x 720)
const GROUND := 118        # where feet stand
const TYPE_SPEED := 0.035  # seconds per character
const MIN_HOLD := 0.4      # a shown line stays at least this long before a click turns it
const AUTO_HOLD := 2.8     # ...and turns by itself after this long
const FADE := 0.35         # fade to / from black when the place changes
const WIDE := Vector2(128, 72)   # camera centre for the wide shot
const PAIR := Vector2(129, 88)   # camera centre for close-ups on the two of them

# Each panel: place, camera (zoom + centre), how dark the sky is, how long its action
# takes (the page won't turn before that), who talks and the line.
const PANELS := [
	{"shot": "walk_in", "place": "village", "zoom": 1.0, "at": WIDE, "dread": 0.0, "act": 2.6,
		"who": "", "text": "This is Mr. Guy. He really loves his hat."},
	{"shot": "walk_on", "place": "village", "zoom": 1.0, "at": WIDE, "dread": 0.0, "act": 3.0,
		"who": "", "text": "One evening, on his usual walk through the village..."},
	{"shot": "bump", "place": "village", "zoom": 1.6, "at": PAIR, "dread": 0.1, "act": 0.4,
		"who": "", "text": "*BUMP*"},
	{"shot": "guy_mad", "place": "village", "zoom": 2.0, "at": PAIR, "dread": 0.15, "act": 0.0,
		"who": "MR. GUY", "text": "HEY! Watch where you're going!"},
	{"shot": "witch_mad", "place": "village", "zoom": 2.0, "at": PAIR, "dread": 0.35, "act": 0.0,
		"who": "MRS. SANDWITCH", "text": "Excuse me?! You talk to ME like that?"},
	{"shot": "hat", "place": "village", "zoom": 2.2, "at": Vector2(124, 88), "dread": 0.35, "act": 0.0,
		"who": "MR. GUY", "text": "You are surely jealous of my HAT!"},
	{"shot": "wand_up", "place": "village", "zoom": 1.8, "at": PAIR, "dread": 0.55, "act": 0.6,
		"who": "MRS. SANDWITCH", "text": "Jealous? Let's see how tough you are... as a SHOTGUN!"},
	{"shot": "zap", "place": "village", "zoom": 1.6, "at": PAIR, "dread": 0.7, "act": 1.0,
		"who": "", "text": "ZZZAP!"},
	{"shot": "shotgun", "place": "village", "zoom": 1.2, "at": Vector2(128, 84), "dread": 0.3, "act": 1.5,
		"who": "", "text": "...and Mr. Guy became a shotgun. A very small, very angry shotgun."},
	{"shot": "carry", "place": "castle", "zoom": 1.0, "at": WIDE, "dread": 0.0, "act": 3.0,
		"who": "MRS. SANDWITCH", "text": "Oh, stop hopping. You're coming with me."},
	{"shot": "throw", "place": "castle", "zoom": 1.0, "at": WIDE, "dread": 0.0, "act": 1.4,
		"who": "MRS. SANDWITCH", "text": "Enjoy the cellar! My tower is right on top of it... if you can climb."},
	{"shot": "fall", "place": "shaft", "zoom": 1.0, "at": WIDE, "dread": 0.0, "act": 1.5,
		"who": "", "text": "Down... down... down..."},
]

# Palette
const SKY := [Color("2a1c3f"), Color("3d2350"), Color("5a2d55"), Color("7e3b55"), Color("a8504f"), Color("d8774a")]
const HILL := Color("2b1f38")
const GROUND_C := Color("4a3a36")
const PATH_C := Color("6b574c")
const COBBLE := Color("806a5c")
const SKIN := Color("eebf98")
const DARK := Color("1a1220")
const HAT_DARK := Color("3f2719")
const SHIRT := Color("a6403a")
const PANTS := Color("3a3150")
const WITCH_SKIN := Color("8cbf5f")
const ROBE := Color("5b2a78")
const ROBE_DARK := Color("3c1a52")
const HAIR := Color("17101c")
const MAGIC := Color("ffe36b")

var _index := -1
var _t := 0.0            # time since the panel appeared; drives all its animation
var _typed := false
var _shown_for := 0.0    # time since the line finished typing
var _busy := false       # true while fading between places
var _flash := 0.0
var _zoom := 1.0         # camera, eased toward the panel's zoom and centre
var _at := WIDE
var _dread := 0.0        # sky darkness, eased too

var _stage: Node2D
var _box: Panel
var _who: Label
var _text: Label
var _prompt: Label
var _fade: ColorRect
var _sfx: AudioStreamPlayer


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


## Turn the page. Same place: cut straight to the next panel and let the camera glide.
## New place (or the start / end): fade through black.
func _next() -> void:
	var next := _index + 1
	var same_place: bool = _index >= 0 and next < PANELS.size() \
		and PANELS[next].place == PANELS[_index].place
	if same_place:
		_index = next
		_show_panel(false)
		return
	_busy = true
	var tween := create_tween()
	if _index >= 0:
		tween.tween_property(_fade, "modulate:a", 1.0, FADE)
	tween.tween_callback(func() -> void:
		_index = next
		if _index >= PANELS.size():
			_close()
			return
		_show_panel(true))
	tween.tween_property(_fade, "modulate:a", 0.0, FADE)
	tween.tween_callback(func() -> void: _busy = false)


func _show_panel(snap_camera: bool) -> void:
	var panel: Dictionary = PANELS[_index]
	_t = 0.0
	_typed = false
	_shown_for = 0.0
	_who.text = panel.who
	_who.visible = panel.who != ""
	_text.text = panel.text
	_text.visible_ratio = 0.0
	_prompt.visible = false
	if snap_camera:
		_zoom = panel.zoom
		_at = panel.at
		_dread = panel.dread
	match panel.shot:
		"bump":
			_play(SFX_BUMP)
		"zap":
			_play(SFX_ZAP)
			_flash = 1.0
		"shotgun":
			_play(SFX_BLAST)
		"fall":
			_play(SFX_WHOOSH)


func _play(stream: AudioStream) -> void:
	_sfx.stream = stream
	_sfx.play()


func _ready_to_turn() -> bool:
	return _typed and _shown_for > MIN_HOLD and _t >= PANELS[_index].act and not _busy


func _process(delta: float) -> void:
	if not visible:
		return
	# Keep the game frozen even if a menu unpauses it under us.
	if not get_tree().paused:
		get_tree().paused = true
	_flash = maxf(_flash - delta * 2.5, 0.0)
	if _index >= 0 and _index < PANELS.size():
		var panel: Dictionary = PANELS[_index]
		_t += delta
		# Ease the camera and sky toward this panel's framing.
		var ease := 1.0 - exp(-delta * 5.0)
		_zoom = lerpf(_zoom, panel.zoom, ease)
		_at = _at.lerp(panel.at, ease)
		_dread = lerpf(_dread, panel.dread, ease)
		if not _typed:
			_text.visible_ratio = minf(_t / maxf(_text.text.length() * TYPE_SPEED, 0.2), 1.0)
			_typed = _text.visible_ratio >= 1.0
		else:
			_shown_for += delta
			_prompt.visible = _ready_to_turn()
			_prompt.modulate.a = 0.55 + 0.45 * sin(_shown_for * 5.0)
			if _ready_to_turn() and _shown_for > AUTO_HOLD:
				_next()
	_stage.scale = Vector2(_zoom, _zoom)
	_stage.position = Vector2(640, 360) - _at * S * _zoom
	_stage.queue_redraw()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	get_viewport().set_input_as_handled()
	var pressed: bool = (event is InputEventMouseButton and event.pressed) \
		or (event is InputEventKey and event.pressed and not event.echo \
			and event.keycode != KEY_ESCAPE)
	if not pressed or _busy or _index < 0 or _index >= PANELS.size():
		return
	if not _typed:
		# Finish the line; the animation keeps its own clock.
		_text.visible_ratio = 1.0
		_typed = true
	elif _ready_to_turn():
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
			# Ends where the next panel picks him up.
			_village(_dread)
			var k := minf(_t / 2.6, 1.0)
			_guy(lerpf(10.0, 70.0, k), walk if k < 1.0 else 0, false)
		"walk_on":
			# They walk into each other: ends at the bump positions.
			_village(_dread)
			var k := minf(_t / 3.0, 1.0)
			var step := walk if k < 1.0 else 0
			_guy(lerpf(70.0, 120.0, k), step, false)
			_witch(lerpf(240.0, 138.0, k), step, false, false)
		"bump":
			# Knocked back a step, to where they stand for the argument.
			_village(_dread)
			var push := minf(_t / 0.25, 1.0) * 4.0
			_guy(120.0 - push, 0, false)
			_witch(138.0 + push, 0, false, false)
			if _t < 1.2:
				_burst(Vector2(129, 102), 9.0 * minf(_t / 0.1, 1.0))
		"guy_mad":
			_village(_dread)
			_guy(116.0, 0, true)
			_witch(142.0, 0, false, false)
			_steam(Vector2(116, 84))
		"witch_mad":
			_village(_dread)
			_guy(116.0, 0, true)
			_witch(142.0, 0, true, false)
			_steam(Vector2(142, 82))
		"hat":
			_village(_dread)
			_guy(116.0, 0, false)
			_witch(142.0, 0, true, false)
			_steam(Vector2(142, 82))
		"wand_up":
			_village(_dread)
			_guy(116.0, 0, false)
			_witch(142.0, 0, true, true)
			var glow := minf(_t / 0.6, 1.0)
			_stage.draw_circle(_p(Vector2(128, 88)), (6.0 + sin(_t * 9.0) * 2.0) * glow * S, Color(MAGIC, 0.25))
		"zap":
			_village(_dread)
			_witch(142.0, 0, true, true)
			if _t < 0.8:
				_zap(Vector2(128, 88), Vector2(116, 100))
			_guy_glow(116.0, clampf(1.0 - (_t - 0.6) / 0.4, 0.0, 1.0))
			if _t > 0.6:
				_smoke(Vector2(116, 110), _t - 0.6)
				_gun(Vector2(116, GROUND - 4), 0.0, 0.5)
		"shotgun":
			# Picks up right where the zap left him: same spot, same smoke.
			_village(_dread)
			_witch(142.0, 0, false, false)
			_smoke(Vector2(116, 110), _t + 0.4)
			var hop := absf(sin(_t * 7.0)) * minf(_t / 0.4, 1.0)
			var x := 116.0 - sin(_t * 1.6) * 14.0
			_gun(Vector2(x, GROUND - 4 - hop * 16.0), sin(_t * 7.0) * 0.35, 0.5)
		"carry":
			_castle()
			var k := minf(_t / 3.0, 1.0)
			var wx := lerpf(30.0, 110.0, k)
			_witch(wx, int(_t * 5.0) % 2 if k < 1.0 else 0, false, false, true)
			# Dangling from her hand by the barrel, wriggling.
			_gun(Vector2(wx + 10, GROUND - 6), PI * 0.5 + sin(_t * 9.0) * 0.4, 0.5)
		"throw":
			# Starts from the hand he was dangling from.
			_castle()
			_witch(110.0, 0, false, _t > 0.15, true)
			var k := clampf((_t - 0.15) / 1.0, 0.0, 1.0)
			var from := Vector2(120, GROUND - 6)
			var to := Vector2(176, GROUND - 4)
			var pos := from.lerp(to, k) + Vector2(0, -sin(k * PI) * 34.0)
			if k < 1.0:
				_gun(pos, PI * 0.5 + k * 14.0, 0.5)
			elif _t < 2.4:
				_word("CLANG!", Vector2(176, 100), 16, Color.WHITE)
		"fall":
			_shaft()
	_stage.draw_set_transform(Vector2.ZERO)
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
	# The very same stetson the shotgun wears in the game.
	var hat := Vector2(STETSON.get_size()) * 0.5
	_stage.draw_texture_rect(STETSON, Rect2(_p(Vector2(x - hat.x * 0.5, g - 26 - hat.y + 2)), hat * S), false)


## Mrs. Sandwitch faces left.
func _witch(x: float, frame: int, mad: bool, wand_up: bool, face_right := false) -> void:
	if face_right:
		# Mirror her around x so she can walk toward the castle.
		_stage.draw_set_transform(Vector2(2.0 * x * S, 0), 0.0, Vector2(-1, 1))
		_witch(x, frame, mad, wand_up)
		_stage.draw_set_transform(Vector2.ZERO)
		return
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
	# Pointy witch hat.
	_px(x - 7, g - 27, 14, 2, HAIR)
	_poly([Vector2(x - 4, g - 27), Vector2(x + 4, g - 27), Vector2(x + 3, g - 37)], HAIR)
	_px(x - 4, g - 29, 8, 2, Color("7a3a9a"))


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


func _guy_glow(x: float, strength: float) -> void:
	if strength <= 0.0:
		return
	var c := Vector2(x, GROUND - 14)
	_stage.draw_circle(_p(c), (14.0 + sin(_t * 18.0) * 2.0) * S, Color(MAGIC, 0.35 * strength))
	_stage.draw_circle(_p(c), 9.0 * S, Color(1, 1, 1, 0.8 * strength))
	for i in 8:
		var a := i * TAU / 8.0 + _t * 3.0
		_star(c + Vector2.from_angle(a) * (16.0 + fmod(_t * 8.0, 6.0)), 1.5 * strength)


## A puff of smoke `age` seconds old, spreading and fading out.
func _smoke(c: Vector2, age: float) -> void:
	var alpha := clampf(1.0 - age / 2.5, 0.0, 0.7)
	if alpha <= 0.0:
		return
	for i in 6:
		var a := i * TAU / 6.0
		var r := 8.0 + age * 6.0
		_stage.draw_circle(_p(c + Vector2.from_angle(a) * r * Vector2(1.4, 0.6)), 5.0 * S, Color(0.75, 0.7, 0.8, alpha))


## The hatted shotgun at art position `c`, turned by `angle`, `scale` art px per texel.
func _gun(c: Vector2, angle: float, scale: float) -> void:
	var size := Vector2(SHOTGUN.get_size()) * scale * S
	_stage.draw_set_transform(_p(c), angle)
	_stage.draw_texture_rect(SHOTGUN, Rect2(-size * 0.5, size), false)
	_stage.draw_set_transform(Vector2.ZERO)


## Her castle at nightfall, with the cellar grate at the foot of the wall.
func _castle() -> void:
	for i in SKY.size():
		_px(0, i * 16, 256, 16, SKY[i].lerp(Color("1c1030"), 0.55))
	_stage.draw_circle(_p(Vector2(40, 70)), 10 * S, Color("e8d8b0"))
	_poly([Vector2(0, 96), Vector2(60, 88), Vector2(130, 94), Vector2(256, 86), Vector2(256, 110), Vector2(0, 110)], HILL)
	var stone := Color("2e2440")
	var trim := Color("40345a")
	_px(140, 60, 116, 46, stone)
	for i in 12:
		_px(140 + i * 10, 56, 6, 4, stone)
	_px(196, 34, 30, 72, trim.darkened(0.2))          # the tower, going up out of frame
	for i in 3:
		_px(207, 44 + i * 14, 8, 8, Color("ffd27a") if i != 1 else Color("120a18"))
	_px(150, 70, 6, 8, Color("ffd27a"))
	_px(236, 70, 6, 8, Color("ffd27a"))
	_px(160, 84, 20, 22, Color("120a18"))             # main gate
	_poly([Vector2(160, 84), Vector2(170, 78), Vector2(180, 84)], Color("120a18"))
	_px(0, 106, 256, 38, GROUND_C)
	_px(0, 110, 256, 12, PATH_C)
	# Cellar grate, low in the wall.
	_px(170, 110, 14, 6, Color("0a0610"))
	for i in 4:
		_px(171 + i * 4, 110, 1, 6, Color("6a6070"))


## Falling down the dark cellar shaft, walls rushing past.
func _shaft() -> void:
	_px(0, 0, 256, 144, Color("0d0812"))
	var scroll := fmod(_t * 160.0, 16.0)
	for side in [0.0, 196.0]:
		_px(side, 0, 60, 144, Color("241c2e"))
		for row in 11:
			var y := row * 16.0 - scroll
			_px(side, y, 60, 1, Color("120c18"))
			_px(side + (20.0 if row % 2 == 0 else 40.0), y, 1, 16, Color("120c18"))
	for i in 8:
		var x := 80.0 + fmod(i * 37.0, 96.0)
		var y := fmod(i * 53.0 - _t * 220.0, 160.0)
		if y < 0: y += 160.0
		_px(x, y, 1, 10, Color(1, 1, 1, 0.25))
	_gun(Vector2(128, 88 + sin(_t * 3.0) * 4.0), _t * 5.0, 0.8)

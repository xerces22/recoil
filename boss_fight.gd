class_name BossFight
extends CanvasLayer
## The final fight at the top of the tower, played on its own screen.
## Phase 1: the gun is locked in the middle and aims at the mouse. Mrs. Sandwitch flies around
## with her hex orb; every hit cracks it. One crack from breaking, she swoops in, grabs it and
## taunts you. Phase 2: shoot the orb in her hand. The curse rebounds, she turns into a shotgun
## and recoils off screen. End card, then back to the menu.

signal finished

const FONT := preload("res://assets/fonts/PressStart2P-Regular.ttf")
const SHOTGUN := preload("res://assets/sprites/player/shotgun_main.png")
const STETSON := preload("res://assets/sprites/player/stetson.png")
const STETSON_OFFSET := Vector2(4, -13)
const BLASTS: Array[AudioStream] = [
	preload("res://assets/sfx/shotgun_blast_mossberg_1.wav"),
	preload("res://assets/sfx/shotgun_blast_mossberg_2.wav"),
	preload("res://assets/sfx/shotgun_blast_model12_1.wav"),
]
const SFX_RELOAD := preload("res://assets/sfx/shotgun_reload.wav")
const SFX_CRACK := preload("res://assets/sfx/spike_break.ogg")
const SFX_ZAP := preload("res://assets/sfx/portal.wav")
const SFX_WHOOSH := preload("res://assets/sfx/fall_wind_loop.ogg")

const S := 5.0                        # screen pixels per art pixel, same as the storyboard
const GUN_POS := Vector2(640, 470)
const GUN_SCALE := 4.0
const ORB_R := 26.0
const CRACKS_TO_SWOOP := 4
const COOLDOWN := 0.55

const DARK := Color("1a1220")
const CREAM := Color("f6e8cb")
const ACCENT := Color("57e08f")
const WITCH_SKIN := Color("8cbf5f")
const ROBE := Color("5b2a78")
const ROBE_DARK := Color("3c1a52")
const HAIR := Color("17101c")
const ORB := Color("b46cff")

enum Phase { INTRO, FIGHT, SWOOP, TAUNT, FINISH, REBOUND, END }

const INTRO_LINES: Array[String] = [
	"So the little boomstick climbed my whole tower.",
	"Cute. My orb says otherwise.",
]
const TAUNT_LINES: Array[String] = [
	"Ha! Did you really think this would be a walk in the park?",
	"Without this orb you're a gun on the floor forever.",
	"Go on, aim at it. I DARE you.",
]
const OUCH: Array[String] = ["Hey!", "Watch the orb!", "Stop that!", "You'll crack it!"]

var game
var _phase := Phase.INTRO
var _t := 0.0
var _phase_t := 0.0
var _lines: Array[String] = []
var _line := 0
var _typed := 0.0
var _aim := Vector2.RIGHT
var _cool := 0.0
var _kick := 0.0
var _flash := 0.0
var _shot_to := Vector2.ZERO
var _shot_t := 0.0
var _cracks := 0
var _orb_flash := 0.0
var _shake := 0.0
var _bark := ""
var _bark_t := 0.0
var _witch := Vector2(640, 180)
var _orb := Vector2(700, 190)
var _orb_held := false
var _swoop_from := Vector2.ZERO
var _shards: Array[Dictionary] = []
var _cursed_gun := Vector2.ZERO
var _cursed_spin := 0.0
var _white := 0.0
var _stars: Array[Vector2] = []
var _sfx: Array[AudioStreamPlayer] = []
var _canvas: Control


func _ready() -> void:
	layer = 25
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in 60:
		_stars.append(Vector2(rng.randf_range(0, 1280), rng.randf_range(0, 420)))
	for i in 4:
		var p := AudioStreamPlayer.new()
		p.bus = &"SFX"
		add_child(p)
		_sfx.append(p)
	_canvas = Control.new()
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_canvas.draw.connect(_draw_all)
	add_child(_canvas)
	_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_say(INTRO_LINES)


func _play(stream: AudioStream, volume := -6.0, pitch := 1.0) -> void:
	for p in _sfx:
		if not p.playing:
			p.stream = stream
			p.volume_db = volume
			p.pitch_scale = pitch
			p.play()
			return
	_sfx[0].stream = stream
	_sfx[0].play()


func _say(lines: Array[String]) -> void:
	_lines = lines
	_line = 0
	_typed = 0.0


func _talking() -> bool:
	return _line < _lines.size()


# ---------------------------------------------------------------- input

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return
	get_viewport().set_input_as_handled()
	if _talking():
		var full := _lines[_line].length()
		if _typed < full:
			_typed = full
		else:
			_line += 1
			_typed = 0.0
			if not _talking():
				_on_lines_done()
		return
	match _phase:
		Phase.FIGHT, Phase.FINISH:
			_fire()
		Phase.END:
			if _phase_t > 1.0:
				_phase = Phase.REBOUND  # stop further clicks
				finished.emit()


func _on_lines_done() -> void:
	match _phase:
		Phase.INTRO:
			_set_phase(Phase.FIGHT)
		Phase.TAUNT:
			_set_phase(Phase.FINISH)


func _set_phase(p: Phase) -> void:
	_phase = p
	_phase_t = 0.0


func _fire() -> void:
	if _cool > 0.0:
		return
	_cool = COOLDOWN
	_kick = 1.0
	_flash = 0.08
	_shake = maxf(_shake, 6.0)
	_play(BLASTS.pick_random(), -8.0, randf_range(0.95, 1.05))
	get_tree().create_timer(0.3).timeout.connect(_play.bind(SFX_RELOAD, -16.0))
	var muzzle := GUN_POS + _aim * 150.0
	var to_orb := _orb - muzzle
	var along := to_orb.dot(_aim)
	var miss := absf(to_orb.cross(_aim))
	var hit := along > -40.0 and miss < ORB_R + 14.0
	_shot_to = _orb if hit else GUN_POS + _aim * 1600.0
	_shot_t = 0.1
	if not hit:
		return
	_orb_flash = 0.25
	_play(SFX_CRACK, -4.0, 1.1 + _cracks * 0.08)
	_spawn_shards(_orb, 6)
	if _phase == Phase.FINISH:
		_start_rebound()
		return
	_cracks += 1
	if _cracks >= CRACKS_TO_SWOOP:
		_swoop_from = _witch
		_set_phase(Phase.SWOOP)
		_play(SFX_WHOOSH, -10.0, 1.4)
	else:
		_bark = OUCH[(_cracks - 1) % OUCH.size()]
		_bark_t = 1.2


func _start_rebound() -> void:
	_set_phase(Phase.REBOUND)
	_cracks = 5
	_spawn_shards(_orb, 22)
	_play(SFX_ZAP, -4.0, 0.8)
	_shake = 14.0


func _spawn_shards(at: Vector2, count: int) -> void:
	for i in count:
		_shards.append({
			"pos": at,
			"vel": Vector2.from_angle(randf() * TAU) * randf_range(120.0, 420.0),
			"life": randf_range(0.5, 1.1),
			"size": randf_range(3.0, 7.0),
		})


# ---------------------------------------------------------------- update

func _process(delta: float) -> void:
	_t += delta
	_phase_t += delta
	_cool = maxf(0.0, _cool - delta)
	_kick = maxf(0.0, _kick - delta * 6.0)
	_flash = maxf(0.0, _flash - delta)
	_shot_t = maxf(0.0, _shot_t - delta)
	_orb_flash = maxf(0.0, _orb_flash - delta)
	_shake = maxf(0.0, _shake - delta * 30.0)
	_bark_t = maxf(0.0, _bark_t - delta)
	_white = maxf(0.0, _white - delta * 1.2)
	if _talking():
		_typed = minf(_typed + delta * 40.0, _lines[_line].length())

	var mouse := _canvas.get_local_mouse_position()
	var want := (mouse - GUN_POS).normalized()
	if want != Vector2.ZERO and _phase in [Phase.FIGHT, Phase.FINISH, Phase.INTRO, Phase.TAUNT, Phase.SWOOP]:
		_aim = Vector2.from_angle(rotate_toward(_aim.angle(), want.angle(), delta * 10.0))

	match _phase:
		Phase.INTRO:
			_witch = _witch.lerp(Vector2(640, 170), delta * 2.0)
			_orb = _witch + Vector2(70, 10 + sin(_t * 2.0) * 8.0)
		Phase.FIGHT:
			# Faster and wider as the orb cracks.
			var speed := 0.6 + _cracks * 0.12
			var k := _phase_t * speed
			_witch = Vector2(640 + sin(k) * 400.0, 190 + sin(k * 2.1) * 90.0)
			_orb = _witch + Vector2.from_angle(_t * (1.5 + _cracks * 0.3)) * 90.0
		Phase.SWOOP:
			# She dives to the orb, grabs it and settles in front of you.
			var k := minf(_phase_t / 0.9, 1.0)
			if k < 0.5:
				_witch = _swoop_from.lerp(_orb, k * 2.0)
			else:
				_orb_held = true
				_witch = _witch.lerp(Vector2(640, 200), delta * 6.0)
			if _orb_held:
				_orb = _witch + Vector2(-46, 18)
			if _phase_t > 1.3:
				_set_phase(Phase.TAUNT)
				_say(TAUNT_LINES)
		Phase.TAUNT, Phase.FINISH:
			var drift := 120.0 if _phase == Phase.FINISH else 30.0
			_witch = Vector2(640 + sin(_phase_t * 0.9) * drift, 200 + sin(_phase_t * 1.7) * 20.0)
			_orb = _witch + Vector2(-46, 18 + sin(_t * 3.0) * 3.0)
		Phase.REBOUND:
			_update_rebound(delta)
		Phase.END:
			pass

	for shard in _shards:
		shard.pos += shard.vel * delta
		shard.vel *= 0.96
		shard.life -= delta
	_shards = _shards.filter(func(s: Dictionary) -> bool: return s.life > 0.0)
	_canvas.queue_redraw()


func _update_rebound(_delta: float) -> void:
	# 0.0-0.9  green curse bolt flies from the orb back into her
	# 0.9      white flash: she is now a shotgun
	# 1.3-3.0  the cursed shotgun fires once and recoils away, spinning
	if _phase_t > 0.9 and _cursed_gun == Vector2.ZERO:
		_white = 1.0
		_cursed_gun = _witch
		_play(BLASTS[0], -2.0, 0.7)
		_shake = 18.0
	if _cursed_gun != Vector2.ZERO and _phase_t > 1.3:
		var k := _phase_t - 1.3
		_cursed_gun = _witch + Vector2(k * k * 260.0, -k * k * 200.0)
		_cursed_spin = k * k * 9.0
	if _phase_t > 3.6:
		_set_phase(Phase.END)


# ---------------------------------------------------------------- drawing

func _draw_all() -> void:
	var c := _canvas
	var shake := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake
	c.draw_set_transform(shake)
	_draw_sky(c)
	if _phase != Phase.END:
		_draw_witch_or_gun(c)
		if not (_phase == Phase.REBOUND and _phase_t > 0.9):
			_draw_orb(c, _orb)
		if _phase == Phase.REBOUND and _phase_t < 0.95:
			_draw_bolt(c, _orb, _witch, _phase_t / 0.9)
		_draw_shards(c)
		_draw_shot(c)
		_draw_player_gun(c)
	c.draw_set_transform(Vector2.ZERO)
	_draw_hud(c)
	if _white > 0.0:
		c.draw_rect(Rect2(0, 0, 1280, 720), Color(1, 1, 1, _white))
	if _phase == Phase.END:
		_draw_end(c)


func _draw_sky(c: Control) -> void:
	var top := Color("0b0512")
	var low := Color("2a1140")
	c.draw_polygon(PackedVector2Array([Vector2(-40, -40), Vector2(1320, -40), Vector2(1320, 760), Vector2(-40, 760)]),
		PackedColorArray([top, top, low, low]))
	for i in _stars.size():
		var tw := 0.5 + 0.5 * sin(_t * 2.0 + i)
		c.draw_rect(Rect2(_stars[i].round(), Vector2(3, 3)), Color(1, 1, 1, 0.25 + tw * 0.4))
	# Moon.
	c.draw_circle(Vector2(1080, 120), 70, Color("f3e9c8"))
	c.draw_circle(Vector2(1052, 102), 70, Color("2a1140", 0.0))
	c.draw_circle(Vector2(1100, 140), 14, Color("d9cda8"))
	c.draw_circle(Vector2(1060, 96), 9, Color("d9cda8"))
	# Tower top: crenellated stone wall along the bottom.
	var wall_y := 560.0
	c.draw_rect(Rect2(-40, wall_y, 1360, 200), Color("2b2233"))
	for x in range(-40, 1320, 120):
		c.draw_rect(Rect2(x, wall_y - 50, 70, 50), Color("2b2233"))
		c.draw_rect(Rect2(x, wall_y - 50, 70, 6), Color("3d3247"))
	c.draw_rect(Rect2(-40, wall_y, 1360, 6), Color("3d3247"))
	for y in range(int(wall_y) + 30, 720, 40):
		for x in range(-40 + (y / 40 % 2) * 60, 1320, 120):
			c.draw_rect(Rect2(x, y, 2, 40), Color("1d1724"))
		c.draw_rect(Rect2(-40, y, 1360, 2), Color("1d1724"))


func _px(c: Control, origin: Vector2, x: float, y: float, w: float, h: float, col: Color) -> void:
	c.draw_rect(Rect2(origin + Vector2(x, y) * S, Vector2(w, h) * S), col)


## Mrs. Sandwitch flying on her broom, centred on `at`. During the rebound she becomes a shotgun.
func _draw_witch_or_gun(c: Control) -> void:
	if _phase == Phase.REBOUND and _phase_t > 0.9:
		_draw_cursed_gun(c)
		return
	var at := _witch.round()
	var face := -1.0 if (_phase == Phase.FIGHT and cos(_phase_t * (0.6 + _cracks * 0.12)) < 0.0) else 1.0
	c.draw_set_transform(at + Vector2(randf_range(-1, 1), 0) * _shake, 0.0, Vector2(face, 1))
	var o := Vector2.ZERO
	var mad := _cracks >= 2 or _phase in [Phase.TAUNT, Phase.FINISH]
	# Broom.
	_px(c, o, -14, 6, 26, 2, Color("6b4423"))
	_px(c, o, 12, 4, 6, 6, Color("c9a24a"))
	# Robe sitting on the broom.
	c.draw_colored_polygon(PackedVector2Array([o + Vector2(-4, -12) * S, o + Vector2(4, -12) * S,
		o + Vector2(8, 7) * S, o + Vector2(-8, 7) * S]), ROBE)
	_px(c, o, -8, 5, 16, 2, ROBE_DARK)
	# Head, hair, nose and eye.
	var skin := WITCH_SKIN.lerp(Color("c46a4a"), 0.45) if mad else WITCH_SKIN
	_px(c, o, 1, -19, 4, 12, HAIR)
	_px(c, o, -3, -19, 5, 7, skin)
	_px(c, o, -5, -16, 2, 2, skin)
	_px(c, o, -5, -15, 1, 1, Color("5a7a3a"))
	_px(c, o, -2, -17, 1, 1, Color("ff3030") if mad else DARK)
	if mad:
		_px(c, o, -2, -18, 2, 1, DARK)
	# Arm reaching for / holding the orb.
	_px(c, o, -7, -9, 4, 2, ROBE)
	# Pointy hat.
	_px(c, o, -7, -20, 14, 2, HAIR)
	c.draw_colored_polygon(PackedVector2Array([o + Vector2(-4, -20) * S, o + Vector2(4, -20) * S,
		o + Vector2(3, -31) * S]), HAIR)
	_px(c, o, -4, -22, 8, 2, Color("7a3a9a"))
	c.draw_set_transform(Vector2.ZERO)


## The witch, cursed into a shotgun: purple-tinted gun wearing her pointy hat, recoiling away.
func _draw_cursed_gun(c: Control) -> void:
	c.draw_set_transform(_cursed_gun.round(), _cursed_spin, Vector2.ONE * GUN_SCALE)
	var half := SHOTGUN.get_size() / 2.0
	c.draw_texture(SHOTGUN, -half, Color(0.85, 0.7, 1.0))
	c.draw_colored_polygon(PackedVector2Array([Vector2(-10, -7), Vector2(2, -7), Vector2(-2, -20)]), HAIR)
	c.draw_rect(Rect2(-12, -8, 16, 2), HAIR)
	c.draw_rect(Rect2(-8, -10, 8, 2), Color("7a3a9a"))
	c.draw_set_transform(Vector2.ZERO)
	if _phase_t < 1.6:
		c.draw_string(FONT, _witch + Vector2(-40, -70), "...!?", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, CREAM)


func _draw_orb(c: Control, at: Vector2) -> void:
	var glow := ORB if _orb_flash <= 0.0 else Color.WHITE
	for ring in 3:
		c.draw_circle(at, ORB_R + 10 + ring * 8, Color(ORB, 0.08))
	c.draw_circle(at, ORB_R, glow.darkened(0.25))
	c.draw_circle(at - Vector2(7, 7), ORB_R * 0.45, glow.lightened(0.35))
	# Cracks: jagged lines, one more per hit.
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in mini(_cracks, CRACKS_TO_SWOOP + 1):
		var a := rng.randf_range(0.0, TAU)
		var p := at
		for seg in 3:
			var nxt := p + Vector2.from_angle(a + rng.randf_range(-0.7, 0.7)) * (ORB_R / 3.0)
			c.draw_line(p, nxt, DARK, 3.0)
			p = nxt


func _draw_bolt(c: Control, from: Vector2, to: Vector2, k: float) -> void:
	var head := from.lerp(to, clampf(k, 0.0, 1.0))
	var points := PackedVector2Array()
	for i in 9:
		var t := i / 8.0
		var p := from.lerp(head, t)
		if i > 0 and i < 8:
			p += Vector2(randf_range(-10, 10), randf_range(-10, 10))
		points.append(p)
	c.draw_polyline(points, Color(ACCENT, 0.4), 14.0)
	c.draw_polyline(points, ACCENT, 5.0)
	c.draw_polyline(points, Color.WHITE, 2.0)


func _draw_shards(c: Control) -> void:
	for s in _shards:
		var a: float = clampf(s.life, 0.0, 1.0)
		c.draw_rect(Rect2(s.pos, Vector2(s.size, s.size)), Color(ORB.lightened(0.3), a))


func _draw_shot(c: Control) -> void:
	if _shot_t <= 0.0:
		return
	var from := GUN_POS + _aim * 150.0
	for spread in [-0.03, 0.0, 0.03]:
		var to: Vector2 = from + (_shot_to - from).rotated(spread)
		c.draw_line(from, to, Color(1.0, 0.85, 0.5, _shot_t * 8.0), 3.0)


func _draw_player_gun(c: Control) -> void:
	var flip := -1.0 if _aim.x < 0.0 else 1.0
	var pos := GUN_POS - _aim * _kick * 18.0
	c.draw_set_transform(pos.round(), _aim.angle(), Vector2(GUN_SCALE, GUN_SCALE * flip))
	var pivot := Vector2(20, 7)
	c.draw_texture(SHOTGUN, -pivot)
	c.draw_texture(STETSON, STETSON_OFFSET - pivot)
	if _flash > 0.0:
		var tip := Vector2(SHOTGUN.get_width() - pivot.x + 4.0, -2.0)
		c.draw_circle(tip, 7.0, Color(1.0, 0.6, 0.2, 0.9))
		c.draw_circle(tip, 4.0, Color(1.0, 0.95, 0.7))
	c.draw_set_transform(Vector2.ZERO)


func _draw_hud(c: Control) -> void:
	# Orb health: five pips, top centre.
	if _phase in [Phase.FIGHT, Phase.SWOOP, Phase.TAUNT, Phase.FINISH]:
		c.draw_string(FONT, Vector2(500, 44), "HEX ORB", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, CREAM)
		for i in 5:
			var col := Color("3a2b48") if i < _cracks else ORB
			c.draw_rect(Rect2(620 + i * 30, 30, 22, 16), col)
	if _phase == Phase.FINISH:
		var a := 0.6 + 0.4 * sin(_t * 6.0)
		_center_text(c, "SHOOT THE ORB IN HER HAND!", 640, 660, 18, Color(ACCENT, a))
	elif _phase == Phase.FIGHT and _phase_t < 4.0:
		_center_text(c, "AIM WITH THE MOUSE. CLICK TO SHOOT THE ORB.", 640, 660, 12, CREAM)
	if _bark_t > 0.0 and _phase == Phase.FIGHT:
		c.draw_string(FONT, Vector2(_witch.x - 40, maxf(_witch.y - 170, 90)), _bark, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(CREAM, minf(_bark_t * 2.0, 1.0)))
	if _talking():
		var box := Rect2(140, 590, 1000, 100)
		c.draw_rect(box, Color("170b22", 0.95))
		c.draw_rect(box, Color("3a2b48"), false, 3.0)
		c.draw_rect(Rect2(box.position + Vector2(3, 3), Vector2(box.size.x - 6, 3)), ACCENT)
		c.draw_string(FONT, box.position + Vector2(24, 30), "MRS. SANDWITCH", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, ACCENT)
		var text := _lines[_line].substr(0, int(_typed))
		c.draw_string(FONT, box.position + Vector2(24, 62), text, HORIZONTAL_ALIGNMENT_LEFT, box.size.x - 48, 13, CREAM)
		if _typed >= _lines[_line].length() and fmod(_t, 0.8) < 0.5:
			c.draw_string(FONT, box.end - Vector2(40, 16), ">", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, ACCENT)


func _draw_end(c: Control) -> void:
	var a := clampf(_phase_t / 0.8, 0.0, 1.0)
	c.draw_rect(Rect2(0, 0, 1280, 720), Color(0.04, 0.02, 0.06, a))
	_center_text(c, "THE CURSE REBOUNDS.", 640, 250, 26, Color(ACCENT, a))
	_center_text(c, "Mrs. Sandwitch is a shotgun now.", 640, 320, 14, Color(CREAM, a))
	_center_text(c, "Guns can't walk. She'll figure it out.", 640, 356, 14, Color(CREAM, a))
	_center_text(c, "THANKS FOR PLAYING CURSED SHOTGUN", 640, 450, 16, Color(Color("ffd583"), a))
	if _phase_t > 1.0 and fmod(_t, 1.0) < 0.65:
		_center_text(c, "Click to return to the menu", 640, 560, 11, Color(Color("bdb0c7"), a))


func _center_text(c: Control, text: String, x: float, y: float, size: int, col: Color) -> void:
	var w := FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	c.draw_string(FONT, Vector2(x - w / 2.0, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)

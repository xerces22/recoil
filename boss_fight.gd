class_name BossFight
extends CanvasLayer
## The final fight at the top of the tower, played on its own screen.
## Phase 1: the gun is locked in the middle and aims at the mouse. Mrs. Sandwitch flies around
## with her hex orb; every hit cracks it. One crack from breaking, she swoops in, grabs it and
## taunts you. Phase 2: shoot the orb in her hand. The curse rebounds, she turns into a shotgun
## and recoils off screen. End card, then back to the menu.

signal finished
## Out of shells. `retry` true: start the fight again; false: back to the menu.
signal lost(retry: bool)
## The orb broke: the fight is beaten (sent before the ending plays).
signal won

const FONT := preload("res://assets/fonts/PressStart2P-Regular.ttf")
const SHOTGUN := preload("res://assets/sprites/player/shotgun_main.png")
const STETSON := preload("res://assets/sprites/player/stetson.png")
const STETSON_OFFSET := Vector2(4, -13)
## Mrs. Sandwitch's hat, cut from the Whimsy Hallow witch (tools/cut_witch_hat.py).
const WITCH_HAT := preload("res://assets/sprites/boss/witch_hat.png")
## Top-left of the hat in her art pixels, so the brim sits on her head (top of head is y = -19).
const HAT_OFFSET := Vector2(-9, -26)
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
const GUN_POS := Vector2(640, 505)
const GUN_SCALE := 4.0
const ORB_R := 34.0
const CRACKS_TO_SWOOP := 7
const COOLDOWN := 0.7

## Teleport fight, osu-style. Each cycle: HOVER (orb shielded) -> WARN (pixel chevrons march
## toward where she's going) -> SINK (the shotgun's death portal swallows her) -> TRANSIT (gone)
## -> OPEN (she's thrown out of a portal at the exit; the orb is open for one short beat).
## An approach ring shrinks onto her exit and closes exactly when she lands: be there with a shell.
enum Tp { HOVER, WARN, SINK, TRANSIT, OPEN }
const TP_HOVER := 0.7
const TP_SINK := 0.3
const TP_TRANSIT := 0.35
const TP_POP := 0.15
## (at 0 cracks, at the last crack) - a bit quicker with every hit, never frantic.
const TP_WARN := Vector2(1.0, 0.7)         # chevron time before she dives in
const TP_OPEN := Vector2(0.75, 0.55)       # how long the orb stays open after she lands
const TP_APPROACH := Vector2(1.3, 1.0)     # approach ring shows this long before she lands
## A shell that reaches her exit this close to her landing still counts: she flies into it.
const TP_GRACE := 0.2
## Where she can pop out, and how far each hop goes at least.
const ARENA := Rect2(190, 110, 900, 210)
const TP_MIN_HOP := 300.0
## She never comes closer than this to your gun.
const KEEP_AWAY := 330.0
## Portal size here (the player's is 34 px in a 2x world).
const PORTAL_R := 80.0
## One shell per shot, tumbling. Time slows while it flies.
const SHELL_SPEED := 1700.0
const SHELL_LIFE := 0.6
const SHELL_PX := 4.0
const SLOW_SCALE := 0.4
const HIT_R := ORB_R + 30.0
const SHIELD_R := HIT_R + 8.0
## A miss costs the shell and a short pump of the action.
const MISS_COOLDOWN := 0.35
## Shells for the whole fight: 4 cracks + the final shot = 5 needed.
const SHELLS := 10
const LOST_LINES: Array[String] = ["Out of shells? How embarrassing.", "Click, click. Ha!"]
const DEFLECT: Array[String] = ["Nope!", "Too slow, boomstick!", "Missed me!", "Shielded, dear."]

const DARK := Color("1a1220")
const CREAM := Color("f6e8cb")
const ACCENT := Color("57e08f")
const WITCH_SKIN := Color("8cbf5f")
const ROBE := Color("5b2a78")
const ROBE_DARK := Color("3c1a52")
const HAIR := Color("17101c")
const ORB := Color("b46cff")

enum Phase { INTRO, FIGHT, SWOOP, TAUNT, FINISH, REBOUND, END, LOST }

## The finale after the last hit (seconds into REBOUND):
## 0 .. BREAK_AT    black bars, slow zoom on the orb, cracks spread, light leaks out
## BREAK_AT         the orb bursts; shards fly in slow motion, the bottom half falls
## .. GUY_AT        the curse lifts off your gun in green wisps; flash: Mr. Guy is back
## .. HEX_AT        the curse flies into her; flash: she's a shotgun wearing her hat
## .. END_AT        she drops onto the wall and waddles off screen, then the end card
const BREAK_AT := 2.4
const GUY_AT := 3.9
const HEX_AT := 4.8
const END_AT := HEX_AT + 5.0
## Witch-gun after she turns: stunned hover, flip down onto the wall, lie there, then hop away.
const STUN_T := 0.6
const FALL_T := 0.55
const LIE_T := 0.6
const HOP_T := 0.42
const HOP_DX := 95.0
const HOP_H := 44.0
## Centre height of a gun lying on the wall top.
const GUN_REST_Y := 532.0
const SFX_THUD := preload("res://assets/sfx/impactWood_heavy_000.ogg")
const SFX_TAP := preload("res://assets/sfx/impactWood_light_001.ogg")
const BAR_H := 84.0
const SFX_SHINE := preload("res://assets/sfx/respawn_shine.ogg")
const SKIN := Color("eebf98")
const SHIRT := Color("a6403a")
const PANTS := Color("3a3150")
const BELT := Color("3f2719")
## Mr. Guy's feet, on top of the tower wall.
const GUY_FEET := Vector2(640, 560)

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
var _shells: Array[Dictionary] = []
var _ammo := SHELLS
## Set by main.gd when you retry: skip her opening lines.
var retry := false
var _lost_hover := -1
var _lost_sent := false
var _end_skip := false
var _end_sent := false
var _end_ticked := 0
var _pops: Array[Dictionary] = []    # judgement popups: PERFECT / GOOD / EARLY / LATE
var _witch_rot := 0.0
var _shine_t := -1.0
var _since_open := 99.0              # world time since the last open beat ended
var _ts := 1.0                 # world time scale (slow motion while pellets fly)
var _tp := Tp.HOVER
var _tp_t := 0.0
var _tp_from := Vector2.ZERO
var _tp_to := Vector2.ZERO
var _witch_sc := 1.0           # she shrinks into / grows out of portals
var _shield_flash := 0.0
var _deflects := 0
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
# Finale state.
var _bars := 0.0
var _zoom := 1.0
var _base := Transform2D.IDENTITY
var _next_tick := 0.0
var _broken := false
var _is_guy := false
var _shell := Vector2.ZERO
var _shell_v := Vector2.ZERO
var _wisps: Array[Dictionary] = []
var _crack_paths: Array[PackedVector2Array] = []
var _waddle_dir := 1.0
var _land := Vector2.ZERO
var _landed := false
var _hops := -1
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
	if retry:
		_set_phase(Phase.FIGHT)
		_phase_t = 6.0  # hint already seen
	else:
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
		Phase.LOST:
			if _phase_t > 1.0 and _lost_hover >= 0 and not _lost_sent:
				_lost_sent = true
				lost.emit(_lost_hover == 0)
		Phase.END:
			if _end_typed() < _end_total():
				_end_skip = true  # first click finishes the typing
			elif not _end_sent:
				_end_sent = true
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
	if _ammo <= 0:
		_play(SFX_TAP, -10.0, 0.6)  # dry click
		_cool = 0.3
		return
	_ammo -= 1
	_cool = COOLDOWN
	_kick = 1.0
	_flash = 0.08
	_shake = maxf(_shake, 6.0)
	_play(BLASTS.pick_random(), -8.0, randf_range(0.8, 0.9))
	get_tree().create_timer(0.25).timeout.connect(_play.bind(SFX_RELOAD, -16.0))
	_shells.append({"pos": GUN_POS + _aim * 150.0, "vel": _aim * SHELL_SPEED, "life": SHELL_LIFE,
		"rot": _aim.angle(), "done": false})


## Moves the shells and judges them: a hit inside the open beat, otherwise EARLY or LATE.
func _update_shells(dt: float) -> void:
	for sh in _shells:
		sh.pos += sh.vel * dt
		sh.rot += dt * (30.0 if sh.done else 14.0)
		sh.life -= dt
		if not sh.done and sh.life <= 0.0 and _phase == Phase.FIGHT:
			_miss(sh, "MISS")  # whiffed into the sky: jams like any other miss
			continue
		if sh.done:
			sh.vel *= 0.9
			continue
		if _phase == Phase.FINISH:
			if sh.pos.distance_to(_orb) < HIT_R:
				sh.done = true
				_on_orb_hit()
			continue
		if _phase != Phase.FIGHT:
			continue
		# At her exit before she lands: right before landing she flies into it, otherwise early.
		if _tp in [Tp.SINK, Tp.TRANSIT] and sh.pos.distance_to(_exit_orb()) < HIT_R:
			if _until_land() <= TP_GRACE:
				_land_now()
				sh.done = true
				sh.life = 0.0
				_pop("HIT!", CREAM)
				_on_orb_hit()
			else:
				_miss(sh, "EARLY!")
			continue
		if not _orb_visible():
			continue
		var d: float = sh.pos.distance_to(_orb)
		if _tp == Tp.OPEN and d < HIT_R:
			sh.done = true
			sh.life = 0.0
			var open := lerpf(TP_OPEN.x, TP_OPEN.y, _difficulty())
			var perfect := _tp_t < open * 0.6
			_pop("BULLSEYE!" if perfect else "HIT!", ACCENT if perfect else CREAM)
			_on_orb_hit()
		elif _tp != Tp.OPEN and d < SHIELD_R:
			sh.vel = sh.vel.bounce((sh.pos - _orb).normalized()) * 0.4
			_shield_flash = 0.3
			_miss(sh, "LATE!" if _since_open < 0.5 else ("EARLY!" if _tp == Tp.WARN else "BLOCKED"))
	_shells = _shells.filter(func(sh: Dictionary) -> bool: return sh.life > 0.0)
	for p in _pops:
		p.life -= dt
		p.pos.y -= dt * 60.0
	_pops = _pops.filter(func(p: Dictionary) -> bool: return p.life > 0.0)


func _miss(sh: Dictionary, word: String) -> void:
	sh.done = true
	_cool = maxf(_cool, MISS_COOLDOWN)
	_pop(word, Color("ff6a5a"), sh.pos if word == "MISS" else Vector2.INF)
	_play(SFX_TAP, -8.0, 1.8)
	_bark = DEFLECT[_deflects % DEFLECT.size()]
	_deflects += 1
	_bark_t = 0.8


func _pop(word: String, col: Color, at := Vector2.INF) -> void:
	_pops.append({"text": word, "pos": (_orb if at == Vector2.INF else at) + Vector2(0, 90), "col": col, "life": 0.7})


func _orb_visible() -> bool:
	return _phase != Phase.FIGHT or _witch_sc > 0.5


## Orb sprite stage (0 whole .. 4 nearly broken, 5 shattered), spread over all the cracks.
func _orb_stage() -> int:
	if _phase == Phase.REBOUND:
		return _cracks
	return roundi(_cracks * 4.0 / CRACKS_TO_SWOOP)


## 0 at the first crack, 1 at the last one before she swoops.
func _difficulty() -> float:
	return clampf(_cracks / float(CRACKS_TO_SWOOP - 1), 0.0, 1.0)


## Where the orb will be once she lands at her exit.
func _exit_orb() -> Vector2:
	var face := 1.0 if _tp_to.x >= 640.0 else -1.0
	return _tp_to + Vector2(-62.0 * face, 16.0)


## World seconds until she lands at her exit (negative when she isn't on her way).
func _until_land() -> float:
	var k := _difficulty()
	match _tp:
		Tp.WARN:
			return lerpf(TP_WARN.x, TP_WARN.y, k) - _tp_t + TP_SINK + TP_TRANSIT
		Tp.SINK:
			return TP_SINK - _tp_t + TP_TRANSIT
		Tp.TRANSIT:
			return TP_TRANSIT - _tp_t
	return -1.0


## The teleport cycle during the fight. `dt` is world time (slowed while a shell flies).
func _update_teleport(dt: float) -> void:
	_tp_t += dt
	_since_open += dt
	var k := _difficulty()
	match _tp:
		Tp.HOVER:
			_witch_sc = 1.0
			_witch_rot = 0.0
			if _tp_t >= TP_HOVER:
				_tp_from = _witch
				_tp_to = _pick_spot(_witch)
				_tp_state(Tp.WARN)
		Tp.WARN:
			if _tp_t >= lerpf(TP_WARN.x, TP_WARN.y, k):
				_play(SFX_ZAP, -16.0, 1.5)
				_tp_state(Tp.SINK)
		Tp.SINK:
			# Spirals into the portal and shrinks, like the shotgun does when it dies.
			var u := _tp_t / TP_SINK
			_witch_sc = 1.0 - u
			_witch_rot = u * TAU * 1.2
			_witch = _tp_from + Vector2(sin(u * 12.0), cos(u * 12.0)) * 18.0 * u
			if _tp_t >= TP_SINK:
				_witch_sc = 0.0
				_tp_state(Tp.TRANSIT)
		Tp.TRANSIT:
			_witch_sc = 0.0
			if _tp_t >= TP_TRANSIT:
				_land_now()
		Tp.OPEN:
			# Thrown out of the exit portal with a little overshoot.
			var u := minf(1.0, _tp_t / TP_POP)
			_witch_sc = u + sin(u * PI) * 0.25
			if _tp_t >= lerpf(TP_OPEN.x, TP_OPEN.y, k):
				_since_open = 0.0
				_tp_state(Tp.HOVER)
	if _shine_t >= 0.0:
		_shine_t += dt / 0.4
		if _shine_t >= 1.0:
			_shine_t = -1.0
	# The orb sits in front of her.
	_orb = _witch + Vector2(-62.0 * _witch_face(), 16.0 + sin(_t * 3.0) * 4.0)


## She comes out of the exit portal (on time, or early when a shell meets her there).
func _land_now() -> void:
	_witch = _tp_to
	_witch_rot = 0.0
	_witch_sc = 1.0
	_shine_t = 0.0
	_orb = _exit_orb()
	_play(SFX_ZAP, -14.0, 1.8)
	_tp_state(Tp.OPEN)


func _tp_state(s: Tp) -> void:
	_tp = s
	_tp_t = 0.0


## Facing left (1) or right (-1): toward the middle of the screen.
func _witch_face() -> float:
	return 1.0 if _witch.x >= 640.0 else -1.0


func _pick_spot(from: Vector2) -> Vector2:
	for i in 30:
		var p := Vector2(randf_range(ARENA.position.x, ARENA.end.x), randf_range(ARENA.position.y, ARENA.end.y))
		if p.distance_to(from) >= TP_MIN_HOP and p.distance_to(GUN_POS) >= KEEP_AWAY:
			return p
	return Vector2(1280.0 - from.x, ARENA.get_center().y)


func _on_orb_hit() -> void:
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
		# She flinches and hops away sooner.
		_tp_state(Tp.HOVER)
		_tp_t = TP_HOVER * 0.5


func _start_rebound() -> void:
	won.emit()
	_set_phase(Phase.REBOUND)
	_cracks = 5
	_next_tick = 0.35
	_shake = 10.0
	_play(SFX_ZAP, -8.0, 0.6)
	# Cracks that creep out from the middle of the orb while it holds on.
	var rng := RandomNumberGenerator.new()
	rng.seed = 23
	_crack_paths.clear()
	for i in 7:
		var path := PackedVector2Array([Vector2.ZERO])
		var a := i * TAU / 7.0 + rng.randf_range(-0.3, 0.3)
		var p := Vector2.ZERO
		for seg in 5:
			p += Vector2.from_angle(a + rng.randf_range(-0.8, 0.8)) * 10.0
			path.append(p)
		_crack_paths.append(path)


func _spawn_shards(at: Vector2, count: int, big := false) -> void:
	for i in count:
		_shards.append({
			"pos": at + (Vector2.from_angle(randf() * TAU) * randf_range(0.0, 30.0) if big else Vector2.ZERO),
			"vel": Vector2.from_angle(randf() * TAU) * randf_range(120.0, 420.0) * (1.6 if big else 1.0),
			"life": randf_range(1.6, 2.6) if big else randf_range(0.5, 1.1),
			"size": randf_range(8.0, 18.0) if big else randf_range(3.0, 7.0),
			"rot": randf() * TAU,
			"spin": randf_range(-8.0, 8.0) if big else 0.0,
			"big": big,
		})


# ---------------------------------------------------------------- update

func _process(delta: float) -> void:
	# Slow motion while your pellets are in the air.
	var want_slow := _shells.any(func(sh: Dictionary) -> bool: return not sh.done) and _phase in [Phase.FIGHT, Phase.FINISH]
	_ts = move_toward(_ts, SLOW_SCALE if want_slow else 1.0, delta * (8.0 if want_slow else 4.0))
	var world_dt := delta * _ts
	_t += delta
	_phase_t += delta
	_cool = maxf(0.0, _cool - world_dt)
	_kick = maxf(0.0, _kick - delta * 6.0)
	_flash = maxf(0.0, _flash - delta)
	_shield_flash = maxf(0.0, _shield_flash - delta)
	_update_shells(world_dt)
	if _phase in [Phase.FIGHT, Phase.FINISH] and _ammo <= 0 and _shells.all(func(sh: Dictionary) -> bool: return sh.done):
		_set_phase(Phase.LOST)
		_bark = LOST_LINES.pick_random()
		_bark_t = 99.0
	_orb_flash = maxf(0.0, _orb_flash - delta)
	_shake = maxf(0.0, _shake - delta * 30.0)
	_bark_t = maxf(0.0, _bark_t - delta)
	_white = maxf(0.0, _white - delta * 1.2)
	if _talking():
		_typed = minf(_typed + delta * 40.0, _lines[_line].length())

	var mouse := _canvas.get_local_mouse_position()
	var want := (mouse - GUN_POS).normalized()
	if want != Vector2.ZERO and _phase in [Phase.FIGHT, Phase.FINISH, Phase.INTRO, Phase.TAUNT, Phase.SWOOP]:
		_aim = Vector2.from_angle(rotate_toward(_aim.angle(), want.angle(), delta * 40.0))

	match _phase:
		Phase.INTRO:
			_witch = _witch.lerp(Vector2(640, 170), delta * 2.0)
			_orb = _witch + Vector2(70, 10 + sin(_t * 2.0) * 8.0)
		Phase.FIGHT:
			_update_teleport(world_dt)
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

	var slow_dt := delta * _slowmo()
	for shard in _shards:
		shard.pos += shard.vel * slow_dt
		if shard.big:
			shard.vel.y += 700.0 * slow_dt
			shard.vel.x *= 0.99
			shard.rot += shard.spin * slow_dt
		else:
			shard.vel *= 0.96
		shard.life -= slow_dt
	_shards = _shards.filter(func(s: Dictionary) -> bool: return s.life > 0.0)
	for wisp in _wisps:
		wisp.pos += wisp.vel * delta
		wisp.life -= delta * 1.2
	_wisps = _wisps.filter(func(w: Dictionary) -> bool: return w.life > 0.0)
	_canvas.queue_redraw()


func _update_rebound(delta: float) -> void:
	var t := _phase_t
	_bars = minf(1.0, _bars + delta * 2.0)
	if t < BREAK_AT:
		# The orb holds on: shaking harder, cracking faster, camera creeping in.
		var k := t / BREAK_AT
		_zoom = lerpf(1.0, 1.4, ease(k, 0.6))
		_shake = maxf(_shake, 1.0 + k * k * 6.0)
		if t >= _next_tick:
			_next_tick += lerpf(0.5, 0.1, k)
			_orb_flash = 0.06
			_spawn_shards(_orb, 2)
			_play(SFX_CRACK, lerpf(-10.0, -3.0, k), lerpf(0.7, 1.6, k))
		if t > 0.5:
			_bark = "No..." if t < 1.4 else "NO NO NO!"
			_bark_t = 0.2
	elif not _broken:
		_broken = true
		_white = 0.9
		_shake = 24.0
		_spawn_shards(_orb, 30, true)
		_spawn_shards(_orb, 20)
		_shell = _orb + Vector2(0, 16)
		_shell_v = Vector2(randf_range(-40.0, 40.0), -120.0)
		_play(SFX_ZAP, -2.0, 0.7)
		_play(BLASTS[1], -4.0, 0.5)
	else:
		_zoom = lerpf(_zoom, 1.0, delta * 2.5)
		_shell_v.y += 900.0 * delta * _slowmo()
		_shell += _shell_v * delta * _slowmo()

	# The curse leaves your gun as green wisps, then you're Mr. Guy again.
	if t > BREAK_AT + 0.4 and t < GUY_AT and randf() < delta * 40.0:
		_wisps.append({"pos": GUN_POS + Vector2(randf_range(-80, 80), randf_range(-30, 30)),
			"vel": Vector2(randf_range(-20, 20), randf_range(-160, -60)), "life": 1.0})
	if t >= GUY_AT and not _is_guy:
		_is_guy = true
		_white = 0.6
		_shake = 10.0
		_play(SFX_SHINE, -6.0)
	# ...and it flies straight into her.
	if t >= HEX_AT and _cursed_gun == Vector2.ZERO:
		_white = 1.0
		_cursed_gun = _witch
		_play(BLASTS[0], -6.0, 0.7)
		_shake = 14.0
		# She lands on the wall away from Mr. Guy, then waddles off that way.
		_waddle_dir = 1.0 if _witch.x >= GUY_FEET.x else -1.0
		_land = Vector2(GUY_FEET.x + _waddle_dir * 230.0, GUN_REST_Y)
	if _cursed_gun != Vector2.ZERO:
		_update_cursed_gun(t - HEX_AT)
	if t > END_AT:
		_set_phase(Phase.END)


## Witch-as-shotgun, `s` seconds after she turned. Hovers stunned, drops onto the wall with a
## flip, lies there a beat, then hops away in little waddling hops, like you did all game.
func _update_cursed_gun(s: float) -> void:
	if s < STUN_T:
		_cursed_gun = _witch + Vector2(0, sin(s * 30.0) * 2.0)
		_cursed_spin = 0.0
		return
	if s < STUN_T + FALL_T:
		var u := (s - STUN_T) / FALL_T
		_cursed_gun = Vector2(lerpf(_witch.x, _land.x, u), lerpf(_witch.y, _land.y, u * u))
		_cursed_spin = -u * TAU * _waddle_dir
		return
	if not _landed:
		_landed = true
		_shake = 8.0
		_play(SFX_THUD, -10.0, 0.8)
	var rest := s - STUN_T - FALL_T - LIE_T
	if rest < 0.0:
		_cursed_gun = _land
		_cursed_spin = 0.0
		return
	var h := rest / HOP_T
	var hop := int(h)
	var f := h - hop
	if hop != _hops:
		_hops = hop
		_play(SFX_TAP, -16.0, randf_range(1.1, 1.3))
	_cursed_gun = _land + Vector2(_waddle_dir * (hop + f) * HOP_DX, -sin(f * PI) * HOP_H)
	# Rock side to side, one way per hop.
	_cursed_spin = (0.35 if hop % 2 == 0 else -0.35) * sin(f * PI)


## Time runs slow for a moment right after the orb bursts.
func _slowmo() -> float:
	if _phase != Phase.REBOUND:
		return _ts
	var since := _phase_t - BREAK_AT
	return 0.2 if since >= 0.0 and since < 0.5 else 1.0


# ---------------------------------------------------------------- drawing

func _draw_all() -> void:
	var c := _canvas
	var shake := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake
	# Zoom on the orb (finale), panning it toward the middle so she stays in frame, plus shake.
	# Everything in the world draws through this.
	var pan := _orb.lerp(Vector2(640, 400), clampf((_zoom - 1.0) / 0.4, 0.0, 1.0))
	_base = Transform2D(0.0, Vector2(_zoom, _zoom), 0.0, shake + pan - _orb * _zoom)
	c.draw_set_transform_matrix(_base)
	_draw_sky(c)
	if _phase != Phase.END:
		_draw_teleport(c)
		_draw_witch_or_gun(c)
		if _broken:
			_draw_shell(c)
		elif _orb_visible():
			_draw_breaking_light(c)
			_draw_orb(c, _orb)
			_draw_shield(c)
		_draw_shards(c)
		_draw_shells(c)
		if _is_guy:
			_draw_guy(c)
		else:
			_draw_player_gun(c)
		_draw_curse(c)
	c.draw_set_transform(Vector2.ZERO)
	if _ts < 0.99:
		# Slow motion: the world dims to a cold purple.
		c.draw_rect(Rect2(0, 0, 1280, 720), Color(0.05, 0.0, 0.12, (1.0 - _ts) * 0.35))
	if _bars > 0.0:
		var h := BAR_H * ease(_bars, 0.4)
		c.draw_rect(Rect2(0, 0, 1280, h), Color.BLACK)
		c.draw_rect(Rect2(0, 720 - h, 1280, h), Color.BLACK)
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
	if _cursed_gun != Vector2.ZERO:
		_draw_cursed_gun(c)
		return
	if _witch_sc <= 0.01:
		return
	var at := _witch.round()
	var face := _witch_face() if _phase == Phase.FIGHT else 1.0
	c.draw_set_transform_matrix(_base * Transform2D(_witch_rot, Vector2(face, 1) * _witch_sc, 0.0, at + Vector2(randf_range(-1, 1), 0) * _shake))
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
	# Pointy hat, brim resting on top of her head.
	c.draw_texture_rect(WITCH_HAT, Rect2(o + HAT_OFFSET * S, WITCH_HAT.get_size() * S), false)
	c.draw_set_transform_matrix(_base)


## The witch, cursed into a shotgun: purple-tinted gun wearing her pointy hat, waddling away.
func _draw_cursed_gun(c: Control) -> void:
	# Barrel points the way she's heading.
	var flip := Vector2(GUN_SCALE * _waddle_dir, GUN_SCALE)
	c.draw_set_transform_matrix(_base * Transform2D(_cursed_spin, flip, 0.0, _cursed_gun.round()))
	var half := SHOTGUN.get_size() / 2.0
	c.draw_texture(SHOTGUN, -half, Color(0.85, 0.7, 1.0))
	c.draw_texture(WITCH_HAT, Vector2(-13, -14))
	c.draw_set_transform_matrix(_base)
	var s := _phase_t - HEX_AT
	if s < STUN_T + FALL_T:
		c.draw_string(FONT, _cursed_gun + Vector2(-40, -70), "...!?", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, CREAM)
	elif s > STUN_T + FALL_T + 0.6 and s < STUN_T + FALL_T + 2.6:
		c.draw_string(FONT, _cursed_gun + Vector2(-60, -60), "hmph. HMPH!", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, CREAM)


func _draw_orb(c: Control, at: Vector2) -> void:
	for ring in 3:
		c.draw_circle(at, ORB_R + 10 + ring * 8, Color(ORB, 0.08))
	var k := clampf(_phase_t / BREAK_AT, 0.0, 1.0) if _phase == Phase.REBOUND else 0.0
	if k > 0.0:
		at += Vector2(randf_range(-1, 1), randf_range(-1, 1)) * (1.0 + k * 5.0)
	# Sprite has one crack stage per hit: 0..4 in the fight, 5 when it finally breaks.
	Art.draw_orb(c, at.round(), _orb_stage(), 3.0, _orb_flash)
	# In the finale, more cracks creep out from the middle until it bursts.
	for path in _crack_paths:
		var shown := int(ceil(k * (path.size() - 1)))
		for i in shown:
			c.draw_line(at + path[i] * 0.9, at + path[i + 1] * 0.9, DARK, 3.0)
			c.draw_line(at + path[i] * 0.9 + Vector2(2, 2), at + path[i + 1] * 0.9 + Vector2(2, 2), Color(ACCENT, 0.7), 2.0)


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
		if s.big:
			# Glass shard: a thin tumbling triangle with a bright edge.
			var r: float = s.size
			var pts := PackedVector2Array()
			for corner in [Vector2(-r, -r * 0.3), Vector2(r, 0), Vector2(-r * 0.4, r * 0.6)]:
				pts.append(s.pos + (corner as Vector2).rotated(s.rot))
			c.draw_colored_polygon(pts, Color(ORB, a))
			c.draw_line(pts[0], pts[1], Color(Color("f6e8ff"), a), 2.0)
		else:
			c.draw_rect(Rect2(s.pos, Vector2(s.size, s.size)), Color(ORB.lightened(0.3), a))


func _draw_shells(c: Control) -> void:
	for sh in _shells:
		Art.draw_shell(c, sh.pos, sh.rot, SHELL_PX, _base)
	for p in _pops:
		var a := clampf(p.life / 0.3, 0.0, 1.0)
		_center_text(c, p.text, p.pos.x, p.pos.y, 16, Color(p.col, a))


## Portals, the chevrons that give away where she's going, and the osu approach ring.
func _draw_teleport(c: Control) -> void:
	if _phase != Phase.FIGHT:
		return
	match _tp:
		Tp.WARN:
			# Three pixel chevrons marching from her toward the exit.
			var d := _tp_to - _tp_from
			var dir := d.normalized()
			for i in 3:
				var f := fmod(_tp_t * 3.0 + i / 3.0, 1.0)
				var at := _tp_from + dir * (90.0 + f * minf(d.length() - 90.0, 260.0))
				Art.draw_chevron(c, at, dir, S, Color(ACCENT, 1.0 - f * 0.6), Color(DARK, 0.9 - f * 0.5))
		Tp.SINK:
			Art.draw_portal(c, _tp_from, PORTAL_R * minf(1.0, _tp_t / (TP_SINK * 0.5)), _t)
		Tp.TRANSIT:
			Art.draw_portal(c, _tp_from, PORTAL_R * (1.0 - _tp_t / TP_TRANSIT), _t)
			Art.draw_portal(c, _tp_to, PORTAL_R * minf(1.0, _tp_t / TP_TRANSIT * 1.5), -_t)
		Tp.OPEN:
			Art.draw_portal(c, _tp_to, PORTAL_R * (1.0 - clampf(_tp_t / 0.3, 0.0, 1.0)), -_t)
	if _shine_t >= 0.0:
		Art.draw_shine(c, _witch + Vector2(0, -30), _shine_t, 2.5)
	# Approach ring: closes onto the hit circle exactly when she lands.
	var left := _until_land()
	var lead := lerpf(TP_APPROACH.x, TP_APPROACH.y, _difficulty())
	if left > 0.0 and left < lead:
		var at := _exit_orb()
		var fade := clampf((lead - left) / 0.12, 0.0, 1.0)
		c.draw_arc(at, HIT_R, 0.0, TAU, 40, Color(DARK, 0.8 * fade), 8.0)
		c.draw_arc(at, HIT_R, 0.0, TAU, 40, Color(ORB, 0.9 * fade), 4.0)
		c.draw_arc(at, HIT_R * (1.0 + 2.6 * left / lead), 0.0, TAU, 48, Color(ACCENT, fade), 4.0)
	elif _tp == Tp.OPEN:
		c.draw_arc(_orb, HIT_R, 0.0, TAU, 40, Color(Color.WHITE, 0.9), 5.0)


## Green bubble around the orb whenever it can't be hit.
func _draw_shield(c: Control) -> void:
	if _phase != Phase.FIGHT or _tp == Tp.OPEN:
		return
	var a := 0.25 + 0.1 * sin(_t * 5.0) + _shield_flash * 2.0
	c.draw_circle(_orb, SHIELD_R, Color(ACCENT, 0.08 + _shield_flash))
	c.draw_arc(_orb, SHIELD_R, 0.0, TAU, 40, Color(ACCENT, a), 3.0)


func _draw_player_gun(c: Control) -> void:
	var flip := -1.0 if _aim.x < 0.0 else 1.0
	var pos := GUN_POS - _aim * _kick * 18.0
	# While the curse lifts off, the gun trembles and glows green.
	var lifting := _phase == Phase.REBOUND and _phase_t > BREAK_AT + 0.3
	if lifting:
		var k := clampf((_phase_t - BREAK_AT - 0.3) / (GUY_AT - BREAK_AT - 0.3), 0.0, 1.0)
		pos += Vector2(randf_range(-1, 1), randf_range(-1, 1)) * k * 6.0
		c.draw_circle(GUN_POS, 70.0 + k * 50.0, Color(ACCENT, 0.12 + k * 0.25))
	c.draw_set_transform_matrix(_base * Transform2D(_aim.angle(), Vector2(GUN_SCALE, GUN_SCALE * flip), 0.0, pos.round()))
	var pivot := Vector2(20, 7)
	var tint := Color.WHITE
	if lifting:
		tint = Color.WHITE.lerp(Color(2.5, 3.0, 2.5), clampf((_phase_t - GUY_AT + 0.6) / 0.6, 0.0, 1.0))
	c.draw_texture(SHOTGUN, -pivot, tint)
	c.draw_texture(STETSON, STETSON_OFFSET - pivot, tint)
	if _flash > 0.0:
		var tip := Vector2(SHOTGUN.get_width() - pivot.x + 4.0, -2.0)
		c.draw_circle(tip, 7.0, Color(1.0, 0.6, 0.2, 0.9))
		c.draw_circle(tip, 4.0, Color(1.0, 0.95, 0.7))
	c.draw_set_transform_matrix(_base)


## Mr. Guy, human again, feet on the tower wall, wearing his stetson. Faces the witch.
func _draw_guy(c: Control) -> void:
	var o := GUY_FEET
	var since := _phase_t - GUY_AT
	# Pop in a little taller, then settle.
	var squash := 1.0 + maxf(0.0, 0.25 - since) * 0.8
	c.draw_set_transform_matrix(_base * Transform2D(0.0, Vector2(1.0 / squash, squash), 0.0, o))
	o = Vector2.ZERO
	var cheer := since > 0.3 and since < 2.6
	_px(c, o, -3, -8, 2, 8, PANTS)
	_px(c, o, 1, -8, 2, 8, PANTS)
	_px(c, o, -4, -1, 3, 1, DARK)
	_px(c, o, 1, -1, 3, 1, DARK)
	_px(c, o, -4, -19, 8, 11, SHIRT)
	_px(c, o, -4, -10, 8, 1, BELT)
	if cheer:
		_px(c, o, 4, -24, 2, 6, SHIRT)           # fist in the air
		_px(c, o, 4, -26, 2, 2, SKIN)
		_px(c, o, -6, -24, 2, 6, SHIRT)
		_px(c, o, -6, -26, 2, 2, SKIN)
	else:
		_px(c, o, -5, -18, 1, 7, SHIRT)
		_px(c, o, 4, -18, 1, 7, SHIRT)
	_px(c, o, -3, -26, 6, 7, SKIN)
	_px(c, o, 1, -23, 1, 1, DARK)                 # eye
	_px(c, o, 0, -21, 3, 1, Color("6b3a22"))      # moustache
	var hat := STETSON.get_size() * 0.5
	c.draw_texture_rect(STETSON, Rect2(Vector2(-hat.x * 0.5, -26 - hat.y + 2) * S, hat * S), false)
	c.draw_set_transform_matrix(_base)
	if since < 0.5:
		c.draw_circle(GUY_FEET + Vector2(0, -70), 40.0 + since * 300.0, Color(1, 1, 1, 0.8 - since * 1.6))
	if cheer:
		_center_text(c, "LEGS! I HAVE LEGS!", GUY_FEET.x, GUY_FEET.y - 190, 14, CREAM)


## The orb about to burst: light pours out of the cracks, which creep outward.
func _draw_breaking_light(c: Control) -> void:
	if _phase != Phase.REBOUND:
		return
	var k := clampf(_phase_t / BREAK_AT, 0.0, 1.0)
	for i in 7:
		var a := i * TAU / 7.0 + _t * 0.4
		var reach := 50.0 + k * k * 200.0
		var w := 0.05 + k * 0.05
		c.draw_colored_polygon(PackedVector2Array([_orb, _orb + Vector2.from_angle(a - w) * reach,
			_orb + Vector2.from_angle(a + w) * reach]), Color(ACCENT, 0.06 + k * 0.18))
	c.draw_circle(_orb, ORB_R + 20.0 + k * 30.0, Color(ACCENT, k * 0.2))


## The curse leaving the gun (wisps) and the bolt that carries it into her.
func _draw_curse(c: Control) -> void:
	for w in _wisps:
		var size: float = 6.0 + (1.0 - w.life) * 8.0
		c.draw_rect(Rect2(w.pos - Vector2(size, size) / 2.0, Vector2(size, size)), Color(ACCENT, w.life * 0.8))
	if _phase == Phase.REBOUND and _phase_t > GUY_AT + 0.2 and _phase_t < HEX_AT + 0.05:
		var k := (_phase_t - GUY_AT - 0.2) / (HEX_AT - GUY_AT - 0.2)
		_draw_bolt(c, GUY_FEET + Vector2(0, -90), _witch + Vector2(0, -40), k)


## Bottom half of the glass, tumbling down after the burst.
func _draw_shell(c: Control) -> void:
	var size := Art.ORB_SHELL.get_size() * 3.0
	c.draw_texture_rect(Art.ORB_SHELL, Rect2(_shell.round() - size / 2.0, size), false)


## Shells left, top left, standing up like the ammo pips under the gun. Spent ones are hollow.
func _draw_ammo(c: Control) -> void:
	if _phase not in [Phase.FIGHT, Phase.SWOOP, Phase.TAUNT, Phase.FINISH, Phase.LOST]:
		return
	c.draw_string(FONT, Vector2(170, 44), "SHELLS", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, CREAM)
	for i in SHELLS:
		var at := Vector2(270 + i * 26, 38)
		if i < _ammo:
			Art.draw_shell(c, at, -PI / 2.0, 3.0)
		else:
			c.draw_rect(Rect2(at - Vector2(9, 16), Vector2(18, 33)), Color("3a2b48"), false, 2.0)
	if _ammo <= 2 and _ammo > 0 and fmod(_t, 0.6) < 0.35:
		c.draw_string(FONT, Vector2(270 + SHELLS * 26 + 4, 44), "LOW!", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("ff6a5a"))


## Out of shells: what she says, and Retry / Menu.
func _draw_lost(c: Control) -> void:
	var a := clampf(_phase_t / 0.6, 0.0, 1.0)
	c.draw_rect(Rect2(0, 0, 1280, 720), Color(0.04, 0.02, 0.06, 0.75 * a))
	_center_text(c, "OUT OF SHELLS", 640, 250, 30, Color(Color("ff6a5a"), a))
	_center_text(c, "\"%s\"" % _bark, 640, 310, 13, Color(CREAM, a))
	var mouse := _canvas.get_local_mouse_position()
	_lost_hover = -1
	for i in 2:
		var box := _lost_button(i)
		var over := box.has_point(mouse) and _phase_t > 1.0
		if over:
			_lost_hover = i
		c.draw_rect(box, Color("170b22", 0.95 * a))
		c.draw_rect(box, Color(ACCENT if over else Color("3a2b48"), a), false, 3.0)
		var word := "RETRY" if i == 0 else "MENU"
		_center_text(c, word, box.get_center().x, box.get_center().y + 8, 18, Color(ACCENT if over else CREAM, a))


func _lost_button(i: int) -> Rect2:
	return Rect2(640 - 230 + i * 260, 400, 200, 60)


func _draw_hud(c: Control) -> void:
	_draw_ammo(c)
	if _phase == Phase.LOST:
		_draw_lost(c)
		return
	# Orb health: one pip per crack plus the final shot, top right.
	if _phase in [Phase.FIGHT, Phase.SWOOP, Phase.TAUNT, Phase.FINISH]:
		c.draw_string(FONT, Vector2(760, 44), "HEX ORB", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, CREAM)
		for i in CRACKS_TO_SWOOP + 1:
			var col := Color("3a2b48") if i < _cracks else ORB
			c.draw_rect(Rect2(880 + i * 30, 30, 22, 16), col)
	if _phase == Phase.FINISH:
		var a := 0.6 + 0.4 * sin(_t * 6.0)
		_center_text(c, "SHOOT THE ORB IN HER HAND!", 640, 660, 18, Color(ACCENT, a))
	elif _phase == Phase.FIGHT and _phase_t < 8.0:
		_center_text(c, "FOLLOW THE ARROWS. SHOOT WHEN THE RING CLOSES!", 640, 650, 13, CREAM)
		_center_text(c, "Her orb is open for a moment after she lands. Mind your shells.", 640, 680, 11, Color(CREAM, 0.7))
	var panicking := _phase == Phase.REBOUND and _phase_t < BREAK_AT
	if _bark_t > 0.0 and (_phase == Phase.FIGHT or panicking):
		var at := _base * Vector2(_witch.x - 40, maxf(_witch.y - 170, 90))
		at.y = maxf(at.y, BAR_H * _bars + 30.0)
		c.draw_string(FONT, at, _bark, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(CREAM, minf(_bark_t * 2.0, 1.0)))
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


## End card lines: text, y, size, colour. They type out one after another.
const END_LINES := [
	["THE CURSE REBOUNDS.", 250, 26, ACCENT],
	["Mrs. Sandwitch is a shotgun now.", 320, 14, CREAM],
	["Guns can't walk. She'll figure it out.", 356, 14, CREAM],
	["THANKS FOR PLAYING CURSED SHOTGUN", 450, 16, Color("ffd583")],
]
const END_TYPE_SPEED := 28.0   # characters per second
const END_PAUSE := 0.5         # beat between lines


func _end_total() -> int:
	var n := 0
	for line in END_LINES:
		n += (line[0] as String).length()
	return n


## Characters shown so far across all end lines (pauses between lines count as time, not chars).
func _end_typed() -> int:
	if _end_skip:
		return _end_total()
	var t := maxf(0.0, _phase_t - 0.9)
	var shown := 0
	for line in END_LINES:
		var len_i := (line[0] as String).length()
		var need := len_i / END_TYPE_SPEED
		if t < need:
			return shown + int(t * END_TYPE_SPEED)
		shown += len_i
		t -= need + END_PAUSE
		if t < 0.0:
			return shown
	return shown


func _draw_end(c: Control) -> void:
	var a := clampf(_phase_t / 0.8, 0.0, 1.0)
	c.draw_rect(Rect2(0, 0, 1280, 720), Color(0.04, 0.02, 0.06, a))
	var left := _end_typed()
	# A soft tick for each new letter.
	if left > _end_ticked:
		if not _end_skip and left % 2 == 0:
			_play(SFX_TAP, -22.0, 2.2)
		_end_ticked = left
	for line in END_LINES:
		var text: String = line[0]
		if left <= 0:
			break
		var part := text.substr(0, mini(left, text.length()))
		# Centre on the full line so letters don't slide while typing.
		var w := FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, line[2]).x
		c.draw_string(FONT, Vector2(640 - w / 2.0, line[1]), part, HORIZONTAL_ALIGNMENT_LEFT, -1, line[2], line[3])
		left -= text.length()
	if _end_typed() >= _end_total() and fmod(_t, 1.0) < 0.65:
		_center_text(c, "Click to return to the menu", 640, 560, 11, Color("bdb0c7"))


func _center_text(c: Control, text: String, x: float, y: float, size: int, col: Color) -> void:
	var w := FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	c.draw_string(FONT, Vector2(x - w / 2.0, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)

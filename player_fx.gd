class_name PlayerFx
extends Node2D
## Feel for the shotgun: sounds, camera zoom and shake, and the death-and-respawn animation.
## The player owns one of these and calls its hooks; it never changes movement itself.
##
## Death: spikes snap the gun into pieces; other deaths keep it whole. Either way a portal opens
## where you died, swallows what's left, and another portal at the last campfire spits the gun
## back out, fixed and shining. The whole thing takes about a second, so it never gets boring.

## Death timeline, in seconds from the moment you die.
const BREAK_TIME := 0.22
const PORTAL_A_OPEN := Vector2(0.10, 0.26)
const SUCK := Vector2(0.24, 0.56)
const PORTAL_A_CLOSE := Vector2(0.58, 0.70)
const TELEPORT_AT := 0.62
const PORTAL_B_OPEN := Vector2(0.70, 0.84)
const EJECT_AT := 0.86
const PORTAL_B_CLOSE := Vector2(0.88, 1.02)
const SHINE := Vector2(0.86, 1.32)
const PORTAL_RADIUS := 34.0
## Speed the gun is thrown out of the respawn portal with.
const EJECT_VELOCITY := Vector2(0, -240)

## Camera feel: a slight push-in while charging, a stronger one on the gun in slow motion,
## and short shakes on shots, wall hits and deaths.
const CHARGE_ZOOM := 0.04
const SLOWMO_ZOOM := 0.12
## Share of the way the view leans toward the gun during slow motion.
const SLOWMO_LEAN := 0.45
const ZOOM_SPEED := 6.0
const SHOT_SHAKE := 4.0
const SHAKE_DECAY := 30.0

## Wind starts at this speed and is loudest at this speed plus WIND_RANGE.
const WIND_START := 380.0
const WIND_RANGE := 520.0
## Walls and ceilings bonk when you hit them at least this fast.
const WALL_HIT_SPEED := 220.0

## Charge-up: a mellow synth riser that sweeps up over the 0.4 s charge and holds a soft note
## (made for this game with tools/make_charge_sound.py). Pitch 1 = as made. Volume in dB.
const CHARGE_SOUND := preload("res://assets/sfx/charge.wav")
const CHARGE_PITCH := 1.0
const CHARGE_VOLUME_DB := -20.0
const WIND_SOUND := preload("res://assets/sfx/fall_wind_loop.ogg")
const PORTAL_SOUND := preload("res://assets/sfx/portal.wav")
const SHINE_SOUND := preload("res://assets/sfx/respawn_shine.ogg")
const SPIKE_HIT_SOUND := preload("res://assets/sfx/spike_hit.ogg")
const SPIKE_BREAK_SOUND := preload("res://assets/sfx/spike_break.ogg")
const WALL_HIT_SOUND := preload("res://assets/sfx/wall_hit.ogg")
## How the gun sprite splits when it breaks: stock, receiver, barrel (sprite pixels).
const PIECES := [Rect2(0, 0, 18, 14), Rect2(18, 0, 16, 14), Rect2(34, 0, 24, 14)]

var player: CharacterBody2D
## True while the death animation runs: the player ignores input and physics.
var dying := false
## True while the gun is gone (between breaking and being thrown out of the portal).
var gun_hidden := false

var _t := 0.0
var _broken := false
var _death_pos := Vector2.ZERO
var _death_angle := 0.0
var _respawn_pos := Vector2.ZERO
var _pieces: Array[Dictionary] = []
var _shine_t := -1.0
var _teleported := false
var _ejected := false
var _shake := 0.0
var _wall_cooldown := 0.0
var _charge: AudioStreamPlayer
var _wind: AudioStreamPlayer
var _sfx: AudioStreamPlayer


func _ready() -> void:
	top_level = true
	z_index = 5
	# Low and quiet, so it sits under the shot instead of taking over.
	_charge = _make_sound(CHARGE_SOUND, CHARGE_VOLUME_DB)
	_charge.pitch_scale = CHARGE_PITCH
	var wind := WIND_SOUND.duplicate() as AudioStreamOggVorbis
	wind.loop = true
	_wind = _make_sound(wind, -80.0)
	_wind.play()
	_sfx = _make_sound(null, -4.0)


func _make_sound(stream: AudioStream, volume_db: float) -> AudioStreamPlayer:
	var sound := AudioStreamPlayer.new()
	sound.stream = stream
	sound.volume_db = volume_db
	add_child(sound)
	return sound


## One-shot sound; several can overlap.
func _play(stream: AudioStream, volume_db := -4.0, pitch := 1.0) -> void:
	var sound := _make_sound(stream, volume_db)
	sound.pitch_scale = pitch
	sound.finished.connect(sound.queue_free)
	sound.play()


# ---------------------------------------------------------------- hooks from the player

func charge_started() -> void:
	_charge.play()


func charge_stopped() -> void:
	_charge.stop()


func shot() -> void:
	_charge.stop()
	shake(SHOT_SHAKE)


func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


## After the player moves: bonk on walls and ceilings hit hard enough.
func check_impacts(before: Vector2) -> void:
	if _wall_cooldown > 0.0:
		return
	for index in range(player.get_slide_collision_count()):
		var hit := player.get_slide_collision(index)
		var normal := hit.get_normal()
		if normal.y < -0.7 or hit.get_collider() is Bouncy:
			continue
		var impact := -before.dot(normal)
		if impact >= WALL_HIT_SPEED:
			var loud := clampf((impact - WALL_HIT_SPEED) / 500.0, 0.0, 1.0)
			_play(WALL_HIT_SOUND, lerpf(-14.0, -3.0, loud), randf_range(0.9, 1.1))
			shake(2.0 + 3.0 * loud)
			_wall_cooldown = 0.12
			return


## Starts the death animation. Returns false if one is already running.
func start_death(reason: String) -> bool:
	if dying:
		return false
	dying = true
	gun_hidden = true
	_broken = reason == "spikes"
	_t = 0.0
	_teleported = false
	_ejected = false
	_death_pos = player.global_position
	_death_angle = player.gun_angle
	_charge.stop()
	shake(8.0 if _broken else 5.0)
	_pieces.clear()
	if _broken:
		_play(SPIKE_HIT_SOUND, -2.0)
		_play(SPIKE_BREAK_SOUND, -4.0)
		for i in PIECES.size():
			var out := Vector2.from_angle(_death_angle + (i - 1) * 1.1 - PI / 2.0)
			_pieces.append({"pos": _death_pos + Vector2.from_angle(_death_angle) * (i * 14.0 - 14.0),
				"vel": out * randf_range(120, 200), "rot": _death_angle, "spin": randf_range(-14, 14)})
	else:
		_pieces.append({"pos": _death_pos, "vel": Vector2.ZERO, "rot": _death_angle, "spin": 9.0})
	return true


## Stops a death animation early (a level load or checkpoint skip moved you already).
func cancel() -> void:
	dying = false
	gun_hidden = false
	_pieces.clear()


# ---------------------------------------------------------------- per frame

func _process(delta: float) -> void:
	_wall_cooldown = maxf(0.0, _wall_cooldown - delta)
	if dying:
		_advance_death(delta)
	if _shine_t >= 0.0:
		_shine_t += delta
		if _shine_t > SHINE.y - SHINE.x:
			_shine_t = -1.0
	_update_wind(delta)
	_update_camera(delta)
	queue_redraw()


func _advance_death(delta: float) -> void:
	var before := _t
	_t += delta
	if before < PORTAL_A_OPEN.x and _t >= PORTAL_A_OPEN.x:
		_play(PORTAL_SOUND, -18.0, 1.15)
	for p in _pieces:
		if _t < BREAK_TIME and _broken:
			p.vel = p.vel * 0.9 + Vector2(0, 300) * delta
			p.pos += p.vel * delta
		p.rot += p.spin * delta
	if not _teleported and _t >= TELEPORT_AT:
		_teleported = true
		player.respawn_after_death()
		_respawn_pos = player.global_position
	if before < PORTAL_B_OPEN.x and _t >= PORTAL_B_OPEN.x:
		_play(PORTAL_SOUND, -20.0, 1.3)
	if not _ejected and _t >= EJECT_AT:
		_ejected = true
		gun_hidden = false
		dying = false
		player.velocity = EJECT_VELOCITY
		_shine_t = 0.0
		_play(SHINE_SOUND, -16.0)


func _update_wind(delta: float) -> void:
	var speed := 0.0 if dying else player.velocity.length()
	var amount := clampf((speed - WIND_START) / WIND_RANGE, 0.0, 1.0)
	var target := linear_to_db(maxf(amount * 0.55, 0.0001))
	_wind.volume_db = lerpf(_wind.volume_db, target, minf(1.0, 8.0 * delta))
	_wind.pitch_scale = 0.85 + amount * 0.35


func _update_camera(delta: float) -> void:
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return
	var zoom := 1.0
	var lean := Vector2.ZERO
	if player.charging and not dying:
		zoom += CHARGE_ZOOM * player.charge_fraction()
		if player.is_air_charging():
			zoom = 1.0 + SLOWMO_ZOOM
			lean = (player.global_position - camera.get_screen_center_position() + camera.offset) * SLOWMO_LEAN
	var z := lerpf(camera.zoom.x, zoom, minf(1.0, ZOOM_SPEED * delta))
	camera.zoom = Vector2(z, z)
	_shake = maxf(0.0, _shake - SHAKE_DECAY * delta)
	var jitter := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake
	var base := camera.offset - _last_jitter
	camera.offset = base.lerp(lean, minf(1.0, ZOOM_SPEED * delta)) + jitter
	_last_jitter = jitter

var _last_jitter := Vector2.ZERO


## Tiny tremble on the gun while charging, building toward full power.
func tremble() -> Vector2:
	if not player.charging or dying:
		return Vector2.ZERO
	var f: float = player.charge_fraction()
	return Vector2(randf_range(-1, 1), randf_range(-1, 1)) * f * f * 1.6


# ---------------------------------------------------------------- drawing (world space)

func _draw() -> void:
	if dying:
		_draw_death()
	if _shine_t >= 0.0:
		_draw_shine(player.global_position, _shine_t / (SHINE.y - SHINE.x))


func _draw_death() -> void:
	# Portal where you died: opens, swallows the gun, closes.
	var ra := _ramp(PORTAL_A_OPEN) * (1.0 - _ramp(PORTAL_A_CLOSE))
	if ra > 0.0:
		_draw_portal(_death_pos, PORTAL_RADIUS * ra, _t)
	# The pieces (or the whole gun) spiral into it and shrink.
	var suck := _ramp(SUCK)
	if suck < 1.0:
		for i in _pieces.size():
			var p := _pieces[i]
			var at: Vector2 = p.pos
			if suck > 0.0:
				var angle := suck * 5.0 + i * 2.0
				var spiral := (at - _death_pos).rotated(angle) * (1.0 - suck)
				at = _death_pos + spiral
			var scale := 1.0 - suck * 0.9
			draw_set_transform(at, p.rot, Vector2(scale, scale))
			if _broken:
				var src: Rect2 = PIECES[i]
				draw_texture_rect_region(Art.SHOTGUN, Rect2(-src.size / 2.0, src.size), src)
			else:
				draw_texture(Art.SHOTGUN, -player.GUN_PIVOT)
			draw_set_transform(Vector2.ZERO)
	# Portal at the campfire: opens, throws the gun out, closes.
	if _teleported:
		var rb := _ramp(PORTAL_B_OPEN) * (1.0 - _ramp(PORTAL_B_CLOSE))
		if rb > 0.0:
			_draw_portal(_respawn_pos, PORTAL_RADIUS * rb, -_t)
	if _broken and _t < 0.12:
		# White snap where the spikes broke it.
		draw_circle(_death_pos, 26.0 * (1.0 - _t / 0.12), Color(1, 1, 1, 0.8))


## 0 before span.x, 1 after span.y, smooth in between.
func _ramp(span: Vector2) -> float:
	return smoothstep(span.x, span.y, _t)


## Swirling purple portal: ragged rim, then darker rings pulled to one side like a tunnel.
func _draw_portal(center: Vector2, radius: float, spin: float) -> void:
	if radius < 1.0:
		return
	var rim := PackedVector2Array()
	for i in 36:
		var a := TAU * i / 36.0
		var r := radius * (1.0 + 0.13 * sin(a * 5.0 + spin * 9.0) + 0.07 * sin(a * 11.0 - spin * 13.0))
		rim.append(center + Vector2.from_angle(a) * r)
	draw_colored_polygon(rim, Color(0.36, 0.2, 0.5))
	var tunnel := Vector2(radius * 0.16, -radius * 0.04)
	draw_circle(center + tunnel * 0.5, radius * 0.8, Color(0.25, 0.12, 0.34))
	draw_circle(center + tunnel, radius * 0.62, Color(0.12, 0.05, 0.17))
	draw_circle(center + tunnel * 1.4, radius * 0.44, Color(0.04, 0.01, 0.06))
	for ring in 3:
		var r2 := radius * (0.3 + 0.17 * ring)
		var start := spin * (6.0 - ring) + ring * 1.7
		draw_arc(center + tunnel * (1.4 - ring * 0.4), r2, start, start + 2.4, 12,
			Color(0.45, 0.25, 0.6, 0.8), 2.0)
	draw_circle(center, radius * 1.25, Color(0.6, 0.35, 0.9, 0.08))


## Clean and shiny: an expanding ring, sparkles, and a bright glow on the fixed gun.
func _draw_shine(center: Vector2, f: float) -> void:
	var fade := 1.0 - f
	draw_circle(center, 22.0 + 18.0 * f, Color(1.0, 0.95, 0.7, 0.18 * fade))
	draw_arc(center, 14.0 + 40.0 * f, 0, TAU, 32, Color(1.0, 0.95, 0.75, 0.8 * fade), 2.0)
	for i in 6:
		var a := TAU * i / 6.0 + f * 1.5
		var p := center + Vector2.from_angle(a) * (16.0 + 26.0 * f)
		var s := 4.0 * fade + 1.0
		draw_rect(Rect2(p - Vector2(0.5, s), Vector2(1.5, s * 2.0)), Color(1, 1, 0.85, fade))
		draw_rect(Rect2(p - Vector2(s, 0.5), Vector2(s * 2.0, 1.5)), Color(1, 1, 0.85, fade))


## How bright the gun glows right after respawning (1 = just thrown out, 0 = normal).
func glow() -> float:
	return 0.0 if _shine_t < 0.0 else 1.0 - _shine_t / (SHINE.y - SHINE.x)

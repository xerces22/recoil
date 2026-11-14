extends CharacterBody2D

signal died
signal shot_fired
signal debug_event(message: String)

const MAX_SHOTS := 2
const GRAVITY := 880.0
const RECOIL_SPEED := 580.0
const MIN_CHARGED_RECOIL := 380.0
const FULL_CHARGE_TIME := 0.40
const AIR_CHARGE_TIME_SCALE := 0.35
const DEBUG_FLIGHT_SPEED := 850.0
## Share of current velocity kept when a turret bolt hits.
const KNOCKBACK_KEEP := 0.25

## Barrel hitbox: distance from the body centre to the muzzle. The barrel is solid.
const GUN_REACH := 38.0
## How fast the gun turns toward the cursor, in radians per second.
const GUN_TURN_SPEED := 30.0
## Wiggle bounce: when the barrel swings into a surface it shoves the body straight off it,
## the same frame, and the body keeps that speed. Slow moves just prop you up; fast flicks bounce.
## Share of the barrel's swing speed passed on to the body.
const WIGGLE_BOUNCE := 0.9
## Fastest a wiggle can launch you (px/s), so shooting stays the main way up.
const WIGGLE_MAX := 420.0
## Floors and ledge tops (normal pointing up at least this much) grip the muzzle so you don't slide.
## Walls don't grip, so you slide down them instead of hanging off the barrel.
const GRIP_NORMAL_Y := -0.5
## Sliding speed the muzzle grip removes per second while it rests on a floor.
const MUZZLE_GRIP := 2400.0

@onready var respawn_position := position
## Playable area from the level. Set by main.gd on level load.
var bounds := Level.SHAFT
var shots := MAX_SHOTS
var pending_shot := Vector2.ZERO
var pending_power := RECOIL_SPEED
var charging := false
var charge_seconds := 0.0
var debug_flying := false
var flash := 0.0
## Seconds left on the muzzle flash, and the direction the barrel pointed when it fired.
var muzzle := 0.0
var muzzle_dir := Vector2.RIGHT
## Current gun angle. Follows the cursor at GUN_TURN_SPEED; shots fire along it.
var gun_angle := 0.0
## True while the muzzle is resting on or pushing into a surface.
var braced := false
## Testing hook: aim at this global point instead of the cursor while it is non-zero.
var forced_aim := Vector2.ZERO
var _was_barrel_grounded := false
## Gun angle at the start of this physics step, to tell a swing from a fall.
var _prev_gun_angle := 0.0

const BLAST_SOUNDS: Array[AudioStream] = [
	preload("res://assets/sfx/shotgun_blast_mossberg_1.wav"),
	preload("res://assets/sfx/shotgun_blast_mossberg_2.wav"),
	preload("res://assets/sfx/shotgun_blast_model12_1.wav"),
	preload("res://assets/sfx/shotgun_blast_model12_2.wav"),
]
const RELOAD_SOUND := preload("res://assets/sfx/shotgun_reload.wav")
const LAND_SOUND := preload("res://assets/sfx/impactWood_light_000.ogg")
const MUZZLE_TIME := 0.07
## Where the gun turns, in sprite pixels from its top-left (just ahead of the grip).
const GUN_PIVOT := Vector2(20, 7)

var _blast: AudioStreamPlayer
var _reload: AudioStreamPlayer
var _land: AudioStreamPlayer
var shoot_button := MOUSE_BUTTON_LEFT
var show_aim_guide := true
var aim_surface: Control


func _ready() -> void:
	add_to_group("player")
	_blast = _make_player(-4.0)
	_reload = _make_player(-6.0)
	_reload.stream = RELOAD_SOUND
	_land = _make_player(-10.0)
	_land.stream = LAND_SOUND


func _make_player(volume_db: float) -> AudioStreamPlayer:
	var sound := AudioStreamPlayer.new()
	sound.volume_db = volume_db
	sound.bus = &"SFX"
	add_child(sound)
	return sound


func handle_game_input(event: InputEvent) -> void:
	if OS.is_debug_build() and event is InputEventKey and event.keycode == KEY_F7:
		if event.pressed and not event.echo:
			debug_flying = not debug_flying
			velocity = Vector2.ZERO
			charging = false
			charge_seconds = 0.0
			pending_shot = Vector2.ZERO
			debug_event.emit("Debug flight on" if debug_flying else "Debug flight off")
		return

	if debug_flying:
		return

	if event is InputEventMouseButton and event.button_index == shoot_button:
		if event.pressed:
			if shots > 0 and pending_shot == Vector2.ZERO and not charging:
				charging = true
				charge_seconds = 0.0
			return
		if not charging:
			return
		charging = false
		# Fire along the barrel as drawn, so the blast always matches what you see.
		pending_shot = -gun_dir()
		pending_power = lerpf(MIN_CHARGED_RECOIL, RECOIL_SPEED, charge_fraction())


func cancel_shot() -> void:
	charging = false
	charge_seconds = 0.0
	pending_shot = Vector2.ZERO
	queue_redraw()


func gun_dir() -> Vector2:
	return Vector2.from_angle(gun_angle)


func _turn_gun(delta: float) -> void:
	var target := forced_aim if forced_aim != Vector2.ZERO else _world_mouse_position()
	var aim := target - global_position
	if aim.length_squared() >= 1.0:
		gun_angle = rotate_toward(gun_angle, aim.angle(), GUN_TURN_SPEED * delta)


func _world_mouse_position() -> Vector2:
	return get_canvas_transform().affine_inverse() * aim_surface.get_local_mouse_position()


## Where the barrel touches something solid, or {} if it is clear.
## `slack` reaches a little past the muzzle so a resting muzzle still counts as touching.
func _barrel_hit(slack := 0.0) -> Dictionary:
	var query := PhysicsRayQueryParameters2D.create(global_position,
		global_position + gun_dir() * (GUN_REACH + slack), collision_mask, [get_rid()])
	return get_world_2d().direct_space_state.intersect_ray(query)


## The floor the muzzle is resting on, or null. Resting the barrel on stone reloads like landing.
func _barrel_floor() -> Object:
	var hit := _barrel_hit(2.0)
	if hit.is_empty() or hit.collider is Bouncy or hit.normal.y > GRIP_NORMAL_Y:
		return null
	return hit.collider


## Before moving: the muzzle holds the body up. No moving further into the surface,
## and on floors it grips so you don't slide. Blue bumpers spring you away instead.
func _brace(delta: float) -> void:
	var hit := _barrel_hit(1.0)
	braced = not hit.is_empty()
	if not braced:
		return
	var dir := gun_dir()
	var bumper := hit.collider as Bouncy
	if bumper != null:
		if velocity.dot(dir) > -bumper.min_speed * 0.5:
			velocity = -dir * bumper.min_speed
			bumper.pulse()
			debug_event.emit("Barrel bounced at %s" % position.round())
		braced = false
		return
	var normal: Vector2 = hit.normal
	var into := -velocity.dot(normal)
	if into > 0.0:
		velocity += normal * into
	if normal.y <= GRIP_NORMAL_Y:
		var along := velocity - normal * velocity.dot(normal)
		velocity -= along - along.move_toward(Vector2.ZERO, MUZZLE_GRIP * delta)


## After moving: if the muzzle ended up inside a surface (the gun swung into it, or you fell
## onto it), shove the body straight off that surface right away, and keep that speed.
## A slow swing just props you up; a fast flick bounces you.
func _lever(delta: float) -> void:
	var hit := _barrel_hit()
	if hit.is_empty() or hit.collider is Bouncy:
		return
	var depth := GUN_REACH - global_position.distance_to(hit.position)
	if depth <= 0.0:
		return
	var normal: Vector2 = hit.normal
	# How far the muzzle sits inside the surface, measured straight out of it.
	var out := depth * maxf(0.0, -gun_dir().dot(normal))
	if out <= 0.0:
		return
	move_and_collide(normal * out)
	# Only the barrel's own swing kicks. Falling onto the muzzle just stops you, no trampoline.
	var swing := (gun_dir() - Vector2.from_angle(_prev_gun_angle)) * GUN_REACH
	var swung_in := minf(out, maxf(0.0, -swing.dot(normal)))
	var kick := minf(swung_in / delta * WIGGLE_BOUNCE, WIGGLE_MAX)
	var away := velocity.dot(normal)
	if kick > away:
		velocity += normal * (kick - away)



func charge_fraction() -> float:
	return clampf(charge_seconds / FULL_CHARGE_TIME, 0.0, 1.0)


func is_air_charging() -> bool:
	return charging and shots == 1 and not is_on_floor()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		cancel_shot()


func _physics_process(delta: float) -> void:
	_prev_gun_angle = gun_angle
	_turn_gun(delta)
	if debug_flying:
		var cursor_offset := _world_mouse_position() - global_position
		velocity = (cursor_offset / delta).limit_length(DEBUG_FLIGHT_SPEED)
		move_and_slide()
		queue_redraw()
		return

	if charging:
		charge_seconds = minf(charge_seconds + delta, FULL_CHARGE_TIME)

	if pending_shot != Vector2.ZERO:
		var before_shot := velocity
		velocity = pending_shot * pending_power
		debug_event.emit("Shot %d power=%.0f aim=%s  velocity %s -> %s" % [
			MAX_SHOTS - shots + 1, pending_power, pending_shot.snapped(Vector2(0.01, 0.01)),
			before_shot.round(), velocity.round(),
		])
		muzzle_dir = -pending_shot
		muzzle = MUZZLE_TIME
		_blast.stream = BLAST_SOUNDS.pick_random()
		_blast.pitch_scale = randf_range(0.95, 1.08)
		_blast.play()
		pending_shot = Vector2.ZERO
		shots -= 1
		shot_fired.emit()

	var time_scale := AIR_CHARGE_TIME_SCALE if is_air_charging() else 1.0
	velocity.y += GRAVITY * delta * time_scale
	_brace(delta * time_scale)
	var was_grounded := is_on_floor()
	var was_on_ceiling := is_on_ceiling()
	var before := velocity
	# Scale movement for this step and keep collision-adjusted momentum for release.
	velocity *= time_scale
	move_and_slide()
	velocity /= time_scale
	_lever(delta)
	var bounced := _apply_bounce(before)
	if is_on_ceiling() and not was_on_ceiling:
		debug_event.emit("Hit ceiling at %s" % position.round())
	var body_down := is_on_floor() and not bounced
	var barrel_ground := _barrel_floor() if not bounced else null
	var grounded := body_down or barrel_ground != null
	if grounded:
		if not was_grounded and not _was_barrel_grounded:
			debug_event.emit("Landed%s at %s  ammo refilled" % [
				"" if body_down else " on barrel", position.round()])
			_land.play()
			if shots == 1:
				charging = false
				charge_seconds = 0.0
		if shots < MAX_SHOTS:
			_reload.play()
		shots = MAX_SHOTS
		if body_down:
			velocity.x = 0.0
		var ground: Object = _floor_collider() if body_down else barrel_ground
		if ground != null and ground.has_method("on_player_landed"):
			ground.on_player_landed(self)
	_was_barrel_grounded = barrel_ground != null

	flash = maxf(0.0, flash - delta)
	muzzle = maxf(0.0, muzzle - delta)
	var fall_limit := minf(bounds.end.y + 20.0, respawn_position.y + 420.0)
	if position.y > fall_limit or position.x < bounds.position.x - 24.0 or position.x > bounds.end.x + 24.0:
		die("out of bounds")

	queue_redraw()


## Reflects off blue surfaces. Returns true if a bounce happened this frame.
func _apply_bounce(before: Vector2) -> bool:
	for index in range(get_slide_collision_count()):
		var hit := get_slide_collision(index)
		var bumper := hit.get_collider() as Bouncy
		if bumper == null:
			continue
		var normal := hit.get_normal()
		var into := before.dot(normal)
		if into >= 0.0:
			continue
		var out := maxf(-into * bumper.strength, bumper.min_speed)
		velocity = before - normal * into + normal * out
		bumper.pulse()
		debug_event.emit("Bounced at %s" % position.round())
		return true
	return false


func _floor_collider() -> Object:
	for index in range(get_slide_collision_count()):
		var hit := get_slide_collision(index)
		if hit.get_normal().y < -0.7:
			return hit.get_collider()
	return null


## Turret bolt hit: shoves you, keeps your shells.
func knock(impulse: Vector2) -> void:
	velocity = velocity * KNOCKBACK_KEEP + impulse
	flash = 0.25
	debug_event.emit("Knocked by bolt at %s" % position.round())


## Mouth bite: no shots until you land again.
func lose_shells() -> void:
	shots = 0
	pending_shot = Vector2.ZERO
	charging = false
	charge_seconds = 0.0
	flash = 0.35
	debug_event.emit("Bitten at %s  ammo lost" % position.round())


## Air refill pickup. Returns true if it gave at least one shell.
func refill(amount: int) -> bool:
	if shots >= MAX_SHOTS:
		return false
	shots = mini(MAX_SHOTS, shots + amount)
	debug_event.emit("Refilled in air at %s  ammo %d" % [position.round(), shots])
	return true


func die(reason := "hazard") -> void:
	respawn(reason)
	died.emit()


func respawn(reason := "reset") -> void:
	debug_event.emit("Respawn (%s) %s -> %s" % [reason, position.round(), respawn_position.round()])
	position = respawn_position
	velocity = Vector2.ZERO
	shots = MAX_SHOTS
	pending_shot = Vector2.ZERO
	charging = false
	charge_seconds = 0.0
	debug_flying = false
	flash = 0.0


func _draw() -> void:
	var aim := gun_dir()
	# Soft warm halo so the gun reads against the dark wall.
	draw_circle(Vector2.ZERO, 26.0, Color(1.0, 0.8, 0.55, 0.07))
	draw_circle(Vector2.ZERO, 17.0, Color(1.0, 0.8, 0.55, 0.08))
	_draw_gun(aim)
	_draw_shells()

	if charging:
		var bar := Rect2(-22, -30, 44, 6)
		draw_rect(bar.grow(2), Color(0.09, 0.05, 0.12))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * charge_fraction(), bar.size.y)),
			Color(1.0, 0.82, 0.3) if charge_fraction() >= 1.0 else Color(0.95, 0.45, 0.15))

	if shots == 0 or debug_flying or not show_aim_guide:
		return

	# Launch direction: away from the cursor.
	var direction := -aim
	var tip := direction * 40.0
	var arrow := Color(1, 1, 1, 0.55)
	draw_line(direction * 22.0, tip, arrow, 2.0, true)
	draw_line(tip, tip - direction.rotated(0.55) * 8.0, arrow, 2.0, true)
	draw_line(tip, tip - direction.rotated(-0.55) * 8.0, arrow, 2.0, true)


## Shotgun sprite turned toward the cursor, flipped so it never hangs upside down.
func _draw_gun(aim: Vector2) -> void:
	var tint := Color(1, 0.45, 0.45) if flash > 0.0 else Color.WHITE
	var flip := -1.0 if aim.x < 0.0 else 1.0
	draw_set_transform(Vector2.ZERO, aim.angle(), Vector2(1, flip))
	draw_texture(Art.SHOTGUN, -GUN_PIVOT, tint)
	draw_texture(Art.STETSON, Art.STETSON_OFFSET - GUN_PIVOT, tint)
	if muzzle > 0.0:
		var tip := Vector2(Art.SHOTGUN.get_width() - GUN_PIVOT.x + 2.0, -2.0)
		draw_circle(tip + Vector2(6, 0), 9.0, Color(1.0, 0.55, 0.15, 0.85))
		draw_circle(tip + Vector2(4, 0), 5.0, Color(1.0, 0.95, 0.6))
	draw_set_transform(Vector2.ZERO)


## Two shell pips under the gun: filled while loaded, hollow once spent.
func _draw_shells() -> void:
	for index in range(MAX_SHOTS):
		var top_left := Vector2(-9 + index * 10, 14)
		draw_rect(Rect2(top_left - Vector2(1, 1), Vector2(8, 13)), Color(0.09, 0.05, 0.12))
		if index < shots:
			draw_rect(Rect2(top_left, Vector2(6, 7)), Color(0.82, 0.16, 0.12))
			draw_rect(Rect2(top_left, Vector2(2, 7)), Color(1.0, 0.45, 0.35))
			draw_rect(Rect2(top_left + Vector2(0, 7), Vector2(6, 4)), Color(0.9, 0.7, 0.25))
		else:
			draw_rect(Rect2(top_left, Vector2(6, 11)), Color(0.35, 0.27, 0.4), false, 1.0)

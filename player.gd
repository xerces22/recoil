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
## Real seconds the air-charge slow motion lasts per click. After that time runs normally,
## though you keep the charge. Click again (new charge) for a fresh window.
const AIR_SLOWMO_TIME := 1.5
const DEBUG_FLIGHT_SPEED := 850.0
## Share of current velocity kept when a turret bolt hits.
const KNOCKBACK_KEEP := 0.25

## Barrel hitbox: distance from the body centre to the muzzle. The barrel is solid.
const GUN_REACH := 38.0
## Body hitbox: a capsule along the gun from the stock end (BODY_BACK px behind the grip) to
## the front of the receiver (BODY_FRONT px ahead), BODY_RADIUS thick. It turns with the gun.
## The thin barrel past BODY_FRONT is the muzzle ray above, so wiggling keeps working.
const BODY_BACK := 20.0
const BODY_FRONT := 10.0
const BODY_RADIUS := 6.0
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
## Real seconds of air-charge slow motion left for the current charge.
var _slowmo_left := 0.0
## True once this charge's slow motion has started, so a refill (back to 2 shells) keeps it.
var _slowmo_kept := false
## Moving platform the muzzle rested on last frame, and where it was then.
var _barrel_carrier: Node2D = null
var _barrel_carrier_pos := Vector2.ZERO
## What the body and/or the muzzle are standing on this frame (checkpoints read this).
var standing_on: Array[Object] = []
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
var _body_shape: CollisionShape2D
## Sounds, camera feel and the death/respawn animation.
var _fx: PlayerFx
var _death_reason := ""
var _respawning_from_death := false
var shoot_button := MOUSE_BUTTON_LEFT
var show_aim_guide := true
var aim_surface: Control


func _ready() -> void:
	add_to_group("player")
	_body_shape = get_node_or_null("CollisionShape2D")
	if _body_shape == null:
		_body_shape = CollisionShape2D.new()
		add_child(_body_shape)
	var capsule := CapsuleShape2D.new()
	capsule.radius = BODY_RADIUS
	capsule.height = BODY_BACK + BODY_FRONT
	_body_shape.shape = capsule
	_sync_body_shape()
	_blast = _make_player(-4.0)
	_reload = _make_player(-6.0)
	_reload.stream = RELOAD_SOUND
	_land = _make_player(-10.0)
	_land.stream = LAND_SOUND
	_fx = PlayerFx.new()
	_fx.player = self
	add_child(_fx)


func _make_player(volume_db: float) -> AudioStreamPlayer:
	var sound := AudioStreamPlayer.new()
	sound.volume_db = volume_db
	sound.bus = &"SFX"
	add_child(sound)
	return sound


func handle_game_input(event: InputEvent) -> void:
	if OS.is_debug_build() and event is InputEventKey and event.keycode == KEY_F2:
		if event.pressed and not event.echo:
			debug_flying = not debug_flying
			velocity = Vector2.ZERO
			charging = false
			charge_seconds = 0.0
			pending_shot = Vector2.ZERO
			debug_event.emit("Debug flight on" if debug_flying else "Debug flight off")
		return

	if debug_flying or _fx.dying:
		return

	if event is InputEventMouseButton and event.button_index == shoot_button:
		if event.pressed:
			if shots > 0 and pending_shot == Vector2.ZERO and not charging:
				charging = true
				charge_seconds = 0.0
				_slowmo_left = AIR_SLOWMO_TIME
				_slowmo_kept = false
				_fx.charge_started()
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
	if _fx != null:
		_fx.charge_stopped()
	queue_redraw()


func gun_dir() -> Vector2:
	return Vector2.from_angle(gun_angle)


## Lays the body capsule along the gun (capsules stand upright, so turn it a quarter more).
func _sync_body_shape() -> void:
	if _body_shape == null:
		return
	_body_shape.position = gun_dir() * (BODY_FRONT - BODY_BACK) * 0.5
	_body_shape.rotation = gun_angle + PI / 2.0


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
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	# Right after a level switch the old platforms can still be in the physics space for a frame.
	if not hit.is_empty() and not is_instance_valid(hit.collider):
		return {}
	return hit


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
		var pad_normal: Vector2 = hit.normal
		var into_pad := velocity.dot(pad_normal)
		if into_pad < 0.0:
			# Falling or flying into the pad barrel-first: bounce off it like the body does,
			# so pads still give your height back.
			var out := maxf(-into_pad * bumper.strength, bumper.min_speed)
			velocity = velocity - pad_normal * into_pad + pad_normal * out
			bumper.pulse()
			debug_event.emit("Barrel bounced at %s  speed %.0f" % [position.round(), out])
		elif velocity.dot(dir) > -bumper.min_speed * 0.5:
			# Resting or slow, poking the pad with the barrel: a small spring away from it.
			velocity = -dir * bumper.min_speed
			bumper.pulse()
			debug_event.emit("Barrel poked pad at %s" % position.round())
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
	if not charging or is_on_floor() or _slowmo_left <= 0.0:
		return false
	# Slow motion starts on your last shell; once going, a refill mid-charge doesn't stop it.
	return shots == 1 or _slowmo_kept


## Drops the held charge and its slow motion; you have to click again to charge.
func cancel_charge() -> void:
	charging = false
	charge_seconds = 0.0
	_slowmo_left = 0.0
	if _fx != null:
		_fx.charge_stopped()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		charging = false
		charge_seconds = 0.0
		if _fx != null:
			_fx.charge_stopped()


func _physics_process(delta: float) -> void:
	_prev_gun_angle = gun_angle
	_turn_gun(delta)
	_sync_body_shape()
	# Dead: the death animation in PlayerFx is running; hold still until it throws you back out.
	if _fx.dying:
		velocity = Vector2.ZERO
		queue_redraw()
		return
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
		_fx.shot()
		pending_shot = Vector2.ZERO
		shots -= 1
		shot_fired.emit()

	_ride_barrel_platform()

	var slowmo := is_air_charging()
	_slowmo_kept = slowmo
	if slowmo:
		_slowmo_left -= delta
	var time_scale := AIR_CHARGE_TIME_SCALE if slowmo else 1.0
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
	_fx.check_impacts(before)
	var bounced := _apply_bounce(before)
	if is_on_ceiling() and not was_on_ceiling:
		debug_event.emit("Hit ceiling at %s" % position.round())
	var body_down := is_on_floor() and not bounced
	var barrel_ground := _barrel_floor() if not bounced else null
	var grounded := body_down or barrel_ground != null
	standing_on.clear()
	if body_down:
		standing_on.append(_floor_collider())
	if barrel_ground != null:
		standing_on.append(barrel_ground)
	if _barrel_in_spikes():
		die.call_deferred("spikes")
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
	# Godot carries the body on a moving platform itself; the barrel is only a ray, so a
	# platform under the muzzle is remembered here and carries you next frame.
	_barrel_carrier = null
	if barrel_ground is AnimatableBody2D and not (body_down and _floor_collider() == barrel_ground):
		_barrel_carrier = barrel_ground
		_barrel_carrier_pos = (barrel_ground as Node2D).global_position

	flash = maxf(0.0, flash - delta)
	muzzle = maxf(0.0, muzzle - delta)
	# Only falling out of the level counts as falling into the void. Long falls inside it play out,
	# so you land on whatever is really below (floor, or spikes) instead of vanishing mid-air.
	var fall_limit := bounds.end.y + 40.0
	if position.y > fall_limit or position.x < bounds.position.x - 24.0 or position.x > bounds.end.x + 24.0:
		die("out of bounds")

	queue_redraw()


## Moves you with the moving platform your barrel rested on last frame, so standing on the
## barrel rides the platform the same way lying on it does.
func _ride_barrel_platform() -> void:
	if _barrel_carrier == null or not is_instance_valid(_barrel_carrier):
		_barrel_carrier = null
		return
	var shift := _barrel_carrier.global_position - _barrel_carrier_pos
	_barrel_carrier_pos = _barrel_carrier.global_position
	if shift != Vector2.ZERO:
		move_and_collide(shift)


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


## Spikes are areas, so the solid barrel ray passes over them. Check the barrel separately,
## so standing on your barrel in a spike row kills like touching them with the body.
func _barrel_in_spikes() -> bool:
	var query := PhysicsRayQueryParameters2D.create(global_position,
		global_position + gun_dir() * GUN_REACH, collision_mask, [get_rid()])
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and hit.collider is Spikes


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
	# A refill keeps the held charge and its slow motion (see _slowmo_kept); momentum is untouched.
	debug_event.emit("Refilled in air at %s  ammo %d" % [position.round(), shots])
	return true


## Starts the death animation (spikes break the gun, everything else just gets swallowed).
## The animation moves you back to the checkpoint partway through.
func die(reason := "hazard") -> void:
	if not _fx.start_death(reason):
		return
	_death_reason = reason
	cancel_charge()
	debug_event.emit("Died (%s) at %s" % [reason, position.round()])


## Called by the death animation once the portal has closed: back to the checkpoint.
func respawn_after_death() -> void:
	_respawning_from_death = true
	respawn(_death_reason)
	_respawning_from_death = false
	died.emit()


func respawn(reason := "reset") -> void:
	# A level load or checkpoint skip in the middle of dying cancels the animation.
	if _fx != null and _fx.dying and not _respawning_from_death:
		_fx.cancel()
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
	if _fx.gun_hidden:
		return
	var aim := gun_dir()
	# Soft warm halo so the gun reads against the dark wall.
	draw_circle(Vector2.ZERO, 26.0, Color(1.0, 0.8, 0.55, 0.07))
	draw_circle(Vector2.ZERO, 17.0, Color(1.0, 0.8, 0.55, 0.08))
	_draw_gun(aim)
	_draw_shells()
	if charging:
		_draw_charge_blocks()

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
	# Fresh out of the respawn portal: shining clean for a moment.
	tint = tint.lerp(Color(1.7, 1.6, 1.25), _fx.glow())
	var flip := -1.0 if aim.x < 0.0 else 1.0
	draw_set_transform(_fx.tremble(), aim.angle(), Vector2(1, flip))
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


## Charge meter under the shells: five little blocks that fill left to right,
## orange while charging, gold and pulsing at full power.
const CHARGE_BLOCKS := 5
func _draw_charge_blocks() -> void:
	var block := Vector2(6, 4)
	var gap := 2.0
	var width := CHARGE_BLOCKS * block.x + (CHARGE_BLOCKS - 1) * gap
	var origin := Vector2(-width / 2.0, 30)
	draw_rect(Rect2(origin - Vector2(2, 2), Vector2(width + 4, block.y + 4)), Color(0.09, 0.05, 0.12))
	var filled := charge_fraction() * CHARGE_BLOCKS
	var full := charge_fraction() >= 1.0
	var pulse := 0.75 + 0.25 * sin(Time.get_ticks_msec() * 0.02)
	for i in CHARGE_BLOCKS:
		var at := origin + Vector2(i * (block.x + gap), 0)
		var amount := clampf(filled - i, 0.0, 1.0)
		draw_rect(Rect2(at, block), Color(0.25, 0.17, 0.25))
		if amount > 0.0:
			var colour := Color(1.0, 0.85, 0.3) * pulse if full else Color(0.95, 0.45, 0.15).lerp(Color(1.0, 0.7, 0.2), float(i) / CHARGE_BLOCKS)
			colour.a = 1.0
			draw_rect(Rect2(at, Vector2(block.x * amount, block.y)), colour)
			draw_rect(Rect2(at, Vector2(block.x * amount, 1)), colour.lightened(0.4))

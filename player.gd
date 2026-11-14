extends CharacterBody2D

signal died
signal shot_fired(blast_direction: Vector2)
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


func _ready() -> void:
	add_to_group("player")


func _unhandled_input(event: InputEvent) -> void:
	if OS.is_debug_build() and event is InputEventKey and event.keycode == KEY_F7:
		if event.pressed and not event.echo:
			debug_flying = not debug_flying
			velocity = Vector2.ZERO
			charging = false
			charge_seconds = 0.0
			pending_shot = Vector2.ZERO
			debug_event.emit("Debug flight on" if debug_flying else "Debug flight off")
		get_viewport().set_input_as_handled()
		return

	if debug_flying:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if shots > 0 and pending_shot == Vector2.ZERO and not charging:
				charging = true
				charge_seconds = 0.0
			return
		if not charging:
			return
		charging = false
		var direction: Vector2 = event.position - get_global_transform_with_canvas().origin
		if direction.length_squared() >= 1.0:
			pending_shot = -direction.normalized()
			pending_power = lerpf(MIN_CHARGED_RECOIL, RECOIL_SPEED, charge_fraction())


func charge_fraction() -> float:
	return clampf(charge_seconds / FULL_CHARGE_TIME, 0.0, 1.0)


func is_air_charging() -> bool:
	return charging and shots == 1 and not is_on_floor()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		charging = false
		charge_seconds = 0.0


func _physics_process(delta: float) -> void:
	if debug_flying:
		var cursor_offset := get_global_mouse_position() - global_position
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
		var blast_direction := -pending_shot
		pending_shot = Vector2.ZERO
		shots -= 1
		shot_fired.emit(blast_direction)

	var time_scale := AIR_CHARGE_TIME_SCALE if is_air_charging() else 1.0
	velocity.y += GRAVITY * delta * time_scale
	var was_grounded := is_on_floor()
	var was_on_ceiling := is_on_ceiling()
	var before := velocity
	# Scale movement for this step and keep collision-adjusted momentum for release.
	velocity *= time_scale
	move_and_slide()
	velocity /= time_scale
	var bounced := _apply_bounce(before)
	if is_on_ceiling() and not was_on_ceiling:
		debug_event.emit("Hit ceiling at %s" % position.round())
	if is_on_floor() and not bounced:
		if not was_grounded:
			debug_event.emit("Landed at %s  ammo refilled" % position.round())
			if shots == 1:
				charging = false
				charge_seconds = 0.0
		shots = MAX_SHOTS
		velocity.x = 0.0
		var ground := _floor_collider()
		if ground != null and ground.has_method("on_player_landed"):
			ground.on_player_landed(self)

	flash = maxf(0.0, flash - delta)
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
	var body_color := Color(0.85, 0.1, 0.1) if flash > 0.0 else Color.BLACK
	draw_circle(Vector2.ZERO, 12.0, body_color, true, -1.0, true)
	for index in range(MAX_SHOTS):
		var pip := Vector2(-5 + index * 10, -21)
		draw_circle(pip, 3.0, Color.BLACK, index < shots, -1.0 if index < shots else 1.0, true)

	if charging:
		draw_rect(Rect2(-25, -36, 50, 7), Color.WHITE)
		draw_rect(Rect2(-25, -36, 50 * charge_fraction(), 7), Color.BLACK)
		draw_rect(Rect2(-25, -36, 50, 7), Color.BLACK, false, 1.0)

	if shots == 0 or debug_flying:
		return

	var direction := -get_local_mouse_position().normalized()
	var tip := direction * 38.0
	draw_line(direction * 16.0, tip, Color.DIM_GRAY, 2.0, true)
	draw_line(tip, tip - direction.rotated(0.55) * 8.0, Color.DIM_GRAY, 2.0, true)
	draw_line(tip, tip - direction.rotated(-0.55) * 8.0, Color.DIM_GRAY, 2.0, true)

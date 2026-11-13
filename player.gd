extends CharacterBody2D

signal debug_event(message: String)

const MAX_SHOTS := 2
const GRAVITY := 880.0
const RECOIL_SPEED := 580.0
const MIN_CHARGED_RECOIL := 380.0
const FULL_CHARGE_TIME := 0.40
const AIR_CHARGE_TIME_SCALE := 0.35
const MAX_RISE_SPEED := 620.0
const FALL_MOMENTUM_DAMPING := 0.5
const RESPAWN_Y := 740.0

@onready var respawn_position := position
var shots := MAX_SHOTS
var pending_shot := Vector2.ZERO
var pending_power := RECOIL_SPEED
var charging := false
var charge_seconds := 0.0


func _unhandled_input(event: InputEvent) -> void:
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
	if charging:
		charge_seconds = minf(charge_seconds + delta, FULL_CHARGE_TIME)

	if pending_shot != Vector2.ZERO:
		var before := velocity
		if shots == 1 and velocity.y > 0.0 and pending_shot.y < 0.0:
			velocity.y *= 1.0 + pending_shot.y * FALL_MOMENTUM_DAMPING
		var recovery := before.y - velocity.y
		velocity += pending_shot * pending_power
		var capped := velocity.y < -MAX_RISE_SPEED
		velocity.y = maxf(velocity.y, -MAX_RISE_SPEED)
		debug_event.emit("Shot %d power=%.0f aim=%s  velocity %s -> %s  recovery=%.1f  cap=%s" % [
			MAX_SHOTS - shots + 1, pending_power, pending_shot.snapped(Vector2(0.01, 0.01)),
			before.round(), velocity.round(), recovery, "yes" if capped else "no",
		])
		pending_shot = Vector2.ZERO
		shots -= 1

	var time_scale := AIR_CHARGE_TIME_SCALE if is_air_charging() else 1.0
	velocity.y += GRAVITY * delta * time_scale
	var was_grounded := is_on_floor()
	var was_on_ceiling := is_on_ceiling()
	# Scale movement for this step and keep collision-adjusted momentum for release.
	velocity *= time_scale
	move_and_slide()
	velocity /= time_scale
	if is_on_ceiling() and not was_on_ceiling:
		debug_event.emit("Hit ceiling at %s" % position.round())
	if is_on_floor():
		if not was_grounded:
			debug_event.emit("Landed at %s  ammo refilled" % position.round())
			if shots == 1:
				charging = false
				charge_seconds = 0.0
		shots = MAX_SHOTS
		velocity.x = 0.0

	var fall_limit := minf(RESPAWN_Y, respawn_position.y + 420.0)
	if position.y > fall_limit or position.x < -24.0 or position.x > 1304.0:
		respawn("out of bounds")

	queue_redraw()


func respawn(reason := "reset") -> void:
	debug_event.emit("Respawn (%s) %s -> %s" % [reason, position.round(), respawn_position.round()])
	position = respawn_position
	velocity = Vector2.ZERO
	shots = MAX_SHOTS
	pending_shot = Vector2.ZERO
	charging = false
	charge_seconds = 0.0


func _draw() -> void:
	draw_circle(Vector2.ZERO, 12.0, Color.BLACK, true, -1.0, true)
	for index in range(MAX_SHOTS):
		var pip := Vector2(-5 + index * 10, -21)
		draw_circle(pip, 3.0, Color.BLACK, index < shots, -1.0 if index < shots else 1.0, true)

	if charging:
		draw_rect(Rect2(-25, -36, 50, 7), Color.WHITE)
		draw_rect(Rect2(-25, -36, 50 * charge_fraction(), 7), Color.BLACK)
		draw_rect(Rect2(-25, -36, 50, 7), Color.BLACK, false, 1.0)

	if shots == 0:
		return

	var direction := -get_local_mouse_position().normalized()
	var tip := direction * 38.0
	draw_line(direction * 16.0, tip, Color.DIM_GRAY, 2.0, true)
	draw_line(tip, tip - direction.rotated(0.55) * 8.0, Color.DIM_GRAY, 2.0, true)
	draw_line(tip, tip - direction.rotated(-0.55) * 8.0, Color.DIM_GRAY, 2.0, true)

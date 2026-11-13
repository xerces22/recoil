extends CharacterBody2D

signal died
signal shot_fired

const MAX_SHOTS := 2
const GRAVITY := 880.0
const RECOIL_SPEED := 580.0
const MAX_RISE_SPEED := 730.0
const FALL_MOMENTUM_DAMPING := 0.5
const RESPAWN_Y := 740.0
## Share of current velocity kept when a turret bolt hits.
const KNOCKBACK_KEEP := 0.25

@onready var respawn_position := position
var shots := MAX_SHOTS
var pending_shot := Vector2.ZERO
var flash := 0.0


func _ready() -> void:
	add_to_group("player")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var direction: Vector2 = event.position - get_global_transform_with_canvas().origin
		if shots > 0 and pending_shot == Vector2.ZERO and direction.length_squared() >= 1.0:
			pending_shot = -direction.normalized()


func _physics_process(delta: float) -> void:
	if pending_shot != Vector2.ZERO:
		if shots == 1 and velocity.y > 0.0 and pending_shot.y < 0.0:
			velocity.y *= 1.0 + pending_shot.y * FALL_MOMENTUM_DAMPING
		velocity += pending_shot * RECOIL_SPEED
		velocity.y = maxf(velocity.y, -MAX_RISE_SPEED)
		pending_shot = Vector2.ZERO
		shots -= 1
		shot_fired.emit()

	velocity.y += GRAVITY * delta
	var before := velocity
	move_and_slide()
	var bounced := _apply_bounce(before)
	if is_on_floor() and not bounced:
		shots = MAX_SHOTS
		velocity.x = 0.0
		var ground := _floor_collider()
		if ground != null and ground.has_method("on_player_landed"):
			ground.on_player_landed(self)

	flash = maxf(0.0, flash - delta)
	var fall_limit := minf(RESPAWN_Y, respawn_position.y + 420.0)
	if position.y > fall_limit or position.x < -24.0 or position.x > 1304.0:
		die()

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


## Mouth bite: no shots until you land again.
func lose_shells() -> void:
	shots = 0
	pending_shot = Vector2.ZERO
	flash = 0.35


func die() -> void:
	respawn()
	died.emit()


func respawn() -> void:
	position = respawn_position
	velocity = Vector2.ZERO
	shots = MAX_SHOTS
	pending_shot = Vector2.ZERO
	flash = 0.0


func _draw() -> void:
	var body_color := Color(0.85, 0.1, 0.1) if flash > 0.0 else Color.BLACK
	draw_circle(Vector2.ZERO, 12.0, body_color, true, -1.0, true)
	for index in range(MAX_SHOTS):
		var pip := Vector2(-5 + index * 10, -21)
		draw_circle(pip, 3.0, Color.BLACK, index < shots, -1.0 if index < shots else 1.0, true)

	if shots == 0:
		return

	var direction := -get_local_mouse_position().normalized()
	var tip := direction * 38.0
	draw_line(direction * 16.0, tip, Color.DIM_GRAY, 2.0, true)
	draw_line(tip, tip - direction.rotated(0.55) * 8.0, Color.DIM_GRAY, 2.0, true)
	draw_line(tip, tip - direction.rotated(-0.55) * 8.0, Color.DIM_GRAY, 2.0, true)

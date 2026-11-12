extends CharacterBody2D

const MAX_SHOTS := 2
const GRAVITY := 880.0
const RECOIL_SPEED := 580.0
const RESPAWN_Y := 740.0

@onready var respawn_position := position
var shots := MAX_SHOTS
var pending_shot := Vector2.ZERO


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var direction: Vector2 = event.position - get_global_transform_with_canvas().origin
		if shots > 0 and pending_shot == Vector2.ZERO and direction.length_squared() >= 1.0:
			pending_shot = -direction.normalized()


func _physics_process(delta: float) -> void:
	velocity.y += GRAVITY * delta
	if pending_shot != Vector2.ZERO:
		velocity += pending_shot * RECOIL_SPEED
		pending_shot = Vector2.ZERO
		shots -= 1

	move_and_slide()
	if is_on_floor():
		shots = MAX_SHOTS
		velocity.x = 0.0

	var fall_limit := minf(RESPAWN_Y, respawn_position.y + 420.0)
	if position.y > fall_limit or position.x < -24.0 or position.x > 1304.0:
		respawn()

	queue_redraw()


func respawn() -> void:
	position = respawn_position
	velocity = Vector2.ZERO
	shots = MAX_SHOTS
	pending_shot = Vector2.ZERO


func _draw() -> void:
	draw_circle(Vector2.ZERO, 12.0, Color.BLACK, true, -1.0, true)
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

extends Area2D
## Turret bolt. Pushes the player and disappears when it hits anything solid.

const RADIUS := 6.0

var direction := Vector2.RIGHT
var speed := 260.0
var knockback := 420.0
var life := 5.0


func _ready() -> void:
	var shape := CircleShape2D.new()
	shape.radius = RADIUS
	var collision := CollisionShape2D.new()
	collision.shape = shape
	add_child(collision)
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	position += direction * speed * delta
	life -= delta
	if life <= 0.0:
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		body.knock(direction * knockback)
	queue_free()


func _draw() -> void:
	draw_line(Vector2.ZERO, -direction * 18.0, Color(1, 0.45, 0.1, 0.45), 8.0)
	draw_circle(Vector2.ZERO, RADIUS + 2.0, Color(0.95, 0.25, 0.05))
	draw_circle(Vector2.ZERO, RADIUS - 2.0, Color(1, 0.85, 0.35))

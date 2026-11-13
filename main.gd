extends Node2D

const RecoilPlayer = preload("res://player.gd")
const LOWER_CHECKPOINT := Rect2(475, -90, 160, 16)
const UPPER_CHECKPOINT := Rect2(695, -650, 155, 16)
const CHECKPOINTS: Array[Rect2] = [LOWER_CHECKPOINT, UPPER_CHECKPOINT]
const FINISH := Rect2(520, -1350, 160, 16)
const PLATFORMS: Array[Rect2] = [
	Rect2(130, 560, 1020, 18),
	Rect2(680, 405, 210, 16),
	Rect2(390, 240, 185, 16),
	Rect2(255, 65, 150, 16),
	Rect2(645, 100, 150, 16),
	LOWER_CHECKPOINT,
	Rect2(770, -265, 160, 16),
	Rect2(480, -460, 180, 16),
	UPPER_CHECKPOINT,
	Rect2(870, -805, 200, 16),
	Rect2(630, -975, 180, 16),
	Rect2(785, -1170, 185, 16),
	FINISH,
]
const SPIKED_BLOCKS: Array[Rect2] = [
	Rect2(540, 310, 115, 20),
	Rect2(625, -190, 110, 20),
	Rect2(615, -565, 74, 20),
	Rect2(655, -808, 70, 80),
	Rect2(1005, -1000, 65, 85),
	Rect2(545, -1140, 67, 72),
	Rect2(680, -1305, 75, 65),
]
const SPIKED_EDGES: Array[Rect2] = [
	Rect2(390, 240, 20, 26),
	Rect2(255, 65, 40, 26),
	Rect2(755, 100, 40, 26),
	Rect2(890, -265, 40, 26),
	Rect2(620, -460, 40, 26),
	Rect2(1050, -805, 20, 26),
	Rect2(630, -975, 20, 26),
	Rect2(950, -1170, 20, 26),
]
const SPIKE_WIDTH := 20

@onready var player: RecoilPlayer = $Player
@onready var camera: Camera2D = $Camera2D
@onready var instructions: Label = $HUD/Instructions
var active_checkpoint := -1


func _ready() -> void:
	for rect in PLATFORMS:
		add_platform(rect)
	for rect in SPIKED_BLOCKS:
		add_platform(rect)
		add_spike_row(Rect2(rect.position, Vector2(rect.size.x, 26)))
	for row in SPIKED_EDGES:
		add_spike_row(row)


func _process(_delta: float) -> void:
	camera.position.y = minf(360.0, player.position.y - 120.0)
	camera.force_update_scroll()
	if player.is_on_floor():
		var feet := player.position + Vector2(0, 13)
		if FINISH.has_point(feet):
			if instructions.text != "Course clear.":
				instructions.text = "Course clear."
				player.debug_event.emit("Course clear at %s" % player.position.round())
		else:
			for index in range(active_checkpoint + 1, CHECKPOINTS.size()):
				var platform := CHECKPOINTS[index]
				if platform.has_point(feet):
					active_checkpoint = index
					player.respawn_position = Vector2(platform.get_center().x, platform.position.y - 14)
					player.debug_event.emit("Checkpoint %d at %s" % [index + 1, player.position.round()])
					instructions.text = "Checkpoint set. Save your second shot for the turn."
					queue_redraw()
					break


func _draw() -> void:
	for index in range(CHECKPOINTS.size()):
		var label := "CHECKPOINT SET" if index <= active_checkpoint else "CHECKPOINT"
		draw_string(ThemeDB.fallback_font, CHECKPOINTS[index].position + Vector2(12, -10),
			label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.BLACK)
	draw_string(ThemeDB.fallback_font, FINISH.position + Vector2(12, -10),
		"FINISH", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.BLACK)


func add_platform(rect: Rect2) -> void:
	var body := StaticBody2D.new()
	body.position = rect.get_center()

	var shape := RectangleShape2D.new()
	shape.size = rect.size
	var collision := CollisionShape2D.new()
	collision.shape = shape
	body.add_child(collision)
	add_child(body)

	var surface := Polygon2D.new()
	surface.polygon = PackedVector2Array([
		rect.position,
		Vector2(rect.end.x, rect.position.y),
		rect.end,
		Vector2(rect.position.x, rect.end.y),
	])
	surface.color = Color.BLACK
	add_child(surface)


func add_spike_row(row: Rect2) -> void:
	var hazard := Area2D.new()
	hazard.position = row.position
	hazard.body_entered.connect(_on_spike_entered)

	# Cover the top surface continuously, including the seams between triangles.
	var strip := RectangleShape2D.new()
	strip.size = Vector2(row.size.x, 4.0)
	var strip_collision := CollisionShape2D.new()
	strip_collision.position = Vector2(row.size.x / 2.0, -1.0)
	strip_collision.shape = strip
	hazard.add_child(strip_collision)

	var count := ceili(row.size.x / SPIKE_WIDTH)
	var width := row.size.x / count
	for index in range(count):
		var left := index * width
		var points := PackedVector2Array([
			Vector2(left, 0),
			Vector2(left + width / 2.0, -row.size.y),
			Vector2(left + width, 0),
		])
		var collision := CollisionPolygon2D.new()
		collision.polygon = points
		hazard.add_child(collision)

		var triangle := Polygon2D.new()
		triangle.polygon = points
		triangle.color = Color.BLACK
		hazard.add_child(triangle)
	add_child(hazard)


func _on_spike_entered(body: Node2D) -> void:
	if body == player:
		player.respawn.call_deferred("spikes")

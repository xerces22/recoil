@tool
class_name RisingHazard
extends Node2D
## Flood that rises from below once the player climbs above `trigger_y`. Touching it kills.
## Keep this node at the level origin (0, 0).

const WIDTH := 1280.0

## The chase starts once the player is higher (smaller y) than this.
@export var trigger_y := 0.0:
	set(value):
		trigger_y = value
		queue_redraw()
## How far below the player it appears when the chase starts.
@export var start_gap := 380.0
@export var speed := 50.0
## Speed added every second, so long climbs get tighter.
@export var acceleration := 2.0
## It never falls further behind than this, so fast players still feel it.
@export var max_gap := 460.0
## Reaching a checkpoint pushes it back to at least this far below.
@export var checkpoint_gap := 300.0

var active := false
var stopped := false
var surface_y := 0.0
var _speed := 0.0
var _wave := 0.0


func _ready() -> void:
	z_index = 10


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or stopped:
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	var player_y := player.global_position.y
	if not active:
		if player_y >= trigger_y:
			return
		active = true
		surface_y = player_y + start_gap
		_speed = speed
	_speed += acceleration * delta
	surface_y = minf(surface_y - _speed * delta, player_y + max_gap)
	_wave += delta
	if player_y + 12.0 >= surface_y:
		player.die.call_deferred("flood")
	queue_redraw()


## Called when the player respawns.
func reset() -> void:
	active = false
	queue_redraw()


## Called when the level is cleared.
func stop() -> void:
	stopped = true
	active = false
	queue_redraw()


func give_breathing_room(player_y: float) -> void:
	if active:
		surface_y = maxf(surface_y, player_y + checkpoint_gap)
		_speed = maxf(speed, _speed * 0.8)


func _draw() -> void:
	if Engine.is_editor_hint() or not active:
		if Engine.is_editor_hint():
			draw_dashed_line(Vector2(0, trigger_y), Vector2(WIDTH, trigger_y), Color(0.85, 0.1, 0.1, 0.6), 2.0, 12.0)
			draw_string(ThemeDB.fallback_font, Vector2(12, trigger_y - 6), "FLOOD STARTS ABOVE THIS LINE",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.85, 0.1, 0.1))
		return
	var water := Color(0.85, 0.1, 0.1, 0.55)
	var points := PackedVector2Array()
	for x in range(0, int(WIDTH) + 41, 40):
		points.append(Vector2(x, surface_y + sin(_wave * 3.0 + x * 0.03) * 5.0))
	points.append(Vector2(WIDTH + 40, surface_y + 2000))
	points.append(Vector2(0, surface_y + 2000))
	draw_colored_polygon(points, water)

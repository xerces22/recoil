@tool
class_name HexOrb
extends Node2D

signal broken

const REACH := 200.0
const HIT_DOT := 0.95371695
@export var spots := PackedVector2Array([Vector2.ZERO])
var hits := 0
var origin := Vector2.ZERO

func _ready() -> void:
	origin = position

func try_hit(from: Vector2, direction: Vector2) -> bool:
	if hits >= 3:
		return false
	var offset := global_position - from
	if offset.length() > REACH or (not offset.is_zero_approx() and direction.dot(offset.normalized()) < HIT_DOT):
		return false
	var query := PhysicsRayQueryParameters2D.create(from, global_position)
	var player := get_tree().get_first_node_in_group("player") as CollisionObject2D
	if player != null:
		query.exclude = [player.get_rid()]
	if not get_world_2d().direct_space_state.intersect_ray(query).is_empty():
		return false
	hits += 1
	if hits == 3:
		hide()
		broken.emit()
	else:
		position = origin + spots[mini(hits, spots.size() - 1)]
		queue_redraw()
	return true

func _draw() -> void:
	draw_circle(Vector2.ZERO, 20.0, Color("#6b3695"))
	draw_arc(Vector2.ZERO, 20.0, 0.0, TAU, 32, Color("#dbc3ed"), 2.0, true)
	draw_string(ThemeDB.fallback_font, Vector2(-4.0, 5.0), str(3 - hits))

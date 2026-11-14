@tool
class_name HexOrb
extends Node2D
## Level goal. Blast it 3 times: aim the cursor at it and fire while it's in range.
## After each hit it hops to the next spot in `spots`. The third hit shatters it.

signal hit(hits_left: int)
signal shattered

const RADIUS := 22.0
## A shot hits if the orb is this close and inside the cone.
const RANGE := 220.0
## Half-angle of the blast cone, in degrees.
const CONE := 35.0
## Seconds the orb flies between spots. It can't be hit while moving.
const HOP_TIME := 0.6

@export var hits := 3
## Where it hops to after each hit, relative to the orb's parent (same space as `position`).
## Needs `hits - 1` entries. Missing entries mean it stays put.
@export var spots: Array[Vector2] = []:
	set(value):
		spots = value
		queue_redraw()

var hits_left := 3
var _player: Node2D
var _hopping := false
var _flash := 0.0
var _time := 0.0
var _shards: Array[Dictionary] = []
var _broken := false


func _ready() -> void:
	z_index = 5
	hits_left = hits
	if Engine.is_editor_hint():
		return
	_player = get_tree().get_first_node_in_group("player") as Node2D
	if _player != null:
		_player.shot_fired.connect(_on_shot)


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_time += delta
	_flash = maxf(0.0, _flash - delta)
	for shard in _shards:
		shard.v.y += 600.0 * delta
		shard.p += shard.v * delta
		shard.life -= delta
	_shards = _shards.filter(func(s: Dictionary) -> bool: return s.life > 0.0)
	queue_redraw()


## True if a blast from `from` toward `aim` would hit the orb right now.
func in_blast(from: Vector2, aim: Vector2) -> bool:
	if _broken or _hopping:
		return false
	var to := global_position - from
	var dist := to.length()
	if dist > RANGE + RADIUS:
		return false
	if dist > RADIUS and absf(rad_to_deg(aim.angle_to(to))) > CONE:
		return false
	# Walls block the blast.
	var query := PhysicsRayQueryParameters2D.create(from, global_position)
	query.exclude = [(_player as CollisionObject2D).get_rid()]
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()


func _on_shot() -> void:
	var aim: Vector2 = _player.get("muzzle_dir")
	if not in_blast(_player.global_position, aim):
		return
	hits_left -= 1
	_flash = 0.3
	_burst(6)
	hit.emit(hits_left)
	_player.emit_signal("debug_event", "Orb hit at %s  %d left" % [global_position.round(), hits_left])
	if hits_left <= 0:
		_broken = true
		_burst(24)
		shattered.emit()
		return
	var index := hits - hits_left - 1
	if index < spots.size():
		_hopping = true
		var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(self, "position", spots[index], HOP_TIME)
		tween.tween_callback(func() -> void: _hopping = false)


func _burst(count: int) -> void:
	for i in count:
		var angle := randf() * TAU
		_shards.append({p = Vector2.ZERO, v = Vector2.from_angle(angle) * randf_range(120, 320), life = randf_range(0.4, 0.9)})


func _draw() -> void:
	if Engine.is_editor_hint():
		_draw_orb(0)
		# Show where it hops, numbered.
		for i in spots.size():
			var at := spots[i] - position
			draw_dashed_line(Vector2.ZERO if i == 0 else spots[i - 1] - position, at, Color(0.7, 0.3, 1.0, 0.7), 2.0, 8.0)
			draw_arc(at, RADIUS, 0, TAU, 24, Color(0.7, 0.3, 1.0, 0.8), 2.0)
			draw_string(ThemeDB.fallback_font, at + Vector2(-5, 6), str(i + 2), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.7, 0.3, 1.0))
		return

	for shard in _shards:
		var a := clampf(shard.life * 2.0, 0.0, 1.0)
		draw_rect(Rect2(shard.p - Vector2(3, 3), Vector2(6, 6)), Color(0.75, 0.4, 1.0, a))
	if _broken:
		return
	_draw_cone()
	_draw_orb(hits - hits_left)


func _draw_orb(cracks: int) -> void:
	var pulse := 1.0 + 0.06 * sin(_time * 3.0)
	var bob := Vector2(0, sin(_time * 2.0) * 4.0)
	var r := RADIUS * pulse
	draw_circle(bob, r + 14.0, Color(0.6, 0.2, 0.9, 0.18))
	draw_circle(bob, r + 6.0, Color(0.6, 0.2, 0.9, 0.3))
	draw_circle(bob, r, Color(1, 1, 1) if _flash > 0.0 else Color(0.45, 0.12, 0.7))
	draw_circle(bob + Vector2(-6, -6), r * 0.45, Color(0.85, 0.6, 1.0, 0.8))
	draw_circle(bob + Vector2(-8, -9), r * 0.15, Color(1, 1, 1, 0.9))
	# One crack per hit taken.
	var crack := Color(0.1, 0.02, 0.15)
	if cracks >= 1:
		draw_polyline(PackedVector2Array([bob + Vector2(-4, -r), bob + Vector2(2, -8), bob + Vector2(-3, 0), bob + Vector2(5, 9)]), crack, 2.0)
	if cracks >= 2:
		draw_polyline(PackedVector2Array([bob + Vector2(r, 2), bob + Vector2(8, 4), bob + Vector2(3, -3), bob + Vector2(-9, 6), bob + Vector2(-r + 2, 10)]), crack, 2.0)
	# Hits-left pips above the orb.
	for i in hits:
		var at := bob + Vector2((i - (hits - 1) / 2.0) * 14.0, -r - 18.0)
		if i < hits_left:
			draw_circle(at, 4.0, Color(0.85, 0.6, 1.0))
		else:
			draw_arc(at, 4.0, 0, TAU, 12, Color(0.5, 0.35, 0.6), 1.5)


## While the player charges near the orb, show the blast cone so they learn the range.
func _draw_cone() -> void:
	if _player == null or not _player.get("charging") or _hopping:
		return
	var from := _player.global_position
	if from.distance_to(global_position) > RANGE + 120.0:
		return
	var aim: Vector2 = (_player._world_mouse_position() - from).normalized()
	if aim == Vector2.ZERO:
		return
	var on := in_blast(from, aim)
	var colour := Color(1.0, 0.85, 0.3, 0.28) if on else Color(1, 1, 1, 0.12)
	var points := PackedVector2Array([to_local(from)])
	for i in 9:
		var angle := aim.angle() + deg_to_rad(lerpf(-CONE, CONE, i / 8.0))
		points.append(to_local(from + Vector2.from_angle(angle) * RANGE))
	draw_colored_polygon(points, colour)

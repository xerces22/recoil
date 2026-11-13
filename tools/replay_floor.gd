extends SceneTree
## Replays the solver's shot plans in the REAL game (barrel, capsule body, spikes, wisps) to prove
## each intended jump of a floor works, not just in the solver's simplified physics.
##
## 1. python tools/floor_solver.py levels/<floor>.tscn --plans=tools/plans_NN.json
## 2. Copy this file to the project root (tools/ has a .gdignore), then:
##    Godot --headless --path . -s res://_replay_tmp.gd -- <level index, 0-based> tools/plans_NN.json
##
## Each plan starts the player at the take-off spot with the plan's speed and shells, points the
## barrel the way a player would, fires at the plan's times, and checks it reaches the target:
## landing on the named surface, touching the named wisp, or rising out of the exit hole.

const DT := 1.0 / 60.0
const MAX_FRAMES := 200

var main: Node
var player: CharacterBody2D
var level: Node2D


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var index := int(args[0])
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args[1]))
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.load_level(index)
	await physics_frame
	player = main.get_node("Player")
	level = main.floors[0]
	var total_fail := 0
	print("REPLAY ", data["floor"])
	for hop in data["hops"]:
		var plans: Array = hop["plans"]
		var ok := 0
		for plan in plans:
			if await _try(plan, hop["to"]):
				ok += 1
		var mark := "ok  " if ok > 0 else "FAIL"
		if ok == 0:
			total_fail += 1
		print("  %s %24s -> %-20s %2d / %2d plans work in the real game" % [mark, hop["from"], hop["to"], ok, plans.size()])
	print("RESULT: ", "OK" if total_fail == 0 else "%d hops FAILED" % total_fail)
	quit(total_fail)


## Moving platforms are frozen at the end of their path the plan uses ("Name@start" / "Name@end"),
## which is what a player gets by waiting for the platform to arrive.
func _place_movers(plan: Dictionary) -> void:
	for node in level.get_children():
		if node is MovingPlatform:
			var at_end := false
			for key in ["src", "dst"]:
				if plan.get(key, "") == node.name + "@end":
					at_end = true
			node._running = false
			node.position = node._origin + (node.travel if at_end else Vector2.ZERO)


func _reset_world(skip_ring: String) -> void:
	# The flood follows the player; each try teleports them, so start every try with it reset.
	for flood in main.floods:
		flood.reset()
	for ring in main.refills:
		ring.reset()
		if ring.name == skip_ring:
			ring.available = false
			ring._cooldown = 999.0


func _hold_aim(dir: Vector2) -> void:
	# The barrel points opposite to where the shot sends you.
	player.gun_angle = (-dir).angle()
	player.forced_aim = player.global_position - dir * 300.0


func _try(plan: Dictionary, target: String) -> bool:
	if player._fx.dying:
		player.respawn("replay reset")
	_reset_world(plan["skip_ring"])
	_place_movers(plan)
	var p: Array = plan["plan"]
	var d1 := Vector2(p[1], p[2])
	var d2 := Vector2(p[4], p[5])
	var t1: int = roundi(p[0] / DT)
	var t2: int = roundi(p[3] / DT) if p[3] >= 0.0 else -1
	player.position = Vector2(plan["x"], plan["y"])
	player.velocity = Vector2(plan["vx"], plan["vy"])
	player.shots = int(plan["shells"])
	player.pending_shot = Vector2.ZERO
	player.charging = false
	_hold_aim(d1)
	var deaths_before: int = main.deaths
	var target_node := level.get_node_or_null(target)
	var exit := level.get_node_or_null("Exit") as Node2D
	for frame in MAX_FRAMES:
		if frame == t1:
			player.pending_shot = d1.normalized()
			player.pending_power = d1.length()
		if frame == t1 + 2 and t2 >= 0:
			_hold_aim(d2)  # Swing the barrel to the second shot's aim during the flight.
		if t2 >= 0 and frame == t2:
			player.pending_shot = d2.normalized()
			player.pending_power = d2.length()
		player.forced_aim = player.global_position + Vector2.from_angle(player.gun_angle) * 300.0
		await physics_frame
		if player._fx.dying or main.deaths != deaths_before:
			player.respawn("replay died")
			return false
		if frame <= t1:
			continue
		if target == "EXIT":
			if exit != null and player.global_position.y < exit.global_position.y - 24.0:
				return true
		elif target_node is ShellRefill:
			if player.global_position.distance_to(target_node.global_position) <= 26.0:
				return true
		elif target_node != null:
			for ground in player.standing_on:
				if ground == target_node or (ground != null and ground.get_parent() == target_node):
					return true
	return false

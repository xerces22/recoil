extends SceneTree
## Loads the real game headless and checks the tower:
## every floor loads, each Entry sits on the Exit below, and the player can stand at each Start.
## Run:  Godot --headless --path . -s res://tools/check_tower.gd
## (Also runs from a copy outside tools/, since tools/ has a .gdignore.)

var fails := 0


func check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	var main: Node = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var player: CharacterBody2D = main.get_node("Player")
	var count: int = main.FLOORS.size()
	check(main.floors.size() == count, "tower loads all %d floors" % count)
	for i in range(1, count):
		var below: Node2D = main.floors[i - 1]
		var above: Node2D = main.floors[i]
		var exit := below.get_node_or_null("Exit") as Node2D
		var entry := above.get_node_or_null("Entry") as Node2D
		check(exit != null and entry != null and exit.global_position.distance_to(entry.global_position) < 0.5,
			"floor %d entry sits on floor %d exit" % [i + 1, i])
	for i in count:
		main.load_level(i)
		for f in 45:
			await physics_frame
		var start: Vector2 = (main.floors[0].get_node("Start") as Node2D).global_position
		var on_floor: bool = player.is_on_floor() or (player.get("braced") == true)
		check(main.deaths == 0 and player.position.distance_to(start) < 40.0 and on_floor,
			"floor %d: player stands at Start (%s, deaths %d)" % [i + 1, player.position.round(), main.deaths])
	print("RESULT: ", "OK" if fails == 0 else "%d FAILED" % fails)
	quit(fails)

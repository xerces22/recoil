extends SceneTree
## Temporary: New Game -> storyboard -> floor 1, clicking through like a player.
var game

func _initialize() -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	_run.call_deferred()

func _click() -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	e.position = Vector2(640, 360)
	Input.parse_input_event(e)
	var u := e.duplicate()
	u.pressed = false
	Input.parse_input_event(u)

func _esc() -> void:
	var e := InputEventKey.new()
	e.keycode = KEY_ESCAPE
	e.pressed = true
	Input.parse_input_event(e)

func _run() -> void:
	for f in 10: await process_frame
	game.settings_node_start() if game.has_method("settings_node_start") else game.new_game()
	var intro = null
	for n in game.get_children():
		if n.get_script() and n.get_script().resource_path.ends_with("story_intro.gd"): intro = n
	print("intro found: ", intro != null, " paused: ", paused)
	await create_timer(1.0).timeout
	_esc()
	await create_timer(0.5).timeout
	print("after esc still showing: ", is_instance_valid(intro) and intro.visible, " panel ", intro._index)
	root.get_texture().get_image().save_png("C:/Users/ADMINI~1/AppData/Local/Temp/claude/63d1d5c5218fb70f/da5d9af7-35ba-4982-92ad-bec5d6307247/scratchpad/shots/flow_a.png")
	var steps := 0
	while is_instance_valid(intro) and steps < 400:
		_click()
		await create_timer(0.3).timeout
		steps += 1
	print("intro done after clicks: ", steps, " paused: ", paused)
	await create_timer(1.0).timeout
	root.get_texture().get_image().save_png("C:/Users/ADMINI~1/AppData/Local/Temp/claude/63d1d5c5218fb70f/da5d9af7-35ba-4982-92ad-bec5d6307247/scratchpad/shots/flow_b.png")
	print("player pos: ", game.player.global_position)
	quit()

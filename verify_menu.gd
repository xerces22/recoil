extends Node

@onready var game = get_parent()
@onready var ui = game.get_node_or_null("Settings")
var failures := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	run.call_deferred()

func check(ok: bool, title: String) -> void:
	if not ok:
		failures += 1
	print("PASS " if ok else "FAIL ", title)

func frames(n := 4) -> void:
	for i in n:
		await get_tree().process_frame

func mouse(button: int, pressed: bool, p := Vector2(850, 415)) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	event.position = p
	event.global_position = p
	get_window().push_input(event, true)

func click(control: Control, fraction := 0.5) -> void:
	var rect := control.get_global_rect()
	var p := rect.position + rect.size * Vector2(fraction, 0.5)
	var move := InputEventMouseMotion.new()
	move.position = p
	move.global_position = p
	get_window().push_input(move, true)
	mouse(MOUSE_BUTTON_LEFT, true, p)
	mouse(MOUSE_BUTTON_LEFT, false, p)

func esc() -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.pressed = true
	get_window().push_input(event, true)

func button(label: String) -> Button:
	for b in ui._panel.find_children("*", "Button", true, false):
		if b.text == label:
			return b
	return null

func choose(picker: OptionButton, index: int) -> void:
	click(picker)
	await frames()
	var popup := picker.get_popup()
	check(popup.visible, picker.tooltip_text + " dropdown opens")
	var p := Vector2(42, 8 + (index + 0.5) * float(popup.size.y - 16) / picker.item_count)
	var motion := InputEventMouseMotion.new()
	motion.position = p
	popup.push_input(motion, true)
	for pressed in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = pressed
		e.position = p
		popup.push_input(e, true)
	await frames()

func run() -> void:
	await frames(12)
	ui = game.get_node("Settings")
	var player = game.player
	var prefs = game.preferences
	var tree := get_tree()
	var hud = game.get_node("HUD")
	check(tree.paused and ui._menu_heading.text == "Recoil Launcher" and not hud.visible, "title is startup screen")
	click(ui._title_actions.get_child(1))
	await frames()
	check(ui._overlay.visible and tree.paused, "title Settings")
	if OS.get_cmdline_user_args().has("reload"):
		check(prefs.values.Music == 31 and not player.show_aim_guide and player.shoot_button == MOUSE_BUTTON_RIGHT, "audio, guide and bind persisted")
		check(Engine.max_fps == 144 and not prefs.values.vsync and not game.get_node("Backdrop").show_decor, "performance settings persisted")
		check(prefs.is_fullscreen() and prefs.values.resolution == Vector2i(960, 540), "display settings persisted")
		click(button("Restore Defaults"))
		await frames(12)
		check(prefs.values == prefs.DEFAULTS and Engine.max_fps == 0 and not prefs.is_fullscreen(), "Restore Defaults applies and resets display")
		check(DisplayServer.window_get_vsync_mode() == DisplayServer.VSYNC_ENABLED and player.shoot_button == MOUSE_BUTTON_LEFT and game.get_node("Backdrop").show_decor, "VSync, controls and backdrop reset")
		for bus in ["Master", "Music", "SFX"]:
			check(ui._sliders[bus].value == 100 and not AudioServer.is_bus_mute(AudioServer.get_bus_index(bus)), bus + " reset")
		var file := ConfigFile.new()
		check(file.load(prefs.save_path) == OK and file.get_value("settings", "frame_cap") == 0, "defaults saved to user://")
		tree.quit(int(failures > 0))
		return

	check(game.music.bus == &"Music" and game.music.playing and player._blast.bus == &"SFX" and player._reload.bus == &"SFX" and player._land.bus == &"SFX", "actual game audio routes")
	for bus in ["Master", "Music", "SFX"]:
		var slider: HSlider = ui._sliders[bus]
		click(slider, 0.002)
		check(AudioServer.is_bus_mute(AudioServer.get_bus_index(bus)), bus + " reaches silence")
		slider.value = 31
		check(ui._readouts[bus].text == "31%" and is_equal_approx(AudioServer.get_bus_volume_linear(AudioServer.get_bus_index(bus)), 0.31), bus + " applies gain")
	click(ui._tabs[1])
	await frames()
	check(ui._pages[1].visible, "Graphics tab")
	click(ui._display)
	await frames(12)
	check(prefs.is_fullscreen() and ui._display.text == "Fullscreen" and not ui._resolution.get_parent().visible, "fullscreen applies and hides resolution")
	click(ui._display)
	await frames(12)
	check(not prefs.is_fullscreen() and ui._display.text == "Windowed", "windowed applies")
	click(ui._vsync)
	check(DisplayServer.window_get_vsync_mode() == DisplayServer.VSYNC_DISABLED, "VSync off applies")
	for i in prefs.available_resolutions().size():
		if DisplayServer.window_get_size() == Vector2i(960, 540):
			break
		click(ui._resolution)
		await frames(8)
	check(prefs.values.resolution == Vector2i(960, 540) and DisplayServer.window_get_size() == Vector2i(960, 540), "window resolution applies")
	for cap in [30, 60, 120, 144]:
		click(ui._frame_cap)
		await frames()
		check(Engine.max_fps == cap, "cap %d applies" % cap)
	check(Engine.max_fps == 144, "frame cap applies")
	click(ui._background)
	click(ui._aim)
	check(not game.get_node("Backdrop").show_decor and not player.show_aim_guide, "background and guide toggle")
	click(ui._display)
	await frames(12)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	await frames(12)
	check(ui._display.text == "Windowed", "external window change updates label")
	click(ui._display)
	await frames(12)
	check(prefs.is_fullscreen(), "fullscreen selected for relaunch")
	click(ui._tabs[2])
	await frames()
	click(ui._shoot)
	mouse(MOUSE_BUTTON_WHEEL_UP, true)
	check(ui._listening and player.shoot_button == MOUSE_BUTTON_LEFT, "scroll wheel rejected")
	mouse(MOUSE_BUTTON_RIGHT, true)
	mouse(MOUSE_BUTTON_RIGHT, false)
	check(player.shoot_button == MOUSE_BUTTON_RIGHT and not ui._listening, "rebind")
	click(button("Back"))
	await frames()
	check(tree.paused and ui._title_actions.visible, "Back returns to title")
	click(ui._title_actions.get_child(0))
	await frames(12)
	check(not tree.paused and hud.visible and game.current == 0 and game.tower_mode, "Play starts fresh tower")
	player.forced_aim = player.global_position + Vector2(0, 500)
	mouse(MOUSE_BUTTON_LEFT, true)
	mouse(MOUSE_BUTTON_LEFT, false)
	check(not player.charging and player.shots == 2, "old shoot binding disabled")
	mouse(MOUSE_BUTTON_RIGHT, true)
	await frames(15)
	check(player.charging and player.charge_fraction() > 0.0, "rebound button charges")
	mouse(MOUSE_BUTTON_RIGHT, false)
	await frames(10)
	check(player.shots == 1 and player._blast.playing, "rebound button fires")
	mouse(MOUSE_BUTTON_RIGHT, true)
	check(player.is_air_charging(), "midair slow aim")
	click(ui._pause_button)
	await frames()
	var frozen: Vector2 = player.position
	var elapsed: float = game.elapsed
	var velocity: Vector2 = player.velocity
	await frames(8)
	check(tree.paused and frozen == player.position and elapsed == game.elapsed and not player.charging, "Pause freezes run and cancels charge")
	mouse(MOUSE_BUTTON_RIGHT, false)
	click(ui._pause_actions.get_child(2))
	await frames()
	click(button("Back"))
	await frames()
	check(tree.paused and ui._pause_actions.visible, "Back returns to pause")
	click(ui._pause_actions.get_child(0))
	check(not tree.paused and player.shots == 1 and player.pending_shot == Vector2.ZERO and player.velocity == velocity, "Resume preserves state and spends no shell")
	esc()
	await frames()
	check(tree.paused, "Esc pauses")
	esc()
	check(not tree.paused, "Esc resumes")
	var old_floor: Node = game.floors[1]
	var first_floor: Node = game.floors[0]
	first_floor.get_node("LeftTurn").reached = true
	old_floor.get_node("LiftStop").reached = true
	player.global_position = old_floor.get_node("Start").global_position
	await frames(6)
	esc()
	await frames()
	click(ui._pause_actions.get_child(1))
	check(not tree.paused and game.current == 1 and game.floors[1] != old_floor and game.floors[0] == first_floor and first_floor.get_node("LeftTurn").reached and not game.floors[1].get_node("LiftStop").reached and player.global_position == game.floors[1].get_node("Start").global_position, "Restart Level reloads current tower floor only")
	game.load_level(2)
	await frames()
	esc()
	await frames()
	click(ui._pause_actions.get_child(1))
	check(not game.tower_mode and game.level_index == 2 and game.floors.size() == 1, "Restart Level reloads standalone test floor")
	esc()
	await frames()
	click(ui._pause_actions.get_child(3))
	check(tree.paused and ui._title_actions.visible and not hud.visible, "Quit returns to main menu")
	await frames()
	click(ui._title_actions.get_child(0))
	check(game.tower_mode and game.current == 0 and game.elapsed < 0.1 and game.deaths == 0, "Play starts a new run after quit")
	tree.quit(int(failures > 0))


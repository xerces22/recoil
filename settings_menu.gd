extends CanvasLayer
## Title, pause, floor select, credits and settings.
## Title: dark side panel on the left (logo, options, Exit at the bottom), the live castle
## zoomed in on the hatted shotgun on the right, with drifting motes and a slow colour wash.

const Preferences = preload("res://game_preferences.gd")
const FONT := preload("res://assets/fonts/PressStart2P-Regular.ttf")
const LOGO := preload("res://assets/sprites/logo/logo_color.png")
const CREAM := Color("#f6e8cb")
const GOLD := Color("#ffd583")
const LILAC := Color("#bdb0c7")
const ACCENT := Color("#57e08f")
const INK := Color("#170b22")
const PURPLE := Color("#3b1d57")
const TitleVoid = preload("res://title_void.gd")
const EDGE := Color("#3a2b48")
const PANEL_SIZE := Vector2(708, 560)
## Width of the dark side panel the menu options sit on.
const SIDE_W := 440.0

const CURSOR_POINTER := preload("res://assets/sprites/ui/cursor_pointer.png")

const SFX_HOVER := preload("res://assets/sfx/impactWood_light_001.ogg")
const SFX_NEW := preload("res://assets/sfx/shotgun_reload.wav")
const SFX_CONTINUE := preload("res://assets/sfx/impactMetal_heavy_000.ogg")
const SFX_SETTINGS := preload("res://assets/sfx/impactPlank_medium_000.ogg")
const SFX_CREDITS := preload("res://assets/sfx/impactWood_heavy_000.ogg")
const SFX_EXIT := preload("res://assets/sfx/impactSoft_heavy_000.ogg")
const SFX_BACK := preload("res://assets/sfx/impactWood_light_002.ogg")
const SFX_FLOOR := preload("res://assets/sfx/checkpoint_fire.ogg")

const CREDITS := [
	["Developed by", "luhcalmdevs (nullMuath and xerces)"],
	["Art", "Crumpaloo (Whimsy Hallow), Quintino Pixels, Leozlk (Shotguns Only)"],
	["Hat", "Stetson Cowboy Hat by Jordan Irwin (AntumDeluge), CC BY 4.0"],
	["Music", "HydroGene, Pro Sensory (Alex McCulloch), Sudocolon"],
	["Sound", "Ben Jaszczak et al., SpringySpringo, AntumDeluge, SketchMan3, Ogrebane, rubberduck, Kenney"],
	["Font", "Press Start 2P by CodeMan38"],
	["Cursor", "Original pixel art by the Cursed Shotgun team"],
	["", "Thanks for playing!"],
]

signal start_requested
signal restart_requested
signal quit_requested

enum Screen { TITLE, PLAY, PAUSE, SETTINGS, CREDITS, FLOORS }

var preferences: Preferences
var player
## main.gd: floor titles, saved progress and the title camera.
var game
var _screen := Screen.TITLE
var _base := Screen.TITLE
var _settings_return := Screen.TITLE
var _pause_button: Button
## Set by main.gd once the witch is beaten: no pausing through the ending and end card.
var pause_locked := false:
	set(value):
		pause_locked = value
		if _pause_button != null:
			_pause_button.visible = _screen == Screen.PLAY and not value
var _menu_overlay: Control
var _menu_heading: Label
var _title_actions: VBoxContainer
var _pause_actions: VBoxContainer
var _floor_actions: VBoxContainer
## Continue on the title; becomes Level Select once the witch is beaten.
var _continue_item: MenuItem
var _logo: TextureRect
var _credits: Control
var _particles: Node2D
var _void: Control
var _tip_floor: Label
var _tip_text: Label
var _fader: ColorRect
var _busy := false
var _sfx: AudioStreamPlayer
var _time := 0.0
var _overlay: ColorRect
var _panel: Control
var _tabs: Array[Button] = []
var _pages: Array[VBoxContainer] = []
var _sliders: Dictionary = {}
var _readouts: Dictionary = {}
var _aim: Button
var _tips: Button
var _display: Button
var _display_hint: Label
var _fps_readout: Label
var _vsync: Button
var _frame_cap: Button
var _resolution: Button
var _background: Button
var _render_quality: Button
var _shoot: Button
var _cursor: Button
var _controls_hint: Label
var _listening := false
var _active_tab := 0
var _swallow_release := MOUSE_BUTTON_NONE
var _web_request_time := 0


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	var theme := _castle_theme()
	_build_run_menu(theme)

	_overlay = ColorRect.new()
	_overlay.name = "SettingsOverlay"
	_overlay.color = Color(0, 0, 0, 0)
	_overlay.theme = theme
	_overlay.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.hide()

	var center := _right_center(_overlay)
	_panel = Control.new()
	_panel.custom_minimum_size = PANEL_SIZE
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.draw.connect(_draw_frame.bind(_panel))
	center.add_child(_panel)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 16)
	_panel.add_child(layout)
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.offset_left = 42
	layout.offset_right = -42
	layout.offset_top = 34
	layout.offset_bottom = -30
	layout.add_child(_label("Settings", 20, ACCENT))

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	layout.add_child(tabs)
	var pages := Control.new()
	pages.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(pages)
	for title in ["Audio", "Graphics", "Controls", "Stats"]:
		var tab := _button(title)
		tab.toggle_mode = true
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.pressed.connect(func() -> void:
			_play(SFX_HOVER, 1.1, -10.0)
			_select_tab(_tabs.find(tab)))
		_tabs.append(tab)
		tabs.add_child(tab)
		var page := VBoxContainer.new()
		page.add_theme_constant_override("separation", 8)
		pages.add_child(page)
		page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_pages.append(page)

	_add_volume("Master Volume", "Master")
	_add_volume("Music Volume", "Music")
	_add_volume("Sound Effects Volume", "SFX")

	if preferences.display_supported() or OS.has_feature("web"):
		_display = _graphics_button()
		# A press is required for browser fullscreen permission.
		_display.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
		_display.pressed.connect(_toggle_display)
		_add_row(_pages[1], "Display Mode", _display)
	if preferences.desktop_window_supported():
		_vsync = _graphics_button()
		_vsync.pressed.connect(func() -> void:
			preferences.set_graphics("vsync", not preferences.values.vsync)
			_refresh()
		)
		_add_row(_pages[1], "VSync", _vsync)
	_frame_cap = _graphics_button()
	_frame_cap.pressed.connect(func() -> void:
		var next := (Preferences.FRAME_CAPS.find(preferences.values.frame_cap) + 1) % Preferences.FRAME_CAPS.size()
		preferences.set_graphics("frame_cap", Preferences.FRAME_CAPS[next])
		_refresh()
	)
	_add_row(_pages[1], "Frame Rate Cap", _frame_cap)
	if preferences.desktop_window_supported() and not preferences.available_resolutions().is_empty():
		_resolution = _graphics_button()
		_resolution.pressed.connect(func() -> void:
			var choices := preferences.available_resolutions()
			if not choices.is_empty():
				var next := (choices.find(DisplayServer.window_get_size()) + 1) % choices.size()
				preferences.set_graphics("resolution", choices[next])
				_refresh()
		)
		_add_row(_pages[1], "Resolution", _resolution)
	_background = _graphics_button()
	_background.pressed.connect(func() -> void:
		preferences.set_graphics("background_detail", not preferences.values.background_detail)
		_refresh()
	)
	_add_row(_pages[1], "Background Detail", _background)
	_render_quality = _graphics_button()
	_render_quality.pressed.connect(func() -> void:
		preferences.set_graphics("render_divisor", 2 if preferences.values.render_divisor == 1 else 1)
		_refresh()
	)
	_add_row(_pages[1], "Render Quality", _render_quality)
	_aim = _graphics_button()
	_aim.pressed.connect(func() -> void:
		preferences.set_aim_guide(not preferences.values.aim_guide)
		_refresh()
	)
	_add_row(_pages[1], "Aim Guide", _aim)
	_tips = _graphics_button()
	_tips.pressed.connect(func() -> void:
		preferences.set_floor_tips(not preferences.values.floor_tips)
		_refresh()
	)
	_add_row(_pages[1], "Floor Tips", _tips)
	_cursor = _graphics_button()
	_cursor.pressed.connect(func() -> void:
		preferences.set_cursor_visible(not preferences.values.cursor_visible)
		_refresh()
	)
	_add_row(_pages[1], "Cursor While Playing", _cursor)
	_display_hint = _label("", 9, LILAC)
	_display_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_pages[1].add_child(_display_hint)
	_fps_readout = _label("", 9, GOLD)
	_pages[1].add_child(_fps_readout)

	_shoot = _button("")
	_shoot.pressed.connect(_listen_for_button)
	_add_row(_pages[2], "Shoot", _shoot)
	_pages[2].add_child(_label("That's the whole list.", 11, LILAC))
	# Stats page: filled in each time it's opened (see _refresh_stats).
	_controls_hint = _label("", 10, GOLD)
	_pages[2].add_child(_controls_hint)

	var footer := HBoxContainer.new()
	layout.add_child(footer)
	var defaults := _button("Restore Defaults")
	defaults.pressed.connect(_restore_defaults)
	footer.add_child(defaults)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(gap)
	var back := _button("Back")
	back.pressed.connect(func() -> void:
		_play(SFX_BACK, 1.0, -8.0)
		close())
	footer.add_child(back)

	_build_credits(theme)
	_build_fader()
	_select_tab(0)
	_refresh()
	_show_screen(Screen.TITLE)


# ---------------------------------------------------------------- side menu

func _build_run_menu(theme: Theme) -> void:
	_sfx = AudioStreamPlayer.new()
	_sfx.bus = &"SFX"
	_sfx.max_polyphony = 6
	add_child(_sfx)

	_pause_button = _button("Pause")
	_pause_button.name = "PauseButton"
	_pause_button.theme = theme
	_pause_button.position = Vector2(24, 16)
	_pause_button.size = Vector2(116, 40)
	_pause_button.focus_mode = Control.FOCUS_NONE
	_pause_button.pressed.connect(_show_screen.bind(Screen.PAUSE))
	add_child(_pause_button)

	# Title backdrop: the gun tumbling through a purple void (covers the paused game).
	_void = TitleVoid.new()
	_void.left = SIDE_W
	add_child(_void)
	_void.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_particles = Node2D.new()
	add_child(_particles)
	_add_motes(ACCENT, 38, Vector2(2, 4), 7.0)
	_add_motes(Color("#ff9a3c"), 14, Vector2(2, 3), 5.0)
	_add_motes(Color("#c9a6ff"), 18, Vector2(1, 2), 9.0)

	_menu_overlay = Control.new()
	_menu_overlay.theme = theme
	_menu_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_menu_overlay)
	_menu_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var side := Control.new()
	side.mouse_filter = Control.MOUSE_FILTER_IGNORE
	side.draw.connect(_draw_side.bind(side))
	_menu_overlay.add_child(side)
	side.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	side.offset_right = SIDE_W + 8.0
	side.resized.connect(side.queue_redraw)

	_logo = TextureRect.new()
	_logo.texture = LOGO
	_logo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_logo.position = Vector2(44, 26)
	_logo.size = Vector2(300, 236)
	_logo.pivot_offset = _logo.size / 2.0
	_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	side.add_child(_logo)

	_menu_heading = _label("Paused", 28, ACCENT)
	_menu_heading.position = Vector2(44, 52)
	side.add_child(_menu_heading)
	# Pause shows the current floor and its tip (the HUD no longer does).
	_tip_floor = _label("", 11, GOLD)
	_tip_floor.position = Vector2(44, 116)
	side.add_child(_tip_floor)
	_tip_text = _label("", 10, LILAC)
	_tip_text.position = Vector2(44, 144)
	_tip_text.size = Vector2(SIDE_W - 84, 110)
	_tip_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip_text.add_theme_constant_override("line_spacing", 6)
	side.add_child(_tip_text)

	_title_actions = _action_list(side, 290)
	_pause_actions = _action_list(side, 290)
	_floor_actions = _action_list(side, 286)
	_floor_actions.add_theme_constant_override("separation", 0)

	_add_action(_title_actions, "New Game", SFX_NEW, _new_game)
	_continue_item = _add_action(_title_actions, "Continue", SFX_CONTINUE, _show_screen.bind(Screen.FLOORS))
	_add_action(_title_actions, "Settings", SFX_SETTINGS, open)
	_add_action(_title_actions, "Credits", SFX_CREDITS, _toggle_credits)
	if not OS.has_feature("web"):
		_title_actions.add_child(_spacer(96))
		_add_action(_title_actions, "Exit", SFX_EXIT, _exit_game)

	_add_action(_pause_actions, "Resume", SFX_CONTINUE, _show_screen.bind(Screen.PLAY))
	_add_action(_pause_actions, "Restart Floor", SFX_NEW, _restart)
	_add_action(_pause_actions, "Settings", SFX_SETTINGS, open)
	_pause_actions.add_child(_spacer(150))
	_add_action(_pause_actions, "Quit to Menu", SFX_EXIT, _quit_run)


func _spacer(height: float) -> Control:
	var gap := Control.new()
	gap.custom_minimum_size.y = height
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return gap


func _action_list(side: Control, top: float) -> VBoxContainer:
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	list.position = Vector2(36, top)
	list.custom_minimum_size.x = SIDE_W - 60.0
	list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	side.add_child(list)
	return list


func _add_action(parent: VBoxContainer, title: String, sound: AudioStream, action: Callable,
		size_px := 20) -> MenuItem:
	var item := MenuItem.new(title, size_px, sound)
	item.hover_sound = SFX_HOVER
	item.play_sound = _play
	item.activated.connect(action)
	parent.add_child(item)
	return item


func _add_motes(colour: Color, amount: int, size_range: Vector2, life: float) -> void:
	var motes := CPUParticles2D.new()
	motes.amount = amount
	motes.lifetime = life
	motes.preprocess = life
	motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	motes.emission_rect_extents = Vector2(700, 20)
	motes.position = Vector2(640, 760)
	motes.direction = Vector2(0, -1)
	motes.spread = 20.0
	motes.gravity = Vector2(0, -4)
	motes.initial_velocity_min = 25.0
	motes.initial_velocity_max = 70.0
	motes.angular_velocity_min = -40.0
	motes.angular_velocity_max = 40.0
	motes.scale_amount_min = size_range.x
	motes.scale_amount_max = size_range.y
	var ramp := Gradient.new()
	ramp.set_color(0, Color(colour, 0.0))
	ramp.set_color(1, Color(colour, 0.0))
	ramp.add_point(0.2, Color(colour, 0.75))
	ramp.add_point(0.75, Color(colour, 0.5))
	motes.color_ramp = ramp
	_particles.add_child(motes)


func _play(stream: AudioStream, pitch := 1.0, volume_db := -6.0) -> void:
	_sfx.stream = stream
	_sfx.pitch_scale = pitch
	_sfx.volume_db = volume_db
	_sfx.play()


func _draw_side(side: Control) -> void:
	var h := side.size.y
	side.draw_rect(Rect2(0, 0, SIDE_W, h), INK)
	# Faint brick courses so the panel reads as castle stone, not a flat box.
	for y in range(0, int(h), 24):
		side.draw_rect(Rect2(0, y, SIDE_W, 1), Color(PURPLE, 0.35))
		var shift := 0 if (y / 24) % 2 == 0 else 24
		for x in range(shift, int(SIDE_W), 48):
			side.draw_rect(Rect2(x, y, 1, 24), Color(PURPLE, 0.22))
	# Darken toward the bottom so the options sit on calmer ground.
	side.draw_polygon(PackedVector2Array([Vector2(0, h * 0.4), Vector2(SIDE_W, h * 0.4), Vector2(SIDE_W, h), Vector2(0, h)]),
		PackedColorArray([Color(INK, 0.0), Color(INK, 0.0), Color(INK, 0.85), Color(INK, 0.85)]))
	# Pixel edge: dark gap, purple trim, green line, with studs every 48 px.
	side.draw_rect(Rect2(SIDE_W - 2, 0, 2, h), Color("#0b0512"))
	side.draw_rect(Rect2(SIDE_W, 0, 6, h), PURPLE)
	side.draw_rect(Rect2(SIDE_W + 2, 0, 2, h), ACCENT.darkened(0.35))
	for y in range(20, int(h), 48):
		side.draw_rect(Rect2(SIDE_W - 1, y, 8, 8), PURPLE.lightened(0.25))
		side.draw_rect(Rect2(SIDE_W + 1, y + 2, 4, 4), ACCENT)
	# Divider under the logo and footer.
	side.draw_rect(Rect2(40, 272, SIDE_W - 80, 2), Color(PURPLE, 0.9))
	side.draw_rect(Rect2(40, 272, 60, 2), ACCENT)
	side.draw_rect(Rect2(40, 662, SIDE_W - 80, 2), Color(PURPLE, 0.9))
	side.draw_string(FONT, Vector2(40, 690), "Developed by luhcalmdevs", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(LILAC, 0.75))
	side.draw_string(FONT, Vector2(40, 706), "v1.0", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(LILAC, 0.45))


## A full-screen holder that centres its child in the area right of the side panel.
func _right_center(parent: Control) -> CenterContainer:
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.offset_left = SIDE_W - 30.0
	return center


func _build_credits(theme: Theme) -> void:
	_credits = Control.new()
	_credits.theme = theme
	_credits.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_credits)
	_credits.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := Control.new()
	panel.custom_minimum_size = Vector2(640, 520)
	panel.draw.connect(_draw_frame.bind(panel))
	_right_center(_credits).add_child(panel)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 14)
	panel.add_child(layout)
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.offset_left = 42
	layout.offset_right = -42
	layout.offset_top = 34
	layout.offset_bottom = -30
	layout.add_child(_label("Credits", 20, ACCENT))
	for line: Array in CREDITS:
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 5)
		if line[0] != "":
			row.add_child(_label(line[0], 9, LILAC))
		var body := _label(line[1], 11, GOLD if line[0] == "" else CREAM)
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(body)
		layout.add_child(row)
	_credits.hide()


func _toggle_credits() -> void:
	_show_screen(_base if _screen == Screen.CREDITS else Screen.CREDITS)


func _rebuild_floors() -> void:
	for child in _floor_actions.get_children():
		_floor_actions.remove_child(child)
		child.queue_free()
	var titles: Array[String] = game.floor_titles()
	var reached: int = game.reached_floor()
	for i in titles.size():
		var open_floor := i <= reached
		var label := "%2d  %s" % [i + 1, titles[i].to_upper() if open_floor else "?"]
		var item := _add_action(_floor_actions, label, SFX_FLOOR, _continue_from.bind(i), 10)
		item.set_locked(not open_floor)
		item.custom_minimum_size.y = 28
		if open_floor:
			_set_row_stats(item, "floor_%d" % i)
	# The boss has her own row under the floors, always there (locked until you beat her once),
	# so the menu keeps the same height either way.
	_floor_actions.add_child(_spacer(8))
	var beaten: bool = game.boss_beaten()
	var boss := _add_action(_floor_actions, "    BOSS  %s" % ("MRS. SANDWITCH" if beaten else "?"),
		SFX_FLOOR, _fight_boss, 10)
	boss.set_locked(not beaten)
	boss.custom_minimum_size.y = 28
	if beaten:
		_set_row_stats(boss, "boss")
	_floor_actions.add_child(_spacer(6))
	_add_action(_floor_actions, "Back", SFX_BACK, _show_screen.bind(Screen.TITLE), 16)


## Time spent and deaths on the right of a floor-select row.
func _set_row_stats(item: MenuItem, key: String) -> void:
	item.detail_time = GameStats.format_time(GameStats.time_of(key))
	item.detail_deaths = GameStats.deaths_of(key)
	item.queue_redraw()


func _fight_boss() -> void:
	_fade_through(func() -> void:
		_show_screen(Screen.PLAY)
		game.start_boss_from_menu())


func _new_game() -> void:
	_fade_through(func() -> void:
		_show_screen(Screen.PLAY)
		start_requested.emit())


func _continue_from(index: int) -> void:
	_fade_through(func() -> void:
		_show_screen(Screen.PLAY)
		game.continue_from(index))


func _exit_game() -> void:
	_fade_through(get_tree().quit, 0.5)


func _restart() -> void:
	_fade_through(func() -> void:
		restart_requested.emit()
		_show_screen(Screen.PLAY))


func _quit_run() -> void:
	_fade_through(func() -> void:
		quit_requested.emit()
		_show_screen(Screen.TITLE))


# ---------------------------------------------------------------- transitions

## Black fade over everything: fade out, run `action` while the screen is black, fade back in.
## Input is blocked during the fade so a double click can't start two things.
func _fade_through(action: Callable, out_time := 0.35) -> void:
	if _busy:
		return
	_busy = true
	_fader.mouse_filter = Control.MOUSE_FILTER_STOP
	var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(_fader, "color:a", 1.0, out_time).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(action)
	tween.tween_interval(0.15)
	tween.tween_property(_fader, "color:a", 0.0, 0.5).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(func() -> void:
		_fader.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_busy = false)


func _build_fader() -> void:
	var top := CanvasLayer.new()
	top.layer = 100
	top.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(top)
	_fader = ColorRect.new()
	_fader.color = Color(0, 0, 0, 1)
	_fader.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(_fader)
	_fader.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# The game opens from the black intro: fade the title in.
	var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(_fader, "color:a", 0.0, 0.7).set_trans(Tween.TRANS_SINE)


## Small entrance animations so screens slide in instead of popping.
func _animate_in(screen: Screen) -> void:
	var targets: Array[CanvasItem] = []
	match screen:
		Screen.TITLE:
			targets = [_title_actions, _logo]
		Screen.PAUSE:
			targets = [_pause_actions, _menu_heading, _tip_floor, _tip_text]
		Screen.FLOORS:
			targets = [_floor_actions]
		Screen.SETTINGS:
			targets = [_overlay]
		Screen.CREDITS:
			targets = [_credits]
	var delay := 0.0
	for item in targets:
		var control := item as Control
		var rest_x: float = control.get_meta("rest_x", control.position.x)
		control.set_meta("rest_x", rest_x)
		control.modulate.a = 0.0
		control.position.x = rest_x - 26.0
		var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel()
		tween.tween_property(control, "modulate:a", 1.0, 0.25).set_delay(delay)
		tween.tween_property(control, "position:x", rest_x, 0.3).set_delay(delay) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		delay += 0.05
	# Floor list: each row drops in a beat after the one above.
	if screen == Screen.FLOORS:
		var i := 0
		for row in _floor_actions.get_children():
			(row as Control).modulate.a = 0.0
			create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS) \
				.tween_property(row, "modulate:a", 1.0, 0.2).set_delay(0.04 * i)
			i += 1


func _show_screen(screen: Screen) -> void:
	player.cancel_shot()
	if screen != Screen.PLAY:
		GameStats.save()
	if screen in [Screen.TITLE, Screen.PAUSE, Screen.PLAY]:
		_base = screen
	_screen = screen
	var on_title := _base == Screen.TITLE
	get_tree().paused = screen != Screen.PLAY
	_pause_button.visible = screen == Screen.PLAY and not pause_locked
	_menu_overlay.visible = screen != Screen.PLAY
	_overlay.visible = screen == Screen.SETTINGS
	_credits.visible = screen == Screen.CREDITS
	_particles.visible = on_title
	_void.visible = on_title
	_tip_floor.visible = _base == Screen.PAUSE
	_tip_text.visible = _base == Screen.PAUSE
	_logo.visible = on_title
	_menu_heading.visible = _base == Screen.PAUSE
	_title_actions.visible = on_title and screen != Screen.FLOORS
	_pause_actions.visible = _base == Screen.PAUSE
	_floor_actions.visible = screen == Screen.FLOORS
	if _continue_item != null and game != null and screen == Screen.TITLE:
		_continue_item.text = "Level Select" if game.boss_beaten() else "Continue"
		_continue_item.button.text = _continue_item.text
	_apply_cursor()
	if game != null:
		# In-game HUD only while actually playing; menus get a clean screen.
		# Floor name and tips moved to the pause screen, so they stay off the HUD.
		game.get_node("HUD").visible = screen == Screen.PLAY
		game.title_label.visible = false
		game.instructions.visible = false
	if game != null and _base == Screen.PAUSE and game.level != null:
		var number: int = game.floor_numbers[game.current] + 1
		_tip_floor.text = "FLOOR %d  %s" % [number, String(game.level.title).to_upper()]
		_tip_text.text = game.level.hint
	_animate_in(screen)
	match screen:
		Screen.TITLE:
			_title_actions.get_child(0).button.grab_focus.call_deferred()
		Screen.PAUSE:
			_pause_actions.get_child(0).button.grab_focus.call_deferred()
		Screen.FLOORS:
			_rebuild_floors()
			var last: int = game.reached_floor()
			_floor_actions.get_child(last).button.grab_focus.call_deferred()
		Screen.SETTINGS:
			_tabs[_active_tab].grab_focus()


## One pixel arrow cursor everywhere. While playing it can be hidden in Settings.
func _apply_cursor() -> void:
	Input.set_custom_mouse_cursor(CURSOR_POINTER, Input.CURSOR_ARROW, Vector2(1, 1))
	Input.set_custom_mouse_cursor(CURSOR_POINTER, Input.CURSOR_POINTING_HAND, Vector2(1, 1))
	var hidden: bool = _screen == Screen.PLAY and not preferences.values.cursor_visible
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN if hidden else Input.MOUSE_MODE_VISIBLE


func open() -> void:
	if _screen == Screen.SETTINGS:
		close()
		return
	_settings_return = _base
	_refresh()
	_show_screen(Screen.SETTINGS)


func close() -> void:
	_end_listening()
	_show_screen(_settings_return)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == _swallow_release:
		if not event.pressed:
			_swallow_release = MOUSE_BUTTON_NONE
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed and not event.echo:
		get_viewport().set_input_as_handled()
		if _listening:
			_end_listening()
		elif _overlay.visible:
			close()
		elif _screen in [Screen.CREDITS, Screen.FLOORS]:
			_play(SFX_BACK, 1.0, -8.0)
			_show_screen(_base)
		elif _screen == Screen.PLAY and not pause_locked:
			_show_screen(Screen.PAUSE)
		elif _screen == Screen.PAUSE:
			_show_screen(Screen.PLAY)
		return
	if not _listening or not (event is InputEventMouseButton and event.pressed):
		return
	get_viewport().set_input_as_handled()
	if Preferences.MOUSE_NAMES.has(event.button_index):
		_swallow_release = event.button_index
		preferences.set_shoot_button(event.button_index)
		_end_listening()
	else:
		_controls_hint.text = "Use a mouse button. The scroll wheel is unavailable."


func _process(delta: float) -> void:
	_time += delta
	if _logo.visible:
		_logo.scale = Vector2.ONE * (1.0 + sin(_time * 1.3) * 0.012)
		_logo.rotation = sin(_time * 0.7) * 0.012
	if not _overlay.visible or _active_tab != 1:
		return
	_fps_readout.text = "Current FPS  %d" % Engine.get_frames_per_second()
	if _display != null:
		var actual := _display_mode_text()
		if _display.text != actual:
			_refresh()
	if _resolution != null and not preferences.is_fullscreen():
		_select_actual_resolution()
	if _web_request_time > 0 and Time.get_ticks_msec() >= _web_request_time:
		_web_request_time = 0
		_update_display_hint()


# ---------------------------------------------------------------- settings logic

func _toggle_display() -> void:
	preferences.set_fullscreen(not preferences.is_fullscreen())
	if OS.has_feature("web"):
		_web_request_time = Time.get_ticks_msec() + 500
	_refresh()


func _update_display_hint() -> void:
	var needs_click: bool = OS.has_feature("web") and preferences.values.fullscreen and not preferences.is_fullscreen()
	if OS.has_feature("web") and not preferences.display_supported():
		_display_hint.text = "Fullscreen is blocked here. Try a separate browser tab. Browser refresh limits FPS."
	elif needs_click:
		_display_hint.text = "Click Windowed to retry fullscreen. Browser refresh limits FPS."
	elif OS.has_feature("web"):
		_display_hint.text = "The browser controls refresh rate and canvas size."
	elif preferences.embedded_in_editor():
		_display_hint.text = "Disable Embed Game on Next Play to test window settings."
	elif preferences.values.vsync:
		_display_hint.text = "VSync can limit FPS to your display refresh rate."
	else:
		_display_hint.text = ""


func _display_mode_text() -> String:
	if preferences.is_fullscreen():
		return "Fullscreen"
	if OS.has_feature("web") and not preferences.display_supported():
		return "Unavailable"
	return "Windowed"


func _listen_for_button() -> void:
	_listening = true
	_shoot.text = "Press a mouse button"
	_controls_hint.text = "Esc cancels."


func _end_listening() -> void:
	_listening = false
	_controls_hint.text = ""
	_refresh()


func _restore_defaults() -> void:
	_end_listening()
	preferences.restore_defaults()
	_refresh()


func _select_tab(index: int) -> void:
	_active_tab = index
	if index == 3:
		_refresh_stats()
	for i in _pages.size():
		_pages[i].visible = i == index
		_tabs[i].set_pressed_no_signal(i == index)


func _refresh() -> void:
	for bus in _sliders:
		var value: int = preferences.values[bus]
		_sliders[bus].set_value_no_signal(value)
		_readouts[bus].text = "%d%%" % value
	_aim.text = "On" if preferences.values.aim_guide else "Off"
	_tips.text = "On" if preferences.values.floor_tips else "Off"
	_shoot.text = Preferences.MOUSE_NAMES[preferences.values.shoot_button]
	_cursor.text = "Shown" if preferences.values.cursor_visible else "Hidden"
	if _display != null:
		_display.text = _display_mode_text()
		_display.disabled = _display.text == "Unavailable"
	if _vsync != null:
		_vsync.text = "On" if DisplayServer.window_get_vsync_mode() == DisplayServer.VSYNC_ENABLED else "Off"
	var cap: int = preferences.values.frame_cap
	_frame_cap.text = "Unlimited  >" if cap == 0 else "%d FPS  >" % cap
	if _resolution != null:
		_resolution.get_parent().visible = not preferences.is_fullscreen()
		_select_actual_resolution()
	_background.text = "Full" if preferences.values.background_detail else "Reduced"
	_render_quality.text = "Native" if preferences.values.render_divisor == 1 else "50% Scale"
	_update_display_hint()


func _select_actual_resolution() -> void:
	var actual := DisplayServer.window_get_size()
	_resolution.disabled = preferences.available_resolutions().is_empty()
	_resolution.text = "%d x %d  >" % [actual.x, actual.y]


func _add_volume(title: String, bus: String) -> void:
	var slider := HSlider.new()
	slider.name = bus + "Volume"
	slider.max_value = 100
	slider.step = 1
	slider.custom_minimum_size = Vector2(242, 30)
	slider.scrollable = false
	var readout := _label("", 11, ACCENT)
	readout.custom_minimum_size.x = 52
	readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_sliders[bus] = slider
	_readouts[bus] = readout
	var row := _add_row(_pages[0], title, slider)
	row.add_child(readout)
	slider.value_changed.connect(func(value: float) -> void:
		preferences.set_volume(bus, int(value))
		readout.text = "%d%%" % int(value)
	)


func _add_row(page: VBoxContainer, title: String, control: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	page.add_child(row)
	var label := _label(title, 11)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	row.add_child(control)
	control.tooltip_text = title
	return row


func _label(value: String, font_size: int, tint := CREAM) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", tint)
	return label


func _button(value: String) -> Button:
	var button := Button.new()
	button.text = value
	button.custom_minimum_size.y = 40
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.mouse_entered.connect(func() -> void:
		if not button.disabled:
			_play(SFX_HOVER, randf_range(1.3, 1.5), -18.0))
	return button


func _graphics_button() -> Button:
	var button := _button("")
	button.custom_minimum_size = Vector2(210, 32)
	return button


# ---------------------------------------------------------------- look

func _draw_frame(panel: Control) -> void:
	var frame := Rect2(Vector2.ZERO, panel.size)
	panel.draw_rect(Rect2(Vector2(10, 12), frame.size), Color(0, 0, 0, 0.45))
	panel.draw_rect(frame, Color(INK, 0.96))
	panel.draw_rect(frame, EDGE, false, 2.0)
	panel.draw_rect(Rect2(Vector2(2, 2), Vector2(frame.size.x - 4, 3)), ACCENT)
	# Little pixel studs in the corners.
	for corner in [Vector2(8, 12), Vector2(frame.size.x - 12, 12),
			Vector2(8, frame.size.y - 12), frame.size - Vector2(12, 12)]:
		panel.draw_rect(Rect2(corner, Vector2(4, 4)), EDGE.lightened(0.25))


func _castle_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font = FONT
	theme.default_font_size = 11
	theme.set_stylebox("normal", "Button", _box(Color("#1d1427"), EDGE))
	theme.set_stylebox("hover", "Button", _box(Color("#261a33"), ACCENT.darkened(0.25)))
	theme.set_stylebox("pressed", "Button", _box(Color("#173323"), ACCENT))
	theme.set_stylebox("hover_pressed", "Button", _box(Color("#1c3d2a"), ACCENT))
	theme.set_stylebox("disabled", "Button", _box(Color("#140d1a"), Color("#2a2033")))
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.border_color = ACCENT
	focus.set_border_width_all(2)
	theme.set_stylebox("focus", "Button", focus)
	theme.set_color("font_color", "Button", CREAM)
	for state in ["font_hover_color", "font_focus_color"]:
		theme.set_color(state, "Button", Color.WHITE)
	for state in ["font_pressed_color", "font_hover_pressed_color"]:
		theme.set_color(state, "Button", ACCENT.lightened(0.3))
	theme.set_color("font_disabled_color", "Button", Color("#6d6178"))
	var track := _box(Color("#0e0913"), EDGE)
	track.set_content_margin_all(4)
	theme.set_stylebox("slider", "HSlider", track)
	var fill := StyleBoxFlat.new()
	fill.bg_color = ACCENT.darkened(0.3)
	fill.set_content_margin_all(4)
	theme.set_stylebox("grabber_area", "HSlider", fill)
	var fill_hi := fill.duplicate() as StyleBoxFlat
	fill_hi.bg_color = ACCENT
	theme.set_stylebox("grabber_area_highlight", "HSlider", fill_hi)
	theme.set_icon("grabber", "HSlider", _square(14, CREAM))
	theme.set_icon("grabber_highlight", "HSlider", _square(14, Color.WHITE))
	return theme


func _box(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(2)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style


func _square(px: int, colour: Color) -> ImageTexture:
	var image := Image.create(px, px, false, Image.FORMAT_RGBA8)
	image.fill(colour)
	image.fill_rect(Rect2i(0, px - 3, px, 3), colour.darkened(0.35))
	return ImageTexture.create_from_image(image)


## Stats tab: overall play time and deaths, then a row per floor you've reached and the boss.
func _refresh_stats() -> void:
	var page := _pages[3]
	for child in page.get_children():
		page.remove_child(child)
		child.queue_free()
	page.add_theme_constant_override("separation", 5)
	var summary := HBoxContainer.new()
	summary.add_theme_constant_override("separation", 40)
	page.add_child(summary)
	for pair in [["TOTAL PLAY TIME", GameStats.format_time(GameStats.time_of("total"))],
			["TOTAL DEATHS", str(GameStats.deaths_of("total"))],
			["HIGHEST FLOOR", "%d/%d" % [game.reached_floor() + 1, game.FLOORS.size()]]]:
		var box := VBoxContainer.new()
		box.add_child(_label(pair[0], 8, LILAC))
		box.add_child(_label(pair[1], 14, ACCENT))
		summary.add_child(box)
	page.add_child(_spacer(4))
	page.add_child(_stats_row("FLOOR", "TIME", "DEATHS", LILAC, 8))
	var titles: Array[String] = game.floor_titles()
	var reached: int = game.reached_floor()
	for i in titles.size():
		if i > reached:
			page.add_child(_stats_row("%2d  ?" % (i + 1), "-", "-", Color(LILAC, 0.5), 9))
			continue
		var key := "floor_%d" % i
		page.add_child(_stats_row("%2d  %s" % [i + 1, titles[i].to_upper()],
			GameStats.format_time(GameStats.time_of(key)), str(GameStats.deaths_of(key)), CREAM, 9))
	var beaten: bool = game.boss_beaten()
	page.add_child(_stats_row("    BOSS  %s" % ("MRS. SANDWITCH" if beaten else "?"),
		GameStats.format_time(GameStats.time_of("boss")) if beaten else "-",
		str(GameStats.deaths_of("boss")) if beaten else "-", GOLD if beaten else Color(LILAC, 0.5), 9))


func _stats_row(name_text: String, time_text: String, deaths_text: String, tint: Color, size_px: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	var title := _label(name_text, size_px, tint)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)
	for value in [[time_text, 110], [deaths_text, 90]]:
		var cell := _label(value[0], size_px, tint)
		cell.custom_minimum_size.x = value[1]
		cell.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(cell)
	return row

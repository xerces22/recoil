extends CanvasLayer

const Preferences = preload("res://game_preferences.gd")
const FONT := preload("res://assets/fonts/PressStart2P-Regular.ttf")
const CREAM := Color("#f6e8cb")
const GOLD := Color("#ffd583")
const LILAC := Color("#bdb0c7")
const PANEL_SIZE := Vector2(708, 574)

signal start_requested
signal restart_requested
signal quit_requested

enum Screen { TITLE, PLAY, PAUSE, SETTINGS }

var preferences: Preferences
var player
var _screen := Screen.TITLE
var _settings_return := Screen.TITLE
var _pause_button: Button
var _menu_overlay: ColorRect
var _menu_heading: Label
var _title_actions: VBoxContainer
var _pause_actions: VBoxContainer
var _shotgun_preview: Control
var _overlay: ColorRect
var _panel: Control
var _tabs: Array[Button] = []
var _pages: Array[VBoxContainer] = []
var _sliders: Dictionary = {}
var _readouts: Dictionary = {}
var _aim: Button
var _display: Button
var _display_hint: Label
var _fps_readout: Label
var _vsync: Button
var _frame_cap: Button
var _resolution: Button
var _background: Button
var _render_quality: Button
var _shoot: Button
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
	_overlay.color = Color("#110b18d9")
	_overlay.theme = theme
	_overlay.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_overlay)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.hide()

	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel = Control.new()
	_panel.custom_minimum_size = PANEL_SIZE
	_panel.draw.connect(_draw_frame.bind(_panel))
	center.add_child(_panel)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 16)
	_panel.add_child(layout)
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.offset_left = 42
	layout.offset_right = -42
	layout.offset_top = 36
	layout.offset_bottom = -30
	var heading := _label("Settings", 22)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(heading)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	layout.add_child(tabs)
	var pages := Control.new()
	pages.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(pages)
	for title in ["Audio", "Graphics", "Controls"]:
		var tab := _button(title)
		tab.toggle_mode = true
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.pressed.connect(_select_tab.bind(_tabs.size()))
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
	_display_hint = _label("", 9, LILAC)
	_display_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_pages[1].add_child(_display_hint)
	_fps_readout = _label("", 9, GOLD)
	_pages[1].add_child(_fps_readout)

	_shoot = _button("")
	_shoot.pressed.connect(_listen_for_button)
	_add_row(_pages[2], "Shoot", _shoot)
	_pages[2].add_child(_label("That's the whole list.", 11, LILAC))
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
	back.pressed.connect(close)
	footer.add_child(back)
	_select_tab(0)
	_refresh()
	_show_screen(Screen.TITLE)


func _build_run_menu(theme: Theme) -> void:
	_pause_button = _button("Pause")
	_pause_button.name = "PauseButton"
	_pause_button.theme = theme
	_pause_button.position = Vector2(24, 16)
	_pause_button.size = Vector2(116, 40)
	_pause_button.focus_mode = Control.FOCUS_NONE
	_pause_button.pressed.connect(_show_screen.bind(Screen.PAUSE))
	add_child(_pause_button)

	_menu_overlay = ColorRect.new()
	_menu_overlay.color = Color("#110b18d9")
	_menu_overlay.theme = theme
	_menu_overlay.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_menu_overlay)
	_menu_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	_menu_overlay.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var frame := Control.new()
	frame.custom_minimum_size = Vector2(520, 432)
	frame.draw.connect(_draw_frame.bind(frame))
	center.add_child(frame)
	var layout := VBoxContainer.new()
	frame.add_child(layout)
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.offset_left = 54
	layout.offset_right = -54
	layout.offset_top = 36
	layout.offset_bottom = -32
	layout.add_theme_constant_override("separation", 14)
	_menu_heading = _label("", 22)
	_menu_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(_menu_heading)
	_shotgun_preview = Control.new()
	_shotgun_preview.custom_minimum_size.y = 120
	_shotgun_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shotgun_preview.draw.connect(_draw_shotgun_preview)
	_shotgun_preview.resized.connect(_shotgun_preview.queue_redraw)
	layout.add_child(_shotgun_preview)
	_title_actions = VBoxContainer.new()
	_pause_actions = VBoxContainer.new()
	for actions in [_title_actions, _pause_actions]:
		actions.add_theme_constant_override("separation", 10)
		actions.size_flags_vertical = Control.SIZE_EXPAND_FILL
		actions.alignment = BoxContainer.ALIGNMENT_CENTER
		layout.add_child(actions)
	_add_action(_title_actions, "Play", _start)
	_add_action(_title_actions, "Settings", open)
	_add_action(_pause_actions, "Resume", _show_screen.bind(Screen.PLAY))
	_add_action(_pause_actions, "Restart Level", _restart)
	_add_action(_pause_actions, "Settings", open)
	_add_action(_pause_actions, "Quit to Main Menu", _quit_run)


func _draw_shotgun_preview() -> void:
	const SCALE := 4
	var origin := ((_shotgun_preview.size - Art.SHOTGUN.get_size() * SCALE) / 2
		- Vector2(0, Art.STETSON_OFFSET.y * SCALE / 2)).round()
	_shotgun_preview.draw_texture_rect(Art.SHOTGUN,
		Rect2(origin, Art.SHOTGUN.get_size() * SCALE), false)
	_shotgun_preview.draw_texture_rect(Art.STETSON,
		Rect2(origin + Art.STETSON_OFFSET * SCALE, Art.STETSON.get_size() * SCALE), false)


func _add_action(parent: VBoxContainer, title: String, action: Callable) -> void:
	var button := _button(title)
	button.pressed.connect(action)
	parent.add_child(button)


func _start() -> void:
	start_requested.emit()
	_show_screen(Screen.PLAY)


func _restart() -> void:
	restart_requested.emit()
	_show_screen(Screen.PLAY)


func _quit_run() -> void:
	quit_requested.emit()
	_show_screen(Screen.TITLE)


func _show_screen(screen: Screen) -> void:
	player.cancel_shot()
	_screen = screen
	get_tree().paused = screen != Screen.PLAY
	_pause_button.visible = screen == Screen.PLAY
	_menu_overlay.visible = screen in [Screen.TITLE, Screen.PAUSE]
	_overlay.visible = screen == Screen.SETTINGS
	_title_actions.visible = screen == Screen.TITLE
	_pause_actions.visible = screen == Screen.PAUSE
	_shotgun_preview.visible = screen == Screen.TITLE
	match screen:
		Screen.TITLE:
			_menu_heading.text = "Recoil Launcher"
			_title_actions.get_child(0).grab_focus()
		Screen.PAUSE:
			_menu_heading.text = "Paused"
			_pause_actions.get_child(0).grab_focus()
		Screen.SETTINGS:
			_tabs[_active_tab].grab_focus()


func open() -> void:
	_settings_return = _screen
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
		elif _screen == Screen.PLAY:
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


func _process(_delta: float) -> void:
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
	for i in _pages.size():
		_pages[i].visible = i == index
		_tabs[i].set_pressed_no_signal(i == index)


func _refresh() -> void:
	for bus in _sliders:
		var value: int = preferences.values[bus]
		_sliders[bus].set_value_no_signal(value)
		_readouts[bus].text = "%d%%" % value
	_aim.text = "On" if preferences.values.aim_guide else "Off"
	_shoot.text = Preferences.MOUSE_NAMES[preferences.values.shoot_button]
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
	slider.custom_minimum_size = Vector2(242, 38)
	slider.scrollable = false
	var readout := _label("", 11, GOLD)
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
	var label := _label(title, 12)
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
	button.custom_minimum_size.y = 44
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return button


func _graphics_button() -> Button:
	var button := _button("")
	button.custom_minimum_size = Vector2(210, 34)
	return button


func _draw_frame(panel: Control) -> void:
	var frame := Rect2(Vector2.ZERO, panel.size)
	panel.draw_rect(Rect2(Vector2(8, 10), frame.size), Color("#0b0711"))
	Art.stone(panel, frame, Color("#aaa0b5"))
	var inset := frame.grow(-22)
	panel.draw_rect(inset, Color("#1c1325"))
	panel.draw_rect(inset.grow(2), Color("#b0804d"), false, 2)
	Art.plank(panel, Art.PLANK_WOOD, Rect2(22, 58, frame.size.x - 44, 8), Color("#ad8258"))
	for corner in [Vector2(5, 5), Vector2(frame.size.x - 21, 5),
			Vector2(5, frame.size.y - 21), frame.size - Vector2(21, 21)]:
		panel.draw_texture_rect_region(Art.PLANK_GREY, Rect2(corner, Vector2(16, 16)), Rect2(0, 0, 8, 8))


func _castle_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font = FONT
	theme.default_font_size = 11
	theme.set_stylebox("normal", "Button", _plate(Art.PLANK_DARK, Color("#9c828e")))
	theme.set_stylebox("hover", "Button", _plate(Art.PLANK_WOOD, Color("#c59b71")))
	theme.set_stylebox("pressed", "Button", _plate(Art.PLANK_WOOD, Color("#ffd39d")))
	theme.set_stylebox("hover_pressed", "Button", _plate(Art.PLANK_WOOD, Color("#ffdfaf")))
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.border_color = GOLD
	focus.set_border_width_all(2)
	theme.set_stylebox("focus", "Button", focus)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		theme.set_color(state, "Button", CREAM if state == "font_color" else Color.WHITE)
	theme.set_stylebox("slider", "HSlider", _track(Art.PLANK_DARK, Color("#8e747c")))
	theme.set_stylebox("grabber_area", "HSlider", _track(Art.PLANK_WOOD, Color("#e1b66f")))
	theme.set_stylebox("grabber_area_highlight", "HSlider", _track(Art.PLANK_WOOD, GOLD))
	for state in ["grabber", "grabber_highlight"]:
		var cap := AtlasTexture.new()
		cap.atlas = Art.PLANK_GREY
		cap.region = Rect2(0 if state == "grabber" else 8, 0, 8, 8)
		theme.set_icon(state, "HSlider", cap)
	return theme


func _plate(texture: Texture2D, tint: Color) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = texture
	style.modulate_color = tint
	style.texture_margin_left = 8
	style.texture_margin_right = 8
	style.content_margin_left = 18
	style.content_margin_right = 18
	return style


func _track(texture: Texture2D, tint: Color) -> StyleBoxTexture:
	var style := _plate(texture, tint)
	style.content_margin_left = 0
	style.content_margin_right = 0
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	return style

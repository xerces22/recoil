extends RefCounted
## Stores the player's preferences and applies audio and display changes.

signal gameplay_changed

const PATH := "user://settings.cfg"
const FRAME_CAPS := [30, 60, 120, 144, 0]
const RESOLUTIONS := [Vector2i(960, 540), Vector2i(1280, 720),
	Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1440)]
const MOUSE_NAMES := {
	MOUSE_BUTTON_LEFT: "Left Mouse Button",
	MOUSE_BUTTON_RIGHT: "Right Mouse Button",
	MOUSE_BUTTON_MIDDLE: "Middle Mouse Button",
	MOUSE_BUTTON_XBUTTON1: "Mouse Button 4",
	MOUSE_BUTTON_XBUTTON2: "Mouse Button 5",
}
const DEFAULTS := {
	"Master": 100, "Music": 100, "SFX": 100,
	"aim_guide": true, "floor_tips": true, "fullscreen": false, "shoot_button": MOUSE_BUTTON_LEFT,
	"vsync": true, "frame_cap": 0, "resolution": Vector2i(1280, 720),
	"background_detail": true,
	"render_divisor": 1,
	"cursor_visible": true,
}

var values: Dictionary = DEFAULTS.duplicate()
var save_path := PATH


func load_saved() -> void:
	var config := ConfigFile.new()
	if config.load(save_path) == OK:
		for key in DEFAULTS:
			var value: Variant = config.get_value("settings", key, DEFAULTS[key])
			if typeof(value) == typeof(DEFAULTS[key]):
				values[key] = value
	for bus in ["Master", "Music", "SFX"]:
		values[bus] = clampi(values[bus], 0, 100)
	if not MOUSE_NAMES.has(values.shoot_button):
		values.shoot_button = MOUSE_BUTTON_LEFT
	if not FRAME_CAPS.has(values.frame_cap):
		values.frame_cap = DEFAULTS.frame_cap
	if not RESOLUTIONS.has(values.resolution):
		values.resolution = DEFAULTS.resolution
	if values.render_divisor not in [1, 2]:
		values.render_divisor = DEFAULTS.render_divisor
	_apply_audio()
	_apply_performance()
	if display_supported() and not OS.has_feature("web"):
		_apply_display()


func set_volume(bus: String, percent: int) -> void:
	values[bus] = clampi(percent, 0, 100)
	_apply_volume(bus)
	_save()


## Signs on the tower floors show their tips. The tutorial's signs always show.
func set_floor_tips(enabled: bool) -> void:
	values.floor_tips = enabled
	_save()


func set_aim_guide(enabled: bool) -> void:
	values.aim_guide = enabled
	gameplay_changed.emit()
	_save()


func set_cursor_visible(enabled: bool) -> void:
	values.cursor_visible = enabled
	gameplay_changed.emit()
	_save()


func set_shoot_button(button: int) -> void:
	if MOUSE_NAMES.has(button):
		values.shoot_button = button
		gameplay_changed.emit()
		_save()


func set_fullscreen(enabled: bool) -> void:
	if display_supported():
		values.fullscreen = enabled
		_apply_display()
		_save()


func set_graphics(key: String, value: Variant) -> void:
	values[key] = value
	match key:
		"vsync", "frame_cap":
			_apply_performance()
		"resolution":
			_apply_window_size()
		"background_detail", "render_divisor":
			gameplay_changed.emit()
	_save()


func restore_defaults() -> void:
	values = DEFAULTS.duplicate()
	_apply_audio()
	_apply_performance()
	if display_supported():
		_apply_display()
	gameplay_changed.emit()
	_save()


func display_supported() -> bool:
	if OS.has_feature("web"):
		return web_fullscreen_supported()
	return desktop_window_supported()


func web_fullscreen_supported() -> bool:
	var document := JavaScriptBridge.get_interface("document")
	if document == null:
		return false
	return bool(document.fullscreenEnabled) or bool(document.webkitFullscreenEnabled)


func embedded_in_editor() -> bool:
	var args := OS.get_cmdline_args()
	return args.has("--wid") or args.has("--embedded")


func desktop_window_supported() -> bool:
	return not OS.has_feature("web") and DisplayServer.get_name() != "headless" \
		and not embedded_in_editor()


func available_resolutions() -> Array[Vector2i]:
	var available: Array[Vector2i] = []
	var usable := DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
	for size: Vector2i in RESOLUTIONS:
		if size.x <= usable.size.x and size.y + 40 <= usable.size.y:
			available.append(size)
	return available


func is_fullscreen() -> bool:
	return DisplayServer.window_get_mode() in [
		DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]


func _apply_display() -> void:
	if values.fullscreen != is_fullscreen():
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if values.fullscreen
			else DisplayServer.WINDOW_MODE_WINDOWED)
	if not values.fullscreen and desktop_window_supported():
		_apply_window_size.call_deferred()


func _apply_window_size() -> void:
	if not desktop_window_supported() or is_fullscreen():
		return
	var choices := available_resolutions()
	if choices.is_empty():
		return
	var size: Vector2i = values.resolution if choices.has(values.resolution) else choices.back()
	var usable := DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
	DisplayServer.window_set_size(size)
	DisplayServer.window_set_position(usable.position + (usable.size - size) / 2)


func _apply_performance() -> void:
	Engine.max_fps = values.frame_cap
	if desktop_window_supported():
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if values.vsync
			else DisplayServer.VSYNC_DISABLED)


func _apply_audio() -> void:
	for bus in ["Master", "Music", "SFX"]:
		_apply_volume(bus)


func _apply_volume(bus: String) -> void:
	var index := AudioServer.get_bus_index(bus)
	var linear := float(values[bus]) / 100.0
	AudioServer.set_bus_volume_linear(index, maxf(linear, 0.0001))
	AudioServer.set_bus_mute(index, linear == 0.0)


func _save() -> void:
	var config := ConfigFile.new()
	for key in DEFAULTS:
		config.set_value("settings", key, values[key])
	var result := config.save(save_path)
	if result != OK:
		push_warning("Could not save Cursed Shotgun settings: %s" % error_string(result))

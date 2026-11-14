class_name MenuItem
extends Control
## One option in the side menu. Hover or keyboard focus slides the text right, lights it
## green and shows a diamond marker. Clicking pops it and plays its own sound.
## Locked items show "?" and give a dull thud instead of acting.

signal activated

const FONT := preload("res://assets/fonts/PressStart2P-Regular.ttf")
const CREAM := Color("#f6e8cb")
const ACCENT := Color("#57e08f")
const DIM := Color("#6d6178")
const SLIDE := 18.0

var text := ""
var font_size := 20
var locked := false
var click_sound: AudioStream
var hover_sound: AudioStream
var play_sound: Callable

var button := Button.new()
var _glow := 0.0
var _tween: Tween


func _init(value: String, size_px := 20, sound: AudioStream = null) -> void:
	text = value
	font_size = size_px
	click_sound = sound


func _ready() -> void:
	custom_minimum_size = Vector2(320, font_size + 22)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.text = text
	button.flat = true
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_override("font", FONT)
	button.add_theme_font_size_override("font_size", font_size)
	var empty := StyleBoxEmpty.new()
	empty.content_margin_left = 26
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(state, empty)
	add_child(button)
	button.position = Vector2.ZERO
	button.size = custom_minimum_size
	resized.connect(func() -> void: button.size = size)
	button.mouse_entered.connect(button.grab_focus)
	button.focus_entered.connect(_highlight.bind(true))
	button.focus_exited.connect(_highlight.bind(false))
	button.pressed.connect(_on_pressed)
	set_locked(locked)


func set_locked(value: bool) -> void:
	locked = value
	var base := DIM if locked else CREAM
	for state in ["font_color", "font_focus_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		button.add_theme_color_override(state, base)
	if not locked:
		for state in ["font_focus_color", "font_hover_color", "font_hover_pressed_color"]:
			button.add_theme_color_override(state, ACCENT)
	button.mouse_default_cursor_shape = Control.CURSOR_ARROW if locked else Control.CURSOR_POINTING_HAND


func _highlight(on: bool) -> void:
	if on and play_sound.is_valid() and hover_sound != null:
		play_sound.call(hover_sound, randf_range(1.25, 1.45), -16.0)
	if _tween != null:
		_tween.kill()
	_tween = create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(button, "position:x", SLIDE if on and not locked else (6.0 if on else 0.0), 0.16)
	_tween.tween_method(func(v: float) -> void:
		_glow = v
		queue_redraw(), _glow, 1.0 if on else 0.0, 0.16)


func _on_pressed() -> void:
	if locked:
		if play_sound.is_valid():
			play_sound.call(preload("res://assets/sfx/wall_hit.ogg"), 0.8, -8.0)
		var shake := create_tween()
		for x in [SLIDE - 8.0, SLIDE + 8.0, SLIDE - 4.0, 6.0]:
			shake.tween_property(button, "position:x", x, 0.04)
		return
	if play_sound.is_valid() and click_sound != null:
		play_sound.call(click_sound, randf_range(0.95, 1.05), -6.0)
	# Quick squash and pop.
	button.pivot_offset = Vector2(26, button.size.y / 2.0)
	var pop := create_tween()
	pop.tween_property(button, "scale", Vector2(0.92, 0.92), 0.05)
	pop.tween_property(button, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	activated.emit()


func _draw() -> void:
	if _glow <= 0.01:
		return
	# Diamond marker to the left of the text, and a thin underline that grows with the glow.
	var colour := (DIM if locked else ACCENT)
	colour.a = _glow
	var c := Vector2(10.0 + button.position.x * 0.3, size.y / 2.0)
	var r := 5.0
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)]), colour)
	if not locked:
		var line := colour
		line.a = _glow * 0.35
		var width := button.get_theme_font("font").get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		draw_rect(Rect2(button.position.x + 26.0, size.y - 6.0, width * _glow, 2.0), line)

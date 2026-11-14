extends CanvasLayer
## End of the cellar tutorial: "Keep the aim guide?" with Keep / Hide. Pauses the game while open.
## Saves the choice to the preferences (it can be changed later in Settings), then emits `chosen`.

signal chosen

const Preferences = preload("res://game_preferences.gd")
const FONT := preload("res://assets/fonts/PressStart2P-Regular.ttf")
const CREAM := Color("f6e8cb")
const LILAC := Color("bdb0c7")
const ACCENT := Color("57e08f")
const INK := Color("170b22")
const EDGE := Color("3a2b48")

var preferences: Preferences
var _done := false
var _menu: Node


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	_menu = get_parent().get_node_or_null("Settings")
	if _menu != null:
		_menu.pause_locked = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.01, 0.05, 0.7)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(INK, 0.97)
	box.border_color = EDGE
	box.set_border_width_all(3)
	box.border_width_top = 5
	box.set_content_margin_all(30)
	panel.add_theme_stylebox_override("panel", box)
	center.add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 20)
	panel.add_child(col)
	col.add_child(_label("BRAZIER LIT. PROGRESS SAVED.", 12, ACCENT))
	col.add_child(_label("Keep the aim guide?", 22, CREAM))

	var demo := Control.new()
	demo.custom_minimum_size = Vector2(560, 110)
	demo.draw.connect(_draw_demo.bind(demo))
	col.add_child(demo)

	col.add_child(_label("The arrow beside the gun shows which way your shot will send you.", 12, CREAM, 560))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 24)
	col.add_child(row)
	var keep := _button("Keep Aim Guide", true)
	keep.pressed.connect(_choose.bind(true))
	row.add_child(keep)
	var hide := _button("Hide Aim Guide", false)
	hide.pressed.connect(_choose.bind(false))
	row.add_child(hide)
	col.add_child(_label("You can change this any time in Settings.", 10, LILAC))
	keep.grab_focus.call_deferred()


func _label(text: String, size: int, colour: Color, width := 0) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", colour)
	l.add_theme_constant_override("line_spacing", 8)
	if width > 0:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(width, 0)
	return l


func _button(text: String, primary: bool) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(250, 54)
	b.add_theme_font_override("font", FONT)
	b.add_theme_font_size_override("font_size", 13)
	b.add_theme_color_override("font_color", INK if primary else CREAM)
	b.add_theme_color_override("font_hover_color", INK if primary else ACCENT)
	b.add_theme_color_override("font_focus_color", INK if primary else ACCENT)
	b.add_theme_color_override("font_pressed_color", INK if primary else ACCENT)
	for state in ["normal", "hover", "pressed", "focus"]:
		var s := StyleBoxFlat.new()
		s.bg_color = (ACCENT if state == "normal" else ACCENT.lightened(0.2)) if primary else Color(INK, 1.0)
		s.border_color = ACCENT if (primary or state != "normal") else EDGE
		s.set_border_width_all(3)
		b.add_theme_stylebox_override(state, s)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return b


## The shotgun with its aim chevron, as it looks in game: the barrel points at your cursor (+),
## and the chevron on the other side points the way the shot will throw you.
func _draw_demo(demo: Control) -> void:
	var c := demo.size / 2.0 + Vector2(40, 0)
	var cursor := c + Vector2(-190, 34)
	var aim := (cursor - c).normalized()
	var flip := -1.0 if aim.x < 0.0 else 1.0
	demo.draw_set_transform(c, aim.angle(), Vector2(3.0, 3.0 * flip))
	demo.draw_texture(Art.SHOTGUN, -Vector2(20, 7))
	demo.draw_texture(Art.STETSON, Art.STETSON_OFFSET - Vector2(20, 7))
	demo.draw_set_transform(Vector2.ZERO)
	Art.draw_chevron(demo, c - aim * 92.0, -aim, 4.0)
	# The cursor: a small cross.
	demo.draw_rect(Rect2(cursor - Vector2(10, 2), Vector2(20, 4)), LILAC)
	demo.draw_rect(Rect2(cursor - Vector2(2, 10), Vector2(4, 20)), LILAC)


func _choose(keep: bool) -> void:
	if _done:
		return
	_done = true
	if preferences != null:
		preferences.set_aim_guide(keep)
	if _menu != null:
		_menu.pause_locked = false
	get_tree().paused = false
	chosen.emit()

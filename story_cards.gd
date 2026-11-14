class_name StoryCards
extends CanvasLayer
## Full-screen text cards for the intro and ending. Click or press a key for the next card,
## Esc skips the rest. The game is paused while cards are showing.

signal finished

const FONT := preload("res://assets/fonts/PressStart2P-Regular.ttf")

const INTRO: Array[String] = [
	"Sir Barrett was the finest witch hunter in the kingdom.\n\nHe came to Hexmoor Castle with one weapon: his trusty double-barrel shotgun.",
	"The witch Morwen the Unloaded caught him in the cellar.\n\nShe didn't kill him.\n\nShe did something worse.\n\nShe turned him INTO the shotgun.",
	"\"A gun can't walk,\" she laughed, and floated up to her tower.\n\nHer magic lives in hex orbs hidden through the castle.\n\nSmash them all and the curse breaks.",
]

const ENDING: Array[String] = [
	"The heart orb shatters.\n\nThe curse breaks...\n\n...and bounces.",
	"Sir Barrett is a man again.\n\nMorwen the Unloaded is a broom.\n\nHe sweeps the floor with her.",
	"He never fired a shotgun again.\n\nHe just sort of hopped everywhere.\n\n\nTHE END",
]

var _pages: Array[String] = []
var _index := 0
var _text: Label
var _prompt: Label
var _blink := 0.0


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	var back := ColorRect.new()
	back.color = Color(0.06, 0.03, 0.09)
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(back)

	_text = Label.new()
	_text.set_anchors_preset(Control.PRESET_FULL_RECT)
	_text.offset_left = 160
	_text.offset_right = -160
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.add_theme_font_override("font", FONT)
	_text.add_theme_font_size_override("font_size", 20)
	_text.add_theme_constant_override("line_spacing", 10)
	_text.add_theme_color_override("font_color", Color(0.93, 0.88, 1.0))
	back.add_child(_text)

	_prompt = Label.new()
	_prompt.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_prompt.offset_top = -60
	_prompt.offset_bottom = -30
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.add_theme_font_override("font", FONT)
	_prompt.add_theme_font_size_override("font_size", 12)
	_prompt.add_theme_color_override("font_color", Color(0.65, 0.55, 0.8))
	back.add_child(_prompt)


func play(pages: Array[String]) -> void:
	_pages = pages
	_index = 0
	visible = true
	get_tree().paused = true
	_show()


func _show() -> void:
	_text.text = _pages[_index]
	var last := _index == _pages.size() - 1
	_prompt.text = "click to begin" if last else "click to continue    esc to skip"
	_text.visible_ratio = 0.0
	var tween := create_tween()
	tween.tween_property(_text, "visible_ratio", 1.0, _text.text.length() * 0.02)


func _process(delta: float) -> void:
	_blink += delta
	_prompt.modulate.a = 0.55 + 0.45 * sin(_blink * 4.0)


func _input(event: InputEvent) -> void:
	if not visible:
		return
	var pressed: bool = (event is InputEventMouseButton and event.pressed) \
		or (event is InputEventKey and event.pressed and not event.echo)
	get_viewport().set_input_as_handled()
	if not pressed:
		return
	if event is InputEventKey and event.keycode == KEY_ESCAPE:
		_close()
		return
	if _text.visible_ratio < 1.0:
		# First click finishes the typing, the next one turns the page.
		_text.visible_ratio = 1.0
		return
	_index += 1
	if _index >= _pages.size():
		_close()
	else:
		_show()


func _close() -> void:
	visible = false
	get_tree().paused = false
	finished.emit()

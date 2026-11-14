extends Control
## Opening logo: the white Cursed Shotgun logo fades in on black, holds, fades out, then loads the game (title screen). Any key or click skips.

const LOGO := preload("res://assets/sprites/logo/logo_mono.png")
const NEXT_SCENE := "res://main.tscn"

const FADE_IN := 0.5
const HOLD := 1.6
const FADE_OUT := 0.6

var _logo: TextureRect
var _leaving := false


func _ready() -> void:
	var black := ColorRect.new()
	black.color = Color.BLACK
	add_child(black)
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_logo = TextureRect.new()
	_logo.texture = LOGO
	_logo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_logo.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	_logo.modulate.a = 0.0
	add_child(_logo)
	_logo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_logo.pivot_offset = get_viewport_rect().size / 2.0

	# Logo eases in slightly oversized and settles.
	_logo.scale = Vector2.ONE * 1.08
	var tween := create_tween()
	tween.tween_interval(0.3)
	tween.tween_property(_logo, "modulate:a", 1.0, FADE_IN)
	tween.parallel().tween_property(_logo, "scale", Vector2.ONE, FADE_IN) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(HOLD)
	tween.tween_property(_logo, "modulate:a", 0.0, FADE_OUT)
	tween.tween_callback(_leave)


func _unhandled_input(event: InputEvent) -> void:
	if (event is InputEventKey or event is InputEventMouseButton) and event.pressed:
		_leave()


func _leave() -> void:
	if _leaving:
		return
	_leaving = true
	get_tree().change_scene_to_file.call_deferred(NEXT_SCENE)

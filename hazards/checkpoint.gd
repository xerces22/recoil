@tool
class_name Checkpoint
extends Block
## Platform that saves your respawn point when you land on it.
## Tick `is_finish` for the level goal.
## Reaching it lights the campfire: a whoosh of flame, a crackle, and "CHECKPOINT" floating up.

## Bonfire frames per second once lit.
const FIRE_FPS := 10.0
## Bottom rows of the bonfire sprite: the unlit log pile and stone ring.
const UNLIT_ROWS := 22.0
## How long the lighting flare and the floating text last (seconds).
const FLARE_TIME := 0.45
const TEXT_TIME := 1.4
const FIRE_SOUND := preload("res://assets/sfx/checkpoint_fire.ogg")
const FONT := preload("res://assets/fonts/PressStart2P-Regular.ttf")

@export var is_finish := false:
	set(value):
		is_finish = value
		queue_redraw()

var reached := false:
	set(value):
		var lit_now := value and not reached
		reached = value
		set_process(reached and not Engine.is_editor_hint())
		if lit_now and is_inside_tree() and not Engine.is_editor_hint():
			_light()
		queue_redraw()

var _time := 0.0
## Seconds since the fire was lit, or -1 if the lighting effect isn't playing.
var _lit_t := -1.0


func _ready() -> void:
	super()
	set_process(false)


func _process(delta: float) -> void:
	_time += delta
	if _lit_t >= 0.0:
		_lit_t += delta
		if _lit_t > TEXT_TIME:
			_lit_t = -1.0
	queue_redraw()


## Lighting the fire: crackle that fades out, plus the flare and text drawn in _draw.
func _light() -> void:
	_lit_t = 0.0
	if is_finish:
		return
	var sound := AudioStreamPlayer2D.new()
	sound.stream = FIRE_SOUND
	sound.volume_db = -2.0
	sound.bus = &"SFX"
	sound.position = Vector2(0, -size.y / 2.0 - 20.0)
	add_child(sound)
	sound.play()
	var fade := sound.create_tween()
	fade.tween_interval(0.9)
	fade.tween_property(sound, "volume_db", -40.0, 1.6)
	fade.tween_callback(sound.queue_free)


func plank_texture() -> Texture2D:
	return Art.PLANK_GREY


func bracket_texture() -> Texture2D:
	return Art.SHELF_GREY


func _draw() -> void:
	var top := -size.y / 2.0
	if is_finish:
		# Exit gate standing on the platform.
		Art.stand(self, Art.GATE, Vector2(0, top), Art.PX,
			Color(1.3, 1.2, 0.8) if reached else Color.WHITE)
	super()
	if is_finish:
		return
	var fire := Art.BONFIRE[0]
	var w := float(fire.get_width())
	var h := float(fire.get_height())
	if reached:
		# Flare when it catches: a bright burst behind the fire that settles.
		if _lit_t >= 0.0 and _lit_t < FLARE_TIME:
			var f := _lit_t / FLARE_TIME
			draw_circle(Vector2(0, top - h * 0.4), 20.0 + 40.0 * f, Color(1.0, 0.7, 0.3, 0.45 * (1.0 - f)))
		var frame := Art.BONFIRE[int(_time * FIRE_FPS) % Art.BONFIRE.size()]
		var scale := 1.0
		if _lit_t >= 0.0 and _lit_t < FLARE_TIME:
			scale = 1.0 + 0.35 * (1.0 - _lit_t / FLARE_TIME)
		draw_set_transform(Vector2(0, top), 0.0, Vector2(scale, scale))
		draw_texture(frame, Vector2(-w / 2.0, -h))
		draw_set_transform(Vector2.ZERO)
		if _lit_t >= 0.0:
			_draw_label(top - h - 8.0)
	else:
		draw_texture_rect_region(fire, Rect2(-w / 2.0, top - UNLIT_ROWS, w, UNLIT_ROWS),
			Rect2(0, h - UNLIT_ROWS, w, UNLIT_ROWS), Color(0.75, 0.7, 0.8))


## "CHECKPOINT" rising off the fire and fading out.
func _draw_label(base_y: float) -> void:
	var f := _lit_t / TEXT_TIME
	var alpha := clampf(minf(f * 6.0, (1.0 - f) * 3.0), 0.0, 1.0)
	var y := base_y - 26.0 * f
	var text := "CHECKPOINT"
	var font_size := 10
	var width := FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var at := Vector2(-width / 2.0, y)
	FONT.draw_string_outline(get_canvas_item(), at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 4,
		Color(0.1, 0.04, 0.02, alpha))
	draw_string(FONT, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1.0, 0.85, 0.45, alpha))

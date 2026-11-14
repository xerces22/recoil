@tool
class_name LevelSign
extends Node2D
## A wooden signpost. Stand near it and its `text` shows in a panel on screen (main.gd draws the
## panel on the HUD, at full resolution, so it's always crisp). The node's position is where the
## post meets the ground: put it on the top of a ledge or the slab.

const SPRITE := preload("res://assets/sprites/props/sign_wood.png")

## One short line. Shown on screen while the player is within `radius`.
@export_multiline var text := "":
	set(value):
		text = value
		queue_redraw()
## How close (px, from the post) the player must be for the text to show.
@export var radius := 230.0


func _ready() -> void:
	# Same layer as the level's blocks (drawn after the level's own background), under the player.
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _draw() -> void:
	var size := SPRITE.get_size() * Art.PX
	draw_texture_rect(SPRITE, Rect2(Vector2(-size.x / 2.0, -size.y), size), false)
	if Engine.is_editor_hint():
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(1.0, 0.85, 0.4, 0.35), 2.0)
		draw_string(ThemeDB.fallback_font, Vector2(-size.x / 2.0, -size.y - 8.0), text.left(40),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1.0, 0.9, 0.6))

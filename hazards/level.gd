@tool
class_name Level
extends Node2D
## Root of every level scene. Needs a Marker2D child named "Start".

## Default bounds match the old 1280-wide shaft: camera floor at y 720, no real top.
const SHAFT := Rect2(0, -20000, 1280, 20720)

@export var title := "Level"
@export_multiline var hint := ""
## Mrs. Sandwitch's line, shown under the floor title when the floor is entered. Every floor has one.
@export var taunt := ""
## Clearing this level plays the ending instead of loading the next one.
@export var is_final := false
## Optional backdrop tint for this part of the tower.
@export var backdrop_tint := Color(0.45, 0.4, 0.52)
## Playable area. The camera stops at these edges. Leaving the sides or the bottom
## by more than 24 px kills. Up is negative y, so `position.y` is the top.
@export var bounds := SHAFT:
	set(value):
		bounds = value
		queue_redraw()


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var colour := Color(0.2, 0.6, 1.0, 0.8)
	var r := bounds
	if r.position.y < -15000.0:
		# Old-style shaft: draw only the sides and bottom.
		r = Rect2(r.position.x, r.end.y - 4000.0, r.size.x, 4000.0)
	draw_rect(r, colour, false, 3.0)
	draw_string(ThemeDB.fallback_font, r.position + Vector2(8, 20), "LEVEL BOUNDS",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 16, colour)

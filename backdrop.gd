extends Node2D
## The castle's inner wall behind the level, built like architecture instead of a repeating
## pattern. Stone pillars and storey ledges split it into rooms. Each room has its own brickwork
## and wear, and furniture that fits the zone and sits where it belongs: barrels and cell bars
## stand on the ledge below, chains, cages and chandeliers hang from the ledge above, torches are
## mounted on the pillars.
## The zone follows the floor (Cellar = floors 1-3, Library = 4-7, Tower = 8-10, as in STORY.md)
## and the colours ease between zones as you climb. Moving life (dust, drips, embers, rain, bats,
## lightning, hex sparks) floats in front of the wall. All of it sits behind the level.

enum Zone { CELLAR, LIBRARY, TOWER }

## Wall and rooms scroll at half the camera speed; moving life a little faster (closer).
const PARALLAX := 0.5
const LIFE_PARALLAX := 0.7
## How fast the colours ease to a new zone (share per second).
const BLEND_SPEED := 1.4
const PARTICLES := 70
## Zones of the 7 sandbox test levels, so they get variety too.
const SANDBOX_ZONES: Array[int] = [Zone.CELLAR, Zone.CELLAR, Zone.LIBRARY, Zone.LIBRARY,
	Zone.LIBRARY, Zone.TOWER, Zone.TOWER]

## Room grid in background-layer pixels: distance between pillars, and storey height.
const ROOM := Vector2(560, 400)
const PILLAR_W := 40.0
const LEDGE_H := 24.0
## Furniture is drawn bigger than level art (screen px per art px), so the rooms read as a big
## hall behind you.
const BIG := 3.0
## How much the backdrop is dimmed behind the level (0 = not at all). Keeps platforms reading first.
const HAZE := 0.66
## Opacity of the moving life (dust, rain, bats, sparks, fog).
const LIFE_OPACITY := 0.5

const WALLS: Array[Texture2D] = [
	preload("res://assets/sprites/tilesets/wall_gray_1.png"),
	preload("res://assets/sprites/tilesets/wall_gray_2.png"),
	preload("res://assets/sprites/tilesets/wall_gray_3.png"),
	preload("res://assets/sprites/tilesets/wall_gray_4.png"),
	preload("res://assets/sprites/tilesets/wall_gray_5.png"),
]
const WINDOW := preload("res://assets/sprites/props/window_arch_1.png")
const STAINED := preload("res://assets/sprites/props/stained_glass_tall.png")
const STATUES: Array[Texture2D] = [
	preload("res://assets/sprites/props/knight_statue_1.png"),
	preload("res://assets/sprites/props/knight_statue_2.png"),
]
const GARGOYLE := preload("res://assets/sprites/props/gargoyle_1.png")
const CHAIN := preload("res://assets/sprites/props/chain_dark_castle.png")
const FLAMES: Array[Texture2D] = [
	preload("res://assets/sprites/props/flame_1.png"),
	preload("res://assets/sprites/props/flame_2.png"),
	preload("res://assets/sprites/props/flame_3.png"),
	preload("res://assets/sprites/props/flame_4.png"),
	preload("res://assets/sprites/props/flame_5.png"),
]
const BANNERS: Array[Texture2D] = [
	preload("res://assets/sprites/banners/banner_2.png"),
	preload("res://assets/sprites/banners/banner_5.png"),
	preload("res://assets/sprites/banners/banner_7.png"),
	preload("res://assets/sprites/banners/banner_10.png"),
]
const STORES: Array[Texture2D] = [
	preload("res://assets/sprites/dressing/barrels_stack.png"),
	preload("res://assets/sprites/dressing/barrels_tall.png"),
	preload("res://assets/sprites/dressing/barrels_pair.png"),
	preload("res://assets/sprites/dressing/crates_barrels.png"),
	preload("res://assets/sprites/dressing/crates_small.png"),
	preload("res://assets/sprites/dressing/crates_big.png"),
]
const COBWEBS: Array[Texture2D] = [
	preload("res://assets/sprites/dressing/cobweb_1.png"),
	preload("res://assets/sprites/dressing/cobweb_2.png"),
	preload("res://assets/sprites/dressing/cobweb_3.png"),
	preload("res://assets/sprites/dressing/cobweb_4.png"),
]
const CAGE := preload("res://assets/sprites/dressing/cage_hanging.png")
const GRATE := preload("res://assets/sprites/dressing/grate_window.png")
const BOOKCASES: Array[Texture2D] = [
	preload("res://assets/sprites/dressing/bookcase_long.png"),
	preload("res://assets/sprites/dressing/bookcase_wide.png"),
	preload("res://assets/sprites/dressing/bookcase_tall.png"),
	preload("res://assets/sprites/dressing/bookcase_small.png"),
	preload("res://assets/sprites/dressing/cabinet.png"),
]
const DESK := preload("res://assets/sprites/dressing/desk.png")
const MIRROR := preload("res://assets/sprites/dressing/mirror.png")
const CANDELABRA := preload("res://assets/sprites/dressing/candelabra_gold.png")
const SCONCE := preload("res://assets/sprites/dressing/sconce_gold.png")
const CHANDELIER_GOLD: Array[Texture2D] = [
	preload("res://assets/sprites/dressing/chandelier_gold_1.png"),
	preload("res://assets/sprites/dressing/chandelier_gold_2.png"),
	preload("res://assets/sprites/dressing/chandelier_gold_3.png"),
	preload("res://assets/sprites/dressing/chandelier_gold_4.png"),
]
const CHANDELIER_IRON: Array[Texture2D] = [
	preload("res://assets/sprites/dressing/chandelier_iron_1.png"),
	preload("res://assets/sprites/dressing/chandelier_iron_2.png"),
	preload("res://assets/sprites/dressing/chandelier_iron_3.png"),
	preload("res://assets/sprites/dressing/chandelier_iron_4.png"),
]
const PAINTINGS: Array[Texture2D] = [
	preload("res://assets/sprites/dressing/painting_1.png"),
	preload("res://assets/sprites/dressing/painting_2.png"),
	preload("res://assets/sprites/dressing/painting_3.png"),
	preload("res://assets/sprites/dressing/painting_4.png"),
	preload("res://assets/sprites/dressing/painting_5.png"),
	preload("res://assets/sprites/dressing/painting_6.png"),
	preload("res://assets/sprites/dressing/painting_7.png"),
	preload("res://assets/sprites/dressing/painting_8.png"),
]

## Per-zone look. Floats are blended along with the colours.
##   wall: brick colour. stone: pillars and ledges. decor: tint for furniture.
##   sky_top/sky_low: what you see through windows. light: torch and candle glow.
##   fog/rain/lightning/stars/shafts/sparks: how much of each effect.
const LOOKS := {
	Zone.CELLAR: {
		"wall": Color(0.25, 0.33, 0.29), "stone": Color(0.42, 0.48, 0.43),
		"decor": Color(0.72, 0.76, 0.72),
		"sky_top": Color(0.06, 0.12, 0.10), "sky_low": Color(0.12, 0.24, 0.18),
		"light": Color(1.0, 0.58, 0.25), "fog": 1.0, "rain": 0.0, "lightning": 0.0,
		"stars": 0.0, "shafts": 0.6, "sparks": 0.15,
	},
	Zone.LIBRARY: {
		"wall": Color(0.44, 0.31, 0.22), "stone": Color(0.62, 0.50, 0.40),
		"decor": Color(0.92, 0.85, 0.76),
		"sky_top": Color(0.14, 0.15, 0.34), "sky_low": Color(0.62, 0.36, 0.30),
		"light": Color(1.0, 0.78, 0.42), "fog": 0.0, "rain": 0.0, "lightning": 0.0,
		"stars": 0.5, "shafts": 1.0, "sparks": 0.4,
	},
	Zone.TOWER: {
		"wall": Color(0.20, 0.25, 0.48), "stone": Color(0.42, 0.46, 0.66),
		"decor": Color(0.72, 0.76, 0.92),
		"sky_top": Color(0.03, 0.04, 0.12), "sky_low": Color(0.14, 0.16, 0.34),
		"light": Color(0.75, 0.85, 1.0), "fog": 0.0, "rain": 1.0, "lightning": 1.0,
		"stars": 1.0, "shafts": 0.3, "sparks": 1.0,
	},
}

## Particle kinds and how often each zone spawns them (weights).
enum Kind { DUST, DRIP, SPORE, EMBER, RAIN, SPARK }
const KIND_WEIGHTS := {
	Zone.CELLAR: [30, 25, 30, 15, 0, 0],
	Zone.LIBRARY: [50, 0, 0, 25, 0, 25],
	Zone.TOWER: [10, 0, 0, 0, 60, 30],
}

var _wall_layer := Node2D.new()
var _decor_layer := Node2D.new()
var _life_layer := Node2D.new()
var _look: Dictionary = LOOKS[Zone.CELLAR].duplicate()
var _zone := Zone.CELLAR
var _floor := 0
var _time := 0.0
## Set by main.gd per floor. Unused here: the zone looks above already tint each floor.
var target_tint := Color(0.45, 0.4, 0.52)
## Settings > background detail. Off hides the furniture layer and keeps the plain wall.
var show_decor := true:
	set(value):
		show_decor = value
		_decor_layer.visible = value
var _center := Vector2.ZERO
var _last_center := Vector2.ZERO
var _view := Vector2(1280, 720)
var _particles: Array[Dictionary] = []
var _flyers: Array[Dictionary] = []
var _flyer_timer := 3.0
var _flash := 0.0
var _flash_timer := 6.0
var _rng := RandomNumberGenerator.new()



func _ready() -> void:
	for pair in [[_wall_layer, -60, _draw_wall], [_decor_layer, -55, _draw_decor],
			[_life_layer, -50, _draw_life]]:
		var layer: Node2D = pair[0]
		layer.z_index = pair[1]
		layer.z_as_relative = false
		layer.draw.connect(pair[2])
		add_child(layer)
	# Moving life stays faint so your eye stays on the gun, not the background.
	_life_layer.modulate = Color(1, 1, 1, LIFE_OPACITY)


func _process(delta: float) -> void:
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return
	_time += delta
	_view = get_viewport_rect().size / camera.zoom
	_last_center = _center
	_center = camera.get_screen_center_position()
	var zf := _zone_at(_center.y)
	_zone = zf.x
	_floor = zf.y
	# First frame: start in this zone's look straight away, with its own particles.
	if _particles.is_empty():
		_look = LOOKS[_zone].duplicate()
		for i in PARTICLES:
			_particles.append(_new_particle(true))
	_blend_look(delta)
	_update_particles(delta, _center - _last_center if _last_center != Vector2.ZERO else Vector2.ZERO)
	_update_flyers(delta)
	_update_lightning(delta)
	_wall_layer.queue_redraw()
	_decor_layer.queue_redraw()
	_life_layer.queue_redraw()


# ---------------------------------------------------------------- zones

## Zone and floor number at a world y. Asks main.gd which floor that is.
func _zone_at(world_y: float) -> Vector2i:
	var main := owner if owner != null else get_parent()
	if main == null or not ("floors" in main) or main.floors.is_empty():
		return Vector2i(Zone.CELLAR, 0)
	var index: int = main._floor_at(world_y)
	var number: int = main.floor_numbers[index]
	if number < 0:
		var sandbox := clampi(int(main.level_index) - main.FLOORS.size(), 0, SANDBOX_ZONES.size() - 1)
		return Vector2i(SANDBOX_ZONES[sandbox], sandbox)
	var zone := Zone.CELLAR if number < 3 else (Zone.LIBRARY if number < 7 else Zone.TOWER)
	return Vector2i(zone, number)


func _blend_look(delta: float) -> void:
	var target: Dictionary = LOOKS[_zone]
	var t := minf(1.0, BLEND_SPEED * delta)
	for key in target:
		_look[key] = lerp(_look[key], target[key], t)


# ---------------------------------------------------------------- rooms

## Rooms on screen: [grid cell, world rect]. A room's top LEDGE_H is the ledge above it.
func _rooms() -> Array:
	var shift := _center * PARALLAX
	var area := Rect2(_center - _view / 2.0 - shift, _view)
	var first := (area.position / ROOM).floor()
	var last := (area.end / ROOM).floor()
	var rooms := []
	for i in range(int(first.x), int(last.x) + 1):
		for k in range(int(first.y), int(last.y) + 1):
			rooms.append([Vector2i(i, k), Rect2(Vector2(i, k) * ROOM + shift, ROOM)])
	return rooms


## Which zone a room belongs to: where it sits when the camera is centred on it.
## Fixed per room, so rooms never swap furniture while you look at them.
func _room_zone(cell: Vector2i) -> int:
	return _zone_at((cell.y + 0.5) * ROOM.y / (1.0 - PARALLAX)).x


## Each floor in a zone is a little brighter than the one below, so climbing feels like progress,
## and each room is a touch lighter or darker than its neighbours.
func _wall_colour(seed: int) -> Color:
	var colour := (_look.wall as Color).lightened(float(posmod(_floor, 4)) * 0.05)
	return colour.darkened(float(seed % 5) * 0.035)


func _draw_wall() -> void:
	for room in _rooms():
		var cell: Vector2i = room[0]
		var rect: Rect2 = room[1]
		var seed := _hash(cell.x, cell.y)
		var tex := WALLS[seed % WALLS.size()]
		Art.fill(_wall_layer, tex, Rect2(Vector2.ZERO, tex.get_size()), rect, Art.PX, _wall_colour(seed))


func _draw_decor() -> void:
	var ci := _decor_layer
	var rooms := _rooms()
	for room in rooms:
		var cell: Vector2i = room[0]
		var rect: Rect2 = room[1]
		var seed := _hash(cell.x, cell.y)
		var inside := Rect2(rect.position + Vector2(PILLAR_W / 2.0, LEDGE_H),
			rect.size - Vector2(PILLAR_W, LEDGE_H))
		_draw_wear(ci, inside, seed, _room_zone(cell))
		match _room_zone(cell):
			Zone.CELLAR: _draw_cellar_room(ci, inside, seed)
			Zone.LIBRARY: _draw_library_room(ci, inside, seed)
			Zone.TOWER: _draw_tower_room(ci, inside, seed)
	# Structure on top: ledges, then pillars with their torches.
	var stone: Color = _look.stone
	for room in rooms:
		var rect: Rect2 = room[1]
		var ledge := Rect2(rect.position, Vector2(rect.size.x, LEDGE_H))
		ci.draw_rect(Rect2(ledge.position + Vector2(0, LEDGE_H), Vector2(ledge.size.x, 10)), Color(0, 0, 0, 0.3))
		Art.stone(ci, ledge, stone)
	for room in rooms:
		var cell: Vector2i = room[0]
		var rect: Rect2 = room[1]
		var x := rect.position.x
		var pillar := Rect2(x - PILLAR_W / 2.0, rect.position.y + LEDGE_H, PILLAR_W, rect.size.y - LEDGE_H)
		ci.draw_rect(Rect2(pillar.end.x, pillar.position.y, 8, pillar.size.y), Color(0, 0, 0, 0.22))
		Art.stone(ci, pillar, stone.darkened(0.08))
		# Capital and base, a bit wider than the shaft.
		Art.stone(ci, Rect2(x - PILLAR_W / 2.0 - 6, pillar.position.y, PILLAR_W + 12, 12), stone)
		Art.stone(ci, Rect2(x - PILLAR_W / 2.0 - 6, pillar.end.y - 12, PILLAR_W + 12, 12), stone)
		var seed := _hash(cell.x * 3 + 1, cell.y)
		var mount := Vector2(x, rect.position.y + rect.size.y * 0.5)
		if _room_zone(cell) == Zone.TOWER:
			if seed % 2 == 0:
				_draw_glow(ci, mount + Vector2(0, -20), 0.6, seed)
				Art.stand(ci, SCONCE, mount + Vector2(0, 10), Art.PX, _look.decor)
		elif seed % 3 != 0:
			_draw_torch(ci, mount, seed)
	# Depth haze: dims the whole backdrop so the ledges and furniture never read as platforms.
	ci.draw_rect(Rect2(_center - _view / 2.0 - Vector2(8, 8), _view + Vector2(16, 16)),
		Color((_look.sky_top as Color).darkened(0.6), HAZE))


## Age on the brickwork: cracks, missing bricks, moss in the cellar, cobwebs in the corners.
func _draw_wear(ci: CanvasItem, inside: Rect2, seed: int, zone: int) -> void:
	var dark := Color(0.0, 0.0, 0.0, 0.28)
	for n in seed % 3:
		var h := _hash(seed, 40 + n)
		var p := inside.position + Vector2(h % int(inside.size.x), (h / 7) % int(inside.size.y))
		ci.draw_rect(Rect2(p.snapped(Vector2(16, 16)), Vector2(32, 16)), Color(0, 0, 0, 0.22))
	for n in (seed / 3) % 3:
		var h := _hash(seed, 50 + n)
		var p := inside.position + Vector2(h % int(inside.size.x), (h / 11) % int(inside.size.y * 0.6))
		var points := PackedVector2Array([p])
		for s in 4:
			p += Vector2(float((h >> (s * 3)) % 15) - 7.0, 10.0 + float((h >> (s * 2)) % 8))
			points.append(p)
		ci.draw_polyline(points, dark, 2.0)
	if zone == Zone.CELLAR:
		# Moss and damp running down from the ledge.
		for n in 6:
			var h := _hash(seed, 60 + n)
			var x := inside.position.x + float(h % int(inside.size.x))
			var length := 20.0 + float((h / 13) % 90)
			ci.draw_rect(Rect2(x, inside.position.y, 4 + (h % 3) * 2, length), Color(0.25, 0.45, 0.25, 0.22))
	if zone != Zone.TOWER and seed % 5 < 3:
		var web := COBWEBS[seed % COBWEBS.size()]
		var size := web.get_size() * BIG
		ci.draw_texture_rect(web, Rect2(inside.position, size), false, Color(1, 1, 1, 0.5))
		if seed % 2 == 0:
			ci.draw_texture_rect(web, Rect2(Vector2(inside.end.x, inside.position.y), Vector2(-size.x, size.y)),
				false, Color(1, 1, 1, 0.5))


## Cellar rooms: prison cells, storerooms, a grate high on the wall, or hanging cages.
func _draw_cellar_room(ci: CanvasItem, inside: Rect2, seed: int) -> void:
	var floor_y := inside.end.y
	match seed % 4:
		0:
			# Prison cell: the room is behind iron bars.
			ci.draw_rect(inside, Color(0, 0, 0, 0.35))
			_draw_chains(ci, Vector2(inside.get_center().x - 40, inside.position.y), 150.0)
			_draw_chains(ci, Vector2(inside.get_center().x + 40, inside.position.y), 150.0)
			_draw_bars(ci, inside, seed)
		1:
			# Storeroom: barrels and crates on the floor, stacked against the walls.
			var x := inside.position.x + 30.0
			for n in 2 + seed % 2:
				var tex := STORES[_hash(seed, n) % STORES.size()]
				Art.stand(ci, tex, Vector2(x + tex.get_width() * BIG / 2.0, floor_y), BIG, _look.decor)
				x += tex.get_width() * BIG + 20.0 + float(_hash(seed, n + 9) % 120)
				if x > inside.end.x - 120.0:
					break
		2:
			# Barred grate high on the wall, letting a little light down into the room.
			var at := Vector2(inside.get_center().x, inside.position.y + 70)
			var size := GRATE.get_size() * BIG
			_draw_shaft(ci, Rect2(at.x - size.x * 0.3, at.y, size.x * 0.6, 1), 280.0, seed)
			ci.draw_texture_rect(GRATE, Rect2(at - size / 2.0, size), false, _look.decor)
			var tex := STORES[seed % STORES.size()]
			Art.stand(ci, tex, Vector2(inside.end.x - 90, floor_y), BIG, _look.decor)
		3:
			# Hanging cages, swinging slowly on their chains.
			for n in 1 + seed % 2:
				var x := inside.position.x + inside.size.x * (0.35 + 0.3 * n)
				var drop := 90.0 + float(_hash(seed, n) % 60)
				var swing := sin(_time * 0.9 + seed + n) * 0.06
				ci.draw_set_transform(Vector2(x, inside.position.y), swing)
				ci.draw_texture_rect(CHAIN, Rect2(-7, 0, 14, drop), true, _look.decor)
				ci.draw_texture_rect(CAGE, Rect2(-CAGE.get_width() * BIG / 2.0, drop - 30,
					CAGE.get_width() * BIG, CAGE.get_height() * BIG), false, _look.decor)
				ci.draw_set_transform(Vector2.ZERO)


## Library rooms: walls of bookcases, a study desk, tall windows, or a hall with a chandelier.
func _draw_library_room(ci: CanvasItem, inside: Rect2, seed: int) -> void:
	var floor_y := inside.end.y
	var center_x := inside.get_center().x
	match seed % 4:
		0:
			# Bookcases standing side by side along the floor, a painting above.
			var x := inside.position.x + 16.0
			var n := 0
			while true:
				var tex := BOOKCASES[_hash(seed, n) % BOOKCASES.size()]
				var w := tex.get_width() * BIG
				if x + w > inside.end.x - 16.0:
					break
				Art.stand(ci, tex, Vector2(x + w / 2.0, floor_y), BIG, _look.decor)
				x += w + 6.0
				n += 1
			_draw_painting(ci, Vector2(center_x, inside.position.y + 90), seed)
		1:
			# Study: a desk with a lit candelabra, paintings on the wall.
			Art.stand(ci, DESK, Vector2(center_x, floor_y), BIG, _look.decor)
			var top := floor_y - DESK.get_height() * BIG + 8
			_draw_glow(ci, Vector2(center_x, top - 40), 1.0, seed)
			Art.stand(ci, CANDELABRA, Vector2(center_x, top), Art.PX, _look.decor)
			_draw_painting(ci, Vector2(center_x - 150, inside.position.y + 110), seed)
			_draw_painting(ci, Vector2(center_x + 150, inside.position.y + 110), seed + 1)
			var shelf := BOOKCASES[seed % BOOKCASES.size()]
			Art.stand(ci, shelf, Vector2(inside.end.x - shelf.get_width() * BIG / 2.0 - 20, floor_y), BIG, _look.decor)
		2:
			# Two tall windows with a banner between them.
			_draw_window(ci, Vector2(center_x - 130, floor_y - 150), seed, false)
			_draw_window(ci, Vector2(center_x + 130, floor_y - 150), seed + 1, false)
			_draw_banner(ci, Vector2(center_x, inside.position.y + 60), seed)
		3:
			# Hall: a gold chandelier hanging from the ledge, paintings either side.
			_draw_chandelier(ci, Vector2(center_x, inside.position.y), CHANDELIER_GOLD, seed)
			_draw_painting(ci, Vector2(inside.position.x + 110, inside.position.y + 150), seed)
			_draw_painting(ci, Vector2(inside.end.x - 110, inside.position.y + 150), seed + 3)


## Tower rooms: night windows, an iron chandelier, an armoury of statues, or a gargoyle by a window.
func _draw_tower_room(ci: CanvasItem, inside: Rect2, seed: int) -> void:
	var floor_y := inside.end.y
	var center_x := inside.get_center().x
	match seed % 4:
		0:
			_draw_window(ci, Vector2(center_x - 130, floor_y - 150), seed, false)
			_draw_window(ci, Vector2(center_x + 130, floor_y - 150), seed + 1, false)
		1:
			_draw_chandelier(ci, Vector2(center_x, inside.position.y), CHANDELIER_IRON, seed)
			Art.stand(ci, MIRROR, Vector2(inside.position.x + 90, floor_y), BIG, _look.decor)
			Art.stand(ci, STAINED, Vector2(inside.end.x - 90, floor_y - 60), BIG, _look.decor.lightened(0.15))
		2:
			# Armoury: knight statues on the floor, banners above them.
			for side in [-1.0, 1.0]:
				var x: float = center_x + side * 150.0
				Art.stand(ci, STATUES[seed % STATUES.size()], Vector2(x, floor_y), BIG, _look.decor)
				_draw_banner(ci, Vector2(x, inside.position.y + 50), seed + int(side))
			Art.stand(ci, STAINED, Vector2(center_x, floor_y - 90), BIG, _look.decor.lightened(0.15))
		3:
			_draw_window(ci, Vector2(center_x, floor_y - 150), seed, false)
			Art.stand(ci, GARGOYLE, Vector2(inside.position.x + 100, floor_y), BIG, _look.decor)


## Iron bars across a room, with a crossbar near the top and bottom and a lock in the middle.
func _draw_bars(ci: CanvasItem, inside: Rect2, seed: int) -> void:
	var iron := Color(0.13, 0.13, 0.16)
	var shine := Color(0.42, 0.44, 0.5, 0.8)
	var gap := 22.0
	var x := inside.position.x + 10.0
	while x < inside.end.x - 6.0:
		ci.draw_rect(Rect2(x, inside.position.y, 6, inside.size.y), iron)
		ci.draw_rect(Rect2(x + 1, inside.position.y, 1, inside.size.y), shine)
		x += gap
	for y in [inside.position.y + 26.0, inside.end.y - 34.0]:
		ci.draw_rect(Rect2(inside.position.x, y, inside.size.x, 8), iron)
		ci.draw_rect(Rect2(inside.position.x, y + 1, inside.size.x, 1), shine)
	var lock := Vector2(inside.get_center().x + float(seed % 60) - 30.0, inside.get_center().y + 20)
	ci.draw_rect(Rect2(lock - Vector2(9, 11), Vector2(18, 22)), Color(0.32, 0.26, 0.12))
	ci.draw_rect(Rect2(lock - Vector2(2, 3), Vector2(4, 8)), Color(0.05, 0.04, 0.03))


func _draw_chains(ci: CanvasItem, top: Vector2, length: float) -> void:
	ci.draw_texture_rect(CHAIN, Rect2(top.x - 7, top.y, 14, length), true, _look.decor)


func _draw_painting(ci: CanvasItem, center: Vector2, seed: int) -> void:
	var tex := PAINTINGS[posmod(seed, PAINTINGS.size())]
	var size := tex.get_size() * BIG
	ci.draw_texture_rect(tex, Rect2(center - size / 2.0, size), false, _look.decor)


## Chandelier hanging from a ledge on a short chain, candles flickering.
func _draw_chandelier(ci: CanvasItem, top: Vector2, frames: Array[Texture2D], seed: int) -> void:
	var drop := 40.0
	_draw_chains(ci, top, drop)
	var tex := frames[int(_time * 6.0 + seed) % frames.size()]
	var size := tex.get_size() * BIG
	_draw_glow(ci, top + Vector2(0, drop + size.y * 0.5), 1.6, seed)
	ci.draw_texture_rect(tex, Rect2(top + Vector2(-size.x / 2.0, drop), size), false, _look.decor.lightened(0.1))


## Flickering pool of light.
func _draw_glow(ci: CanvasItem, at: Vector2, strength: float, seed: int) -> void:
	var flicker := 0.85 + 0.15 * sin(_time * 9.0 + seed) * sin(_time * 5.3 + seed * 0.7)
	var light: Color = _look.light
	for ring in [[110.0, 0.035], [70.0, 0.05], [40.0, 0.08], [20.0, 0.12]]:
		ci.draw_circle(at, ring[0] * flicker * strength, Color(light, ring[1] * flicker))


## Torch on a pillar: animated flame with its light.
func _draw_torch(ci: CanvasItem, at: Vector2, seed: int) -> void:
	_draw_glow(ci, at, 1.0, seed)
	var frame := FLAMES[int(_time * 9.0 + seed) % FLAMES.size()]
	Art.stand(ci, frame, at + Vector2(0, 14), Art.PX)


## Light falling from an opening down into the room.
func _draw_shaft(ci: CanvasItem, opening: Rect2, length: float, seed: int) -> void:
	var shafts: float = _look.shafts
	if shafts < 0.05:
		return
	var sway := sin(_time * 0.3 + seed) * 10.0
	var colour := Color(_look.light, 0.07 * shafts + _flash * 0.1)
	ci.draw_colored_polygon(PackedVector2Array([
		Vector2(opening.position.x, opening.end.y), Vector2(opening.end.x, opening.end.y),
		Vector2(opening.end.x + length * 0.5 + sway, opening.end.y + length),
		Vector2(opening.position.x + length * 0.2 + sway, opening.end.y + length),
	]), colour)


## Banner hanging from the ledge, swaying a little as if there's a draught.
func _draw_banner(ci: CanvasItem, top: Vector2, seed: int) -> void:
	var tex := BANNERS[posmod(seed, BANNERS.size())]
	ci.draw_set_transform(top, sin(_time * 1.4 + seed) * 0.05)
	ci.draw_texture_rect(tex, Rect2(-tex.get_size().x * BIG / 2.0, 0,
		tex.get_size().x * BIG, tex.get_size().y * BIG), false, _look.decor)
	ci.draw_set_transform(Vector2.ZERO)


## Glass area of window_arch_1.png (sprite pixels): the pane, and the pointed arch above it.
const PANE := Rect2(5, 17, 13, 25)
const ARCH := [Vector2(11.5, 8), Vector2(18, 17), Vector2(5, 17)]


## Tall arched window showing the sky behind the castle.
func _draw_window(ci: CanvasItem, at: Vector2, seed: int, barred: bool) -> void:
	var scale := 3.0
	var size := WINDOW.get_size() * scale
	var rect := Rect2(at - size / 2.0, size)
	# Frame first (the sprite is a closed shutter), then the sky painted into its glass.
	Art.stand(ci, WINDOW, rect.end - Vector2(size.x / 2.0, 0), scale, _look.decor)
	var inner := Rect2(rect.position + PANE.position * scale, PANE.size * scale)
	var sky_top: Color = (_look.sky_top as Color).lerp(Color(0.85, 0.9, 1.0), _flash * 0.6)
	var sky_low: Color = (_look.sky_low as Color).lerp(Color(0.85, 0.9, 1.0), _flash * 0.6)
	ci.draw_colored_polygon(PackedVector2Array(ARCH.map(func(p: Vector2) -> Vector2:
		return rect.position + p * scale)), sky_top)
	var bands := 8
	for b in bands:
		var colour := sky_top.lerp(sky_low, float(b) / (bands - 1))
		ci.draw_rect(Rect2(inner.position.x, inner.position.y + inner.size.y * b / bands,
			inner.size.x, inner.size.y / bands + 1.0), colour)
	var pane := inner
	inner = inner.merge(Rect2(rect.position + Vector2(5, 8) * scale, Vector2(13, 9) * scale))
	var stars: float = _look.stars
	if stars > 0.05:
		for s in 7:
			var h := _hash(seed, s)
			var p := Vector2(float(h % 997) / 997.0, float((h / 997) % 991) / 991.0)
			var twinkle := 0.5 + 0.5 * sin(_time * (1.5 + s * 0.4) + h)
			ci.draw_rect(Rect2(inner.position + p * inner.size, Vector2(2, 2)), Color(1, 1, 0.9, stars * twinkle))
	if _look.rain > 0.5 and seed % 3 == 0:
		var moon := inner.position + Vector2(inner.size.x * 0.6, inner.size.y * 0.25)
		ci.draw_circle(moon, 9.0, Color(0.95, 0.95, 0.85, 0.9))
		ci.draw_circle(moon + Vector2(-4, -2), 8.0, (_look.sky_top as Color).lightened(0.05))
	var frame := Color(0.12, 0.09, 0.12)
	if barred:
		for x in range(1, 4):
			ci.draw_rect(Rect2(pane.position.x + pane.size.x * x / 4.0 - 2, inner.position.y + 20,
				4, pane.end.y - inner.position.y - 20), frame)
	else:
		ci.draw_rect(Rect2(pane.get_center().x - 1.5, inner.position.y + 18, 3, pane.end.y - inner.position.y - 18), frame)
		ci.draw_rect(Rect2(pane.position.x, pane.position.y + pane.size.y * 0.45, pane.size.x, 3), frame)
	_draw_shaft(ci, Rect2(pane.position.x, pane.end.y - 1, pane.size.x, 1), 220.0, seed)


# ---------------------------------------------------------------- moving life

func _pick_kind() -> int:
	var weights: Array = KIND_WEIGHTS[_zone]
	var total := 0
	for w in weights:
		total += w
	var roll := _rng.randi_range(0, total - 1)
	for kind in weights.size():
		roll -= weights[kind]
		if roll < 0:
			return kind
	return Kind.DUST


## A particle somewhere on screen (or just above/below it for falling and rising kinds).
func _new_particle(anywhere: bool) -> Dictionary:
	var kind := _pick_kind()
	var pos := Vector2(_rng.randf() * _view.x, _rng.randf() * _view.y)
	var vel := Vector2.ZERO
	match kind:
		Kind.DUST: vel = Vector2(_rng.randf_range(-8, 8), _rng.randf_range(-6, 6))
		Kind.DRIP:
			vel = Vector2(0, _rng.randf_range(200, 280))
			if not anywhere:
				pos.y = -10
		Kind.SPORE: vel = Vector2(_rng.randf_range(-6, 6), _rng.randf_range(-25, -12))
		Kind.EMBER:
			vel = Vector2(_rng.randf_range(-12, 12), _rng.randf_range(-70, -40))
			if not anywhere:
				pos.y = _view.y + 10
		Kind.RAIN:
			vel = Vector2(-140, _rng.randf_range(520, 640))
			if not anywhere:
				pos = Vector2(_rng.randf() * (_view.x + 200), -20)
		Kind.SPARK: vel = Vector2(_rng.randf_range(-10, 10), _rng.randf_range(-30, -10))
	return {"kind": kind, "pos": pos, "vel": vel, "seed": _rng.randf() * 100.0,
		"life": _rng.randf_range(4.0, 9.0), "age": 0.0 if not anywhere else _rng.randf() * 3.0}


func _update_particles(delta: float, camera_moved: Vector2) -> void:
	var margin := 30.0
	for i in _particles.size():
		var p := _particles[i]
		p.age += delta
		var pos: Vector2 = p.pos + p.vel * delta - camera_moved * LIFE_PARALLAX
		if p.kind in [Kind.DUST, Kind.SPORE, Kind.SPARK]:
			pos.x += sin(_time * 1.3 + p.seed) * 6.0 * delta
		var outside := pos.x < -margin or pos.x > _view.x + margin \
			or pos.y < -margin or pos.y > _view.y + margin
		if p.age > p.life or outside:
			_particles[i] = _new_particle(false)
			# Slow drifters come back anywhere; the rest re-enter from their edge.
			if _particles[i].kind in [Kind.DUST, Kind.SPORE, Kind.SPARK]:
				_particles[i].pos = Vector2(_rng.randf() * _view.x, _rng.randf() * _view.y)
			continue
		p.pos = pos


func _update_flyers(delta: float) -> void:
	_flyer_timer -= delta
	var rate := {Zone.CELLAR: 14.0, Zone.LIBRARY: 9.0, Zone.TOWER: 6.0}[_zone] as float
	if _flyer_timer <= 0.0:
		_flyer_timer = _rng.randf_range(rate * 0.6, rate * 1.4)
		var from_left := _rng.randf() < 0.5
		var flock := 1 if _zone == Zone.CELLAR else _rng.randi_range(1, 3)
		for b in flock:
			_flyers.append({
				"pos": Vector2(-40.0 - b * 30.0 if from_left else _view.x + 40.0 + b * 30.0,
					_rng.randf_range(_view.y * 0.1, _view.y * 0.7) + b * 18.0),
				"vel": Vector2(_rng.randf_range(130, 210) * (1.0 if from_left else -1.0), 0),
				"size": _rng.randf_range(1.2, 2.2), "seed": _rng.randf() * 10.0,
			})
	var camera_moved := (_center - _last_center) * LIFE_PARALLAX if _last_center != Vector2.ZERO else Vector2.ZERO
	for f in _flyers:
		f.pos += f.vel * delta - camera_moved
		f.pos.y += sin(_time * 3.0 + f.seed) * 30.0 * delta
	_flyers = _flyers.filter(func(f: Dictionary) -> bool:
		return f.pos.x > -200 and f.pos.x < _view.x + 200)


func _update_lightning(delta: float) -> void:
	_flash = maxf(0.0, _flash - delta * 3.0)
	var chance: float = _look.lightning
	if chance < 0.3:
		return
	_flash_timer -= delta
	if _flash_timer <= 0.0:
		_flash_timer = _rng.randf_range(5.0, 11.0)
		_flash = 1.0
	# Second flicker shortly after the first, like real lightning.
	elif _flash_timer > 0.0 and _flash < 0.3 and _flash > 0.25:
		_flash = 0.7


func _draw_life() -> void:
	var ci := _life_layer
	var origin := _center - _view / 2.0
	ci.draw_set_transform(origin)
	var light: Color = _look.light
	for p in _particles:
		var fade := clampf(minf(p.age, p.life - p.age), 0.0, 1.0)
		var pos: Vector2 = p.pos
		match p.kind:
			Kind.DUST:
				ci.draw_rect(Rect2(pos, Vector2(2, 2)), Color(light, 0.35 * fade))
			Kind.DRIP:
				ci.draw_rect(Rect2(pos, Vector2(2, 6)), Color(0.6, 0.78, 0.8, 0.55))
			Kind.SPORE:
				ci.draw_circle(pos, 4.0, Color(0.45, 1.0, 0.55, 0.1 * fade))
				ci.draw_rect(Rect2(pos - Vector2.ONE, Vector2(2, 2)), Color(0.6, 1.0, 0.65, 0.7 * fade))
			Kind.EMBER:
				var glow := 0.6 + 0.4 * sin(_time * 12.0 + p.seed)
				ci.draw_rect(Rect2(pos, Vector2(2, 2)), Color(1.0, 0.55, 0.15, glow * fade))
			Kind.RAIN:
				ci.draw_line(pos, pos + Vector2(-5, 18), Color(0.75, 0.85, 1.0, 0.55 * _look.rain), 1.5)
			Kind.SPARK:
				# Morwen's hex magic: brighter the higher you climb.
				var a: float = (0.3 + 0.5 * absf(sin(_time * 3.0 + p.seed))) * fade * _look.sparks
				var c := Color(0.75, 0.45, 1.0, a) if int(p.seed) % 2 == 0 else Color(0.4, 1.0, 0.9, a)
				ci.draw_rect(Rect2(pos - Vector2(0, 2), Vector2(1, 5)), c)
				ci.draw_rect(Rect2(pos - Vector2(2, 0), Vector2(5, 1)), c)

	for f in _flyers:
		_draw_bat(ci, f.pos, f.size, f.seed, f.vel.x > 0.0)

	# Cellar fog rolling along the bottom of the screen.
	var fog: float = _look.fog
	if fog > 0.02:
		for band in 4:
			var y := _view.y - 40.0 - band * 34.0 + sin(_time * 0.5 + band) * 8.0
			ci.draw_rect(Rect2(-20, y, _view.x + 40, 60), Color(0.45, 0.62, 0.52, 0.05 * fog))

	# Soft dark edges so the middle of the screen, where you are, reads first.
	for ring in 6:
		var w := 26.0 * (ring + 1)
		var shade := Color(0.0, 0.0, 0.02, 0.045)
		ci.draw_rect(Rect2(0, 0, _view.x, w), shade)
		ci.draw_rect(Rect2(0, _view.y - w, _view.x, w), shade)
		ci.draw_rect(Rect2(0, 0, w, _view.y), shade)
		ci.draw_rect(Rect2(_view.x - w, 0, w, _view.y), shade)

	# Lightning lights up the whole background for a moment.
	if _flash > 0.0:
		ci.draw_rect(Rect2(Vector2.ZERO, _view), Color(0.8, 0.85, 1.0, 0.06 * _flash))
	ci.draw_set_transform(Vector2.ZERO)


## Little bat silhouette with flapping wings.
func _draw_bat(ci: CanvasItem, pos: Vector2, size: float, seed: float, facing_right: bool) -> void:
	var flap := sin(_time * 18.0 + seed * 5.0)
	var body := Color(0.04, 0.03, 0.07, 0.9)
	var wing := Vector2(7.0, -4.0 * flap) * size
	var dir := 1.0 if facing_right else -1.0
	ci.draw_rect(Rect2(pos - Vector2(2, 2) * size, Vector2(4, 4) * size), body)
	ci.draw_line(pos, pos + Vector2(wing.x, wing.y), body, 2.0 * size)
	ci.draw_line(pos, pos + Vector2(-wing.x, wing.y), body, 2.0 * size)
	ci.draw_rect(Rect2(pos + Vector2(dir * 2.0 * size, -3.0 * size), Vector2(2, 2) * size), body)


func _hash(a: int, b: int) -> int:
	var h := a * 73856093 ^ b * 19349663
	h = (h ^ (h >> 13)) * 1274126177
	return absi(h ^ (h >> 16))

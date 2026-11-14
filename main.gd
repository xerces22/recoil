extends Node2D
## Builds the tower: every floor in FLOORS stacked into one continuous climb.
## Number keys load a single floor (or sandbox) on its own for testing. T jumps to the boss orb.

const RecoilPlayer = preload("res://player.gd")
const Preferences = preload("res://game_preferences.gd")
const SettingsMenu = preload("res://settings_menu.gd")

## The tower, bottom to top. Each floor's `Entry` hole is lined up with the `Exit` hole
## of the floor below. Add new floors here, in order.
const FLOORS: Array[String] = [
	"res://levels/level_01_wake_up.tscn",
	"res://levels/level_02_chimney.tscn",
	"res://levels/level_03_chain_lift.tscn",
	"res://levels/level_04_quiet_please.tscn",
	"res://levels/level_05_rotten_shelves.tscn",
	"res://levels/level_06_gargoyle_gallery.tscn",
	"res://levels/level_07_mind_the_doors.tscn",
	"res://levels/level_08_its_boiling.tscn",
	"res://levels/level_09_everything_hates_you.tscn",
	"res://levels/level_10_morwen.tscn",
]

## Test levels. Empty in the release build (see planned_release_debug).
const SANDBOXES: Array[String] = [
	"res://levels/level_01_counterweight.tscn",
	"res://levels/level_02_switchyard.tscn",
	"res://levels/level_03_shellworks.tscn",
	"res://levels/level_1_basics.tscn",
	"res://levels/level_2_bounce.tscn",
	"res://levels/level_3_moving.tscn",
	"res://levels/level_4_turrets.tscn",
	"res://levels/level_5_mouths.tscn",
	"res://levels/level_6_flood.tscn",
	"res://levels/level_7_refills.tscn",
]

## Music: cellar track for the first CELLAR_LEVELS floors, final track on the last floor,
## main climb track for everything between. Works for any number of floors.
const MUSIC_CELLAR := preload("res://assets/music/castle_in_the_darkness_2.wav")
const MUSIC_CLIMB := preload("res://assets/music/monstervania_2.mp3")
const MUSIC_FINAL := preload("res://assets/music/final_castle.mp3")
const CELLAR_LEVELS := 2

const FONT := preload("res://assets/fonts/PressStart2P-Regular.ttf")

## Camera: how far ahead it leads in the flight direction, and how fast the lead catches up.
const LOOK_AHEAD := 120.0
const LOOK_SPEED := 3.0
## The player sits this far below the screen centre, since the goal is usually above.
const CAMERA_LIFT := 100.0
## Flying this far above a floor's Exit marker clears that floor when it's loaded on its own.
const EXIT_CLEAR_MARGIN := 24.0

@onready var music: AudioStreamPlayer = get_node_or_null("Music")
@onready var world_surface: TextureRect = $WorldSurface
@onready var world_viewport: SubViewport = $WorldSurface/World
@onready var backdrop = $WorldSurface/World/Backdrop
@onready var player: RecoilPlayer = $WorldSurface/World/Player
@onready var camera: Camera2D = $WorldSurface/World/Camera2D
@onready var title_label: Label = $HUD/Title
@onready var instructions: Label = $HUD/Instructions
@onready var stats: Label = $HUD/Stats
@onready var level_root: Node2D = $WorldSurface/World/Level

## Every level the number keys can load: the floors first, then the sandboxes.
var levels: Array[String] = []
## Floors currently loaded, bottom to top. One entry when testing a single level.
var floors: Array[Level] = []
## Tower floor number (0-based) of each loaded floor, or -1 for a sandbox.
var floor_numbers: Array[int] = []
var tower_mode := true
## Index into `floors` of the floor the player is in now, and the highest one reached.
var current := 0
var highest := 0
## The floor the player is in. Same as floors[current].
var level: Level
var level_index := 0

var checkpoints: Array[Checkpoint] = []
var floods: Array[RisingHazard] = []
var refills: Array[ShellRefill] = []
var deaths := 0
var elapsed := 0.0
var cleared := false
var look := Vector2.ZERO
var banner: VBoxContainer
var banner_tween: Tween
var preferences := Preferences.new()


func _ready() -> void:
	levels.assign(FLOORS + SANDBOXES)
	if music == null:
		# Builds without the Music node in main.tscn still get music.
		music = AudioStreamPlayer.new()
		music.name = "Music"
		music.volume_db = -6.0
		add_child(music)
	music.bus = &"Music"
	music.process_mode = Node.PROCESS_MODE_ALWAYS
	preferences.load_saved()
	preferences.gameplay_changed.connect(_apply_gameplay_settings)
	player.aim_surface = world_surface
	get_viewport().size_changed.connect(_update_render_quality)
	_apply_gameplay_settings()
	var settings := SettingsMenu.new()
	settings.name = "Settings"
	settings.preferences = preferences
	settings.player = player
	settings.game = self
	settings.start_requested.connect(new_game)
	settings.restart_requested.connect(_restart_current_floor)
	settings.quit_requested.connect(_end_run)
	player.died.connect(_on_player_died)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 6.0
	camera.limit_smoothed = true
	music.finished.connect(music.play)
	_build_banner()
	load_tower()
	$HUD.hide()
	add_child(settings)


func _apply_gameplay_settings() -> void:
	player.shoot_button = preferences.values.shoot_button
	player.show_aim_guide = preferences.values.aim_guide
	player.queue_redraw()
	backdrop.show_decor = preferences.values.background_detail
	_update_render_quality()


func _update_render_quality() -> void:
	var logical_size := Vector2i(get_viewport().get_visible_rect().size.round())
	if logical_size.x < 4 or logical_size.y < 4:
		return
	var divisor: int = preferences.values.render_divisor
	world_surface.size = Vector2(logical_size)
	world_viewport.size_2d_override = logical_size
	world_viewport.size = logical_size / divisor
	_sync_world_camera.call_deferred()
	backdrop.queue_redraw()


func _sync_world_camera() -> void:
	camera.force_update_scroll()


func _start_run() -> void:
	load_tower()
	$HUD.show()


## New Game: story cards, then the climb from floor 1.
func new_game() -> void:
	_start_run()
	# Opening storyboard (Mr. Guy meets Mrs. Sandwitch). Can't be skipped; frees itself.
	var intro: StoryIntro = preload("res://story_intro.gd").new()
	add_child(intro)
	intro.finished.connect(_drop_into_cellar)
	intro.play()


## The storyboard ends with her throwing him in the cellar: start the run falling from
## the top of floor 1 down onto its start ledge.
func _drop_into_cellar() -> void:
	var start := (floors[0].get_node("Start") as Node2D).global_position
	player.position = start + Vector2(0, -1300)
	player.velocity = Vector2.ZERO
	look = Vector2.ZERO
	_update_camera(0.0)
	camera.reset_smoothing()


## Continue: the whole tower, starting at the bottom of floor `index`.
func continue_from(index: int) -> void:
	_start_run()
	if index <= 0:
		return
	player.set_respawn_point((floors[index].get_node("Start") as Node2D).global_position)
	player.respawn("continue from floor %d" % (index + 1))
	_enter_floor(index, true)
	look = Vector2.ZERO
	_update_camera(0.0)
	camera.reset_smoothing()


# ---------------------------------------------------------------- saved progress

const PROGRESS_PATH := "user://progress.cfg"


## Highest floor index ever reached (0 = only floor 1).
func reached_floor() -> int:
	var config := ConfigFile.new()
	if config.load(PROGRESS_PATH) != OK:
		return 0
	return clampi(int(config.get_value("progress", "reached", 0)), 0, FLOORS.size() - 1)


## True once the witch has been beaten: the menu offers Level Select with the boss in it.
func boss_beaten() -> bool:
	var config := ConfigFile.new()
	if config.load(PROGRESS_PATH) != OK:
		return false
	return bool(config.get_value("progress", "beaten", false))


func _save_beaten() -> void:
	var config := ConfigFile.new()
	config.load(PROGRESS_PATH)
	config.set_value("progress", "beaten", true)
	config.set_value("progress", "reached", FLOORS.size() - 1)
	config.save(PROGRESS_PATH)


func _save_reached(index: int) -> void:
	if index <= reached_floor():
		return
	var config := ConfigFile.new()
	config.load(PROGRESS_PATH)
	config.set_value("progress", "reached", index)
	config.save(PROGRESS_PATH)


## Floor titles in tower order, for the floor select.
func floor_titles() -> Array[String]:
	var titles: Array[String] = []
	for i in FLOORS.size():
		titles.append(floors[i].title if tower_mode and i < floors.size() else "Floor %d" % (i + 1))
	return titles


func _end_run() -> void:
	$HUD.hide()
	# Reset the scene behind the title and discard the ended run.
	load_tower()


func _restart_current_floor() -> void:
	if not tower_mode:
		load_level(level_index)
		return
	var index := current
	var old := floors[index]
	var replacement: Level = load(FLOORS[index]).instantiate()
	replacement.position = old.position
	level_root.remove_child(old)
	old.queue_free()
	level_root.add_child(replacement)
	floors[index] = replacement
	_rebuild_hazard_lists()
	cleared = false
	player.set_respawn_point((replacement.get_node("Start") as Node2D).global_position)
	player.respawn("floor restarted")
	_enter_floor(index)
	look = Vector2.ZERO
	_update_camera(0.0)
	camera.reset_smoothing()


func _play_music(floor_number: int) -> void:
	var track: AudioStream = MUSIC_CLIMB
	if floor_number >= 0 and floor_number < CELLAR_LEVELS:
		track = MUSIC_CELLAR
	elif floor_number == FLOORS.size() - 1 and floor_number > 0:
		track = MUSIC_FINAL
	if music.stream != track:
		music.stream = track
		music.play()


func _unhandled_input(event: InputEvent) -> void:
	if _boss != null:
		return
	player.handle_game_input(event)
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	# Debug keys: 1-9 / 0 load one level, T teleports to the boss, R respawns, N skips a checkpoint.
	var number: int = 9 if event.keycode == KEY_0 else event.keycode - KEY_1
	if number >= 0 and number < levels.size():
		load_level(number)
	elif event.keycode == KEY_T:
		_teleport_to_orb()
	elif event.keycode == KEY_R:
		player.die("restart key")
	elif event.keycode == KEY_N:
		skip_to_next_checkpoint()


## TEMP test key (T): drop onto the top floor's orb platform, which starts the boss fight.
func _teleport_to_orb() -> void:
	if not tower_mode:
		load_tower()
	var top := floors.back() as Level
	var orb := top.find_child("HexOrb", true, false) as Node2D
	if orb == null:
		return
	player.cancel_shot()
	# Just left of the orb, a little above its platform; you drop onto it.
	player.respawn_position = orb.global_position + Vector2(-140, 120)
	player.respawn("T to the orb")


## Loads every floor stacked into one tower and starts at the bottom.
func load_tower() -> void:
	tower_mode = true
	level_index = 0
	var numbers: Array[int] = []
	for i in FLOORS.size():
		numbers.append(i)
	_build(FLOORS, numbers)


## Loads one floor or sandbox on its own, for testing.
func load_level(index: int) -> void:
	tower_mode = false
	level_index = index
	var number := index if index < FLOORS.size() else -1
	_build([levels[index]], [number])


func _build(paths: Array[String], numbers: Array[int]) -> void:
	for old in level_root.get_children():
		level_root.remove_child(old)
		old.queue_free()
	floors.clear()
	floor_numbers = numbers
	checkpoints.clear()
	floods.clear()
	refills.clear()
	for path in paths:
		var next: Level = load(path).instantiate()
		if not floors.is_empty():
			next.position = _stack_offset(floors.back(), next)
		level_root.add_child(next)
		floors.append(next)
		_collect(next)
	# New spikes register against the player's position from the PREVIOUS floor for one physics
	# step, so switching floors could kill you on arrival. Keep them off until you've moved in.
	var new_spikes := level_root.find_children("*", "Spikes", true, false)
	for spikes in new_spikes:
		spikes.monitoring = false
	_rearm_spikes.call_deferred(new_spikes)
	# Lowest first, so "next checkpoint" means the next one up.
	checkpoints.sort_custom(func(a: Checkpoint, b: Checkpoint) -> bool:
		return a.global_position.y > b.global_position.y)

	deaths = 0
	elapsed = 0.0
	cleared = false
	highest = 0
	player.set_respawn_point((floors[0].get_node("Start") as Node2D).global_position)
	player.respawn("%s loaded" % ("tower" if tower_mode else "level %d" % (level_index + 1)))
	_enter_floor(0, true)
	look = Vector2.ZERO
	_update_camera(0.0)
	camera.reset_smoothing()


func _rearm_spikes(list: Array[Node]) -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	for spikes in list:
		if is_instance_valid(spikes):
			spikes.monitoring = true


## Where to put `next` so its Entry hole sits on the Exit hole of `below`.
func _stack_offset(below: Level, next: Level) -> Vector2:
	var exit := below.get_node_or_null("Exit") as Node2D
	var entry := next.get_node_or_null("Entry") as Node2D
	if exit != null and entry != null:
		return below.position + exit.position - entry.position
	push_warning("%s needs an Exit and %s needs an Entry marker to line up. Stacking by bounds instead." % [
		below.name, next.name])
	return below.position + Vector2(below.bounds.position.x - next.bounds.position.x,
		below.bounds.position.y - next.bounds.end.y)


## A floor's playable area in world space.
func _area(index: int) -> Rect2:
	var f := floors[index]
	return Rect2(f.bounds.position + f.position, f.bounds.size)


## Which floor a world y is in: you're in floor N+1 once you rise past the top of floor N.
func _floor_at(y: float) -> int:
	for i in range(floors.size() - 1, 0, -1):
		if y < _area(i - 1).position.y:
			return i
	return 0


func _enter_floor(index: int, first := false) -> void:
	current = index
	level = floors[index]
	var area := _area(index)
	var tower_top := _area(floors.size() - 1).position.y
	var tower_bottom := _area(0).end.y
	# Sides come from the floor you're in; top and bottom span the whole tower.
	camera.limit_left = int(area.position.x)
	camera.limit_right = int(area.end.x)
	camera.limit_top = int(tower_top)
	camera.limit_bottom = int(tower_bottom)
	player.bounds = Rect2(area.position.x, tower_top, area.size.x, tower_bottom - tower_top)

	var number := floor_numbers[index]
	if number >= 0:
		title_label.text = "Floor %d/%d  %s" % [number + 1, FLOORS.size(), level.title]
	else:
		title_label.text = "Sandbox  %s" % level.title
	instructions.text = level.hint
	backdrop.target_tint = level.backdrop_tint
	_play_music(number)

	if first or index > highest:
		highest = maxi(highest, index)
		if tower_mode and number >= 0:
			_save_reached(number)
		if number >= 0:
			_show_banner(number, level)
		player.debug_event.emit("Entered %s" % level.title)
		# Floods below stay behind once you leave their floor.
		for flood in floods:
			if _floor_of(flood) < index:
				flood.stop()


func _collect(node: Node) -> void:
	for child in node.get_children():
		if child is Checkpoint:
			checkpoints.append(child)
		elif child is RisingHazard:
			floods.append(child)
		elif child is ShellRefill:
			refills.append(child)
		_collect(child)


func _rebuild_hazard_lists() -> void:
	checkpoints.clear()
	floods.clear()
	refills.clear()
	for floor_node in floors:
		_collect(floor_node)
	# Lowest first, so "next checkpoint" means the next one up.
	checkpoints.sort_custom(func(a: Checkpoint, b: Checkpoint) -> bool:
		return a.global_position.y > b.global_position.y)


## Index into `floors` of the floor a node belongs to.
func _floor_of(node: Node) -> int:
	var at := node
	while at != null:
		for i in floors.size():
			if floors[i] == at:
				return i
		at = at.get_parent()
	return -1


## A finish checkpoint only ends the run on the top floor of the tower. On lower floors it's
## a stand-in used for testing a floor on its own, and acts as a normal checkpoint.
func _is_goal(checkpoint: Checkpoint) -> bool:
	return checkpoint.is_finish and (not tower_mode or _floor_of(checkpoint) == floors.size() - 1)


func _physics_process(_delta: float) -> void:
	# Runs before the player's physics, so bounds are right for this frame.
	var index := _floor_at(player.global_position.y)
	if index != current:
		_enter_floor(index)


func _process(delta: float) -> void:
	_update_camera(delta)
	if not cleared:
		elapsed += delta
	# Lifetime stats: total play time, plus time on this floor or in the boss fight.
	GameStats.tick(delta, _stats_key())

	# Standing on a checkpoint with the body or resting the barrel on it both count.
	for ground in player.standing_on:
		if is_instance_valid(ground) and ground.is_in_group("void_after_checkpoint"):
			var start := floors[_floor_of(ground)].get_node("Start") as Node2D
			if player.respawn_position.y < start.global_position.y:
				player.die("void")
				break
		if ground is Checkpoint:
			_reach(ground)
			break

	# Testing one floor on its own: flying up through its exit hole clears it.
	if not tower_mode and not cleared:
		var exit := floors[0].get_node_or_null("Exit") as Node2D
		if exit != null and player.global_position.y < exit.global_position.y - EXIT_CLEAR_MARGIN:
			_clear()

	var saved := checkpoints.filter(func(c: Checkpoint) -> bool: return c.reached and not _is_goal(c)).size()
	var total := checkpoints.filter(func(c: Checkpoint) -> bool: return not _is_goal(c)).size()
	var status := "Time %s   Deaths %d   Checkpoints %d/%d" % [_format_time(elapsed), deaths, saved, total]
	if cleared:
		var next: String
		if tower_mode:
			next = "You reached the top!"
		else:
			next = "That was the last level."
		status = "CLEAR!  " + status + "\n" + next
	stats.text = status


func _reach(checkpoint: Checkpoint) -> void:
	if _is_goal(checkpoint):
		checkpoint.reached = true
		_clear()
		return
	if checkpoint.reached:
		return
	var top := checkpoint.world_rect().position.y
	# Only move the respawn point upward.
	if top - 14.0 >= player.respawn_position.y:
		return
	checkpoint.reached = true
	player.set_respawn_point(Vector2(checkpoint.global_position.x, top - 14.0), true)
	player.debug_event.emit("Checkpoint at %s" % player.position.round())
	for flood in floods:
		flood.give_breathing_room(player.global_position.y)


func _clear() -> void:
	if cleared:
		return
	cleared = true
	player.debug_event.emit("Clear at %s  time %s  deaths %d" % [
		player.position.round(), _format_time(elapsed), deaths])
	for flood in floods:
		flood.stop()
	# Top of the tower: the witch fight.
	if tower_mode and level != null and level.is_final:
		_start_boss.call_deferred()


var _boss: BossFight


## Final fight on its own screen. Beating it unlocks the boss in Level Select; running out of
## shells offers Retry (straight back into the fight) or the menu.
func _start_boss(retry := false) -> void:
	if _boss != null:
		return
	player.cancel_shot()
	$HUD.hide()
	_boss = BossFight.new()
	# Running out of shells counts as a death in the boss fight.
	_boss.lost.connect(func(_retry: bool) -> void: GameStats.add_death("boss"))
	_boss.game = self
	_boss.retry = retry
	add_child(_boss)
	_boss.won.connect(func() -> void:
		_save_beaten()
		get_node("Settings").pause_locked = true)
	_boss.finished.connect(func() -> void:
		get_node("Settings")._quit_run()
		await get_tree().create_timer(0.4).timeout
		_close_boss())
	_boss.lost.connect(func(again: bool) -> void:
		if again:
			_close_boss()
			_start_boss.call_deferred(true)
		else:
			get_node("Settings")._quit_run()
			await get_tree().create_timer(0.4).timeout
			_close_boss())


func _close_boss() -> void:
	get_node("Settings").pause_locked = false
	if _boss != null:
		_boss.queue_free()
		_boss = null


## Level Select > the witch: the tower with you at the top, straight into the fight.
func start_boss_from_menu() -> void:
	continue_from(FLOORS.size() - 1)
	_start_boss()


## Follows the player on both axes, leading a little in the flight direction.
func _update_camera(delta: float) -> void:
	# Hold the lead still while aiming in slow motion, so the view doesn't swing.
	if not player.is_air_charging():
		var target := (player.velocity * 0.2).limit_length(LOOK_AHEAD)
		look = look.lerp(target, minf(1.0, LOOK_SPEED * delta))
	var goal := player.position + look - Vector2(0, CAMERA_LIFT)
	camera.position = goal
	# Respawns and checkpoint skips teleport the player: cut instead of panning.
	if camera.get_screen_center_position().distance_to(goal) > 900.0:
		camera.reset_smoothing()


func _build_banner() -> void:
	banner = VBoxContainer.new()
	banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	banner.offset_left = -600
	banner.offset_right = 600
	banner.offset_top = 130
	banner.alignment = BoxContainer.ALIGNMENT_CENTER
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.add_theme_constant_override("separation", 14)
	banner.modulate.a = 0.0
	for spec: Array in [[16, Color(0.75, 0.65, 0.85)], [30, Color(1.0, 0.92, 0.75)], [14, Color(0.8, 0.45, 1.0)]]:
		var label := Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_font_override("font", FONT)
		label.add_theme_font_size_override("font_size", spec[0])
		label.add_theme_color_override("font_color", spec[1])
		label.add_theme_color_override("font_outline_color", Color(0.06, 0.03, 0.09))
		label.add_theme_constant_override("outline_size", 10)
		banner.add_child(label)
	$HUD.add_child(banner)


## Big "FLOOR N / title / taunt" card when the player rises into a new floor.
func _show_banner(number: int, floor_level: Level) -> void:
	var lines := banner.get_children()
	(lines[0] as Label).text = "FLOOR %d" % (number + 1)
	(lines[1] as Label).text = floor_level.title.to_upper()
	(lines[2] as Label).text = "MRS. SANDWITCH: \"%s\"" % floor_level.taunt if floor_level.taunt != "" else ""
	(lines[2] as Label).visible = floor_level.taunt != ""
	if banner_tween != null:
		banner_tween.kill()
	banner.modulate.a = 0.0
	banner_tween = create_tween()
	banner_tween.tween_property(banner, "modulate:a", 1.0, 0.35)
	banner_tween.tween_interval(2.4 if floor_level.taunt == "" else 3.4)
	banner_tween.tween_property(banner, "modulate:a", 0.0, 0.8)


## Testing shortcut: jump to the next checkpoint up.
func skip_to_next_checkpoint() -> void:
	for checkpoint in checkpoints:
		if not checkpoint.reached and not _is_goal(checkpoint):
			var top := checkpoint.world_rect().position.y
			checkpoint.reached = true
			player.set_respawn_point(Vector2(checkpoint.global_position.x, top - 14.0), true)
			player.respawn("skipped to checkpoint")
			for flood in floods:
				flood.reset()
			return


## Stats bucket for where the player is now: "boss", "floor_N" in the tower, or "" (total only).
func _stats_key() -> String:
	if _boss != null:
		return "boss"
	if tower_mode and current < floor_numbers.size() and floor_numbers[current] >= 0:
		return "floor_%d" % floor_numbers[current]
	return ""


func _on_player_died() -> void:
	deaths += 1
	GameStats.add_death(_stats_key())
	for flood in floods:
		flood.reset()
	for refill in refills:
		refill.reset()


func _format_time(seconds: float) -> String:
	return "%d:%04.1f" % [int(seconds) / 60, fmod(seconds, 60.0)]

extends Label

const RecoilPlayer = preload("res://player.gd")
const SAMPLE_INTERVAL := 0.25
const MAX_RECENT_EVENTS := 4

@export var player_path: NodePath
@onready var player: RecoilPlayer = get_node(player_path)

var started_at := 0
var sample_elapsed := 0.0
var log_file: FileAccess
var log_location := "Log unavailable"
var recent_events: Array[String] = []


func _ready() -> void:
	if not OS.is_debug_build():
		hide()
		set_process(false)
		return

	started_at = Time.get_ticks_msec()
	var stamp := Time.get_datetime_string_from_system().replace(":", "-")
	var filename := "run_%s_%d_%d.log" % [stamp, OS.get_process_id(), started_at]
	for directory in ["res://playtest_logs", "user://playtest_logs"]:
		var absolute_directory := ProjectSettings.globalize_path(directory)
		if DirAccess.make_dir_recursive_absolute(absolute_directory) == OK:
			log_file = FileAccess.open(absolute_directory.path_join(filename), FileAccess.WRITE)
			if log_file != null:
				log_location = directory.trim_prefix("res://").path_join(filename)
				break

	player.debug_event.connect(_record_event)
	_record_event("Run started  kick=%.0f  upward cap=%.0f  fall damping=%.0f%%" % [
		RecoilPlayer.RECOIL_SPEED, RecoilPlayer.MAX_RISE_SPEED, RecoilPlayer.FALL_MOMENTUM_DAMPING * 100.0,
	])


func _process(delta: float) -> void:
	var motion := "Grounded" if player.is_on_floor() else ("Falling" if player.velocity.y > 0.0 else "Rising")
	var stats := "%s  |  pos %s  |  velocity %s px/s  |  ammo %d/%d" % [
		motion, player.position.round(), player.velocity.round(), player.shots, RecoilPlayer.MAX_SHOTS,
	]
	text = "Playtest  |  %s\n%s\n%s" % [log_location, stats, "\n".join(recent_events)]
	sample_elapsed += delta
	if sample_elapsed >= SAMPLE_INTERVAL:
		sample_elapsed = fmod(sample_elapsed, SAMPLE_INTERVAL)
		_write_line("Sample  " + stats)


func _record_event(message: String) -> void:
	recent_events.push_front(_write_line(message))
	if recent_events.size() > MAX_RECENT_EVENTS:
		recent_events.pop_back()


func _write_line(message: String) -> String:
	var line := "%7.3fs  %s" % [(Time.get_ticks_msec() - started_at) / 1000.0, message]
	if log_file != null:
		log_file.store_line(line)
		log_file.flush()
	return line

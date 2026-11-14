class_name GameStats
extends RefCounted
## Lifetime play stats, saved to user://stats.cfg: total play time and deaths, plus time and
## deaths per floor ("floor_0" .. "floor_9") and for the boss fight ("boss").
## main.gd calls tick() every unpaused frame and add_death() on each death; menus read the totals.

const PATH := "user://stats.cfg"
## Save at most this often while playing (deaths and menus save right away).
const SAVE_EVERY := 5.0

static var _config: ConfigFile
static var _unsaved := 0.0


static func _data() -> ConfigFile:
	if _config == null:
		_config = ConfigFile.new()
		_config.load(PATH)
	return _config


## Add play time. `key` is "floor_N", "boss", or "" for time that only counts toward the total.
static func tick(delta: float, key: String) -> void:
	var data := _data()
	data.set_value("total", "time", float(data.get_value("total", "time", 0.0)) + delta)
	if key != "":
		data.set_value(key, "time", float(data.get_value(key, "time", 0.0)) + delta)
	_unsaved += delta
	if _unsaved >= SAVE_EVERY:
		save()


static func add_death(key: String) -> void:
	var data := _data()
	data.set_value("total", "deaths", int(data.get_value("total", "deaths", 0)) + 1)
	if key != "":
		data.set_value(key, "deaths", int(data.get_value(key, "deaths", 0)) + 1)
	save()


static func save() -> void:
	if _config != null:
		_config.save(PATH)
	_unsaved = 0.0


static func time_of(key: String) -> float:
	return float(_data().get_value(key, "time", 0.0))


static func deaths_of(key: String) -> int:
	return int(_data().get_value(key, "deaths", 0))


## 75 -> "1:15", 3725 -> "1:02:05".
static func format_time(seconds: float) -> String:
	var s := int(seconds)
	if s >= 3600:
		return "%d:%02d:%02d" % [s / 3600, (s / 60) % 60, s % 60]
	return "%d:%02d" % [s / 60, s % 60]

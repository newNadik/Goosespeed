class_name LevelProgressStore
extends Node

signal best_time_changed(course_path: String, best_time: float)

const SAVE_PATH := "user://goosespeed_level_progress.cfg"
const BEST_TIMES_SECTION := "best_times"
const NO_BEST_TIME := -1.0

var best_times := {}


func _ready() -> void:
	load_progress()


func load_progress() -> void:
	best_times.clear()
	var config := ConfigFile.new()
	var error := config.load(SAVE_PATH)
	if error != OK:
		return

	for key in config.get_section_keys(BEST_TIMES_SECTION):
		var time := float(config.get_value(BEST_TIMES_SECTION, key, NO_BEST_TIME))
		if time > 0.0:
			best_times[key] = time


func save_progress() -> void:
	var config := ConfigFile.new()
	for course_path in best_times.keys():
		config.set_value(BEST_TIMES_SECTION, str(course_path), float(best_times[course_path]))
	var error := config.save(SAVE_PATH)
	if error != OK:
		push_warning("Failed to save GooseSpeed level progress: %s" % error)


func get_best_time(course_path: String) -> float:
	if course_path.is_empty() or not best_times.has(course_path):
		return NO_BEST_TIME
	return float(best_times[course_path])


func record_level_time(course_path: String, time_seconds: float) -> bool:
	if course_path.is_empty() or time_seconds <= 0.0:
		return false
	var previous_best := get_best_time(course_path)
	if previous_best > 0.0 and time_seconds >= previous_best:
		return false
	best_times[course_path] = time_seconds
	save_progress()
	best_time_changed.emit(course_path, time_seconds)
	return true


func reset_for_tests() -> void:
	best_times.clear()
	var absolute_path := ProjectSettings.globalize_path(SAVE_PATH)
	if FileAccess.file_exists(absolute_path):
		var error := DirAccess.remove_absolute(absolute_path)
		if error != OK:
			push_warning("Failed to remove GooseSpeed level progress test save: %s" % error)

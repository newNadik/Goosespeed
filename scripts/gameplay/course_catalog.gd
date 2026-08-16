class_name GooseCourseCatalog
extends RefCounted

const FIRST_COURSE_PATH := "res://scenes/courses/farm/level_farm.tscn"
const DEFAULT_COURSE_PATH := FIRST_COURSE_PATH


static func get_predicted_next_course_path() -> String:
	return FIRST_COURSE_PATH


static func request_course_preload(course_path := DEFAULT_COURSE_PATH) -> void:
	if course_path.is_empty() or ResourceLoader.has_cached(course_path):
		return

	var error := ResourceLoader.load_threaded_request(course_path)
	if error != OK and error != ERR_BUSY:
		push_warning("Could not start course preload for %s: %s" % [course_path, error])

extends Node


func _ready() -> void:
	var course_a := "res://scenes/courses/farm/level_farm.tscn"
	var course_b := "res://scenes/courses/test/level_test.tscn"

	if LevelProgress.has_method("reset_for_tests"):
		LevelProgress.reset_for_tests()
	LevelProgress.load_progress()

	if LevelProgress.get_best_time(course_a) != LevelProgress.NO_BEST_TIME:
		push_error("LevelProgress should start without a best time")
		get_tree().quit(1)
		return
	if not LevelProgress.record_level_time(course_a, 42.5):
		push_error("LevelProgress did not create an initial best time")
		get_tree().quit(1)
		return
	if not is_equal_approx(LevelProgress.get_best_time(course_a), 42.5):
		push_error("LevelProgress did not store initial best time")
		get_tree().quit(1)
		return
	if LevelProgress.record_level_time(course_a, 44.0):
		push_error("LevelProgress overwrote best time with a slower time")
		get_tree().quit(1)
		return
	if not is_equal_approx(LevelProgress.get_best_time(course_a), 42.5):
		push_error("LevelProgress changed best time after slower time")
		get_tree().quit(1)
		return
	if not LevelProgress.record_level_time(course_a, 39.25):
		push_error("LevelProgress did not improve best time")
		get_tree().quit(1)
		return
	if not is_equal_approx(LevelProgress.get_best_time(course_a), 39.25):
		push_error("LevelProgress did not store improved best time")
		get_tree().quit(1)
		return
	if LevelProgress.get_best_time(course_b) != LevelProgress.NO_BEST_TIME:
		push_error("LevelProgress best time leaked between courses")
		get_tree().quit(1)
		return

	LevelProgress.load_progress()
	if not is_equal_approx(LevelProgress.get_best_time(course_a), 39.25):
		push_error("LevelProgress did not reload persisted best time")
		get_tree().quit(1)
		return

	LevelProgress.reset_for_tests()
	print("Level progress OK")
	get_tree().quit(0)

extends SceneTree

const MainMenuScript := preload("res://scripts/ui/main_menu.gd")
const CourseCatalog := preload("res://scripts/gameplay/course_catalog.gd")


func _initialize() -> void:
	if MainMenuScript.LEVEL_SCENE != "res://scenes/game/game_scene.tscn":
		push_error("Main menu does not start the reusable game scene")
		quit(1)
		return
	if MainMenuScript.PREDICTED_COURSE_SCENE != CourseCatalog.FIRST_COURSE_PATH:
		push_error("Main menu does not preload the predicted first course")
		quit(1)
		return
	print("Main menu OK")
	quit(0)

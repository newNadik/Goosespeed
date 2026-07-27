extends SceneTree

const MainMenuScript := preload("res://scripts/ui/main_menu.gd")


func _initialize() -> void:
	if MainMenuScript.LEVEL_SCENE != "res://scenes/game/game_scene.tscn":
		push_error("Main menu does not start the reusable game scene")
		quit(1)
		return
	print("Main menu OK")
	quit(0)

class_name MainMenu
extends Control

const LEVEL_SCENE := "res://scenes/test/goosespeed_movement_lab.tscn"

@onready var start_button: Button = $CenterContainer/MainPanel/Margin/VBox/StartButton
@onready var quit_button: Button = $CenterContainer/MainPanel/Margin/VBox/QuitButton


func _ready() -> void:
	start_button.pressed.connect(on_start_pressed)
	quit_button.pressed.connect(on_quit_pressed)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	start_button.grab_focus()


func on_start_pressed() -> void:
	get_tree().change_scene_to_file(LEVEL_SCENE)


func on_quit_pressed() -> void:
	get_tree().quit()

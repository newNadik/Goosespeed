class_name MainMenu
extends Control

const CourseCatalog := preload("res://scripts/gameplay/course_catalog.gd")
const LEVEL_SCENE := "res://scenes/game/game_scene.tscn"
const PREDICTED_COURSE_SCENE := CourseCatalog.FIRST_COURSE_PATH

@onready var start_button: Button = $MenuBackground/MarginContainer/VBoxContainer/StartButton
@onready var settings_button: Button = $MenuBackground/MarginContainer/VBoxContainer/SettingsButton
@onready var quit_button: Button = $MenuBackground/MarginContainer/VBoxContainer/QuitButton
@onready var settings_overlay = $GooseSettingsOverlay


func _ready() -> void:
	if DisplayServer.get_name() != "headless":
		CourseCatalog.request_course_preload(PREDICTED_COURSE_SCENE)
	start_button.pressed.connect(on_start_pressed)
	settings_button.pressed.connect(on_settings_pressed)
	quit_button.pressed.connect(on_quit_pressed)
	settings_overlay.back_requested.connect(on_settings_back_requested)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	start_button.grab_focus()


func on_start_pressed() -> void:
	get_tree().change_scene_to_file(LEVEL_SCENE)


func on_settings_pressed() -> void:
	settings_overlay.show_settings()


func on_settings_back_requested() -> void:
	settings_button.grab_focus()


func on_quit_pressed() -> void:
	get_tree().quit()

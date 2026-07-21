class_name MainMenu
extends Control

const LEVEL_SCENE := "res://scenes/test/goosespeed_movement_lab.tscn"

@onready var start_button: Button = $MenuBackground/MarginContainer/VBoxContainer/StartButton
@onready var settings_button: Button = $MenuBackground/MarginContainer/VBoxContainer/SettingsButton
@onready var quit_button: Button = $MenuBackground/MarginContainer/VBoxContainer/QuitButton
@onready var settings_menu = $GooseSettingsMenu


func _ready() -> void:
	start_button.pressed.connect(on_start_pressed)
	settings_button.pressed.connect(on_settings_pressed)
	quit_button.pressed.connect(on_quit_pressed)
	settings_menu.back_requested.connect(on_settings_back_requested)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	start_button.grab_focus()


func on_start_pressed() -> void:
	get_tree().change_scene_to_file(LEVEL_SCENE)


func on_settings_pressed() -> void:
	settings_menu.show_settings()


func on_settings_back_requested() -> void:
	settings_menu.hide_settings()
	settings_button.grab_focus()


func on_quit_pressed() -> void:
	get_tree().quit()

class_name MainMenu
extends Control

const LEVEL_SCENE := "res://scenes/test/goosespeed_movement_lab.tscn"

@onready var start_button: Button = $CenterContainer/MainPanel/Margin/VBox/StartButton
@onready var backend_option: OptionButton = $CenterContainer/MainPanel/Margin/VBox/BackendOption
@onready var quit_button: Button = $CenterContainer/MainPanel/Margin/VBox/QuitButton


func _ready() -> void:
	_populate_backend_options()
	start_button.pressed.connect(on_start_pressed)
	quit_button.pressed.connect(on_quit_pressed)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	start_button.grab_focus()


func on_start_pressed() -> void:
	var selected_index := backend_option.selected
	RuntimeConfig.movement_backend = str(backend_option.get_item_metadata(selected_index))
	get_tree().change_scene_to_file(LEVEL_SCENE)


func on_quit_pressed() -> void:
	get_tree().quit()


func _populate_backend_options() -> void:
	backend_option.clear()
	backend_option.add_item("Q3")
	backend_option.set_item_metadata(0, RuntimeConfig.MOVEMENT_Q3)
	backend_option.add_item("Platformer")
	backend_option.set_item_metadata(1, RuntimeConfig.MOVEMENT_PLATFORMER)
	backend_option.add_item("Basic")
	backend_option.set_item_metadata(2, RuntimeConfig.MOVEMENT_BASIC)
	for index in backend_option.item_count:
		if backend_option.get_item_metadata(index) == RuntimeConfig.movement_backend:
			backend_option.select(index)
			return

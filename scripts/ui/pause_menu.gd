class_name PauseMenu
extends CanvasLayer

const MAIN_MENU_SCENE := "res://scenes/ui/main_menu.tscn"

@onready var menu_root: Control = $MenuRoot
@onready var pause_panel: PanelContainer = $MenuRoot/CenterContainer/PausePanel
@onready var resume_button: Button = $MenuRoot/CenterContainer/PausePanel/Margin/VBox/ResumeButton
@onready var restart_button: Button = $MenuRoot/CenterContainer/PausePanel/Margin/VBox/RestartButton
@onready var settings_button: Button = $MenuRoot/CenterContainer/PausePanel/Margin/VBox/SettingsButton
@onready var main_menu_button: Button = $MenuRoot/CenterContainer/PausePanel/Margin/VBox/MainMenuButton
@onready var quit_button: Button = $MenuRoot/CenterContainer/PausePanel/Margin/VBox/QuitButton
@onready var settings_menu = $MenuRoot/GooseSettingsMenu

var open := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	resume_button.pressed.connect(on_resume_pressed)
	restart_button.pressed.connect(on_restart_pressed)
	settings_button.pressed.connect(on_settings_pressed)
	main_menu_button.pressed.connect(on_main_menu_pressed)
	quit_button.pressed.connect(on_quit_pressed)
	settings_menu.back_requested.connect(on_settings_back_requested)
	settings_menu.movement_backend_changed.connect(on_movement_backend_changed)
	set_open(false, false)


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo or not Input.is_action_just_pressed(&"ui_cancel"):
		return
	if open and settings_menu.visible:
		show_pause_panel()
		get_viewport().set_input_as_handled()
		return
	set_open(not open)
	get_viewport().set_input_as_handled()


func set_open(value: bool, update_mouse_mode := true) -> void:
	open = value
	menu_root.visible = value
	settings_menu.hide_settings()
	pause_panel.visible = value
	get_tree().paused = value
	if value:
		resume_button.grab_focus()
		if update_mouse_mode:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif update_mouse_mode:
		call_deferred("capture_mouse")


func capture_mouse() -> void:
	if not open and DisplayServer.window_is_focused():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func on_resume_pressed() -> void:
	set_open(false)


func on_restart_pressed() -> void:
	set_open(false, false)
	get_tree().paused = false
	get_tree().reload_current_scene()


func on_settings_pressed() -> void:
	pause_panel.visible = false
	settings_menu.show_settings()


func on_settings_back_requested() -> void:
	show_pause_panel()


func on_movement_backend_changed(_backend: String) -> void:
	set_open(false, false)
	get_tree().paused = false
	get_tree().reload_current_scene()


func on_main_menu_pressed() -> void:
	set_open(false, false)
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func on_quit_pressed() -> void:
	get_tree().quit()


func show_pause_panel() -> void:
	settings_menu.hide_settings()
	pause_panel.visible = true
	resume_button.grab_focus()

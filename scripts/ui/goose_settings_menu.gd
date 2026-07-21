class_name GooseSettingsMenu
extends Control

signal back_requested
signal movement_backend_changed(backend: String)

@onready var backend_option: OptionButton = $CenterContainer/SettingsPanel/Margin/VBox/BackendOption
@onready var back_button: Button = $CenterContainer/SettingsPanel/Margin/VBox/BackButton

var syncing := false


func _ready() -> void:
	_populate_backend_options()
	backend_option.item_selected.connect(on_backend_selected)
	back_button.pressed.connect(on_back_pressed)


func show_settings() -> void:
	_sync_from_settings()
	visible = true
	backend_option.grab_focus()


func hide_settings() -> void:
	visible = false


func on_backend_selected(index: int) -> void:
	if syncing:
		return
	var backend := str(backend_option.get_item_metadata(index))
	GooseGameSettings.set_movement_backend(backend)
	movement_backend_changed.emit(backend)


func on_back_pressed() -> void:
	back_requested.emit()


func _populate_backend_options() -> void:
	backend_option.clear()
	_add_backend_option("Q3", GooseGameSettings.MOVEMENT_Q3)
	_add_backend_option("Platformer", GooseGameSettings.MOVEMENT_PLATFORMER)
	_add_backend_option("Basic", GooseGameSettings.MOVEMENT_BASIC)
	_sync_from_settings()


func _add_backend_option(label: String, backend: String) -> void:
	backend_option.add_item(label)
	backend_option.set_item_metadata(backend_option.item_count - 1, backend)


func _sync_from_settings() -> void:
	syncing = true
	for index in backend_option.item_count:
		if backend_option.get_item_metadata(index) == GooseGameSettings.movement_backend:
			backend_option.select(index)
			syncing = false
			return
	syncing = false

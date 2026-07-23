class_name GooseSettingsOverlay
extends CanvasLayer

signal back_requested

const GooseMovesRuntimeScript := preload("res://scripts/player/goose_moves_runtime.gd")

@onready var root: Control = $Root
@onready var settings_menu = $Root/SettingsMenu
@onready var keybindings_menu = $Root/KeybindingsMenu


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	settings_menu.back_requested.connect(on_settings_back_requested)
	settings_menu.keybindings_requested.connect(on_keybindings_requested)
	keybindings_menu.back_requested.connect(on_keybindings_back_requested)
	_apply_game_settings_scope()
	hide_settings()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo and Input.is_action_just_pressed(&"ui_cancel"):
		if keybindings_menu.visible:
			on_keybindings_back_requested()
			get_viewport().set_input_as_handled()
			return
		on_settings_back_requested()
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if visible and Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func show_settings() -> void:
	_lock_movement_settings()
	visible = true
	root.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	settings_menu.visible = true
	keybindings_menu.visible = false
	settings_menu.show_character_settings()
	_apply_game_settings_scope()
	_focus_character_settings()


func hide_settings() -> void:
	settings_menu.visible = false
	keybindings_menu.visible = false
	root.visible = false
	visible = false


func on_settings_back_requested() -> void:
	hide_settings()
	back_requested.emit()


func on_keybindings_requested() -> void:
	settings_menu.visible = false
	keybindings_menu.visible = true
	keybindings_menu.focus_first()


func on_keybindings_back_requested() -> void:
	keybindings_menu.visible = false
	settings_menu.visible = true
	_lock_movement_settings()
	settings_menu.show_character_settings()
	_apply_game_settings_scope()
	_focus_character_settings()


func _apply_game_settings_scope() -> void:
	var character_row := settings_menu.get_node_or_null("Panel/Margin/VBox/SettingsTabs/Character/CharacterRow") as Control
	if character_row != null:
		character_row.visible = false

	var character_option := settings_menu.get_node_or_null("Panel/Margin/VBox/SettingsTabs/Character/CharacterRow/CharacterOption") as BaseButton
	if character_option != null:
		character_option.disabled = true


func _focus_character_settings() -> void:
	var preset_option := settings_menu.get_node_or_null("Panel/Margin/VBox/SettingsTabs/Character/PresetRow/PresetOption") as Control
	if preset_option != null and preset_option.visible:
		preset_option.grab_focus()
		return

	var keybindings_button := settings_menu.get_node_or_null("Panel/Margin/VBox/SettingsTabs/Character/KeybindingsButton") as Control
	if keybindings_button != null:
		keybindings_button.grab_focus()


func _lock_movement_settings() -> void:
	GooseMovesRuntimeScript.lock_settings_backend(get_node_or_null("/root/Settings"))

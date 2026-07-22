class_name GooseSettingsOverlay
extends CanvasLayer

signal back_requested

@onready var root: Control = $Root
@onready var settings_menu = $Root/SettingsMenu
@onready var keybindings_menu = $Root/KeybindingsMenu


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	settings_menu.back_requested.connect(on_settings_back_requested)
	settings_menu.keybindings_requested.connect(on_keybindings_requested)
	keybindings_menu.back_requested.connect(on_keybindings_back_requested)
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
	visible = true
	root.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	settings_menu.visible = true
	keybindings_menu.visible = false
	settings_menu.show_character_settings()
	settings_menu.focus_first()


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
	settings_menu.show_character_settings()
	settings_menu.focus_first()

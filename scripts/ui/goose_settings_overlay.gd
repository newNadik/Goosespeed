class_name GooseSettingsOverlay
extends CanvasLayer

signal back_requested

@onready var root: Control = $Root
@onready var settings_menu = $Root/GooseSettingsMenu


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	settings_menu.back_requested.connect(on_settings_back_requested)
	hide_settings()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo and Input.is_action_just_pressed(&"ui_cancel"):
		on_settings_back_requested()
		get_viewport().set_input_as_handled()


func show_settings() -> void:
	visible = true
	root.visible = true
	settings_menu.show_settings()


func hide_settings() -> void:
	settings_menu.hide_settings()
	root.visible = false
	visible = false


func on_settings_back_requested() -> void:
	hide_settings()
	back_requested.emit()

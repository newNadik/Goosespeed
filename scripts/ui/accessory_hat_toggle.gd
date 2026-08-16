class_name AccessoryHatToggle
extends Control

const ACCESSORY_ID := GooseGameSettings.ACCESSORY_STRAW_HAT

@onready var hat_button: Button = $PanelMargin/Panel/InnerMargin/HatButton
@onready var check_mark: TextureRect = $PanelMargin/Panel/CheckMark


func _ready() -> void:
	hat_button.toggle_mode = true
	hat_button.pressed.connect(_on_pressed)
	if not GooseGameSettings.settings_changed.is_connected(_refresh):
		GooseGameSettings.settings_changed.connect(_refresh)
	_refresh()


func _exit_tree() -> void:
	if GooseGameSettings.settings_changed.is_connected(_refresh):
		GooseGameSettings.settings_changed.disconnect(_refresh)


func _on_pressed() -> void:
	if not GooseGameSettings.is_accessory_unlocked(ACCESSORY_ID):
		_refresh()
		return
	GooseGameSettings.set_accessory_equipped(ACCESSORY_ID, hat_button.button_pressed)
	_refresh()


func _refresh() -> void:
	var unlocked := GooseGameSettings.is_accessory_unlocked(ACCESSORY_ID)
	visible = unlocked
	hat_button.disabled = not unlocked
	hat_button.button_pressed = unlocked and GooseGameSettings.is_accessory_equipped(ACCESSORY_ID)
	if check_mark != null:
		check_mark.visible = hat_button.button_pressed


func is_toggle_disabled() -> bool:
	return hat_button.disabled


func is_toggle_pressed() -> bool:
	return hat_button.button_pressed


func set_toggle_pressed_no_signal(value: bool) -> void:
	hat_button.set_pressed_no_signal(value)


func emit_toggle_pressed() -> void:
	hat_button.pressed.emit()

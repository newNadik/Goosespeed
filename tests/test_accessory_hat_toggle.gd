extends Node

const ACCESSORY_HAT_TOGGLE_SCENE := preload("res://scenes/ui/accessory_hat_toggle.tscn")

var original_straw_hat_unlocked := false
var original_straw_hat_equipped := false


func _ready() -> void:
	original_straw_hat_unlocked = GooseGameSettings.straw_hat_unlocked
	original_straw_hat_equipped = GooseGameSettings.straw_hat_equipped

	GooseGameSettings.straw_hat_unlocked = false
	GooseGameSettings.straw_hat_equipped = false
	GooseGameSettings.save_settings()

	var toggle := ACCESSORY_HAT_TOGGLE_SCENE.instantiate() as AccessoryHatToggle
	add_child(toggle)
	await get_tree().process_frame

	if toggle.visible or not toggle.is_toggle_disabled():
		_fail("Accessory hat toggle should be hidden while the hat is locked")
		return

	GooseGameSettings.straw_hat_unlocked = true
	GooseGameSettings.straw_hat_equipped = false
	GooseGameSettings.save_settings()
	GooseGameSettings.settings_changed.emit()
	await get_tree().process_frame

	if not toggle.visible or toggle.is_toggle_disabled():
		_fail("Accessory hat toggle should be available after unlock")
		return
	if toggle.is_toggle_pressed():
		_fail("Accessory hat toggle should start unchecked when the hat is unequipped")
		return

	toggle.set_toggle_pressed_no_signal(true)
	toggle.emit_toggle_pressed()
	if not GooseGameSettings.straw_hat_equipped:
		_fail("Accessory hat toggle did not equip the hat")
		return

	toggle.set_toggle_pressed_no_signal(false)
	toggle.emit_toggle_pressed()
	if GooseGameSettings.straw_hat_equipped:
		_fail("Accessory hat toggle did not unequip the hat")
		return

	_restore_accessory_state()
	print("Accessory hat toggle OK")
	get_tree().quit(0)


func _fail(message: String) -> void:
	_restore_accessory_state()
	push_error(message)
	get_tree().quit(1)


func _restore_accessory_state() -> void:
	GooseGameSettings.straw_hat_unlocked = original_straw_hat_unlocked
	GooseGameSettings.straw_hat_equipped = original_straw_hat_equipped
	GooseGameSettings.save_settings()

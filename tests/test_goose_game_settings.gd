extends Node

const SETTINGS_MENU_SCENE := preload("res://scenes/ui/goose_settings_menu.tscn")


func _ready() -> void:
	var original_backend: String = GooseGameSettings.movement_backend

	GooseGameSettings.set_movement_backend(GooseGameSettings.MOVEMENT_PLATFORMER)
	GooseGameSettings.movement_backend = GooseGameSettings.MOVEMENT_Q3
	GooseGameSettings.load_settings()
	if GooseGameSettings.movement_backend != GooseGameSettings.MOVEMENT_PLATFORMER:
		push_error("Saved movement backend did not load")
		get_tree().quit(1)
		return

	if GooseGameSettings.normalize_movement_backend("unknown") != GooseGameSettings.MOVEMENT_Q3:
		push_error("Invalid movement backend did not normalize to Q3")
		get_tree().quit(1)
		return

	var settings_menu := SETTINGS_MENU_SCENE.instantiate()
	add_child(settings_menu)
	await get_tree().process_frame
	if not _settings_menu_backends_are_valid(settings_menu):
		settings_menu.queue_free()
		_restore_backend(original_backend)
		get_tree().quit(1)
		return

	settings_menu.queue_free()
	_restore_backend(original_backend)
	print("Goose game settings OK")
	get_tree().quit(0)


func _settings_menu_backends_are_valid(settings_menu: Node) -> bool:
	var backend_option := settings_menu.get_node("CenterContainer/SettingsPanel/Margin/VBox/BackendOption") as OptionButton
	var expected_backends := GooseGameSettings.MOVEMENT_BACKENDS
	if backend_option.item_count != expected_backends.size():
		push_error("Settings backend option count is wrong")
		return false
	for index in backend_option.item_count:
		var backend := str(backend_option.get_item_metadata(index))
		if backend != expected_backends[index]:
			push_error("Settings backend option %d is %s, expected %s" % [index, backend, expected_backends[index]])
			return false
	return true


func _restore_backend(backend: String) -> void:
	GooseGameSettings.set_movement_backend(backend)

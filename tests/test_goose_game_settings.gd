extends Node

const SETTINGS_MENU_SCENE := preload("res://scenes/ui/goose_settings_menu.tscn")
const SETTINGS_OVERLAY_SCENE := preload("res://scenes/ui/goose_settings_overlay.tscn")


func _ready() -> void:
	var original_backend: String = GooseGameSettings.movement_backend
	var original_camera_mode: String = GooseGameSettings.camera_mode

	GooseGameSettings.set_movement_backend(GooseGameSettings.MOVEMENT_PLATFORMER)
	GooseGameSettings.set_camera_mode(GooseGameSettings.CAMERA_FIRST_PERSON)
	GooseGameSettings.movement_backend = GooseGameSettings.MOVEMENT_Q3
	GooseGameSettings.camera_mode = GooseGameSettings.CAMERA_THIRD_PERSON
	GooseGameSettings.load_settings()
	if GooseGameSettings.movement_backend != GooseGameSettings.MOVEMENT_PLATFORMER:
		push_error("Saved movement backend did not load")
		get_tree().quit(1)
		return
	if GooseGameSettings.camera_mode != GooseGameSettings.CAMERA_FIRST_PERSON:
		push_error("Saved camera mode did not load")
		get_tree().quit(1)
		return

	if GooseGameSettings.normalize_movement_backend("unknown") != GooseGameSettings.MOVEMENT_Q3:
		push_error("Invalid movement backend did not normalize to Q3")
		get_tree().quit(1)
		return
	if GooseGameSettings.normalize_camera_mode("unknown") != GooseGameSettings.CAMERA_THIRD_PERSON:
		push_error("Invalid camera mode did not normalize to third person")
		get_tree().quit(1)
		return

	var settings_menu := SETTINGS_MENU_SCENE.instantiate()
	add_child(settings_menu)
	await get_tree().process_frame
	if not _settings_menu_options_are_valid(settings_menu):
		settings_menu.queue_free()
		_restore_settings(original_backend, original_camera_mode)
		get_tree().quit(1)
		return
	if not _settings_menu_tuning_is_valid(settings_menu):
		settings_menu.queue_free()
		_restore_settings(original_backend, original_camera_mode)
		get_tree().quit(1)
		return
	if not await _settings_overlay_is_valid():
		settings_menu.queue_free()
		_restore_settings(original_backend, original_camera_mode)
		get_tree().quit(1)
		return

	settings_menu.queue_free()
	_restore_settings(original_backend, original_camera_mode)
	print("Goose game settings OK")
	get_tree().quit(0)


func _settings_menu_options_are_valid(settings_menu: Node) -> bool:
	var backend_option := settings_menu.get_node("CenterContainer/SettingsPanel/Margin/VBox/BackendOption") as OptionButton
	var camera_option := settings_menu.get_node("CenterContainer/SettingsPanel/Margin/VBox/CameraOption") as OptionButton
	var expected_backends := GooseGameSettings.MOVEMENT_BACKENDS
	var expected_camera_modes := GooseGameSettings.CAMERA_MODES
	if backend_option.item_count != expected_backends.size():
		push_error("Settings backend option count is wrong")
		return false
	for index in backend_option.item_count:
		var backend := str(backend_option.get_item_metadata(index))
		if backend != expected_backends[index]:
			push_error("Settings backend option %d is %s, expected %s" % [index, backend, expected_backends[index]])
			return false
	if camera_option.item_count != expected_camera_modes.size():
		push_error("Settings camera option count is wrong")
		return false
	for index in camera_option.item_count:
		var camera_mode := str(camera_option.get_item_metadata(index))
		if camera_mode != expected_camera_modes[index]:
			push_error(
				"Settings camera option %d is %s, expected %s"
				% [index, camera_mode, expected_camera_modes[index]]
			)
			return false
	return true


func _settings_overlay_is_valid() -> bool:
	var overlay := SETTINGS_OVERLAY_SCENE.instantiate()
	add_child(overlay)
	await get_tree().process_frame
	overlay.show_settings()
	await get_tree().process_frame
	if not overlay.visible:
		push_error("Settings overlay did not become visible")
		overlay.queue_free()
		return false
	overlay.hide_settings()
	await get_tree().process_frame
	if overlay.visible:
		push_error("Settings overlay did not hide")
		overlay.queue_free()
		return false
	overlay.queue_free()
	return true


func _settings_menu_tuning_is_valid(settings_menu: Node) -> bool:
	var tuning_panel := settings_menu.get_node("CenterContainer/SettingsPanel/Margin/VBox/TuningPanel")
	tuning_panel.rebuild(GooseGameSettings.MOVEMENT_Q3)
	for key in ["movement_mode", "auto_jump", "crouch_slide", "wall_jump"]:
		if not tuning_panel.has_control(key):
			push_error("Q3 tuning is missing %s" % key)
			return false

	tuning_panel.rebuild(GooseGameSettings.MOVEMENT_PLATFORMER)
	for key in ["max_run_speed", "ground_acceleration", "jump_velocity"]:
		if not tuning_panel.has_control(key):
			push_error("Platformer tuning is missing %s" % key)
			return false

	tuning_panel.rebuild(GooseGameSettings.MOVEMENT_BASIC)
	if tuning_panel.has_control("movement_mode") or tuning_panel.has_control("max_run_speed"):
		push_error("Basic backend should not expose prototype tuning controls")
		return false
	return true


func _restore_settings(backend: String, camera_mode: String) -> void:
	GooseGameSettings.set_movement_backend(backend)
	GooseGameSettings.set_camera_mode(camera_mode)

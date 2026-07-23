extends Node

const SETTINGS_OVERLAY_SCENE := preload("res://scenes/ui/goose_settings_overlay.tscn")


func _ready() -> void:
	var original_camera_mode: String = GooseGameSettings.camera_mode

	GooseGameSettings.set_camera_mode(GooseGameSettings.CAMERA_FIRST_PERSON)
	GooseGameSettings.camera_mode = GooseGameSettings.CAMERA_THIRD_PERSON
	GooseGameSettings.load_settings()
	if GooseGameSettings.camera_mode != GooseGameSettings.CAMERA_FIRST_PERSON:
		push_error("Saved camera mode did not load")
		get_tree().quit(1)
		return

	if GooseGameSettings.normalize_camera_mode("unknown") != GooseGameSettings.CAMERA_THIRD_PERSON:
		push_error("Invalid camera mode did not normalize to third person")
		get_tree().quit(1)
		return

	var prototype_settings := get_node_or_null("/root/Settings")
	if prototype_settings != null and str(prototype_settings.get("character_controller")) != "q3_n_flight":
		push_error("GooseSpeed did not lock goose-moves to Q3 + Flight")
		get_tree().quit(1)
		return

	if not await _settings_overlay_is_valid():
		_restore_settings(original_camera_mode)
		get_tree().quit(1)
		return

	_restore_settings(original_camera_mode)
	print("Goose game settings OK")
	get_tree().quit(0)


func _settings_overlay_is_valid() -> bool:
	var overlay := SETTINGS_OVERLAY_SCENE.instantiate()
	add_child(overlay)
	await get_tree().process_frame
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	overlay.show_settings()
	await get_tree().process_frame
	if not overlay.visible:
		push_error("Settings overlay did not become visible")
		overlay.queue_free()
		return false
	if Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
		push_error("Settings overlay did not restore visible mouse mode")
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


func _restore_settings(camera_mode: String) -> void:
	GooseGameSettings.set_camera_mode(camera_mode)

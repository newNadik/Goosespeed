extends Node

const PLAYER_SCENE := preload("res://scenes/player/goose_player_root.tscn")
const HUD_SCENE := preload("res://scenes/ui/goose_game_hud.tscn")


func _ready() -> void:
	var original_backend: String = GooseGameSettings.movement_backend
	var original_camera_mode: String = GooseGameSettings.camera_mode
	GooseGameSettings.movement_backend = GooseGameSettings.MOVEMENT_Q3
	GooseGameSettings.camera_mode = GooseGameSettings.CAMERA_THIRD_PERSON

	var player := PLAYER_SCENE.instantiate()
	var hud := HUD_SCENE.instantiate()
	add_child(player)
	add_child(hud)
	await get_tree().process_frame

	hud.set_player(player)
	hud.set_run_state(12.34, true)
	await get_tree().process_frame

	if not _label_contains(hud, "Root/TopLeftPanel/Margin/VBox/BackendLabel", "Q3"):
		push_error(
			"HUD backend label did not use saved backend: %s"
			% _label_text(hud, "Root/TopLeftPanel/Margin/VBox/BackendLabel")
		)
		_restore_settings(original_backend, original_camera_mode)
		get_tree().quit(1)
		return
	if not _label_contains(hud, "Root/TopLeftPanel/Margin/VBox/CameraLabel", "Third Person"):
		push_error("HUD camera label did not use saved camera mode")
		_restore_settings(original_backend, original_camera_mode)
		get_tree().quit(1)
		return
	if not _label_contains(hud, "Root/TopRightPanel/Margin/VBox/TimerLabel", "12.34"):
		push_error("HUD timer label did not use run state")
		_restore_settings(original_backend, original_camera_mode)
		get_tree().quit(1)
		return
	if not _label_contains(hud, "Root/HintsPanel/Margin/HintsList/PauseLabel", "Esc  Pause"):
		push_error("HUD hints label is missing pause hint")
		_restore_settings(original_backend, original_camera_mode)
		get_tree().quit(1)
		return
	if not _hints_contain(hud, "Shift  Walk"):
		push_error("Q3 HUD hints are missing walk hint")
		_restore_settings(original_backend, original_camera_mode)
		get_tree().quit(1)
		return
	if not _hints_contain(hud, "Ctrl  Crouch / Slide"):
		push_error("Q3 HUD hints are missing crouch/slide hint")
		_restore_settings(original_backend, original_camera_mode)
		get_tree().quit(1)
		return
	if not _hints_contain(hud, "Q  Honk"):
		push_error("Q3 HUD hints are missing honk hint")
		_restore_settings(original_backend, original_camera_mode)
		get_tree().quit(1)
		return

	GooseGameSettings.movement_backend = GooseGameSettings.MOVEMENT_PLATFORMER
	player.movement_backend = GooseGameSettings.MOVEMENT_PLATFORMER
	hud.set_player(player)
	await get_tree().process_frame
	if _hints_contain(hud, "Shift"):
		push_error("Platformer HUD hints should not advertise Shift")
		_restore_settings(original_backend, original_camera_mode)
		get_tree().quit(1)
		return
	if not _hints_contain(hud, "Ctrl+Space  Trick Jump"):
		push_error("Platformer HUD hints are missing trick jump hint")
		_restore_settings(original_backend, original_camera_mode)
		get_tree().quit(1)
		return
	if not _hints_contain(hud, "E in Air  Dive"):
		push_error("Platformer HUD hints are missing dive hint")
		_restore_settings(original_backend, original_camera_mode)
		get_tree().quit(1)
		return
	if not _hints_contain(hud, "Q  Honk"):
		push_error("Platformer HUD hints are missing honk hint")
		_restore_settings(original_backend, original_camera_mode)
		get_tree().quit(1)
		return

	_restore_settings(original_backend, original_camera_mode)
	print("Goose game HUD OK")
	get_tree().quit(0)


func _label_contains(root: Node, path: NodePath, expected_text: String) -> bool:
	var label := root.get_node_or_null(path) as Label
	return label != null and label.text.contains(expected_text)


func _label_text(root: Node, path: NodePath) -> String:
	var label := root.get_node_or_null(path) as Label
	return label.text if label != null else "<missing>"


func _hints_contain(hud: Node, expected_text: String) -> bool:
	var hints_list := hud.get_node_or_null("Root/HintsPanel/Margin/HintsList")
	if hints_list == null:
		return false
	for child in hints_list.get_children():
		var label := child as Label
		if label != null and label.visible and label.text.contains(expected_text):
			return true
	return false


func _restore_settings(backend: String, camera_mode: String) -> void:
	GooseGameSettings.movement_backend = backend
	GooseGameSettings.camera_mode = camera_mode

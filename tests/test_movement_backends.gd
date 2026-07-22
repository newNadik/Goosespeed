extends Node

const PLAYER_SCENE := preload("res://scenes/player/goose_player_root.tscn")
const BACKENDS := [
	"q3_n_flight",
	"basic",
	"q3",
	"platformer",
	"flight",
]


func _ready() -> void:
	var original_backend: String = GooseGameSettings.movement_backend
	var original_camera_mode: String = GooseGameSettings.camera_mode
	GooseGameSettings.camera_mode = GooseGameSettings.CAMERA_THIRD_PERSON
	for backend in BACKENDS:
		GooseGameSettings.set_movement_backend(backend)
		var player := PLAYER_SCENE.instantiate()
		add_child(player)
		await get_tree().process_frame
		var controller: Node = player.get_active_controller()
		if controller == null:
			push_error("Backend %s did not create an active controller" % backend)
			get_tree().quit(1)
			return
		if controller.name != "ActiveMovementController":
			push_error("Backend %s active controller has unexpected name %s" % [backend, controller.name])
			get_tree().quit(1)
			return
		await get_tree().process_frame
		if not _prototype_visuals_are_hidden(controller):
			push_error("Backend %s prototype visuals are visible" % backend)
			get_tree().quit(1)
			return
		if backend in ["q3", "q3_n_flight", "platformer", "flight"]:
			if not _backend_hud_is_visible(controller):
				push_error("Backend %s debug HUD is hidden" % backend)
				get_tree().quit(1)
				return
		elif not _backend_hud_is_hidden(controller):
			push_error("Backend %s debug HUD is visible" % backend)
			get_tree().quit(1)
			return
		if backend == "platformer" and not await _platformer_facing_is_normalized(player):
			push_error("Platformer backend facing direction is not normalized to face_yaw")
			get_tree().quit(1)
			return
		if not _goosespeed_camera_mode_is_current(player, GooseGameSettings.CAMERA_THIRD_PERSON):
			push_error("Backend %s does not use GooseSpeed current camera" % backend)
			get_tree().quit(1)
			return
		GooseGameSettings.set_camera_mode(GooseGameSettings.CAMERA_FIRST_PERSON)
		await get_tree().process_frame
		if not _goosespeed_camera_mode_is_current(player, GooseGameSettings.CAMERA_FIRST_PERSON):
			push_error("Backend %s does not switch to first-person GooseSpeed camera" % backend)
			get_tree().quit(1)
			return
		GooseGameSettings.set_camera_mode(GooseGameSettings.CAMERA_THIRD_PERSON)
		await get_tree().process_frame
		if not _goosespeed_camera_mode_is_current(player, GooseGameSettings.CAMERA_THIRD_PERSON):
			push_error("Backend %s does not switch back to third-person GooseSpeed camera" % backend)
			get_tree().quit(1)
			return
		if not _backend_cameras_are_disabled(controller):
			push_error("Backend %s has a current backend camera" % backend)
			get_tree().quit(1)
			return
		player.queue_free()
		await get_tree().process_frame

	GooseGameSettings.set_movement_backend(original_backend)
	GooseGameSettings.camera_mode = original_camera_mode
	print("Movement backends OK: %d backends" % BACKENDS.size())
	get_tree().quit(0)


func _prototype_visuals_are_hidden(controller: Node) -> bool:
	for node_name in ["BodyMesh", "FaceMarker", "CharacterColliderVisual", "FlightBodyMesh"]:
		var visual := controller.get_node_or_null(node_name) as Node3D
		if visual != null and visual.visible:
			return false
	return true


func _platformer_facing_is_normalized(player: Node) -> bool:
	var controller: Node = player.get_active_controller()
	controller.set("face_yaw", PI * 0.5)
	await get_tree().process_frame
	var state: RefCounted = player.movement_state_bridge.get_state()
	return state.facing_direction.is_equal_approx(Vector3.RIGHT)


func _goosespeed_camera_mode_is_current(player: Node, camera_mode: String) -> bool:
	var third_person_camera := player.get_node_or_null(
		"GooseCameraRig/YawPivot/PitchPivot/SpringArm3D/ThirdPersonCamera"
	) as Camera3D
	var first_person_camera := player.get_node_or_null(
		"GooseCameraRig/YawPivot/PitchPivot/FirstPersonCamera"
	) as Camera3D
	if third_person_camera == null or first_person_camera == null:
		return false
	if camera_mode == GooseGameSettings.CAMERA_FIRST_PERSON:
		return first_person_camera.current and not third_person_camera.current
	return third_person_camera.current and not first_person_camera.current


func _backend_cameras_are_disabled(controller: Node) -> bool:
	for camera in _find_cameras(controller):
		if camera.current:
			return false
	return true


func _backend_hud_is_hidden(controller: Node) -> bool:
	var backend_hud := controller.get_node_or_null("HUD") as CanvasLayer
	return backend_hud == null or not backend_hud.visible


func _backend_hud_is_visible(controller: Node) -> bool:
	for hud_name in ["HUD", "Q3HUD"]:
		var backend_hud := controller.get_node_or_null(hud_name) as CanvasLayer
		if backend_hud != null and backend_hud.visible:
			return true
	return false


func _find_cameras(root: Node) -> Array[Camera3D]:
	var cameras: Array[Camera3D] = []
	if root is Camera3D:
		cameras.append(root as Camera3D)
	for child in root.get_children():
		cameras.append_array(_find_cameras(child))
	return cameras

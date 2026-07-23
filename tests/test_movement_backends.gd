extends Node

const PLAYER_SCENE := preload("res://scenes/player/goose_player_root.tscn")


func _ready() -> void:
	var player := PLAYER_SCENE.instantiate()
	add_child(player)
	await get_tree().process_frame
	var controller: Node = player.get_active_controller()
	if controller == null:
		push_error("Q3 + Flight did not create an active controller")
		get_tree().quit(1)
		return
	if not _controller_contract_is_valid(controller):
		push_error("Q3 + Flight controller does not match GooseSpeed runtime contract")
		get_tree().quit(1)
		return
	if controller.name != "ActiveMovementController":
		push_error("Active controller has unexpected name %s" % controller.name)
		get_tree().quit(1)
		return
	await get_tree().process_frame
	if not _prototype_visuals_are_hidden(controller):
		push_error("Prototype visuals are visible")
		get_tree().quit(1)
		return
	if not _backend_hud_is_visible(controller):
		push_error("Debug HUD is hidden")
		get_tree().quit(1)
		return
	if not _backend_camera_is_current(controller):
		push_error("Q3 + Flight does not use an addon camera")
		get_tree().quit(1)
		return

	print("Q3 + Flight backend OK")
	get_tree().quit(0)


func _prototype_visuals_are_hidden(controller: Node) -> bool:
	for node_name in ["BodyMesh", "FaceMarker", "CharacterColliderVisual", "FlightBodyMesh"]:
		var visual := controller.get_node_or_null(node_name) as Node3D
		if visual != null and visual.visible:
			return false
	return true


func _controller_contract_is_valid(controller: Node) -> bool:
	if not controller is Node3D:
		return false
	for method_name in GooseMovesRuntime.REQUIRED_CONTROLLER_METHODS:
		if not controller.has_method(method_name):
			return false
	return true


func _backend_camera_is_current(controller: Node) -> bool:
	for camera in _find_cameras(controller):
		if camera.current:
			return true
	return false


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

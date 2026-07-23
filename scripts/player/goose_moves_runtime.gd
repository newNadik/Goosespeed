class_name GooseMovesRuntime
extends Node

const MOVEMENT_BACKEND := "q3_n_flight"
const Q3_FLIGHT_CONTROLLER_SCENE := preload("res://addons/goose-moves/scenes/q3_n_flight_controller.tscn")

var active_controller: Node


func _ready() -> void:
	var settings := get_node_or_null("/root/Settings")
	if settings != null and settings.has_signal("settings_changed"):
		var callback := Callable(self, "_on_goose_moves_settings_changed")
		if not settings.is_connected("settings_changed", callback):
			settings.connect("settings_changed", callback)


static func lock_settings_backend(settings: Node) -> void:
	if settings != null and str(settings.get("character_controller")) != MOVEMENT_BACKEND:
		settings.set("character_controller", MOVEMENT_BACKEND)
		if settings.has_signal("settings_changed"):
			settings.emit_signal("settings_changed")


func spawn_controller(placeholder: Node3D) -> Node:
	lock_settings_backend(get_node_or_null("/root/Settings"))
	var spawn_transform := placeholder.global_transform
	var parent := placeholder.get_parent()
	var sibling_index := placeholder.get_index()
	parent.remove_child(placeholder)
	placeholder.queue_free()

	active_controller = Q3_FLIGHT_CONTROLLER_SCENE.instantiate()
	active_controller.name = "ActiveMovementController"
	parent.add_child(active_controller)
	parent.move_child(active_controller, sibling_index)
	(active_controller as Node3D).global_transform = spawn_transform
	active_controller.set_meta("spawn_transform", spawn_transform)
	disable_backend_cameras()
	return active_controller


func get_active_controller() -> Node:
	return active_controller


func reset_to_spawn() -> void:
	if active_controller == null:
		return
	if active_controller.has_method("reset_to_spawn"):
		active_controller.reset_to_spawn()
		return
	var spawn_transform: Transform3D = active_controller.get_meta("spawn_transform", Transform3D.IDENTITY)
	(active_controller as Node3D).global_transform = spawn_transform
	if active_controller.get("velocity") != null:
		active_controller.set("velocity", Vector3.ZERO)


func set_spawn_transform(value: Transform3D) -> void:
	if active_controller == null:
		return
	if active_controller.has_method("set_spawn_transform"):
		active_controller.set_spawn_transform(value)
	else:
		active_controller.set_meta("spawn_transform", value)


func set_medium(value: StringName) -> void:
	if active_controller != null and active_controller.has_method("set_medium"):
		active_controller.set_medium(value)


func apply_debug_visibility(debug_visible: bool) -> void:
	if active_controller == null:
		return
	for node_name in ["BodyMesh", "FaceMarker", "CharacterColliderVisual", "FlightBodyMesh"]:
		var visual := active_controller.get_node_or_null(node_name) as Node3D
		if visual:
			visual.visible = false

	for hud_name in ["HUD", "Q3HUD"]:
		var backend_hud := active_controller.get_node_or_null(hud_name) as CanvasLayer
		if backend_hud:
			backend_hud.visible = debug_visible
	if not debug_visible:
		var flight_hud := active_controller.get_node_or_null("FlightHUD") as CanvasLayer
		if flight_hud:
			flight_hud.visible = false


func disable_backend_cameras() -> void:
	if active_controller == null:
		return
	for camera in find_backend_cameras():
		camera.current = false


func find_backend_cameras() -> Array[Camera3D]:
	var cameras: Array[Camera3D] = []
	if active_controller != null:
		_append_cameras(active_controller, cameras)
	return cameras


func sync_camera_from_backend(current_yaw: float, current_pitch: float) -> Vector2:
	if active_controller == null:
		return Vector2(current_yaw, current_pitch)
	var backend_yaw = active_controller.get("camera_yaw")
	if backend_yaw != null:
		current_yaw = float(backend_yaw)
	var backend_pitch = active_controller.get("camera_pitch")
	if backend_pitch != null:
		current_pitch = float(backend_pitch)
	return Vector2(current_yaw, current_pitch)


func sync_camera_to_backend(yaw: float, pitch: float) -> void:
	if active_controller == null:
		return
	if active_controller.get("camera_yaw") != null:
		active_controller.set("camera_yaw", yaw)
	if active_controller.get("camera_pitch") != null:
		active_controller.set("camera_pitch", pitch)
	if active_controller.get("yaw") != null:
		active_controller.set("yaw", yaw)
	var head := active_controller.get_node_or_null("Head") as Node3D
	if head:
		head.rotation.x = pitch


func _append_cameras(root: Node, cameras: Array[Camera3D]) -> void:
	if root is Camera3D:
		cameras.append(root as Camera3D)
	for child in root.get_children():
		_append_cameras(child, cameras)


func _on_goose_moves_settings_changed() -> void:
	lock_settings_backend(get_node_or_null("/root/Settings"))

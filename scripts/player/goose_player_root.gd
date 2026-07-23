class_name GoosePlayerRoot
extends Node3D

const BASIC_BACKEND := "basic"
const Q3_BACKEND := "q3"
const Q3_FLIGHT_BACKEND := "q3_n_flight"
const PLATFORMER_BACKEND := "platformer"
const FLIGHT_BACKEND := "flight"
const Q3_CONTROLLER_SCENE := preload("res://addons/goose-moves/scenes/q3_character_controller.tscn")
const Q3_FLIGHT_CONTROLLER_SCENE := preload("res://addons/goose-moves/scenes/q3_n_flight_controller.tscn")
const PLATFORMER_CONTROLLER_SCENE := preload("res://addons/goose-moves/scenes/platformer_controller.tscn")
const FLIGHT_CONTROLLER_SCENE := preload("res://addons/goose-moves/scenes/flight_controller.tscn")

@export_enum("q3_n_flight", "q3", "platformer", "flight", "basic") var movement_backend := Q3_FLIGHT_BACKEND

@onready var input_adapter: Node = $InputAdapter
@onready var active_movement_controller: Node = $ActiveMovementController
@onready var glide_flap_modifier: Node = $GlideFlapModifier
@onready var movement_state_bridge: Node = $MovementStateBridge
@onready var goose_camera_rig: Node = $GooseCameraRig
@onready var goose_visual: Node = $GooseVisual


func _ready() -> void:
	_spawn_backend()
	_connect_settings_changed()
	movement_state_bridge.set_controller(active_movement_controller)
	goose_camera_rig.set_state_bridge(movement_state_bridge)
	goose_camera_rig.set_active_backend(active_movement_controller)
	if goose_visual.has_method("set_movement_backend"):
		goose_visual.set_movement_backend(movement_backend)
	goose_visual.set_state_bridge(movement_state_bridge)


func _process(_delta: float) -> void:
	call_deferred("_apply_backend_debug_visibility")


func get_active_controller() -> Node:
	return active_movement_controller


func reset_to_spawn() -> void:
	if active_movement_controller.has_method("reset_to_spawn"):
		active_movement_controller.reset_to_spawn()
	else:
		var spawn_transform: Transform3D = active_movement_controller.get_meta("spawn_transform", Transform3D.IDENTITY)
		(active_movement_controller as Node3D).global_transform = spawn_transform
		if active_movement_controller.get("velocity") != null:
			active_movement_controller.set("velocity", Vector3.ZERO)
	goose_visual.global_position = (active_movement_controller as Node3D).global_position


func set_spawn_transform(value: Transform3D) -> void:
	if active_movement_controller.has_method("set_spawn_transform"):
		active_movement_controller.set_spawn_transform(value)
	else:
		active_movement_controller.set_meta("spawn_transform", value)


func _spawn_backend() -> void:
	var spawn_transform := (active_movement_controller as Node3D).global_transform
	movement_backend = _resolve_movement_backend()
	if movement_backend == Q3_FLIGHT_BACKEND:
		_replace_active_controller(Q3_FLIGHT_CONTROLLER_SCENE.instantiate(), spawn_transform)
		_set_prototype_character_controller(Q3_FLIGHT_BACKEND)
	elif movement_backend == Q3_BACKEND:
		_replace_active_controller(Q3_CONTROLLER_SCENE.instantiate(), spawn_transform)
		_set_prototype_character_controller(Q3_BACKEND)
	elif movement_backend == PLATFORMER_BACKEND:
		_replace_active_controller(PLATFORMER_CONTROLLER_SCENE.instantiate(), spawn_transform)
		_set_prototype_character_controller(PLATFORMER_BACKEND)
	elif movement_backend == FLIGHT_BACKEND:
		_replace_active_controller(FLIGHT_CONTROLLER_SCENE.instantiate(), spawn_transform)
		_set_prototype_character_controller(FLIGHT_BACKEND)
	else:
		_configure_basic_controller()


func _replace_active_controller(controller: Node, spawn_transform: Transform3D) -> void:
	remove_child(active_movement_controller)
	active_movement_controller.queue_free()
	active_movement_controller = controller
	active_movement_controller.name = "ActiveMovementController"
	add_child(active_movement_controller)
	(active_movement_controller as Node3D).global_transform = spawn_transform
	active_movement_controller.set_meta("spawn_transform", spawn_transform)
	_apply_backend_debug_visibility()
	call_deferred("_apply_backend_debug_visibility")


func _configure_basic_controller() -> void:
	active_movement_controller.input_adapter = input_adapter
	active_movement_controller.glide_flap_modifier = glide_flap_modifier
	call_deferred("_disable_backend_cameras")


func _hide_backend_debug_visuals() -> void:
	var body_mesh := active_movement_controller.get_node_or_null("BodyMesh") as Node3D
	if body_mesh:
		body_mesh.visible = false
	var face_marker := active_movement_controller.get_node_or_null("FaceMarker") as Node3D
	if face_marker:
		face_marker.visible = false
	var backend_hud := active_movement_controller.get_node_or_null("HUD") as CanvasLayer
	if backend_hud:
		backend_hud.visible = false


func _apply_backend_debug_visibility() -> void:
	var debug_visible := true
	var game_settings := get_node_or_null("/root/GooseGameSettings")
	if game_settings != null:
		debug_visible = bool(game_settings.get("debug_hud_visible"))

	var body_mesh := active_movement_controller.get_node_or_null("BodyMesh") as Node3D
	if body_mesh:
		body_mesh.visible = false
	var face_marker := active_movement_controller.get_node_or_null("FaceMarker") as Node3D
	if face_marker:
		face_marker.visible = false
	var character_collider_visual := active_movement_controller.get_node_or_null("CharacterColliderVisual") as Node3D
	if character_collider_visual:
		character_collider_visual.visible = false
	var flight_body_mesh := active_movement_controller.get_node_or_null("FlightBodyMesh") as Node3D
	if flight_body_mesh:
		flight_body_mesh.visible = false

	for hud_name in ["HUD", "Q3HUD"]:
		var backend_hud := active_movement_controller.get_node_or_null(hud_name) as CanvasLayer
		if backend_hud:
			backend_hud.visible = debug_visible
	if not debug_visible:
		var flight_hud := active_movement_controller.get_node_or_null("FlightHUD") as CanvasLayer
		if flight_hud:
			flight_hud.visible = false


func _disable_backend_cameras() -> void:
	if goose_camera_rig:
		goose_camera_rig.set_active_backend(active_movement_controller)


func _resolve_movement_backend() -> String:
	var game_settings := get_node_or_null("/root/GooseGameSettings")
	if game_settings != null and game_settings.get("movement_backend") == BASIC_BACKEND:
		return BASIC_BACKEND
	var prototype_settings := get_node_or_null("/root/Settings")
	if prototype_settings != null:
		var prototype_backend = prototype_settings.get("character_controller")
		if prototype_backend in [Q3_FLIGHT_BACKEND, Q3_BACKEND, PLATFORMER_BACKEND, FLIGHT_BACKEND]:
			return str(prototype_backend)
	if game_settings != null:
		var configured_backend = game_settings.get("movement_backend")
		if configured_backend in [Q3_FLIGHT_BACKEND, BASIC_BACKEND, Q3_BACKEND, PLATFORMER_BACKEND, FLIGHT_BACKEND]:
			return configured_backend
	return movement_backend


func _set_prototype_character_controller(controller_id: String) -> void:
	var settings := get_node_or_null("/root/Settings")
	if settings != null and settings.has_method("set_character_controller"):
		settings.set_character_controller(controller_id)


func _connect_settings_changed() -> void:
	for path in ["/root/Settings", "/root/GooseGameSettings"]:
		var settings := get_node_or_null(path)
		if settings != null and settings.has_signal("settings_changed"):
			var callback := _on_settings_changed
			if not settings.is_connected("settings_changed", callback):
				settings.connect("settings_changed", callback)


func _on_settings_changed() -> void:
	var next_backend := _resolve_movement_backend()
	if next_backend != movement_backend:
		var spawn_transform := (active_movement_controller as Node3D).global_transform
		_spawn_backend_at(spawn_transform)
		movement_state_bridge.set_controller(active_movement_controller)
		goose_camera_rig.set_active_backend(active_movement_controller)
		if goose_visual.has_method("set_movement_backend"):
			goose_visual.set_movement_backend(movement_backend)
		return
	_apply_backend_debug_visibility()


func _spawn_backend_at(spawn_transform: Transform3D) -> void:
	movement_backend = _resolve_movement_backend()
	if movement_backend == Q3_FLIGHT_BACKEND:
		_replace_active_controller(Q3_FLIGHT_CONTROLLER_SCENE.instantiate(), spawn_transform)
		_set_prototype_character_controller(Q3_FLIGHT_BACKEND)
	elif movement_backend == Q3_BACKEND:
		_replace_active_controller(Q3_CONTROLLER_SCENE.instantiate(), spawn_transform)
		_set_prototype_character_controller(Q3_BACKEND)
	elif movement_backend == PLATFORMER_BACKEND:
		_replace_active_controller(PLATFORMER_CONTROLLER_SCENE.instantiate(), spawn_transform)
		_set_prototype_character_controller(PLATFORMER_BACKEND)
	elif movement_backend == FLIGHT_BACKEND:
		_replace_active_controller(FLIGHT_CONTROLLER_SCENE.instantiate(), spawn_transform)
		_set_prototype_character_controller(FLIGHT_BACKEND)
	else:
		_configure_basic_controller()

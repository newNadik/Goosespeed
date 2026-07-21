class_name GoosePlayerRoot
extends Node3D

const BASIC_BACKEND := "basic"
const Q3_BACKEND := "q3"
const PLATFORMER_BACKEND := "platformer"
const Q3_CONTROLLER_SCENE := preload("res://scenes/q3_character_controller.tscn")
const PLATFORMER_CONTROLLER_SCENE := preload("res://scenes/platformer_controller.tscn")

@export_enum("basic", "q3", "platformer") var movement_backend := Q3_BACKEND

@onready var input_adapter: Node = $InputAdapter
@onready var active_movement_controller: Node = $ActiveMovementController
@onready var glide_flap_modifier: Node = $GlideFlapModifier
@onready var movement_state_bridge: Node = $MovementStateBridge
@onready var goose_camera_rig: Node = $GooseCameraRig
@onready var goose_visual: Node = $GooseVisual


func _ready() -> void:
	_spawn_backend()
	movement_state_bridge.set_controller(active_movement_controller)
	goose_camera_rig.set_state_bridge(movement_state_bridge)
	goose_camera_rig.set_active_backend(active_movement_controller)
	goose_visual.set_state_bridge(movement_state_bridge)


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
	if movement_backend == Q3_BACKEND:
		_replace_active_controller(Q3_CONTROLLER_SCENE.instantiate(), spawn_transform)
		_set_prototype_character_controller(Q3_BACKEND)
	elif movement_backend == PLATFORMER_BACKEND:
		_replace_active_controller(PLATFORMER_CONTROLLER_SCENE.instantiate(), spawn_transform)
		_set_prototype_character_controller(PLATFORMER_BACKEND)
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
	_hide_backend_debug_visuals()
	call_deferred("_hide_backend_debug_visuals")


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


func _disable_backend_cameras() -> void:
	if goose_camera_rig:
		goose_camera_rig.set_active_backend(active_movement_controller)


func _resolve_movement_backend() -> String:
	var game_settings := get_node_or_null("/root/GooseGameSettings")
	if game_settings != null:
		var configured_backend = game_settings.get("movement_backend")
		if configured_backend in [BASIC_BACKEND, Q3_BACKEND, PLATFORMER_BACKEND]:
			return configured_backend
	return movement_backend


func _set_prototype_character_controller(controller_id: String) -> void:
	var settings := get_node_or_null("/root/Settings")
	if settings != null and settings.has_method("set_character_controller"):
		settings.set_character_controller(controller_id)

class_name GoosePlayerRoot
extends Node3D

const MOVEMENT_BACKEND := "q3_n_flight"
const Q3_FLIGHT_CONTROLLER_SCENE := preload("res://addons/goose-moves/scenes/q3_n_flight_controller.tscn")

var movement_backend := MOVEMENT_BACKEND

@onready var active_movement_controller: Node = $ActiveMovementController
@onready var movement_state_bridge: Node = $MovementStateBridge
@onready var goose_camera_rig: Node = $GooseCameraRig
@onready var goose_visual: Node = $GooseVisual


func _ready() -> void:
	_lock_goose_moves_backend()
	_spawn_controller()
	_connect_settings_changed()
	movement_state_bridge.set_controller(active_movement_controller)
	goose_camera_rig.set_state_bridge(movement_state_bridge)
	goose_camera_rig.set_active_backend(active_movement_controller)
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


func _spawn_controller() -> void:
	var spawn_transform := (active_movement_controller as Node3D).global_transform
	remove_child(active_movement_controller)
	active_movement_controller.queue_free()
	active_movement_controller = Q3_FLIGHT_CONTROLLER_SCENE.instantiate()
	active_movement_controller.name = "ActiveMovementController"
	add_child(active_movement_controller)
	(active_movement_controller as Node3D).global_transform = spawn_transform
	active_movement_controller.set_meta("spawn_transform", spawn_transform)
	_apply_backend_debug_visibility()
	call_deferred("_apply_backend_debug_visibility")


func _apply_backend_debug_visibility() -> void:
	var debug_visible := true
	var game_settings := get_node_or_null("/root/GooseGameSettings")
	if game_settings != null:
		debug_visible = bool(game_settings.get("debug_hud_visible"))

	for node_name in ["BodyMesh", "FaceMarker", "CharacterColliderVisual", "FlightBodyMesh"]:
		var visual := active_movement_controller.get_node_or_null(node_name) as Node3D
		if visual:
			visual.visible = false

	for hud_name in ["HUD", "Q3HUD"]:
		var backend_hud := active_movement_controller.get_node_or_null(hud_name) as CanvasLayer
		if backend_hud:
			backend_hud.visible = debug_visible
	if not debug_visible:
		var flight_hud := active_movement_controller.get_node_or_null("FlightHUD") as CanvasLayer
		if flight_hud:
			flight_hud.visible = false


func _connect_settings_changed() -> void:
	for path in ["/root/Settings", "/root/GooseGameSettings"]:
		var settings := get_node_or_null(path)
		if settings != null and settings.has_signal("settings_changed"):
			if not settings.is_connected("settings_changed", _on_settings_changed):
				settings.connect("settings_changed", _on_settings_changed)


func _on_settings_changed() -> void:
	_lock_goose_moves_backend()
	_apply_backend_debug_visibility()


func _lock_goose_moves_backend() -> void:
	var settings := get_node_or_null("/root/Settings")
	if settings != null and str(settings.get("character_controller")) != MOVEMENT_BACKEND:
		settings.set("character_controller", MOVEMENT_BACKEND)
		if settings.has_signal("settings_changed"):
			settings.emit_signal("settings_changed")

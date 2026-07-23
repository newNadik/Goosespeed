class_name GoosePlayerRoot
extends Node3D

@onready var goose_moves_runtime: Node = $GooseMovesRuntime
@onready var active_movement_controller: Node = $ActiveMovementController
@onready var movement_state_bridge: Node = $MovementStateBridge
@onready var goose_visual: Node = $GooseVisual


func _ready() -> void:
	active_movement_controller = goose_moves_runtime.spawn_controller(active_movement_controller)
	_connect_settings_changed()
	movement_state_bridge.set_controller(active_movement_controller)
	goose_visual.set_state_bridge(movement_state_bridge)
	_apply_backend_debug_visibility()
	call_deferred("_apply_backend_debug_visibility")


func get_active_controller() -> Node:
	return active_movement_controller


func reset_to_spawn() -> void:
	goose_moves_runtime.reset_to_spawn()
	goose_visual.global_position = (active_movement_controller as Node3D).global_position


func set_spawn_transform(value: Transform3D) -> void:
	goose_moves_runtime.set_spawn_transform(value)


func _apply_backend_debug_visibility() -> void:
	var debug_visible := true
	var game_settings := get_node_or_null("/root/GooseGameSettings")
	if game_settings != null:
		debug_visible = bool(game_settings.get("debug_hud_visible"))
	goose_moves_runtime.apply_debug_visibility(debug_visible)


func _connect_settings_changed() -> void:
	var settings := get_node_or_null("/root/GooseGameSettings")
	if settings != null and settings.has_signal("settings_changed"):
		if not settings.is_connected("settings_changed", _on_settings_changed):
			settings.connect("settings_changed", _on_settings_changed)


func _on_settings_changed() -> void:
	_apply_backend_debug_visibility()

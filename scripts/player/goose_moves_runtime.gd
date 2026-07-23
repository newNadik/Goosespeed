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
	if settings == null:
		return
	settings.set_character_controller_runtime(MOVEMENT_BACKEND)


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
	active_controller.set_spawn_transform(spawn_transform)
	return active_controller


func get_active_controller() -> Node:
	return active_controller


func reset_to_spawn() -> void:
	if active_controller == null:
		return
	active_controller.reset_to_spawn()


func set_spawn_transform(value: Transform3D) -> void:
	if active_controller == null:
		return
	active_controller.set_spawn_transform(value)


func set_medium(value: StringName) -> void:
	if active_controller != null and active_controller.has_method("set_medium"):
		active_controller.set_medium(value)


func apply_debug_visibility(debug_visible: bool) -> void:
	if active_controller == null:
		return
	active_controller.set_debug_hud_visible(debug_visible)


func _on_goose_moves_settings_changed() -> void:
	lock_settings_backend(get_node_or_null("/root/Settings"))

class_name MovementStateBridge
extends Node

const MovementStateScript := preload("res://scripts/player/movement_state.gd")

signal state_changed(state)

var controller: Node
var current_state := MovementStateScript.new()


func _ready() -> void:
	if controller:
		_connect_controller()


func _process(_delta: float) -> void:
	if controller and not controller.has_signal("movement_state_changed"):
		_on_controller_state_changed(_capture_controller_state())


func set_controller(value: Node) -> void:
	if (
		controller
		and controller.has_signal("movement_state_changed")
		and controller.is_connected("movement_state_changed", _on_controller_state_changed)
	):
		controller.disconnect("movement_state_changed", _on_controller_state_changed)
	controller = value
	if is_inside_tree() and controller:
		_connect_controller()


func get_state() -> RefCounted:
	return current_state.duplicate_state()


func _connect_controller() -> void:
	if (
		controller.has_signal("movement_state_changed")
		and not controller.is_connected("movement_state_changed", _on_controller_state_changed)
	):
		controller.connect("movement_state_changed", _on_controller_state_changed)
	current_state = controller.get_movement_state() if controller.has_method("get_movement_state") else _capture_controller_state()


func _on_controller_state_changed(state: RefCounted) -> void:
	current_state = state.duplicate_state()
	state_changed.emit(current_state.duplicate_state())


func _capture_controller_state() -> RefCounted:
	var result := MovementStateScript.new()
	if controller == null:
		return result
	result.position = (controller as Node3D).global_position
	var controller_velocity = controller.get("velocity")
	if typeof(controller_velocity) == TYPE_VECTOR3:
		result.velocity = controller_velocity
	result.horizontal_speed = Vector2(result.velocity.x, result.velocity.z).length()
	result.facing_direction = _capture_facing_direction()
	if controller.has_method("is_on_floor"):
		result.grounded = controller.is_on_floor()
	result.swimming = _controller_is_swimming()
	result.sliding = controller.get("is_crouch_sliding") == true
	result.gliding = false
	result.flapping = false
	result.falling = not result.grounded and result.velocity.y < -0.2
	var controller_surface = controller.get("current_surface")
	result.surface_type = StringName(controller_surface) if controller_surface != null else &"default"
	result.medium_type = &"water" if result.swimming else &"air"
	return result


func _controller_is_swimming() -> bool:
	var water_level = controller.get("water_level")
	if water_level != null:
		return int(water_level) > 1
	var current_medium = controller.get("current_medium")
	if current_medium != null:
		return StringName(current_medium) == &"water"
	return false


func _capture_facing_direction() -> Vector3:
	var face_yaw = controller.get("face_yaw")
	if face_yaw != null:
		return Vector3(sin(float(face_yaw)), 0.0, cos(float(face_yaw))).normalized()

	var facing := -(controller as Node3D).global_transform.basis.z
	facing.y = 0.0
	return facing.normalized() if not facing.is_zero_approx() else Vector3.FORWARD

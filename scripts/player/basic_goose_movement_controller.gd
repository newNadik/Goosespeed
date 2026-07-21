class_name BasicGooseMovementController
extends CharacterBody3D

const MovementStateScript := preload("res://scripts/player/movement_state.gd")

signal movement_state_changed(state)

@export var walk_speed := 11.0
@export var sprint_speed := 16.0
@export var brake_speed := 6.0
@export var ground_acceleration := 34.0
@export var air_acceleration := 10.0
@export var ground_friction := 26.0
@export var gravity := 22.0
@export var jump_velocity := 8.0
@export var swim_speed := 7.5
@export var swim_buoyancy := 5.0
@export var mouse_sensitivity := 0.003
@export var controller_turn_speed := 10.0

@onready var camera_pivot: Node3D = $CameraPivot
@onready var spring_arm: SpringArm3D = $CameraPivot/SpringArm3D
@onready var camera: Camera3D = $CameraPivot/SpringArm3D/Camera3D

var input_adapter: Node
var glide_flap_modifier: Node
var current_medium: StringName = &"air"
var current_surface: StringName = &"default"
var state := MovementStateScript.new()
var spawn_transform := Transform3D.IDENTITY
var yaw := 0.0
var pitch := deg_to_rad(-14.0)


func _ready() -> void:
	spawn_transform = global_transform
	floor_stop_on_slope = false
	floor_snap_length = 0.35
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	yaw = rotation.y
	_apply_camera_rotation()


func _physics_process(delta: float) -> void:
	if input_adapter == null:
		return

	_update_camera(delta)
	var grounded := is_on_floor()
	var wish_direction := _get_camera_relative_direction(input_adapter.move_vector)
	var target_speed := _target_speed()

	if current_medium == &"water":
		_apply_swim_motion(wish_direction, target_speed, delta)
	elif grounded:
		_apply_ground_motion(wish_direction, target_speed, delta)
	else:
		_apply_air_motion(wish_direction, target_speed, delta)

	if grounded and input_adapter.consume_jump_pressed():
		velocity.y = jump_velocity
		grounded = false

	var forward_direction := _get_forward_direction(wish_direction)
	if glide_flap_modifier:
		velocity = glide_flap_modifier.apply(
			velocity,
			forward_direction,
			input_adapter,
			grounded,
			delta
		)

	if not grounded and current_medium != &"water":
		var gravity_scale := 1.0
		if glide_flap_modifier:
			gravity_scale = glide_flap_modifier.gravity_scale_for_airborne(input_adapter)
		velocity.y -= gravity * gravity_scale * delta

	move_and_slide()
	_face_velocity_or_camera(wish_direction, delta)
	_update_state()


func reset_to_spawn() -> void:
	global_transform = spawn_transform
	velocity = Vector3.ZERO
	current_medium = &"air"
	current_surface = &"default"
	_update_state()


func set_spawn_transform(value: Transform3D) -> void:
	spawn_transform = value


func set_medium(value: StringName) -> void:
	current_medium = value


func get_movement_state() -> RefCounted:
	return state.duplicate_state()


func _apply_ground_motion(wish_direction: Vector3, target_speed: float, delta: float) -> void:
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	if wish_direction.is_zero_approx():
		horizontal = horizontal.move_toward(Vector3.ZERO, ground_friction * delta)
	else:
		horizontal = horizontal.move_toward(wish_direction * target_speed, ground_acceleration * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	velocity.y = minf(velocity.y, 0.0)


func _apply_air_motion(wish_direction: Vector3, target_speed: float, delta: float) -> void:
	if wish_direction.is_zero_approx():
		return
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	horizontal = horizontal.move_toward(wish_direction * target_speed, air_acceleration * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z


func _apply_swim_motion(wish_direction: Vector3, target_speed: float, delta: float) -> void:
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	var swim_target := swim_speed
	if input_adapter.speed_held:
		swim_target = target_speed
	if input_adapter.control_held:
		swim_target = brake_speed
	horizontal = horizontal.move_toward(wish_direction * swim_target, ground_acceleration * 0.55 * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	velocity.y = move_toward(velocity.y, 0.25, swim_buoyancy * delta)
	if input_adapter.consume_jump_pressed():
		velocity.y = jump_velocity * 0.8


func _target_speed() -> float:
	if input_adapter.control_held:
		return brake_speed
	if input_adapter.speed_held:
		return sprint_speed
	return walk_speed


func _get_camera_relative_direction(move_vector: Vector2) -> Vector3:
	if move_vector.is_zero_approx():
		return Vector3.ZERO
	var yaw_basis := Basis(Vector3.UP, yaw)
	var forward := -yaw_basis.z
	var right := yaw_basis.x
	return ((right * move_vector.x) + (forward * move_vector.y)).normalized()


func _get_forward_direction(wish_direction: Vector3) -> Vector3:
	if not wish_direction.is_zero_approx():
		return wish_direction
	var yaw_basis := Basis(Vector3.UP, yaw)
	return -yaw_basis.z


func _face_velocity_or_camera(wish_direction: Vector3, delta: float) -> void:
	var facing := wish_direction
	if facing.is_zero_approx():
		var horizontal := Vector3(velocity.x, 0.0, velocity.z)
		if horizontal.length() > 0.2:
			facing = horizontal.normalized()
	if facing.is_zero_approx():
		return
	var target_yaw := atan2(-facing.x, -facing.z)
	rotation.y = lerp_angle(rotation.y, target_yaw, minf(controller_turn_speed * delta, 1.0))


func _update_camera(_delta: float) -> void:
	if input_adapter.consume_reset_camera_pressed():
		yaw = rotation.y
		pitch = deg_to_rad(-14.0)
	var look: Vector2 = input_adapter.consume_look_delta()
	yaw -= look.x * mouse_sensitivity
	pitch = clampf(pitch - look.y * mouse_sensitivity, deg_to_rad(-55.0), deg_to_rad(18.0))
	_apply_camera_rotation()


func _apply_camera_rotation() -> void:
	camera_pivot.rotation = Vector3(pitch, yaw - rotation.y, 0.0)


func _update_state() -> void:
	state.position = global_position
	state.velocity = velocity
	state.horizontal_speed = Vector2(velocity.x, velocity.z).length()
	state.facing_direction = -global_transform.basis.z
	state.grounded = is_on_floor()
	state.swimming = current_medium == &"water"
	state.sliding = input_adapter != null and input_adapter.control_held and state.horizontal_speed > walk_speed
	state.gliding = glide_flap_modifier != null and glide_flap_modifier.gliding
	state.flapping = glide_flap_modifier != null and glide_flap_modifier.flapping
	state.falling = not state.grounded and velocity.y < -0.2
	state.surface_type = current_surface
	state.medium_type = current_medium
	movement_state_changed.emit(state.duplicate_state())

class_name GooseHeadLookController
extends Node

const MovementStateScript := preload("res://scripts/player/movement_state.gd")

@export var enabled := true
@export_range(0.0, 1.0, 0.05) var intensity := 0.65
@export var smoothness := 10.0
@export_range(0.0, 90.0, 1.0, "radians_as_degrees") var max_yaw := deg_to_rad(85.0)
@export_range(0.0, 60.0, 1.0, "radians_as_degrees") var max_pitch := deg_to_rad(16.0)
@export_range(0.0, 90.0, 1.0, "radians_as_degrees") var flight_max_yaw := deg_to_rad(70.0)
@export_range(0.0, 60.0, 1.0, "radians_as_degrees") var flight_max_pitch := deg_to_rad(24.0)
@export var flight_yaw_scale := 1.35
@export var flight_pitch_vertical_scale := 0.45
@export_range(0.0, 1.0, 0.05) var flight_head_level_strength := 0.75
@export var neck_motion_scale := 1.1
@export var ground_intensity_scale := 1.0
@export var ground_min_look_speed := 0.35
@export var yaw_axis_sign := -1.0
@export var pitch_axis_sign := -1.0
@export var flight_world_solver_enabled := true
@export var flight_world_solver_smoothness := 12.0
@export var flight_head_forward_axis := Vector3.UP
@export var flight_world_solver_weights: Array[float] = [0.0, 0.22, 0.34, 0.44]

var skeleton: Skeleton3D
var bone_names: Array[StringName] = [&"Neck1", &"Neck2", &"Neck3", &"Head"]
var bone_indices: Array[int] = []
var yaw_weights: Array[float] = [0.08, 0.22, 0.34, 0.36]
var pitch_weights: Array[float] = [0.02, 0.14, 0.28, 0.06]
var current_yaw := 0.0
var current_pitch := 0.0
var queued_state: RefCounted
var queued_visual_basis := Basis.IDENTITY
var queued_camera: Camera3D
var smoothed_flight_target_direction := Vector3.ZERO


func setup(visual_root: Node) -> void:
	skeleton = visual_root.get_node_or_null("Goose/Skeleton3D") as Skeleton3D
	_rebuild_bone_indices()


func _process(delta: float) -> void:
	if queued_state != null:
		apply_look(delta, queued_state, queued_visual_basis, queued_camera)


func queue_look(state: RefCounted, visual_basis: Basis, camera: Camera3D) -> void:
	queued_state = state
	queued_visual_basis = visual_basis
	queued_camera = camera


func apply_look(delta: float, state: RefCounted, visual_basis: Basis, camera: Camera3D) -> void:
	if skeleton == null:
		return

	if state.mode == &"flight" and flight_world_solver_enabled:
		_apply_flight_world_solver(delta, state, camera)
		return

	var target_angles := _target_angles(state, visual_basis, camera)
	var blend := minf(delta * maxf(smoothness, 0.0), 1.0)
	current_yaw = lerp_angle(current_yaw, target_angles.x, blend)
	current_pitch = lerpf(current_pitch, target_angles.y, blend)
	_apply_pose_offsets(_state_intensity(state), state, visual_basis)


func _rebuild_bone_indices() -> void:
	bone_indices.clear()
	if skeleton == null:
		return
	for bone_name in bone_names:
		var bone_index := skeleton.find_bone(String(bone_name))
		if bone_index >= 0:
			bone_indices.append(bone_index)


func _target_angles(state: RefCounted, visual_basis: Basis, camera: Camera3D) -> Vector2:
	var state_intensity := _state_intensity(state)
	if state_intensity <= 0.0:
		return Vector2.ZERO

	var look_direction := _look_direction(state, camera)
	if look_direction.is_zero_approx():
		return Vector2.ZERO

	var local_direction := visual_basis.inverse() * look_direction.normalized()
	if local_direction.is_zero_approx():
		return Vector2.ZERO

	var yaw_direction := _yaw_local_direction(local_direction, state)
	if yaw_direction.is_zero_approx():
		return Vector2.ZERO
	var pitch_direction := _pitch_local_direction(local_direction, state)
	var yaw := atan2(yaw_direction.x, -yaw_direction.z) * _yaw_scale_for_state(state)
	var pitch := asin(clampf(pitch_direction.y, -1.0, 1.0))
	var state_max_yaw := _max_yaw_for_state(state)
	var state_max_pitch := _max_pitch_for_state(state)
	return Vector2(
		clampf(yaw, -state_max_yaw, state_max_yaw),
		clampf(pitch, -state_max_pitch, state_max_pitch),
	)


func _look_direction(state: RefCounted, camera: Camera3D) -> Vector3:
	if camera != null:
		var camera_basis := camera.global_basis if camera.is_inside_tree() else camera.basis
		return -camera_basis.z
	if "look_direction" in state and not state.look_direction.is_zero_approx():
		return state.look_direction
	if state.mode == &"flight":
		return -(state.body_basis as Basis).z
	return state.facing_direction


func _state_intensity(state: RefCounted) -> float:
	if not enabled:
		return 0.0
	var clamped_intensity := clampf(intensity, 0.0, 1.0)
	if state.mode == &"flight":
		return clamped_intensity
	if state.grounded and not state.swimming:
		if not _has_ground_look_intent(state):
			return 0.0
		return clamped_intensity * clampf(ground_intensity_scale, 0.0, 1.0)
	return 0.0


func _has_ground_look_intent(state: RefCounted) -> bool:
	if state.horizontal_speed >= ground_min_look_speed:
		return true
	if "intended_movement_magnitude" in state and state.intended_movement_magnitude > 0.05:
		return true
	return false


func _max_yaw_for_state(state: RefCounted) -> float:
	if state.mode == &"flight":
		return minf(max_yaw, flight_max_yaw)
	return max_yaw


func _max_pitch_for_state(state: RefCounted) -> float:
	if state.mode == &"flight":
		return minf(max_pitch, flight_max_pitch)
	return max_pitch


func _yaw_scale_for_state(state: RefCounted) -> float:
	if state.mode == &"flight":
		return maxf(flight_yaw_scale, 0.0)
	return 1.0


func _yaw_local_direction(local_direction: Vector3, state: RefCounted) -> Vector3:
	if state.mode == &"flight":
		var flight_result := Vector3(local_direction.x, 0.0, local_direction.z)
		return flight_result.normalized() if not flight_result.is_zero_approx() else Vector3.ZERO
	var vertical_scale := 0.25
	var result := Vector3(local_direction.x, local_direction.y * vertical_scale, local_direction.z)
	return result.normalized() if not result.is_zero_approx() else Vector3.ZERO


func _pitch_local_direction(local_direction: Vector3, state: RefCounted) -> Vector3:
	var vertical_scale := flight_pitch_vertical_scale if state.mode == &"flight" else 0.25
	var result := Vector3(local_direction.x, local_direction.y * vertical_scale, local_direction.z)
	return result.normalized() if not result.is_zero_approx() else Vector3.ZERO


func _apply_pose_offsets(state_intensity: float, state: RefCounted, visual_basis: Basis) -> void:
	var bone_count: int = mini(bone_indices.size(), mini(yaw_weights.size(), pitch_weights.size()))
	for index in bone_count:
		var bone_index := bone_indices[index]
		var yaw_weight := yaw_weights[index] * state_intensity * neck_motion_scale
		var pitch_weight := pitch_weights[index] * state_intensity * neck_motion_scale
		var yaw_rotation := Quaternion(Vector3.BACK * _axis_sign(yaw_axis_sign), current_yaw * yaw_weight)
		var pitch_rotation := Quaternion(Vector3.RIGHT * _axis_sign(pitch_axis_sign), current_pitch * pitch_weight)
		var pose_rotation := skeleton.get_bone_pose_rotation(bone_index)
		var level_rotation := _head_level_rotation(index, state, visual_basis)
		skeleton.set_bone_pose_rotation(bone_index, pose_rotation * yaw_rotation * pitch_rotation * level_rotation)
	if skeleton.has_method("force_update_all_bone_transforms"):
		skeleton.call("force_update_all_bone_transforms")


func _apply_flight_world_solver(delta: float, state: RefCounted, camera: Camera3D) -> void:
	var state_intensity := _state_intensity(state)
	var target_direction_world := _look_direction(state, camera)
	if state_intensity <= 0.0 or target_direction_world.is_zero_approx():
		return
	target_direction_world = target_direction_world.normalized()
	var target_blend := minf(delta * maxf(flight_world_solver_smoothness, 0.0), 1.0)
	if smoothed_flight_target_direction.is_zero_approx():
		smoothed_flight_target_direction = target_direction_world
	else:
		smoothed_flight_target_direction = smoothed_flight_target_direction.slerp(
			target_direction_world,
			target_blend,
		).normalized()

	var skeleton_basis := skeleton.global_basis.orthonormalized()
	var target_direction_local := (skeleton_basis.inverse() * smoothed_flight_target_direction).normalized()
	var head_index := _head_bone_index()
	if head_index < 0:
		return

	for index in range(1, bone_indices.size()):
		var weight := _flight_world_solver_weight(index) * state_intensity * neck_motion_scale
		if weight <= 0.0:
			continue
		_apply_world_aim_step(bone_indices[index], head_index, target_direction_local, weight)

func _apply_world_aim_step(
	bone_index: int,
	head_index: int,
	target_direction_local: Vector3,
	weight: float,
) -> void:
	var head_pose := skeleton.get_bone_global_pose(head_index)
	var current_direction := _head_forward_direction(head_pose)
	if current_direction.is_zero_approx() or target_direction_local.is_zero_approx():
		return
	var dot := clampf(current_direction.dot(target_direction_local), -1.0, 1.0)
	var angle := acos(dot)
	if angle <= 0.001:
		return
	var axis := current_direction.cross(target_direction_local)
	if axis.is_zero_approx():
		return
	var correction := Quaternion(axis.normalized(), angle * clampf(weight, 0.0, 1.0))
	var bone_pose := skeleton.get_bone_global_pose(bone_index)
	bone_pose.basis = (Basis(correction) * bone_pose.basis).orthonormalized()
	skeleton.set_bone_global_pose(bone_index, bone_pose)
	if skeleton.has_method("force_update_all_bone_transforms"):
		skeleton.call("force_update_all_bone_transforms")


func _head_forward_direction(head_pose: Transform3D) -> Vector3:
	var axis := flight_head_forward_axis.normalized()
	if axis.is_zero_approx():
		axis = Vector3.FORWARD
	return (head_pose.basis.orthonormalized() * axis).normalized()


func _head_bone_index() -> int:
	if bone_indices.is_empty():
		return -1
	return bone_indices[bone_indices.size() - 1]


func _flight_world_solver_weight(index: int) -> float:
	if index < 0 or index >= flight_world_solver_weights.size():
		return 0.0
	return flight_world_solver_weights[index]


func _head_level_rotation(bone_chain_index: int, state: RefCounted, visual_basis: Basis) -> Quaternion:
	if state.mode != &"flight" or bone_chain_index != bone_indices.size() - 1:
		return Quaternion.IDENTITY
	var local_world_up := visual_basis.orthonormalized().inverse() * Vector3.UP
	var roll_angle := atan2(local_world_up.x, local_world_up.y)
	if absf(roll_angle) <= 0.001:
		return Quaternion.IDENTITY
	return Quaternion(Vector3.UP, -roll_angle * clampf(flight_head_level_strength, 0.0, 1.0))


func _axis_sign(value: float) -> float:
	return -1.0 if value < 0.0 else 1.0

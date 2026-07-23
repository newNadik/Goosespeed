class_name GooseHeadLookController
extends Node

const MovementStateScript := preload("res://scripts/player/movement_state.gd")

@export var enabled := true
@export_range(0.0, 1.0, 0.05) var intensity := 0.65
@export var smoothness := 10.0
@export_range(0.0, 90.0, 1.0, "radians_as_degrees") var max_yaw := deg_to_rad(65.0)
@export_range(0.0, 60.0, 1.0, "radians_as_degrees") var max_pitch := deg_to_rad(38.0)
@export var neck_motion_scale := 1.6
@export var ground_intensity_scale := 0.35

var skeleton: Skeleton3D
var bone_names: Array[StringName] = [&"Neck1", &"Neck2", &"Neck3", &"Head"]
var bone_indices: Array[int] = []
var bone_weights: Array[float] = [0.34, 0.30, 0.24, 0.12]
var current_yaw := 0.0
var current_pitch := 0.0
var queued_state: RefCounted
var queued_visual_basis := Basis.IDENTITY
var queued_camera: Camera3D


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

	var target_angles := _target_angles(state, visual_basis, camera)
	var blend := minf(delta * maxf(smoothness, 0.0), 1.0)
	current_yaw = lerp_angle(current_yaw, target_angles.x, blend)
	current_pitch = lerpf(current_pitch, target_angles.y, blend)
	_apply_pose_offsets(_state_intensity(state))


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

	var yaw := atan2(local_direction.x, -local_direction.z)
	var pitch := asin(clampf(local_direction.y, -1.0, 1.0))
	return Vector2(
		clampf(yaw, -max_yaw, max_yaw),
		clampf(pitch, -max_pitch, max_pitch),
	)


func _look_direction(state: RefCounted, camera: Camera3D) -> Vector3:
	if "look_direction" in state and not state.look_direction.is_zero_approx():
		return state.look_direction
	if camera != null:
		return -camera.global_basis.z
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
		return clamped_intensity * clampf(ground_intensity_scale, 0.0, 1.0)
	return 0.0


func _apply_pose_offsets(state_intensity: float) -> void:
	var bone_count: int = mini(bone_indices.size(), bone_weights.size())
	for index in bone_count:
		var bone_index := bone_indices[index]
		var weight := bone_weights[index] * state_intensity * neck_motion_scale
		var yaw_rotation := Quaternion(Vector3.UP, -current_yaw * weight)
		var pitch_rotation := Quaternion(Vector3.RIGHT, current_pitch * weight)
		var pose_rotation := skeleton.get_bone_pose_rotation(bone_index)
		skeleton.set_bone_pose_rotation(bone_index, pose_rotation * yaw_rotation * pitch_rotation)
	if skeleton.has_method("force_update_all_bone_transforms"):
		skeleton.call("force_update_all_bone_transforms")

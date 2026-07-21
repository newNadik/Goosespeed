class_name GooseCameraRig
extends Node3D

@export var mouse_sensitivity := 0.003
@export var third_person_distance := 6.0
@export var target_height := 1.25
@export var follow_speed := 18.0
@export var pitch_min_degrees := -75.0
@export var pitch_max_degrees := 60.0
@export var fov := 100.0

@onready var yaw_pivot: Node3D = $YawPivot
@onready var pitch_pivot: Node3D = $YawPivot/PitchPivot
@onready var spring_arm: SpringArm3D = $YawPivot/PitchPivot/SpringArm3D
@onready var third_person_camera: Camera3D = $YawPivot/PitchPivot/SpringArm3D/ThirdPersonCamera
@onready var first_person_camera: Camera3D = $YawPivot/PitchPivot/FirstPersonCamera

var state_bridge: Node
var active_backend: Node
var yaw := 0.0
var pitch := deg_to_rad(-15.0)
var first_person_enabled := false


func _ready() -> void:
	spring_arm.spring_length = third_person_distance
	third_person_camera.fov = fov
	first_person_camera.fov = fov
	_apply_camera_mode()
	_apply_rotation()


func _process(delta: float) -> void:
	if Input.is_action_just_pressed(&"player_reset_camera"):
		_align_behind_facing()
	_sync_from_backend_if_available()
	_follow_target(delta)
	_apply_rotation()
	_sync_backend_camera_state()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion := event as InputEventMouseMotion
		yaw -= motion.relative.x * mouse_sensitivity
		pitch = clampf(
			pitch - (motion.relative.y * mouse_sensitivity),
			deg_to_rad(pitch_min_degrees),
			deg_to_rad(pitch_max_degrees)
		)


func set_state_bridge(value: Node) -> void:
	state_bridge = value
	if is_inside_tree():
		_align_behind_facing()


func set_active_backend(value: Node) -> void:
	active_backend = value
	_disable_backend_cameras()
	call_deferred("_disable_backend_cameras")
	_sync_from_backend_if_available()


func _follow_target(delta: float) -> void:
	if state_bridge == null:
		return
	var state: RefCounted = state_bridge.get_state()
	var target_position: Vector3 = state.position + (Vector3.UP * target_height)
	global_position = global_position.lerp(target_position, minf(follow_speed * delta, 1.0))


func _align_behind_facing() -> void:
	if state_bridge == null:
		return
	var state: RefCounted = state_bridge.get_state()
	var facing: Vector3 = state.facing_direction
	if facing.is_zero_approx():
		return
	yaw = atan2(-facing.x, -facing.z)
	pitch = deg_to_rad(-15.0)


func _apply_rotation() -> void:
	yaw_pivot.rotation.y = yaw
	pitch_pivot.rotation.x = pitch


func _apply_camera_mode() -> void:
	third_person_camera.current = not first_person_enabled
	first_person_camera.current = first_person_enabled


func _disable_backend_cameras() -> void:
	if active_backend == null:
		return
	for camera in _find_backend_cameras(active_backend):
		(camera as Camera3D).current = false
	_apply_camera_mode()


func _find_backend_cameras(root: Node) -> Array[Camera3D]:
	var cameras: Array[Camera3D] = []
	if root is Camera3D:
		cameras.append(root as Camera3D)
	for child in root.get_children():
		cameras.append_array(_find_backend_cameras(child))
	return cameras


func _sync_from_backend_if_available() -> void:
	if active_backend == null:
		return
	var backend_yaw = active_backend.get("camera_yaw")
	if backend_yaw != null:
		yaw = float(backend_yaw)
	var backend_pitch = active_backend.get("camera_pitch")
	if backend_pitch != null:
		pitch = float(backend_pitch)


func _sync_backend_camera_state() -> void:
	if active_backend == null:
		return
	if active_backend.get("camera_yaw") != null:
		active_backend.set("camera_yaw", yaw)
	if active_backend.get("camera_pitch") != null:
		active_backend.set("camera_pitch", pitch)
	if active_backend.get("yaw") != null:
		active_backend.set("yaw", yaw)
	var head := active_backend.get_node_or_null("Head") as Node3D
	if head:
		head.rotation.x = pitch

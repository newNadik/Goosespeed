class_name GooseCameraRig
extends Node3D

@export var mouse_sensitivity := 0.003
@export var third_person_distance := 4.0
@export var target_height := 0.9
@export var follow_speed := 18.0
@export var pitch_min_degrees := -75.0
@export var pitch_max_degrees := 60.0
@export var fov := 78.0

@onready var yaw_pivot: Node3D = $YawPivot
@onready var pitch_pivot: Node3D = $YawPivot/PitchPivot
@onready var spring_arm: SpringArm3D = $YawPivot/PitchPivot/SpringArm3D
@onready var third_person_camera: Camera3D = $YawPivot/PitchPivot/SpringArm3D/ThirdPersonCamera
@onready var first_person_camera: Camera3D = $YawPivot/PitchPivot/FirstPersonCamera

var state_bridge: Node
var yaw := 0.0
var pitch := deg_to_rad(-15.0)
var first_person_enabled := false


func _ready() -> void:
	spring_arm.spring_length = third_person_distance
	third_person_camera.fov = fov
	first_person_camera.fov = fov
	_apply_saved_camera_mode()
	var game_settings := get_node_or_null("/root/GooseGameSettings")
	var callback := Callable(self, "_apply_saved_camera_mode")
	if game_settings != null and game_settings.has_signal("settings_changed") and not game_settings.is_connected("settings_changed", callback):
		game_settings.connect("settings_changed", callback)
	_apply_camera_mode()
	_apply_rotation()


func _process(delta: float) -> void:
	if Input.is_action_just_pressed(&"player_reset_camera"):
		_align_behind_facing()
	_follow_target(delta)
	_apply_rotation()


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


func deactivate() -> void:
	set_process(false)
	set_process_unhandled_input(false)
	third_person_camera.clear_current(false)
	first_person_camera.clear_current(false)


func set_camera_mode(value: String) -> void:
	first_person_enabled = value == "first_person"
	_apply_camera_mode()


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


func _apply_saved_camera_mode() -> void:
	var game_settings := get_node_or_null("/root/GooseGameSettings")
	if game_settings == null:
		return
	set_camera_mode(str(game_settings.get("camera_mode")))

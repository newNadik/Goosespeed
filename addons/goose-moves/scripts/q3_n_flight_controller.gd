class_name Q3NFlightController
extends CharacterBody3D

signal movement_state_changed(state)

const DEFAULT_FLIGHT_HOLD_THRESHOLD := 0.3
const DEFAULT_FLIGHT_NO_CONTACT_THRESHOLD := 0.3
const DEFAULT_FLIGHT_MIN_ACTIVATION_SPEED := 12.0
const DEFAULT_BODY_BOUNCE_ENABLED := 1.0
const DEFAULT_BODY_BOUNCE_MIN_NORMAL_SPEED := 18.0
const DEFAULT_BODY_BOUNCE_KNOCKDOWN_DURATION := 1.2
const DEFAULT_BODY_BOUNCE_RESTITUTION := 0.75
const DEFAULT_BODY_BOUNCE_MAX_SPEED := 16.0
const DEFAULT_LANDING_CARRY_ENABLED := 1.0
const DEFAULT_LANDING_FRICTION_MULTIPLIER := 0.5
const DEFAULT_LANDING_CARRY_DURATION := 0.18
const DEFAULT_LANDING_CARRY_MIN_SPEED := 3.0
const DEFAULT_HARD_LANDING_VERTICAL_SPEED := 14.0
const CAMERA_TRANSITION_DURATION := 0.2
const FLIGHT_COLLISION_SIZE := Vector3(1.2, 1.2, 1.2)
const TAKEOFF_FLIGHT_MAX_PITCH_UP := deg_to_rad(30.0)
const TAKEOFF_FLIGHT_MAX_PITCH_DOWN := deg_to_rad(25.0)
const Q3_MOVEMENT_MOTOR := preload("res://addons/goose-moves/scripts/q3_movement_motor.gd")
const FLIGHT_MOVEMENT_MOTOR := preload("res://addons/goose-moves/scripts/flight_movement_motor.gd")
const Q3_MOVEMENT_HUD := preload("res://addons/goose-moves/scripts/q3_movement_hud.gd")
const MOVEMENT_STATE_TRACKER := preload("res://addons/goose-moves/scripts/movement_state_tracker.gd")

enum Mode {
	Q3,
	FLIGHT,
}

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var third_person_spring_arm: SpringArm3D = $Head/ThirdPersonSpringArm
@onready var third_person_camera: Camera3D = $Head/ThirdPersonSpringArm/Camera3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var character_collider_visual: MeshInstance3D = $CharacterColliderVisual
@onready var q3_hud: Q3_MOVEMENT_HUD = $Q3HUD
@onready var flight_body_mesh: MeshInstance3D = $FlightBodyMesh
@onready var flight_camera_rig: Node3D = $FlightCameraRig
@onready var flight_camera: Camera3D = $FlightCameraRig/SpringArm3D/Camera3D
@onready var flight_first_person_camera: Camera3D = $FlightFirstPersonCamera
@onready var transition_camera: Camera3D = $TransitionCamera
@onready var flight_spring_arm: SpringArm3D = $FlightCameraRig/SpringArm3D
@onready var flight_hud: CanvasLayer = $FlightHUD
@onready var flight_status_label: Label = $FlightHUD/StatusLabel

var q3_motor := Q3_MOVEMENT_MOTOR.new()
var flight_motor := FLIGHT_MOVEMENT_MOTOR.new()
var mode := Mode.Q3
var flight_hold_threshold := DEFAULT_FLIGHT_HOLD_THRESHOLD
var flight_no_contact_threshold := DEFAULT_FLIGHT_NO_CONTACT_THRESHOLD
var flight_min_activation_speed := DEFAULT_FLIGHT_MIN_ACTIVATION_SPEED
var body_bounce_enabled := DEFAULT_BODY_BOUNCE_ENABLED >= 0.5
var body_bounce_min_normal_speed := DEFAULT_BODY_BOUNCE_MIN_NORMAL_SPEED
var body_bounce_knockdown_duration := DEFAULT_BODY_BOUNCE_KNOCKDOWN_DURATION
var body_bounce_restitution := DEFAULT_BODY_BOUNCE_RESTITUTION
var body_bounce_max_speed := DEFAULT_BODY_BOUNCE_MAX_SPEED
var landing_carry_enabled := DEFAULT_LANDING_CARRY_ENABLED >= 0.5
var landing_friction_multiplier := DEFAULT_LANDING_FRICTION_MULTIPLIER
var landing_carry_duration := DEFAULT_LANDING_CARRY_DURATION
var landing_carry_min_speed := DEFAULT_LANDING_CARRY_MIN_SPEED
var hard_landing_vertical_speed := DEFAULT_HARD_LANDING_VERTICAL_SPEED
var knockdown_time_remaining := 0.0
var flap_hold_time := 0.0
var no_surface_contact_time := 0.0
var movement_state := MOVEMENT_STATE_TRACKER.new()
var camera_transition_active := false
var camera_transition_elapsed := 0.0
var camera_transition_from_transform := Transform3D.IDENTITY
var camera_transition_from_fov := 100.0
var camera_transition_target: Camera3D
var first_person_camera_enabled := false
var presentation_enabled := true
var debug_hud_visible := true
var player_body_render_layer := 0


func _ready() -> void:
	transition_camera.top_level = true
	flight_motor.setup(self, {
		"collision_shape": collision_shape,
		"body_mesh": flight_body_mesh,
		"camera_rig": flight_camera_rig,
		"camera": flight_camera,
		"first_person_camera": flight_first_person_camera,
		"spring_arm": flight_spring_arm,
		"status_label": flight_status_label,
		"body_mesh_visible": false,
	}, Settings.CHARACTER_Q3_N_FLIGHT, false)
	q3_motor.setup(self, {
		"head": head,
		"camera": camera,
		"third_person_spring_arm": third_person_spring_arm,
		"third_person_camera": third_person_camera,
		"collision_shape": collision_shape,
		"character_collider_visual": character_collider_visual,
		"character_collider_visible": false,
		"hud": q3_hud,
	}, Settings.CHARACTER_Q3_N_FLIGHT)
	_sync_q3_body_size_to_flight()
	Settings.settings_changed.connect(on_settings_changed)
	_apply_controller_settings()
	_enter_q3(false)


func _process(delta: float) -> void:
	_handle_camera_actions()
	if mode == Mode.FLIGHT:
		flight_motor.process_tick(delta)
	else:
		q3_motor.process_tick(delta)
	_update_knockdown_hud()
	_update_camera_transition(delta)


func _physics_process(delta: float) -> void:
	movement_state.physics_tick(delta)
	_update_knockdown_timer(delta)
	if mode == Mode.FLIGHT:
		if Input.is_action_pressed("player_crouch"):
			_enter_q3(true)
			_emit_movement_state_changed()
			return
		var flight_impact_velocity := velocity
		flight_motor.physics_tick(delta)
		if flight_motor.consume_flap_impulse_fired():
			movement_state.record_flap()
		var flight_bounce_impact := _get_body_bounce_impact(flight_impact_velocity)
		if not flight_bounce_impact.is_empty():
			var bounced_velocity := _get_body_bounce_velocity(
				flight_impact_velocity,
				flight_bounce_impact["normal"] as Vector3,
			)
			_enter_q3(true)
			velocity = bounced_velocity
			movement_state.record_crash(flight_bounce_impact)
			_start_knockdown()
		elif get_slide_collision_count() > 0:
			var flight_landing_impact := _get_floor_impact(flight_impact_velocity)
			_enter_q3(true)
			_record_landing_and_preserve(flight_impact_velocity, flight_landing_impact)
		_emit_movement_state_changed()
		return

	q3_motor.control_enabled = not _is_knocked_down()
	_update_flap_hold(delta)
	var was_grounded := is_on_floor()
	var q3_impact_velocity := velocity
	q3_motor.ground_friction_multiplier = movement_state.get_landing_friction_multiplier(
		landing_carry_enabled,
		landing_friction_multiplier,
	)
	q3_motor.physics_tick(delta)
	q3_motor.ground_friction_multiplier = 1.0
	if not was_grounded and is_on_floor() and q3_impact_velocity.y <= 0.0:
		_record_landing_and_preserve(q3_impact_velocity, _get_floor_impact(q3_impact_velocity))
	elif was_grounded and not is_on_floor():
		movement_state.record_takeoff(q3_impact_velocity)
	var q3_bounce_impact := _get_body_bounce_impact(q3_impact_velocity)
	if not q3_bounce_impact.is_empty():
		velocity = _get_body_bounce_velocity(q3_impact_velocity, q3_bounce_impact["normal"] as Vector3)
		movement_state.record_crash(q3_bounce_impact)
		_start_knockdown()
	_update_no_surface_contact_time(delta)
	if _can_activate_flight():
		_enter_flight()
	_emit_movement_state_changed()


func _input(event: InputEvent) -> void:
	if mode == Mode.FLIGHT:
		flight_motor.handle_input(event)


func _unhandled_input(event: InputEvent) -> void:
	if mode == Mode.Q3:
		q3_motor.handle_unhandled_input(event)


func place_at_view(view_transform: Transform3D) -> void:
	var euler := view_transform.basis.get_euler()
	position = view_transform.origin - (Vector3.UP * _get_q3_eye_height())
	rotation = Vector3(0.0, euler.y, 0.0)
	var view_head := get_node_or_null("Head") as Node3D
	if view_head:
		view_head.rotation = Vector3(euler.x, 0.0, 0.0)


func get_view_camera() -> Camera3D:
	if camera_transition_active:
		return transition_camera
	if mode == Mode.FLIGHT:
		return flight_motor.get_view_camera()
	if q3_motor.third_person_enabled:
		return third_person_camera
	return camera


func get_movement_state() -> Dictionary:
	return movement_state.build_state(_get_movement_state_snapshot())


func _emit_movement_state_changed() -> void:
	movement_state_changed.emit(get_movement_state())


func get_flight_debug_state() -> Dictionary:
	var debug_state := flight_motor.get_debug_state()
	debug_state["mode"] = "flight" if mode == Mode.FLIGHT else "q3"
	return debug_state


func _try_flap_impulse() -> void:
	if mode == Mode.FLIGHT and flight_motor._try_flap_impulse():
		movement_state.record_flap()


func set_spawn_transform(value: Transform3D) -> void:
	set_meta("spawn_transform", value)


func reset_to_spawn() -> void:
	var spawn_transform: Transform3D = get_meta("spawn_transform", Transform3D.IDENTITY)
	global_transform = spawn_transform
	velocity = Vector3.ZERO
	mode = Mode.Q3
	motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED
	knockdown_time_remaining = 0.0
	flap_hold_time = 0.0
	no_surface_contact_time = 0.0
	movement_state = MOVEMENT_STATE_TRACKER.new()
	var euler := spawn_transform.basis.get_euler()
	set_view_angles(euler.y, euler.x)
	_set_q3_visuals()


func set_presentation_enabled(value: bool) -> void:
	presentation_enabled = value
	_apply_presentation_state()


func set_debug_hud_visible(value: bool) -> void:
	debug_hud_visible = value
	_apply_debug_hud_visibility()


func get_view_angles() -> Vector2:
	if mode == Mode.FLIGHT:
		return Vector2(flight_motor.camera_yaw, flight_motor.camera_pitch)
	return Vector2(q3_motor.yaw, q3_motor.pitch)


func get_view_direction() -> Vector3:
	var view_angles := get_view_angles()
	var pitch_scale := cos(view_angles.y)
	return Vector3(
		-sin(view_angles.x) * pitch_scale,
		sin(view_angles.y),
		-cos(view_angles.x) * pitch_scale,
	).normalized()


func set_view_angles(view_yaw: float, view_pitch: float) -> void:
	q3_motor.yaw = view_yaw
	q3_motor.pitch = clampf(view_pitch, deg_to_rad(-89.0), deg_to_rad(89.0))
	q3_motor._apply_view_rotation(false)
	flight_motor.camera_yaw = view_yaw
	flight_motor.camera_pitch = clampf(view_pitch, deg_to_rad(-75.0), deg_to_rad(60.0))
	flight_motor._apply_camera_rotation()


func recenter_camera() -> void:
	if mode == Mode.FLIGHT:
		flight_motor.camera_yaw = _get_upright_yaw()
		flight_motor._apply_camera_rotation()
		return
	q3_motor.recenter_camera()


func toggle_camera_mode() -> void:
	var new_first_person := not first_person_camera_enabled
	Settings.set_controller_setting(
		"third_person",
		0.0 if new_first_person else 1.0,
		Settings.CHARACTER_Q3_N_FLIGHT,
	)
	Settings.set_controller_setting(
		"first_person",
		1.0 if new_first_person else 0.0,
		Settings.CHARACTER_Q3_N_FLIGHT,
	)
	_apply_shared_camera_mode(new_first_person)
	if mode == Mode.FLIGHT:
		_set_flight_visuals()
	else:
		_set_q3_visuals()


func disable_internal_cameras() -> void:
	for camera_node in _find_cameras(self):
		camera_node.clear_current(false)


func set_player_body_render_layer(value: int) -> void:
	player_body_render_layer = value
	_apply_player_body_cull_masks()


func on_settings_changed() -> void:
	q3_motor.on_settings_changed()
	_sync_q3_body_size_to_flight()
	flight_motor.on_settings_changed()
	_apply_controller_settings()
	if mode == Mode.Q3:
		_set_q3_visuals()
	_apply_presentation_state()
	_apply_debug_hud_visibility()


func _apply_controller_settings() -> void:
	flight_hold_threshold = Settings.get_controller_setting(
		"flight_hold_threshold",
		Settings.CHARACTER_Q3_N_FLIGHT,
	)
	flight_no_contact_threshold = Settings.get_controller_setting(
		"flight_no_contact_threshold",
		Settings.CHARACTER_Q3_N_FLIGHT,
	)
	flight_min_activation_speed = Settings.get_controller_setting(
		"flight_min_activation_speed",
		Settings.CHARACTER_Q3_N_FLIGHT,
	)
	body_bounce_enabled = Settings.get_controller_setting(
		"body_bounce",
		Settings.CHARACTER_Q3_N_FLIGHT,
	) >= 0.5
	body_bounce_min_normal_speed = Settings.get_controller_setting(
		"body_bounce_min_normal_speed",
		Settings.CHARACTER_Q3_N_FLIGHT,
	)
	body_bounce_knockdown_duration = Settings.get_controller_setting(
		"body_bounce_knockdown_duration",
		Settings.CHARACTER_Q3_N_FLIGHT,
	)
	body_bounce_restitution = Settings.get_controller_setting(
		"body_bounce_restitution",
		Settings.CHARACTER_Q3_N_FLIGHT,
	)
	body_bounce_max_speed = Settings.get_controller_setting(
		"body_bounce_max_speed",
		Settings.CHARACTER_Q3_N_FLIGHT,
	)
	landing_carry_enabled = Settings.get_controller_setting(
		"landing_carry",
		Settings.CHARACTER_Q3_N_FLIGHT,
	) >= 0.5
	landing_friction_multiplier = Settings.get_controller_setting(
		"landing_friction_multiplier",
		Settings.CHARACTER_Q3_N_FLIGHT,
	)
	landing_carry_duration = Settings.get_controller_setting(
		"landing_carry_duration",
		Settings.CHARACTER_Q3_N_FLIGHT,
	)
	landing_carry_min_speed = Settings.get_controller_setting(
		"landing_carry_min_speed",
		Settings.CHARACTER_Q3_N_FLIGHT,
	)
	hard_landing_vertical_speed = Settings.get_controller_setting(
		"hard_landing_vertical_speed",
		Settings.CHARACTER_Q3_N_FLIGHT,
	)
	var settings_first_person := Settings.get_controller_setting(
		"first_person",
		Settings.CHARACTER_Q3_N_FLIGHT,
	) >= 0.5
	var settings_third_person := Settings.get_controller_setting(
		"third_person",
		Settings.CHARACTER_Q3_N_FLIGHT,
	) >= 0.5
	_apply_shared_camera_mode(settings_first_person or not settings_third_person)


func _apply_shared_camera_mode(first_person: bool) -> void:
	first_person_camera_enabled = first_person
	q3_motor.third_person_enabled = not first_person
	flight_motor.first_person_enabled = first_person
	_apply_player_body_cull_masks()


func _handle_camera_actions() -> void:
	if KeybindingsSettings.is_action_just_pressed(&"player_reset_camera"):
		recenter_camera()
	if KeybindingsSettings.is_action_just_pressed(&"player_toggle_camera"):
		toggle_camera_mode()


func _get_movement_state_snapshot() -> Dictionary:
	var mode_name := "flight" if mode == Mode.FLIGHT else "q3"
	var grounded := is_on_floor()
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	var slick_sliding: bool = mode == Mode.Q3 and grounded and q3_motor.floor_is_slick and horizontal_speed > 0.05
	return {
		"controller": mode_name,
		"mode": mode_name,
		"position": global_position,
		"velocity": velocity,
		"body_basis": global_basis,
		"facing_direction": -global_basis.z,
		"look_direction": get_view_direction(),
		"intended_movement_direction": q3_motor.intended_movement_direction if mode == Mode.Q3 else Vector3.ZERO,
		"intended_movement_magnitude": q3_motor.intended_movement_magnitude if mode == Mode.Q3 else 0.0,
		"grounded": grounded,
		"swimming": q3_motor.water_level > 1,
		"water_level": q3_motor.water_level,
		"water_type": q3_motor.water_type,
		"crouching": q3_motor.is_crouching,
		"crouch_sliding": q3_motor.is_crouch_sliding,
		"sliding": q3_motor.is_crouch_sliding or slick_sliding,
		"wall_contact": is_on_wall(),
		"ceiling_contact": is_on_ceiling(),
		"flight_activation_charging": mode == Mode.Q3 and flap_hold_time > 0.0,
		"flight_activation_charge": flap_hold_time,
		"flight_activation_threshold": flight_hold_threshold,
		"gliding": mode == Mode.FLIGHT,
		"knocked_down": _is_knocked_down(),
		"crash_recovery_time_remaining": knockdown_time_remaining,
	}


func _record_landing_and_preserve(impact_velocity: Vector3, impact: Dictionary) -> void:
	if impact.is_empty():
		return
	movement_state.record_landing(impact_velocity, impact, _get_landing_carry_config())
	movement_state.apply_landing_carry_preservation(self, impact_velocity, _get_landing_carry_config())


func _get_floor_impact(impact_velocity: Vector3) -> Dictionary:
	return movement_state.get_floor_collision_impact(
		self,
		impact_velocity,
		cos(floor_max_angle),
		_get_surface_type(),
	)


func _get_surface_type() -> StringName:
	if q3_motor.water_level > 0:
		return q3_motor.water_type
	if q3_motor.floor_is_slick:
		return &"slick"
	return &"ground"


func _get_landing_carry_config() -> Dictionary:
	return {
		"enabled": landing_carry_enabled,
		"duration": landing_carry_duration,
		"min_speed": landing_carry_min_speed,
		"hard_landing_vertical_speed": hard_landing_vertical_speed,
	}


func _update_flap_hold(delta: float) -> void:
	if _is_knocked_down():
		flap_hold_time = 0.0
		return
	if Input.is_action_pressed("player_flap"):
		flap_hold_time += delta
	else:
		flap_hold_time = 0.0


func _update_no_surface_contact_time(delta: float) -> void:
	if _is_touching_surface():
		no_surface_contact_time = 0.0
	else:
		no_surface_contact_time += delta


func _can_activate_flight() -> bool:
	return (
		not _is_knocked_down()
		and flap_hold_time >= flight_hold_threshold
		and no_surface_contact_time >= flight_no_contact_threshold
		and velocity.length() >= flight_min_activation_speed
	)


func _is_touching_surface() -> bool:
	return is_on_floor() or is_on_wall() or is_on_ceiling() or get_slide_collision_count() > 0


func _is_knocked_down() -> bool:
	return knockdown_time_remaining > 0.0


func _update_knockdown_timer(delta: float) -> void:
	if knockdown_time_remaining <= 0.0:
		return
	knockdown_time_remaining = maxf(knockdown_time_remaining - delta, 0.0)
	if knockdown_time_remaining <= 0.0:
		q3_motor.control_enabled = true


func _get_body_bounce_impact(impact_velocity: Vector3) -> Dictionary:
	if not body_bounce_enabled:
		return {}
	var strongest_speed := body_bounce_min_normal_speed
	var strongest_normal := Vector3.ZERO
	for collision_index in get_slide_collision_count():
		var normal := get_slide_collision(collision_index).get_normal().normalized()
		var normal_speed := maxf(0.0, -impact_velocity.dot(normal))
		if normal_speed > strongest_speed:
			strongest_speed = normal_speed
			strongest_normal = normal
	if strongest_normal == Vector3.ZERO:
		return {}
	return {
		"normal": strongest_normal,
		"speed": strongest_speed,
	}


func _get_body_bounce_velocity(impact_velocity: Vector3, normal: Vector3) -> Vector3:
	var normalized_normal := normal.normalized()
	var reflected := impact_velocity - (2.0 * impact_velocity.dot(normalized_normal) * normalized_normal)
	var bounced_velocity := reflected * body_bounce_restitution
	if body_bounce_max_speed > 0.0 and bounced_velocity.length() > body_bounce_max_speed:
		return bounced_velocity.normalized() * body_bounce_max_speed
	return bounced_velocity


func _start_knockdown() -> void:
	knockdown_time_remaining = maxf(body_bounce_knockdown_duration, 0.0)
	q3_motor.control_enabled = not _is_knocked_down()
	flap_hold_time = 0.0
	no_surface_contact_time = 0.0
	_update_knockdown_hud()


func _update_knockdown_hud() -> void:
	if q3_hud != null:
		q3_hud.set_knockdown_time(knockdown_time_remaining)


func _enter_flight() -> void:
	if mode == Mode.FLIGHT:
		return
	var previous_camera := get_view_camera()
	var previous_view_transform := previous_camera.global_transform
	var previous_view_fov := previous_camera.fov
	var preserved_velocity := velocity
	var preserved_position := global_position
	var view_transform := previous_view_transform
	var flight_basis := _get_takeoff_flight_basis(view_transform.basis, preserved_velocity)
	var entering_from_flap_hold := Input.is_action_pressed("player_flap")
	var view_euler := view_transform.basis.get_euler()
	if _body_would_overlap_with_basis(flight_basis):
		flight_basis = Basis(Vector3.UP, view_euler.y).orthonormalized()
	global_basis = flight_basis
	global_position = preserved_position
	flight_motor.camera_yaw = view_euler.y
	flight_motor.camera_pitch = clampf(
		view_euler.x,
		deg_to_rad(-75.0),
		deg_to_rad(60.0),
	)
	velocity = preserved_velocity
	mode = Mode.FLIGHT
	movement_state.record_entered_flight()
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	floor_snap_length = 0.0
	flap_hold_time = 0.0
	flight_motor._apply_camera_rotation()
	flight_motor._update_aero_angles()
	_set_flight_visuals()
	_begin_camera_transition(previous_view_transform, previous_view_fov, flight_motor.get_view_camera())
	if entering_from_flap_hold:
		Input.action_release("player_flap")


func _get_takeoff_flight_basis(view_basis: Basis, takeoff_velocity: Vector3) -> Basis:
	var horizontal_forward := -view_basis.orthonormalized().z
	horizontal_forward.y = 0.0
	if horizontal_forward.length_squared() <= 0.0001:
		horizontal_forward = Vector3(takeoff_velocity.x, 0.0, takeoff_velocity.z)
	if horizontal_forward.length_squared() <= 0.0001:
		horizontal_forward = -global_basis.z
		horizontal_forward.y = 0.0
	if horizontal_forward.length_squared() <= 0.0001:
		horizontal_forward = Vector3.FORWARD
	horizontal_forward = horizontal_forward.normalized()

	var right_axis := horizontal_forward.cross(Vector3.UP).normalized()
	var velocity_in_pitch_plane := takeoff_velocity - (right_axis * takeoff_velocity.dot(right_axis))
	var forward_axis := horizontal_forward
	var forward_speed := velocity_in_pitch_plane.dot(horizontal_forward)
	if velocity_in_pitch_plane.length_squared() > 0.0001 and forward_speed > 0.0001:
		var pitch := atan2(velocity_in_pitch_plane.y, forward_speed)
		pitch = clampf(pitch, -TAKEOFF_FLIGHT_MAX_PITCH_DOWN, TAKEOFF_FLIGHT_MAX_PITCH_UP)
		forward_axis = ((horizontal_forward * cos(pitch)) + (Vector3.UP * sin(pitch))).normalized()
	var up_axis := right_axis.cross(forward_axis).normalized()
	return Basis(right_axis, up_axis, -forward_axis).orthonormalized()


func _sync_q3_body_size_to_flight() -> void:
	q3_motor.set_character_size(FLIGHT_COLLISION_SIZE)


func _body_would_overlap_with_basis(candidate_basis: Basis) -> bool:
	if not is_inside_tree():
		return false
	var original_basis := global_basis
	global_basis = candidate_basis
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = collision_shape.shape
	query.transform = collision_shape.global_transform
	query.collision_mask = collision_mask
	query.exclude = [get_rid()]
	query.margin = safe_margin
	var overlaps := not get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()
	global_basis = original_basis
	return overlaps


func _enter_q3(snap_upright: bool) -> void:
	var should_blend_camera := mode == Mode.FLIGHT
	var previous_camera := get_view_camera()
	var previous_view_transform := previous_camera.global_transform
	var previous_view_fov := previous_camera.fov
	var preserved_velocity := velocity
	if snap_upright:
		var upright_yaw := _get_upright_yaw()
		rotation = Vector3(0.0, upright_yaw, 0.0)
		q3_motor.yaw = upright_yaw
		q3_motor.pitch = clampf(
			flight_motor.camera_pitch,
			deg_to_rad(-89.0),
			deg_to_rad(89.0),
		)
		head.rotation = Vector3(q3_motor.pitch, 0.0, 0.0)
	velocity = preserved_velocity
	mode = Mode.Q3
	if should_blend_camera:
		movement_state.record_exited_flight()
	motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED
	q3_motor.control_enabled = not _is_knocked_down()
	floor_stop_on_slope = false
	floor_max_angle = deg_to_rad(q3_motor.max_slope_angle)
	floor_snap_length = q3_motor.step_height
	flap_hold_time = 0.0
	no_surface_contact_time = 0.0
	_set_q3_visuals()
	if should_blend_camera:
		_begin_camera_transition(previous_view_transform, previous_view_fov, _get_q3_view_camera())


func _set_q3_visuals() -> void:
	_cancel_camera_transition()
	q3_motor.set_force_vector_debug_active(true)
	flight_motor.set_view_active(false)
	flight_hud.visible = false
	_get_q3_view_camera().current = true
	character_collider_visual.visible = q3_motor.character_collider_visible and q3_motor.third_person_enabled
	_update_knockdown_hud()
	_apply_presentation_state()
	_apply_debug_hud_visibility()


func _set_flight_visuals() -> void:
	_cancel_camera_transition()
	flight_hud.visible = true
	camera.current = false
	third_person_camera.current = false
	q3_motor.set_force_vector_debug_active(false)
	flight_motor.set_view_active(true)
	character_collider_visual.visible = false
	_apply_presentation_state()
	_apply_debug_hud_visibility()


func _get_q3_view_camera() -> Camera3D:
	if q3_motor.third_person_enabled:
		return third_person_camera
	return camera


func _begin_camera_transition(from_transform: Transform3D, from_fov: float, target_camera: Camera3D) -> void:
	if target_camera == null or CAMERA_TRANSITION_DURATION <= 0.0:
		if target_camera != null:
			target_camera.current = true
		return
	camera_transition_from_transform = from_transform
	camera_transition_from_fov = from_fov
	camera_transition_target = target_camera
	camera_transition_elapsed = 0.0
	camera_transition_active = true
	transition_camera.global_transform = from_transform
	transition_camera.fov = from_fov
	_apply_player_body_cull_mask(transition_camera)
	transition_camera.current = true


func _cancel_camera_transition() -> void:
	camera_transition_active = false
	camera_transition_target = null
	if transition_camera != null:
		transition_camera.current = false


func _update_camera_transition(delta: float) -> void:
	if not camera_transition_active:
		return
	if camera_transition_target == null:
		_cancel_camera_transition()
		return
	camera_transition_elapsed += delta
	var raw_weight := clampf(camera_transition_elapsed / CAMERA_TRANSITION_DURATION, 0.0, 1.0)
	var weight := smoothstep(0.0, 1.0, raw_weight)
	var target_transform := camera_transition_target.global_transform
	var blended_origin := camera_transition_from_transform.origin.lerp(target_transform.origin, weight)
	var blended_basis := camera_transition_from_transform.basis.slerp(target_transform.basis, weight).orthonormalized()
	transition_camera.global_transform = Transform3D(blended_basis, blended_origin)
	transition_camera.fov = lerpf(camera_transition_from_fov, camera_transition_target.fov, weight)
	if raw_weight >= 1.0:
		var final_camera := camera_transition_target
		_cancel_camera_transition()
		final_camera.current = true


func _get_upright_yaw() -> float:
	var forward := Vector3(velocity.x, 0.0, velocity.z)
	if forward.length_squared() <= 0.0001:
		forward = -global_basis.z
		forward.y = 0.0
	if forward.length_squared() <= 0.0001:
		return rotation.y
	forward = forward.normalized()
	return atan2(-forward.x, -forward.z)


func _get_q3_eye_height() -> float:
	return (
		q3_motor.character_size.y
		* Q3_MOVEMENT_MOTOR.Q3_STANDING_EYE_HEIGHT
		/ Q3_MOVEMENT_MOTOR.Q3_STANDING_HULL_HEIGHT
	)


func _apply_presentation_state() -> void:
	if presentation_enabled:
		return
	character_collider_visual.visible = false
	flight_body_mesh.visible = false
	disable_internal_cameras()


func _apply_debug_hud_visibility() -> void:
	q3_hud.visible = debug_hud_visible
	if mode == Mode.FLIGHT:
		flight_hud.visible = debug_hud_visible
	else:
		flight_hud.visible = false


func _find_cameras(root: Node) -> Array[Camera3D]:
	var cameras: Array[Camera3D] = []
	_append_cameras(root, cameras)
	return cameras


func _append_cameras(root: Node, cameras: Array[Camera3D]) -> void:
	if root is Camera3D:
		cameras.append(root as Camera3D)
	for child in root.get_children():
		_append_cameras(child, cameras)


func _apply_player_body_cull_mask(target_camera: Camera3D) -> void:
	if target_camera == null or player_body_render_layer <= 0:
		return
	target_camera.set_cull_mask_value(player_body_render_layer, not first_person_camera_enabled)


func _apply_player_body_cull_masks() -> void:
	if player_body_render_layer <= 0:
		return
	for target_camera in _find_cameras(self):
		_apply_player_body_cull_mask(target_camera)

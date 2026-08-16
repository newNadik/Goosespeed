class_name GooseVisualController
extends Node3D


class JumpSecondaryMotionApplier:
	extends Node

	var visual_controller: GooseVisualController


	func _process(delta: float) -> void:
		if visual_controller != null:
			visual_controller._update_jump_secondary_motion(delta)


const MovementStateScript := preload("res://scripts/player/movement_state.gd")
const HeadLookControllerScript := preload("res://scripts/player/goose_head_look_controller.gd")
const FLAP_SOUND := preload("res://assets/sounds/wing-flap.mp3")

const ANIM_JUMP := &"Goose|A A_Jump"
const ANIM_JUMP_2 := &"Goose|A A_Jump_2"
const ANIM_JUMP_3 := &"Goose|A A_Jump_3"
const ANIM_IDLE := &"Goose|A A_StandStraight_Idle1"
const ANIM_IDLE_ALT := &"Goose|A_StandStraight_Breathing"
const ANIM_WALK_SLOW := &"Goose|A_WalkSlow"
const ANIM_WALK_MEDIUM := &"Goose|A_WalkMedium"
const ANIM_WALK_FAST := &"Goose|A_WalkFast"
const ANIM_RUN_SLOW := &"Goose|A_RunSlow"
const ANIM_RUN_FAST := &"Goose|A_RunFast"
const ANIM_SWIM_STEADY := &"Goose|A_SwimSteady_1"
const ANIM_SWIM_DIVE := &"Goose|A_SwimSteady_3"
const ANIM_SWIM_UP := &"Goose|A_SwimSteady_4"
const ANIM_SWIM_TAKEOFF := &"Goose|A_SwimSteady_5"
const ANIM_SWIM_MOVE := &"Goose|A_SwimMove"
const ANIM_SWIM_MEDIUM := &"Goose|A_SwimMoveMedium"
const ANIM_SWIM_FAST := &"Goose|A_SwimMoveFast"
const ANIM_FLY_FLAP := &"Goose|A_FlyFlapping"
const ANIM_FLY_GLIDE := &"Goose|A_FlyGliding"
const ANIM_PRE_LAND := &"Goose|A_Landing_PreLanding"
const ANIM_LAND := &"Goose|A_Landing_Touch"
const ANIM_TAKEOFF_BOUNCE := &"Goose|A_TakeOff_BounceOff"
const ANIM_TAKEOFF_RUNUP := &"Goose|A_TakeOff_RunUp"
const ANIM_SLIDE := &"Goose|A_Sliding"
const JUMP_SECONDARY_BONE_NAMES := [
	&"Chest",
	&"ArmL1",
	&"ArmR1",
	&"WingL_G1",
	&"WingR_G1",
]
const LOOPING_ANIMATIONS := [
	ANIM_IDLE,
	ANIM_IDLE_ALT,
	ANIM_WALK_SLOW,
	ANIM_WALK_MEDIUM,
	ANIM_WALK_FAST,
	ANIM_RUN_SLOW,
	ANIM_RUN_FAST,
	ANIM_SWIM_STEADY,
	ANIM_SWIM_UP,
	ANIM_SWIM_MOVE,
	ANIM_SWIM_MEDIUM,
	ANIM_SWIM_FAST,
	ANIM_FLY_FLAP,
	ANIM_FLY_GLIDE,
	ANIM_TAKEOFF_RUNUP,
]

@export var animation_blend_time := 0.18
@export var idle_speed_threshold := 0.25
@export var q3_walk_fast_speed := 2.5
@export var q3_run_slow_speed := 4.0
@export var q3_run_fast_speed := 5.5
@export var q3_run_fast_exit_speed := 5.0
@export var run_fast_min_hold_time := 0.18
@export var locomotion_min_hold_time := 0.1
@export var locomotion_blend_time := 0.08
@export var run_fast_blend_time := 0.05
@export var flight_exit_blend_time := 0.4
@export var jump_blend_time := 0.1
@export var jump_exit_blend_time := 0.22
@export var jump_autohop_hold_time := 0.24
@export var landing_hold_time := 0.22
@export var prelanding_ground_distance := 2.5
@export_range(0.0, 1.0, 0.05) var takeoff_runup_charge_ratio := 0.7
@export var ground_input_turn_rate := 7.0
@export var default_turn_rate := 14.0
@export var input_facing_commit_time := 0.14
@export var visual_vertical_smoothness := 18.0
@export var swim_visual_y_offset := -0.30
@export var head_look_enabled := true
@export_range(0.0, 1.0, 0.05) var head_look_intensity := 0.65
@export var head_look_smoothness := 10.0
@export var jump_secondary_motion_enabled := true
@export_range(0.0, 1.5, 0.05) var jump_secondary_motion_intensity := 0.65
@export var flap_sound_enabled := true
@export var flap_sound_volume_db := -8.0
@export var flap_sound_min_pitch := 0.94
@export var flap_sound_max_pitch := 1.06

@onready var animation_player: AnimationPlayer = get_node_or_null("AnimationPlayer") as AnimationPlayer
@onready var skeleton: Skeleton3D = get_node_or_null("Goose/Skeleton3D") as Skeleton3D

var state_bridge: Node
var transform_source: Node3D
var latest_state := MovementStateScript.new()
var previous_grounded := true
var landing_hold_remaining := 0.0
var active_locomotion_animation: StringName = &""
var run_fast_hold_remaining := 0.0
var locomotion_hold_remaining := 0.0
var jump_visual_hold_remaining := 0.0
var jump_sequence_index := 0
var jump_takeoff_was_consumed := false
var intended_movement_time := 0.0
var tracked_intended_movement_direction := Vector3.ZERO
var jump_secondary_motion_controller: Node
var head_look_controller: Node
var smoothed_visual_y := 0.0
var visual_y_initialized := false
var jump_secondary_bone_indices: Dictionary = {}
var flap_sound_player: AudioStreamPlayer3D
var previous_flapping := false
var cutscene_idle_enabled := false


func _ready() -> void:
	_configure_animation_player()
	_cache_jump_secondary_bones()
	_ensure_flap_sound_player()
	_ensure_jump_secondary_motion_controller()
	_ensure_head_look_controller()
	if state_bridge:
		_connect_bridge()


func set_state_bridge(value: Node) -> void:
	if state_bridge and state_bridge.state_changed.is_connected(_on_state_changed):
		state_bridge.state_changed.disconnect(_on_state_changed)
	state_bridge = value
	if is_inside_tree() and state_bridge:
		_connect_bridge()


func set_transform_source(value: Node3D) -> void:
	transform_source = value
	if transform_source != null:
		global_position = transform_source.global_position
		_reset_visual_position_smoothing()
		if _uses_full_flight_orientation(latest_state):
			global_basis = _get_flight_visual_target_basis_for_basis(transform_source.global_basis)


func snap_to_transform_source() -> void:
	if transform_source == null:
		return
	global_position = transform_source.global_position
	global_basis = _get_flight_visual_target_basis_for_basis(transform_source.global_basis)
	tracked_intended_movement_direction = Vector3.ZERO
	intended_movement_time = 0.0
	_reset_visual_position_smoothing()


func set_cutscene_idle_enabled(value: bool) -> void:
	cutscene_idle_enabled = value
	if value:
		_clear_ground_locomotion()
		jump_visual_hold_remaining = 0.0
		landing_hold_remaining = 0.0
		if animation_player != null:
			_play_animation(_first_available([ANIM_IDLE, ANIM_IDLE_ALT]), 1.0)


func _process(delta: float) -> void:
	landing_hold_remaining = maxf(landing_hold_remaining - delta, 0.0)
	run_fast_hold_remaining = maxf(run_fast_hold_remaining - delta, 0.0)
	locomotion_hold_remaining = maxf(locomotion_hold_remaining - delta, 0.0)
	_update_jump_visual_state(delta)
	_update_animation()
	_update_head_look(delta)
	previous_grounded = latest_state.grounded


func _physics_process(delta: float) -> void:
	_update_intended_movement_turn_state(delta)
	_sync_visual_transform(delta)


func _sync_visual_transform(delta: float) -> void:
	global_position = _get_visual_position(delta)
	if _uses_full_flight_orientation(latest_state):
		global_basis = _get_flight_visual_target_basis_for_basis(_get_root_basis())
		return

	var visual_facing_direction := _get_visual_facing_direction(latest_state)
	if visual_facing_direction.is_zero_approx():
		return
	var target_yaw := atan2(-visual_facing_direction.x, -visual_facing_direction.z)
	global_rotation.y = lerp_angle(
		global_rotation.y,
		target_yaw,
		minf(delta * _get_visual_turn_rate(latest_state), 1.0),
	)
	global_rotation.x = lerp_angle(global_rotation.x, 0.0, minf(delta * default_turn_rate, 1.0))
	global_rotation.z = lerp_angle(global_rotation.z, 0.0, minf(delta * default_turn_rate, 1.0))


func _connect_bridge() -> void:
	if not state_bridge.state_changed.is_connected(_on_state_changed):
		state_bridge.state_changed.connect(_on_state_changed)
	latest_state = state_bridge.get_state()
	previous_flapping = latest_state.flapping
	global_position = latest_state.position
	_reset_visual_position_smoothing()
	if _uses_full_flight_orientation(latest_state):
		global_basis = _get_flight_visual_target_basis(latest_state)


func _on_state_changed(state: RefCounted) -> void:
	var next_state: RefCounted = state.duplicate_state()
	_update_flap_sound(next_state)
	latest_state = next_state


func _get_visual_facing_direction(state: RefCounted) -> Vector3:
	if _should_face_intended_movement(state):
		return _horizontal_direction(state.intended_movement_direction)
	return _horizontal_direction(state.facing_direction)


func _uses_full_flight_orientation(state: RefCounted) -> bool:
	return state.mode == &"flight"


func _get_flight_visual_target_basis(state: RefCounted) -> Basis:
	return _get_flight_visual_target_basis_for_basis(state.body_basis as Basis)


func _get_flight_visual_target_basis_for_basis(source_basis: Basis) -> Basis:
	var clean_basis := source_basis.orthonormalized()
	return clean_basis if _basis_is_finite(clean_basis) else Basis.IDENTITY


func _get_root_position() -> Vector3:
	if transform_source != null:
		return transform_source.global_position
	return latest_state.position


func _get_visual_position(delta: float) -> Vector3:
	var target_position := _get_root_position()
	if latest_state.swimming:
		target_position.y += swim_visual_y_offset
	if not _should_smooth_visual_position(latest_state):
		_set_smoothed_visual_y(target_position.y)
		return target_position
	if not visual_y_initialized:
		_set_smoothed_visual_y(target_position.y)
	else:
		smoothed_visual_y = _smooth_visual_y(smoothed_visual_y, target_position.y, delta)
	return Vector3(target_position.x, smoothed_visual_y, target_position.z)


func _should_smooth_visual_position(state: RefCounted) -> bool:
	return (
		state.mode != &"flight"
		and state.grounded
		and not state.swimming
		and not state.crashed
		and not state.knocked_down
		and not state.hard_landed
	)


func _set_smoothed_visual_y(value: float) -> void:
	smoothed_visual_y = value
	visual_y_initialized = true


func _reset_visual_position_smoothing() -> void:
	_set_smoothed_visual_y(_get_root_position().y)


func _smooth_visual_y(current_y: float, target_y: float, delta: float) -> float:
	var blend := 1.0 - exp(-maxf(visual_vertical_smoothness, 0.0) * delta)
	return lerpf(current_y, target_y, blend)


func _get_root_basis() -> Basis:
	if transform_source != null:
		return transform_source.global_basis
	return latest_state.body_basis as Basis


func _basis_is_finite(value: Basis) -> bool:
	return (
		is_finite(value.x.x)
		and is_finite(value.x.y)
		and is_finite(value.x.z)
		and is_finite(value.y.x)
		and is_finite(value.y.y)
		and is_finite(value.y.z)
		and is_finite(value.z.x)
		and is_finite(value.z.y)
		and is_finite(value.z.z)
	)


func _update_intended_movement_turn_state(delta: float) -> void:
	if not _has_ground_intended_movement(latest_state):
		intended_movement_time = 0.0
		tracked_intended_movement_direction = Vector3.ZERO
		return

	var intended_direction := _horizontal_direction(latest_state.intended_movement_direction)
	if (
		tracked_intended_movement_direction.is_zero_approx()
		or tracked_intended_movement_direction.dot(intended_direction) < 0.94
	):
		tracked_intended_movement_direction = intended_direction
		intended_movement_time = 0.0
	intended_movement_time += delta


func _should_face_intended_movement(state: RefCounted) -> bool:
	return _has_ground_intended_movement(state) and intended_movement_time >= input_facing_commit_time


func _has_ground_intended_movement(state: RefCounted) -> bool:
	return (
		state.mode != &"flight"
		and state.grounded
		and not state.swimming
		and state.intended_movement_magnitude > 0.05
		and not state.intended_movement_direction.is_zero_approx()
	)


func _get_visual_turn_rate(state: RefCounted) -> float:
	return ground_input_turn_rate if _should_face_intended_movement(state) else default_turn_rate


func _horizontal_direction(value: Vector3) -> Vector3:
	var result := Vector3(value.x, 0.0, value.z)
	return result.normalized() if not result.is_zero_approx() else Vector3.ZERO


func animation_for_state(state: RefCounted) -> StringName:
	return _animation_for_state(state, false)


func visual_state_for_state(state: RefCounted) -> StringName:
	if _should_use_landing_animation(state):
		return &"landing"
	if _should_use_prelanding_animation(state):
		return &"prelanding"
	if _should_use_flight_charge_animation(state) and not state.swimming:
		return &"takeoff_charge"
	if state.mode == &"flight":
		return &"flight_flap" if state.flapping else &"flight_glide"
	if state.swimming:
		if _should_use_flight_charge_animation(state):
			return &"swim_takeoff_charge"
		if _should_use_swim_dive_animation(state):
			return &"swim_dive"
		if _should_use_swim_up_animation(state):
			return &"swim_up"
		if state.horizontal_speed >= _run_slow_speed():
			return &"swim_fast"
		if state.horizontal_speed >= _walk_medium_speed():
			return &"swim"
		return &"swim_idle"
	if _should_use_jump_animation(state):
		return &"jump"
	if not state.grounded:
		if state.just_entered_flight:
			return &"takeoff"
		return _ground_visual_state_for_speed(state.horizontal_speed)
	if state.crouch_sliding or state.sliding:
		return &"slide"
	if state.horizontal_speed < idle_speed_threshold:
		return &"idle"
	if state.horizontal_speed < q3_run_slow_speed:
		return &"walk"
	return &"run"


func _animation_for_state(state: RefCounted, use_ground_stability: bool) -> StringName:
	if _should_use_landing_animation(state):
		if use_ground_stability:
			_clear_ground_locomotion()
		return _first_available([ANIM_LAND, ANIM_PRE_LAND, ANIM_IDLE])

	if _should_use_prelanding_animation(state):
		if use_ground_stability:
			_clear_ground_locomotion()
		return _first_available([ANIM_PRE_LAND, ANIM_RUN_SLOW, ANIM_WALK_FAST])

	if _should_use_flight_charge_animation(state) and not state.swimming:
		if use_ground_stability:
			_clear_ground_locomotion()
		return _first_available([ANIM_TAKEOFF_RUNUP, ANIM_RUN_FAST, ANIM_WALK_FAST])

	if state.mode == &"flight":
		if use_ground_stability:
			_clear_ground_locomotion()
		if state.flapping:
			return _first_available([ANIM_FLY_FLAP, ANIM_FLY_GLIDE])
		return _first_available([ANIM_FLY_GLIDE, ANIM_FLY_FLAP])

	if state.swimming:
		if use_ground_stability:
			_clear_ground_locomotion()
		if _should_use_flight_charge_animation(state):
			return _first_available([ANIM_SWIM_TAKEOFF, ANIM_SWIM_STEADY, ANIM_SWIM_MOVE])
		if _should_use_swim_dive_animation(state):
			return _first_available([ANIM_SWIM_DIVE, ANIM_SWIM_STEADY, ANIM_SWIM_MOVE])
		if _should_use_swim_up_animation(state):
			return _first_available([ANIM_SWIM_UP, ANIM_SWIM_STEADY, ANIM_SWIM_MOVE])
		if state.horizontal_speed >= _run_slow_speed():
			return _first_available([ANIM_SWIM_FAST, ANIM_SWIM_MEDIUM, ANIM_SWIM_MOVE])
		if state.horizontal_speed >= _walk_medium_speed():
			return _first_available([ANIM_SWIM_MEDIUM, ANIM_SWIM_MOVE])
		return _first_available([ANIM_SWIM_STEADY, ANIM_SWIM_MOVE])

	if _should_use_jump_animation(state):
		if use_ground_stability:
			_clear_ground_locomotion()
		return _first_available([_get_jump_animation(state), ANIM_JUMP, _ground_animation_for_speed(state.horizontal_speed)])

	if not state.grounded:
		if use_ground_stability:
			_clear_ground_locomotion()
		if state.just_entered_flight:
			return _first_available([ANIM_TAKEOFF_BOUNCE, ANIM_FLY_GLIDE])
		return _ground_animation_for_speed(state.horizontal_speed)

	if state.crouch_sliding or state.sliding:
		if use_ground_stability:
			_clear_ground_locomotion()
		var fallback_animation := _ground_slide_animation_for_speed(state.horizontal_speed)
		return _first_available([ANIM_SLIDE, fallback_animation])

	var candidate := _ground_animation_for_speed(state.horizontal_speed)
	if use_ground_stability:
		return _stable_ground_animation(candidate, state.horizontal_speed)
	return candidate


func _ground_animation_for_speed(horizontal_speed: float) -> StringName:
	if horizontal_speed < idle_speed_threshold:
		return _first_available([ANIM_IDLE, ANIM_IDLE_ALT])
	if horizontal_speed < q3_walk_fast_speed:
		return _first_available([ANIM_WALK_MEDIUM, ANIM_WALK_FAST])
	if horizontal_speed < q3_run_slow_speed:
		return _first_available([ANIM_WALK_FAST, ANIM_RUN_SLOW])
	if horizontal_speed < q3_run_fast_speed:
		return _first_available([ANIM_RUN_SLOW, ANIM_RUN_FAST, ANIM_WALK_FAST])
	return _first_available([ANIM_RUN_FAST, ANIM_RUN_SLOW, ANIM_WALK_FAST])


func _ground_visual_state_for_speed(horizontal_speed: float) -> StringName:
	if horizontal_speed < idle_speed_threshold:
		return &"idle"
	if horizontal_speed < q3_run_slow_speed:
		return &"walk"
	return &"run"


func _should_use_landing_animation(state: RefCounted) -> bool:
	return (
		state.crashed
		or state.knocked_down
		or state.hard_landed
		or (
			state.just_landed
			and (
				state.just_exited_flight
				or state.mode == &"flight"
			)
		)
	)


func _should_use_prelanding_animation(state: RefCounted) -> bool:
	return (
		state.mode != &"flight"
		and not state.grounded
		and not state.swimming
		and state.falling
		and state.ground_distance >= prelanding_ground_distance
	)


func _should_use_jump_animation(state: RefCounted) -> bool:
	if (
		state.mode == &"flight"
		or state.swimming
	):
		return false
	if state.just_took_off and state.takeoff_vertical_speed > 0.1:
		return true
	if (
		state.jump_held
		and jump_visual_hold_remaining > 0.0
		and state.takeoff_vertical_speed > 0.1
	):
		return true
	if state.grounded or state.falling or state.vertical_speed <= 0.1:
		return false
	return (
		animation_player != null
		and animation_player.current_animation == ANIM_JUMP
		and animation_player.is_playing()
	)


func _update_jump_visual_state(delta: float) -> void:
	if latest_state.mode == &"flight" or latest_state.swimming or not latest_state.jump_held:
		jump_visual_hold_remaining = 0.0
		if not latest_state.jump_held:
			jump_sequence_index = 0
		jump_takeoff_was_consumed = false
		return
	if latest_state.just_took_off and latest_state.takeoff_vertical_speed > 0.1:
		if not jump_takeoff_was_consumed:
			_advance_jump_sequence()
			jump_takeoff_was_consumed = true
		jump_visual_hold_remaining = jump_autohop_hold_time
		return
	jump_takeoff_was_consumed = false
	if (
		not latest_state.grounded
		and latest_state.takeoff_vertical_speed > 0.1
		and not _should_use_prelanding_animation(latest_state)
	):
		jump_visual_hold_remaining = jump_autohop_hold_time
		return
	jump_visual_hold_remaining = maxf(jump_visual_hold_remaining - delta, 0.0)


func _should_use_flight_charge_animation(state: RefCounted) -> bool:
	if not state.flight_activation_charging or state.mode == &"flight":
		return false
	var threshold := maxf(state.flight_activation_threshold, 0.0)
	if threshold <= 0.0:
		return true
	return state.flight_activation_charge >= threshold * clampf(takeoff_runup_charge_ratio, 0.0, 1.0)


func _should_use_swim_dive_animation(state: RefCounted) -> bool:
	return state.crouching and state.vertical_speed < -0.1


func _should_use_swim_up_animation(state: RefCounted) -> bool:
	return state.vertical_speed > 0.1 and state.water_level >= 2


func _ground_slide_animation_for_speed(horizontal_speed: float) -> StringName:
	if horizontal_speed >= _run_slow_speed():
		return _first_available([ANIM_RUN_FAST, ANIM_RUN_SLOW, ANIM_WALK_FAST])
	return _first_available([ANIM_WALK_FAST, ANIM_RUN_SLOW, ANIM_WALK_MEDIUM])


func _slide_has_player_input(state: RefCounted) -> bool:
	return (
		state.intended_movement_magnitude > 0.05
		and not state.intended_movement_direction.is_zero_approx()
	)


func _stable_ground_animation(candidate: StringName, horizontal_speed: float) -> StringName:
	if candidate == &"":
		return candidate
	if active_locomotion_animation == candidate:
		return candidate
	if (
		active_locomotion_animation == ANIM_RUN_FAST
		and candidate != ANIM_RUN_FAST
		and (horizontal_speed >= _run_fast_exit_speed() or run_fast_hold_remaining > 0.0)
	):
		return active_locomotion_animation
	if (
		_is_ground_locomotion(active_locomotion_animation)
		and _is_ground_locomotion(candidate)
		and locomotion_hold_remaining > 0.0
	):
		return active_locomotion_animation

	active_locomotion_animation = candidate
	run_fast_hold_remaining = run_fast_min_hold_time if candidate == ANIM_RUN_FAST else 0.0
	locomotion_hold_remaining = locomotion_min_hold_time if _is_ground_locomotion(candidate) else 0.0
	return candidate


func _clear_ground_locomotion() -> void:
	active_locomotion_animation = &""
	run_fast_hold_remaining = 0.0
	locomotion_hold_remaining = 0.0


func _configure_animation_player() -> void:
	if animation_player == null:
		return
	for animation_name in LOOPING_ANIMATIONS:
		if animation_player.has_animation(animation_name):
			animation_player.get_animation(animation_name).loop_mode = Animation.LOOP_LINEAR
	for animation_name in [ANIM_JUMP, ANIM_JUMP_2, ANIM_JUMP_3, ANIM_PRE_LAND, ANIM_TAKEOFF_BOUNCE, ANIM_SWIM_DIVE, ANIM_SWIM_TAKEOFF]:
		if animation_player.has_animation(animation_name):
			animation_player.get_animation(animation_name).loop_mode = Animation.LOOP_NONE
	if animation_player.has_animation(ANIM_LAND):
		animation_player.get_animation(ANIM_LAND).loop_mode = Animation.LOOP_NONE
	if animation_player.has_animation(ANIM_SLIDE):
		animation_player.get_animation(ANIM_SLIDE).loop_mode = Animation.LOOP_NONE


func _update_animation() -> void:
	if animation_player == null:
		return
	if cutscene_idle_enabled:
		_play_animation(_first_available([ANIM_IDLE, ANIM_IDLE_ALT]), 1.0)
		return
	var just_landed := latest_state.just_landed or (not previous_grounded and latest_state.grounded)
	if just_landed and _should_use_landing_animation(latest_state):
		landing_hold_remaining = landing_hold_time
	var next_animation := (
		_first_available([ANIM_LAND])
		if landing_hold_remaining > 0.0
		else _animation_for_state(latest_state, true)
	)
	if next_animation == &"":
		return
	_play_animation(next_animation, _animation_speed_scale(next_animation))


func _play_animation(animation_name: StringName, speed_scale: float) -> void:
	animation_player.speed_scale = speed_scale
	_configure_runtime_animation_loop(animation_name)
	if animation_player.current_animation == animation_name and animation_player.is_playing():
		return
	var preserve_locomotion_phase := _should_preserve_locomotion_phase(animation_name)
	var locomotion_phase := _current_animation_phase() if preserve_locomotion_phase else 0.0
	animation_player.play(animation_name, _blend_time_for_animation(animation_name))
	if preserve_locomotion_phase:
		var animation := animation_player.get_animation(animation_name)
		animation_player.seek(animation.length * locomotion_phase, true)


func _ensure_head_look_controller() -> void:
	head_look_controller = get_node_or_null("GooseHeadLookController")
	if head_look_controller == null:
		head_look_controller = HeadLookControllerScript.new()
		head_look_controller.name = "GooseHeadLookController"
		add_child(head_look_controller)
	head_look_controller.setup(self)


func _ensure_jump_secondary_motion_controller() -> void:
	jump_secondary_motion_controller = get_node_or_null("JumpSecondaryMotionApplier")
	if jump_secondary_motion_controller == null:
		var applier := JumpSecondaryMotionApplier.new()
		applier.name = "JumpSecondaryMotionApplier"
		applier.visual_controller = self
		jump_secondary_motion_controller = applier
		add_child(jump_secondary_motion_controller)
	elif jump_secondary_motion_controller is JumpSecondaryMotionApplier:
		(jump_secondary_motion_controller as JumpSecondaryMotionApplier).visual_controller = self


func _ensure_flap_sound_player() -> void:
	flap_sound_player = get_node_or_null("FlapSound") as AudioStreamPlayer3D
	if flap_sound_player == null:
		flap_sound_player = AudioStreamPlayer3D.new()
		flap_sound_player.name = "FlapSound"
		add_child(flap_sound_player)
	flap_sound_player.stream = FLAP_SOUND
	flap_sound_player.bus = "SFX"
	flap_sound_player.volume_db = flap_sound_volume_db
	flap_sound_player.unit_size = 6.0
	flap_sound_player.max_distance = 42.0


func _update_flap_sound(state: RefCounted) -> void:
	if _should_play_flap_sound(state):
		_play_flap_sound()
	previous_flapping = state.flapping


func _should_play_flap_sound(state: RefCounted) -> bool:
	return (
		flap_sound_enabled
		and state.mode == &"flight"
		and state.flapping
		and not previous_flapping
	)


func _play_flap_sound() -> void:
	if flap_sound_player == null:
		return
	flap_sound_player.pitch_scale = randf_range(flap_sound_min_pitch, flap_sound_max_pitch)
	flap_sound_player.play()


func _cache_jump_secondary_bones() -> void:
	jump_secondary_bone_indices.clear()
	if skeleton == null:
		return
	for bone_name in JUMP_SECONDARY_BONE_NAMES:
		var bone_index := skeleton.find_bone(String(bone_name))
		if bone_index >= 0:
			jump_secondary_bone_indices[bone_name] = bone_index


func _update_jump_secondary_motion(_delta: float) -> void:
	if not _should_apply_jump_secondary_motion(latest_state):
		return
	var phase := _current_animation_phase()
	var side := _jump_secondary_side_for_animation(animation_player.current_animation)
	var weight := _jump_secondary_motion_weight(latest_state)
	var hop := sin(TAU * phase)
	var hop_soft := sin(TAU * phase + 0.65)
	var settle := sin(TAU * phase + PI)
	var alternating_side := side if side != 0.0 else sin(TAU * phase)

	_apply_jump_secondary_rotation(
		&"Chest",
		Vector3(
			deg_to_rad(2.2) * settle,
			deg_to_rad(1.5) * alternating_side * hop_soft,
			deg_to_rad(2.2) * alternating_side * hop,
		) * weight,
	)
	_apply_jump_secondary_rotation(
		&"ArmL1",
		Vector3(
			deg_to_rad(1.7) * -hop_soft,
			deg_to_rad(2.4) * hop,
			deg_to_rad(1.9) * -alternating_side * settle,
		) * weight,
	)
	_apply_jump_secondary_rotation(
		&"ArmR1",
		Vector3(
			deg_to_rad(1.7) * -hop_soft,
			deg_to_rad(2.4) * -hop,
			deg_to_rad(1.9) * alternating_side * settle,
		) * weight,
	)
	_apply_jump_secondary_rotation(
		&"WingL_G1",
		Vector3(
			deg_to_rad(2.0) * -hop,
			deg_to_rad(1.5) * hop_soft,
			deg_to_rad(3.0) * -settle,
		) * weight,
	)
	_apply_jump_secondary_rotation(
		&"WingR_G1",
		Vector3(
			deg_to_rad(2.0) * -hop,
			deg_to_rad(1.5) * -hop_soft,
			deg_to_rad(3.0) * settle,
		) * weight,
	)
	if skeleton.has_method("force_update_all_bone_transforms"):
		skeleton.call("force_update_all_bone_transforms")


func _apply_jump_secondary_rotation(bone_name: StringName, euler: Vector3) -> void:
	var bone_index := int(jump_secondary_bone_indices.get(bone_name, -1))
	if bone_index < 0:
		return
	var pose_rotation := skeleton.get_bone_pose_rotation(bone_index)
	var offset := (
		Quaternion(Vector3.RIGHT, euler.x)
		* Quaternion(Vector3.UP, euler.y)
		* Quaternion(Vector3.BACK, euler.z)
	)
	skeleton.set_bone_pose_rotation(bone_index, (pose_rotation * offset).normalized())


func _should_apply_jump_secondary_motion(state: RefCounted) -> bool:
	return (
		jump_secondary_motion_enabled
		and skeleton != null
		and animation_player != null
		and animation_player.is_playing()
		and _is_jump_animation_name(animation_player.current_animation)
		and _is_jump_secondary_motion_state(state)
	)


func _is_jump_secondary_motion_state(state: RefCounted) -> bool:
	return (
		state.mode != &"flight"
		and not state.swimming
		and state.jump_held
		and jump_visual_hold_remaining > 0.0
		and state.takeoff_vertical_speed > 0.1
	)


func _jump_secondary_motion_weight(state: RefCounted) -> float:
	if not _is_jump_secondary_motion_state(state):
		return 0.0
	return clampf(jump_secondary_motion_intensity, 0.0, 1.5)


func _jump_secondary_side_for_animation(animation_name: StringName) -> float:
	if animation_name == ANIM_JUMP_2:
		return 1.0
	if animation_name == ANIM_JUMP_3:
		return -1.0
	return 0.0


func _update_head_look(_delta: float) -> void:
	if head_look_controller == null:
		return
	head_look_controller.enabled = head_look_enabled
	if not head_look_enabled:
		return
	head_look_controller.intensity = head_look_intensity
	head_look_controller.smoothness = head_look_smoothness
	head_look_controller.queue_look(latest_state, _get_head_look_basis(), get_viewport().get_camera_3d())


func _get_head_look_basis() -> Basis:
	if latest_state.mode == &"flight":
		return _get_root_basis().orthonormalized()
	return global_basis


func _animation_speed_scale(animation_name: StringName) -> float:
	if animation_name == ANIM_WALK_MEDIUM:
		return clampf(latest_state.horizontal_speed / q3_walk_fast_speed, 0.85, 1.25)
	if animation_name == ANIM_WALK_FAST:
		return clampf(latest_state.horizontal_speed / q3_walk_fast_speed, 1.0, 1.35)
	if animation_name == ANIM_RUN_SLOW:
		return clampf(latest_state.horizontal_speed / q3_run_slow_speed, 1.0, 1.35)
	if animation_name == ANIM_RUN_FAST:
		return clampf(latest_state.horizontal_speed / q3_run_fast_speed, 0.95, 1.25)
	if animation_name in [ANIM_SWIM_MOVE, ANIM_SWIM_MEDIUM, ANIM_SWIM_FAST]:
		return clampf(latest_state.horizontal_speed / _walk_medium_speed(), 0.75, 1.35)
	return 1.0


func _blend_time_for_animation(animation_name: StringName) -> float:
	if _is_flight_exit_locomotion_blend(animation_name):
		return maxf(flight_exit_blend_time, animation_blend_time)
	if _is_jump_exit_locomotion_blend(animation_name):
		return maxf(jump_exit_blend_time, animation_blend_time)
	if _is_jump_animation_name(animation_name):
		return minf(jump_blend_time, animation_blend_time)
	if animation_name == ANIM_RUN_FAST:
		return minf(run_fast_blend_time, animation_blend_time)
	if _is_ground_locomotion(animation_name):
		return minf(locomotion_blend_time, animation_blend_time)
	return animation_blend_time


func _is_flight_exit_locomotion_blend(next_animation: StringName) -> bool:
	return (
		latest_state.just_exited_flight
		and latest_state.mode != &"flight"
		and _is_flight_animation(animation_player.current_animation)
		and _is_ground_locomotion(next_animation)
	)


func _is_jump_exit_locomotion_blend(next_animation: StringName) -> bool:
	return (
		animation_player != null
		and _is_jump_animation_name(animation_player.current_animation)
		and _is_ground_locomotion(next_animation)
	)


func _configure_runtime_animation_loop(animation_name: StringName) -> void:
	if not _is_jump_animation_name(animation_name) or not animation_player.has_animation(animation_name):
		return
	var animation := animation_player.get_animation(animation_name)
	animation.loop_mode = (
		Animation.LOOP_LINEAR
		if _jump_should_loop(latest_state)
		else Animation.LOOP_NONE
	)


func _jump_should_loop(state: RefCounted) -> bool:
	return (
		state.jump_held
		and jump_visual_hold_remaining > 0.0
		and state.takeoff_vertical_speed > 0.1
	)


func _get_jump_animation(state: RefCounted) -> StringName:
	if not state.jump_held:
		return ANIM_JUMP
	if jump_sequence_index <= 1:
		return ANIM_JUMP
	return ANIM_JUMP_2 if jump_sequence_index % 2 == 0 else ANIM_JUMP_3


func _advance_jump_sequence() -> void:
	if latest_state.jump_held:
		jump_sequence_index += 1
	else:
		jump_sequence_index = 1


func _is_jump_animation_name(animation_name: StringName) -> bool:
	return animation_name in [ANIM_JUMP, ANIM_JUMP_2, ANIM_JUMP_3]


func _is_flight_animation(animation_name: StringName) -> bool:
	return animation_name in [ANIM_FLY_FLAP, ANIM_FLY_GLIDE]


func _is_ground_locomotion(animation_name: StringName) -> bool:
	return animation_name in [
		ANIM_WALK_SLOW,
		ANIM_WALK_MEDIUM,
		ANIM_WALK_FAST,
		ANIM_RUN_SLOW,
		ANIM_RUN_FAST,
	]


func _should_preserve_locomotion_phase(next_animation: StringName) -> bool:
	return (
		animation_player != null
		and _is_ground_locomotion(animation_player.current_animation)
		and _is_ground_locomotion(next_animation)
	)


func _current_animation_phase() -> float:
	if animation_player == null:
		return 0.0
	if animation_player.current_animation_length <= 0.0:
		return 0.0
	return fposmod(
		animation_player.current_animation_position / animation_player.current_animation_length,
		1.0,
	)


func _walk_medium_speed() -> float:
	return q3_walk_fast_speed


func _run_slow_speed() -> float:
	return q3_run_slow_speed


func _run_fast_exit_speed() -> float:
	return q3_run_fast_exit_speed


func _first_available(animation_names: Array) -> StringName:
	if animation_player == null:
		return animation_names[0] if not animation_names.is_empty() else &""
	for animation_name in animation_names:
		if animation_player.has_animation(animation_name):
			return animation_name
	return &""

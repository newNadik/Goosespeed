class_name GooseVisualController
extends Node3D

const MovementStateScript := preload("res://scripts/player/movement_state.gd")

const ANIM_IDLE := &"Goose|A A_StandStraight_Idle1"
const ANIM_IDLE_ALT := &"Goose|A_StandStraight_Breathing"
const ANIM_WALK_SLOW := &"Goose|A_WalkSlow"
const ANIM_WALK_MEDIUM := &"Goose|A_WalkMedium"
const ANIM_WALK_FAST := &"Goose|A_WalkFast"
const ANIM_RUN_SLOW := &"Goose|A_RunSlow"
const ANIM_RUN_FAST := &"Goose|A_RunFast"
const ANIM_SWIM_STEADY := &"Goose|A_SwimSteady_1"
const ANIM_SWIM_MOVE := &"Goose|A_SwimMove"
const ANIM_SWIM_MEDIUM := &"Goose|A_SwimMoveMedium"
const ANIM_SWIM_FAST := &"Goose|A_SwimMoveFast"
const ANIM_FLY_FLAP := &"Goose|A_FlyFlapping"
const ANIM_FLY_GLIDE := &"Goose|A_FlyGliding"
const ANIM_PRE_LAND := &"Goose|A_Landing_PreLanding"
const ANIM_LAND := &"Goose|A_Landing_Touch"
const ANIM_TAKEOFF_BOUNCE := &"Goose|A_TakeOff_BounceOff"
const ANIM_TAKEOFF_RUNUP := &"Goose|A_TakeOff_RunUp"
const LOOPING_ANIMATIONS := [
	ANIM_IDLE,
	ANIM_IDLE_ALT,
	ANIM_WALK_SLOW,
	ANIM_WALK_MEDIUM,
	ANIM_WALK_FAST,
	ANIM_RUN_SLOW,
	ANIM_RUN_FAST,
	ANIM_SWIM_STEADY,
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
@export var landing_hold_time := 0.22
@export var prelanding_vertical_speed := -8.0
@export var ground_input_turn_rate := 7.0
@export var default_turn_rate := 14.0
@export var input_facing_commit_time := 0.14

@onready var animation_player: AnimationPlayer = get_node_or_null("AnimationPlayer") as AnimationPlayer

var state_bridge: Node
var latest_state := MovementStateScript.new()
var previous_grounded := true
var landing_hold_remaining := 0.0
var active_locomotion_animation: StringName = &""
var run_fast_hold_remaining := 0.0
var locomotion_hold_remaining := 0.0
var intended_movement_time := 0.0
var tracked_intended_movement_direction := Vector3.ZERO


func _ready() -> void:
	_configure_animation_player()
	if state_bridge:
		_connect_bridge()


func set_state_bridge(value: Node) -> void:
	if state_bridge and state_bridge.state_changed.is_connected(_on_state_changed):
		state_bridge.state_changed.disconnect(_on_state_changed)
	state_bridge = value
	if is_inside_tree() and state_bridge:
		_connect_bridge()


func _process(delta: float) -> void:
	landing_hold_remaining = maxf(landing_hold_remaining - delta, 0.0)
	run_fast_hold_remaining = maxf(run_fast_hold_remaining - delta, 0.0)
	locomotion_hold_remaining = maxf(locomotion_hold_remaining - delta, 0.0)
	_update_intended_movement_turn_state(delta)

	global_position = global_position.lerp(latest_state.position, minf(delta * 20.0, 1.0))
	var visual_facing_direction := _get_visual_facing_direction(latest_state)
	if not visual_facing_direction.is_zero_approx():
		var target_yaw := atan2(-visual_facing_direction.x, -visual_facing_direction.z)
		global_rotation.y = lerp_angle(
			global_rotation.y,
			target_yaw,
			minf(delta * _get_visual_turn_rate(latest_state), 1.0),
		)

	_update_animation()
	previous_grounded = latest_state.grounded


func _connect_bridge() -> void:
	if not state_bridge.state_changed.is_connected(_on_state_changed):
		state_bridge.state_changed.connect(_on_state_changed)
	latest_state = state_bridge.get_state()


func _on_state_changed(state: RefCounted) -> void:
	latest_state = state


func _get_visual_facing_direction(state: RefCounted) -> Vector3:
	if _should_face_intended_movement(state):
		return _horizontal_direction(state.intended_movement_direction)
	return _horizontal_direction(state.facing_direction)


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
	if state.crashed or state.knocked_down or state.hard_landed or state.just_landed:
		return &"landing"
	if state.swimming:
		if state.horizontal_speed >= _run_slow_speed():
			return &"swim_fast"
		if state.horizontal_speed >= _walk_medium_speed():
			return &"swim"
		return &"swim_idle"
	if state.flight_activation_charging and state.grounded:
		return &"takeoff_charge"
	if state.mode == &"flight":
		return &"flight_flap" if state.flapping else &"flight_glide"
	if not state.grounded:
		if state.flapping:
			return &"air_flap"
		if state.just_entered_flight:
			return &"takeoff"
		if state.falling and state.vertical_speed <= prelanding_vertical_speed:
			return &"prelanding"
		return &"air_glide"
	if state.crouch_sliding or state.sliding:
		return &"slide"
	if state.horizontal_speed < idle_speed_threshold:
		return &"idle"
	if state.horizontal_speed < q3_run_slow_speed:
		return &"walk"
	return &"run"


func _animation_for_state(state: RefCounted, use_ground_stability: bool) -> StringName:
	if state.crashed or state.knocked_down or state.hard_landed or state.just_landed:
		if use_ground_stability:
			_clear_ground_locomotion()
		return _first_available([ANIM_LAND, ANIM_PRE_LAND, ANIM_IDLE])

	if state.swimming:
		if use_ground_stability:
			_clear_ground_locomotion()
		if state.horizontal_speed >= _run_slow_speed():
			return _first_available([ANIM_SWIM_FAST, ANIM_SWIM_MEDIUM, ANIM_SWIM_MOVE])
		if state.horizontal_speed >= _walk_medium_speed():
			return _first_available([ANIM_SWIM_MEDIUM, ANIM_SWIM_MOVE])
		return _first_available([ANIM_SWIM_STEADY, ANIM_SWIM_MOVE])

	if state.flight_activation_charging and state.grounded:
		if use_ground_stability:
			_clear_ground_locomotion()
		return _first_available([ANIM_TAKEOFF_RUNUP, ANIM_RUN_FAST, ANIM_WALK_FAST])

	if state.mode == &"flight":
		if use_ground_stability:
			_clear_ground_locomotion()
		if state.flapping:
			return _first_available([ANIM_FLY_FLAP, ANIM_FLY_GLIDE])
		return _first_available([ANIM_FLY_GLIDE, ANIM_FLY_FLAP])

	if not state.grounded:
		if use_ground_stability:
			_clear_ground_locomotion()
		if state.flapping:
			return _first_available([ANIM_FLY_FLAP, ANIM_FLY_GLIDE])
		if state.just_entered_flight:
			return _first_available([ANIM_TAKEOFF_BOUNCE, ANIM_FLY_GLIDE])
		if state.falling and state.vertical_speed <= prelanding_vertical_speed:
			return _first_available([ANIM_PRE_LAND, ANIM_FLY_GLIDE])
		return _first_available([ANIM_FLY_GLIDE, ANIM_FLY_FLAP])

	if state.crouch_sliding or state.sliding:
		var slide_candidate := _ground_slide_animation_for_speed(state.horizontal_speed)
		if use_ground_stability:
			return _stable_ground_animation(slide_candidate, state.horizontal_speed)
		return slide_candidate

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


func _ground_slide_animation_for_speed(horizontal_speed: float) -> StringName:
	if horizontal_speed >= _run_slow_speed():
		return _first_available([ANIM_RUN_FAST, ANIM_RUN_SLOW, ANIM_WALK_FAST])
	return _first_available([ANIM_WALK_FAST, ANIM_RUN_SLOW, ANIM_WALK_MEDIUM])


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
	for animation_name in [ANIM_PRE_LAND, ANIM_TAKEOFF_BOUNCE]:
		if animation_player.has_animation(animation_name):
			animation_player.get_animation(animation_name).loop_mode = Animation.LOOP_NONE
	if animation_player.has_animation(ANIM_LAND):
		animation_player.get_animation(ANIM_LAND).loop_mode = Animation.LOOP_NONE


func _update_animation() -> void:
	if animation_player == null:
		return
	var just_landed := latest_state.just_landed or (not previous_grounded and latest_state.grounded)
	if just_landed:
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
	if animation_player.current_animation == animation_name and animation_player.is_playing():
		return
	var preserve_locomotion_phase := _should_preserve_locomotion_phase(animation_name)
	var locomotion_phase := _current_animation_phase() if preserve_locomotion_phase else 0.0
	animation_player.play(animation_name, _blend_time_for_animation(animation_name))
	if preserve_locomotion_phase:
		var animation := animation_player.get_animation(animation_name)
		animation_player.seek(animation.length * locomotion_phase, true)


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
	if animation_name == ANIM_RUN_FAST:
		return minf(run_fast_blend_time, animation_blend_time)
	if _is_ground_locomotion(animation_name):
		return minf(locomotion_blend_time, animation_blend_time)
	return animation_blend_time


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

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
const BACKEND_BASIC := "basic"
const BACKEND_Q3 := "q3"
const BACKEND_Q3_FLIGHT := "q3_n_flight"
const BACKEND_FLIGHT := "flight"
const BACKEND_PLATFORMER := "platformer"
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

@export var body_bob_amount := 0.08
@export var max_lean_degrees := 10.0
@export var animation_blend_time := 0.18
@export var idle_speed_threshold := 0.25
@export var walk_medium_speed := 4.5
@export var run_slow_speed := 6.5
@export var run_fast_speed := 8.0
@export var run_fast_exit_speed := 7.2
@export var q3_walk_fast_speed := 2.5
@export var q3_run_slow_speed := 4.0
@export var q3_run_fast_speed := 5.5
@export var q3_run_fast_exit_speed := 5.0
@export var run_fast_min_hold_time := 0.18
@export var locomotion_min_hold_time := 0.1
@export var locomotion_blend_time := 0.08
@export var run_fast_blend_time := 0.05
@export var airborne_flap_speed := 1.0
@export var flap_hold_time := 0.28
@export var landing_hold_time := 0.22
@export var prelanding_vertical_speed := -8.0

@onready var body: Node3D = get_node_or_null("Body") as Node3D
@onready var left_wing: Node3D = get_node_or_null("Body/LeftWing") as Node3D
@onready var right_wing: Node3D = get_node_or_null("Body/RightWing") as Node3D
@onready var neck: Node3D = get_node_or_null("Body/Neck") as Node3D
@onready var animation_player: AnimationPlayer = get_node_or_null("AnimationPlayer") as AnimationPlayer

var state_bridge: Node
var latest_state := MovementStateScript.new()
var previous_grounded := true
var flap_hold_remaining := 0.0
var landing_hold_remaining := 0.0
var active_locomotion_animation: StringName = &""
var run_fast_hold_remaining := 0.0
var locomotion_hold_remaining := 0.0
var movement_backend := BACKEND_PLATFORMER


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


func set_movement_backend(value: String) -> void:
	movement_backend = value
	_clear_ground_locomotion()


func _process(delta: float) -> void:
	flap_hold_remaining = maxf(flap_hold_remaining - delta, 0.0)
	landing_hold_remaining = maxf(landing_hold_remaining - delta, 0.0)
	run_fast_hold_remaining = maxf(run_fast_hold_remaining - delta, 0.0)
	locomotion_hold_remaining = maxf(locomotion_hold_remaining - delta, 0.0)
	if Input.is_action_just_pressed(&"player_flap") and _flap_input_can_animate():
		flap_hold_remaining = flap_hold_time
	if latest_state.just_entered_flight:
		flap_hold_remaining = flap_hold_time

	global_position = global_position.lerp(latest_state.position, minf(delta * 20.0, 1.0))
	if not latest_state.facing_direction.is_zero_approx():
		var target_yaw := atan2(-latest_state.facing_direction.x, -latest_state.facing_direction.z)
		global_rotation.y = lerp_angle(global_rotation.y, target_yaw, minf(delta * 14.0, 1.0))

	if body:
		var speed_scale := clampf(latest_state.horizontal_speed / 16.0, 0.0, 1.5)
		var bob := sin(Time.get_ticks_msec() * 0.018 * maxf(speed_scale, 0.2)) * body_bob_amount * speed_scale
		body.position.y = bob

		var lean := deg_to_rad(max_lean_degrees) * clampf(latest_state.velocity.y / 12.0, -1.0, 1.0)
		body.rotation.x = lerpf(body.rotation.x, -lean, minf(delta * 8.0, 1.0))

	var wing_target := 0.25
	if latest_state.gliding:
		wing_target = 1.1
	elif latest_state.flapping:
		wing_target = -0.75
	if left_wing:
		left_wing.rotation.z = lerp_angle(left_wing.rotation.z, wing_target, minf(delta * 12.0, 1.0))
	if right_wing:
		right_wing.rotation.z = lerp_angle(right_wing.rotation.z, -wing_target, minf(delta * 12.0, 1.0))
	if neck:
		var neck_target := -0.12 if latest_state.gliding or latest_state.falling else 0.08
		neck.rotation.x = lerpf(neck.rotation.x, neck_target, minf(delta * 8.0, 1.0))

	_update_animation()
	previous_grounded = latest_state.grounded


func _connect_bridge() -> void:
	if not state_bridge.state_changed.is_connected(_on_state_changed):
		state_bridge.state_changed.connect(_on_state_changed)
	latest_state = state_bridge.get_state()


func _on_state_changed(state: RefCounted) -> void:
	latest_state = state


func animation_for_state(state: RefCounted) -> StringName:
	return _animation_for_state(state, false)


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

	if state.just_entered_flight:
		if use_ground_stability:
			_clear_ground_locomotion()
		return _first_available([ANIM_FLY_FLAP, ANIM_TAKEOFF_BOUNCE, ANIM_FLY_GLIDE])

	if state.mode == &"flight":
		if use_ground_stability:
			_clear_ground_locomotion()
		if state.flapping or flap_hold_remaining > 0.0:
			return _first_available([ANIM_FLY_FLAP, ANIM_FLY_GLIDE])
		return _first_available([ANIM_FLY_GLIDE, ANIM_FLY_FLAP])

	if not state.grounded:
		if use_ground_stability:
			_clear_ground_locomotion()
		if state.flapping or flap_hold_remaining > 0.0:
			return _first_available([ANIM_FLY_FLAP, ANIM_FLY_GLIDE])
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
	if _uses_q3_thresholds():
		return _q3_ground_animation_for_speed(horizontal_speed)
	if horizontal_speed < idle_speed_threshold:
		return _first_available([ANIM_IDLE, ANIM_IDLE_ALT])
	if horizontal_speed < walk_medium_speed:
		return _first_available([ANIM_WALK_MEDIUM, ANIM_WALK_FAST, ANIM_WALK_SLOW])
	if horizontal_speed < run_slow_speed:
		return _first_available([ANIM_WALK_FAST, ANIM_RUN_SLOW])
	if horizontal_speed < run_fast_speed:
		return _first_available([ANIM_RUN_SLOW, ANIM_RUN_FAST, ANIM_WALK_FAST])
	return _first_available([ANIM_RUN_FAST, ANIM_RUN_SLOW, ANIM_WALK_FAST])


func _ground_slide_animation_for_speed(horizontal_speed: float) -> StringName:
	if horizontal_speed >= _run_slow_speed():
		return _first_available([ANIM_RUN_FAST, ANIM_RUN_SLOW, ANIM_WALK_FAST])
	return _first_available([ANIM_WALK_FAST, ANIM_RUN_SLOW, ANIM_WALK_MEDIUM])


func _q3_ground_animation_for_speed(horizontal_speed: float) -> StringName:
	if horizontal_speed < idle_speed_threshold:
		return _first_available([ANIM_IDLE, ANIM_IDLE_ALT])
	if horizontal_speed < q3_walk_fast_speed:
		return _first_available([ANIM_WALK_MEDIUM, ANIM_WALK_FAST])
	if horizontal_speed < q3_run_slow_speed:
		return _first_available([ANIM_WALK_FAST, ANIM_RUN_SLOW])
	if horizontal_speed < q3_run_fast_speed:
		return _first_available([ANIM_RUN_SLOW, ANIM_RUN_FAST, ANIM_WALK_FAST])
	return _first_available([ANIM_RUN_FAST, ANIM_RUN_SLOW, ANIM_WALK_FAST])


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
	if _uses_q3_thresholds():
		return _q3_animation_speed_scale(animation_name)
	if animation_name == ANIM_RUN_FAST:
		return clampf(latest_state.horizontal_speed / run_fast_speed, 0.9, 1.15)
	if animation_name in [ANIM_WALK_SLOW, ANIM_WALK_MEDIUM, ANIM_WALK_FAST, ANIM_RUN_SLOW, ANIM_RUN_FAST]:
		return clampf(latest_state.horizontal_speed / run_slow_speed, 0.75, 1.2)
	if animation_name in [ANIM_SWIM_MOVE, ANIM_SWIM_MEDIUM, ANIM_SWIM_FAST]:
		return clampf(latest_state.horizontal_speed / walk_medium_speed, 0.75, 1.35)
	return 1.0


func _q3_animation_speed_scale(animation_name: StringName) -> float:
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
	return q3_walk_fast_speed if _uses_q3_thresholds() else walk_medium_speed


func _run_slow_speed() -> float:
	return q3_run_slow_speed if _uses_q3_thresholds() else run_slow_speed


func _run_fast_exit_speed() -> float:
	return q3_run_fast_exit_speed if _uses_q3_thresholds() else run_fast_exit_speed


func _uses_q3_thresholds() -> bool:
	return movement_backend == BACKEND_Q3 or movement_backend == BACKEND_Q3_FLIGHT


func _flap_input_can_animate() -> bool:
	return latest_state.mode == &"flight" or not latest_state.grounded


func _first_available(animation_names: Array) -> StringName:
	if animation_player == null:
		return animation_names[0] if not animation_names.is_empty() else &""
	for animation_name in animation_names:
		if animation_player.has_animation(animation_name):
			return animation_name
	return &""

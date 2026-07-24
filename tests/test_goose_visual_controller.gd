extends SceneTree

const MovementStateScript := preload("res://scripts/player/movement_state.gd")
const VisualControllerScript := preload("res://scripts/player/goose_visual_controller.gd")
const HeadLookControllerScript := preload("res://scripts/player/goose_head_look_controller.gd")


func _initialize() -> void:
	var visual := VisualControllerScript.new()
	var failures: Array[String] = []

	_expect_animation(
		failures,
		visual,
		_state({"grounded": true, "horizontal_speed": 0.0}),
		VisualControllerScript.ANIM_IDLE,
		"idle",
	)
	_expect_animation(
		failures,
		visual,
		_state({"grounded": true, "horizontal_speed": 3.0}),
		VisualControllerScript.ANIM_WALK_FAST,
		"q3 crouch speed",
	)
	_expect_animation(
		failures,
		visual,
		_state({"grounded": true, "horizontal_speed": 6.1}),
		VisualControllerScript.ANIM_RUN_FAST,
		"q3 shift walk speed",
	)
	_expect_animation(
		failures,
		visual,
		_state({"grounded": true, "horizontal_speed": 12.2}),
		VisualControllerScript.ANIM_RUN_FAST,
		"q3 run speed",
	)
	_expect_sticky_run(failures, visual)
	_expect_locomotion_hold(failures, visual)
	_expect_q3_speed_scale(failures, visual)
	_expect_visual_facing_direction(failures, visual)
	_expect_head_look_angles(failures)
	_expect_transition_mapping(failures, visual)
	_expect_locomotion_phase_preserved(failures)
	_expect_animation(
		failures,
		visual,
		_state({"swimming": true, "horizontal_speed": 0.0}),
		VisualControllerScript.ANIM_SWIM_STEADY,
		"steady swim",
	)
	_expect_animation(
		failures,
		visual,
		_state({"swimming": true, "horizontal_speed": 13.0}),
		VisualControllerScript.ANIM_SWIM_FAST,
		"fast swim",
	)
	_expect_animation(
		failures,
		visual,
		_state({"grounded": false, "velocity": Vector3.UP * 2.0}),
		VisualControllerScript.ANIM_FLY_GLIDE,
		"upward jump without flap",
	)
	_expect_animation(
		failures,
		visual,
		_state({"grounded": false, "flapping": true, "velocity": Vector3.UP * 2.0}),
		VisualControllerScript.ANIM_FLY_FLAP,
		"explicit jump flap",
	)
	_expect_animation(
		failures,
		visual,
		_state({"grounded": false, "falling": true, "velocity": Vector3.DOWN}),
		VisualControllerScript.ANIM_FLY_GLIDE,
		"fall glide",
	)
	_expect_visual_state(
		failures,
		visual,
		_state({"grounded": true, "horizontal_speed": 0.0}),
		&"idle",
		"idle visual state",
	)
	_expect_visual_state(
		failures,
		visual,
		_state({"grounded": true, "horizontal_speed": 3.0}),
		&"walk",
		"walk visual state",
	)
	_expect_visual_state(
		failures,
		visual,
		_state({"grounded": true, "horizontal_speed": 6.0}),
		&"run",
		"run visual state",
	)
	_expect_visual_state(
		failures,
		visual,
		_state({"mode": &"flight", "grounded": false, "flapping": true}),
		&"flight_flap",
		"flight flap visual state",
	)
	_expect_visual_state(
		failures,
		visual,
		_state({"mode": &"flight", "grounded": false, "just_entered_flight": true, "flapping": true}),
		&"flight_flap",
		"flight flap beats entry visual state",
	)
	_expect_visual_state(
		failures,
		visual,
		_state({"grounded": false, "falling": true, "vertical_speed": -12.0}),
		&"prelanding",
		"prelanding visual state",
	)

	visual.free()

	if failures.is_empty():
		print("Goose visual controller OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _state(values: Dictionary) -> RefCounted:
	var state := MovementStateScript.new()
	for key in values:
		state.set(key, values[key])
	return state


func _expect_animation(
	failures: Array[String],
	visual: Node,
	state: RefCounted,
	expected: StringName,
	label: String
) -> void:
	var actual: StringName = visual.animation_for_state(state)
	if actual != expected:
		failures.append("%s selected %s, expected %s" % [label, actual, expected])


func _expect_visual_state(
	failures: Array[String],
	visual: Node,
	state: RefCounted,
	expected: StringName,
	label: String
) -> void:
	var actual: StringName = visual.visual_state_for_state(state)
	if actual != expected:
		failures.append("%s selected %s, expected %s" % [label, actual, expected])


func _expect_sticky_run(failures: Array[String], visual: Node) -> void:
	var run: StringName = visual._animation_for_state(
		_state({"grounded": true, "horizontal_speed": 8.5}),
		true,
	)
	if run != VisualControllerScript.ANIM_RUN_FAST:
		failures.append("stable selector entered %s, expected run fast" % run)
	var dip: StringName = visual._animation_for_state(
		_state({"grounded": true, "horizontal_speed": 4.8}),
		true,
	)
	if dip != VisualControllerScript.ANIM_RUN_FAST:
		failures.append("stable selector dipped to %s, expected sticky run fast" % dip)
	visual.run_fast_hold_remaining = 0.0
	visual.locomotion_hold_remaining = 0.0
	var exit: StringName = visual._animation_for_state(
		_state({"grounded": true, "horizontal_speed": 3.5}),
		true,
	)
	if exit != VisualControllerScript.ANIM_WALK_FAST:
		failures.append("stable selector exited to %s, expected walk fast" % exit)


func _expect_locomotion_hold(failures: Array[String], visual: Node) -> void:
	visual._clear_ground_locomotion()
	var medium: StringName = visual._animation_for_state(
		_state({"grounded": true, "horizontal_speed": 2.0}),
		true,
	)
	if medium != VisualControllerScript.ANIM_WALK_MEDIUM:
		failures.append("locomotion hold entered %s, expected walk medium" % medium)
	var held: StringName = visual._animation_for_state(
		_state({"grounded": true, "horizontal_speed": 3.0}),
		true,
	)
	if held != VisualControllerScript.ANIM_WALK_MEDIUM:
		failures.append("locomotion hold switched to %s, expected held walk medium" % held)
	visual.locomotion_hold_remaining = 0.0
	var released: StringName = visual._animation_for_state(
		_state({"grounded": true, "horizontal_speed": 3.0}),
		true,
	)
	if released != VisualControllerScript.ANIM_WALK_FAST:
		failures.append("locomotion hold released to %s, expected walk fast" % released)


func _expect_q3_speed_scale(failures: Array[String], visual: Node) -> void:
	visual.latest_state = _state({"grounded": true, "horizontal_speed": 3.0})
	var crouch_scale: float = visual._animation_speed_scale(VisualControllerScript.ANIM_WALK_FAST)
	if crouch_scale < 1.0:
		failures.append("q3 crouch speed scale %.3f should keep feet moving" % crouch_scale)
	visual.latest_state = _state({"grounded": true, "horizontal_speed": 6.1})
	var walk_scale: float = visual._animation_speed_scale(VisualControllerScript.ANIM_RUN_FAST)
	if walk_scale < 1.0:
		failures.append("q3 shift walk speed scale %.3f should keep feet moving" % walk_scale)


func _expect_visual_facing_direction(failures: Array[String], visual: Node) -> void:
	var input_state := _state({
		"grounded": true,
		"facing_direction": Vector3.FORWARD,
		"intended_movement_direction": Vector3.RIGHT,
		"intended_movement_magnitude": 1.0,
	})
	visual.latest_state = input_state
	visual._update_intended_movement_turn_state(0.04)
	if visual._get_visual_facing_direction(input_state).distance_to(Vector3.FORWARD) > 0.001:
		failures.append("short ground input tap should not immediately redirect visual facing")
	visual._update_intended_movement_turn_state(visual.input_facing_commit_time)
	if visual._get_visual_facing_direction(input_state).distance_to(Vector3.RIGHT) > 0.001:
		failures.append("held ground input should drive visual facing toward intended direction")

	var slide_state := _state({
		"grounded": true,
		"sliding": true,
		"facing_direction": Vector3.FORWARD,
		"intended_movement_direction": Vector3.ZERO,
		"intended_movement_magnitude": 0.0,
	})
	if visual._get_visual_facing_direction(slide_state).distance_to(Vector3.FORWARD) > 0.001:
		failures.append("no-input slide should keep visual facing stable")

	var flight_state := _state({
		"mode": &"flight",
		"grounded": false,
		"facing_direction": Vector3.FORWARD,
		"body_basis": Basis(Vector3.FORWARD, deg_to_rad(35.0)).orthonormalized(),
		"intended_movement_direction": Vector3.RIGHT,
		"intended_movement_magnitude": 1.0,
	})
	if not visual._uses_full_flight_orientation(flight_state):
		failures.append("flight should use full backend body orientation")
	var full_basis: Basis = visual._get_flight_visual_target_basis(flight_state)
	if full_basis.z.distance_to((flight_state.body_basis as Basis).z) > 0.001:
		failures.append("flight orientation should match backend basis")
	var scaled_basis := Basis.IDENTITY.scaled(Vector3(1.001, 1.0, 0.999))
	var clean_basis: Basis = visual._get_flight_visual_target_basis_for_basis(scaled_basis)
	if not _basis_is_normalized(clean_basis):
		failures.append("flight orientation copy should return a normalized rotation basis")


func _expect_head_look_angles(failures: Array[String]) -> void:
	var head_look := HeadLookControllerScript.new()
	head_look.max_yaw = deg_to_rad(30.0)
	head_look.max_pitch = deg_to_rad(20.0)
	head_look.intensity = 1.0
	var flight_state := _state({
		"mode": &"flight",
		"grounded": false,
		"body_basis": Basis.IDENTITY,
	})
	var right_angles: Vector2 = head_look._target_angles(
		flight_state,
		Basis.IDENTITY,
		null,
	)
	if absf(right_angles.x) > 0.001 or absf(right_angles.y) > 0.001:
		failures.append("default flight head look should align with body forward")

	flight_state.body_basis = Basis.IDENTITY
	var target_state := _state({
		"mode": &"ground",
		"grounded": true,
		"facing_direction": Vector3.RIGHT,
		"horizontal_speed": 1.0,
		"look_direction": Vector3.RIGHT,
	})
	var ground_angles: Vector2 = head_look._target_angles(
		target_state,
		Basis.IDENTITY,
		null,
	)
	if absf(ground_angles.x - head_look.max_yaw) > 0.001:
		failures.append("ground head look yaw %.3f should clamp to max yaw" % ground_angles.x)

	var pitch_state := _state({
		"mode": &"ground",
		"grounded": true,
		"facing_direction": Vector3(0.0, 1.0, -1.0).normalized(),
		"horizontal_speed": 1.0,
		"look_direction": Vector3(0.0, 1.0, -1.0).normalized(),
	})
	var pitch_angles: Vector2 = head_look._target_angles(
		pitch_state,
		Basis.IDENTITY,
		null,
	)
	if pitch_angles.y <= 0.0 or pitch_angles.y >= head_look.max_pitch:
		failures.append("head look pitch %.3f should be damped below max pitch" % pitch_angles.y)

	var camera := Camera3D.new()
	camera.basis = Basis(Vector3.FORWARD, Vector3.UP, Vector3.LEFT)
	var camera_priority_state := _state({
		"mode": &"flight",
		"grounded": false,
		"body_basis": Basis.IDENTITY,
		"look_direction": Vector3.FORWARD,
	})
	var camera_angles: Vector2 = head_look._target_angles(
		camera_priority_state,
		Basis.IDENTITY,
		camera,
	)
	if absf(camera_angles.x - head_look.max_yaw) > 0.001:
		failures.append("head look should prefer camera target direction")
	camera.free()

	var idle_ground_state := _state({
		"mode": &"ground",
		"grounded": true,
		"horizontal_speed": 0.0,
		"intended_movement_magnitude": 0.0,
	})
	if head_look._state_intensity(idle_ground_state) > 0.0:
		failures.append("idle grounded head look should be disabled")

	var moving_ground_state := _state({
		"mode": &"ground",
		"grounded": true,
		"horizontal_speed": 1.0,
		"intended_movement_magnitude": 0.0,
	})
	if head_look._state_intensity(moving_ground_state) <= 0.0:
		failures.append("moving grounded head look should stay enabled")
	head_look.free()


func _basis_is_normalized(value: Basis) -> bool:
	return (
		absf(value.x.length() - 1.0) <= 0.001
		and absf(value.y.length() - 1.0) <= 0.001
		and absf(value.z.length() - 1.0) <= 0.001
		and absf(value.x.dot(value.y)) <= 0.001
		and absf(value.x.dot(value.z)) <= 0.001
		and absf(value.y.dot(value.z)) <= 0.001
	)


func _expect_transition_mapping(failures: Array[String], visual: Node) -> void:
	_expect_animation(
		failures,
		visual,
		_state({"grounded": true, "flight_activation_charging": true, "horizontal_speed": 8.0}),
		VisualControllerScript.ANIM_TAKEOFF_RUNUP,
		"flight activation charge",
	)
	_expect_animation(
		failures,
		visual,
		_state({"grounded": false, "just_entered_flight": true, "velocity": Vector3.UP * 8.0}),
		VisualControllerScript.ANIM_TAKEOFF_BOUNCE,
		"flight entry",
	)
	_expect_animation(
		failures,
		visual,
		_state({"mode": &"flight", "grounded": false, "just_entered_flight": true, "flapping": true}),
		VisualControllerScript.ANIM_FLY_FLAP,
		"flight flap beats entry animation",
	)
	_expect_animation(
		failures,
		visual,
		_state({"grounded": false, "just_took_off": true, "velocity": Vector3.UP * 8.0}),
		VisualControllerScript.ANIM_FLY_GLIDE,
		"generic takeoff without flap",
	)
	_expect_animation(
		failures,
		visual,
		_state({"mode": &"flight", "grounded": false, "velocity": Vector3.FORWARD * 10.0}),
		VisualControllerScript.ANIM_FLY_GLIDE,
		"flight glide mode",
	)
	_expect_animation(
		failures,
		visual,
		_state({"mode": &"flight", "grounded": false, "flapping": true}),
		VisualControllerScript.ANIM_FLY_FLAP,
		"explicit flight flap",
	)
	_expect_animation(
		failures,
		visual,
		_state({"mode": &"flight", "grounded": false, "velocity": Vector3.UP * 4.0}),
		VisualControllerScript.ANIM_FLY_GLIDE,
		"flight ignores missing backend flap flag",
	)
	_expect_animation(
		failures,
		visual,
		_state({"grounded": false, "velocity": Vector3.UP * 4.0}),
		VisualControllerScript.ANIM_FLY_GLIDE,
		"airborne ignores missing backend flap flag",
	)
	_expect_animation(
		failures,
		visual,
		_state({"grounded": false, "falling": true, "vertical_speed": -12.0, "velocity": Vector3.DOWN * 12.0}),
		VisualControllerScript.ANIM_PRE_LAND,
		"fast prelanding fall",
	)
	_expect_animation(
		failures,
		visual,
		_state({"grounded": true, "just_landed": true, "landing_vertical_impact_speed": 6.0}),
		VisualControllerScript.ANIM_LAND,
		"landing event",
	)
	_expect_animation(
		failures,
		visual,
		_state({"grounded": true, "crouch_sliding": true, "horizontal_speed": 5.0}),
		VisualControllerScript.ANIM_RUN_FAST,
		"fast crouch slide",
	)


func _expect_locomotion_phase_preserved(failures: Array[String]) -> void:
	var visual := VisualControllerScript.new()
	var player := AnimationPlayer.new()
	visual.animation_player = player
	visual.add_child(player)
	var library := AnimationLibrary.new()
	var walk := Animation.new()
	walk.length = 1.0
	var run := Animation.new()
	run.length = 0.5
	library.add_animation(VisualControllerScript.ANIM_WALK_FAST, walk)
	library.add_animation(VisualControllerScript.ANIM_RUN_FAST, run)
	player.add_animation_library(&"", library)
	player.play(VisualControllerScript.ANIM_WALK_FAST)
	player.seek(0.5, true)
	visual._play_animation(VisualControllerScript.ANIM_RUN_FAST, 1.0)
	if absf(player.current_animation_position - 0.25) > 0.001:
		failures.append(
			"locomotion phase switched to %.3f, expected 0.250"
			% player.current_animation_position
		)
	visual.free()

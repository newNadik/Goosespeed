extends SceneTree

const MovementStateScript := preload("res://scripts/player/movement_state.gd")
const VisualControllerScript := preload("res://scripts/player/goose_visual_controller.gd")


func _initialize() -> void:
	var visual := VisualControllerScript.new()
	var failures: Array[String] = []

	visual.set_movement_backend(VisualControllerScript.BACKEND_PLATFORMER)
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
		_state({"grounded": true, "horizontal_speed": 2.0}),
		VisualControllerScript.ANIM_WALK_MEDIUM,
		"low speed walk",
	)
	_expect_animation(
		failures,
		visual,
		_state({"grounded": true, "horizontal_speed": 4.0}),
		VisualControllerScript.ANIM_WALK_MEDIUM,
		"medium walk",
	)
	_expect_animation(
		failures,
		visual,
		_state({"grounded": true, "horizontal_speed": 5.0}),
		VisualControllerScript.ANIM_WALK_FAST,
		"fast walk",
	)
	_expect_animation(
		failures,
		visual,
		_state({"grounded": true, "horizontal_speed": 7.0}),
		VisualControllerScript.ANIM_RUN_SLOW,
		"slow run",
	)
	_expect_animation(
		failures,
		visual,
		_state({"grounded": true, "horizontal_speed": 8.5}),
		VisualControllerScript.ANIM_RUN_FAST,
		"run",
	)
	_expect_animation(
		failures,
		visual,
		_state({"grounded": true, "horizontal_speed": 7.5}),
		VisualControllerScript.ANIM_RUN_SLOW,
		"slow run below fast run threshold",
	)
	_expect_sticky_run(failures, visual)
	_expect_locomotion_hold(failures, visual)
	_expect_run_speed_scale(failures, visual)
	_expect_q3_mapping(failures, visual)
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
		VisualControllerScript.ANIM_FLY_FLAP,
		"jump flap",
	)
	_expect_animation(
		failures,
		visual,
		_state({"grounded": false, "falling": true, "velocity": Vector3.DOWN}),
		VisualControllerScript.ANIM_FLY_GLIDE,
		"fall glide",
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


func _expect_sticky_run(failures: Array[String], visual: Node) -> void:
	var run: StringName = visual._animation_for_state(
		_state({"grounded": true, "horizontal_speed": 8.5}),
		true,
	)
	if run != VisualControllerScript.ANIM_RUN_FAST:
		failures.append("stable selector entered %s, expected run fast" % run)
	var dip: StringName = visual._animation_for_state(
		_state({"grounded": true, "horizontal_speed": 7.4}),
		true,
	)
	if dip != VisualControllerScript.ANIM_RUN_FAST:
		failures.append("stable selector dipped to %s, expected sticky run fast" % dip)
	visual.run_fast_hold_remaining = 0.0
	visual.locomotion_hold_remaining = 0.0
	var exit: StringName = visual._animation_for_state(
		_state({"grounded": true, "horizontal_speed": 6.0}),
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
		_state({"grounded": true, "horizontal_speed": 5.0}),
		true,
	)
	if held != VisualControllerScript.ANIM_WALK_MEDIUM:
		failures.append("locomotion hold switched to %s, expected held walk medium" % held)
	visual.locomotion_hold_remaining = 0.0
	var released: StringName = visual._animation_for_state(
		_state({"grounded": true, "horizontal_speed": 5.0}),
		true,
	)
	if released != VisualControllerScript.ANIM_WALK_FAST:
		failures.append("locomotion hold released to %s, expected walk fast" % released)


func _expect_run_speed_scale(failures: Array[String], visual: Node) -> void:
	visual.set_movement_backend(VisualControllerScript.BACKEND_PLATFORMER)
	visual.latest_state = _state({"grounded": true, "horizontal_speed": 14.0})
	var speed_scale: float = visual._animation_speed_scale(VisualControllerScript.ANIM_RUN_FAST)
	if speed_scale > 1.15:
		failures.append("run fast speed scale %.3f exceeded readable cap" % speed_scale)


func _expect_q3_mapping(failures: Array[String], visual: Node) -> void:
	visual.set_movement_backend(VisualControllerScript.BACKEND_Q3)
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
	visual.latest_state = _state({"grounded": true, "horizontal_speed": 3.0})
	var crouch_scale: float = visual._animation_speed_scale(VisualControllerScript.ANIM_WALK_FAST)
	if crouch_scale < 1.0:
		failures.append("q3 crouch speed scale %.3f should keep feet moving" % crouch_scale)
	visual.latest_state = _state({"grounded": true, "horizontal_speed": 6.1})
	var walk_scale: float = visual._animation_speed_scale(VisualControllerScript.ANIM_RUN_FAST)
	if walk_scale < 1.0:
		failures.append("q3 shift walk speed scale %.3f should keep feet moving" % walk_scale)
	visual.set_movement_backend(VisualControllerScript.BACKEND_PLATFORMER)


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

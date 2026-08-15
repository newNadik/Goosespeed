extends Node

const PLAYER_SCENE := preload("res://scenes/player/goose_player_root.tscn")
const DEFAULT_PROFILE := preload("res://resources/movement_profiles/default.tres")
const EXPERIMENTAL_PROFILE := preload("res://resources/movement_profiles/experimental_flap.tres")


func _ready() -> void:
	var player := PLAYER_SCENE.instantiate()
	add_child(player)
	await get_tree().process_frame
	var controller: Node = player.get_active_controller()
	if controller == null:
		push_error("Q3 + Flight did not create an active controller")
		get_tree().quit(1)
		return
	if not _controller_contract_is_valid(controller):
		push_error("Q3 + Flight controller does not match GooseSpeed runtime contract")
		get_tree().quit(1)
		return
	if not _controller_control_gate_allows_camera_look(controller):
		get_tree().quit(1)
		return
	if controller.name != "ActiveMovementController":
		push_error("Active controller has unexpected name %s" % controller.name)
		get_tree().quit(1)
		return
	await get_tree().process_frame
	if not _prototype_visuals_are_hidden(controller):
		push_error("Prototype visuals are visible")
		get_tree().quit(1)
		return
	if not _backend_hud_is_hidden(controller):
		push_error("Prototype debug HUD is visible")
		get_tree().quit(1)
		return
	if not _backend_camera_is_current(controller):
		push_error("Q3 + Flight does not use an addon camera")
		get_tree().quit(1)
		return
	if not _goose_visual_settings_are_applied(player):
		get_tree().quit(1)
		return
	if not _movement_profiles_are_configured():
		get_tree().quit(1)
		return
	if not _movement_profile_is_applied(player, controller):
		get_tree().quit(1)
		return
	if not _straight_run_bonus_behaves_as_profiled(controller):
		get_tree().quit(1)
		return
	if not await _first_person_camera_hides_goose_visual(player, controller):
		get_tree().quit(1)
		return
	if not await _bridge_preserves_backend_flap_state(player, controller):
		get_tree().quit(1)
		return
	if not _hybrid_control_button_behaves_as_slide(controller):
		get_tree().quit(1)
		return

	print("Q3 + Flight backend OK")
	get_tree().quit(0)


func _prototype_visuals_are_hidden(controller: Node) -> bool:
	for node_name in ["BodyMesh", "FaceMarker", "CharacterColliderVisual", "FlightBodyMesh"]:
		var visual := controller.get_node_or_null(node_name) as Node3D
		if visual != null and visual.visible:
			return false
	return true


func _controller_contract_is_valid(controller: Node) -> bool:
	if not controller is Node3D:
		return false
	for method_name in GooseMovesRuntime.REQUIRED_CONTROLLER_METHODS:
		if not controller.has_method(method_name):
			return false
	return true


func _controller_control_gate_allows_camera_look(controller: Node) -> bool:
	controller.set_control_enabled(false)
	var q3_motor = controller.get("q3_motor")
	var flight_motor = controller.get("flight_motor")
	if bool(q3_motor.get("control_enabled")):
		push_error("Control gate did not block Q3 movement controls")
		return false
	if not bool(q3_motor.get("camera_control_enabled")):
		push_error("Control gate should leave Q3 camera look enabled")
		return false
	if bool(flight_motor.get("control_enabled")):
		push_error("Control gate did not block flight movement controls")
		return false
	controller.set_control_enabled(true)
	if not bool(q3_motor.get("control_enabled")) or not bool(flight_motor.get("control_enabled")):
		push_error("Control gate did not restore movement controls")
		return false
	return true


func _backend_camera_is_current(controller: Node) -> bool:
	for camera in _find_cameras(controller):
		if camera.current:
			return true
	return false


func _backend_hud_is_hidden(controller: Node) -> bool:
	for hud_name in ["HUD", "Q3HUD"]:
		var backend_hud := controller.get_node_or_null(hud_name) as CanvasLayer
		if backend_hud != null and backend_hud.visible:
			return false
	return true


func _goose_visual_settings_are_applied(player: Node) -> bool:
	var goose_visual := player.get_node("GooseVisual")
	if bool(goose_visual.get("head_look_enabled")) != GooseGameSettings.head_look_enabled:
		push_error("Goose visual did not apply head-look enabled setting")
		return false
	if not is_equal_approx(
		float(goose_visual.get("head_look_intensity")),
		GooseGameSettings.head_look_intensity,
	):
		push_error("Goose visual did not apply head-look intensity setting")
		return false
	if not is_equal_approx(
		float(goose_visual.get("head_look_smoothness")),
		GooseGameSettings.head_look_smoothness,
	):
		push_error("Goose visual did not apply head-look smoothness setting")
		return false
	if goose_visual.get_node_or_null("GooseHeadLookController") == null:
		push_error("Goose visual did not create a head-look controller")
		return false
	var animation_player := goose_visual.get_node_or_null("AnimationPlayer") as AnimationPlayer
	var head_look := goose_visual.get_node_or_null("GooseHeadLookController")
	if animation_player == null or head_look == null or head_look.get_index() <= animation_player.get_index():
		push_error("Goose head-look controller does not run after AnimationPlayer")
		return false
	return true


func _movement_profiles_are_configured() -> bool:
	if not is_equal_approx(DEFAULT_PROFILE.flight_hold_threshold, 0.3):
		push_error("Default movement profile changed the old flight hold threshold")
		return false
	if not is_equal_approx(DEFAULT_PROFILE.flap_cooldown, 0.5):
		push_error("Default movement profile changed the old flap cooldown")
		return false
	if not is_equal_approx(DEFAULT_PROFILE.takeoff_runup_charge_ratio, 0.5):
		push_error("Default movement profile changed the player scene charge animation ratio")
		return false
	if not is_equal_approx(DEFAULT_PROFILE.straight_run_bonus_acceleration, 0.0):
		push_error("Default movement profile should leave straight-run bonus disabled")
		return false
	if not is_equal_approx(DEFAULT_PROFILE.straight_run_bonus_max_speed, 0.0):
		push_error("Default movement profile should not allow extra straight-run speed")
		return false
	if not is_equal_approx(EXPERIMENTAL_PROFILE.flight_hold_threshold, 0.3):
		push_error("Experimental movement profile did not set flight hold threshold")
		return false
	if not is_equal_approx(EXPERIMENTAL_PROFILE.flap_cooldown, 0.8):
		push_error("Experimental movement profile did not set flap cooldown")
		return false
	if not is_equal_approx(EXPERIMENTAL_PROFILE.takeoff_runup_charge_ratio, 0.5):
		push_error("Experimental movement profile changed charge animation ratio")
		return false
	if not is_equal_approx(EXPERIMENTAL_PROFILE.straight_run_bonus_acceleration, 0.3):
		push_error("Experimental movement profile did not set straight-run bonus acceleration")
		return false
	if not is_equal_approx(EXPERIMENTAL_PROFILE.straight_run_bonus_max_speed, 6.0):
		push_error("Experimental movement profile did not set straight-run bonus max speed")
		return false
	if not is_equal_approx(EXPERIMENTAL_PROFILE.straight_run_bonus_decay, 8.0):
		push_error("Experimental movement profile did not set straight-run bonus decay")
		return false
	return true


func _movement_profile_is_applied(player: Node, controller: Node) -> bool:
	var profile: Resource = player.get("movement_profile")
	if profile == null:
		push_error("Player scene does not assign a movement profile")
		return false
	if profile != EXPERIMENTAL_PROFILE:
		push_error("Player scene is not using the experimental movement profile")
		return false
	if not is_equal_approx(
		float(controller.get("flight_hold_threshold")),
		float(profile.get("flight_hold_threshold")),
	):
		push_error("Movement profile did not apply flight hold threshold to the controller")
		return false
	var flight_motor = controller.get("flight_motor")
	if flight_motor == null:
		push_error("Movement profile cannot find controller flight motor")
		return false
	if not is_equal_approx(
		float(flight_motor.get("flap_cooldown")),
		float(profile.get("flap_cooldown")),
	):
		push_error("Movement profile did not apply flap cooldown to the flight motor")
		return false
	var goose_visual := player.get_node("GooseVisual")
	if not is_equal_approx(
		float(goose_visual.get("takeoff_runup_charge_ratio")),
		float(profile.get("takeoff_runup_charge_ratio")),
	):
		push_error("Movement profile did not apply charge animation ratio to goose visual")
		return false
	var q3_motor = controller.get("q3_motor")
	if q3_motor == null:
		push_error("Movement profile cannot find controller Q3 motor")
		return false
	for setting_name in [
		"straight_run_bonus_acceleration",
		"straight_run_bonus_max_speed",
		"straight_run_bonus_decay",
		"straight_run_min_forward_input",
		"straight_run_max_lateral_input",
		"straight_run_max_direction_change_degrees",
		"straight_run_max_floor_normal_change_degrees",
	]:
		if not is_equal_approx(float(q3_motor.get(setting_name)), float(profile.get(setting_name))):
			push_error("Movement profile did not apply %s to the Q3 motor" % setting_name)
			return false
	return true


func _straight_run_bonus_behaves_as_profiled(controller: Node) -> bool:
	var q3_motor = controller.get("q3_motor")
	if q3_motor == null:
		push_error("Straight-run test cannot find controller Q3 motor")
		return false
	q3_motor._reset_straight_run_bonus()
	q3_motor.velocity = Vector3.ZERO
	var target_bonus: float = q3_motor._update_straight_run_bonus(
		1.0,
		true,
		Vector2(0.0, 1.0),
		Vector3.FORWARD,
		Vector3.UP,
	)
	if (
		not is_equal_approx(q3_motor.straight_run_bonus_speed, 0.3)
		or not is_equal_approx(q3_motor.straight_run_current_acceleration, 0.3)
		or not is_equal_approx(target_bonus, 0.3)
		or q3_motor.velocity.length() > 0.0
	):
		push_error("Straight-run bonus did not add target speed during stable forward ground movement")
		return false
	target_bonus = q3_motor._update_straight_run_bonus(
		1.0,
		true,
		Vector2(1.0, 0.7),
		Vector3.RIGHT,
		Vector3.UP,
	)
	if q3_motor.straight_run_bonus_speed > 0.0 or target_bonus > 0.0:
		push_error("Straight-run bonus did not decay after a rapid turn")
		return false
	q3_motor._reset_straight_run_bonus()
	q3_motor.velocity = Vector3.ZERO
	q3_motor._update_straight_run_bonus(2.0, true, Vector2(0.0, 1.0), Vector3.FORWARD, Vector3.UP)
	target_bonus = q3_motor._update_straight_run_bonus(
		1.0,
		true,
		Vector2(0.0, 1.0),
		Vector3.FORWARD,
		Vector3.UP.rotated(Vector3.RIGHT, deg_to_rad(25.0)),
	)
	if q3_motor.straight_run_bonus_speed > 0.0 or target_bonus > 0.0:
		push_error("Straight-run bonus did not decay on bumpy terrain")
		return false
	return true


func _first_person_camera_hides_goose_visual(player: Node, controller: Node) -> bool:
	var goose_visual := player.get_node("GooseVisual")
	for instance in _find_player_body_instances(goose_visual):
		if not instance.get_layer_mask_value(GoosePlayerRoot.PLAYER_BODY_RENDER_LAYER):
			push_error("Goose visual is not on the player-body render layer")
			return false
		if instance.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			push_error("Goose visual shadow casting was disabled")
			return false
	if _find_shadow_caster_instances(goose_visual).is_empty():
		push_error("Goose visual does not have a first-person shadow caster")
		return false
	for instance in _find_shadow_caster_instances(goose_visual):
		if instance.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
			push_error("First-person shadow caster is not shadow-only")
			return false

	if not controller.has_method("toggle_camera_mode"):
		push_error("Q3 + Flight controller cannot toggle camera mode")
		return false

	controller.toggle_camera_mode()
	await get_tree().process_frame
	var first_person_camera := controller.get_view_camera() as Camera3D
	if first_person_camera == null or first_person_camera.get_cull_mask_value(GoosePlayerRoot.PLAYER_BODY_RENDER_LAYER):
		push_error("First-person camera still renders the goose visual layer")
		return false
	if _any_backend_camera_renders_player_body(controller):
		push_error("Inactive first-person backend camera renders the goose visual layer before switching")
		return false
	controller._enter_flight()
	var transition_camera := controller.get_view_camera() as Camera3D
	if (
		transition_camera == null
		or transition_camera.name != "TransitionCamera"
		or transition_camera.get_cull_mask_value(GoosePlayerRoot.PLAYER_BODY_RENDER_LAYER)
	):
		push_error("First-person transition camera renders the goose visual layer")
		return false
	await get_tree().process_frame
	controller._update_camera_transition(controller.CAMERA_TRANSITION_DURATION)
	await get_tree().process_frame

	controller.toggle_camera_mode()
	await get_tree().process_frame
	var third_person_camera := controller.get_view_camera() as Camera3D
	if third_person_camera == null or not third_person_camera.get_cull_mask_value(GoosePlayerRoot.PLAYER_BODY_RENDER_LAYER):
		push_error("Third-person camera does not render the goose visual layer")
		return false
	if not _all_backend_cameras_render_player_body(controller):
		push_error("Inactive third-person backend camera does not render the goose visual layer")
		return false
	return true


func _bridge_preserves_backend_flap_state(player: Node, controller: Node) -> bool:
	controller._enter_flight()
	await get_tree().process_frame
	controller.flight_motor.flap_cooldown = 0.5
	controller.flight_motor.flap_cooldown_remaining = 0.0
	controller.flight_motor.flap_feedback_remaining = 0.0
	controller._try_flap_impulse()
	await get_tree().physics_frame
	await get_tree().process_frame
	var bridge: Node = player.get_node("MovementStateBridge")
	var visual: Node = player.get_node("GooseVisual")
	var state: RefCounted = bridge.get_state()
	if not state.flapping:
		push_error("MovementStateBridge dropped backend flap state")
		return false
	if visual.visual_state_for_state(state) != &"flight_flap":
		push_error("Goose visual state did not use bridged backend flap state")
		return false
	return true


func _hybrid_control_button_behaves_as_slide(controller: Node) -> bool:
	var q3_motor = controller.q3_motor
	if not q3_motor.crouch_slide_enabled:
		push_error("Q3 + Flight did not force slide/tuck enabled")
		return false
	controller._enter_q3(false)
	q3_motor.water_level = 0
	q3_motor.is_crouch_sliding = false
	q3_motor.crouch_slide_time_remaining = 0.0
	q3_motor.velocity = Vector3(8.0, 0.0, 0.0)

	Input.action_press("player_crouch")
	q3_motor._update_crouch_slide(1.0 / 60.0, true)
	if not q3_motor.is_crouch_sliding:
		Input.action_release("player_crouch")
		push_error("Control button did not start a grounded slide")
		return false
	if q3_motor.crouch_slide_time_remaining > 0.6:
		Input.action_release("player_crouch")
		push_error("Grounded slide lasted too long for flat ground")
		return false
	q3_motor._update_crouch_state()
	if not q3_motor.is_crouching:
		Input.action_release("player_crouch")
		push_error("Slide did not lower the stance while active")
		return false

	q3_motor.is_crouch_sliding = false
	q3_motor.crouch_slide_time_remaining = 0.0
	q3_motor._update_crouch_state()
	Input.action_release("player_crouch")
	if q3_motor.is_crouching:
		push_error("Control button stayed in dry-ground crouch after slide")
		return false
	return true


func _find_cameras(root: Node) -> Array[Camera3D]:
	var cameras: Array[Camera3D] = []
	if root is Camera3D:
		cameras.append(root as Camera3D)
	for child in root.get_children():
		cameras.append_array(_find_cameras(child))
	return cameras


func _any_backend_camera_renders_player_body(controller: Node) -> bool:
	for camera in _find_cameras(controller):
		if camera.get_cull_mask_value(GoosePlayerRoot.PLAYER_BODY_RENDER_LAYER):
			return true
	return false


func _all_backend_cameras_render_player_body(controller: Node) -> bool:
	for camera in _find_cameras(controller):
		if not camera.get_cull_mask_value(GoosePlayerRoot.PLAYER_BODY_RENDER_LAYER):
			return false
	return true


func _find_visual_instances(root: Node) -> Array[VisualInstance3D]:
	var instances: Array[VisualInstance3D] = []
	if root is VisualInstance3D:
		instances.append(root as VisualInstance3D)
	for child in root.get_children():
		instances.append_array(_find_visual_instances(child))
	return instances


func _find_player_body_instances(root: Node) -> Array[VisualInstance3D]:
	var instances: Array[VisualInstance3D] = []
	for instance in _find_visual_instances(root):
		if not bool(instance.get_meta(GoosePlayerRoot.SHADOW_CASTER_META, false)):
			instances.append(instance)
	return instances


func _find_shadow_caster_instances(root: Node) -> Array[VisualInstance3D]:
	var instances: Array[VisualInstance3D] = []
	for instance in _find_visual_instances(root):
		if bool(instance.get_meta(GoosePlayerRoot.SHADOW_CASTER_META, false)):
			instances.append(instance)
	return instances

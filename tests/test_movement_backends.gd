extends Node

const PLAYER_SCENE := preload("res://scenes/player/goose_player_root.tscn")


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
	if controller.name != "ActiveMovementController":
		push_error("Active controller has unexpected name %s" % controller.name)
		get_tree().quit(1)
		return
	await get_tree().process_frame
	if not _prototype_visuals_are_hidden(controller):
		push_error("Prototype visuals are visible")
		get_tree().quit(1)
		return
	if not _backend_hud_is_visible(controller):
		push_error("Debug HUD is hidden")
		get_tree().quit(1)
		return
	if not _backend_camera_is_current(controller):
		push_error("Q3 + Flight does not use an addon camera")
		get_tree().quit(1)
		return
	if not _goose_visual_settings_are_applied(player):
		get_tree().quit(1)
		return
	if not await _first_person_camera_hides_goose_visual(player, controller):
		get_tree().quit(1)
		return
	if not await _bridge_preserves_backend_flap_state(player, controller):
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


func _backend_camera_is_current(controller: Node) -> bool:
	for camera in _find_cameras(controller):
		if camera.current:
			return true
	return false


func _backend_hud_is_visible(controller: Node) -> bool:
	for hud_name in ["HUD", "Q3HUD"]:
		var backend_hud := controller.get_node_or_null(hud_name) as CanvasLayer
		if backend_hud != null and backend_hud.visible:
			return true
	return false


func _goose_visual_settings_are_applied(player: Node) -> bool:
	var goose_visual := player.get_node("GooseVisual")
	if not is_equal_approx(
		float(goose_visual.get("flight_orientation_intensity")),
		GooseGameSettings.flight_orientation_intensity,
	):
		push_error("Goose visual did not apply flight orientation intensity setting")
		return false
	if not is_equal_approx(
		float(goose_visual.get("flight_orientation_slerp_rate")),
		GooseGameSettings.flight_orientation_slerp_rate,
	):
		push_error("Goose visual did not apply flight orientation smoothness setting")
		return false
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

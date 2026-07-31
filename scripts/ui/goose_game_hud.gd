class_name GooseGameHud
extends CanvasLayer

const MovementStateScript := preload("res://scripts/player/movement_state.gd")

const PANEL_MARGIN := 16.0

@onready var direction_panel: PanelContainer = $Root/DirectionPanel
@onready var direction_arrow: Label = $Root/DirectionPanel/Margin/DirectionBox/DirectionArrow
@onready var direction_label: Label = $Root/DirectionPanel/Margin/DirectionBox/DirectionLabel
@onready var state_details_panel: PanelContainer = $Root/StateDetailsPanel
@onready var state_details_label: RichTextLabel = $Root/StateDetailsPanel/Margin/StateDetailsLabel
@onready var timer_panel: PanelContainer = $Root/TimerPanel
@onready var timer_label: Label = $Root/TimerPanel/Margin/VBox/TimerLabel
@onready var movement_panel: PanelContainer = $Root/MovementPanel
@onready var speed_label: Label = $Root/MovementPanel/Margin/VBox/SpeedLabel
@onready var flight_widget: VBoxContainer = $Root/MovementPanel/Margin/VBox/FlightWidget
@onready var flight_label: Label = $Root/MovementPanel/Margin/VBox/FlightWidget/FlightLabel
@onready var flight_progress: ProgressBar = $Root/MovementPanel/Margin/VBox/FlightWidget/FlightProgress
@onready var vertical_speed_label: Label = $Root/MovementPanel/Margin/VBox/VerticalSpeedLabel
@onready var acceleration_label: Label = $Root/MovementPanel/Margin/VBox/AccelerationLabel
@onready var surface_label: Label = $Root/MovementPanel/Margin/VBox/SurfaceLabel
@onready var debug_panel: PanelContainer = $Root/DebugPanel
@onready var state_label: Label = $Root/DebugPanel/Margin/VBox/StateLabel
@onready var fps_label: Label = $Root/DebugPanel/Margin/VBox/FpsLabel
@onready var raw_movement_label: Label = $Root/DebugPanel/Margin/VBox/RawMovementLabel
@onready var surface_flags_label: Label = $Root/DebugPanel/Margin/VBox/SurfaceFlagsLabel
@onready var input_state_label: Label = $Root/DebugPanel/Margin/VBox/InputStateLabel

var player: Node
var state_bridge: Node
var visual_controller: Node
var finish_target: Node3D
var elapsed_time := 0.0
var run_finished := false
var previous_velocity := Vector3.ZERO
var acceleration := 0.0
var has_previous_velocity := false


func _ready() -> void:
	_connect_settings()
	_update_visibility()


func _process(delta: float) -> void:
	_update_acceleration(delta)
	_update_labels()


func set_player(value: Node) -> void:
	player = value
	state_bridge = player.get("movement_state_bridge") if player != null else null
	visual_controller = player.get_node_or_null("GooseVisual") if player != null else null
	has_previous_velocity = false
	_update_labels()


func set_finish_target(value: Node3D) -> void:
	finish_target = value
	_update_labels()


func set_run_state(time_seconds: float, finished: bool) -> void:
	elapsed_time = time_seconds
	run_finished = finished
	_update_labels()


func _connect_settings() -> void:
	var settings := get_node_or_null("/root/GooseGameSettings")
	if settings != null and settings.has_signal("settings_changed"):
		if not settings.is_connected("settings_changed", _on_settings_changed):
			settings.connect("settings_changed", _on_settings_changed)


func _on_settings_changed() -> void:
	_update_visibility()
	_update_labels()


func _update_visibility() -> void:
	var direction_visible := _hud_visible(GooseGameSettings.HUD_DIRECTION_TO_FINISH)
	var timer_visible := _hud_visible(GooseGameSettings.HUD_TIMER)
	var speed_visible := _hud_visible(GooseGameSettings.HUD_SPEED)
	var flight_visible := _hud_visible(GooseGameSettings.HUD_FLIGHT_WIDGET)
	var vertical_speed_visible := _hud_visible(GooseGameSettings.HUD_VERTICAL_SPEED)
	var acceleration_visible := _hud_visible(GooseGameSettings.HUD_ACCELERATION)
	var surface_visible := _hud_visible(GooseGameSettings.HUD_SURFACE_GRIP)
	var state_visible := _hud_visible(GooseGameSettings.HUD_STATE)
	var fps_visible := _hud_visible(GooseGameSettings.HUD_FPS)
	var raw_visible := _hud_visible(GooseGameSettings.HUD_RAW_MOVEMENT)
	var surface_flags_visible := _hud_visible(GooseGameSettings.HUD_SURFACE_FLAGS)
	var input_visible := _hud_visible(GooseGameSettings.HUD_INPUT_STATE)
	var state_details_visible := _hud_visible(GooseGameSettings.HUD_DEBUG_STATE_VIEW)

	state_details_panel.visible = state_details_visible and player != null and state_bridge != null
	direction_panel.visible = direction_visible and finish_target != null
	timer_label.visible = timer_visible
	timer_panel.visible = timer_visible
	speed_label.visible = speed_visible
	flight_widget.visible = flight_visible and _has_flight_widget_data()

	vertical_speed_label.visible = vertical_speed_visible
	acceleration_label.visible = acceleration_visible
	surface_label.visible = surface_visible
	movement_panel.visible = (
		speed_label.visible
		or flight_widget.visible
		or vertical_speed_visible
		or acceleration_visible
		or surface_visible
	)

	state_label.visible = state_visible
	fps_label.visible = fps_visible
	raw_movement_label.visible = raw_visible
	surface_flags_label.visible = surface_flags_visible
	input_state_label.visible = input_visible
	debug_panel.visible = state_visible or fps_visible or raw_visible or surface_flags_visible or input_visible


func _update_labels() -> void:
	var state := _get_movement_state()
	_update_visibility()
	_update_direction_marker(state)
	speed_label.text = "Speed  %.1f m/s" % state.horizontal_speed
	timer_label.text = "Run  %05.2f%s" % [elapsed_time, "  FINISH" if run_finished else ""]
	_update_flight_widget()
	vertical_speed_label.text = "Vertical  %+.1f m/s" % state.vertical_speed
	acceleration_label.text = "Accel  %.1f m/s2" % acceleration
	surface_label.text = "Surface  %s" % _surface_text(state)
	state_label.text = "State  %s" % _state_text(state)
	fps_label.text = "FPS  %d" % Engine.get_frames_per_second()
	raw_movement_label.text = "Raw  %.1f u/s  %.1f m/s  %.1f accel" % [
		state.velocity.length(),
		state.horizontal_speed,
		acceleration,
	]
	surface_flags_label.text = "Flags  %s" % _format_surface_flags(state)
	input_state_label.text = "Input  %s  mode:%s" % [_format_input_state(), str(state.mode)]
	_update_state_details(state)


func _get_movement_state() -> RefCounted:
	if state_bridge != null and state_bridge.has_method("get_state"):
		return state_bridge.get_state()
	return MovementStateScript.new()


func _update_acceleration(delta: float) -> void:
	if delta <= 0.0:
		return
	var state := _get_movement_state()
	if has_previous_velocity:
		acceleration = (state.velocity - previous_velocity).length() / delta
	previous_velocity = state.velocity
	has_previous_velocity = true


func _update_direction_marker(state: RefCounted) -> void:
	if not direction_panel.visible or finish_target == null:
		return
	var camera := get_viewport().get_camera_3d()
	var active_controller := _get_active_controller()
	if camera == null or active_controller == null:
		direction_panel.visible = false
		return

	var viewport_size := get_viewport().get_visible_rect().size
	var target_position := finish_target.global_position
	var screen_position := camera.unproject_position(target_position)
	var center := viewport_size * 0.5
	var direction := screen_position - center
	if camera.is_position_behind(target_position):
		direction = -direction
	if direction.length_squared() < 1.0:
		direction = Vector2.UP

	var marker_position := screen_position
	var panel_size := direction_panel.size
	var min_position := Vector2(PANEL_MARGIN, PANEL_MARGIN)
	var max_position := viewport_size - panel_size - Vector2(PANEL_MARGIN, PANEL_MARGIN)
	if (
		camera.is_position_behind(target_position)
		or screen_position.x < min_position.x
		or screen_position.y < min_position.y
		or screen_position.x > max_position.x
		or screen_position.y > max_position.y
	):
		var edge_direction := direction.normalized()
		var edge_radius := (viewport_size - panel_size - Vector2(PANEL_MARGIN * 2.0, PANEL_MARGIN * 2.0)) * 0.5
		var scale: float = min(
			edge_radius.x / max(abs(edge_direction.x), 0.001),
			edge_radius.y / max(abs(edge_direction.y), 0.001)
		)
		marker_position = center + edge_direction * scale

	direction_panel.position = marker_position.clamp(min_position, max_position)
	direction_arrow.rotation = direction.angle()
	direction_label.text = "%dm" % int(round(active_controller.global_position.distance_to(target_position)))


func _update_flight_widget() -> void:
	if not flight_widget.visible:
		return
	var flight_debug := _get_flight_debug_state()
	var remaining := float(flight_debug.get("flap_cooldown_remaining", 0.0))
	var cooldown := float(flight_debug.get("flap_cooldown", 0.0))
	if cooldown <= 0.0:
		flight_widget.visible = false
		return
	flight_progress.max_value = cooldown
	flight_progress.value = cooldown - remaining
	flight_label.text = "Flap  ready" if remaining <= 0.0 else "Flap  %.1fs" % remaining


func _has_flight_widget_data() -> bool:
	return float(_get_flight_debug_state().get("flap_cooldown", 0.0)) > 0.0


func _get_flight_debug_state() -> Dictionary:
	var active_controller := _get_active_controller()
	if active_controller != null and active_controller.has_method("get_flight_debug_state"):
		return active_controller.get_flight_debug_state()
	return {}


func _update_state_details(state: RefCounted) -> void:
	if not state_details_panel.visible:
		return
	var flight_debug := _get_flight_debug_state()
	state_details_label.text = "\n".join([
		"[center][b]%s[/b][/center]" % _get_visual_state_name(state),
		"[center]contact  %s[/center]" % _format_debug_flags(state, [
			&"grounded",
			&"airborne",
			&"swimming",
			&"sliding",
			&"crouching",
			&"crouch_sliding",
		]),
		"[center]flight   %s[/center]" % _format_debug_flags(state, [
			&"flight_activation_charging",
			&"just_entered_flight",
			&"just_exited_flight",
			&"gliding",
			&"flapping",
			&"falling",
		]),
		"[center]flap cd %s[/center]" % _format_flap_cooldown(flight_debug),
	])


func _format_debug_flags(state: RefCounted, flags: Array[StringName]) -> String:
	var parts: Array[String] = []
	for flag in flags:
		parts.append(_format_debug_flag(str(flag), bool(state.get(str(flag)))))
	return "  ".join(parts)


func _format_debug_flag(flag_name: String, active: bool) -> String:
	if active:
		return "[color=#ffffff][b]%s[/b][/color]" % flag_name
	return "[color=#5f6670]%s[/color]" % flag_name


func _format_flap_cooldown(debug_state: Dictionary) -> String:
	var remaining := float(debug_state.get("flap_cooldown_remaining", 0.0))
	var cooldown := float(debug_state.get("flap_cooldown", 0.0))
	if cooldown <= 0.0:
		return "[color=#5f6670]n/a[/color]"
	if remaining > 0.0:
		return "[color=#ffcc45][b]%.2f / %.2f[/b][/color]" % [remaining, cooldown]
	return "[color=#1df05a][b]ready[/b][/color]"


func _get_visual_state_name(state: RefCounted) -> String:
	if visual_controller != null and visual_controller.has_method("visual_state_for_state"):
		return str(visual_controller.visual_state_for_state(state))
	return _state_text(state)


func _get_active_controller() -> Node3D:
	if player != null and player.has_method("get_active_controller"):
		return player.get_active_controller() as Node3D
	return null


func _hud_visible(element: String) -> bool:
	var settings := get_node_or_null("/root/GooseGameSettings")
	if settings == null or not settings.has_method("is_hud_element_visible"):
		return element in GooseGameSettings.HUD_CORE_ELEMENTS
	return settings.is_hud_element_visible(element)


func _state_text(state: RefCounted) -> String:
	if state.swimming:
		return "water"
	if state.sliding:
		return "sliding"
	if state.gliding:
		return "gliding"
	if state.flapping:
		return "flapping"
	if state.falling:
		return "falling"
	if state.grounded:
		return "ground"
	return "air"


func _surface_text(state: RefCounted) -> String:
	if state.surface_type != &"":
		return str(state.surface_type)
	return str(state.medium_type)


func _format_surface_flags(state: RefCounted) -> String:
	var flags: Array[String] = []
	if state.grounded:
		flags.append("ground")
	if state.sliding:
		flags.append("slick")
	if state.swimming:
		flags.append("water")
	if state.wall_contact:
		flags.append("wall")
	if state.knocked_down:
		flags.append("knockdown")
	return "none" if flags.is_empty() else " / ".join(flags)


func _format_input_state() -> String:
	var inputs: Array[String] = []
	for action in [&"player_forward", &"player_back", &"player_left", &"player_right"]:
		if Input.is_action_pressed(action):
			inputs.append(str(action).replace("player_", ""))
	if Input.is_action_pressed(&"player_jump"):
		inputs.append("jump")
	if Input.is_action_pressed(&"player_crouch"):
		inputs.append("crouch")
	if Input.is_action_pressed(&"player_walk"):
		inputs.append("walk")
	return "none" if inputs.is_empty() else " / ".join(inputs)

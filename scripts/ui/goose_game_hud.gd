class_name GooseGameHud
extends CanvasLayer

const MovementStateScript := preload("res://scripts/player/movement_state.gd")

const COMPASS_CLIP_CENTER_X := 228.0
const COMPASS_CYCLE_WIDTH := 456.0
const COMPASS_CENTER_N_X := 456.0
const COUNTDOWN_TEXTURES: Array[Texture2D] = [
	preload("res://assets/ui/count_3.png"),
	preload("res://assets/ui/count_2.png"),
	preload("res://assets/ui/count_1.png"),
	preload("res://assets/ui/count_go.png"),
]
const COUNTDOWN_SLIDE_DURATION := 0.2
const COUNTDOWN_CENTER_HOLD_DURATION := 0.6
const COUNTDOWN_MAX_WIDTH := 520.0
const COUNTDOWN_SCREEN_WIDTH_SCALE := 0.42
const COUNTDOWN_SCREEN_HEIGHT_SCALE := 0.45
const ACCELERATION_SMOOTHNESS := 14.0

@onready var root: Control = $Root
@onready var direction_panel: Control = $Root/DirectionWidget
@onready var compass_clip: Control = $Root/DirectionWidget/CompassClip
@onready var compass_strip: Control = $Root/DirectionWidget/CompassClip/CompassStrip
@onready var finish_icon: TextureRect = $Root/DirectionWidget/CompassClip/FinishIcon
@onready var direction_label: Label = $Root/DirectionWidget/FinishLabel
@onready var state_details_panel: PanelContainer = $Root/StateDetailsPanel
@onready var state_details_label: RichTextLabel = $Root/StateDetailsPanel/Margin/StateDetailsLabel
@onready var timer_panel: Control = $Root/TimerWidget
@onready var timer_label: Label = $Root/TimerWidget/HBoxContainer/TimerLabel
@onready var coin_label: Label = $Root/TimerWidget/CoinsRow/CoinLabel
@onready var movement_panel: Control = $Root/MovementWidget
@onready var speed_label: Label = $Root/MovementWidget/SpeedLabel
@onready var speed_unit_label: Label = $Root/MovementWidget/SpeedUnitLabel
@onready var speedometer_gauge: Control = $Root/MovementWidget/SpeedometerGauge
@onready var flight_widget: Control = $Root/MovementWidget/FlightWidget
@onready var flap_cooldown_gauge: Control = $Root/MovementWidget/FlightWidget/FlapCooldownGauge
@onready var vertical_speed_gauge: Control = $Root/MovementWidget/VerticalSpeedGauge
@onready var acceleration_gauge: Control = $Root/MovementWidget/AccelerationGauge
@onready var flight_aim_dot: Control = $Root/FlightAimDot
@onready var fps_label: Label = $Root/FpsLabel
@onready var controls_hint_panel: PanelContainer = $Root/ControlsHintPanel
@onready var move_hint_key_label: Label = $Root/ControlsHintPanel/Margin/Row/MoveHint/KeyLabel
@onready var jump_hint_key_label: Label = $Root/ControlsHintPanel/Margin/Row/JumpHint/KeyLabel
@onready var jump_hint_action_label: Label = $Root/ControlsHintPanel/Margin/Row/JumpHint/ActionLabel
@onready var flap_hint_item: Control = $Root/ControlsHintPanel/Margin/Row/FlapHint
@onready var flap_hint_key_label: Label = $Root/ControlsHintPanel/Margin/Row/FlapHint/KeyLabel
@onready var slide_hint_key_label: Label = $Root/ControlsHintPanel/Margin/Row/SlideHint/KeyLabel
@onready var honk_hint_key_label: Label = $Root/ControlsHintPanel/Margin/Row/HonkHint/KeyLabel
@onready var debug_panel: PanelContainer = $Root/DebugPanel
@onready var state_label: Label = $Root/DebugPanel/Margin/VBox/StateLabel
@onready var raw_movement_label: Label = $Root/DebugPanel/Margin/VBox/RawMovementLabel
@onready var surface_flags_label: Label = $Root/DebugPanel/Margin/VBox/SurfaceFlagsLabel
@onready var input_state_label: Label = $Root/DebugPanel/Margin/VBox/InputStateLabel

var player: Node
var state_bridge: Node
var visual_controller: Node
var finish_target: Node3D
var elapsed_time := 0.0
var run_finished := false
var coin_count := 0
var coin_target := 0
var previous_horizontal_velocity := Vector2.ZERO
var acceleration := 0.0
var has_previous_velocity := false
var finish_icon_base_y := 0.0
var countdown_rect: TextureRect
var countdown_playing := false


func _ready() -> void:
	finish_icon_base_y = finish_icon.position.y
	_ensure_countdown_rect()
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


func set_coin_count(value: int) -> void:
	coin_count = max(value, 0)
	_update_labels()


func set_coin_target(value: int) -> void:
	coin_target = max(value, 0)
	_update_labels()


func play_level_start_countdown(show_controls_hint := false) -> void:
	_ensure_countdown_rect()
	countdown_playing = true
	_update_controls_hint_bindings()
	controls_hint_panel.visible = show_controls_hint
	for texture in COUNTDOWN_TEXTURES:
		await _play_countdown_step(texture)
	countdown_rect.visible = false
	controls_hint_panel.visible = false
	countdown_playing = false


func is_level_start_countdown_playing() -> bool:
	return countdown_playing


func _connect_settings() -> void:
	var settings := get_node_or_null("/root/GooseGameSettings")
	if settings != null and settings.has_signal("settings_changed"):
		if not settings.is_connected("settings_changed", _on_settings_changed):
			settings.connect("settings_changed", _on_settings_changed)


func _on_settings_changed() -> void:
	_update_visibility()
	_update_labels()


func _update_visibility(state: RefCounted = null) -> void:
	var direction_visible := _hud_visible(GooseGameSettings.HUD_DIRECTION_TO_FINISH)
	var timer_visible := _hud_visible(GooseGameSettings.HUD_TIMER)
	var speed_visible := _hud_visible(GooseGameSettings.HUD_SPEED)
	var flight_visible := _hud_visible(GooseGameSettings.HUD_FLIGHT_WIDGET)
	var flight_aim_dot_visible := _hud_visible(GooseGameSettings.HUD_FLIGHT_AIM_DOT)
	var vertical_speed_visible := _hud_visible(GooseGameSettings.HUD_VERTICAL_SPEED)
	var acceleration_visible := _hud_visible(GooseGameSettings.HUD_ACCELERATION)
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
	speed_unit_label.visible = speed_visible
	speedometer_gauge.visible = speed_visible
	flight_widget.visible = flight_visible and _should_show_flight_widget(state)
	flight_aim_dot.visible = flight_aim_dot_visible and _should_show_flight_aim_dot(state)

	var vertical_visible := vertical_speed_visible and _should_show_vertical_speed_widget(state)
	vertical_speed_gauge.visible = vertical_visible
	acceleration_gauge.visible = acceleration_visible
	movement_panel.visible = (
		speed_label.visible
		or flight_widget.visible
		or vertical_visible
		or acceleration_visible
	)

	state_label.visible = state_visible
	fps_label.visible = fps_visible
	raw_movement_label.visible = raw_visible
	surface_flags_label.visible = surface_flags_visible
	input_state_label.visible = input_visible
	debug_panel.visible = state_visible or raw_visible or surface_flags_visible or input_visible


func _update_labels() -> void:
	var state := _get_movement_state()
	_update_visibility(state)
	_update_direction_marker(state)
	speed_label.text = "%.1f" % state.horizontal_speed
	if speedometer_gauge.has_method("set_speed"):
		speedometer_gauge.set_speed(state.horizontal_speed)
	timer_label.text = "%05.2fs" % elapsed_time
	coin_label.text = _format_coin_count()
	_update_flight_widget(state)
	if vertical_speed_gauge.has_method("set_vertical_speed"):
		vertical_speed_gauge.set_vertical_speed(state.vertical_speed)
	if acceleration_gauge.has_method("set_acceleration"):
		acceleration_gauge.set_acceleration(acceleration)
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


func _format_coin_count() -> String:
	if coin_target > 0:
		return "%d / %d" % [coin_count, coin_target]
	return str(coin_count)


func _update_acceleration(delta: float) -> void:
	if delta <= 0.0:
		return
	var state := _get_movement_state()
	var horizontal_velocity := Vector2(state.velocity.x, state.velocity.z)
	if has_previous_velocity:
		var raw_acceleration := (horizontal_velocity - previous_horizontal_velocity).length() / delta
		var blend := 1.0 - exp(-ACCELERATION_SMOOTHNESS * delta)
		acceleration = lerpf(acceleration, raw_acceleration, blend)
	previous_horizontal_velocity = horizontal_velocity
	has_previous_velocity = true


func _update_direction_marker(_state: RefCounted) -> void:
	if not direction_panel.visible or finish_target == null:
		return
	var camera := get_viewport().get_camera_3d()
	var active_controller := _get_active_controller()
	if camera == null or active_controller == null:
		direction_panel.visible = false
		return

	var target_position := finish_target.global_position
	var target_delta := target_position - active_controller.global_position
	target_delta.y = 0.0
	if target_delta.length_squared() < 0.001:
		target_delta = -camera.global_transform.basis.z
	target_delta = target_delta.normalized()

	var camera_forward := -camera.global_transform.basis.z
	camera_forward.y = 0.0
	if camera_forward.length_squared() < 0.001:
		camera_forward = Vector3.FORWARD
	camera_forward = camera_forward.normalized()

	var camera_heading := _world_bearing(camera_forward)
	var target_heading := _world_bearing(target_delta)
	_roll_compass_strip(camera_heading)
	_update_finish_icon_position(target_heading, camera_heading)
	direction_label.text = "%dm" % int(round(active_controller.global_position.distance_to(target_position)))


func _roll_compass_strip(signed_angle: float) -> void:
	var target_x := _compass_target_x(signed_angle)
	compass_strip.position.x = COMPASS_CLIP_CENTER_X - target_x


func _update_finish_icon_position(target_heading: float, camera_heading: float) -> void:
	var relative_angle := _wrap_angle(target_heading - camera_heading)
	var visible_half_width := compass_clip.size.x * 0.5
	var marker_center_x := visible_half_width + (relative_angle / PI) * visible_half_width
	var icon_width := finish_icon.size.x
	if icon_width <= 0.0:
		icon_width = 50.0
	var max_x: float = max(compass_clip.size.x - icon_width, 0.0)
	finish_icon.position = Vector2(
		clampf(marker_center_x - icon_width * 0.5, 0.0, max_x),
		finish_icon_base_y
	)


func _compass_target_x(signed_angle: float) -> float:
	var wrapped_angle := _wrap_angle(signed_angle)
	return COMPASS_CENTER_N_X + (wrapped_angle / TAU) * COMPASS_CYCLE_WIDTH


func _wrap_angle(angle: float) -> float:
	return fposmod(angle + PI, TAU) - PI


func _world_bearing(direction: Vector3) -> float:
	return atan2(direction.dot(Vector3.RIGHT), direction.dot(Vector3.FORWARD))


func _update_flight_widget(state: RefCounted) -> void:
	if not flight_widget.visible:
		return
	var flight_debug := _get_flight_debug_state()
	var remaining := float(flight_debug.get("flap_cooldown_remaining", 0.0))
	var cooldown := float(flight_debug.get("flap_cooldown", 0.0))
	if cooldown <= 0.0 or not _should_show_flight_widget(state):
		flight_widget.visible = false
		return
	if flap_cooldown_gauge.has_method("set_cooldown"):
		flap_cooldown_gauge.set_cooldown(cooldown, remaining)


func _should_show_flight_widget(state: RefCounted = null) -> bool:
	var flight_debug := _get_flight_debug_state()
	var cooldown := float(flight_debug.get("flap_cooldown", 0.0))
	var remaining := float(flight_debug.get("flap_cooldown_remaining", 0.0))
	if cooldown <= 0.0:
		return false
	if remaining > 0.0:
		return true
	return _state_is_flight_relevant(state)


func _state_is_flight_relevant(state: RefCounted) -> bool:
	if state == null:
		return false
	return (
		bool(state.get("flight_activation_charging"))
		or bool(state.get("gliding"))
		or bool(state.get("flapping"))
	)


func _should_show_vertical_speed_widget(state: RefCounted) -> bool:
	if state == null:
		return false
	return (
		bool(state.get("gliding"))
		or bool(state.get("flapping"))
		or bool(state.get("flight_activation_charging"))
	)


func _should_show_flight_aim_dot(state: RefCounted) -> bool:
	return state != null and StringName(state.get("mode")) == &"flight"


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


func _ensure_countdown_rect() -> void:
	if countdown_rect != null:
		return
	countdown_rect = TextureRect.new()
	countdown_rect.name = "LevelStartCountdown"
	countdown_rect.visible = false
	countdown_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	countdown_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	countdown_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	countdown_rect.z_index = 100
	root.add_child(countdown_rect)


func _update_controls_hint_bindings() -> void:
	var jump_binding := _primary_binding_label(&"player_jump", "Space")
	var flap_binding := _primary_binding_label(&"player_flap", jump_binding)
	move_hint_key_label.text = _movement_binding_label()
	jump_hint_key_label.text = jump_binding
	slide_hint_key_label.text = _primary_binding_label(&"player_crouch", "Ctrl")
	honk_hint_key_label.text = _primary_binding_label(&"player_honk", "Q")
	if flap_binding == jump_binding:
		jump_hint_action_label.text = "Jump / Hold to Fly"
		flap_hint_item.visible = false
	else:
		jump_hint_action_label.text = "Jump"
		flap_hint_key_label.text = flap_binding
		flap_hint_item.visible = true


func _movement_binding_label() -> String:
	var forward := _primary_binding_label(&"player_forward", "W")
	var left := _primary_binding_label(&"player_left", "A")
	var back := _primary_binding_label(&"player_back", "S")
	var right := _primary_binding_label(&"player_right", "D")
	if forward == "W" and left == "A" and back == "S" and right == "D":
		return "WASD"
	if forward == "Up" and left == "Left" and back == "Down" and right == "Right":
		return "Arrows"
	return "%s/%s/%s/%s" % [forward, left, back, right]


func _primary_binding_label(action: StringName, fallback: String) -> String:
	if not InputMap.has_action(action):
		return fallback
	var events := InputMap.action_get_events(action)
	for event in events:
		var key_event := event as InputEventKey
		if key_event != null:
			return _key_event_label(key_event, fallback)
	for event in events:
		var mouse_event := event as InputEventMouseButton
		if mouse_event != null:
			return _mouse_button_label(mouse_event.button_index)
	for event in events:
		var joy_button := event as InputEventJoypadButton
		if joy_button != null:
			return _joy_button_label(joy_button.button_index)
	for event in events:
		var joy_motion := event as InputEventJoypadMotion
		if joy_motion != null:
			return _joy_motion_label(joy_motion)
	return fallback


func _key_event_label(event: InputEventKey, fallback: String) -> String:
	var keycode := event.physical_keycode if event.physical_keycode != 0 else event.keycode
	if keycode == 0:
		return fallback
	match keycode:
		KEY_UP:
			return "Up"
		KEY_DOWN:
			return "Down"
		KEY_LEFT:
			return "Left"
		KEY_RIGHT:
			return "Right"
		_:
			var label := OS.get_keycode_string(keycode)
			return fallback if label.is_empty() else label


func _mouse_button_label(button: MouseButton) -> String:
	match button:
		MOUSE_BUTTON_LEFT:
			return "Mouse 1"
		MOUSE_BUTTON_RIGHT:
			return "Mouse 2"
		MOUSE_BUTTON_MIDDLE:
			return "Mouse 3"
		_:
			return "Mouse %d" % int(button)


func _joy_button_label(button: JoyButton) -> String:
	match button:
		JOY_BUTTON_A:
			return "Pad A"
		JOY_BUTTON_B:
			return "Pad B"
		JOY_BUTTON_X:
			return "Pad X"
		JOY_BUTTON_Y:
			return "Pad Y"
		JOY_BUTTON_LEFT_SHOULDER:
			return "LB"
		JOY_BUTTON_RIGHT_SHOULDER:
			return "RB"
		_:
			return "Pad %d" % int(button)


func _joy_motion_label(event: InputEventJoypadMotion) -> String:
	if event.axis == JOY_AXIS_LEFT_X:
		return "LS X"
	if event.axis == JOY_AXIS_LEFT_Y:
		return "LS Y"
	return "Axis %d" % int(event.axis)


func _play_countdown_step(texture: Texture2D) -> void:
	if texture == null:
		return
	var layout := _get_countdown_layout(texture)
	countdown_rect.texture = texture
	countdown_rect.size = layout["size"]
	countdown_rect.position = layout["start"]
	countdown_rect.modulate.a = 1.0
	countdown_rect.visible = true

	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_BOUND)
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(countdown_rect, "position", layout["center"], COUNTDOWN_SLIDE_DURATION)
	await tween.finished
	await get_tree().create_timer(COUNTDOWN_CENTER_HOLD_DURATION, false).timeout

	tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_BOUND)
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(countdown_rect, "position", layout["end"], COUNTDOWN_SLIDE_DURATION)
	await tween.finished


func _get_countdown_layout(texture: Texture2D) -> Dictionary:
	var viewport_size := root.size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = get_viewport().get_visible_rect().size
	var texture_size := texture.get_size()
	var aspect := texture_size.x / maxf(texture_size.y, 1.0)
	var width: float = minf(COUNTDOWN_MAX_WIDTH, viewport_size.x * COUNTDOWN_SCREEN_WIDTH_SCALE)
	var height := width / maxf(aspect, 0.001)
	var max_height := viewport_size.y * COUNTDOWN_SCREEN_HEIGHT_SCALE
	if height > max_height:
		height = max_height
		width = height * aspect
	var size := Vector2(width, height)
	var center := (viewport_size - size) * 0.5
	return {
		"size": size,
		"start": Vector2(viewport_size.x + size.x, center.y),
		"center": center,
		"end": Vector2(-size.x, center.y),
	}

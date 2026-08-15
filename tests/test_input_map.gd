extends SceneTree

const REQUIRED_ACTIONS := [
	&"player_forward",
	&"player_back",
	&"player_left",
	&"player_right",
	&"player_jump",
	&"player_flap",
	&"player_crouch",
	&"player_special",
	&"player_walk",
	&"player_reset_camera",
	&"player_toggle_camera",
	&"player_honk",
	&"player_restart",
	&"ui_cancel",
]


func _initialize() -> void:
	var settings := root.get_node_or_null("Settings")
	if settings != null:
		settings.set_character_controller_runtime("q3_n_flight")
	var failures: Array[String] = []
	for action in REQUIRED_ACTIONS:
		if not InputMap.has_action(action):
			failures.append("missing action %s" % action)
			continue
		if InputMap.action_get_events(action).is_empty():
			failures.append("action %s has no events" % action)
	if not _action_has_joy_motion(&"player_forward", JOY_AXIS_LEFT_Y, -1.0):
		failures.append("player_forward has no left-stick forward binding")
	if not _action_has_joy_motion(&"player_back", JOY_AXIS_LEFT_Y, 1.0):
		failures.append("player_back has no left-stick back binding")
	if not _action_has_joy_motion(&"player_left", JOY_AXIS_LEFT_X, -1.0):
		failures.append("player_left has no left-stick left binding")
	if not _action_has_joy_motion(&"player_right", JOY_AXIS_LEFT_X, 1.0):
		failures.append("player_right has no left-stick right binding")
	if not _action_has_joy_button(&"player_flap", JOY_BUTTON_A):
		failures.append("player_flap has no gamepad A binding")
	if not _action_has_joy_button(&"player_honk", JOY_BUTTON_B):
		failures.append("player_honk has no gamepad B binding")

	if failures.is_empty():
		print("Input map OK: %d actions" % REQUIRED_ACTIONS.size())
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _action_has_joy_button(action: StringName, button_index: JoyButton) -> bool:
	for event in InputMap.action_get_events(action):
		var joy_button := event as InputEventJoypadButton
		if joy_button != null and joy_button.button_index == button_index:
			return true
	return false


func _action_has_joy_motion(action: StringName, axis: JoyAxis, axis_value: float) -> bool:
	for event in InputMap.action_get_events(action):
		var joy_motion := event as InputEventJoypadMotion
		if (
			joy_motion != null
			and joy_motion.axis == axis
			and signf(joy_motion.axis_value) == signf(axis_value)
		):
			return true
	return false

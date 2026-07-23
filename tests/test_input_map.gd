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
	var failures: Array[String] = []
	for action in REQUIRED_ACTIONS:
		if not InputMap.has_action(action):
			failures.append("missing action %s" % action)
			continue
		if InputMap.action_get_events(action).is_empty():
			failures.append("action %s has no events" % action)

	if failures.is_empty():
		print("Input map OK: %d actions" % REQUIRED_ACTIONS.size())
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

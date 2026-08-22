extends Node

const PLAYER_SCENE := preload("res://scenes/player/goose_player_root.tscn")
const HUD_SCENE := preload("res://scenes/ui/goose_game_hud.tscn")
const MovementStateScript := preload("res://scripts/player/movement_state.gd")

class FakeStateBridge:
	extends Node

	var velocity := Vector3.ZERO

	func get_state() -> RefCounted:
		var state := MovementStateScript.new()
		state.velocity = velocity
		return state


func _ready() -> void:
	var player := PLAYER_SCENE.instantiate()
	var hud := HUD_SCENE.instantiate()
	add_child(player)
	add_child(hud)
	await get_tree().process_frame

	hud.set_player(player)
	hud.set_coin_target(10)
	hud.set_run_state(12.34, true)
	hud.set_coin_count(7)
	await get_tree().process_frame

	if hud.get_node_or_null("Root/TopLeftPanel") != null:
		push_error("HUD top-left status panel should be removed")
		get_tree().quit(1)
		return
	if hud.get_node_or_null("Root/FpsLabel") == null:
		push_error("HUD FPS label should be a standalone small label")
		get_tree().quit(1)
		return
	if hud.get_node_or_null("Root/DebugPanel/Margin/VBox/FpsLabel") != null:
		push_error("HUD FPS label should not be inside the debug panel")
		get_tree().quit(1)
		return
	if not _label_contains(hud, "Root/TimerWidget/HBoxContainer/TimerLabel", "12.34"):
		push_error("HUD timer label did not use run state")
		get_tree().quit(1)
		return
	if not _label_contains(hud, "Root/TimerWidget/CoinsRow/CoinLabel", "7 / 10"):
		push_error("HUD coin label did not use coin count")
		get_tree().quit(1)
		return
	var speedometer := hud.get_node_or_null("Root/MovementWidget/SpeedometerGauge")
	if speedometer == null or not speedometer.has_method("set_speed"):
		push_error("HUD speedometer gauge is missing")
		get_tree().quit(1)
		return
	speedometer.set_speed(12.0)
	if not is_equal_approx(float(speedometer.get("current_speed")), 12.0):
		push_error("HUD speedometer gauge did not accept speed data")
		get_tree().quit(1)
		return
	var flap_gauge := hud.get_node_or_null("Root/MovementWidget/FlightWidget/FlapCooldownGauge")
	if flap_gauge == null or not flap_gauge.has_method("set_cooldown"):
		push_error("HUD flap cooldown gauge is missing")
		get_tree().quit(1)
		return
	flap_gauge.set_cooldown(2.0, 0.5)
	if (
		not is_equal_approx(float(flap_gauge.get("cooldown_duration")), 2.0)
		or not is_equal_approx(float(flap_gauge.get("cooldown_remaining")), 0.5)
	):
		push_error("HUD flap cooldown gauge did not accept cooldown data")
		get_tree().quit(1)
		return
	var acceleration_gauge := hud.get_node_or_null("Root/MovementWidget/AccelerationGauge")
	if acceleration_gauge == null or not acceleration_gauge.has_method("set_acceleration"):
		push_error("HUD acceleration gauge is missing")
		get_tree().quit(1)
		return
	acceleration_gauge.set_acceleration(16.0)
	if not is_equal_approx(float(acceleration_gauge.get("current_acceleration")), 16.0):
		push_error("HUD acceleration gauge did not accept acceleration data")
		get_tree().quit(1)
		return
	acceleration_gauge.set_acceleration(0.4)
	if int(acceleration_gauge._active_segment_count()) != 1:
		push_error("HUD acceleration gauge did not show gentle straight-run acceleration")
		get_tree().quit(1)
		return
	acceleration_gauge.set_acceleration(5.0)
	if int(acceleration_gauge._active_segment_count()) != 2:
		push_error("HUD acceleration gauge gradation is too sensitive for moderate turns")
		get_tree().quit(1)
		return
	acceleration_gauge.set_acceleration(22.0)
	if int(acceleration_gauge._active_segment_count()) != 5:
		push_error("HUD acceleration gauge did not fill at high acceleration")
		get_tree().quit(1)
		return
	if not _hud_acceleration_uses_smoothed_horizontal_velocity(hud):
		get_tree().quit(1)
		return
	var vertical_gauge := hud.get_node_or_null("Root/MovementWidget/VerticalSpeedGauge")
	if vertical_gauge == null or not vertical_gauge.has_method("set_vertical_speed"):
		push_error("HUD vertical speed gauge is missing")
		get_tree().quit(1)
		return
	vertical_gauge.set_vertical_speed(-3.5)
	if not is_equal_approx(float(vertical_gauge.get("current_vertical_speed")), -3.5):
		push_error("HUD vertical speed gauge did not accept vertical speed data")
		get_tree().quit(1)
		return
	if not _controls_hint_uses_current_flap_binding(hud):
		get_tree().quit(1)
		return
	hud.play_level_start_countdown(true)
	await get_tree().process_frame
	if not hud.is_level_start_countdown_playing():
		push_error("HUD countdown did not start")
		get_tree().quit(1)
		return
	var controls_hint := hud.get_node_or_null("Root/ControlsHintPanel") as Control
	if controls_hint == null or not controls_hint.visible:
		push_error("HUD countdown controls hint did not appear when requested")
		get_tree().quit(1)
		return
	if not _node_tree_contains_text(controls_hint, "Space") or not _node_tree_contains_text(controls_hint, "Jump / Hold to Fly"):
		push_error("HUD countdown controls hint did not include the flight control text")
		get_tree().quit(1)
		return
	var flap_hint := controls_hint.get_node_or_null("Margin/Row/FlapHint") as Control
	if flap_hint == null:
		push_error("HUD countdown controls hint is missing the flap binding row")
		get_tree().quit(1)
		return
	get_tree().paused = true
	await get_tree().create_timer(4.5, true).timeout
	if not hud.is_level_start_countdown_playing():
		get_tree().paused = false
		push_error("HUD countdown completed while paused")
		get_tree().quit(1)
		return
	get_tree().paused = false
	if not await _wait_for_countdown_complete(hud):
		push_error("HUD countdown did not complete after unpausing")
		get_tree().quit(1)
		return
	if controls_hint.visible:
		push_error("HUD countdown controls hint did not hide after countdown")
		get_tree().quit(1)
		return
	print("Goose game HUD OK")
	get_tree().quit(0)


func _label_contains(root: Node, path: NodePath, expected_text: String) -> bool:
	var label := root.get_node_or_null(path) as Label
	return label != null and label.text.contains(expected_text)


func _node_tree_contains_text(root: Node, expected_text: String) -> bool:
	var label := root as Label
	if label != null and label.text.contains(expected_text):
		return true
	for child in root.get_children():
		if _node_tree_contains_text(child, expected_text):
			return true
	return false


func _hud_acceleration_uses_smoothed_horizontal_velocity(hud: Node) -> bool:
	var original_state_bridge = hud.get("state_bridge")
	var fake_bridge := FakeStateBridge.new()
	add_child(fake_bridge)
	hud.set("state_bridge", fake_bridge)
	hud.set("has_previous_velocity", false)
	hud.set("acceleration", 0.0)

	fake_bridge.velocity = Vector3.ZERO
	hud._update_acceleration(0.1)
	fake_bridge.velocity = Vector3(0.0, 30.0, 0.0)
	hud._update_acceleration(0.1)
	if float(hud.get("acceleration")) > 0.001:
		push_error("HUD acceleration should ignore vertical-only velocity changes")
		hud.set("state_bridge", original_state_bridge)
		fake_bridge.queue_free()
		return false

	fake_bridge.velocity = Vector3(3.0, 30.0, 0.0)
	hud._update_acceleration(0.1)
	if float(hud.get("acceleration")) <= 0.0:
		push_error("HUD acceleration should still show horizontal velocity changes")
		hud.set("state_bridge", original_state_bridge)
		fake_bridge.queue_free()
		return false

	hud.set("state_bridge", original_state_bridge)
	fake_bridge.queue_free()
	return true


func _controls_hint_uses_current_flap_binding(hud: Node) -> bool:
	var original_events := InputMap.action_get_events(&"player_flap")
	InputMap.action_erase_events(&"player_flap")
	var flap_key := InputEventKey.new()
	flap_key.physical_keycode = KEY_F
	InputMap.action_add_event(&"player_flap", flap_key)
	hud._update_controls_hint_bindings()
	var jump_action_label := hud.get_node_or_null(
		"Root/ControlsHintPanel/Margin/Row/JumpHint/ActionLabel"
	) as Label
	var flap_hint := hud.get_node_or_null("Root/ControlsHintPanel/Margin/Row/FlapHint") as Control
	var flap_key_label := hud.get_node_or_null("Root/ControlsHintPanel/Margin/Row/FlapHint/KeyLabel") as Label
	var valid := (
		jump_action_label != null
		and jump_action_label.text == "Jump"
		and flap_hint != null
		and flap_hint.visible
		and flap_key_label != null
		and flap_key_label.text == "F"
	)
	InputMap.action_erase_events(&"player_flap")
	for event in original_events:
		InputMap.action_add_event(&"player_flap", event)
	hud._update_controls_hint_bindings()
	if not valid:
		push_error("HUD controls hint did not use the current separate flap binding")
	return valid


func _wait_for_countdown_complete(hud: Node) -> bool:
	var deadline := Time.get_ticks_msec() + 10000
	while Time.get_ticks_msec() < deadline:
		if not hud.is_level_start_countdown_playing():
			return true
		await get_tree().create_timer(0.05).timeout
	return false

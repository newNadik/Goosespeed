class_name GooseVisualDebugOverlay
extends Node3D

var player: Node
var state_bridge: Node
var visual_controller: Node
var label: RichTextLabel


func _ready() -> void:
	_setup_canvas()
	set_process(false)


func set_player(value: Node) -> void:
	player = value
	state_bridge = player.get_node_or_null("MovementStateBridge") if player != null else null
	visual_controller = player.get_node_or_null("GooseVisual") if player != null else null
	set_process(player != null and state_bridge != null)


func _process(_delta: float) -> void:
	if player == null or state_bridge == null:
		return
	var state: RefCounted = state_bridge.get_state()
	_update_label(state)


func _setup_canvas() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "DebugCanvas"
	add_child(canvas)

	var root := Control.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(root)

	var panel := PanelContainer.new()
	panel.name = "StatePanel"
	panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	panel.offset_left = -360.0
	panel.offset_right = 360.0
	panel.offset_top = 12.0
	panel.offset_bottom = 126.0
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	label = RichTextLabel.new()
	label.name = "StateLabel"
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.add_theme_font_size_override("font_size", 15)
	margin.add_child(label)


func _update_label(state: RefCounted) -> void:
	var flight_debug := _get_flight_debug_state()
	label.text = "\n".join([
		"[center][b]%s[/b][/center]" % _get_visual_state_name(state),
		"[center]contact  %s[/center]" % _format_flags(state, [
			&"grounded",
			&"airborne",
			&"swimming",
			&"sliding",
			&"crouching",
			&"crouch_sliding",
		]),
		"[center]flight   %s[/center]" % _format_flags(state, [
			&"flight_activation_charging",
			&"just_entered_flight",
			&"just_exited_flight",
			&"gliding",
				&"flapping",
				&"falling",
			]),
			"[center]flap cd %s[/center]" % _format_flap_cooldown(flight_debug),
		])


func _format_flags(state: RefCounted, flags: Array[StringName]) -> String:
	var parts: Array[String] = []
	for flag in flags:
		parts.append(_format_flag(str(flag), bool(state.get(str(flag)))))
	return "  ".join(parts)


func _format_flag(flag_name: String, active: bool) -> String:
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


func _get_flight_debug_state() -> Dictionary:
	var controller: Node = player.get_active_controller() if player != null and player.has_method("get_active_controller") else null
	if controller != null and controller.has_method("get_flight_debug_state"):
		return controller.get_flight_debug_state()
	return {}


func _get_visual_state_name(state: RefCounted) -> String:
	if visual_controller != null and visual_controller.has_method("visual_state_for_state"):
		return str(visual_controller.visual_state_for_state(state))
	return "unknown"


func _get_current_animation_name() -> String:
	if visual_controller == null:
		return ""
	var animation_player := visual_controller.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if animation_player == null:
		return ""
	return animation_player.current_animation

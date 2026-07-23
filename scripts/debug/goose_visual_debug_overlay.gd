class_name GooseVisualDebugOverlay
extends Node3D

const FACING_COLOR := Color(0.2, 0.55, 1.0, 1.0)
const VELOCITY_COLOR := Color(0.1, 0.95, 0.35, 1.0)

@export var vertical_offset := 1.25
@export var facing_arrow_length := 2.0
@export var velocity_arrow_scale := 0.22
@export var max_velocity_arrow_length := 4.0

var player: Node
var state_bridge: Node
var visual_controller: Node
var label: RichTextLabel
var facing_arrow: MeshInstance3D
var velocity_arrow: MeshInstance3D
var facing_material := StandardMaterial3D.new()
var velocity_material := StandardMaterial3D.new()


func _ready() -> void:
	_setup_materials()
	_setup_canvas()
	_setup_arrows()
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
	_update_arrows(state)


func _setup_materials() -> void:
	_configure_material(facing_material, FACING_COLOR)
	_configure_material(velocity_material, VELOCITY_COLOR)


func _configure_material(material: StandardMaterial3D, color: Color) -> void:
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color


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


func _setup_arrows() -> void:
	facing_arrow = _create_arrow("FacingArrow", facing_material)
	velocity_arrow = _create_arrow("VelocityArrow", velocity_material)


func _create_arrow(node_name: String, material: Material) -> MeshInstance3D:
	var arrow := MeshInstance3D.new()
	arrow.name = node_name
	arrow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	arrow.material_override = material
	add_child(arrow)
	return arrow


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
		"[center]flap cd %s   [color=#338cff]blue facing[/color]   [color=#1df05a]green velocity[/color][/center]" % _format_flap_cooldown(flight_debug),
	])


func _update_arrows(state: RefCounted) -> void:
	var origin: Vector3 = state.position + Vector3.UP * vertical_offset
	var facing_direction := _horizontal_direction(state.facing_direction as Vector3)
	_set_arrow(facing_arrow, origin, facing_direction, facing_arrow_length)

	var velocity_direction := _velocity_direction(state)
	var velocity_length := _velocity_length(state)
	_set_arrow(velocity_arrow, origin + Vector3.UP * 0.18, velocity_direction, velocity_length)


func _set_arrow(arrow: MeshInstance3D, origin: Vector3, direction: Vector3, length: float) -> void:
	if direction.is_zero_approx() or length <= 0.01:
		arrow.visible = false
		return
	arrow.visible = true
	var end := origin + direction.normalized() * length
	var side_axis := direction.cross(Vector3.UP)
	if side_axis.length_squared() < 0.0001:
		side_axis = direction.cross(Vector3.RIGHT)
	var side := side_axis.normalized() * minf(length * 0.16, 0.35)
	var back := direction.normalized() * minf(length * 0.28, 0.55)

	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	mesh.surface_add_vertex(origin)
	mesh.surface_add_vertex(end)
	mesh.surface_add_vertex(end)
	mesh.surface_add_vertex(end - back + side)
	mesh.surface_add_vertex(end)
	mesh.surface_add_vertex(end - back - side)
	mesh.surface_end()
	arrow.mesh = mesh


func _horizontal_direction(value: Vector3) -> Vector3:
	var result := Vector3(value.x, 0.0, value.z)
	return result.normalized() if not result.is_zero_approx() else Vector3.ZERO


func _velocity_direction(state: RefCounted) -> Vector3:
	var velocity := state.velocity as Vector3
	if state.mode == &"flight":
		return velocity.normalized() if not velocity.is_zero_approx() else Vector3.ZERO
	return _horizontal_direction(velocity)


func _velocity_length(state: RefCounted) -> float:
	var velocity := state.velocity as Vector3
	var speed: float = velocity.length() if state.mode == &"flight" else state.horizontal_speed
	return clampf(speed * velocity_arrow_scale, 0.0, max_velocity_arrow_length)


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

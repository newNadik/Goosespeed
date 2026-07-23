class_name MovementState
extends RefCounted

var position := Vector3.ZERO
var velocity := Vector3.ZERO
var horizontal_speed := 0.0
var vertical_speed := 0.0
var facing_direction := Vector3.FORWARD
var grounded := false
var airborne := true
var swimming := false
var water_level := 0
var sliding := false
var crouching := false
var crouch_sliding := false
var gliding := false
var flapping := false
var falling := false
var wall_contact := false
var ceiling_contact := false
var flight_activation_charging := false
var flight_activation_charge := 0.0
var flight_activation_threshold := 0.0
var just_landed := false
var just_took_off := false
var just_entered_flight := false
var just_exited_flight := false
var hard_landed := false
var crashed := false
var knocked_down := false
var landing_horizontal_speed := 0.0
var landing_vertical_impact_speed := 0.0
var landing_surface_normal := Vector3.UP
var landing_carry_active := false
var landing_carry_time_remaining := 0.0
var takeoff_horizontal_speed := 0.0
var takeoff_vertical_speed := 0.0
var crash_impact_speed := 0.0
var crash_surface_normal := Vector3.ZERO
var crash_recovery_time_remaining := 0.0
var surface_type: StringName = &"default"
var medium_type: StringName = &"air"
var mode: StringName = &""
var controller: StringName = &""
var water_type: StringName = &""
var landing_surface_type: StringName = &""


func copy_from(other) -> void:
	position = _read(other, "position", position) as Vector3
	velocity = _read(other, "velocity", velocity) as Vector3
	horizontal_speed = float(_read(other, "horizontal_speed", Vector2(velocity.x, velocity.z).length()))
	vertical_speed = float(_read(other, "vertical_speed", velocity.y))
	facing_direction = _read(other, "facing_direction", facing_direction) as Vector3
	grounded = bool(_read(other, "grounded", grounded))
	airborne = bool(_read(other, "airborne", not grounded))
	swimming = bool(_read(other, "swimming", swimming))
	water_level = int(_read(other, "water_level", water_level))
	crouching = bool(_read(other, "crouching", crouching))
	crouch_sliding = bool(_read(other, "crouch_sliding", _read(other, "sliding", crouch_sliding)))
	sliding = bool(_read(other, "sliding", crouch_sliding))
	flapping = bool(_read(other, "flapping", flapping))
	gliding = bool(_read(other, "gliding", _read(other, "mode", mode) == "flight")) and not flapping
	falling = bool(_read(other, "falling", not grounded and vertical_speed < -0.2))
	wall_contact = bool(_read(other, "wall_contact", wall_contact))
	ceiling_contact = bool(_read(other, "ceiling_contact", ceiling_contact))
	flight_activation_charging = bool(_read(other, "flight_activation_charging", flight_activation_charging))
	flight_activation_charge = float(_read(other, "flight_activation_charge", flight_activation_charge))
	flight_activation_threshold = float(_read(other, "flight_activation_threshold", flight_activation_threshold))
	just_landed = bool(_read(other, "just_landed", just_landed))
	just_took_off = bool(_read(other, "just_took_off", just_took_off))
	just_entered_flight = bool(_read(other, "just_entered_flight", just_entered_flight))
	just_exited_flight = bool(_read(other, "just_exited_flight", just_exited_flight))
	hard_landed = bool(_read(other, "hard_landed", hard_landed))
	crashed = bool(_read(other, "crashed", crashed))
	knocked_down = bool(_read(other, "knocked_down", knocked_down))
	landing_horizontal_speed = float(_read(other, "landing_horizontal_speed", landing_horizontal_speed))
	landing_vertical_impact_speed = float(_read(other, "landing_vertical_impact_speed", landing_vertical_impact_speed))
	landing_surface_normal = _read(other, "landing_surface_normal", landing_surface_normal) as Vector3
	landing_carry_active = bool(_read(other, "landing_carry_active", landing_carry_active))
	landing_carry_time_remaining = float(_read(other, "landing_carry_time_remaining", landing_carry_time_remaining))
	takeoff_horizontal_speed = float(_read(other, "takeoff_horizontal_speed", takeoff_horizontal_speed))
	takeoff_vertical_speed = float(_read(other, "takeoff_vertical_speed", takeoff_vertical_speed))
	crash_impact_speed = float(_read(other, "crash_impact_speed", crash_impact_speed))
	crash_surface_normal = _read(other, "crash_surface_normal", crash_surface_normal) as Vector3
	crash_recovery_time_remaining = float(_read(other, "crash_recovery_time_remaining", crash_recovery_time_remaining))
	surface_type = StringName(_read(other, "surface_type", surface_type))
	medium_type = StringName(_read(other, "medium_type", medium_type))
	mode = StringName(_read(other, "mode", mode))
	controller = StringName(_read(other, "controller", controller))
	water_type = StringName(_read(other, "water_type", water_type))
	landing_surface_type = StringName(_read(other, "landing_surface_type", landing_surface_type))

	if swimming:
		medium_type = &"water"
	if water_type != &"":
		medium_type = water_type
	if landing_surface_type != &"":
		surface_type = landing_surface_type
	if mode == &"flight" and not flapping:
		gliding = true
	airborne = not grounded


func duplicate_state() -> RefCounted:
	var result: RefCounted = get_script().new()
	result.copy_from(self)
	return result


func _read(source, key: String, default_value):
	if source is Dictionary:
		return source.get(key, default_value)
	var value = source.get(key)
	return default_value if value == null else value

class_name HudSpeedometerGauge
extends Control

const GAUGE_FONT := preload("res://assets/ui/fonts/Condor_Medium.otf")
const ARC_DEGREES := 135.0
const START_DEGREES := -180.0
const TICK_VALUES := [0.0, 6.0, 12.0, 18.0, 24.0, 30.0, 36.0]
const MAJOR_TICK_VALUES := [0.0, 12.0, 24.0, 36.0]

@export var max_speed := 36.0

var current_speed := 0.0


func set_speed(value: float) -> void:
	current_speed = maxf(value, 0.0)
	queue_redraw()


func _draw() -> void:
	var arc_color := Color(0.09411765, 0.18431373, 0.26666668, 0.88)
	var outline_color := Color(0.94509804, 0.8745098, 0.7411765, 0.85)
	var needle_color := Color(0.99607843, 0.46666667, 0.2627451, 1.0)
	var center := Vector2(size.x * 0.43, size.y * 0.93)
	var radius: float = minf(size.x * 0.4, size.y * 0.78)
	var start_angle := deg_to_rad(START_DEGREES)
	var end_angle := deg_to_rad(START_DEGREES + ARC_DEGREES)
	var arc_outline_width := maxf(8.0, radius * 0.055)
	var arc_width := maxf(4.0, radius * 0.025)

	draw_arc(center + Vector2(0, 2), radius, start_angle, end_angle, 56, outline_color, arc_outline_width, true)
	draw_arc(center, radius, start_angle, end_angle, 56, arc_color, arc_width, true)
	_draw_ticks(center, radius, arc_color, outline_color)
	_draw_needle(center, radius, start_angle, end_angle, needle_color, outline_color)


func _draw_ticks(center: Vector2, radius: float, arc_color: Color, outline_color: Color) -> void:
	for tick_value in TICK_VALUES:
		var ratio := clampf(float(tick_value) / max_speed, 0.0, 1.0)
		var angle := deg_to_rad(START_DEGREES + ARC_DEGREES * ratio)
		var direction := Vector2(cos(angle), sin(angle))
		var is_major: bool = tick_value in MAJOR_TICK_VALUES
		var tick_length := radius * 0.078 if is_major else radius * 0.045
		var width := maxf(3.0, radius * 0.016) if is_major else maxf(2.0, radius * 0.011)
		var outer := center + direction * (radius + 2.0)
		var inner := center + direction * (radius - tick_length)

		draw_line(outer + Vector2(0, 1), inner + Vector2(0, 1), outline_color, width + 2.0, true)
		draw_line(outer, inner, arc_color, width, true)

		var label := str(int(tick_value))
		var font_size := int(clampf(radius * (0.15 if is_major else 0.115), 16.0, 30.0))
		var label_size := GAUGE_FONT.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
		var label_radius := radius - radius * (0.2 if is_major else 0.14)
		var label_position := center + direction * label_radius - label_size * 0.5
		_draw_outlined_string(
			GAUGE_FONT,
			label_position + Vector2(0, label_size.y),
			label,
			font_size,
			arc_color,
			outline_color
		)


func _draw_needle(center: Vector2, radius: float, start_angle: float, end_angle: float, needle_color: Color, outline_color: Color) -> void:
	var ratio := clampf(current_speed / max_speed, 0.0, 1.0)
	var angle := lerpf(start_angle, end_angle, ratio)
	var direction := Vector2(cos(angle), sin(angle))
	var perpendicular := Vector2(-direction.y, direction.x)
	var tip := center + direction * (radius - radius * 0.075)
	var tail := radius * 0.032
	var half_width := radius * 0.025
	var left := center - direction * tail + perpendicular * half_width
	var right := center - direction * tail - perpendicular * half_width

	draw_colored_polygon(PackedVector2Array([tip + Vector2(0, 1), left + Vector2(0, 1), right + Vector2(0, 1)]), outline_color)
	draw_colored_polygon(PackedVector2Array([tip, left, right]), needle_color)
	draw_circle(center + Vector2(0, 1), radius * 0.04, outline_color)
	draw_circle(center, radius * 0.028, needle_color)


func _draw_outlined_string(font: Font, text_position: Vector2, text: String, font_size: int, fill_color: Color, outline_color: Color) -> void:
	var outline_offsets := [
		Vector2(-2, 0),
		Vector2(2, 0),
		Vector2(0, -2),
		Vector2(0, 2),
		Vector2(-1, -1),
		Vector2(1, -1),
		Vector2(-1, 1),
		Vector2(1, 1),
	]
	for offset in outline_offsets:
		draw_string(font, text_position + offset, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, outline_color)
	draw_string(font, text_position, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, fill_color)

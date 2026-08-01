class_name HudVerticalSpeedGauge
extends Control

const VALUE_FONT := preload("res://assets/ui/fonts/Condor_Medium.otf")
const MAX_DISPLAY_SPEED := 12.0

var current_vertical_speed := 0.0


func set_vertical_speed(value: float) -> void:
	current_vertical_speed = value
	queue_redraw()


func _draw() -> void:
	var line_color := Color(0.09411765, 0.18431373, 0.26666668, 0.9)
	var shadow_color := Color(0.94509804, 0.8745098, 0.7411765, 0.86)
	var marker_color := Color(0.99607843, 0.46666667, 0.2627451, 1.0)
	var tape_x := size.x * 0.16
	var top := size.y * 0.14
	var bottom := size.y * 0.86
	var center_y := size.y * 0.5

	_draw_tape_shadow(tape_x, top, center_y, bottom, shadow_color)
	draw_line(Vector2(tape_x, top), Vector2(tape_x, bottom), line_color, 3.0, true)
	_draw_tick(tape_x, top, 9.0, line_color)
	_draw_tick(tape_x, center_y, 16.0, line_color)
	_draw_tick(tape_x, bottom, 9.0, line_color)
	_draw_marker(tape_x, center_y, top, bottom, marker_color)
	_draw_value(center_y, line_color, shadow_color)


func _draw_tape_shadow(tape_x: float, top: float, center_y: float, bottom: float, shadow_color: Color) -> void:
	draw_line(Vector2(tape_x + 1.0, top + 1.0), Vector2(tape_x + 1.0, bottom + 1.0), shadow_color, 5.0, true)
	_draw_tick_shadow(tape_x, top, 9.0, shadow_color)
	_draw_tick_shadow(tape_x, center_y, 16.0, shadow_color)
	_draw_tick_shadow(tape_x, bottom, 9.0, shadow_color)


func _draw_tick_shadow(tape_x: float, y: float, length: float, shadow_color: Color) -> void:
	draw_line(Vector2(tape_x - length + 1.0, y + 1.0), Vector2(tape_x + length + 1.0, y + 1.0), shadow_color, 3.5, true)


func _draw_tick(tape_x: float, y: float, length: float, line_color: Color) -> void:
	draw_line(Vector2(tape_x - length, y), Vector2(tape_x + length, y), line_color, 1.5, true)


func _draw_marker(tape_x: float, center_y: float, top: float, bottom: float, marker_color: Color) -> void:
	var ratio := clampf(current_vertical_speed / MAX_DISPLAY_SPEED, -1.0, 1.0)
	var travel := minf(center_y - top, bottom - center_y)
	var marker_y := center_y - ratio * travel
	var half_width := 19.0
	var radius := 3.0
	draw_rect(
		Rect2(tape_x - half_width + radius, marker_y - radius, half_width * 2.0 - radius * 2.0, radius * 2.0),
		marker_color
	)
	draw_circle(Vector2(tape_x - half_width + radius, marker_y), radius, marker_color)
	draw_circle(Vector2(tape_x + half_width - radius, marker_y), radius, marker_color)


func _draw_value(center_y: float, fill_color: Color, outline_color: Color) -> void:
	var text := "%.1f m/s" % absf(current_vertical_speed)
	var font_size := 30
	var position := Vector2(size.x * 0.42, center_y + font_size * 0.36)
	var offsets := [
		Vector2(-1, 0),
		Vector2(1, 0),
		Vector2(0, -1),
		Vector2(0, 1),
	]
	for offset in offsets:
		draw_string(VALUE_FONT, position + offset, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, outline_color)
	draw_string(VALUE_FONT, position, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, fill_color)

class_name HudAccelerationGauge
extends Control

const SEGMENT_COUNT := 5
const ACCEL_PER_SEGMENT := 8.0

var current_acceleration := 0.0


func set_acceleration(value: float) -> void:
	current_acceleration = maxf(value, 0.0)
	queue_redraw()


func _draw() -> void:
	var active_color := Color(0.99607843, 0.46666667, 0.2627451, 1.0)
	var inactive_color := Color(0.09411765, 0.18431373, 0.26666668, 0.42)
	var outline_color := Color(0.94509804, 0.8745098, 0.7411765, 0.9)
	var active_count := clampi(int(round(current_acceleration / ACCEL_PER_SEGMENT)), 0, SEGMENT_COUNT)
	var gap := maxf(1.5, size.x * 0.012)
	var segment_width := (size.x - gap * float(SEGMENT_COUNT - 1)) / float(SEGMENT_COUNT)
	var segment_height := size.y * 0.62
	var top := (size.y - segment_height) * 0.5
	var slant := minf(segment_width * 0.38, segment_height * 0.48)

	for index in range(SEGMENT_COUNT):
		var left := float(index) * (segment_width + gap)
		var points := PackedVector2Array([
			Vector2(left + slant, top),
			Vector2(left + segment_width, top),
			Vector2(left + segment_width - slant, top + segment_height),
			Vector2(left, top + segment_height),
		])
		draw_colored_polygon(_offset_points(points, Vector2(0, 1)), outline_color)
		draw_colored_polygon(points, active_color if index < active_count else inactive_color)


func _offset_points(points: PackedVector2Array, offset: Vector2) -> PackedVector2Array:
	var shifted := PackedVector2Array()
	for point in points:
		shifted.append(point + offset)
	return shifted

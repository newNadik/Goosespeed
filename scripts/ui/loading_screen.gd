class_name GooseLoadingScreen
extends Control

const BACKGROUND_COLOUR := Color(0.012, 0.011, 0.01, 0.98)

var progress := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func set_progress(value: float) -> void:
	progress = clampf(value, 0.0, 1.0)
	queue_redraw()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, BACKGROUND_COLOUR, true)
	_draw_progress_glow(rect)


func _draw_progress_glow(rect: Rect2) -> void:
	var glow_width := maxf(0.0, rect.size.x * progress)
	if glow_width <= 0.0:
		return
	var glow_rect := Rect2(0.0, rect.size.y - 8.0, glow_width, 8.0)
	draw_rect(glow_rect, Color(1.0, 0.43, 0.08, 0.9), true)

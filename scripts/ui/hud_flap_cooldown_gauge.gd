class_name HudFlapCooldownGauge
extends Control

var cooldown_duration := 0.0
var cooldown_remaining := 0.0


func set_cooldown(duration: float, remaining: float) -> void:
	cooldown_duration = maxf(duration, 0.0)
	cooldown_remaining = clampf(remaining, 0.0, cooldown_duration)
	queue_redraw()


func _draw() -> void:
	var bg_color := Color(0.09411765, 0.18431373, 0.26666668, 0.38)
	var fill_color := Color(0.99607843, 0.46666667, 0.2627451, 1.0)
	var center := size * 0.5
	var radius: float = minf(size.x, size.y) * 0.32
	var width: float = maxf(9.0, radius * 0.45)
	var ready_ratio := 1.0
	if cooldown_duration > 0.0:
		ready_ratio = 1.0 - (cooldown_remaining / cooldown_duration)
	ready_ratio = clampf(ready_ratio, 0.0, 1.0)

	draw_arc(center, radius, 0.0, TAU, 48, bg_color, width, true)
	if ready_ratio > 0.0:
		draw_arc(center, radius, -PI * 0.5, -PI * 0.5 - TAU * ready_ratio, 48, fill_color, width, true)

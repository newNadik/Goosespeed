class_name GlideFlapModifier
extends Node

@export var enabled := true
@export var glide_gravity_scale := 0.32
@export var glide_max_fall_speed := 7.0
@export var glide_forward_acceleration := 5.0
@export var flap_vertical_impulse := 5.5
@export var flap_forward_impulse := 2.5
@export var flap_cooldown := 0.42

var cooldown_remaining := 0.0
var gliding := false
var flapping := false


func apply(
	velocity: Vector3,
	forward_direction: Vector3,
	input_adapter: Node,
	grounded: bool,
	delta: float
) -> Vector3:
	cooldown_remaining = maxf(cooldown_remaining - delta, 0.0)
	gliding = false
	flapping = false

	if not enabled or grounded:
		return velocity

	if input_adapter.jump_held and velocity.y < 1.5:
		gliding = true
		if velocity.y < -glide_max_fall_speed:
			velocity.y = move_toward(velocity.y, -glide_max_fall_speed, 22.0 * delta)
		velocity += forward_direction * glide_forward_acceleration * delta

	if input_adapter.consume_jump_pressed() and cooldown_remaining <= 0.0:
		flapping = true
		cooldown_remaining = flap_cooldown
		velocity.y = maxf(velocity.y, 0.0) + flap_vertical_impulse
		velocity += forward_direction * flap_forward_impulse

	return velocity


func gravity_scale_for_airborne(input_adapter: Node) -> float:
	if enabled and input_adapter.jump_held:
		return glide_gravity_scale
	return 1.0

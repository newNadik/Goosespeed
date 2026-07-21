class_name MovementState
extends RefCounted

var position := Vector3.ZERO
var velocity := Vector3.ZERO
var horizontal_speed := 0.0
var facing_direction := Vector3.FORWARD
var grounded := false
var swimming := false
var sliding := false
var gliding := false
var flapping := false
var falling := false
var surface_type: StringName = &"default"
var medium_type: StringName = &"air"


func copy_from(other: RefCounted) -> void:
	position = other.position
	velocity = other.velocity
	horizontal_speed = other.horizontal_speed
	facing_direction = other.facing_direction
	grounded = other.grounded
	swimming = other.swimming
	sliding = other.sliding
	gliding = other.gliding
	flapping = other.flapping
	falling = other.falling
	surface_type = other.surface_type
	medium_type = other.medium_type


func duplicate_state() -> RefCounted:
	var result: RefCounted = get_script().new()
	result.copy_from(self)
	return result

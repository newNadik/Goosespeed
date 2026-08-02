extends Node3D

@export var rotation_speed_degrees := 30.0
@export var rotation_axis := Vector3.FORWARD

func _process(delta: float) -> void:
	rotate_object_local(rotation_axis.normalized(), deg_to_rad(rotation_speed_degrees) * delta)

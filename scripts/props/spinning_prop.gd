extends Node3D

@export var rotation_speed_degrees := 30.0
@export var rotation_axis := Vector3.FORWARD
@export_range(0.0, 1.0, 0.01, "or_greater") var update_interval := 0.0

var _update_time_buffer := 0.0

func _process(delta: float) -> void:
	if update_interval > 0.0:
		_update_time_buffer += delta
		if _update_time_buffer < update_interval:
			return
		delta = _update_time_buffer
		_update_time_buffer = 0.0

	rotate_object_local(rotation_axis.normalized(), deg_to_rad(rotation_speed_degrees) * delta)

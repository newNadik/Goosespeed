class_name SkyController
extends Node3D

@export_range(0, 5, 1) var cloudiness := 4
@export_range(0, 5, 1) var wind := 1
@export var cloud_presets: Array[PackedScene] = []
@export var spawn_area_size := Vector2(150.0, 150.0)
@export var altitude_range := Vector2(24.0, 42.0)
@export var random_seed := 9173
@export_range(0.0, 5.0, 0.05) var cloud_scale_in_seconds := 2.0
@export_range(0.0, 5.0, 0.05) var cloud_scale_out_seconds := 2.0

var rng := RandomNumberGenerator.new()
var drift_direction := Vector3.RIGHT
var drift_speed := 0.5
var wrap_margin := 28.0


func _ready() -> void:
	rng.seed = random_seed
	_rebuild_clouds()


func _process(delta: float) -> void:
	if drift_speed <= 0.0:
		return
	for cloud in get_children():
		if cloud is Node3D:
			_move_cloud(cloud as Node3D, delta)


func _rebuild_clouds() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	if cloud_presets.is_empty():
		return

	var config := _sky_config()
	drift_direction = config["direction"] as Vector3
	drift_speed = float(config["speed"])
	wrap_margin = float(config["wrap_margin"])

	var cloud_count := int(config["count"])
	for index in cloud_count:
		_spawn_cloud(index, config, false)


func set_cloudiness(value: int) -> void:
	var clamped_value := clampi(value, 0, 5)
	if cloudiness == clamped_value:
		return
	cloudiness = clamped_value
	_rebuild_clouds()


func set_wind(value: int) -> void:
	var clamped_value := clampi(value, 0, 5)
	if wind == clamped_value:
		return
	wind = clamped_value
	_rebuild_clouds()


func _spawn_cloud(index: int, config: Dictionary, scale_in := true) -> void:
	var scene := cloud_presets[rng.randi_range(0, cloud_presets.size() - 1)]
	var cloud := scene.instantiate() as Node3D
	if cloud == null:
		return

	cloud.name = "Cloud%02d" % index
	cloud.position = _random_position()
	cloud.rotation.y = _random_cloud_yaw(config)

	var scale_range := config["scale"] as Vector2
	var base_scale := rng.randf_range(scale_range.x, scale_range.y)
	var target_scale := Vector3.ONE * base_scale
	cloud.set_meta(&"target_scale", target_scale)
	cloud.set_meta(&"transitioning", scale_in)
	cloud.scale = Vector3.ZERO if scale_in else target_scale
	add_child(cloud)
	if scale_in:
		_scale_cloud_in(cloud, target_scale)


func _move_cloud(cloud: Node3D, delta: float) -> void:
	cloud.position += drift_direction * drift_speed * delta
	if bool(cloud.get_meta(&"transitioning", false)):
		return

	var axis := Vector3(drift_direction.x, 0.0, drift_direction.z).normalized()
	if axis.is_zero_approx():
		axis = Vector3.RIGHT
	var side_axis := Vector3(-axis.z, 0.0, axis.x)

	var half_forward := _projected_half_extent(axis) + wrap_margin
	var half_side := _projected_half_extent(side_axis)
	var forward_distance := cloud.position.dot(axis)
	if forward_distance > half_forward:
		_wrap_cloud_with_transition(cloud, axis, side_axis, half_forward, half_side)


func _random_position() -> Vector3:
	return Vector3(
		rng.randf_range(-spawn_area_size.x * 0.5, spawn_area_size.x * 0.5),
		rng.randf_range(altitude_range.x, altitude_range.y),
		rng.randf_range(-spawn_area_size.y * 0.5, spawn_area_size.y * 0.5)
	)


func _projected_half_extent(axis: Vector3) -> float:
	return abs(axis.x) * spawn_area_size.x * 0.5 + abs(axis.z) * spawn_area_size.y * 0.5


func _random_cloud_yaw(config: Dictionary) -> float:
	var direction := config["direction"] as Vector3
	var base_yaw := atan2(direction.x, direction.z)
	var variation := float(config["rotation_variation"])
	return base_yaw + rng.randf_range(-variation, variation)


func _wrap_cloud_with_transition(cloud: Node3D, axis: Vector3, side_axis: Vector3, half_forward: float, half_side: float) -> void:
	cloud.set_meta(&"transitioning", true)
	var tween := create_tween()
	tween.tween_property(cloud, "scale", Vector3.ZERO, cloud_scale_out_seconds)
	tween.tween_callback(_reset_wrapped_cloud.bind(cloud, axis, side_axis, half_forward, half_side))


func _reset_wrapped_cloud(cloud: Node3D, axis: Vector3, side_axis: Vector3, half_forward: float, half_side: float) -> void:
	if not is_instance_valid(cloud):
		return
	cloud.position -= axis * half_forward * 2.0
	cloud.position += side_axis * rng.randf_range(-half_side, half_side) * 0.18
	cloud.position.y = rng.randf_range(altitude_range.x, altitude_range.y)
	var target_scale := cloud.get_meta(&"target_scale", Vector3.ONE) as Vector3
	_scale_cloud_in(cloud, target_scale)


func _scale_cloud_in(cloud: Node3D, target_scale: Vector3) -> void:
	var tween := create_tween()
	tween.tween_property(cloud, "scale", target_scale, cloud_scale_in_seconds)
	tween.tween_callback(_finish_cloud_transition.bind(cloud))


func _finish_cloud_transition(cloud: Node3D) -> void:
	if is_instance_valid(cloud):
		cloud.set_meta(&"transitioning", false)


func _sky_config() -> Dictionary:
	var cloud_counts := [0, 8, 14, 24, 36, 52]
	var wind_speeds := [0.02, 0.28, 0.55, 0.9, 1.35, 1.9]
	var wind_angles := [0.08, 0.14, 0.2, 0.28, 0.38, 0.5]
	var rotation_variations := [PI, PI * 0.7, PI * 0.5, PI * 0.3, PI * 0.15, PI * 0.07]
	var scale_mins := [0.75, 0.75, 0.78, 0.8, 0.82, 0.85]
	var scale_maxes := [0.9, 1.0, 1.15, 1.3, 1.45, 1.6]
	var clamped_cloudiness := clampi(cloudiness, 0, 5)
	var clamped_wind := clampi(wind, 0, 5)

	return {
		"count": cloud_counts[clamped_cloudiness],
		"speed": wind_speeds[clamped_wind],
		"direction": Vector3(1.0, 0.0, wind_angles[clamped_wind]).normalized(),
		"rotation_variation": rotation_variations[clamped_wind],
		"scale": Vector2(scale_mins[clamped_cloudiness], scale_maxes[clamped_cloudiness]),
		"wrap_margin": 28.0 + float(clamped_wind) * 2.0,
	}

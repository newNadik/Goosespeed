class_name SkyController
extends Node3D

@export_range(0, 5, 1) var cloudiness := 4
@export_range(0, 5, 1) var wind := 1
@export var cloud_presets: Array[PackedScene] = []
@export var spawn_area_size := Vector2(150.0, 150.0)
@export var altitude_range := Vector2(24.0, 42.0)
@export var random_seed := 9173

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
		_spawn_cloud(index, config)


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


func _spawn_cloud(index: int, config: Dictionary) -> void:
	var scene := cloud_presets[rng.randi_range(0, cloud_presets.size() - 1)]
	var cloud := scene.instantiate() as Node3D
	if cloud == null:
		return

	cloud.name = "Cloud%02d" % index
	cloud.position = _random_position()
	cloud.rotation.y = rng.randf_range(-PI, PI)

	var scale_range := config["scale"] as Vector2
	var base_scale := rng.randf_range(scale_range.x, scale_range.y)
	var stretch := rng.randf_range(0.9, 1.2 + float(wind) * 0.08)
	cloud.scale = Vector3(base_scale * stretch, base_scale, base_scale * rng.randf_range(0.9, 1.15))
	add_child(cloud)


func _move_cloud(cloud: Node3D, delta: float) -> void:
	cloud.position += drift_direction * drift_speed * delta

	var axis := Vector3(drift_direction.x, 0.0, drift_direction.z).normalized()
	if axis.is_zero_approx():
		axis = Vector3.RIGHT
	var side_axis := Vector3(-axis.z, 0.0, axis.x)

	var half_forward := _projected_half_extent(axis) + wrap_margin
	var half_side := _projected_half_extent(side_axis)
	var forward_distance := cloud.position.dot(axis)
	if forward_distance > half_forward:
		cloud.position -= axis * half_forward * 2.0
		cloud.position += side_axis * rng.randf_range(-half_side, half_side) * 0.18
		cloud.position.y = rng.randf_range(altitude_range.x, altitude_range.y)


func _random_position() -> Vector3:
	return Vector3(
		rng.randf_range(-spawn_area_size.x * 0.5, spawn_area_size.x * 0.5),
		rng.randf_range(altitude_range.x, altitude_range.y),
		rng.randf_range(-spawn_area_size.y * 0.5, spawn_area_size.y * 0.5)
	)


func _projected_half_extent(axis: Vector3) -> float:
	return abs(axis.x) * spawn_area_size.x * 0.5 + abs(axis.z) * spawn_area_size.y * 0.5


func _sky_config() -> Dictionary:
	var cloud_counts := [0, 4, 7, 11, 16, 22]
	var wind_speeds := [0.02, 0.28, 0.55, 0.9, 1.35, 1.9]
	var wind_angles := [0.08, 0.14, 0.2, 0.28, 0.38, 0.5]
	var scale_mins := [0.75, 0.75, 0.78, 0.8, 0.82, 0.85]
	var scale_maxes := [0.9, 1.0, 1.15, 1.3, 1.45, 1.6]
	var clamped_cloudiness := clampi(cloudiness, 0, 5)
	var clamped_wind := clampi(wind, 0, 5)

	return {
		"count": cloud_counts[clamped_cloudiness],
		"speed": wind_speeds[clamped_wind],
		"direction": Vector3(1.0, 0.0, wind_angles[clamped_wind]).normalized(),
		"scale": Vector2(scale_mins[clamped_cloudiness], scale_maxes[clamped_cloudiness]),
		"wrap_margin": 28.0 + float(clamped_wind) * 2.0,
	}

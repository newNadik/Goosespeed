class_name CloudFlyingAnimal
extends CharacterBody3D

signal fly_by_finished(animal: CloudFlyingAnimal)

@export var animation_player_path := NodePath("AnimationPlayer")
@export var flap_animation_name := &"flap"
@export var glide_animation_names: Array[StringName] = [&"planer", &"planer 2"]
@export var flap_time_range := Vector2(1.4, 4.0)
@export var fly_speed := 18.0
@export var turn_speed := 2.5
@export_range(-PI, PI, 0.001, "radians") var model_forward_yaw_offset := 0.0

var _animation_player: AnimationPlayer
var _rng := RandomNumberGenerator.new()
var _target_position := Vector3.ZERO
var _is_flying := false
var _flap_time_remaining := 0.0
var _flap_play_time_remaining := 0.0


func _ready() -> void:
	_rng.randomize()
	_animation_player = get_node_or_null(animation_player_path) as AnimationPlayer
	visible = false


func _physics_process(delta: float) -> void:
	if not _is_flying:
		velocity = Vector3.ZERO
		return

	_update_flight(delta)


func start_fly_by(
	flight_center: Vector3,
	forward_axis: Vector3,
	side_axis: Vector3,
	half_forward_extent: float,
	half_side_extent: float,
	flight_altitude_range: Vector2,
	speed: float
) -> void:
	_is_flying = true
	visible = true
	fly_speed = speed

	var side_offset := _rng.randf_range(-half_side_extent, half_side_extent)
	var altitude := _rng.randf_range(
		minf(flight_altitude_range.x, flight_altitude_range.y),
		maxf(flight_altitude_range.x, flight_altitude_range.y)
	)
	global_position = flight_center - forward_axis * half_forward_extent + side_axis * side_offset
	global_position.y = altitude
	_target_position = flight_center + forward_axis * half_forward_extent + side_axis * side_offset
	_target_position.y = altitude + _rng.randf_range(-3.0, 3.0)
	_flap_time_remaining = _random_range(flap_time_range)
	_flap_play_time_remaining = 0.0
	_play_random_glide_animation()


func _update_flight(delta: float) -> void:
	var to_target := _target_position - global_position
	if to_target.length_squared() <= 4.0:
		_finish_fly_by()
		return

	var desired_direction := to_target.normalized()
	_face_direction(desired_direction, delta)
	_update_animation(delta)
	velocity = desired_direction * fly_speed
	move_and_slide()


func _finish_fly_by() -> void:
	_is_flying = false
	velocity = Vector3.ZERO
	visible = false
	if _animation_player != null and _animation_player.is_playing():
		_animation_player.stop()
	fly_by_finished.emit(self)


func _update_animation(delta: float) -> void:
	_flap_time_remaining -= delta
	if _flap_play_time_remaining > 0.0:
		_flap_play_time_remaining -= delta
		if _flap_play_time_remaining <= 0.0:
			_play_random_glide_animation()
		return

	if _flap_time_remaining <= 0.0:
		_play_flap_animation()
		_flap_time_remaining = _random_range(flap_time_range)


func _play_flap_animation() -> void:
	if _animation_player == null or flap_animation_name == &"" or not _animation_player.has_animation(flap_animation_name):
		return

	var animation := _animation_player.get_animation(flap_animation_name)
	animation.loop_mode = Animation.LOOP_NONE
	_animation_player.play(flap_animation_name)
	_flap_play_time_remaining = maxf(animation.length / maxf(absf(_animation_player.speed_scale), 0.001), 0.1)


func _play_random_glide_animation() -> void:
	if _animation_player == null:
		return

	var valid_names: Array[StringName] = []
	for animation_name in glide_animation_names:
		if animation_name != &"" and _animation_player.has_animation(animation_name):
			valid_names.append(animation_name)
	if valid_names.is_empty():
		return

	var animation_name := valid_names[_rng.randi_range(0, valid_names.size() - 1)]
	var animation := _animation_player.get_animation(animation_name)
	animation.loop_mode = Animation.LOOP_LINEAR
	_animation_player.play(animation_name)


func _face_direction(direction: Vector3, delta: float) -> void:
	var flat_direction := Vector3(direction.x, 0.0, direction.z)
	if flat_direction.length_squared() <= 0.001:
		return

	var target_yaw := atan2(flat_direction.x, flat_direction.z) + model_forward_yaw_offset
	rotation.y = lerp_angle(rotation.y, target_yaw, clampf(delta * turn_speed, 0.0, 1.0))


func _random_range(value_range: Vector2) -> float:
	var low := minf(value_range.x, value_range.y)
	var high := maxf(value_range.x, value_range.y)
	return _rng.randf_range(low, high)

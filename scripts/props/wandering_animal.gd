class_name WanderingAnimal
extends CharacterBody3D

@export var animation_player_path := NodePath("AnimationPlayer")
@export var poke_animation_name := &"poke"
@export var walk_animation_name := &"walk"
@export var color_mesh_path := NodePath("")
@export_range(0, 16, 1, "or_greater") var color_surface_index := 0
@export var walk_speed := 1.4
@export var turn_speed := 5.0
@export_range(-PI, PI, 0.001, "radians") var model_forward_yaw_offset := PI
@export var avoidance_radius := 1.2
@export var avoidance_weight := 1.5
@export var stay_time_range := Vector2(1.5, 4.0)
@export var walk_time_range := Vector2(1.2, 3.2)
@export var target_reached_distance := 0.35

var _animation_player: AnimationPlayer
var _rng := RandomNumberGenerator.new()
var _area_center := Vector3.ZERO
var _area_half_extents := Vector2.ONE
var _flock_group := &""
var _state := &"stay"
var _state_time_remaining := 0.0
var _target_position := Vector3.ZERO
var _color_material: StandardMaterial3D


func _ready() -> void:
	_rng.randomize()
	_animation_player = get_node_or_null(animation_player_path) as AnimationPlayer
	_enter_stay()


func _physics_process(delta: float) -> void:
	_state_time_remaining -= delta
	if _state_time_remaining <= 0.0:
		_pick_next_state()

	if _state == &"walk":
		_update_walk(delta)
	else:
		velocity = Vector3.ZERO
		move_and_slide()


func configure_wander_area(area_center: Vector3, area_half_extents: Vector2, flock_group: StringName) -> void:
	_area_center = area_center
	_area_half_extents = area_half_extents
	_flock_group = flock_group
	if _flock_group != &"":
		add_to_group(_flock_group)
	_target_position = _random_point_in_area()


func apply_albedo_color(color: Color) -> void:
	var mesh_instance := get_node_or_null(color_mesh_path) as MeshInstance3D
	if mesh_instance == null:
		return

	if _color_material == null:
		var source_material := mesh_instance.get_surface_override_material(color_surface_index)
		if source_material == null:
			source_material = mesh_instance.get_active_material(color_surface_index)
		if source_material == null:
			return
		_color_material = source_material.duplicate() as StandardMaterial3D

	if _color_material == null:
		return

	_color_material.albedo_color = color
	mesh_instance.set_surface_override_material(color_surface_index, _color_material)


func _pick_next_state() -> void:
	var roll := _rng.randf()
	if roll < 0.45:
		_enter_stay()
	elif roll < 0.70:
		_enter_poke()
	else:
		_enter_walk()


func _enter_stay() -> void:
	_state = &"stay"
	_state_time_remaining = _random_range(stay_time_range)
	velocity = Vector3.ZERO
	if _animation_player != null and _animation_player.is_playing():
		_animation_player.stop()


func _enter_poke() -> void:
	_state = &"poke"
	velocity = Vector3.ZERO
	_state_time_remaining = _play_one_shot_animation(poke_animation_name, _random_range(stay_time_range))


func _enter_walk() -> void:
	_state = &"walk"
	_state_time_remaining = _random_range(walk_time_range)
	_target_position = _random_point_in_area()
	_play_looping_animation(walk_animation_name)


func _update_walk(delta: float) -> void:
	var to_target := _target_position - global_position
	to_target.y = 0.0
	if to_target.length() <= target_reached_distance:
		_target_position = _random_point_in_area()
		to_target = _target_position - global_position
		to_target.y = 0.0

	var desired_direction := to_target.normalized() if to_target.length_squared() > 0.001 else -global_transform.basis.z
	desired_direction = (desired_direction + _separation_direction() * avoidance_weight).normalized()
	if desired_direction.length_squared() <= 0.001:
		desired_direction = -global_transform.basis.z

	var target_yaw := atan2(desired_direction.x, desired_direction.z) + model_forward_yaw_offset
	rotation.y = lerp_angle(rotation.y, target_yaw, clampf(delta * turn_speed, 0.0, 1.0))
	velocity = desired_direction * walk_speed
	velocity.y = 0.0
	move_and_slide()

	if get_slide_collision_count() > 0 or not _is_inside_area(global_position):
		_target_position = _random_point_in_area()


func _separation_direction() -> Vector3:
	if _flock_group == &"":
		return Vector3.ZERO

	var separation := Vector3.ZERO
	for peer in get_tree().get_nodes_in_group(_flock_group):
		if peer == self or not peer is Node3D:
			continue
		var offset := global_position - (peer as Node3D).global_position
		offset.y = 0.0
		var distance := offset.length()
		if distance > 0.001 and distance < avoidance_radius:
			separation += offset.normalized() * ((avoidance_radius - distance) / avoidance_radius)
	return separation


func _random_point_in_area() -> Vector3:
	return _area_center + Vector3(
		_rng.randf_range(-_area_half_extents.x, _area_half_extents.x),
		0.0,
		_rng.randf_range(-_area_half_extents.y, _area_half_extents.y)
	)


func _is_inside_area(point: Vector3) -> bool:
	var local_point := point - _area_center
	return absf(local_point.x) <= _area_half_extents.x and absf(local_point.z) <= _area_half_extents.y


func _play_looping_animation(animation_name: StringName) -> void:
	if _animation_player == null or animation_name == &"" or not _animation_player.has_animation(animation_name):
		return

	var animation := _animation_player.get_animation(animation_name)
	animation.loop_mode = Animation.LOOP_LINEAR
	if _animation_player.current_animation != animation_name or not _animation_player.is_playing():
		_animation_player.play(animation_name)


func _play_one_shot_animation(animation_name: StringName, fallback_duration: float) -> float:
	if _animation_player == null or animation_name == &"" or not _animation_player.has_animation(animation_name):
		return fallback_duration

	var animation := _animation_player.get_animation(animation_name)
	animation.loop_mode = Animation.LOOP_NONE
	_animation_player.play(animation_name)
	return maxf(animation.length / maxf(absf(_animation_player.speed_scale), 0.001), 0.1)


func _random_range(value_range: Vector2) -> float:
	var low := minf(value_range.x, value_range.y)
	var high := maxf(value_range.x, value_range.y)
	return _rng.randf_range(low, high)

class_name WanderingAnimal
extends CharacterBody3D

@export var animation_player_path := NodePath("AnimationPlayer")
@export var poke_animation_name := &"poke"
@export var walk_animation_name := &"walk"
@export var idle_animation_names: Array[StringName] = []
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
@export var flee_enabled := false
@export var player_group := &"player"
@export var flee_trigger_distance := 6.0
@export var flee_distance := 12.0
@export var flee_height := 3.0
@export var flee_fly_speed := 5.5
@export var flee_check_interval := 0.3
@export var takeoff_animation_name := &""
@export var fly_loop_animation_name := &""
@export var land_animation_name := &""

var _animation_player: AnimationPlayer
var _rng := RandomNumberGenerator.new()
var _area_center := Vector3.ZERO
var _area_half_extents := Vector2.ONE
var _flock_group := &""
var _state := &"stay"
var _state_time_remaining := 0.0
var _target_position := Vector3.ZERO
var _color_material: StandardMaterial3D
var _flee_check_time_remaining := 0.0
var _ground_y := 0.0
var _flee_takeoff_duration := 0.35


func _ready() -> void:
	_rng.randomize()
	_animation_player = get_node_or_null(animation_player_path) as AnimationPlayer
	_ground_y = global_position.y
	_enter_stay()


func _physics_process(delta: float) -> void:
	_update_flee_detection(delta)

	if _state == &"flee_takeoff" or _state == &"flee_fly" or _state == &"flee_land":
		_update_flee(delta)
		return

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
	_ground_y = area_center.y
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
	if not idle_animation_names.is_empty() and roll < 0.22:
		_enter_random_idle_animation()
	elif roll < 0.45:
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


func _enter_random_idle_animation() -> void:
	_state = &"idle_animation"
	velocity = Vector3.ZERO
	var animation_name := _random_valid_animation_name(idle_animation_names)
	_state_time_remaining = _play_one_shot_animation(animation_name, _random_range(stay_time_range))


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


func _update_flee_detection(delta: float) -> void:
	if not flee_enabled or player_group == &"":
		return
	if _state == &"flee_takeoff" or _state == &"flee_fly" or _state == &"flee_land":
		return

	_flee_check_time_remaining -= delta
	if _flee_check_time_remaining > 0.0:
		return
	_flee_check_time_remaining = flee_check_interval

	var nearest_player := _nearest_player()
	if nearest_player == null:
		return
	var offset := global_position - nearest_player.global_position
	offset.y = 0.0
	if offset.length_squared() <= flee_trigger_distance * flee_trigger_distance:
		_enter_flee(offset)


func _enter_flee(away_from_player: Vector3) -> void:
	var away_direction := away_from_player.normalized() if away_from_player.length_squared() > 0.001 else _random_flat_direction()
	_target_position = _clamp_to_area(global_position + away_direction * flee_distance)
	_target_position.y = _ground_y + flee_height
	_state = &"flee_takeoff"
	_state_time_remaining = _play_one_shot_animation(takeoff_animation_name, 0.35)
	_flee_takeoff_duration = _state_time_remaining


func _update_flee(delta: float) -> void:
	_state_time_remaining -= delta
	if _state == &"flee_takeoff":
		velocity = Vector3.UP * (flee_height / maxf(_flee_takeoff_duration, 0.1))
		move_and_slide()
		if _state_time_remaining <= 0.0:
			_state = &"flee_fly"
			_play_looping_animation(fly_loop_animation_name)
		return

	if _state == &"flee_fly":
		_move_toward_flee_target(delta, _target_position, flee_fly_speed)
		if global_position.distance_squared_to(_target_position) <= 1.0:
			_state = &"flee_land"
			_target_position.y = _ground_y
			_state_time_remaining = _play_one_shot_animation(land_animation_name, 0.45)
		return

	if absf(global_position.y - _ground_y) > 0.05:
		var descent_target := Vector3(global_position.x, _ground_y, global_position.z)
		_move_toward_flee_target(delta, descent_target, flee_fly_speed * 0.65)
	else:
		velocity = Vector3.ZERO
		move_and_slide()

	if _state_time_remaining <= 0.0:
		global_position.y = _ground_y
		if idle_animation_names.is_empty():
			_enter_stay()
		else:
			_enter_random_idle_animation()


func _move_toward_flee_target(delta: float, target: Vector3, speed: float) -> void:
	var to_target := target - global_position
	if to_target.length_squared() <= 0.001:
		velocity = Vector3.ZERO
		move_and_slide()
		return

	var desired_direction := to_target.normalized()
	_face_direction(desired_direction, delta)
	velocity = desired_direction * speed
	move_and_slide()


func _nearest_player() -> Node3D:
	var nearest: Node3D
	var nearest_distance_squared := INF
	for player in get_tree().get_nodes_in_group(player_group):
		if not player is Node3D:
			continue
		var distance_squared := global_position.distance_squared_to((player as Node3D).global_position)
		if distance_squared < nearest_distance_squared:
			nearest = player as Node3D
			nearest_distance_squared = distance_squared
	return nearest


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


func _clamp_to_area(point: Vector3) -> Vector3:
	return Vector3(
		clampf(point.x, _area_center.x - _area_half_extents.x, _area_center.x + _area_half_extents.x),
		point.y,
		clampf(point.z, _area_center.z - _area_half_extents.y, _area_center.z + _area_half_extents.y)
	)


func _face_direction(direction: Vector3, delta: float) -> void:
	var flat_direction := Vector3(direction.x, 0.0, direction.z)
	if flat_direction.length_squared() <= 0.001:
		return
	var target_yaw := atan2(flat_direction.x, flat_direction.z) + model_forward_yaw_offset
	rotation.y = lerp_angle(rotation.y, target_yaw, clampf(delta * turn_speed, 0.0, 1.0))


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


func _random_valid_animation_name(animation_names: Array[StringName]) -> StringName:
	var valid_names: Array[StringName] = []
	for animation_name in animation_names:
		if _animation_player != null and animation_name != &"" and _animation_player.has_animation(animation_name):
			valid_names.append(animation_name)
	if valid_names.is_empty():
		return &""
	return valid_names[_rng.randi_range(0, valid_names.size() - 1)]


func _random_flat_direction() -> Vector3:
	var angle := _rng.randf_range(-PI, PI)
	return Vector3(sin(angle), 0.0, cos(angle))


func _random_range(value_range: Vector2) -> float:
	var low := minf(value_range.x, value_range.y)
	var high := maxf(value_range.x, value_range.y)
	return _rng.randf_range(low, high)

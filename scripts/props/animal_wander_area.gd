@tool
class_name AnimalWanderArea
extends Area3D

@export var animal_scene: PackedScene
@export_range(0, 64, 1, "or_greater") var spawn_count := 8
@export var area_size := Vector2(12.0, 8.0):
	set(value):
		area_size = value
		_update_area_shape()
@export var spawn_y_offset := 0.0
@export_range(0.01, 4.0, 0.01, "or_greater") var min_animal_scale := 0.85
@export_range(0.01, 4.0, 0.01, "or_greater") var max_animal_scale := 1.15
@export var albedo_color_options: Array[Color] = []
@export var color_mesh_path := NodePath("")
@export_range(0, 16, 1, "or_greater") var color_surface_index := 0
@export var poke_animation_name := &"poke"
@export var walk_animation_name := &"walk"
@export var idle_animation_names: Array[StringName] = []
@export var walk_speed := 1.4
@export_range(-PI, PI, 0.001, "radians") var model_forward_yaw_offset := PI
@export var avoidance_radius := 1.2
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

var _rng := RandomNumberGenerator.new()
var _spawned_animals: Array[Node] = []
var _has_local_resources := false


func _ready() -> void:
	_ensure_local_resources()
	_update_area_shape()
	if Engine.is_editor_hint():
		return

	_set_preview_visible(false)
	_rng.randomize()
	_spawn_animals()


func _spawn_animals() -> void:
	if animal_scene == null:
		return

	_clear_spawned_animals()
	var flock_group := StringName("%s_flock_%d" % [name, get_instance_id()])
	var used_positions: Array[Vector3] = []
	for index in spawn_count:
		var animal := animal_scene.instantiate()
		if not animal is Node3D:
			animal.queue_free()
			continue

		add_child(animal)
		_spawned_animals.append(animal)
		var animal_node := animal as Node3D
		animal_node.position = _pick_spawn_position(used_positions)
		used_positions.append(animal_node.position)
		animal_node.rotation.y = _rng.randf_range(-PI, PI)
		var animal_scale := _rng.randf_range(min_animal_scale, max_animal_scale)
		animal_node.scale = Vector3.ONE * animal_scale

		if animal.has_method("configure_wander_area"):
			animal.set("poke_animation_name", poke_animation_name)
			animal.set("walk_animation_name", walk_animation_name)
			animal.set("idle_animation_names", idle_animation_names)
			animal.set("walk_speed", walk_speed)
			animal.set("model_forward_yaw_offset", model_forward_yaw_offset)
			animal.set("avoidance_radius", avoidance_radius)
			animal.set("flee_enabled", flee_enabled)
			animal.set("player_group", player_group)
			animal.set("flee_trigger_distance", flee_trigger_distance)
			animal.set("flee_distance", flee_distance)
			animal.set("flee_height", flee_height)
			animal.set("flee_fly_speed", flee_fly_speed)
			animal.set("flee_check_interval", flee_check_interval)
			animal.set("takeoff_animation_name", takeoff_animation_name)
			animal.set("fly_loop_animation_name", fly_loop_animation_name)
			animal.set("land_animation_name", land_animation_name)
			animal.set("color_mesh_path", color_mesh_path)
			animal.set("color_surface_index", color_surface_index)
			animal.configure_wander_area(global_position, area_size * 0.5, flock_group)
			if not albedo_color_options.is_empty() and animal.has_method("apply_albedo_color"):
				animal.apply_albedo_color(albedo_color_options[_rng.randi_range(0, albedo_color_options.size() - 1)])


func _exit_tree() -> void:
	_clear_spawned_animals()


func _clear_spawned_animals() -> void:
	for animal in _spawned_animals:
		if is_instance_valid(animal):
			animal.free()
	_spawned_animals.clear()


func _pick_spawn_position(used_positions: Array[Vector3]) -> Vector3:
	var minimum_spacing := maxf(avoidance_radius * 0.8, 0.1)
	for attempt in 24:
		var candidate := _random_local_point()
		var accepted := true
		for used_position in used_positions:
			if Vector2(candidate.x - used_position.x, candidate.z - used_position.z).length() < minimum_spacing:
				accepted = false
				break
		if accepted:
			return candidate
	return _random_local_point()


func _random_local_point() -> Vector3:
	return Vector3(
		_rng.randf_range(-area_size.x * 0.5, area_size.x * 0.5),
		spawn_y_offset,
		_rng.randf_range(-area_size.y * 0.5, area_size.y * 0.5)
	)


func _update_area_shape() -> void:
	if not is_inside_tree():
		return

	_ensure_local_resources()

	var collision_shape := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collision_shape == null:
		return

	var box_shape := collision_shape.shape as BoxShape3D
	if box_shape == null:
		box_shape = BoxShape3D.new()
		collision_shape.shape = box_shape
	box_shape.size = Vector3(maxf(area_size.x, 0.1), 1.0, maxf(area_size.y, 0.1))

	var preview_mesh_instance := get_node_or_null("PreviewMesh") as MeshInstance3D
	if preview_mesh_instance == null:
		return

	var box_mesh := preview_mesh_instance.mesh as BoxMesh
	if box_mesh != null:
		box_mesh.size = box_shape.size
	_set_preview_visible(Engine.is_editor_hint())


func _set_preview_visible(is_visible: bool) -> void:
	var preview_mesh_instance := get_node_or_null("PreviewMesh") as MeshInstance3D
	if preview_mesh_instance != null:
		preview_mesh_instance.visible = is_visible


func _ensure_local_resources() -> void:
	if _has_local_resources or not is_inside_tree():
		return

	var collision_shape := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collision_shape != null and collision_shape.shape != null:
		collision_shape.shape = collision_shape.shape.duplicate()
		collision_shape.shape.resource_local_to_scene = true

	var preview_mesh_instance := get_node_or_null("PreviewMesh") as MeshInstance3D
	if preview_mesh_instance != null and preview_mesh_instance.mesh != null:
		preview_mesh_instance.mesh = preview_mesh_instance.mesh.duplicate()
		preview_mesh_instance.mesh.resource_local_to_scene = true
		var mesh_material := preview_mesh_instance.mesh.surface_get_material(0)
		if mesh_material != null:
			preview_mesh_instance.mesh.surface_set_material(0, mesh_material.duplicate())
			preview_mesh_instance.mesh.surface_get_material(0).resource_local_to_scene = true

	_has_local_resources = true

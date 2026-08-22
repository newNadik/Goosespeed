class_name FarmWebQuality
extends Node

const RENDERING_METHOD_SETTING := "rendering/renderer/rendering_method"
const COMPATIBILITY_RENDERING_METHOD := "gl_compatibility"
const VIEWPORT_3D_SCALE_PROPERTY := "scaling_3d_scale"

@export var force_enabled := false
@export_range(0, 240, 1, "or_greater") var max_fps := 60
@export_range(0.25, 1.0, 0.01) var render_scale_3d := 0.85
@export var sun_shadow_max_distance := 55.0
@export_range(0, 5, 1) var sky_cloudiness := 3
@export_range(0, 5, 1) var sky_wind := 3
@export var bird_spawn_interval_range := Vector2(22.0, 36.0)
@export_range(0, 8, 1, "or_greater") var bird_spawn_min_count := 0
@export_range(0, 8, 1, "or_greater") var bird_spawn_max_count := 1
@export_range(0.0, 1.0, 0.01, "or_greater") var sky_update_interval := 0.1
@export var ambient_light_energy := 0.42
@export var fog_density := 0.012
@export var fog_depth_begin := 80.0
@export var fog_depth_end := 180.0
@export var fog_sky_affect := 0.35
@export var adjustment_saturation := 1.05
@export var adjustment_contrast := 1.04
@export var corn_visibility_range_end := 160.0
@export var corn_visibility_range_end_margin := 20.0
@export var corn_disable_shadows := true
@export var scenery_disable_shadows := true
@export var scenery_shadow_roots := PackedStringArray([
	"FarmRoad",
	"trash",
	"stoneroad",
	"mud",
	"bus",
])
@export var animal_disable_runtime := true
@export var animal_root_name := "animals"
@export var animal_active_wander_prefixes := PackedStringArray([
	"ChickenWanderArea",
	"PigeonWanderArea",
])
@export var animal_disable_collision_shapes := false
@export var animal_disable_areas := false
@export var animal_stop_audio := true
@export var coin_disable_shadows := true
@export_range(0.0, 1.0, 0.01, "or_greater") var coin_spin_update_interval := 0.1
@export var scenery_visibility_range_end := 180.0
@export var scenery_visibility_range_end_margin := 25.0
@export var scenery_visibility_roots := PackedStringArray([
	"cars",
	"trash",
	"stoneroad",
	"plants",
	"bus",
])
@export var building_visibility_range_end := 280.0
@export var building_visibility_range_end_margin := 35.0
@export var building_visibility_roots := PackedStringArray([
	"buildings",
])

var _previous_max_fps := 0
var _applied_max_fps := false
var _previous_render_scale_3d := 1.0
var _applied_render_scale_3d := false


func _ready() -> void:
	if not _should_apply():
		return
	_apply_frame_rate_settings()
	_apply_render_scale_settings()
	call_deferred("_apply_quality_settings")


func _exit_tree() -> void:
	if _applied_max_fps:
		Engine.max_fps = _previous_max_fps
	if _applied_render_scale_3d:
		get_viewport().set(VIEWPORT_3D_SCALE_PROPERTY, _previous_render_scale_3d)


func _should_apply() -> bool:
	return (
		force_enabled
		or OS.has_feature("web")
		or ProjectSettings.get_setting(RENDERING_METHOD_SETTING, "") == COMPATIBILITY_RENDERING_METHOD
	)


func _apply_quality_settings() -> void:
	var course_root := get_parent()
	if course_root == null:
		return

	_apply_sun_settings(course_root)
	_apply_sky_settings(course_root)
	_apply_environment_settings(course_root)
	_apply_corn_settings(course_root)
	_apply_scenery_shadow_settings(course_root)
	_apply_animal_runtime_settings(course_root)
	_apply_coin_settings(course_root)
	_apply_scenery_visibility_settings(course_root)


func _apply_frame_rate_settings() -> void:
	if max_fps <= 0:
		return
	_previous_max_fps = Engine.max_fps
	Engine.max_fps = max_fps
	_applied_max_fps = true


func _apply_render_scale_settings() -> void:
	var viewport := get_viewport()
	if viewport == null or not _has_property(viewport, VIEWPORT_3D_SCALE_PROPERTY):
		return
	_previous_render_scale_3d = float(viewport.get(VIEWPORT_3D_SCALE_PROPERTY))
	viewport.set(VIEWPORT_3D_SCALE_PROPERTY, render_scale_3d)
	_applied_render_scale_3d = true


func _apply_sun_settings(course_root: Node) -> void:
	var sun := course_root.find_child("Sun", true, false) as DirectionalLight3D
	if sun == null:
		return
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = sun_shadow_max_distance


func _apply_sky_settings(course_root: Node) -> void:
	var sky := course_root.find_child("Sky", true, false)
	if sky == null:
		return

	if sky.has_method("set_cloudiness"):
		sky.call("set_cloudiness", sky_cloudiness)
	else:
		sky.set("cloudiness", sky_cloudiness)
	if sky.has_method("set_wind"):
		sky.call("set_wind", sky_wind)
	else:
		sky.set("wind", sky_wind)
	sky.set("bird_spawn_interval_range", bird_spawn_interval_range)
	sky.set("bird_spawn_min_count", bird_spawn_min_count)
	sky.set("bird_spawn_max_count", bird_spawn_max_count)
	_set_property_if_available(sky, "update_interval", sky_update_interval)


func _apply_environment_settings(course_root: Node) -> void:
	var world_environment := course_root.find_child("WorldEnvironment", true, false) as WorldEnvironment
	if world_environment == null or world_environment.environment == null:
		return

	var environment := world_environment.environment.duplicate() as Environment
	if environment == null:
		return
	world_environment.environment = environment

	environment.ambient_light_energy = ambient_light_energy
	environment.fog_density = fog_density
	environment.fog_depth_begin = fog_depth_begin
	environment.fog_depth_end = fog_depth_end
	environment.fog_sky_affect = fog_sky_affect
	environment.volumetric_fog_density = 0.0
	environment.adjustment_enabled = true
	environment.adjustment_saturation = adjustment_saturation
	environment.adjustment_contrast = adjustment_contrast


func _apply_corn_settings(course_root: Node) -> void:
	var corn_root := course_root.find_child("FarmCornFields", true, false)
	if corn_root == null:
		return

	for child in corn_root.find_children("*", "MultiMeshInstance3D", true, false):
		var corn_field := child as MultiMeshInstance3D
		if corn_field == null:
			continue
		corn_field.visibility_range_end = corn_visibility_range_end
		corn_field.visibility_range_end_margin = corn_visibility_range_end_margin
		if corn_disable_shadows:
			corn_field.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _apply_scenery_shadow_settings(course_root: Node) -> void:
	if not scenery_disable_shadows:
		return

	for root_name in scenery_shadow_roots:
		var scenery_root := course_root.find_child(root_name, true, false)
		if scenery_root == null:
			continue
		_disable_shadows_for_tree(scenery_root)


func _disable_shadows_for_tree(root: Node) -> void:
	var geometry_root := root as GeometryInstance3D
	if geometry_root != null:
		geometry_root.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	for child in root.find_children("*", "GeometryInstance3D", true, false):
		var geometry := child as GeometryInstance3D
		if geometry == null:
			continue
		geometry.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _apply_animal_runtime_settings(course_root: Node) -> void:
	if not animal_disable_runtime:
		return

	var animal_root := course_root.find_child(animal_root_name, true, false)
	if animal_root == null:
		return

	for child in animal_root.get_children():
		if _is_active_wander_area(child):
			continue
		child.process_mode = Node.PROCESS_MODE_DISABLED

	if animal_disable_collision_shapes:
		for child in animal_root.find_children("*", "CollisionShape3D", true, false):
			var collision_shape := child as CollisionShape3D
			if collision_shape == null:
				continue
			collision_shape.disabled = true

	if animal_disable_areas:
		for child in animal_root.find_children("*", "Area3D", true, false):
			var area := child as Area3D
			if area == null:
				continue
			area.monitoring = false
			area.monitorable = false

	if animal_stop_audio:
		for child in animal_root.find_children("*", "AudioStreamPlayer3D", true, false):
			var audio_player := child as AudioStreamPlayer3D
			if audio_player == null:
				continue
			audio_player.stop()


func _is_active_wander_area(node: Node) -> bool:
	for prefix in animal_active_wander_prefixes:
		if node.name.begins_with(prefix):
			return true
	return false


func _apply_coin_settings(course_root: Node) -> void:
	var coin_root := course_root.find_child("coins", true, false)
	if coin_root == null:
		return

	if coin_disable_shadows:
		_disable_shadows_for_tree(coin_root)

	for child in coin_root.find_children("*", "Node3D", true, false):
		_set_property_if_available(child, "update_interval", coin_spin_update_interval)


func _apply_scenery_visibility_settings(course_root: Node) -> void:
	for root_name in scenery_visibility_roots:
		var scenery_root := course_root.find_child(root_name, true, false)
		if scenery_root == null:
			continue
		_apply_visibility_range_for_tree(
			scenery_root,
			scenery_visibility_range_end,
			scenery_visibility_range_end_margin
		)

	for root_name in building_visibility_roots:
		var building_root := course_root.find_child(root_name, true, false)
		if building_root == null:
			continue
		_apply_visibility_range_for_tree(
			building_root,
			building_visibility_range_end,
			building_visibility_range_end_margin
		)


func _apply_visibility_range_for_tree(root: Node, range_end: float, range_margin: float) -> void:
	var geometry_root := root as GeometryInstance3D
	if geometry_root != null:
		_apply_visibility_range(geometry_root, range_end, range_margin)

	for child in root.find_children("*", "GeometryInstance3D", true, false):
		var geometry := child as GeometryInstance3D
		if geometry == null:
			continue
		_apply_visibility_range(geometry, range_end, range_margin)


func _apply_visibility_range(geometry: GeometryInstance3D, range_end: float, range_margin: float) -> void:
	geometry.visibility_range_end = range_end
	geometry.visibility_range_end_margin = range_margin
	geometry.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED


func _set_property_if_available(object: Object, property_name: StringName, value: Variant) -> void:
	if not _has_property(object, property_name):
		return
	object.set(property_name, value)


func _has_property(object: Object, property_name: StringName) -> bool:
	for property in object.get_property_list():
		if property.get("name", "") == property_name:
			return true
	return false

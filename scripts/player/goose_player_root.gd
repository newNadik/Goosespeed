class_name GoosePlayerRoot
extends Node3D

const PLAYER_BODY_RENDER_LAYER := 20
const SHADOW_CASTER_META := &"goose_first_person_shadow_caster"

@export var movement_profile: Resource

@onready var goose_moves_runtime: Node = $GooseMovesRuntime
@onready var active_movement_controller: Node = $ActiveMovementController
@onready var movement_state_bridge: Node = $MovementStateBridge
@onready var goose_visual: Node = $GooseVisual
@onready var straw_hat: Node3D = $GooseVisual/Goose/Skeleton3D/BoneAttachment3D/Node3D/straw_hat


func _ready() -> void:
	active_movement_controller = goose_moves_runtime.spawn_controller(active_movement_controller)
	active_movement_controller.add_to_group("player")
	_configure_controller_render_contract()
	_configure_goose_visual_render_layer()
	_connect_settings_changed()
	_apply_movement_profile()
	movement_state_bridge.set_controller(active_movement_controller)
	goose_visual.set_state_bridge(movement_state_bridge)
	goose_visual.set_transform_source(active_movement_controller as Node3D)
	_apply_backend_debug_visibility()
	_apply_visual_settings()
	_sync_first_person_camera_visibility()
	call_deferred("_apply_backend_debug_visibility")
	call_deferred("_apply_visual_settings")
	call_deferred("_sync_first_person_camera_visibility")


func _process(_delta: float) -> void:
	_sync_first_person_camera_visibility()


func get_active_controller() -> Node:
	return active_movement_controller


func reset_to_spawn() -> void:
	goose_moves_runtime.reset_to_spawn()
	if goose_visual.has_method("snap_to_transform_source"):
		goose_visual.snap_to_transform_source()
	else:
		goose_visual.global_transform = (active_movement_controller as Node3D).global_transform


func set_spawn_transform(value: Transform3D) -> void:
	goose_moves_runtime.set_spawn_transform(value)


func set_control_enabled(value: bool) -> void:
	goose_moves_runtime.set_control_enabled(value)


func enter_cutscene_idle() -> void:
	set_control_enabled(false)
	var controller := get_active_controller()
	if controller != null:
		if "velocity" in controller:
			controller.set("velocity", Vector3.ZERO)
		if controller.has_method("set_control_enabled"):
			controller.set_control_enabled(false)
	if goose_visual != null:
		if goose_visual.has_method("snap_to_transform_source"):
			goose_visual.snap_to_transform_source()
		if goose_visual.has_method("set_cutscene_idle_enabled"):
			goose_visual.set_cutscene_idle_enabled(true)


func exit_cutscene_idle() -> void:
	if goose_visual != null and goose_visual.has_method("set_cutscene_idle_enabled"):
		goose_visual.set_cutscene_idle_enabled(false)


func detach_visual_from_movement_controller() -> void:
	if goose_visual != null and goose_visual.has_method("clear_transform_source"):
		goose_visual.clear_transform_source()


func set_visual_cutscene_local_transform_enabled(value: bool) -> void:
	if goose_visual != null and goose_visual.has_method("set_cutscene_local_transform_enabled"):
		goose_visual.set_cutscene_local_transform_enabled(value)


func get_active_camera() -> Camera3D:
	return _get_active_camera()


func set_goose_visual_visible(value: bool) -> void:
	if goose_visual != null:
		goose_visual.visible = value


func is_straw_hat_equipped() -> bool:
	return straw_hat != null and straw_hat.visible


func set_straw_hat_visible(value: bool) -> void:
	if straw_hat != null:
		straw_hat.visible = value


func _apply_movement_profile() -> void:
	if movement_profile == null:
		return
	if active_movement_controller != null:
		if "flight_hold_threshold" in active_movement_controller:
			active_movement_controller.set(
				"flight_hold_threshold",
				float(movement_profile.get("flight_hold_threshold")),
			)
		var flight_motor = (
			active_movement_controller.get("flight_motor")
			if "flight_motor" in active_movement_controller
			else null
		)
		if flight_motor != null and "flap_cooldown" in flight_motor:
			flight_motor.set("flap_cooldown", float(movement_profile.get("flap_cooldown")))
		var q3_motor = (
			active_movement_controller.get("q3_motor")
			if "q3_motor" in active_movement_controller
			else null
		)
		if q3_motor != null:
			for setting_name in [
				"straight_run_bonus_acceleration",
				"straight_run_bonus_max_speed",
				"straight_run_bonus_decay",
				"straight_run_min_forward_input",
				"straight_run_max_lateral_input",
				"straight_run_max_direction_change_degrees",
				"straight_run_max_floor_normal_change_degrees",
			]:
				if setting_name in q3_motor:
					q3_motor.set(setting_name, float(movement_profile.get(setting_name)))
	if goose_visual != null and "takeoff_runup_charge_ratio" in goose_visual:
		goose_visual.set(
			"takeoff_runup_charge_ratio",
			float(movement_profile.get("takeoff_runup_charge_ratio")),
		)


func _apply_backend_debug_visibility() -> void:
	goose_moves_runtime.apply_debug_visibility(false)


func _connect_settings_changed() -> void:
	var settings := get_node_or_null("/root/GooseGameSettings")
	if settings != null and settings.has_signal("settings_changed"):
		if not settings.is_connected("settings_changed", _on_settings_changed):
			settings.connect("settings_changed", _on_settings_changed)


func _on_settings_changed() -> void:
	_apply_backend_debug_visibility()
	_apply_visual_settings()


func _apply_visual_settings() -> void:
	var game_settings := get_node_or_null("/root/GooseGameSettings")
	if game_settings == null or goose_visual == null:
		return
	goose_visual.head_look_enabled = bool(game_settings.get("head_look_enabled"))
	goose_visual.head_look_intensity = float(game_settings.get("head_look_intensity"))
	goose_visual.head_look_smoothness = float(game_settings.get("head_look_smoothness"))
	if straw_hat != null and game_settings.has_method("is_accessory_equipped"):
		straw_hat.visible = game_settings.is_accessory_equipped(
			GooseGameSettings.ACCESSORY_STRAW_HAT
		)


func _configure_goose_visual_render_layer() -> void:
	_remove_first_person_shadow_casters(goose_visual)
	for instance in _find_mesh_instances(goose_visual):
		instance.layers = 0
		instance.set_layer_mask_value(PLAYER_BODY_RENDER_LAYER, true)
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		_add_first_person_shadow_caster(instance)


func _configure_controller_render_contract() -> void:
	if (
		active_movement_controller != null
		and active_movement_controller.has_method("set_player_body_render_layer")
	):
		active_movement_controller.set_player_body_render_layer(PLAYER_BODY_RENDER_LAYER)


func _sync_first_person_camera_visibility() -> void:
	var first_person_active := _active_camera_is_first_person()
	for camera in _find_cameras(active_movement_controller):
		camera.set_cull_mask_value(PLAYER_BODY_RENDER_LAYER, not first_person_active)


func _active_camera_is_first_person() -> bool:
	if (
		active_movement_controller != null
		and "first_person_camera_enabled" in active_movement_controller
	):
		return bool(active_movement_controller.get("first_person_camera_enabled"))
	var camera := _get_active_camera()
	if camera == null:
		return false
	var path := str(camera.get_path())
	return (
		path.ends_with("/Head/Camera3D")
		or path.ends_with("/Q3CameraAnchor/Camera3D")
		or path.ends_with("/FlightFirstPersonCamera")
	)


func _get_active_camera() -> Camera3D:
	if active_movement_controller != null and active_movement_controller.has_method("get_view_camera"):
		return active_movement_controller.get_view_camera() as Camera3D
	for camera in _find_cameras(active_movement_controller):
		if camera.current:
			return camera
	return null


func _find_visual_instances(root: Node) -> Array[VisualInstance3D]:
	var instances: Array[VisualInstance3D] = []
	if root is VisualInstance3D:
		instances.append(root as VisualInstance3D)
	if root == null:
		return instances
	for child in root.get_children():
		instances.append_array(_find_visual_instances(child))
	return instances


func _find_mesh_instances(root: Node) -> Array[MeshInstance3D]:
	var instances: Array[MeshInstance3D] = []
	if root is MeshInstance3D and not bool(root.get_meta(SHADOW_CASTER_META, false)):
		instances.append(root as MeshInstance3D)
	if root == null:
		return instances
	for child in root.get_children():
		instances.append_array(_find_mesh_instances(child))
	return instances


func _remove_first_person_shadow_casters(root: Node) -> void:
	if root == null:
		return
	for child in root.get_children():
		if bool(child.get_meta(SHADOW_CASTER_META, false)):
			child.queue_free()
		else:
			_remove_first_person_shadow_casters(child)


func _add_first_person_shadow_caster(source: MeshInstance3D) -> void:
	var shadow_caster := source.duplicate() as MeshInstance3D
	if shadow_caster == null:
		return
	shadow_caster.name = "%sShadowCaster" % source.name
	shadow_caster.set_meta(SHADOW_CASTER_META, true)
	shadow_caster.visible = true
	shadow_caster.layers = 1
	shadow_caster.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	source.add_sibling(shadow_caster)


func _find_cameras(root: Node) -> Array[Camera3D]:
	var cameras: Array[Camera3D] = []
	if root is Camera3D:
		cameras.append(root as Camera3D)
	if root == null:
		return cameras
	for child in root.get_children():
		cameras.append_array(_find_cameras(child))
	return cameras

class_name FarmLevelEndSequence
extends Node3D

signal summary_ready
signal departure_finished(destination: StringName)

const GOOSE_RENDER_LAYER := 20

@export var cutscene_camera_path: NodePath = ^"CutsceneCamera"
@export var finish_camera_marker_path: NodePath = ^"FinishCameraMarker"
@export var finish_look_marker_path: NodePath = ^"FinishLookMarker"
@export var bus_path: NodePath = ^"../bus"
@export var bus_start_marker_path: NodePath = ^"BusStartMarker"
@export var bus_stop_marker_path: NodePath = ^"BusStopMarker"
@export var bus_exit_marker_path: NodePath = ^"BusExitMarker"
@export var fade_layer_path: NodePath = ^"FadeLayer"

@export var camera_turn_duration := 2.5
@export var finish_hold_duration := 0.35
@export var summary_delay := 0.18
@export var bus_approach_duration := 2.0
@export var bus_stop_duration := 1.5
@export var bus_goose_board_duration := 2.0
@export var bus_exit_duration := 2.0
@export var bus_skew_amount := 0.18
@export var fade_duration := 0.65
@export var fade_color := Color(0.035, 0.105, 0.17, 1.0)
@export var cutscene_fov := 54.0
@export var use_finish_look_marker := false

var player: Node
var finish_line: Node3D
var has_played_finish_intro := false
var is_departing := false

@onready var cutscene_camera: Camera3D = get_node_or_null(cutscene_camera_path) as Camera3D
@onready var finish_camera_marker: Node3D = get_node_or_null(finish_camera_marker_path) as Node3D
@onready var finish_look_marker: Node3D = get_node_or_null(finish_look_marker_path) as Node3D
@onready var bus: Node3D = get_node_or_null(bus_path) as Node3D
@onready var bus_start_marker: Node3D = get_node_or_null(bus_start_marker_path) as Node3D
@onready var bus_stop_marker: Node3D = get_node_or_null(bus_stop_marker_path) as Node3D
@onready var bus_exit_marker: Node3D = get_node_or_null(bus_exit_marker_path) as Node3D
@onready var fade_layer: CanvasLayer = get_node_or_null(fade_layer_path) as CanvasLayer
@onready var fade_rect: ColorRect = get_node_or_null("%FadeRect") as ColorRect


func _ready() -> void:
	if fade_rect == null and fade_layer != null:
		fade_rect = fade_layer.get_node_or_null("FadeRect") as ColorRect
	if cutscene_camera != null:
		cutscene_camera.clear_current(false)
	if bus != null:
		bus.visible = false
		_configure_bus_goose_for_cutscene()
	if fade_rect != null:
		fade_rect.color = Color(fade_color.r, fade_color.g, fade_color.b, 0.0)
		fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if fade_layer != null:
		fade_layer.visible = true


func setup(value_player: Node, value_finish_line: Node3D) -> void:
	player = value_player
	finish_line = value_finish_line


func reset_sequence() -> void:
	has_played_finish_intro = false
	is_departing = false
	if cutscene_camera != null:
		cutscene_camera.clear_current(false)
	var player_camera := _get_player_camera()
	if player_camera != null:
		player_camera.make_current()
	if bus != null:
		bus.visible = false
		bus.scale = Vector3.ONE
		_configure_bus_goose_for_cutscene()
	if fade_rect != null:
		fade_rect.color = Color(fade_color.r, fade_color.g, fade_color.b, 0.0)
	if player != null:
		if player.has_method("exit_cutscene_idle"):
			player.exit_cutscene_idle()
		if player.has_method("set_goose_visual_visible"):
			player.set_goose_visual_visible(true)


func play_finish_intro(value_player: Node, value_finish_line: Node3D) -> void:
	setup(value_player, value_finish_line)
	if has_played_finish_intro:
		return
	has_played_finish_intro = true
	if player != null and player.has_method("enter_cutscene_idle"):
		player.enter_cutscene_idle()
	await _turn_camera_to_finish()
	await get_tree().create_timer(maxf(finish_hold_duration + summary_delay, 0.0)).timeout
	summary_ready.emit()


func play_departure(destination: StringName) -> void:
	if is_departing:
		return
	is_departing = true
	if bus == null:
		await _fade_out()
		departure_finished.emit(destination)
		return

	_prepare_bus()
	await _move_bus(bus_start_marker, bus_stop_marker, bus_approach_duration, true)
	_show_bus_goose_and_play_sit()
	await get_tree().create_timer(maxf(bus_stop_duration, 0.0)).timeout
	_hide_player_goose_for_departure()
	await get_tree().create_timer(maxf(bus_goose_board_duration, 0.0)).timeout
	await _move_bus(bus_stop_marker, bus_exit_marker, bus_exit_duration, true)
	await _fade_out()
	departure_finished.emit(destination)


func _turn_camera_to_finish() -> void:
	if cutscene_camera == null or finish_camera_marker == null:
		return
	var source_camera := _get_player_camera()
	var from_transform := cutscene_camera.global_transform
	var from_fov := cutscene_camera.fov
	if source_camera != null:
		from_transform = source_camera.global_transform
		from_fov = source_camera.fov
		source_camera.clear_current(false)
	cutscene_camera.top_level = true
	cutscene_camera.global_transform = from_transform
	cutscene_camera.fov = from_fov
	cutscene_camera.set_cull_mask_value(GOOSE_RENDER_LAYER, true)
	cutscene_camera.current = true

	var target_position := finish_camera_marker.global_position
	var target_basis := finish_camera_marker.global_basis
	if (
		use_finish_look_marker
		and finish_look_marker != null
		and target_position.distance_squared_to(finish_look_marker.global_position) > 0.0001
	):
		target_basis = _basis_looking_at(target_position, finish_look_marker.global_position)
	var target_transform := Transform3D(target_basis, target_position)

	var tween := create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_method(
		Callable(self, "_apply_camera_blend").bind(
			from_transform,
			target_transform,
			from_fov,
			cutscene_fov
		),
		0.0,
		1.0,
		maxf(camera_turn_duration, 0.01)
	)
	await tween.finished


func _apply_camera_blend(
	weight: float,
	from_transform: Transform3D,
	target_transform: Transform3D,
	from_fov: float,
	target_fov: float
) -> void:
	if cutscene_camera == null:
		return
	var from_rotation := from_transform.basis.get_rotation_quaternion()
	var target_rotation := target_transform.basis.get_rotation_quaternion()
	cutscene_camera.global_transform = Transform3D(
		Basis(from_rotation.slerp(target_rotation, weight)),
		from_transform.origin.lerp(target_transform.origin, weight)
	)
	cutscene_camera.fov = lerpf(from_fov, target_fov, weight)


func _basis_looking_at(origin: Vector3, target: Vector3) -> Basis:
	if origin.distance_squared_to(target) <= 0.0001:
		return Basis.IDENTITY
	return Transform3D(Basis.IDENTITY, origin).looking_at(target, Vector3.UP).basis


func _get_player_camera() -> Camera3D:
	if player == null:
		return null
	if player.has_method("get_active_camera"):
		return player.get_active_camera() as Camera3D
	var controller = player.get_active_controller() if player.has_method("get_active_controller") else null
	if controller != null and controller.has_method("get_view_camera"):
		return controller.get_view_camera() as Camera3D
	return null


func _prepare_bus() -> void:
	bus.visible = true
	bus.scale = Vector3.ONE
	if bus_start_marker != null:
		bus.global_transform = bus_start_marker.global_transform
	_configure_bus_goose_for_cutscene()
	_sync_bus_hat()
	_set_bus_goose_visible(false)


func _move_bus(from_marker: Node3D, to_marker: Node3D, duration: float, skew: bool) -> void:
	if bus == null or to_marker == null:
		return
	if from_marker != null:
		bus.global_transform = from_marker.global_transform
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(bus, "global_transform", to_marker.global_transform, maxf(duration, 0.01))
	if skew:
		tween.parallel().tween_method(
			Callable(self, "_apply_bus_speed_skew"),
			0.0,
			1.0,
			maxf(duration, 0.01)
		)
	await tween.finished
	bus.scale = Vector3.ONE


func _apply_bus_speed_skew(weight: float) -> void:
	if bus == null:
		return
	var pulse := sin(weight * PI)
	bus.scale = Vector3(1.0 + bus_skew_amount * pulse, 1.0, 1.0 - bus_skew_amount * 0.35 * pulse)


func _show_bus_goose_and_play_sit() -> void:
	_sync_bus_hat()
	_set_bus_goose_visible(true)
	var bus_animation_player := bus.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if bus_animation_player != null and bus_animation_player.has_animation(&"goose_sit"):
		bus_animation_player.play(&"goose_sit")


func _hide_player_goose_for_departure() -> void:
	if player != null and player.has_method("set_goose_visual_visible"):
		player.set_goose_visual_visible(false)


func _set_bus_goose_visible(value: bool) -> void:
	var bus_goose := bus.get_node_or_null("GoosePlayerRoot") if bus != null else null
	if bus_goose != null:
		_configure_bus_goose_for_cutscene()
		bus_goose.visible = value
		if bus_goose.has_method("set_control_enabled"):
			bus_goose.set_control_enabled(false)
		if bus_goose.has_method("set_goose_visual_visible"):
			bus_goose.set_goose_visual_visible(value)
		if bus_goose.has_method("enter_cutscene_idle"):
			bus_goose.enter_cutscene_idle()


func _configure_bus_goose_for_cutscene() -> void:
	var bus_goose := bus.get_node_or_null("GoosePlayerRoot") if bus != null else null
	if bus_goose == null:
		return
	if bus_goose.has_method("set_visual_cutscene_local_transform_enabled"):
		bus_goose.set_visual_cutscene_local_transform_enabled(true)
	elif bus_goose.has_method("detach_visual_from_movement_controller"):
		bus_goose.detach_visual_from_movement_controller()
	if bus_goose.has_method("set_control_enabled"):
		bus_goose.set_control_enabled(false)
	var input_adapter := bus_goose.get_node_or_null("InputAdapter")
	if input_adapter != null:
		input_adapter.process_mode = Node.PROCESS_MODE_DISABLED
	var controller: Node = (
		bus_goose.get_active_controller()
		if bus_goose.has_method("get_active_controller")
		else null
	)
	if controller != null:
		if controller.has_method("set_control_enabled"):
			controller.set_control_enabled(false)
		if controller.has_method("disable_internal_cameras"):
			controller.disable_internal_cameras()
		controller.process_mode = Node.PROCESS_MODE_DISABLED


func _sync_bus_hat() -> void:
	var bus_goose := bus.get_node_or_null("GoosePlayerRoot") if bus != null else null
	if bus_goose == null or not bus_goose.has_method("set_straw_hat_visible"):
		return
	var equipped := false
	if player != null and player.has_method("is_straw_hat_equipped"):
		equipped = player.is_straw_hat_equipped()
	bus_goose.set_straw_hat_visible(equipped)


func _fade_out() -> void:
	if fade_rect == null:
		return
	fade_rect.color = Color(fade_color.r, fade_color.g, fade_color.b, 0.0)
	var tween := create_tween()
	tween.tween_property(fade_rect, "color:a", fade_color.a, maxf(fade_duration, 0.01))
	await tween.finished

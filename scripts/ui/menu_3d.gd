class_name Menu3D
extends Node3D

const CourseCatalog := preload("res://scripts/gameplay/course_catalog.gd")
const SceneTransitionFadeScript := preload("res://scripts/ui/scene_transition_fade.gd")
const LOADING_SCREEN_SCENE := preload("res://scenes/ui/loading_screen.tscn")
const LEVEL_SCENE := "res://scenes/game/game_scene.tscn"
const PREDICTED_COURSE_SCENE := CourseCatalog.FIRST_COURSE_PATH
const LOADING_LAYER_NAME := "LoadingLayer"
const LOADING_FADE_BASE_NAME := "LoadingFadeBase"
const LOADING_NAVY_COLOUR := SceneTransitionFadeScript.FADE_COLOR
const LOADING_NAVY_FADE_DURATION := 0.18
const INVALID_VIEWPORT_POSITION := Vector2(-1.0, -1.0)

@onready var camera: Camera3D = $Camera3D
@onready var menu_sprite: Sprite3D = $Sprite3D
@onready var menu_hit_area: Area3D = $Sprite3D/MenuHitArea
@onready var menu_viewport: SubViewport = $SubViewport
@onready var start_button: Button = $MenuInputLayer/MenuRoot/MenuBackground/MarginContainer/VBoxContainer/StartButton
@onready var settings_button: Button = $MenuInputLayer/MenuRoot/MenuBackground/MarginContainer/VBoxContainer/SettingsButton
@onready var quit_button: Button = $MenuInputLayer/MenuRoot/MenuBackground/MarginContainer/VBoxContainer/QuitButton
@onready var settings_overlay = $GooseSettingsOverlay

var starting_game := false
var last_forwarded_mouse_position := Vector2.ZERO


func _ready() -> void:
	_track_analytics("main_menu_opened")
	if DisplayServer.get_name() != "headless":
		CourseCatalog.request_course_preload(PREDICTED_COURSE_SCENE)
	var audio_manager := get_node_or_null("/root/AudioManager")
	if audio_manager != null and audio_manager.has_method("play_menu_music"):
		audio_manager.play_menu_music()
	start_button.pressed.connect(on_start_pressed)
	settings_button.pressed.connect(on_settings_pressed)
	quit_button.pressed.connect(on_quit_pressed)
	quit_button.visible = not OS.has_feature("web")
	settings_overlay.back_requested.connect(on_settings_back_requested)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	start_button.grab_focus()
	await SceneTransitionFadeScript.fade_in(get_tree())


func _unhandled_input(event: InputEvent) -> void:
	if starting_game or settings_overlay.visible:
		return
	if not (event is InputEventMouse):
		return
	var viewport_position := _get_menu_viewport_position(event as InputEventMouse)
	if viewport_position == INVALID_VIEWPORT_POSITION:
		if event is InputEventMouseButton and not (event as InputEventMouseButton).pressed:
			_forward_mouse_event(event, last_forwarded_mouse_position)
		elif event is InputEventMouseMotion:
			_forward_mouse_event(event, Vector2(-1000.0, -1000.0))
		return
	last_forwarded_mouse_position = viewport_position
	_forward_mouse_event(event, viewport_position)
	get_viewport().set_input_as_handled()


func on_start_pressed() -> void:
	if starting_game:
		return
	_track_analytics("new_game_selected")
	starting_game = true
	start_button.disabled = true
	settings_button.disabled = true
	quit_button.disabled = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await _fade_to_loading_base()
	_show_loading_screen()
	get_tree().change_scene_to_file(LEVEL_SCENE)


func on_settings_pressed() -> void:
	settings_overlay.show_settings()


func on_settings_back_requested() -> void:
	settings_button.grab_focus()


func on_quit_pressed() -> void:
	_track_analytics("quit_selected")
	get_tree().quit()


func _get_menu_viewport_position(event: InputEventMouse) -> Vector2:
	var ray_origin := camera.project_ray_origin(event.position)
	var ray_direction := camera.project_ray_normal(event.position)
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_origin + ray_direction * 100.0)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	query.collision_mask = menu_hit_area.collision_layer
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or hit.get("collider") != menu_hit_area:
		return INVALID_VIEWPORT_POSITION
	var hit_position := hit["position"] as Vector3
	var local_hit := menu_sprite.to_local(hit_position)
	var viewport_size := Vector2(menu_viewport.size)
	var pixel_size := menu_sprite.pixel_size
	if pixel_size <= 0.0:
		return INVALID_VIEWPORT_POSITION
	var local_size := viewport_size * pixel_size
	var viewport_position := Vector2(
		(local_hit.x + local_size.x * 0.5) / pixel_size,
		(local_size.y * 0.5 - local_hit.y) / pixel_size
	)
	if (
		viewport_position.x < 0.0
		or viewport_position.y < 0.0
		or viewport_position.x > viewport_size.x
		or viewport_position.y > viewport_size.y
	):
		return INVALID_VIEWPORT_POSITION
	return viewport_position


func _forward_mouse_event(event: InputEvent, viewport_position: Vector2) -> void:
	var forwarded := event.duplicate() as InputEvent
	if forwarded is InputEventMouse:
		(forwarded as InputEventMouse).position = viewport_position
		(forwarded as InputEventMouse).global_position = viewport_position
	menu_viewport.push_input(forwarded, true)


func _fade_to_loading_base() -> void:
	var loading_base := _get_or_create_loading_base()
	loading_base.color = Color(LOADING_NAVY_COLOUR, 0.0)
	var tween := create_tween()
	tween.tween_property(loading_base, "color:a", 1.0, LOADING_NAVY_FADE_DURATION)
	await tween.finished


func _show_loading_screen() -> void:
	var loading_screen := _get_or_create_loading_screen()
	loading_screen.modulate.a = 1.0


func _get_or_create_loading_layer() -> CanvasLayer:
	var loading_layer := get_tree().root.get_node_or_null(LOADING_LAYER_NAME) as CanvasLayer
	if loading_layer == null:
		loading_layer = CanvasLayer.new()
		loading_layer.name = LOADING_LAYER_NAME
		loading_layer.layer = 100
		loading_layer.process_mode = Node.PROCESS_MODE_ALWAYS
		get_tree().root.add_child(loading_layer)
	return loading_layer


func _get_or_create_loading_base() -> ColorRect:
	var loading_layer := _get_or_create_loading_layer()
	var loading_base := loading_layer.get_node_or_null(LOADING_FADE_BASE_NAME) as ColorRect
	if loading_base == null:
		loading_base = ColorRect.new()
		loading_base.name = LOADING_FADE_BASE_NAME
		loading_base.anchors_preset = Control.PRESET_FULL_RECT
		loading_base.anchor_right = 1.0
		loading_base.anchor_bottom = 1.0
		loading_base.grow_horizontal = Control.GROW_DIRECTION_BOTH
		loading_base.grow_vertical = Control.GROW_DIRECTION_BOTH
		loading_base.mouse_filter = Control.MOUSE_FILTER_STOP
		loading_base.color = Color(LOADING_NAVY_COLOUR, 0.0)
		loading_layer.add_child(loading_base)
	return loading_base


func _get_or_create_loading_screen() -> Control:
	var loading_layer := _get_or_create_loading_layer()
	var loading_screen := loading_layer.get_node_or_null("GooseLoadingScreen") as Control
	if loading_screen == null:
		loading_screen = LOADING_SCREEN_SCENE.instantiate() as Control
		loading_layer.add_child(loading_screen)
	return loading_screen


func _track_analytics(event_name: String, props := {}) -> void:
	var analytics := get_tree().root.get_node_or_null("GameAnalytics")
	if analytics != null and analytics.has_method("track"):
		analytics.track(event_name, props)

class_name MainMenu
extends Control

const CourseCatalog := preload("res://scripts/gameplay/course_catalog.gd")
const SceneTransitionFadeScript := preload("res://scripts/ui/scene_transition_fade.gd")
const LOADING_SCREEN_SCENE := preload("res://scenes/ui/loading_screen.tscn")
const LEVEL_SCENE := "res://scenes/game/game_scene.tscn"
const PREDICTED_COURSE_SCENE := CourseCatalog.FIRST_COURSE_PATH
const LOADING_LAYER_NAME := "LoadingLayer"
const LOADING_FADE_BASE_NAME := "LoadingFadeBase"
const LOADING_NAVY_COLOUR := SceneTransitionFadeScript.FADE_COLOR
const LOADING_NAVY_FADE_DURATION := 0.18

@onready var start_button: Button = $MenuBackground/MarginContainer/VBoxContainer/StartButton
@onready var settings_button: Button = $MenuBackground/MarginContainer/VBoxContainer/SettingsButton
@onready var quit_button: Button = $MenuBackground/MarginContainer/VBoxContainer/QuitButton
@onready var settings_overlay = $GooseSettingsOverlay

var starting_game := false


func _ready() -> void:
	if DisplayServer.get_name() != "headless":
		CourseCatalog.request_course_preload(PREDICTED_COURSE_SCENE)
	var audio_manager := get_node_or_null("/root/AudioManager")
	if audio_manager != null and audio_manager.has_method("play_menu_music"):
		audio_manager.play_menu_music()
	start_button.pressed.connect(on_start_pressed)
	settings_button.pressed.connect(on_settings_pressed)
	quit_button.pressed.connect(on_quit_pressed)
	settings_overlay.back_requested.connect(on_settings_back_requested)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	start_button.grab_focus()
	await SceneTransitionFadeScript.fade_in(get_tree())


func on_start_pressed() -> void:
	if starting_game:
		return
	starting_game = true
	start_button.disabled = true
	settings_button.disabled = true
	quit_button.disabled = true
	await _fade_to_loading_base()
	_show_loading_screen()
	get_tree().change_scene_to_file(LEVEL_SCENE)


func on_settings_pressed() -> void:
	settings_overlay.show_settings()


func on_settings_back_requested() -> void:
	settings_button.grab_focus()


func on_quit_pressed() -> void:
	get_tree().quit()


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

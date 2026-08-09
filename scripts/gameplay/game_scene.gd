class_name GooseGameScene
extends Node3D

const PAUSE_MENU_SCENE := preload("res://scenes/ui/pause_menu.tscn")
const LOADING_SCREEN_SCENE := preload("res://scenes/ui/loading_screen.tscn")
const CourseCatalog := preload("res://scripts/gameplay/course_catalog.gd")
const COIN_PICKUP_GROUP := &"coins"
const LOADING_FADE_IN_DURATION := 0.06
const LOADING_FADE_OUT_DURATION := 0.28
const LOADING_LAYER_NAME := "LoadingLayer"
const LOADING_FADE_BASE_NAME := "LoadingFadeBase"

@export_file("*.tscn") var course_scene_path: String = CourseCatalog.DEFAULT_COURSE_PATH

@onready var player: Node = $GoosePlayerRoot
@onready var game_hud: Node = $GooseGameHud
@onready var course_root: Node3D = $CourseRoot

var elapsed_time := 0.0
var finished := false
var run_coin_count := 0
var finish_area: Area3D
var spawn_point: Node3D
var coin_pickups: Array[CoinPickup] = []
var active_course: Node3D
var loading_layer: CanvasLayer
var loading_screen: Control


func _ready() -> void:
	set_process(false)
	player.process_mode = Node.PROCESS_MODE_DISABLED
	_show_loading_screen()
	_fade_loading_screen(1.0, LOADING_FADE_IN_DURATION)
	await _load_and_attach_course()
	_cache_course_contract()
	_connect_finish_trigger()
	_apply_spawn_transform()
	_cache_coin_pickups()
	game_hud.set_player(player)
	if game_hud.has_method("set_finish_target"):
		game_hud.set_finish_target(finish_area)
	add_child(PAUSE_MENU_SCENE.instantiate())
	_update_hud()
	await _fade_loading_screen(0.0, LOADING_FADE_OUT_DURATION)
	_hide_loading_screen()
	player.process_mode = Node.PROCESS_MODE_INHERIT
	set_process(true)


func _process(delta: float) -> void:
	if Input.is_action_just_pressed(&"player_restart"):
		restart_run()
	if not finished:
		elapsed_time += delta
	_update_hud()


func restart_run() -> void:
	elapsed_time = 0.0
	finished = false
	run_coin_count = 0
	_reset_coin_pickups()
	player.reset_to_spawn()
	_update_hud()


func get_elapsed_time() -> float:
	return elapsed_time


func is_run_finished() -> bool:
	return finished


func get_finish_area() -> Area3D:
	return finish_area


func get_run_coin_count() -> int:
	return run_coin_count


func get_total_coin_count() -> int:
	var wallet := get_node_or_null("/root/CoinWallet")
	if wallet != null and wallet.has_method("get_total_coins"):
		return wallet.get_total_coins()
	return 0


func _cache_course_contract() -> void:
	spawn_point = course_root.find_child("SpawnPoint", true, false) as Node3D
	finish_area = course_root.find_child("FinishTrigger", true, false) as Area3D
	if spawn_point == null:
		push_error("Course is missing SpawnPoint")
	if finish_area == null:
		push_error("Course is missing FinishTrigger")


func _connect_finish_trigger() -> void:
	if finish_area == null:
		return
	if not finish_area.body_entered.is_connected(_on_finish_body_entered):
		finish_area.body_entered.connect(_on_finish_body_entered)


func _cache_coin_pickups() -> void:
	coin_pickups.clear()
	var active_controller := player.get_active_controller() as Node3D
	for node in get_tree().get_nodes_in_group(COIN_PICKUP_GROUP):
		var coin := node as CoinPickup
		if coin == null or not course_root.is_ancestor_of(coin):
			continue
		coin_pickups.append(coin)
		coin.set_collector_body(active_controller)
		if not coin.collected.is_connected(_on_coin_collected):
			coin.collected.connect(_on_coin_collected)


func _reset_coin_pickups() -> void:
	for coin in coin_pickups:
		if is_instance_valid(coin):
			coin.reset_pickup()


func _apply_spawn_transform() -> void:
	var active_controller := player.get_active_controller() as Node3D
	var spawn_transform: Transform3D = active_controller.global_transform
	if spawn_point != null:
		spawn_transform = spawn_point.global_transform
		active_controller.global_transform = spawn_transform
	player.set_spawn_transform(spawn_transform)


func _on_finish_body_entered(body: Node3D) -> void:
	if body == player.get_active_controller():
		if not finished:
			var wallet := get_node_or_null("/root/CoinWallet")
			if wallet != null and wallet.has_method("add_coins"):
				wallet.add_coins(run_coin_count)
		finished = true
		_update_hud()


func _on_coin_collected(coin: CoinPickup) -> void:
	run_coin_count += coin.value
	_update_hud()


func _update_hud() -> void:
	game_hud.set_run_state(elapsed_time, finished)
	if game_hud.has_method("set_coin_count"):
		game_hud.set_coin_count(run_coin_count)


func _load_and_attach_course() -> void:
	var course_scene := await _load_course_scene()
	if course_scene == null:
		push_error("Could not load course scene: %s" % course_scene_path)
		return

	active_course = course_scene.instantiate() as Node3D
	if active_course == null:
		push_error("Course scene root must be a Node3D: %s" % course_scene_path)
		return
	course_root.add_child(active_course)
	await get_tree().process_frame


func _load_course_scene() -> PackedScene:
	var path := _get_course_scene_path()
	CourseCatalog.request_course_preload(path)

	var progress: Array = []
	var status := ResourceLoader.load_threaded_get_status(path, progress)
	while status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		_set_loading_progress(_read_threaded_progress(progress))
		await get_tree().process_frame
		progress.clear()
		status = ResourceLoader.load_threaded_get_status(path, progress)

	if status == ResourceLoader.THREAD_LOAD_LOADED:
		_set_loading_progress(1.0)
		return ResourceLoader.load_threaded_get(path) as PackedScene

	var loaded_resource := ResourceLoader.load(path)
	_set_loading_progress(1.0)
	return loaded_resource as PackedScene


func _get_course_scene_path() -> String:
	if course_scene_path.is_empty():
		return CourseCatalog.DEFAULT_COURSE_PATH
	return course_scene_path


func _show_loading_screen() -> void:
	loading_layer = get_tree().root.get_node_or_null(LOADING_LAYER_NAME) as CanvasLayer
	if loading_layer == null:
		loading_layer = CanvasLayer.new()
		loading_layer.name = LOADING_LAYER_NAME
		loading_layer.layer = 100
		loading_layer.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(loading_layer)

	loading_screen = loading_layer.get_node_or_null("GooseLoadingScreen") as Control
	if loading_screen == null:
		loading_screen = LOADING_SCREEN_SCENE.instantiate() as Control
		loading_screen.modulate.a = 0.0
		loading_layer.add_child(loading_screen)


func _hide_loading_screen() -> void:
	if loading_layer != null:
		loading_layer.queue_free()
	loading_layer = null
	loading_screen = null


func _set_loading_progress(value: float) -> void:
	if loading_screen != null and loading_screen.has_method("set_progress"):
		loading_screen.set_progress(value)


func _fade_loading_screen(alpha: float, duration: float) -> void:
	if loading_screen == null:
		return
	var tween := create_tween()
	var loading_base := loading_layer.get_node_or_null(LOADING_FADE_BASE_NAME) as ColorRect
	if loading_base != null:
		tween.tween_property(loading_base, "color:a", alpha, duration)
		tween.parallel()
	tween.tween_property(loading_screen, "modulate:a", alpha, duration)
	await tween.finished


func _read_threaded_progress(progress: Array) -> float:
	if progress.is_empty():
		return 0.0
	return float(progress[0])

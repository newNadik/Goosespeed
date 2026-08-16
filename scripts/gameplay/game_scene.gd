class_name GooseGameScene
extends Node3D

const PAUSE_MENU_SCENE := preload("res://scenes/ui/pause_menu.tscn")
const LOADING_SCREEN_SCENE := preload("res://scenes/ui/loading_screen.tscn")
const LEVEL_SUMMARY_POPUP_SCENE := preload("res://scenes/ui/level_summary_popup.tscn")
const CourseCatalog := preload("res://scripts/gameplay/course_catalog.gd")
const SceneTransitionFadeScript := preload("res://scripts/ui/scene_transition_fade.gd")
const COIN_PICKUP_GROUP := &"coins"
const LOADING_FADE_IN_DURATION := 0.06
const LOADING_FADE_OUT_DURATION := 0.28
const LOADING_LAYER_NAME := "LoadingLayer"
const LOADING_FADE_BASE_NAME := "LoadingFadeBase"
const MAIN_MENU_SCENE := "res://scenes/ui/main_menu.tscn"
const FARM_LEVEL_END_SEQUENCE_SCRIPT := preload("res://scripts/courses/farm/farm_level_end_sequence.gd")

@export_file("*.tscn") var course_scene_path: String = CourseCatalog.DEFAULT_COURSE_PATH
@export var target_coin_count := 20

@onready var player: Node = $GoosePlayerRoot
@onready var game_hud: Node = $GooseGameHud
@onready var course_root: Node3D = $CourseRoot

var elapsed_time := 0.0
var finished := false
var run_coin_count := 0
var finish_area: Area3D
var finish_line: Node3D
var spawn_point: Node3D
var coin_pickups: Array[CoinPickup] = []
var active_course: Node3D
var loading_layer: CanvasLayer
var loading_screen: Control
var level_summary_popup
var pause_menu: PauseMenu
var countdown_active := false
var last_finish_best_time := -1.0
var last_finish_new_best := false
var level_end_sequence: Node
var run_started_tracked := false


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
	_reset_coin_pickups()
	game_hud.set_player(player)
	if game_hud.has_method("set_coin_target"):
		game_hud.set_coin_target(target_coin_count)
	if game_hud.has_method("set_finish_target"):
		game_hud.set_finish_target(finish_area)
	pause_menu = PAUSE_MENU_SCENE.instantiate() as PauseMenu
	add_child(pause_menu)
	_add_level_summary_popup()
	_update_hud()
	await _cover_with_transition_color()
	_hide_loading_screen()
	await _fade_out_music_for_scene_change()
	player.process_mode = Node.PROCESS_MODE_INHERIT
	_restore_player_camera()
	await get_tree().process_frame
	await _fade_in_from_transition_color()
	await _begin_level_start_countdown()


func _process(delta: float) -> void:
	if Input.is_action_just_pressed(&"player_restart"):
		restart_run()
	if not finished:
		elapsed_time += delta
	_update_hud()


func _unhandled_input(event: InputEvent) -> void:
	if not _should_request_gameplay_mouse_capture(event):
		return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	get_viewport().set_input_as_handled()


func restart_run() -> void:
	if countdown_active:
		return
	elapsed_time = 0.0
	finished = false
	last_finish_new_best = false
	_set_hud_visible(true)
	_set_player_cutscene_camera_lock_enabled(false)
	_set_pause_blocked(false)
	if level_summary_popup != null:
		level_summary_popup.hide_summary()
	if level_end_sequence != null and level_end_sequence.has_method("reset_sequence"):
		level_end_sequence.reset_sequence()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	run_coin_count = 0
	run_started_tracked = false
	_reset_coin_pickups()
	_reset_finish_line()
	player.reset_to_spawn()
	_restore_player_camera()
	_play_restart_transition()
	_begin_level_start_countdown()
	_update_hud()


func get_elapsed_time() -> float:
	return elapsed_time


func is_run_finished() -> bool:
	return finished


func get_finish_area() -> Area3D:
	return finish_area


func get_run_coin_count() -> int:
	return run_coin_count


func get_target_coin_count() -> int:
	return target_coin_count


func get_total_coin_count() -> int:
	var wallet := get_node_or_null("/root/CoinWallet")
	if wallet != null and wallet.has_method("get_total_coins"):
		return wallet.get_total_coins()
	return 0


func get_best_time() -> float:
	var progress := get_node_or_null("/root/LevelProgress")
	if progress != null and progress.has_method("get_best_time"):
		return progress.get_best_time(_get_course_scene_path())
	return -1.0


func was_last_finish_new_best() -> bool:
	return last_finish_new_best


func _cache_course_contract() -> void:
	spawn_point = course_root.find_child("SpawnPoint", true, false) as Node3D
	finish_area = course_root.find_child("FinishTrigger", true, false) as Area3D
	finish_line = course_root.find_child("finish_line", true, false) as Node3D
	level_end_sequence = course_root.find_child("LevelEndSequence", true, false)
	if level_end_sequence != null and level_end_sequence.has_method("setup"):
		level_end_sequence.setup(player, finish_line)
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


func _reset_finish_line() -> void:
	if finish_line != null and finish_line.has_method("reset_finish_line"):
		finish_line.reset_finish_line(run_coin_count, target_coin_count)
	else:
		_update_finish_line()


func _apply_spawn_transform() -> void:
	var active_controller := player.get_active_controller() as Node3D
	var spawn_transform: Transform3D = active_controller.global_transform
	if spawn_point != null:
		spawn_transform = spawn_point.global_transform
		active_controller.global_transform = spawn_transform
	player.set_spawn_transform(spawn_transform)


func _on_finish_body_entered(body: Node3D) -> void:
	if body == player.get_active_controller():
		if run_coin_count < target_coin_count:
			return
		if not finished:
			finished = true
			var previous_best_time := get_best_time()
			_record_level_time()
			var wallet := get_node_or_null("/root/CoinWallet")
			if wallet != null and wallet.has_method("add_coins"):
				wallet.add_coins(run_coin_count)
				if finish_line != null and finish_line.has_method("complete_finish_line"):
					finish_line.complete_finish_line()
			_track_run_finished(previous_best_time)
			_set_pause_blocked(true)
			_set_player_controls_enabled(false)
			_set_hud_visible(false)
			_set_player_cutscene_camera_lock_enabled(true)
			if level_end_sequence != null and level_end_sequence.has_method("play_finish_intro"):
				await level_end_sequence.play_finish_intro(player, finish_line)
			elif player != null and player.has_method("enter_cutscene_idle"):
				player.enter_cutscene_idle()
			_show_level_summary()
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_update_hud()


func _record_level_time() -> void:
	last_finish_best_time = get_best_time()
	last_finish_new_best = false
	var progress := get_node_or_null("/root/LevelProgress")
	if progress != null and progress.has_method("record_level_time"):
		last_finish_new_best = progress.record_level_time(_get_course_scene_path(), elapsed_time)
		if last_finish_new_best:
			last_finish_best_time = elapsed_time


func _show_level_summary() -> void:
	if level_summary_popup == null:
		return
	level_summary_popup.show_summary(
		_get_course_display_name(),
		elapsed_time,
		get_best_time(),
		last_finish_new_best,
		run_coin_count,
		target_coin_count,
		get_total_coin_count()
	)


func _on_coin_collected(coin: CoinPickup) -> void:
	run_coin_count += coin.value
	_update_finish_line()
	_update_hud()


func _update_hud() -> void:
	game_hud.set_run_state(elapsed_time, finished)
	if game_hud.has_method("set_coin_count"):
		game_hud.set_coin_count(run_coin_count)
	if game_hud.has_method("set_coin_target"):
		game_hud.set_coin_target(target_coin_count)


func _update_finish_line() -> void:
	if finish_line != null and finish_line.has_method("set_coin_progress"):
		finish_line.set_coin_progress(run_coin_count, target_coin_count)


func _play_random_game_music() -> void:
	var audio_manager := get_node_or_null("/root/AudioManager")
	if audio_manager != null and audio_manager.has_method("play_random_game_music"):
		audio_manager.play_random_game_music()


func _begin_level_start_countdown() -> void:
	countdown_active = true
	set_process(false)
	_set_player_controls_enabled(false)
	_stop_music()
	_play_countdown_sfx()
	if game_hud.has_method("play_level_start_countdown"):
		await game_hud.play_level_start_countdown()
	_set_player_controls_enabled(true)
	_play_random_game_music()
	countdown_active = false
	set_process(true)
	_request_gameplay_mouse_capture()
	_track_run_started()
	_update_hud()


func _set_player_controls_enabled(value: bool) -> void:
	if player != null and player.has_method("set_control_enabled"):
		player.set_control_enabled(value)


func _request_gameplay_mouse_capture() -> void:
	if finished or countdown_active or get_tree().paused:
		return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _should_request_gameplay_mouse_capture(event: InputEvent) -> bool:
	if countdown_active or finished or get_tree().paused:
		return false
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		return false
	var mouse_button := event as InputEventMouseButton
	return mouse_button != null and mouse_button.pressed


func _set_player_cutscene_camera_lock_enabled(value: bool) -> void:
	if player != null and player.has_method("set_cutscene_camera_lock_enabled"):
		player.set_cutscene_camera_lock_enabled(value)


func _set_hud_visible(value: bool) -> void:
	if game_hud != null:
		game_hud.visible = value


func _restore_player_camera() -> void:
	if player == null:
		return
	if player.has_method("get_active_camera"):
		var camera := player.get_active_camera() as Camera3D
		if camera != null:
			camera.make_current()


func _set_pause_blocked(value: bool) -> void:
	if pause_menu != null and pause_menu.has_method("set_pause_blocked"):
		pause_menu.set_pause_blocked(value)


func _play_countdown_sfx() -> void:
	var audio_manager := get_node_or_null("/root/AudioManager")
	if audio_manager != null and audio_manager.has_method("play_countdown_sfx"):
		audio_manager.play_countdown_sfx()


func _stop_music() -> void:
	var audio_manager := get_node_or_null("/root/AudioManager")
	if audio_manager != null and audio_manager.has_method("stop_music"):
		audio_manager.stop_music()


func _load_and_attach_course() -> void:
	var course_scene := await _load_course_scene()
	if course_scene == null:
		push_error("Could not load course scene: %s" % course_scene_path)
		return

	active_course = course_scene.instantiate() as Node3D
	if active_course == null:
		push_error("Course scene root must be a Node3D: %s" % course_scene_path)
		return
	_attach_level_end_sequence_script(active_course)
	course_root.add_child(active_course)
	await get_tree().process_frame


func _attach_level_end_sequence_script(course: Node3D) -> void:
	if not _get_course_scene_path().ends_with("level_farm.tscn"):
		return
	var sequence := course.find_child("LevelEndSequence", true, false)
	if sequence == null or sequence.get_script() != null:
		return
	sequence.set_script(FARM_LEVEL_END_SEQUENCE_SCRIPT)


func _add_level_summary_popup() -> void:
	level_summary_popup = LEVEL_SUMMARY_POPUP_SCENE.instantiate()
	if level_summary_popup == null:
		return
	add_child(level_summary_popup)
	level_summary_popup.restart_requested.connect(_on_summary_restart_requested)
	level_summary_popup.main_menu_requested.connect(_on_summary_main_menu_requested)
	level_summary_popup.continue_requested.connect(_on_summary_continue_requested)


func _on_summary_restart_requested() -> void:
	restart_run()


func _on_summary_continue_requested() -> void:
	await _play_summary_departure(&"continue")
	await _go_to_main_menu()


func _on_summary_main_menu_requested() -> void:
	await _play_summary_departure(&"main_menu")
	_track_analytics("main_menu_returned", {
		"source": "level_summary",
		"course_path": _get_course_scene_path(),
		"course_name": _get_course_display_name(),
	})
	await _go_to_main_menu()


func _play_summary_departure(destination: StringName) -> void:
	if level_summary_popup != null:
		level_summary_popup.hide_summary()
	if level_end_sequence != null and level_end_sequence.has_method("play_departure"):
		await level_end_sequence.play_departure(destination)


func _go_to_main_menu() -> void:
	_stop_analytics_gameplay()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await _fade_out_to_transition_color()
	await _fade_out_music_for_scene_change()
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func _fade_out_music_for_scene_change() -> void:
	var audio_manager := get_node_or_null("/root/AudioManager")
	if audio_manager != null and audio_manager.has_method("fade_out_music"):
		await audio_manager.fade_out_music()


func _fade_in_from_transition_color() -> void:
	await SceneTransitionFadeScript.fade_in(get_tree())


func _cover_with_transition_color() -> void:
	await SceneTransitionFadeScript.cover(get_tree())


func _fade_out_to_transition_color() -> void:
	await SceneTransitionFadeScript.fade_out(get_tree())


func _play_restart_transition() -> void:
	call_deferred("_fade_in_from_transition_color")


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


func _get_course_display_name() -> String:
	var path := _get_course_scene_path()
	var file_name := path.get_file().get_basename()
	if file_name.begins_with("level_"):
		file_name = file_name.substr("level_".length())
	return file_name.replace("_", " ")


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


func _track_run_started() -> void:
	if run_started_tracked:
		return
	run_started_tracked = true
	var analytics := get_tree().root.get_node_or_null("GameAnalytics")
	if analytics != null and analytics.has_method("track_run_started"):
		analytics.track_run_started(_get_course_scene_path(), _get_course_display_name())


func _track_run_finished(previous_best_time: float) -> void:
	var analytics := get_tree().root.get_node_or_null("GameAnalytics")
	if analytics != null and analytics.has_method("track_run_finished"):
		analytics.track_run_finished(
			_get_course_scene_path(),
			_get_course_display_name(),
			elapsed_time,
			run_coin_count,
			target_coin_count,
			get_total_coin_count(),
			previous_best_time,
			get_best_time(),
			last_finish_new_best
		)


func _track_analytics(event_name: String, props := {}) -> void:
	var analytics := get_tree().root.get_node_or_null("GameAnalytics")
	if analytics != null and analytics.has_method("track"):
		analytics.track(event_name, props)


func _stop_analytics_gameplay() -> void:
	var analytics := get_tree().root.get_node_or_null("GameAnalytics")
	if analytics != null and analytics.has_method("stop_gameplay"):
		analytics.stop_gameplay()

class_name GooseGameScene
extends Node3D

const PAUSE_MENU_SCENE := preload("res://scenes/ui/pause_menu.tscn")

@onready var player: Node = $GoosePlayerRoot
@onready var game_hud: Node = $GooseGameHud
@onready var course_root: Node3D = $CourseRoot

var elapsed_time := 0.0
var finished := false
var finish_area: Area3D
var spawn_point: Node3D


func _ready() -> void:
	_cache_course_contract()
	_connect_finish_trigger()
	_apply_spawn_transform()
	game_hud.set_player(player)
	if game_hud.has_method("set_finish_target"):
		game_hud.set_finish_target(finish_area)
	add_child(PAUSE_MENU_SCENE.instantiate())
	_update_hud()


func _process(delta: float) -> void:
	if Input.is_action_just_pressed(&"player_restart"):
		restart_run()
	if not finished:
		elapsed_time += delta
	_update_hud()


func restart_run() -> void:
	elapsed_time = 0.0
	finished = false
	player.reset_to_spawn()
	_update_hud()


func get_elapsed_time() -> float:
	return elapsed_time


func is_run_finished() -> bool:
	return finished


func get_finish_area() -> Area3D:
	return finish_area


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


func _apply_spawn_transform() -> void:
	var active_controller := player.get_active_controller() as Node3D
	var spawn_transform: Transform3D = active_controller.global_transform
	if spawn_point != null:
		spawn_transform = spawn_point.global_transform
		active_controller.global_transform = spawn_transform
	player.set_spawn_transform(spawn_transform)


func _on_finish_body_entered(body: Node3D) -> void:
	if body == player.get_active_controller():
		finished = true
		_update_hud()


func _update_hud() -> void:
	game_hud.set_run_state(elapsed_time, finished)

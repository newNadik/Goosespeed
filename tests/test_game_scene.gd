extends Node

const GAME_SCENE := preload("res://scenes/game/game_scene.tscn")


func _ready() -> void:
	var game := GAME_SCENE.instantiate()
	add_child(game)
	await get_tree().process_frame
	await get_tree().physics_frame

	var player := game.get_node("GoosePlayerRoot")
	var controller: Node3D = player.get_active_controller()
	var spawn_point := game.get_node("CourseRoot/FirstCourseSlice/SpawnPoint") as Node3D
	if _horizontal_distance(controller.global_position, spawn_point.global_position) > 0.05:
		push_error(
			"Game scene did not place player at course spawn: got %s, want %s" % [
				controller.global_position,
				spawn_point.global_position,
			]
		)
		get_tree().quit(1)
		return

	game.elapsed_time = 4.2
	game._on_finish_body_entered(controller)
	if not game.is_run_finished():
		push_error("Game scene finish trigger did not finish run")
		get_tree().quit(1)
		return

	controller.global_position += Vector3(3, 0, 0)
	game.restart_run()
	await get_tree().process_frame
	if game.is_run_finished():
		push_error("Game scene restart did not clear finished state")
		get_tree().quit(1)
		return
	if not is_equal_approx(game.get_elapsed_time(), 0.0):
		push_error("Game scene restart did not reset timer")
		get_tree().quit(1)
		return
	if _horizontal_distance(controller.global_position, spawn_point.global_position) > 0.05:
		push_error("Game scene restart did not reset player to spawn")
		get_tree().quit(1)
		return

	print("Game scene OK")
	get_tree().quit(0)


func _horizontal_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))

extends Node

const GAME_SCENE := preload("res://scenes/game/game_scene.tscn")


func _ready() -> void:
	var game := GAME_SCENE.instantiate()
	add_child(game)
	if not await _wait_for_course(game):
		push_error("Game scene did not attach the default course")
		get_tree().quit(1)
		return

	var player := game.get_node("GoosePlayerRoot")
	var controller: Node3D = player.get_active_controller()
	if CoinWallet.has_method("reset_for_tests"):
		CoinWallet.reset_for_tests()
	var spawn_point := game.get_node("CourseRoot/LevelFarm/SpawnPoint") as Node3D
	var course := game.get_node("CourseRoot/LevelFarm")
	for required_node in [
		"Finish/FinishTrigger",
		"coins",
	]:
		if course.get_node_or_null(required_node) == null:
			push_error("Farm level is missing race route node: %s" % required_node)
			get_tree().quit(1)
			return

	if _horizontal_distance(controller.global_position, spawn_point.global_position) > 0.05:
		push_error(
			"Game scene did not place player at course spawn: got %s, want %s" % [
				controller.global_position,
				spawn_point.global_position,
			]
		)
		get_tree().quit(1)
		return

	var first_coin := game.get_node_or_null("CourseRoot/LevelFarm/coins/Path_1/Piece_000")
	if first_coin == null or not first_coin.has_method("collect_from"):
		push_error("Game scene coin pickup fixture is missing")
		get_tree().quit(1)
		return
	var pickup_sound := first_coin.get_node_or_null("PickupSound") as AudioStreamPlayer3D
	if pickup_sound != null:
		pickup_sound.stream = null
	if not first_coin.collect_from(controller):
		push_error("Game scene coin pickup did not accept player controller")
		get_tree().quit(1)
		return
	if game.get_run_coin_count() != 1:
		push_error("Game scene did not count collected run coin")
		get_tree().quit(1)
		return
	if game.get_total_coin_count() != 0:
		push_error("Game scene added coins to total before finish")
		get_tree().quit(1)
		return

	game.elapsed_time = 4.2
	game._on_finish_body_entered(controller)
	if not game.is_run_finished():
		push_error("Game scene finish trigger did not finish run")
		get_tree().quit(1)
		return
	if game.get_total_coin_count() != 1:
		push_error("Game scene did not add run coins to total on finish")
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
	if game.get_run_coin_count() != 0:
		push_error("Game scene restart did not reset run coins")
		get_tree().quit(1)
		return
	if game.get_total_coin_count() != 1:
		push_error("Game scene restart changed total coins")
		get_tree().quit(1)
		return
	if bool(first_coin.get("is_collected")) or not first_coin.visible:
		push_error("Game scene restart did not restore collected coins")
		get_tree().quit(1)
		return
	if _horizontal_distance(controller.global_position, spawn_point.global_position) > 0.05:
		push_error("Game scene restart did not reset player to spawn")
		get_tree().quit(1)
		return

	game.queue_free()
	await get_tree().process_frame
	print("Game scene OK")
	get_tree().quit(0)


func _horizontal_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))


func _wait_for_course(game: Node) -> bool:
	var deadline := Time.get_ticks_msec() + 20000
	while Time.get_ticks_msec() < deadline:
		if game.get_node_or_null("CourseRoot/LevelFarm") != null:
			await get_tree().physics_frame
			return true
		await get_tree().create_timer(0.05).timeout
	return false

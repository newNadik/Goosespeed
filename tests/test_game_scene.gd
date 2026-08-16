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
	var goose_visual := player.get_node_or_null("GooseVisual") as Node3D
	if goose_visual == null:
		push_error("Game scene goose visual fixture is missing")
		get_tree().quit(1)
		return
	if CoinWallet.has_method("reset_for_tests"):
		CoinWallet.reset_for_tests()
	if LevelProgress.has_method("reset_for_tests"):
		LevelProgress.reset_for_tests()
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

	var initial_controller_basis := controller.global_basis
	var initial_visual_basis := goose_visual.global_basis
	var first_coin := game.get_node_or_null("CourseRoot/LevelFarm/coins/Path_1/Piece_000")
	var first_air_coin := game.get_node_or_null("CourseRoot/LevelFarm/coins/Path_4/Piece_000")
	var finish_line := game.get_node_or_null("CourseRoot/LevelFarm/Finish/finish_line")
	var summary := game.get_node_or_null("LevelSummaryPopup")
	if first_coin == null or not first_coin.has_method("collect_from"):
		push_error("Game scene coin pickup fixture is missing")
		get_tree().quit(1)
		return
	if first_air_coin == null or not first_air_coin.has_method("collect_from"):
		push_error("Game scene air coin pickup fixture is missing")
		get_tree().quit(1)
		return
	if not _coin_pickup_radius_is(first_coin, 1.0):
		push_error("Ground coin pickup radius should stay at 1.0")
		get_tree().quit(1)
		return
	if not _coin_pickup_radius_is(first_air_coin, 2.25):
		push_error("Air coin pickup radius should use the larger override")
		get_tree().quit(1)
		return
	if finish_line == null or not finish_line.has_method("set_coin_progress"):
		push_error("Game scene finish line fixture is missing")
		get_tree().quit(1)
		return
	if summary == null or not summary.has_method("is_summary_visible"):
		push_error("Game scene level summary fixture is missing")
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
	if game.is_run_finished():
		push_error("Game scene finished before target coins were collected")
		get_tree().quit(1)
		return
	if game.get_total_coin_count() != 0:
		push_error("Game scene added coins to total before target coin finish")
		get_tree().quit(1)
		return
	if not finish_line.visible or bool(finish_line.get("unlocked")):
		push_error("Finish line unlocked before target coins were collected")
		get_tree().quit(1)
		return

	var expected_payout: int = game.get_target_coin_count() + 1
	if not await _collect_coins(game, controller, expected_payout - game.get_run_coin_count()):
		push_error("Game scene could not collect enough coins for target")
		get_tree().quit(1)
		return
	await get_tree().process_frame
	if not finish_line.visible or not bool(finish_line.get("unlocked")):
		push_error("Finish line did not unlock while staying visible after target coins")
		get_tree().quit(1)
		return

	game._on_finish_body_entered(controller)
	if not game.is_run_finished():
		push_error("Game scene finish trigger did not finish run after target coins")
		get_tree().quit(1)
		return
	if finish_line.visible or not bool(finish_line.get("completed")):
		push_error("Finish line did not disappear after completed finish")
		get_tree().quit(1)
		return
	if game.get_total_coin_count() != expected_payout:
		push_error("Game scene did not add run coins to total on finish")
		get_tree().quit(1)
		return
	if not summary.is_summary_visible():
		push_error("Game scene did not show level summary after finish")
		get_tree().quit(1)
		return
	var summary_pause_menu := game.get_node_or_null("PauseMenu")
	if summary_pause_menu == null:
		push_error("Game scene pause menu fixture is missing")
		get_tree().quit(1)
		return
	_press_escape(summary_pause_menu)
	await get_tree().process_frame
	if bool(summary_pause_menu.get("open")) or get_tree().paused:
		push_error("Pause menu opened while level summary was visible")
		get_tree().quit(1)
		return
	if not _label_contains(summary, "Root/Panel/Margin/VBox/Stats/TimeRow/Value", "04.20s"):
		push_error("Level summary did not show final time")
		get_tree().quit(1)
		return
	if not _label_contains(summary, "Root/Panel/Margin/VBox/Stats/BestRow/Value", "04.20s"):
		push_error("Level summary did not show best time")
		get_tree().quit(1)
		return
	var best_time_panel := summary.get_node_or_null("Root/Panel/Margin/VBox/Stats/TimeRow/BEST_TIME_Panel") as Panel
	if best_time_panel == null or not best_time_panel.visible:
		push_error("Level summary did not show new best badge")
		get_tree().quit(1)
		return
	if not _label_contains(summary, "Root/Panel/Margin/VBox/Stats/CoinsRow/Value", str(expected_payout)):
		push_error("Level summary did not show collected coins")
		get_tree().quit(1)
		return
	if not _label_contains(summary, "Root/Panel/Margin/VBox/Stats/WalletRow/Value", str(expected_payout)):
		push_error("Level summary did not show wallet total")
		get_tree().quit(1)
		return
	var continue_button := summary.get_node_or_null("Root/Panel/Margin/VBox/Buttons/ContinueButton") as Button
	if continue_button == null or not continue_button.disabled:
		push_error("Level summary continue button should be disabled")
		get_tree().quit(1)
		return
	game._on_finish_body_entered(controller)
	if game.get_total_coin_count() != expected_payout:
		push_error("Game scene paid out the same finished run twice")
		get_tree().quit(1)
		return
	if not game.was_last_finish_new_best():
		push_error("Game scene did not mark first finish as a new best")
		get_tree().quit(1)
		return
	if not is_equal_approx(game.get_best_time(), 4.2):
		push_error("Game scene did not record level best time")
		get_tree().quit(1)
		return

	controller.global_position += Vector3(3, 0, 0)
	game.restart_run()
	await get_tree().process_frame
	await get_tree().physics_frame
	if game.is_run_finished():
		push_error("Game scene restart did not clear finished state")
		get_tree().quit(1)
		return
	if summary.is_summary_visible():
		push_error("Game scene restart did not hide level summary")
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
	CoinWallet.load_wallet()
	if game.get_total_coin_count() != expected_payout:
		push_error("Game scene restart changed total coins")
		get_tree().quit(1)
		return
	if bool(first_coin.get("is_collected")) or not first_coin.visible:
		push_error("Game scene restart did not restore collected coins")
		get_tree().quit(1)
		return
	if not finish_line.visible or bool(finish_line.get("unlocked")):
		push_error("Game scene restart did not restore finish line")
		get_tree().quit(1)
		return
	if _horizontal_distance(controller.global_position, spawn_point.global_position) > 0.05:
		push_error("Game scene restart did not reset player to spawn")
		get_tree().quit(1)
		return
	if not _basis_yaw_matches(controller.global_basis, initial_controller_basis):
		push_error("Game scene restart did not reset controller facing direction")
		get_tree().quit(1)
		return
	if not _basis_yaw_matches(goose_visual.global_basis, initial_visual_basis):
		push_error("Game scene restart did not reset goose visual facing direction")
		get_tree().quit(1)
		return
	if not await _wait_for_countdown_complete(game):
		push_error("Game scene restart countdown did not complete")
		get_tree().quit(1)
		return
	controller.global_position += Vector3(4, 0, 0)
	var pause_menu := game.get_node_or_null("PauseMenu")
	if pause_menu == null or not pause_menu.has_method("on_restart_pressed"):
		push_error("Game scene pause menu restart fixture is missing")
		get_tree().quit(1)
		return
	var pause_resume_button := pause_menu.get_node_or_null(
		"MenuRoot/MenuBackground/MarginContainer/VBoxContainer/ResumeButton"
	) as Button
	if pause_resume_button == null:
		push_error("Game scene pause menu resume button fixture is missing")
		get_tree().quit(1)
		return
	pause_resume_button.grab_focus()
	_press_escape(pause_menu)
	await get_tree().process_frame
	if not bool(pause_menu.get("open")) or not get_tree().paused:
		push_error("Pause menu did not open from Escape while UI had focus")
		get_tree().quit(1)
		return
	_press_escape(pause_menu)
	await get_tree().process_frame
	if bool(pause_menu.get("open")):
		push_error("Pause menu did not close from Escape while open")
		get_tree().quit(1)
		return
	pause_menu.set_open(false, false)
	get_tree().paused = false
	pause_menu.on_restart_pressed()
	await get_tree().process_frame
	await get_tree().physics_frame
	if not game.is_inside_tree():
		push_error("Pause menu restart reloaded the game scene")
		get_tree().quit(1)
		return
	if _horizontal_distance(controller.global_position, spawn_point.global_position) > 0.05:
		push_error("Pause menu restart did not reset player to spawn")
		get_tree().quit(1)
		return

	game.queue_free()
	await get_tree().process_frame

	var next_game := GAME_SCENE.instantiate()
	add_child(next_game)
	if not await _wait_for_course(next_game):
		push_error("Fresh game scene did not attach the default course")
		get_tree().quit(1)
		return
	var fresh_first_coin := next_game.get_node_or_null("CourseRoot/LevelFarm/coins/Path_1/Piece_000")
	if fresh_first_coin == null or bool(fresh_first_coin.get("is_collected")) or not fresh_first_coin.visible:
		push_error("Fresh game scene did not reload collected coins")
		get_tree().quit(1)
		return
	next_game.queue_free()
	await get_tree().process_frame
	if LevelProgress.has_method("reset_for_tests"):
		LevelProgress.reset_for_tests()

	print("Game scene OK")
	get_tree().quit(0)


func _horizontal_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))


func _basis_yaw_matches(a: Basis, b: Basis) -> bool:
	var a_forward := -a.z
	var b_forward := -b.z
	a_forward.y = 0.0
	b_forward.y = 0.0
	if a_forward.length_squared() <= 0.0001 or b_forward.length_squared() <= 0.0001:
		return false
	return a_forward.normalized().dot(b_forward.normalized()) > 0.999


func _press_escape(pause_menu: Node) -> void:
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = KEY_ESCAPE
	event.physical_keycode = KEY_ESCAPE
	pause_menu._input(event)


func _label_contains(root: Node, path: NodePath, expected_text: String) -> bool:
	var label := root.get_node_or_null(path) as Label
	return label != null and label.text.contains(expected_text)


func _collect_coins(game: Node, controller: Node3D, amount: int) -> bool:
	var collected := 0
	for node in game.get_tree().get_nodes_in_group(&"coins"):
		var coin := node as CoinPickup
		if coin == null or bool(coin.get("is_collected")):
			continue
		if not game.get_node("CourseRoot").is_ancestor_of(coin):
			continue
		var pickup_sound := coin.get_node_or_null("PickupSound") as AudioStreamPlayer3D
		if pickup_sound != null:
			pickup_sound.stream = null
		if coin.collect_from(controller):
			collected += 1
		if collected >= amount:
			return true
	return collected >= amount


func _coin_pickup_radius_is(coin: Node, expected: float) -> bool:
	var shape_node := coin.get_node_or_null("PickupArea/CollisionShape3D") as CollisionShape3D
	if shape_node == null:
		return false
	var sphere := shape_node.shape as SphereShape3D
	if sphere == null:
		return false
	return is_equal_approx(sphere.radius, expected)


func _wait_for_course(game: Node) -> bool:
	var deadline := Time.get_ticks_msec() + 20000
	while Time.get_ticks_msec() < deadline:
		var course_loaded := game.get_node_or_null("CourseRoot/LevelFarm") != null
		var spawn_ready := game.get("spawn_point") != null
		if course_loaded and spawn_ready and game.is_processing():
			await get_tree().physics_frame
			return true
		await get_tree().create_timer(0.05).timeout
	return false


func _wait_for_countdown_complete(game: Node) -> bool:
	var deadline := Time.get_ticks_msec() + 10000
	while Time.get_ticks_msec() < deadline:
		if not bool(game.get("countdown_active")):
			return true
		await get_tree().create_timer(0.05).timeout
	return false

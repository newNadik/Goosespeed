extends SceneTree


func _initialize() -> void:
	await process_frame
	var failures: Array[String] = []
	var goose_honk := root.get_node_or_null("GooseHonk")
	if goose_honk == null:
		failures.append("GooseHonk autoload is missing")
	else:
		if goose_honk.process_mode != Node.PROCESS_MODE_ALWAYS:
			failures.append("GooseHonk should process while paused")
		var player := goose_honk.get("player") as AudioStreamPlayer
		if player == null:
			failures.append("GooseHonk audio player is missing")
		else:
			if player.process_mode != Node.PROCESS_MODE_ALWAYS:
				failures.append("HonkPlayer should process while paused")
			if player.stream == null:
				failures.append("HonkPlayer has no stream")
		var min_pitch := float(goose_honk.get("min_pitch"))
		var max_pitch := float(goose_honk.get("max_pitch"))
		if min_pitch >= max_pitch:
			failures.append("GooseHonk pitch range is invalid")
		if min_pitch <= 0.0:
			failures.append("GooseHonk minimum pitch must be positive")

	if failures.is_empty():
		print("Goose honk OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

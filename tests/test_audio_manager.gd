extends Node


func _ready() -> void:
	await get_tree().process_frame
	var failures: Array[String] = []
	var audio_manager := get_node_or_null("/root/AudioManager")
	if audio_manager == null:
		failures.append("AudioManager autoload is missing")
	else:
		if audio_manager.process_mode != Node.PROCESS_MODE_ALWAYS:
			failures.append("AudioManager should keep processing for menu and settings audio")
		if not audio_manager.has_method("play_countdown_sfx"):
			failures.append("AudioManager is missing play_countdown_sfx")
		else:
			audio_manager.play_countdown_sfx()
			await get_tree().process_frame
			var countdown_player := audio_manager.get("_countdown_player") as AudioStreamPlayer
			if countdown_player == null:
				failures.append("CountdownPlayer is missing")
			else:
				if countdown_player.process_mode != Node.PROCESS_MODE_PAUSABLE:
					failures.append("CountdownPlayer should pause with the scene tree")
				if not countdown_player.playing:
					failures.append("CountdownPlayer did not start")
				var paused_position := countdown_player.get_playback_position()
				get_tree().paused = true
				await get_tree().create_timer(0.35, true).timeout
				var resumed_position := countdown_player.get_playback_position()
				get_tree().paused = false
				countdown_player.stop()
				if resumed_position - paused_position > 0.08:
					failures.append("CountdownPlayer advanced while paused")

	if failures.is_empty():
		print("Audio manager OK")
		get_tree().quit(0)
	else:
		get_tree().paused = false
		for failure in failures:
			push_error(failure)
		get_tree().quit(1)

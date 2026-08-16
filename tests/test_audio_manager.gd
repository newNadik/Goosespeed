extends Node


func _ready() -> void:
	await get_tree().process_frame
	var failures: Array[String] = []
	var original_music_enabled := GooseGameSettings.music_enabled
	var original_sfx_enabled := GooseGameSettings.sfx_enabled
	var original_music_volume := GooseGameSettings.music_volume
	var original_sfx_volume := GooseGameSettings.sfx_volume
	var audio_manager := get_node_or_null("/root/AudioManager")
	if audio_manager == null:
		failures.append("AudioManager autoload is missing")
	else:
		if audio_manager.process_mode != Node.PROCESS_MODE_ALWAYS:
			failures.append("AudioManager should keep processing for menu and settings audio")
		if not audio_manager.has_method("play_countdown_sfx"):
			failures.append("AudioManager is missing play_countdown_sfx")
		else:
			if (audio_manager.get("_menu_tracks") as Array).is_empty():
				failures.append("AudioManager has no exported menu music tracks")
			if (audio_manager.get("_game_tracks") as Array).is_empty():
				failures.append("AudioManager has no exported game music tracks")
			GooseGameSettings.set_music_enabled(true)
			GooseGameSettings.set_sfx_enabled(true)
			GooseGameSettings.set_music_volume(0.5)
			GooseGameSettings.set_sfx_volume(0.25)
			await get_tree().process_frame
			var music_bus := AudioServer.get_bus_index("Music")
			var sfx_bus := AudioServer.get_bus_index("SFX")
			if music_bus < 0 or sfx_bus < 0:
				failures.append("Audio buses were not created")
			else:
				if not is_equal_approx(AudioServer.get_bus_volume_db(music_bus), linear_to_db(0.5)):
					failures.append("AudioManager did not apply music volume")
				if not is_equal_approx(AudioServer.get_bus_volume_db(sfx_bus), linear_to_db(0.25)):
					failures.append("AudioManager did not apply SFX volume")
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
		_restore_audio_settings(original_music_enabled, original_sfx_enabled, original_music_volume, original_sfx_volume)
		print("Audio manager OK")
		get_tree().quit(0)
	else:
		get_tree().paused = false
		_restore_audio_settings(original_music_enabled, original_sfx_enabled, original_music_volume, original_sfx_volume)
		for failure in failures:
			push_error(failure)
		get_tree().quit(1)


func _restore_audio_settings(
	music_enabled: bool,
	sfx_enabled: bool,
	music_volume: float,
	sfx_volume: float,
) -> void:
	GooseGameSettings.music_enabled = music_enabled
	GooseGameSettings.sfx_enabled = sfx_enabled
	GooseGameSettings.music_volume = music_volume
	GooseGameSettings.sfx_volume = sfx_volume
	GooseGameSettings.save_settings()
	GooseGameSettings.settings_changed.emit()

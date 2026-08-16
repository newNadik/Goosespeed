extends Node

const MUSIC_BUS := "Music"
const SFX_BUS := "SFX"
const COUNTDOWN_STREAM := preload("res://assets/sounds/countdown.mp3")
const MENU_TRACKS: Array[AudioStream] = [
	preload("res://assets/music/menu/fresh_morning-fiddle-in-my-hands.mp3"),
]
const GAME_TRACKS: Array[AudioStream] = [
	preload("res://assets/music/game/jorisvermeer-bold-slide-guitar-indie.mp3"),
	preload("res://assets/music/game/jorisvermeer-bright-smiles-instrumental.mp3"),
	preload("res://assets/music/game/jorisvermeer-cheerful-arcade-theme.mp3"),
	preload("res://assets/music/game/jorisvermeer-indie-rock-drive-with-powerful-slide-guitar.mp3"),
	preload("res://assets/music/game/jorisvermeer-slide-rock-energy.mp3"),
]
const SILENT_DB := -80.0
const MUSIC_FADE_OUT_DURATION := 0.45

var _menu_player: AudioStreamPlayer
var _game_player: AudioStreamPlayer
var _countdown_player: AudioStreamPlayer
var _rng := RandomNumberGenerator.new()
var _menu_tracks: Array[AudioStream] = []
var _game_tracks: Array[AudioStream] = []
var _music_fade_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	_ensure_audio_buses()
	_menu_player = _create_music_player("MenuMusicPlayer")
	_game_player = _create_music_player("GameMusicPlayer")
	_countdown_player = _create_sfx_player("CountdownPlayer")
	_countdown_player.process_mode = Node.PROCESS_MODE_PAUSABLE
	_menu_tracks = MENU_TRACKS.duplicate()
	_game_tracks = GAME_TRACKS.duplicate()
	var settings := _get_game_settings()
	if settings != null and settings.has_signal("settings_changed") and not settings.is_connected("settings_changed", _on_settings_changed):
		settings.connect("settings_changed", _on_settings_changed)
	_apply_audio_settings()


func play_menu_music() -> void:
	_cancel_music_fade()
	_apply_audio_settings()
	_stop_player(_game_player)
	if _menu_tracks.is_empty():
		return
	_play_track(_menu_player, _menu_tracks[0])


func play_random_game_music() -> void:
	_cancel_music_fade()
	_apply_audio_settings()
	_stop_player(_menu_player)
	if _game_tracks.is_empty():
		return
	var index := _rng.randi_range(0, _game_tracks.size() - 1)
	_play_track(_game_player, _game_tracks[index])


func stop_music() -> void:
	_cancel_music_fade()
	_stop_player(_menu_player)
	_stop_player(_game_player)


func fade_out_music(duration := MUSIC_FADE_OUT_DURATION) -> void:
	_cancel_music_fade()
	var active_players := _get_active_music_players()
	if active_players.is_empty():
		return
	if duration <= 0.0:
		stop_music()
		return

	_music_fade_tween = create_tween()
	_music_fade_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_music_fade_tween.set_parallel(true)
	for player in active_players:
		_music_fade_tween.tween_property(player, "volume_db", SILENT_DB, duration)
	await _music_fade_tween.finished
	for player in active_players:
		_stop_player(player)
	_music_fade_tween = null


func play_countdown_sfx() -> void:
	_apply_audio_settings()
	if _countdown_player == null:
		return
	_countdown_player.stop()
	_countdown_player.play()


func _create_music_player(node_name: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = node_name
	player.bus = MUSIC_BUS
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(player)
	return player


func _create_sfx_player(node_name: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = node_name
	player.stream = COUNTDOWN_STREAM
	player.bus = SFX_BUS
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(player)
	return player


func _play_track(player: AudioStreamPlayer, track: AudioStream) -> void:
	if player == null or track == null:
		return
	_configure_loop(track)
	player.stream = track
	player.volume_db = 0.0
	player.play()


func _stop_player(player: AudioStreamPlayer) -> void:
	if player != null:
		player.stop()
		player.volume_db = 0.0


func _cancel_music_fade() -> void:
	if _music_fade_tween != null:
		_music_fade_tween.kill()
		_music_fade_tween = null
	if _menu_player != null:
		_menu_player.volume_db = 0.0
	if _game_player != null:
		_game_player.volume_db = 0.0


func _get_active_music_players() -> Array[AudioStreamPlayer]:
	var active_players: Array[AudioStreamPlayer] = []
	if _menu_player != null and _menu_player.playing:
		active_players.append(_menu_player)
	if _game_player != null and _game_player.playing:
		active_players.append(_game_player)
	return active_players


func _configure_loop(track: AudioStream) -> void:
	for property in track.get_property_list():
		if str(property.get("name", "")) == "loop":
			track.set("loop", true)
			return


func _ensure_audio_buses() -> void:
	_ensure_audio_bus(MUSIC_BUS)
	_ensure_audio_bus(SFX_BUS)


func _ensure_audio_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	AudioServer.add_bus()
	var bus_index := AudioServer.get_bus_count() - 1
	AudioServer.set_bus_name(bus_index, bus_name)


func _on_settings_changed() -> void:
	_apply_audio_settings()


func _apply_audio_settings() -> void:
	var settings := _get_game_settings()
	var music_enabled := bool(settings.get("music_enabled")) if settings != null else true
	var sfx_enabled := bool(settings.get("sfx_enabled")) if settings != null else true
	var music_volume := float(settings.get("music_volume")) if settings != null else 1.0
	var sfx_volume := float(settings.get("sfx_volume")) if settings != null else 1.0
	_set_bus_volume(MUSIC_BUS, music_volume)
	_set_bus_volume(SFX_BUS, sfx_volume)
	_set_bus_muted(MUSIC_BUS, not music_enabled)
	_set_bus_muted(SFX_BUS, not sfx_enabled)


func _get_game_settings() -> Node:
	return get_node_or_null("/root/GooseGameSettings")


func _set_bus_muted(bus_name: String, muted: bool) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index >= 0:
		AudioServer.set_bus_mute(bus_index, muted)


func _set_bus_volume(bus_name: String, volume: float) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		return
	var clamped_volume := clampf(volume, 0.0, 1.0)
	AudioServer.set_bus_volume_db(
		bus_index,
		linear_to_db(clamped_volume) if clamped_volume > 0.0 else SILENT_DB,
	)

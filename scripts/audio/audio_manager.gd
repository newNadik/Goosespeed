extends Node

const MUSIC_BUS := "Music"
const SFX_BUS := "SFX"
const MENU_MUSIC_DIR := "res://assets/music/menu"
const GAME_MUSIC_DIR := "res://assets/music/game"
const AUDIO_EXTENSIONS := ["mp3", "ogg", "wav"]
const COUNTDOWN_STREAM := preload("res://assets/sounds/countdown.mp3")

var _menu_player: AudioStreamPlayer
var _game_player: AudioStreamPlayer
var _countdown_player: AudioStreamPlayer
var _rng := RandomNumberGenerator.new()
var _menu_tracks: Array[AudioStream] = []
var _game_tracks: Array[AudioStream] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	_ensure_audio_buses()
	_menu_player = _create_music_player("MenuMusicPlayer")
	_game_player = _create_music_player("GameMusicPlayer")
	_countdown_player = _create_sfx_player("CountdownPlayer")
	_countdown_player.process_mode = Node.PROCESS_MODE_PAUSABLE
	_menu_tracks = _load_tracks_from_dir(MENU_MUSIC_DIR)
	_game_tracks = _load_tracks_from_dir(GAME_MUSIC_DIR)
	var settings := _get_game_settings()
	if settings != null and settings.has_signal("settings_changed") and not settings.is_connected("settings_changed", _on_settings_changed):
		settings.connect("settings_changed", _on_settings_changed)
	_apply_audio_settings()


func play_menu_music() -> void:
	_apply_audio_settings()
	_stop_player(_game_player)
	if _menu_tracks.is_empty():
		return
	_play_track(_menu_player, _menu_tracks[0])


func play_random_game_music() -> void:
	_apply_audio_settings()
	_stop_player(_menu_player)
	if _game_tracks.is_empty():
		return
	var index := _rng.randi_range(0, _game_tracks.size() - 1)
	_play_track(_game_player, _game_tracks[index])


func stop_music() -> void:
	_stop_player(_menu_player)
	_stop_player(_game_player)


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
	player.play()


func _stop_player(player: AudioStreamPlayer) -> void:
	if player != null:
		player.stop()


func _load_tracks_from_dir(dir_path: String) -> Array[AudioStream]:
	var tracks: Array[AudioStream] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_warning("AudioManager could not open music folder: %s" % dir_path)
		return tracks

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while not file_name.is_empty():
		if not dir.current_is_dir() and _is_audio_file(file_name):
			var stream := load("%s/%s" % [dir_path, file_name]) as AudioStream
			if stream != null:
				tracks.append(stream)
		file_name = dir.get_next()
	dir.list_dir_end()
	return tracks


func _is_audio_file(file_name: String) -> bool:
	var extension := file_name.get_extension().to_lower()
	return extension in AUDIO_EXTENSIONS


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
	_set_bus_muted(MUSIC_BUS, not music_enabled)
	_set_bus_muted(SFX_BUS, not sfx_enabled)


func _get_game_settings() -> Node:
	return get_node_or_null("/root/GooseGameSettings")


func _set_bus_muted(bus_name: String, muted: bool) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index >= 0:
		AudioServer.set_bus_mute(bus_index, muted)

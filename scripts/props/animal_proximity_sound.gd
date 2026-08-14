class_name AnimalProximitySound
extends Node3D

@export var sound_stream: AudioStream
@export var player_group := &"player"
@export var activation_distance := 18.0
@export var max_audible_distance := 14.0
@export var delay_range := Vector2(6.0, 16.0)
@export_range(0.0, 1.0, 0.01) var play_chance := 0.35
@export var volume_db := -6.0
@export var pitch_scale_range := Vector2(0.95, 1.05)
@export var proximity_check_interval := 0.35

var _rng := RandomNumberGenerator.new()
var _sound_player: AudioStreamPlayer3D
var _time_until_attempt := 0.0
var _time_until_proximity_check := 0.0
var _is_player_nearby := false


func _ready() -> void:
	_rng.randomize()
	_reset_attempt_timer()


func _process(delta: float) -> void:
	if sound_stream == null or player_group == &"":
		return

	_time_until_proximity_check -= delta
	if _time_until_proximity_check <= 0.0:
		_time_until_proximity_check = proximity_check_interval
		_is_player_nearby = _has_nearby_player()

	if not _is_player_nearby:
		return

	_time_until_attempt -= delta
	if _time_until_attempt > 0.0:
		return

	if _rng.randf() <= play_chance:
		_play_sound()
	_reset_attempt_timer()


func _ensure_sound_player() -> void:
	_sound_player = get_node_or_null("SoundPlayer") as AudioStreamPlayer3D
	if _sound_player == null:
		_sound_player = AudioStreamPlayer3D.new()
		_sound_player.name = "SoundPlayer"
		add_child(_sound_player)

	_sound_player.stream = sound_stream
	_sound_player.bus = "SFX"
	_sound_player.volume_db = volume_db
	_sound_player.max_distance = max_audible_distance


func _play_sound() -> void:
	_ensure_sound_player()
	if _sound_player.playing:
		return

	var low_pitch := minf(pitch_scale_range.x, pitch_scale_range.y)
	var high_pitch := maxf(pitch_scale_range.x, pitch_scale_range.y)
	_sound_player.pitch_scale = _rng.randf_range(low_pitch, high_pitch)
	_sound_player.play()


func _has_nearby_player() -> bool:
	var max_distance_squared := activation_distance * activation_distance
	for player in get_tree().get_nodes_in_group(player_group):
		if not player is Node3D:
			continue
		if global_position.distance_squared_to((player as Node3D).global_position) <= max_distance_squared:
			return true
	return false


func _reset_attempt_timer() -> void:
	var low_delay := minf(delay_range.x, delay_range.y)
	var high_delay := maxf(delay_range.x, delay_range.y)
	_time_until_attempt = _rng.randf_range(low_delay, high_delay)

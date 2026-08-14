extends Node

signal honked(position: Vector3)

const HONK_STREAM := preload("res://assets/sounds/honk-sound.mp3")

@export var min_pitch := 0.92
@export var max_pitch := 1.08

var player: AudioStreamPlayer
var random := RandomNumberGenerator.new()


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	random.randomize()
	player = AudioStreamPlayer.new()
	player.name = "HonkPlayer"
	player.stream = HONK_STREAM
	player.bus = "SFX"
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(player)


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed(&"player_honk"):
		honk()


func honk() -> void:
	if player == null:
		return
	player.pitch_scale = random.randf_range(min_pitch, max_pitch)
	player.play()
	honked.emit(_honk_origin())


func _honk_origin() -> Vector3:
	var nearest_player := _nearest_player()
	if nearest_player == null:
		return Vector3.ZERO
	return nearest_player.global_position


func _nearest_player() -> Node3D:
	var nearest: Node3D
	var nearest_distance_squared := INF
	for candidate in get_tree().get_nodes_in_group(&"player"):
		if not candidate is Node3D:
			continue
		var distance_squared := (candidate as Node3D).global_position.length_squared()
		if distance_squared < nearest_distance_squared:
			nearest = candidate as Node3D
			nearest_distance_squared = distance_squared
	return nearest

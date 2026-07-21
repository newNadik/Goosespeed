extends Node

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

class_name GooseGameHud
extends CanvasLayer

@onready var backend_label: Label = $Root/TopLeftPanel/Margin/VBox/BackendLabel
@onready var camera_label: Label = $Root/TopLeftPanel/Margin/VBox/CameraLabel
@onready var fps_label: Label = $Root/TopLeftPanel/Margin/VBox/FpsLabel
@onready var speed_label: Label = $Root/TopRightPanel/Margin/VBox/SpeedLabel
@onready var state_label: Label = $Root/TopRightPanel/Margin/VBox/StateLabel
@onready var timer_label: Label = $Root/TopRightPanel/Margin/VBox/TimerLabel

var player: Node
var state_bridge: Node
var elapsed_time := 0.0
var run_finished := false


func _process(_delta: float) -> void:
	_update_labels()


func set_player(value: Node) -> void:
	player = value
	state_bridge = player.get("movement_state_bridge") if player != null else null
	_update_labels()


func set_run_state(time_seconds: float, finished: bool) -> void:
	elapsed_time = time_seconds
	run_finished = finished
	_update_labels()


func _update_labels() -> void:
	backend_label.text = "Backend  %s" % _humanize_id(GooseGameSettings.movement_backend)
	camera_label.text = "Camera  %s" % _humanize_id(GooseGameSettings.camera_mode)
	fps_label.text = "FPS  %d" % Engine.get_frames_per_second()

	var state := _get_movement_state()
	speed_label.text = "Speed  %.1f m/s" % state.horizontal_speed
	state_label.text = "State  %s" % _state_text(state)
	timer_label.text = "Run  %05.2f%s" % [elapsed_time, "  FINISH" if run_finished else ""]


func _get_movement_state() -> RefCounted:
	if state_bridge != null and state_bridge.has_method("get_state"):
		return state_bridge.get_state()
	return preload("res://scripts/player/movement_state.gd").new()


func _state_text(state: RefCounted) -> String:
	if state.swimming:
		return "water"
	if state.sliding:
		return "sliding"
	if state.gliding:
		return "gliding"
	if state.flapping:
		return "flapping"
	if state.falling:
		return "falling"
	if state.grounded:
		return "ground"
	return "air"


func _humanize_id(value: String) -> String:
	if value == GooseGameSettings.MOVEMENT_Q3:
		return "Q3"
	if value == GooseGameSettings.MOVEMENT_PLATFORMER:
		return "Platformer"
	if value == GooseGameSettings.MOVEMENT_BASIC:
		return "Basic"
	if value == GooseGameSettings.CAMERA_THIRD_PERSON:
		return "Third Person"
	if value == GooseGameSettings.CAMERA_FIRST_PERSON:
		return "First Person"
	return value.replace("_", " ").capitalize()

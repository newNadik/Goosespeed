class_name GooseGameHud
extends CanvasLayer

@onready var speed_label: Label = $Root/TopRightPanel/Margin/VBox/SpeedLabel
@onready var state_label: Label = $Root/TopRightPanel/Margin/VBox/StateLabel
@onready var timer_label: Label = $Root/TopRightPanel/Margin/VBox/TimerLabel
@onready var hints_list: VBoxContainer = $Root/HintsPanel/Margin/HintsList

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
	_update_hints()
	var state := _get_movement_state()
	speed_label.text = "Speed  %.1f m/s" % state.horizontal_speed
	state_label.text = "State  %s" % _state_text(state)
	timer_label.text = "Run  %05.2f%s" % [elapsed_time, "  FINISH" if run_finished else ""]


func _get_movement_state() -> RefCounted:
	if state_bridge != null and state_bridge.has_method("get_state"):
		return state_bridge.get_state()
	return preload("res://scripts/player/movement_state.gd").new()


func _update_hints() -> void:
	var hints := _control_hints()
	while hints_list.get_child_count() < hints.size():
		var label := Label.new()
		hints_list.add_child(label)
	for index in hints_list.get_child_count():
		var label := hints_list.get_child(index) as Label
		if label == null:
			continue
		label.visible = index < hints.size()
		if index < hints.size():
			label.text = hints[index]


func _control_hints() -> Array[String]:
	return [
		"WASD  Move / Fly",
		"Mouse  Look",
		"Space  Jump / Hold Flight",
		"Shift  Walk",
		"Ctrl  Crouch / Exit Flight",
		"E  Wall Jump",
		"Q  Honk",
		"R  Restart",
		"C  Recenter Camera",
		"V  Toggle Camera",
		"Esc  Pause",
	]


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

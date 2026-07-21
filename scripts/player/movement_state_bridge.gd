class_name MovementStateBridge
extends Node

const MovementStateScript := preload("res://scripts/player/movement_state.gd")

signal state_changed(state)

var controller: Node
var current_state := MovementStateScript.new()


func _ready() -> void:
	if controller:
		_connect_controller()


func set_controller(value: Node) -> void:
	if controller and controller.movement_state_changed.is_connected(_on_controller_state_changed):
		controller.movement_state_changed.disconnect(_on_controller_state_changed)
	controller = value
	if is_inside_tree() and controller:
		_connect_controller()


func get_state() -> RefCounted:
	return current_state.duplicate_state()


func _connect_controller() -> void:
	if not controller.movement_state_changed.is_connected(_on_controller_state_changed):
		controller.movement_state_changed.connect(_on_controller_state_changed)
	current_state = controller.get_movement_state()


func _on_controller_state_changed(state: RefCounted) -> void:
	current_state = state.duplicate_state()
	state_changed.emit(current_state.duplicate_state())

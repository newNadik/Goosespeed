class_name GoosePlayerRoot
extends Node3D

@onready var input_adapter: Node = $InputAdapter
@onready var active_movement_controller: Node = $ActiveMovementController
@onready var glide_flap_modifier: Node = $GlideFlapModifier
@onready var movement_state_bridge: Node = $MovementStateBridge
@onready var goose_visual: Node = $GooseVisual


func _ready() -> void:
	active_movement_controller.input_adapter = input_adapter
	active_movement_controller.glide_flap_modifier = glide_flap_modifier
	movement_state_bridge.set_controller(active_movement_controller)
	goose_visual.set_state_bridge(movement_state_bridge)


func get_active_controller() -> Node:
	return active_movement_controller


func reset_to_spawn() -> void:
	active_movement_controller.reset_to_spawn()
	goose_visual.global_position = active_movement_controller.global_position


func set_spawn_transform(value: Transform3D) -> void:
	active_movement_controller.set_spawn_transform(value)

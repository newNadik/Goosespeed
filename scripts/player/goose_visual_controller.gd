class_name GooseVisualController
extends Node3D

const MovementStateScript := preload("res://scripts/player/movement_state.gd")

@export var body_bob_amount := 0.08
@export var max_lean_degrees := 10.0

@onready var body: Node3D = $Body
@onready var left_wing: Node3D = $Body/LeftWing
@onready var right_wing: Node3D = $Body/RightWing
@onready var neck: Node3D = $Body/Neck

var state_bridge: Node
var latest_state := MovementStateScript.new()


func _ready() -> void:
	if state_bridge:
		_connect_bridge()


func set_state_bridge(value: Node) -> void:
	if state_bridge and state_bridge.state_changed.is_connected(_on_state_changed):
		state_bridge.state_changed.disconnect(_on_state_changed)
	state_bridge = value
	if is_inside_tree() and state_bridge:
		_connect_bridge()


func _process(delta: float) -> void:
	global_position = global_position.lerp(latest_state.position, minf(delta * 20.0, 1.0))
	if not latest_state.facing_direction.is_zero_approx():
		var target_yaw := atan2(-latest_state.facing_direction.x, -latest_state.facing_direction.z)
		global_rotation.y = lerp_angle(global_rotation.y, target_yaw, minf(delta * 14.0, 1.0))

	var speed_scale := clampf(latest_state.horizontal_speed / 16.0, 0.0, 1.5)
	var bob := sin(Time.get_ticks_msec() * 0.018 * maxf(speed_scale, 0.2)) * body_bob_amount * speed_scale
	body.position.y = bob

	var lean := deg_to_rad(max_lean_degrees) * clampf(latest_state.velocity.y / 12.0, -1.0, 1.0)
	body.rotation.x = lerpf(body.rotation.x, -lean, minf(delta * 8.0, 1.0))

	var wing_target := 0.25
	if latest_state.gliding:
		wing_target = 1.1
	elif latest_state.flapping:
		wing_target = -0.75
	left_wing.rotation.z = lerp_angle(left_wing.rotation.z, wing_target, minf(delta * 12.0, 1.0))
	right_wing.rotation.z = lerp_angle(right_wing.rotation.z, -wing_target, minf(delta * 12.0, 1.0))
	var neck_target := -0.12 if latest_state.gliding or latest_state.falling else 0.08
	neck.rotation.x = lerpf(neck.rotation.x, neck_target, minf(delta * 8.0, 1.0))


func _connect_bridge() -> void:
	if not state_bridge.state_changed.is_connected(_on_state_changed):
		state_bridge.state_changed.connect(_on_state_changed)
	latest_state = state_bridge.get_state()


func _on_state_changed(state: RefCounted) -> void:
	latest_state = state

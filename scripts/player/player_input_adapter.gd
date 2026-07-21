class_name PlayerInputAdapter
extends Node

var move_vector := Vector2.ZERO
var look_delta := Vector2.ZERO
var jump_pressed := false
var jump_held := false
var speed_held := false
var control_held := false
var peck_pressed := false
var honk_pressed := false
var reset_camera_pressed := false


func _process(_delta: float) -> void:
	_sample()


func _physics_process(_delta: float) -> void:
	_sample()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		look_delta += (event as InputEventMouseMotion).relative


func _sample() -> void:
	move_vector = Input.get_vector(
		&"player_left",
		&"player_right",
		&"player_back",
		&"player_forward"
	)
	jump_pressed = jump_pressed or Input.is_action_just_pressed(&"player_jump")
	peck_pressed = peck_pressed or Input.is_action_just_pressed(&"player_special")
	honk_pressed = honk_pressed or Input.is_action_just_pressed(&"player_honk")
	reset_camera_pressed = reset_camera_pressed or Input.is_action_just_pressed(&"player_reset_camera")
	jump_held = Input.is_action_pressed(&"player_jump")
	speed_held = Input.is_action_pressed(&"player_walk")
	control_held = Input.is_action_pressed(&"player_crouch")


func consume_jump_pressed() -> bool:
	var result := jump_pressed
	jump_pressed = false
	return result


func consume_peck_pressed() -> bool:
	var result := peck_pressed
	peck_pressed = false
	return result


func consume_honk_pressed() -> bool:
	var result := honk_pressed
	honk_pressed = false
	return result


func consume_reset_camera_pressed() -> bool:
	var result := reset_camera_pressed
	reset_camera_pressed = false
	return result


func consume_look_delta() -> Vector2:
	var result := look_delta
	look_delta = Vector2.ZERO
	return result

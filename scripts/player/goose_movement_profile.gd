class_name GooseMovementProfile
extends Resource

const Q3NFlightControllerScript := preload("res://addons/goose-moves/scripts/q3_n_flight_controller.gd")
const FlightMovementMotorScript := preload("res://addons/goose-moves/scripts/flight_movement_motor.gd")

@export var flight_hold_threshold := Q3NFlightControllerScript.DEFAULT_FLIGHT_HOLD_THRESHOLD
@export var flap_cooldown := FlightMovementMotorScript.DEFAULT_FLAP_COOLDOWN
@export_range(0.0, 1.0, 0.05) var takeoff_runup_charge_ratio := 0.5
@export_range(0.0, 10.0, 0.1, "suffix:m/s2") var straight_run_bonus_acceleration := 0.0
@export_range(0.0, 20.0, 0.1, "suffix:m/s") var straight_run_bonus_max_speed := 0.0
@export_range(0.0, 20.0, 0.1, "suffix:m/s2") var straight_run_bonus_decay := 8.0
@export_range(0.0, 1.0, 0.01) var straight_run_min_forward_input := 0.9
@export_range(0.0, 1.0, 0.01) var straight_run_max_lateral_input := 0.18
@export_range(0.0, 90.0, 0.5, "degrees") var straight_run_max_direction_change_degrees := 8.0
@export_range(0.0, 90.0, 0.5, "degrees") var straight_run_max_floor_normal_change_degrees := 10.0

class_name GooseMovementProfile
extends Resource

const Q3NFlightControllerScript := preload("res://addons/goose-moves/scripts/q3_n_flight_controller.gd")
const FlightMovementMotorScript := preload("res://addons/goose-moves/scripts/flight_movement_motor.gd")

@export var flight_hold_threshold := Q3NFlightControllerScript.DEFAULT_FLIGHT_HOLD_THRESHOLD
@export var flap_cooldown := FlightMovementMotorScript.DEFAULT_FLAP_COOLDOWN
@export_range(0.0, 1.0, 0.05) var takeoff_runup_charge_ratio := 0.5

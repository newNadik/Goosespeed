extends Node

signal settings_changed

const GooseMovesRuntimeScript := preload("res://scripts/player/goose_moves_runtime.gd")
const SAVE_PATH := "user://goosespeed_settings.cfg"
const SECTION := "goosespeed"
const DEFAULT_FLIGHT_ORIENTATION_INTENSITY := 0.65
const DEFAULT_FLIGHT_ORIENTATION_SLERP_RATE := 7.0
const DEFAULT_HEAD_LOOK_ENABLED := true
const DEFAULT_HEAD_LOOK_INTENSITY := 1.0
const DEFAULT_HEAD_LOOK_SMOOTHNESS := 10.0

var debug_hud_visible := true
var flight_orientation_intensity := DEFAULT_FLIGHT_ORIENTATION_INTENSITY
var flight_orientation_slerp_rate := DEFAULT_FLIGHT_ORIENTATION_SLERP_RATE
var head_look_enabled := DEFAULT_HEAD_LOOK_ENABLED
var head_look_intensity := DEFAULT_HEAD_LOOK_INTENSITY
var head_look_smoothness := DEFAULT_HEAD_LOOK_SMOOTHNESS


func _ready() -> void:
	load_settings()
	call_deferred("_lock_goose_moves_backend")


func load_settings() -> void:
	var config := ConfigFile.new()
	var error := config.load(SAVE_PATH)
	if error != OK:
		_lock_goose_moves_backend()
		return

	debug_hud_visible = bool(config.get_value(SECTION, "debug_hud_visible", debug_hud_visible))
	flight_orientation_intensity = clampf(
		float(config.get_value(SECTION, "flight_orientation_intensity", flight_orientation_intensity)),
		0.0,
		1.0,
	)
	flight_orientation_slerp_rate = clampf(
		float(config.get_value(SECTION, "flight_orientation_slerp_rate", flight_orientation_slerp_rate)),
		1.0,
		20.0,
	)
	head_look_enabled = bool(config.get_value(SECTION, "head_look_enabled", head_look_enabled))
	head_look_intensity = clampf(
		float(config.get_value(SECTION, "head_look_intensity", head_look_intensity)),
		0.0,
		1.0,
	)
	head_look_smoothness = clampf(
		float(config.get_value(SECTION, "head_look_smoothness", head_look_smoothness)),
		1.0,
		20.0,
	)
	_lock_goose_moves_backend()


func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value(SECTION, "debug_hud_visible", debug_hud_visible)
	config.set_value(SECTION, "flight_orientation_intensity", flight_orientation_intensity)
	config.set_value(SECTION, "flight_orientation_slerp_rate", flight_orientation_slerp_rate)
	config.set_value(SECTION, "head_look_enabled", head_look_enabled)
	config.set_value(SECTION, "head_look_intensity", head_look_intensity)
	config.set_value(SECTION, "head_look_smoothness", head_look_smoothness)
	var error := config.save(SAVE_PATH)
	if error != OK:
		push_warning("Failed to save GooseSpeed settings: %s" % error)


func set_flight_orientation_intensity(value: float) -> void:
	var clamped_value := clampf(value, 0.0, 1.0)
	if is_equal_approx(flight_orientation_intensity, clamped_value):
		return
	flight_orientation_intensity = clamped_value
	save_settings()
	settings_changed.emit()


func set_flight_orientation_slerp_rate(value: float) -> void:
	var clamped_value := clampf(value, 1.0, 20.0)
	if is_equal_approx(flight_orientation_slerp_rate, clamped_value):
		return
	flight_orientation_slerp_rate = clamped_value
	save_settings()
	settings_changed.emit()


func set_head_look_enabled(value: bool) -> void:
	if head_look_enabled == value:
		return
	head_look_enabled = value
	save_settings()
	settings_changed.emit()


func set_head_look_intensity(value: float) -> void:
	var clamped_value := clampf(value, 0.0, 1.0)
	if is_equal_approx(head_look_intensity, clamped_value):
		return
	head_look_intensity = clamped_value
	save_settings()
	settings_changed.emit()


func set_head_look_smoothness(value: float) -> void:
	var clamped_value := clampf(value, 1.0, 20.0)
	if is_equal_approx(head_look_smoothness, clamped_value):
		return
	head_look_smoothness = clamped_value
	save_settings()
	settings_changed.emit()


func _lock_goose_moves_backend() -> void:
	GooseMovesRuntimeScript.lock_settings_backend(get_node_or_null("/root/Settings"))

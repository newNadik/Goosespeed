extends Node

signal settings_changed

const GooseMovesRuntimeScript := preload("res://scripts/player/goose_moves_runtime.gd")
const SAVE_PATH := "user://goosespeed_settings.cfg"
const SECTION := "goosespeed"
const MOVEMENT_Q3_FLIGHT := "q3_n_flight"
const CAMERA_THIRD_PERSON := "third_person"
const CAMERA_FIRST_PERSON := "first_person"
const CAMERA_MODES := [
	CAMERA_THIRD_PERSON,
	CAMERA_FIRST_PERSON,
]

var camera_mode := CAMERA_THIRD_PERSON
var debug_hud_visible := true


func _ready() -> void:
	load_settings()
	call_deferred("_lock_goose_moves_backend")


func load_settings() -> void:
	var config := ConfigFile.new()
	var error := config.load(SAVE_PATH)
	if error != OK:
		_lock_goose_moves_backend()
		return

	camera_mode = normalize_camera_mode(str(config.get_value(SECTION, "camera_mode", camera_mode)))
	debug_hud_visible = bool(config.get_value(SECTION, "debug_hud_visible", debug_hud_visible))
	_lock_goose_moves_backend()


func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value(SECTION, "camera_mode", camera_mode)
	config.set_value(SECTION, "debug_hud_visible", debug_hud_visible)
	var error := config.save(SAVE_PATH)
	if error != OK:
		push_warning("Failed to save GooseSpeed settings: %s" % error)


func set_camera_mode(value: String) -> void:
	var normalized := normalize_camera_mode(value)
	if camera_mode == normalized:
		return
	camera_mode = normalized
	save_settings()
	settings_changed.emit()


func normalize_camera_mode(value: String) -> String:
	if value in CAMERA_MODES:
		return value
	return CAMERA_THIRD_PERSON


func _lock_goose_moves_backend() -> void:
	GooseMovesRuntimeScript.lock_settings_backend(get_node_or_null("/root/Settings"))

extends Node

signal settings_changed

const SAVE_PATH := "user://goosespeed_settings.cfg"
const SECTION := "goosespeed"
const MOVEMENT_BASIC := "basic"
const MOVEMENT_Q3 := "q3"
const MOVEMENT_PLATFORMER := "platformer"
const MOVEMENT_BACKENDS := [
	MOVEMENT_Q3,
	MOVEMENT_PLATFORMER,
	MOVEMENT_BASIC,
]
const CAMERA_THIRD_PERSON := "third_person"
const CAMERA_FIRST_PERSON := "first_person"
const CAMERA_MODES := [
	CAMERA_THIRD_PERSON,
	CAMERA_FIRST_PERSON,
]

var movement_backend := MOVEMENT_Q3
var camera_mode := CAMERA_THIRD_PERSON
var debug_hud_visible := true


func _ready() -> void:
	load_settings()


func load_settings() -> void:
	var config := ConfigFile.new()
	var error := config.load(SAVE_PATH)
	if error != OK:
		return

	movement_backend = normalize_movement_backend(
		str(config.get_value(SECTION, "movement_backend", movement_backend))
	)
	camera_mode = normalize_camera_mode(str(config.get_value(SECTION, "camera_mode", camera_mode)))
	debug_hud_visible = bool(config.get_value(SECTION, "debug_hud_visible", debug_hud_visible))


func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value(SECTION, "movement_backend", movement_backend)
	config.set_value(SECTION, "camera_mode", camera_mode)
	config.set_value(SECTION, "debug_hud_visible", debug_hud_visible)
	var error := config.save(SAVE_PATH)
	if error != OK:
		push_warning("Failed to save GooseSpeed settings: %s" % error)


func set_movement_backend(value: String) -> void:
	var normalized := normalize_movement_backend(value)
	if movement_backend == normalized:
		return
	movement_backend = normalized
	save_settings()
	settings_changed.emit()


func set_camera_mode(value: String) -> void:
	var normalized := normalize_camera_mode(value)
	if camera_mode == normalized:
		return
	camera_mode = normalized
	save_settings()
	settings_changed.emit()


func normalize_movement_backend(value: String) -> String:
	if value in MOVEMENT_BACKENDS:
		return value
	return MOVEMENT_Q3


func normalize_camera_mode(value: String) -> String:
	if value in CAMERA_MODES:
		return value
	return CAMERA_THIRD_PERSON

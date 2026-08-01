extends Node

signal settings_changed

const GooseMovesRuntimeScript := preload("res://scripts/player/goose_moves_runtime.gd")
const SAVE_PATH := "user://goosespeed_settings.cfg"
const SECTION := "goosespeed"
const DEFAULT_HEAD_LOOK_ENABLED := true
const DEFAULT_HEAD_LOOK_INTENSITY := 1.0
const DEFAULT_HEAD_LOOK_SMOOTHNESS := 10.0
const HUD_DIRECTION_TO_FINISH := "direction_to_finish"
const HUD_TIMER := "timer"
const HUD_SPEED := "speed"
const HUD_FLIGHT_WIDGET := "flight_widget"
const HUD_FLIGHT_AIM_DOT := "flight_aim_dot"
const HUD_VERTICAL_SPEED := "vertical_speed"
const HUD_ACCELERATION := "acceleration"
const HUD_STATE := "state"
const HUD_FPS := "fps"
const HUD_RAW_MOVEMENT := "raw_movement"
const HUD_SURFACE_FLAGS := "surface_flags"
const HUD_INPUT_STATE := "input_state"
const HUD_DEBUG_STATE_VIEW := "debug_state_view"
const HUD_ELEMENTS := [
	HUD_DIRECTION_TO_FINISH,
	HUD_TIMER,
	HUD_SPEED,
	HUD_FLIGHT_WIDGET,
	HUD_FLIGHT_AIM_DOT,
	HUD_VERTICAL_SPEED,
	HUD_ACCELERATION,
	HUD_STATE,
	HUD_FPS,
	HUD_RAW_MOVEMENT,
	HUD_SURFACE_FLAGS,
	HUD_INPUT_STATE,
	HUD_DEBUG_STATE_VIEW,
]
const HUD_CORE_ELEMENTS := [
	HUD_DIRECTION_TO_FINISH,
	HUD_TIMER,
]
const HUD_DETAILED_ELEMENTS := [
	HUD_SPEED,
	HUD_FLIGHT_WIDGET,
	HUD_FLIGHT_AIM_DOT,
	HUD_VERTICAL_SPEED,
	HUD_ACCELERATION,
]
const HUD_DEBUG_ELEMENTS := [
	HUD_STATE,
	HUD_FPS,
	HUD_RAW_MOVEMENT,
	HUD_SURFACE_FLAGS,
	HUD_INPUT_STATE,
	HUD_DEBUG_STATE_VIEW,
]

var debug_hud_visible := false
var head_look_enabled := DEFAULT_HEAD_LOOK_ENABLED
var head_look_intensity := DEFAULT_HEAD_LOOK_INTENSITY
var head_look_smoothness := DEFAULT_HEAD_LOOK_SMOOTHNESS
var hud_elements := {}


func _ready() -> void:
	load_settings()
	call_deferred("_lock_goose_moves_backend")


func load_settings() -> void:
	_reset_hud_defaults()
	var config := ConfigFile.new()
	var error := config.load(SAVE_PATH)
	if error != OK:
		_sync_debug_hud_visible()
		_lock_goose_moves_backend()
		return

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
	for element in HUD_ELEMENTS:
		var key := "hud_%s" % element
		hud_elements[element] = bool(config.get_value(SECTION, key, hud_elements[element]))
	_sync_debug_hud_visible()
	_lock_goose_moves_backend()


func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value(SECTION, "head_look_enabled", head_look_enabled)
	config.set_value(SECTION, "head_look_intensity", head_look_intensity)
	config.set_value(SECTION, "head_look_smoothness", head_look_smoothness)
	for element in HUD_ELEMENTS:
		config.set_value(SECTION, "hud_%s" % element, bool(hud_elements[element]))
	var error := config.save(SAVE_PATH)
	if error != OK:
		push_warning("Failed to save GooseSpeed settings: %s" % error)


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


func is_hud_element_visible(element: String) -> bool:
	if not hud_elements.has(element):
		return false
	return bool(hud_elements[element])


func set_hud_element_visible(element: String, value: bool) -> void:
	if not hud_elements.has(element):
		return
	if bool(hud_elements[element]) == value:
		return
	hud_elements[element] = value
	_sync_debug_hud_visible()
	save_settings()
	settings_changed.emit()


func apply_hud_preset(preset: String) -> void:
	_reset_hud_defaults(true)
	if preset == "detailed" or preset == "debug":
		for element in HUD_DETAILED_ELEMENTS:
			hud_elements[element] = true
	if preset == "debug":
		for element in HUD_DEBUG_ELEMENTS:
			hud_elements[element] = true
	_sync_debug_hud_visible()
	save_settings()
	settings_changed.emit()


func _reset_hud_defaults(core_enabled := true) -> void:
	hud_elements.clear()
	for element in HUD_ELEMENTS:
		hud_elements[element] = core_enabled and element in HUD_CORE_ELEMENTS


func _sync_debug_hud_visible() -> void:
	debug_hud_visible = bool(hud_elements.get(HUD_DEBUG_STATE_VIEW, false))


func _lock_goose_moves_backend() -> void:
	GooseMovesRuntimeScript.lock_settings_backend(get_node_or_null("/root/Settings"))

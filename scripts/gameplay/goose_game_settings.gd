extends Node

signal settings_changed

const GooseMovesRuntimeScript := preload("res://scripts/player/goose_moves_runtime.gd")
const SAVE_PATH := "user://goosespeed_settings.cfg"
const SECTION := "goosespeed"
const DEFAULT_MUSIC_ENABLED := true
const DEFAULT_SFX_ENABLED := true
const DEFAULT_MUSIC_VOLUME := 0.70
const DEFAULT_SFX_VOLUME := 1.0
const DEFAULT_HEAD_LOOK_ENABLED := true
const DEFAULT_HEAD_LOOK_INTENSITY := 1.0
const DEFAULT_HEAD_LOOK_SMOOTHNESS := 10.0
const LIVE_BUILD_OVERRIDE_SETTING := "goosespeed/build/live_override"
const ACCESSORY_STRAW_HAT := "straw_hat"
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
	HUD_RAW_MOVEMENT,
	HUD_SURFACE_FLAGS,
	HUD_INPUT_STATE,
	HUD_DEBUG_STATE_VIEW,
]
const HUD_LIVE_RESTRICTED_ELEMENTS := [
	HUD_STATE,
	HUD_RAW_MOVEMENT,
	HUD_SURFACE_FLAGS,
	HUD_INPUT_STATE,
	HUD_DEBUG_STATE_VIEW,
]

var debug_hud_visible := false
var music_enabled := DEFAULT_MUSIC_ENABLED
var sfx_enabled := DEFAULT_SFX_ENABLED
var music_volume := DEFAULT_MUSIC_VOLUME
var sfx_volume := DEFAULT_SFX_VOLUME
var head_look_enabled := DEFAULT_HEAD_LOOK_ENABLED
var head_look_intensity := DEFAULT_HEAD_LOOK_INTENSITY
var head_look_smoothness := DEFAULT_HEAD_LOOK_SMOOTHNESS
var straw_hat_unlocked := false
var straw_hat_equipped := false
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

	music_enabled = bool(config.get_value(SECTION, "music_enabled", music_enabled))
	sfx_enabled = bool(config.get_value(SECTION, "sfx_enabled", sfx_enabled))
	music_volume = clampf(float(config.get_value(SECTION, "music_volume", music_volume)), 0.0, 1.0)
	sfx_volume = clampf(float(config.get_value(SECTION, "sfx_volume", sfx_volume)), 0.0, 1.0)
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
	straw_hat_unlocked = bool(config.get_value(SECTION, "straw_hat_unlocked", straw_hat_unlocked))
	straw_hat_equipped = (
		straw_hat_unlocked
		and bool(config.get_value(SECTION, "straw_hat_equipped", straw_hat_equipped))
	)
	for element in HUD_ELEMENTS:
		var key := "hud_%s" % element
		hud_elements[element] = bool(config.get_value(SECTION, key, hud_elements[element]))
	_sanitize_hud_for_build()
	_sync_debug_hud_visible()
	_lock_goose_moves_backend()


func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value(SECTION, "music_enabled", music_enabled)
	config.set_value(SECTION, "sfx_enabled", sfx_enabled)
	config.set_value(SECTION, "music_volume", music_volume)
	config.set_value(SECTION, "sfx_volume", sfx_volume)
	config.set_value(SECTION, "head_look_enabled", head_look_enabled)
	config.set_value(SECTION, "head_look_intensity", head_look_intensity)
	config.set_value(SECTION, "head_look_smoothness", head_look_smoothness)
	config.set_value(SECTION, "straw_hat_unlocked", straw_hat_unlocked)
	config.set_value(SECTION, "straw_hat_equipped", straw_hat_equipped)
	for element in HUD_ELEMENTS:
		config.set_value(SECTION, "hud_%s" % element, bool(hud_elements[element]))
	var error := config.save(SAVE_PATH)
	if error != OK:
		push_warning("Failed to save GooseSpeed settings: %s" % error)


func set_music_enabled(value: bool) -> void:
	if music_enabled == value:
		return
	music_enabled = value
	save_settings()
	settings_changed.emit()


func set_sfx_enabled(value: bool) -> void:
	if sfx_enabled == value:
		return
	sfx_enabled = value
	save_settings()
	settings_changed.emit()


func set_music_volume(value: float) -> void:
	var clamped_value := clampf(value, 0.0, 1.0)
	if is_equal_approx(music_volume, clamped_value):
		return
	music_volume = clamped_value
	save_settings()
	settings_changed.emit()


func set_sfx_volume(value: float) -> void:
	var clamped_value := clampf(value, 0.0, 1.0)
	if is_equal_approx(sfx_volume, clamped_value):
		return
	sfx_volume = clamped_value
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


func is_accessory_unlocked(accessory: String) -> bool:
	match accessory:
		ACCESSORY_STRAW_HAT:
			return straw_hat_unlocked
		_:
			return false


func is_accessory_equipped(accessory: String) -> bool:
	match accessory:
		ACCESSORY_STRAW_HAT:
			return straw_hat_unlocked and straw_hat_equipped
		_:
			return false


func unlock_accessory(accessory: String, equip_on_unlock := true) -> void:
	match accessory:
		ACCESSORY_STRAW_HAT:
			var changed := false
			if not straw_hat_unlocked:
				straw_hat_unlocked = true
				changed = true
			if equip_on_unlock and not straw_hat_equipped:
				straw_hat_equipped = true
				changed = true
			if changed:
				save_settings()
				settings_changed.emit()


func set_accessory_equipped(accessory: String, equipped: bool) -> void:
	match accessory:
		ACCESSORY_STRAW_HAT:
			if not straw_hat_unlocked:
				return
			if straw_hat_equipped == equipped:
				return
			straw_hat_equipped = equipped
			save_settings()
			settings_changed.emit()


func is_hud_element_visible(element: String) -> bool:
	if not hud_elements.has(element):
		return false
	if _is_live_restricted_hud_element(element):
		return false
	return bool(hud_elements[element])


func set_hud_element_visible(element: String, value: bool) -> void:
	if not hud_elements.has(element):
		return
	if value and _is_live_restricted_hud_element(element):
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
		hud_elements[HUD_FPS] = true
		for element in HUD_DEBUG_ELEMENTS:
			hud_elements[element] = true
	_sanitize_hud_for_build()
	_sync_debug_hud_visible()
	save_settings()
	settings_changed.emit()


func is_live_build() -> bool:
	return (
		bool(ProjectSettings.get_setting(LIVE_BUILD_OVERRIDE_SETTING, false))
		or OS.has_feature("live")
		or OS.has_feature("talo_live")
		or OS.has_feature("web")
	)


func _reset_hud_defaults(core_enabled := true) -> void:
	hud_elements.clear()
	for element in HUD_ELEMENTS:
		hud_elements[element] = core_enabled and element in HUD_CORE_ELEMENTS


func _sync_debug_hud_visible() -> void:
	debug_hud_visible = bool(hud_elements.get(HUD_DEBUG_STATE_VIEW, false))


func _sanitize_hud_for_build() -> void:
	if not is_live_build():
		return
	for element in HUD_LIVE_RESTRICTED_ELEMENTS:
		hud_elements[element] = false


func _is_live_restricted_hud_element(element: String) -> bool:
	return is_live_build() and element in HUD_LIVE_RESTRICTED_ELEMENTS


func _lock_goose_moves_backend() -> void:
	GooseMovesRuntimeScript.lock_settings_backend(get_node_or_null("/root/Settings"))

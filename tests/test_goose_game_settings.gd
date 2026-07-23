extends Node

const SETTINGS_OVERLAY_SCENE := preload("res://scenes/ui/goose_settings_overlay.tscn")


func _ready() -> void:
	var original_debug_visible: bool = GooseGameSettings.debug_hud_visible
	var original_flight_orientation_intensity: float = GooseGameSettings.flight_orientation_intensity
	var original_flight_orientation_slerp_rate: float = GooseGameSettings.flight_orientation_slerp_rate

	GooseGameSettings.debug_hud_visible = false
	GooseGameSettings.flight_orientation_intensity = 0.35
	GooseGameSettings.flight_orientation_slerp_rate = 9.5
	GooseGameSettings.save_settings()
	GooseGameSettings.debug_hud_visible = true
	GooseGameSettings.flight_orientation_intensity = 0.9
	GooseGameSettings.flight_orientation_slerp_rate = 2.0
	GooseGameSettings.load_settings()
	if GooseGameSettings.debug_hud_visible:
		push_error("Saved debug HUD visibility did not load")
		get_tree().quit(1)
		return
	if not is_equal_approx(GooseGameSettings.flight_orientation_intensity, 0.35):
		push_error("Saved flight visual intensity did not load")
		get_tree().quit(1)
		return
	if not is_equal_approx(GooseGameSettings.flight_orientation_slerp_rate, 9.5):
		push_error("Saved flight visual smoothness did not load")
		get_tree().quit(1)
		return

	var prototype_settings := get_node_or_null("/root/Settings")
	if prototype_settings != null and str(prototype_settings.get("character_controller")) != "q3_n_flight":
		push_error("GooseSpeed did not lock goose-moves to Q3 + Flight")
		get_tree().quit(1)
		return

	if not await _settings_overlay_is_valid():
		_restore_settings(
			original_debug_visible,
			original_flight_orientation_intensity,
			original_flight_orientation_slerp_rate,
		)
		get_tree().quit(1)
		return

	_restore_settings(
		original_debug_visible,
		original_flight_orientation_intensity,
		original_flight_orientation_slerp_rate,
	)
	print("Goose game settings OK")
	get_tree().quit(0)


func _settings_overlay_is_valid() -> bool:
	var overlay := SETTINGS_OVERLAY_SCENE.instantiate()
	add_child(overlay)
	await get_tree().process_frame
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	overlay.show_settings()
	await get_tree().process_frame
	if not overlay.visible:
		push_error("Settings overlay did not become visible")
		overlay.queue_free()
		return false
	if Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
		push_error("Settings overlay did not restore visible mouse mode")
		overlay.queue_free()
		return false
	var settings_tabs := overlay.get_node("Root/SettingsMenu/Panel/Margin/VBox/SettingsTabs") as TabContainer
	if settings_tabs.current_tab != 1:
		push_error("Settings overlay did not open movement adjustments")
		overlay.queue_free()
		return false
	var character_row := overlay.get_node("Root/SettingsMenu/Panel/Margin/VBox/SettingsTabs/Character/CharacterRow") as Control
	if character_row.visible:
		push_error("Settings overlay exposed movement backend switching")
		overlay.queue_free()
		return false
	var controller_title := overlay.get_node("Root/SettingsMenu/Panel/Margin/VBox/SettingsTabs/Character/ControllerTitle") as Label
	if not controller_title.text.contains("Q3 + Flight"):
		push_error("Settings overlay did not show Q3 + Flight adjustments")
		overlay.queue_free()
		return false
	var keybindings_button := overlay.get_node("Root/SettingsMenu/Panel/Margin/VBox/SettingsTabs/Character/KeybindingsButton") as Button
	if not keybindings_button.visible or keybindings_button.disabled:
		push_error("Settings overlay did not expose key bindings")
		overlay.queue_free()
		return false
	var visual_settings := overlay.find_child("GooseVisualSettings", true, false) as VBoxContainer
	if visual_settings == null:
		push_error("Settings overlay did not expose GooseSpeed visual settings")
		overlay.queue_free()
		return false
	var intensity_slider := overlay.find_child("FlightTiltIntensitySlider", true, false) as HSlider
	var slerp_slider := overlay.find_child("FlightTiltSlerpRateSlider", true, false) as HSlider
	if intensity_slider == null or slerp_slider == null:
		push_error("Settings overlay did not expose flight visual sliders")
		overlay.queue_free()
		return false
	intensity_slider.value = 0.5
	slerp_slider.value = 12.0
	await get_tree().process_frame
	if not is_equal_approx(GooseGameSettings.flight_orientation_intensity, 0.5):
		push_error("Flight visual intensity slider did not update settings")
		overlay.queue_free()
		return false
	if not is_equal_approx(GooseGameSettings.flight_orientation_slerp_rate, 12.0):
		push_error("Flight visual smoothness slider did not update settings")
		overlay.queue_free()
		return false
	overlay.hide_settings()
	await get_tree().process_frame
	if overlay.visible:
		push_error("Settings overlay did not hide")
		overlay.queue_free()
		return false
	overlay.queue_free()
	return true


func _restore_settings(
	debug_visible: bool,
	flight_orientation_intensity: float,
	flight_orientation_slerp_rate: float,
) -> void:
	GooseGameSettings.debug_hud_visible = debug_visible
	GooseGameSettings.flight_orientation_intensity = flight_orientation_intensity
	GooseGameSettings.flight_orientation_slerp_rate = flight_orientation_slerp_rate
	GooseGameSettings.save_settings()

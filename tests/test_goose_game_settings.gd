extends Node

const SETTINGS_OVERLAY_SCENE := preload("res://scenes/ui/goose_settings_overlay.tscn")


func _ready() -> void:
	var original_debug_visible: bool = GooseGameSettings.debug_hud_visible
	var original_music_enabled: bool = GooseGameSettings.music_enabled
	var original_sfx_enabled: bool = GooseGameSettings.sfx_enabled
	var original_head_look_enabled: bool = GooseGameSettings.head_look_enabled
	var original_head_look_intensity: float = GooseGameSettings.head_look_intensity
	var original_head_look_smoothness: float = GooseGameSettings.head_look_smoothness

	GooseGameSettings.debug_hud_visible = false
	GooseGameSettings.music_enabled = false
	GooseGameSettings.sfx_enabled = false
	GooseGameSettings.head_look_enabled = false
	GooseGameSettings.head_look_intensity = 0.4
	GooseGameSettings.head_look_smoothness = 11.5
	GooseGameSettings.save_settings()
	GooseGameSettings.debug_hud_visible = true
	GooseGameSettings.music_enabled = true
	GooseGameSettings.sfx_enabled = true
	GooseGameSettings.head_look_enabled = true
	GooseGameSettings.head_look_intensity = 0.8
	GooseGameSettings.head_look_smoothness = 3.0
	GooseGameSettings.load_settings()
	if GooseGameSettings.debug_hud_visible:
		push_error("Saved debug HUD visibility did not load")
		get_tree().quit(1)
		return
	if GooseGameSettings.music_enabled:
		push_error("Saved music enabled flag did not load")
		get_tree().quit(1)
		return
	if GooseGameSettings.sfx_enabled:
		push_error("Saved SFX enabled flag did not load")
		get_tree().quit(1)
		return
	if GooseGameSettings.head_look_enabled:
		push_error("Saved head-look enabled flag did not load")
		get_tree().quit(1)
		return
	if not is_equal_approx(GooseGameSettings.head_look_intensity, 0.4):
		push_error("Saved head-look intensity did not load")
		get_tree().quit(1)
		return
	if not is_equal_approx(GooseGameSettings.head_look_smoothness, 11.5):
		push_error("Saved head-look smoothness did not load")
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
			original_music_enabled,
			original_sfx_enabled,
			original_head_look_enabled,
			original_head_look_intensity,
			original_head_look_smoothness,
		)
		get_tree().quit(1)
		return

	_restore_settings(
		original_debug_visible,
		original_music_enabled,
		original_sfx_enabled,
		original_head_look_enabled,
		original_head_look_intensity,
		original_head_look_smoothness,
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
	var tabs := overlay.get_node("Root/MarginContainer/Margin/VBox/TabsArea/Tabs") as HBoxContainer
	if tabs.get_child_count() != GooseSettingsOverlay.TABS.size():
		push_error("Settings overlay did not build the expected tabs")
		overlay.queue_free()
		return false

	var audio_button := _find_tab_button(tabs, GooseSettingsOverlay.TAB_AUDIO)
	if audio_button == null:
		push_error("Settings overlay did not build the Audio tab")
		overlay.queue_free()
		return false
	audio_button.pressed.emit()
	await get_tree().process_frame
	var content_box := overlay.get_node("Root/MarginContainer/Margin/VBox/FolderBody/FolderMargin/ContentScroll/ContentCenter/ContentBox") as VBoxContainer
	var music_toggle := _find_toggle_with_label(content_box, "Music")
	var sfx_toggle := _find_toggle_with_label(content_box, "Sound Effects")
	if music_toggle == null or sfx_toggle == null:
		push_error("Settings overlay did not expose audio toggles")
		overlay.queue_free()
		return false
	music_toggle.button_pressed = false
	sfx_toggle.button_pressed = false
	await get_tree().process_frame
	if GooseGameSettings.music_enabled:
		push_error("Music toggle did not update settings")
		overlay.queue_free()
		return false
	if GooseGameSettings.sfx_enabled:
		push_error("SFX toggle did not update settings")
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


func _find_tab_button(tabs: HBoxContainer, label_text: String) -> Button:
	for child in tabs.get_children():
		var button := child as Button
		if button != null and button.text == label_text:
			return button
	return null


func _find_toggle_with_label(content_box: VBoxContainer, label_text: String) -> CheckButton:
	for row in content_box.get_children():
		if not row is HBoxContainer:
			continue
		var label := (row as HBoxContainer).get_child(0) as Label
		var toggle := (row as HBoxContainer).get_node_or_null("Toggle") as CheckButton
		if label != null and toggle != null and label.text == label_text:
			return toggle
	return null


func _restore_settings(
	debug_visible: bool,
	music_enabled: bool,
	sfx_enabled: bool,
	head_look_enabled: bool,
	head_look_intensity: float,
	head_look_smoothness: float,
) -> void:
	GooseGameSettings.debug_hud_visible = debug_visible
	GooseGameSettings.music_enabled = music_enabled
	GooseGameSettings.sfx_enabled = sfx_enabled
	GooseGameSettings.head_look_enabled = head_look_enabled
	GooseGameSettings.head_look_intensity = head_look_intensity
	GooseGameSettings.head_look_smoothness = head_look_smoothness
	GooseGameSettings.save_settings()

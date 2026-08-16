extends Node

const SETTINGS_OVERLAY_SCENE := preload("res://scenes/ui/goose_settings_overlay.tscn")


func _ready() -> void:
	var original_debug_visible: bool = GooseGameSettings.debug_hud_visible
	var original_music_enabled: bool = GooseGameSettings.music_enabled
	var original_sfx_enabled: bool = GooseGameSettings.sfx_enabled
	var original_music_volume: float = GooseGameSettings.music_volume
	var original_sfx_volume: float = GooseGameSettings.sfx_volume
	var original_head_look_enabled: bool = GooseGameSettings.head_look_enabled
	var original_head_look_intensity: float = GooseGameSettings.head_look_intensity
	var original_head_look_smoothness: float = GooseGameSettings.head_look_smoothness
	var original_straw_hat_unlocked: bool = GooseGameSettings.straw_hat_unlocked
	var original_straw_hat_equipped: bool = GooseGameSettings.straw_hat_equipped
	var original_live_override := bool(ProjectSettings.get_setting(
		GooseGameSettings.LIVE_BUILD_OVERRIDE_SETTING,
		false,
	))

	ProjectSettings.set_setting(GooseGameSettings.LIVE_BUILD_OVERRIDE_SETTING, false)
	GooseGameSettings.debug_hud_visible = false
	GooseGameSettings.music_enabled = false
	GooseGameSettings.sfx_enabled = false
	GooseGameSettings.music_volume = 0.35
	GooseGameSettings.sfx_volume = 0.65
	GooseGameSettings.head_look_enabled = false
	GooseGameSettings.head_look_intensity = 0.4
	GooseGameSettings.head_look_smoothness = 11.5
	GooseGameSettings.straw_hat_unlocked = true
	GooseGameSettings.straw_hat_equipped = true
	GooseGameSettings.save_settings()
	GooseGameSettings.debug_hud_visible = true
	GooseGameSettings.music_enabled = true
	GooseGameSettings.sfx_enabled = true
	GooseGameSettings.music_volume = 1.0
	GooseGameSettings.sfx_volume = 1.0
	GooseGameSettings.head_look_enabled = true
	GooseGameSettings.head_look_intensity = 0.8
	GooseGameSettings.head_look_smoothness = 3.0
	GooseGameSettings.straw_hat_unlocked = false
	GooseGameSettings.straw_hat_equipped = false
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
	if not is_equal_approx(GooseGameSettings.music_volume, 0.35):
		push_error("Saved music volume did not load")
		get_tree().quit(1)
		return
	if not is_equal_approx(GooseGameSettings.sfx_volume, 0.65):
		push_error("Saved SFX volume did not load")
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
	if not GooseGameSettings.straw_hat_unlocked:
		push_error("Saved straw hat unlocked flag did not load")
		get_tree().quit(1)
		return
	if not GooseGameSettings.straw_hat_equipped:
		push_error("Saved straw hat equipped flag did not load")
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
			original_music_volume,
			original_sfx_volume,
			original_head_look_enabled,
			original_head_look_intensity,
			original_head_look_smoothness,
			original_straw_hat_unlocked,
			original_straw_hat_equipped,
			original_live_override,
		)
		get_tree().quit(1)
		return

	ProjectSettings.set_setting(GooseGameSettings.LIVE_BUILD_OVERRIDE_SETTING, true)
	if not await _live_settings_overlay_is_valid():
		_restore_settings(
			original_debug_visible,
			original_music_enabled,
			original_sfx_enabled,
			original_music_volume,
			original_sfx_volume,
			original_head_look_enabled,
			original_head_look_intensity,
			original_head_look_smoothness,
			original_straw_hat_unlocked,
			original_straw_hat_equipped,
			original_live_override,
		)
		get_tree().quit(1)
		return
	ProjectSettings.set_setting(GooseGameSettings.LIVE_BUILD_OVERRIDE_SETTING, false)

	_restore_settings(
		original_debug_visible,
		original_music_enabled,
		original_sfx_enabled,
		original_music_volume,
		original_sfx_volume,
		original_head_look_enabled,
		original_head_look_intensity,
		original_head_look_smoothness,
		original_straw_hat_unlocked,
		original_straw_hat_equipped,
		original_live_override,
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
	var back_requests := [0]
	overlay.back_requested.connect(func() -> void: back_requests[0] += 1)
	overlay.back_button.grab_focus()
	_press_escape(overlay)
	await get_tree().process_frame
	if overlay.visible or int(back_requests[0]) != 1:
		push_error("Settings overlay did not close from Escape while UI had focus")
		overlay.queue_free()
		return false
	overlay.show_settings()
	await get_tree().process_frame

	var controls_button := _find_tab_button(tabs, GooseSettingsOverlay.TAB_CONTROLS)
	if controls_button == null:
		push_error("Settings overlay did not build the Controls tab")
		overlay.queue_free()
		return false
	controls_button.pressed.emit()
	await get_tree().process_frame
	var content_box := overlay.get_node("Root/MarginContainer/Margin/VBox/FolderBody/FolderMargin/ContentScroll/ContentCenter/ContentBox") as VBoxContainer
	var binding_grid := _find_binding_grid(content_box)
	if binding_grid == null:
		push_error("Settings overlay did not expose keybinding rows")
		overlay.queue_free()
		return false
	if binding_grid.columns != 5:
		push_error("Settings overlay keybinding grid did not reserve a gamepad column")
		overlay.queue_free()
		return false
	if not _binding_grid_has_gamepad_label(binding_grid):
		push_error("Settings overlay keybinding gamepad column is empty")
		overlay.queue_free()
		return false

	var audio_button := _find_tab_button(tabs, GooseSettingsOverlay.TAB_AUDIO)
	if audio_button == null:
		push_error("Settings overlay did not build the Audio tab")
		overlay.queue_free()
		return false
	audio_button.pressed.emit()
	await get_tree().process_frame
	content_box = overlay.get_node("Root/MarginContainer/Margin/VBox/FolderBody/FolderMargin/ContentScroll/ContentCenter/ContentBox") as VBoxContainer
	var music_volume_slider := _find_slider_with_label(content_box, "Music Volume")
	var sfx_volume_slider := _find_slider_with_label(content_box, "SFX Volume")
	if _find_control_with_label(content_box, "Music") != null or _find_control_with_label(content_box, "Sound Effects") != null:
		push_error("Settings overlay still exposes audio toggles")
		overlay.queue_free()
		return false
	if music_volume_slider == null or sfx_volume_slider == null:
		push_error("Settings overlay did not expose audio volume sliders")
		overlay.queue_free()
		return false
	music_volume_slider.value = 0.42
	sfx_volume_slider.value = 0.73
	await get_tree().process_frame
	if not is_equal_approx(GooseGameSettings.music_volume, 0.42):
		push_error("Music volume slider did not update settings")
		overlay.queue_free()
		return false
	if not is_equal_approx(GooseGameSettings.sfx_volume, 0.73):
		push_error("SFX volume slider did not update settings")
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


func _live_settings_overlay_is_valid() -> bool:
	var overlay := SETTINGS_OVERLAY_SCENE.instantiate()
	add_child(overlay)
	await get_tree().process_frame
	overlay.show_settings()
	await get_tree().process_frame
	var tabs := overlay.get_node("Root/MarginContainer/Margin/VBox/TabsArea/Tabs") as HBoxContainer
	if _find_tab_button(tabs, GooseSettingsOverlay.TAB_GOOSE_MOVES) != null:
		push_error("Live settings overlay exposed the Goose Moves tab")
		overlay.queue_free()
		return false
	var hud_button := _find_tab_button(tabs, GooseSettingsOverlay.TAB_HUD)
	if hud_button == null:
		push_error("Live settings overlay did not expose the HUD tab")
		overlay.queue_free()
		return false
	hud_button.pressed.emit()
	await get_tree().process_frame
	var content_box := overlay.get_node("Root/MarginContainer/Margin/VBox/FolderBody/FolderMargin/ContentScroll/ContentCenter/ContentBox") as VBoxContainer
	if _find_button_with_text(content_box, "Debug") != null:
		push_error("Live settings overlay exposed the Debug HUD preset")
		overlay.queue_free()
		return false
	if _find_control_with_label(content_box, "Raw movement") != null:
		push_error("Live settings overlay exposed debug HUD toggles")
		overlay.queue_free()
		return false
	if _find_control_with_label(content_box, "FPS") == null:
		push_error("Live settings overlay did not keep the FPS option")
		overlay.queue_free()
		return false
	overlay.queue_free()
	return true


func _press_escape(target: Node) -> void:
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = KEY_ESCAPE
	event.physical_keycode = KEY_ESCAPE
	target._input(event)


func _find_tab_button(tabs: HBoxContainer, label_text: String) -> Button:
	for child in tabs.get_children():
		var button := child as Button
		if button != null and button.text == label_text:
			return button
	return null


func _find_binding_grid(content_box: VBoxContainer) -> GridContainer:
	for child in content_box.get_children():
		var grid := child as GridContainer
		if grid != null:
			return grid
	return null


func _binding_grid_has_gamepad_label(grid: GridContainer) -> bool:
	for child in grid.get_children():
		var button := child as Button
		if button != null and (button.text.begins_with("Pad ") or button.text.begins_with("LS ")):
			return true
	return false


func _find_control_with_label(content_box: VBoxContainer, label_text: String) -> Control:
	for row in content_box.get_children():
		if not row is HBoxContainer:
			continue
		var label := (row as HBoxContainer).get_child(0) as Label
		if label != null and label.text == label_text:
			return row as Control
	return null


func _find_button_with_text(root: Node, label_text: String) -> Button:
	var button := root as Button
	if button != null and button.text == label_text:
		return button
	for child in root.get_children():
		var found := _find_button_with_text(child, label_text)
		if found != null:
			return found
	return null


func _find_slider_with_label(content_box: VBoxContainer, label_text: String) -> HSlider:
	for row in content_box.get_children():
		if not row is HBoxContainer:
			continue
		var label := (row as HBoxContainer).get_child(0) as Label
		var slider := (row as HBoxContainer).get_node_or_null("Slider") as HSlider
		if label != null and slider != null and label.text == label_text:
			return slider
	return null


func _restore_settings(
	debug_visible: bool,
	music_enabled: bool,
	sfx_enabled: bool,
	music_volume: float,
	sfx_volume: float,
	head_look_enabled: bool,
	head_look_intensity: float,
	head_look_smoothness: float,
	straw_hat_unlocked: bool,
	straw_hat_equipped: bool,
	live_override: bool,
) -> void:
	ProjectSettings.set_setting(GooseGameSettings.LIVE_BUILD_OVERRIDE_SETTING, live_override)
	GooseGameSettings.debug_hud_visible = debug_visible
	GooseGameSettings.music_enabled = music_enabled
	GooseGameSettings.sfx_enabled = sfx_enabled
	GooseGameSettings.music_volume = music_volume
	GooseGameSettings.sfx_volume = sfx_volume
	GooseGameSettings.head_look_enabled = head_look_enabled
	GooseGameSettings.head_look_intensity = head_look_intensity
	GooseGameSettings.head_look_smoothness = head_look_smoothness
	GooseGameSettings.straw_hat_unlocked = straw_hat_unlocked
	GooseGameSettings.straw_hat_equipped = straw_hat_equipped
	GooseGameSettings.save_settings()

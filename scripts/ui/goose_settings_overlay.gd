class_name GooseSettingsOverlay
extends CanvasLayer

signal back_requested

const GooseMovesRuntimeScript := preload("res://scripts/player/goose_moves_runtime.gd")
const GooseMovesSettingsScene := preload("res://addons/goose-moves/scenes/settings_menu.tscn")
const TAB_FONT := preload("res://assets/ui/fonts/Condor Medium Condensed.otf")

const TAB_CONTROLS := "Controls"
const TAB_VISUAL := "Visual"
const TAB_HUD := "HUD"
const TAB_GOOSE_MOVES := "Goose Moves"
const TAB_AUDIO := "Audio"
const TABS := [TAB_VISUAL, TAB_CONTROLS, TAB_HUD, TAB_GOOSE_MOVES, TAB_AUDIO]
const LISTENING_TEXT := "Press input..."
const GAMEPAD_BINDING_SLOT := 2
const MOVEMENT_SETTINGS_CONTROLLER := "q3_n_flight"
const VISUAL_MOVEMENT_SETTINGS := [
	"fov",
	"third_person_distance",
	"camera_distance",
]
const CONTROL_MOVEMENT_SETTINGS := [
	"mouse_sensitivity",
]

const INK := GooseSpeedPalette.INK
const ORANGE := GooseSpeedPalette.ORANGE
const PAPER := GooseSpeedPalette.PAPER_CREAM
const PAPER_LIGHT := GooseSpeedPalette.HIGHLIGHT_CREAM
const DISABLED_INK := GooseSpeedPalette.MID_SHADOW_BLUE_GREY
const TAB_BORDER := Color("#a8a192")

@onready var root: Control = $Root
@onready var back_button: Button = $Root/MarginContainer/Margin/VBox/Header/BackButton
@onready var tabs_row: HBoxContainer = $Root/MarginContainer/Margin/VBox/TabsArea/Tabs
@onready var content_box: VBoxContainer = $Root/MarginContainer/Margin/VBox/FolderBody/FolderMargin/ContentScroll/ContentCenter/ContentBox

var current_tab := TAB_VISUAL
var tab_buttons: Dictionary = {}
var syncing_hud_settings_controls := false
var syncing_game_settings_controls := false
var fullscreen_toggle: CheckButton
var music_volume_slider: HSlider
var music_volume_label: Label
var sfx_volume_slider: HSlider
var sfx_volume_label: Label
var movement_setting_controls := {}
var hud_toggles := {}
var goose_moves_settings_menu: Control
var readable_ui_font: SystemFont
var listening_action := ""
var listening_slot := -1
var binding_buttons: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	readable_ui_font = _create_readable_ui_font()
	back_button.pressed.connect(on_settings_back_requested)
	_connect_settings_signals()
	_build_tabs()
	hide_settings()


func _input(event: InputEvent) -> void:
	if _is_cancel_pressed(event):
		if not listening_action.is_empty():
			_stop_listening_for_binding()
			get_viewport().set_input_as_handled()
			return
		if visible:
			on_settings_back_requested()
			get_viewport().set_input_as_handled()
		return

	if listening_action.is_empty():
		return

	var binding: Variant
	if event is InputEventKey:
		if listening_slot == GAMEPAD_BINDING_SLOT:
			return
		var key_event := event as InputEventKey
		if not key_event.pressed or key_event.echo:
			return
		if key_event.keycode == KEY_ESCAPE:
			_stop_listening_for_binding()
			get_viewport().set_input_as_handled()
			return
		var keycode := int(key_event.physical_keycode)
		if keycode == 0:
			keycode = int(key_event.keycode)
		binding = keycode
	elif event is InputEventMouseButton:
		if listening_slot == GAMEPAD_BINDING_SLOT:
			return
		var mouse_event := event as InputEventMouseButton
		if not mouse_event.pressed:
			return
		binding = {
			"type": "mouse",
			"button_index": int(mouse_event.button_index),
		}
	elif event is InputEventJoypadButton:
		if listening_slot != GAMEPAD_BINDING_SLOT:
			return
		var joy_button_event := event as InputEventJoypadButton
		if not joy_button_event.pressed:
			return
		binding = {
			"type": "joy_button",
			"button_index": int(joy_button_event.button_index),
		}
	elif event is InputEventJoypadMotion:
		if listening_slot != GAMEPAD_BINDING_SLOT:
			return
		var joy_motion_event := event as InputEventJoypadMotion
		if absf(joy_motion_event.axis_value) < 0.5:
			return
		binding = {
			"type": "joy_motion",
			"axis": int(joy_motion_event.axis),
			"axis_value": -1.0 if joy_motion_event.axis_value < 0.0 else 1.0,
		}
	else:
		return

	KeybindingsSettings.set_binding(listening_action, listening_slot, binding)
	_track_setting_changed("controls", listening_action, {
		"slot": listening_slot,
		"binding": _get_binding_label(binding),
	})
	_stop_listening_for_binding()
	get_viewport().set_input_as_handled()


func _is_cancel_pressed(event: InputEvent) -> bool:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if not key_event.pressed or key_event.echo:
			return false
		return (
			event.is_action_pressed(&"ui_cancel")
			or key_event.keycode == KEY_ESCAPE
			or key_event.physical_keycode == KEY_ESCAPE
		)
	return event.is_action_pressed(&"ui_cancel")


func _process(_delta: float) -> void:
	if visible and Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func show_settings() -> void:
	_lock_movement_settings()
	visible = true
	root.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if not (current_tab in _get_available_tabs()):
		current_tab = TAB_VISUAL
	_show_tab(current_tab)
	_focus_current_tab()


func hide_settings() -> void:
	_stop_listening_for_binding(false)
	root.visible = false
	visible = false


func on_settings_back_requested() -> void:
	hide_settings()
	back_requested.emit()


func _connect_settings_signals() -> void:
	var settings := get_node_or_null("/root/Settings")
	if settings != null and settings.has_signal("settings_changed"):
		if not settings.is_connected("settings_changed", _on_external_settings_changed):
			settings.connect("settings_changed", _on_external_settings_changed)
	if not GooseGameSettings.settings_changed.is_connected(_on_external_settings_changed):
		GooseGameSettings.settings_changed.connect(_on_external_settings_changed)
	if not KeybindingsSettings.bindings_changed.is_connected(_refresh_keybinding_labels):
		KeybindingsSettings.bindings_changed.connect(_refresh_keybinding_labels)


func _on_external_settings_changed() -> void:
	_sync_game_settings_controls()
	_sync_hud_settings_controls()


func _lock_movement_settings() -> void:
	GooseMovesRuntimeScript.lock_settings_backend(get_node_or_null("/root/Settings"))


func _build_tabs() -> void:
	for child in tabs_row.get_children():
		child.queue_free()
	tab_buttons.clear()
	for tab_name in _get_available_tabs():
		var button := Button.new()
		button.text = tab_name
		button.custom_minimum_size = Vector2(160.0, 56.0)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_show_tab.bind(tab_name))
		tabs_row.add_child(button)
		tab_buttons[tab_name] = button
	_style_icon_button(back_button)


func _show_tab(tab_name: String) -> void:
	if not (tab_name in _get_available_tabs()):
		tab_name = TAB_VISUAL
	current_tab = tab_name
	_clear_content()
	hud_toggles.clear()
	_update_tab_styles()
	match tab_name:
		TAB_CONTROLS:
			_build_controls_tab()
		TAB_VISUAL:
			_build_visual_tab()
		TAB_HUD:
			_build_hud_tab()
		TAB_GOOSE_MOVES:
			_build_goose_moves_tab()
		TAB_AUDIO:
			_build_audio_tab()
	_sync_game_settings_controls()
	_sync_hud_settings_controls()


func _focus_current_tab() -> void:
	var tab_button := tab_buttons.get(current_tab) as Button
	if tab_button != null:
		tab_button.grab_focus()


func _clear_content() -> void:
	_stop_listening_for_binding(false)
	binding_buttons.clear()
	movement_setting_controls.clear()
	fullscreen_toggle = null
	goose_moves_settings_menu = null
	for child in content_box.get_children():
		child.queue_free()


func _update_tab_styles() -> void:
	for tab_name in _get_available_tabs():
		var button := tab_buttons.get(tab_name) as Button
		if button != null:
			_style_tab_button(button, tab_name == current_tab)


func _build_visual_tab() -> void:
	var settings := get_node_or_null("/root/Settings")
	var fullscreen := bool(settings.get("fullscreen")) if settings != null else false
	var row := _create_toggle_row("Fullscreen", fullscreen, _on_fullscreen_changed)
	fullscreen_toggle = row.get_node("Toggle") as CheckButton
	content_box.add_child(row)
	content_box.add_child(_create_group_title("Camera"))
	for key in VISUAL_MOVEMENT_SETTINGS:
		_add_movement_setting_slider(key)


func _build_controls_tab() -> void:
	for key in CONTROL_MOVEMENT_SETTINGS:
		_add_movement_setting_slider(key)
	_build_keybinding_rows()


func _build_keybinding_rows() -> void:
	binding_buttons.clear()

	var hint := _create_label("Select a binding slot, then press a key, mouse button, or gamepad input.")
	hint.add_theme_color_override("font_color", DISABLED_INK)
	content_box.add_child(hint)

	var grid := GridContainer.new()
	grid.columns = 5
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 8)
	content_box.add_child(grid)

	for action in KeybindingsSettings.get_actions():
		var label := _create_label(_get_action_display_label(action))
		label.custom_minimum_size = Vector2(220.0, 40.0)
		grid.add_child(label)

		var buttons: Array[Button] = []
		for slot in KeybindingsSettings.MAX_BINDINGS:
			var button := Button.new()
			button.custom_minimum_size = Vector2(130.0, 40.0)
			button.pressed.connect(_on_bind_pressed.bind(action, slot))
			_style_button(button, false)
			grid.add_child(button)
			buttons.append(button)
		binding_buttons[action] = buttons

		var clear_button := Button.new()
		clear_button.text = "Clear"
		clear_button.custom_minimum_size = Vector2(90.0, 40.0)
		clear_button.pressed.connect(_on_clear_binding_pressed.bind(action))
		_style_button(clear_button, false)
		grid.add_child(clear_button)

	var reset_button := Button.new()
	reset_button.text = "Reset Defaults"
	reset_button.custom_minimum_size = Vector2(180.0, 44.0)
	reset_button.pressed.connect(_on_reset_bindings_pressed)
	_style_button(reset_button, false)
	content_box.add_child(reset_button)
	_refresh_keybinding_labels()


func _build_hud_tab() -> void:
	var presets := HBoxContainer.new()
	presets.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	presets.add_theme_constant_override("separation", 10)
	presets.add_child(_create_hud_preset_button("Core", "core"))
	presets.add_child(_create_hud_preset_button("Detailed", "detailed"))
	if not GooseGameSettings.is_live_build():
		presets.add_child(_create_hud_preset_button("Debug", "debug"))
	content_box.add_child(presets)

	content_box.add_child(_create_group_title("Core"))
	_add_hud_group([
		[GooseGameSettings.HUD_DIRECTION_TO_FINISH, "Direction to finish"],
		[GooseGameSettings.HUD_TIMER, "Timer"],
	])
	content_box.add_child(_create_group_title("Detailed"))
	_add_hud_group([
		[GooseGameSettings.HUD_SPEED, "Speed"],
		[GooseGameSettings.HUD_FLIGHT_WIDGET, "Flight widget"],
		[GooseGameSettings.HUD_FLIGHT_AIM_DOT, "Flight aim dot"],
		[GooseGameSettings.HUD_VERTICAL_SPEED, "Vertical speed"],
		[GooseGameSettings.HUD_ACCELERATION, "Acceleration"],
	])
	content_box.add_child(_create_group_title("Performance"))
	_add_hud_group([
		[GooseGameSettings.HUD_FPS, "FPS"],
	])
	if not GooseGameSettings.is_live_build():
		content_box.add_child(_create_group_title("Debug"))
		_add_hud_group([
			[GooseGameSettings.HUD_STATE, "State"],
			[GooseGameSettings.HUD_RAW_MOVEMENT, "Raw movement"],
			[GooseGameSettings.HUD_SURFACE_FLAGS, "Surface flags"],
			[GooseGameSettings.HUD_INPUT_STATE, "Input state"],
			[GooseGameSettings.HUD_DEBUG_STATE_VIEW, "Debug state view"],
		])


func _build_audio_tab() -> void:
	var music_volume_row := _create_volume_slider_row(
		"Music Volume",
		GooseGameSettings.music_volume,
		_on_music_volume_changed,
	)
	music_volume_slider = music_volume_row.get_node("Slider") as HSlider
	music_volume_label = music_volume_row.get_node("ValueLabel") as Label
	content_box.add_child(music_volume_row)

	var sfx_volume_row := _create_volume_slider_row(
		"SFX Volume",
		GooseGameSettings.sfx_volume,
		_on_sfx_volume_changed,
	)
	sfx_volume_slider = sfx_volume_row.get_node("Slider") as HSlider
	sfx_volume_label = sfx_volume_row.get_node("ValueLabel") as Label
	content_box.add_child(sfx_volume_row)


func _get_available_tabs() -> Array:
	var tabs := TABS.duplicate()
	if GooseGameSettings.is_live_build():
		tabs.erase(TAB_GOOSE_MOVES)
	return tabs


func _build_goose_moves_tab() -> void:
	goose_moves_settings_menu = GooseMovesSettingsScene.instantiate() as Control
	goose_moves_settings_menu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	goose_moves_settings_menu.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_box.add_child(goose_moves_settings_menu)
	_configure_goose_moves_settings_menu.call_deferred(goose_moves_settings_menu)


func _configure_goose_moves_settings_menu(menu: Control) -> void:
	if not is_instance_valid(menu):
		return
	if menu.has_method("show_character_settings"):
		menu.show_character_settings()
	var title := menu.get_node_or_null("Panel/Margin/VBox/Title") as Control
	if title != null:
		title.visible = false
	var back := menu.get_node_or_null("Panel/Margin/VBox/BackButton") as Control
	if back != null:
		back.visible = false
	var keybindings := menu.get_node_or_null("Panel/Margin/VBox/SettingsTabs/Character/KeybindingsButton") as Control
	if keybindings != null:
		keybindings.visible = false
	var panel := menu.get_node_or_null("Panel") as PanelContainer
	if panel != null:
		panel.add_theme_stylebox_override("panel", _embedded_panel_style())


func _add_hud_group(items: Array) -> void:
	for item in items:
		var element := str(item[0])
		var label_text := str(item[1])
		var row := _create_hud_toggle_row(label_text, element)
		content_box.add_child(row)


func _create_group_title(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", ORANGE)
	_apply_readable_font(label, 23)
	return label


func _create_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(260.0, 0.0)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_color_override("font_color", INK)
	_apply_readable_font(label, 22)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label


func _create_toggle_row(label_text: String, pressed: bool, callback: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 12)
	row.add_child(_create_label(label_text))

	var toggle := CheckButton.new()
	toggle.name = "Toggle"
	toggle.button_pressed = pressed
	toggle.toggled.connect(callback)
	_style_check_button(toggle)
	row.add_child(toggle)
	return row


func _create_hud_preset_button(label_text: String, preset: String) -> Button:
	var button := Button.new()
	button.text = label_text
	button.custom_minimum_size = Vector2(0.0, 44.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(_on_hud_preset_pressed.bind(preset))
	_style_button(button, false)
	return button


func _create_hud_toggle_row(label_text: String, element: String) -> HBoxContainer:
	var row := _create_toggle_row(
		label_text,
		GooseGameSettings.is_hud_element_visible(element),
		_on_hud_toggle_changed.bind(element)
	)
	var toggle := row.get_node("Toggle") as CheckButton
	toggle.name = _hud_toggle_name(element)
	toggle.set_meta("hud_element", element)
	hud_toggles[element] = toggle
	return row


func _add_movement_setting_slider(key: String) -> void:
	var def := _get_movement_setting_def(key)
	if def.is_empty():
		return
	var value := _get_movement_setting_value(key, def)
	var row := _create_movement_slider_row(str(def["label"]), value, def, _on_movement_setting_slider_changed.bind(key))
	content_box.add_child(row)
	movement_setting_controls[key] = {
		"slider": row.get_node("Slider"),
		"value_label": row.get_node("ValueLabel"),
		"def": def,
	}


func _create_movement_slider_row(label_text: String, value: float, def: Dictionary, callback: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 12)
	row.add_child(_create_label(label_text))

	var slider := HSlider.new()
	slider.name = "Slider"
	slider.custom_minimum_size = Vector2(320.0, 36.0)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.min_value = float(def["min"])
	slider.max_value = float(def["max"])
	slider.step = float(def["step"])
	slider.value = value
	slider.value_changed.connect(callback)
	_style_slider(slider)
	row.add_child(slider)

	var value_label := _create_label(_format_movement_setting_value(value, def))
	value_label.name = "ValueLabel"
	value_label.custom_minimum_size = Vector2(82.0, 36.0)
	value_label.size_flags_horizontal = Control.SIZE_SHRINK_END
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value_label)
	return row


func _create_volume_slider_row(label_text: String, value: float, callback: Callable) -> HBoxContainer:
	var def := {
		"min": 0.0,
		"max": 1.0,
		"step": 0.01,
		"format": "percent",
	}
	return _create_movement_slider_row(label_text, clampf(value, 0.0, 1.0), def, callback)


func _sync_game_settings_controls() -> void:
	if (
		fullscreen_toggle == null
		and music_volume_slider == null
		and sfx_volume_slider == null
		and movement_setting_controls.is_empty()
	):
		return
	var settings := get_node_or_null("/root/Settings")
	syncing_game_settings_controls = true
	if fullscreen_toggle != null:
		fullscreen_toggle.set_pressed_no_signal(bool(settings.get("fullscreen")) if settings != null else false)
	if music_volume_slider != null:
		music_volume_slider.set_value_no_signal(GooseGameSettings.music_volume)
	if music_volume_label != null:
		music_volume_label.text = _format_movement_setting_value(GooseGameSettings.music_volume, {"format": "percent"})
	if sfx_volume_slider != null:
		sfx_volume_slider.set_value_no_signal(GooseGameSettings.sfx_volume)
	if sfx_volume_label != null:
		sfx_volume_label.text = _format_movement_setting_value(GooseGameSettings.sfx_volume, {"format": "percent"})
	for key in movement_setting_controls:
		var control_data := movement_setting_controls.get(key, {}) as Dictionary
		var slider := control_data.get("slider") as HSlider
		var value_label := control_data.get("value_label") as Label
		var def := control_data.get("def", {}) as Dictionary
		if slider == null or value_label == null or def.is_empty():
			continue
		var value := _get_movement_setting_value(str(key), def)
		slider.set_value_no_signal(value)
		value_label.text = _format_movement_setting_value(value, def)
	syncing_game_settings_controls = false


func _sync_hud_settings_controls() -> void:
	if hud_toggles.is_empty():
		return
	syncing_hud_settings_controls = true
	for element in hud_toggles:
		var toggle := hud_toggles.get(element) as CheckButton
		if toggle != null:
			toggle.set_pressed_no_signal(GooseGameSettings.is_hud_element_visible(element))
	syncing_hud_settings_controls = false


func _on_fullscreen_changed(enabled: bool) -> void:
	if syncing_game_settings_controls:
		return
	var settings := get_node_or_null("/root/Settings")
	if settings != null and settings.has_method("set_fullscreen"):
		settings.set_fullscreen(enabled)
	_track_setting_changed("visual", "fullscreen", enabled)


func _on_music_volume_changed(value: float) -> void:
	if music_volume_label != null:
		music_volume_label.text = _format_movement_setting_value(value, {"format": "percent"})
	if syncing_game_settings_controls:
		return
	GooseGameSettings.set_music_volume(value)
	_track_setting_changed("audio", "music_volume", value)


func _on_sfx_volume_changed(value: float) -> void:
	if sfx_volume_label != null:
		sfx_volume_label.text = _format_movement_setting_value(value, {"format": "percent"})
	if syncing_game_settings_controls:
		return
	GooseGameSettings.set_sfx_volume(value)
	_track_setting_changed("audio", "sfx_volume", value)


func _on_movement_setting_slider_changed(value: float, key: String) -> void:
	var control_data := movement_setting_controls.get(key, {}) as Dictionary
	var value_label := control_data.get("value_label") as Label
	var def := control_data.get("def", {}) as Dictionary
	if value_label != null and not def.is_empty():
		value_label.text = _format_movement_setting_value(value, def)
	if syncing_game_settings_controls:
		return
	var settings := get_node_or_null("/root/Settings")
	if settings != null and settings.has_method("set_controller_setting"):
		settings.set_controller_setting(key, value, MOVEMENT_SETTINGS_CONTROLLER)
		_track_setting_changed("movement", key, value)


func _on_hud_preset_pressed(preset: String) -> void:
	GooseGameSettings.apply_hud_preset(preset)
	_track_setting_changed("hud", "preset", preset)
	_sync_hud_settings_controls()


func _on_hud_toggle_changed(enabled: bool, element: String) -> void:
	if syncing_hud_settings_controls:
		return
	GooseGameSettings.set_hud_element_visible(element, enabled)
	_track_setting_changed("hud", element, enabled)


func _on_bind_pressed(action: String, slot: int) -> void:
	_stop_listening_for_binding()
	listening_action = action
	listening_slot = slot
	((binding_buttons[action] as Array)[slot] as Button).text = LISTENING_TEXT


func _on_clear_binding_pressed(action: String) -> void:
	if listening_action == action:
		_stop_listening_for_binding()
	KeybindingsSettings.clear_action(action)
	_track_setting_changed("controls", action, "cleared")


func _on_reset_bindings_pressed() -> void:
	_stop_listening_for_binding()
	KeybindingsSettings.reset_to_defaults()
	_track_setting_changed("controls", "bindings", "reset_defaults")


func _stop_listening_for_binding(refresh_labels := true) -> void:
	listening_action = ""
	listening_slot = -1
	if refresh_labels:
		_refresh_keybinding_labels()


func _refresh_keybinding_labels() -> void:
	for action in KeybindingsSettings.get_actions():
		if not binding_buttons.has(action):
			continue
		var buttons := binding_buttons[action] as Array
		var bindings := KeybindingsSettings.get_bindings(action)
		for slot in KeybindingsSettings.MAX_BINDINGS:
			if action == listening_action and slot == listening_slot:
				continue
			if slot >= buttons.size():
				continue
			var button := buttons[slot] as Button
			if not is_instance_valid(button):
				continue
			button.text = _get_binding_label(bindings[slot])


func _get_binding_label(binding: Variant) -> String:
	if binding is int:
		var keycode := int(binding)
		return OS.get_keycode_string(keycode as Key) if keycode > 0 else "---"
	if binding is Dictionary and str((binding as Dictionary).get("type", "")) == "mouse":
		var button_index := int((binding as Dictionary).get("button_index", -1))
		match button_index:
			MOUSE_BUTTON_LEFT:
				return "M1"
			MOUSE_BUTTON_RIGHT:
				return "M2"
			MOUSE_BUTTON_MIDDLE:
				return "M3"
			MOUSE_BUTTON_WHEEL_UP:
				return "Wheel Up"
			MOUSE_BUTTON_WHEEL_DOWN:
				return "Wheel Down"
			_:
				return "M%d" % button_index
	if binding is Dictionary and str((binding as Dictionary).get("type", "")) == "joy_button":
		return _get_joy_button_label(int((binding as Dictionary).get("button_index", -1)))
	if binding is Dictionary and str((binding as Dictionary).get("type", "")) == "joy_motion":
		return _get_joy_motion_label(
			int((binding as Dictionary).get("axis", -1)),
			float((binding as Dictionary).get("axis_value", 0.0)),
		)
	return "---"


func _get_joy_button_label(button_index: int) -> String:
	match button_index:
		JOY_BUTTON_A:
			return "Pad A"
		JOY_BUTTON_B:
			return "Pad B"
		JOY_BUTTON_X:
			return "Pad X"
		JOY_BUTTON_Y:
			return "Pad Y"
		JOY_BUTTON_BACK:
			return "Back"
		JOY_BUTTON_START:
			return "Start"
		JOY_BUTTON_LEFT_SHOULDER:
			return "LB"
		JOY_BUTTON_RIGHT_SHOULDER:
			return "RB"
		JOY_BUTTON_LEFT_STICK:
			return "LS"
		JOY_BUTTON_RIGHT_STICK:
			return "RS"
		_:
			return "Pad %d" % button_index


func _get_joy_motion_label(axis: int, axis_value: float) -> String:
	var suffix := "-" if axis_value < 0.0 else "+"
	match axis:
		JOY_AXIS_LEFT_X:
			return "LS X%s" % suffix
		JOY_AXIS_LEFT_Y:
			return "LS Y%s" % suffix
		JOY_AXIS_RIGHT_X:
			return "RS X%s" % suffix
		JOY_AXIS_RIGHT_Y:
			return "RS Y%s" % suffix
		JOY_AXIS_TRIGGER_LEFT:
			return "LT"
		JOY_AXIS_TRIGGER_RIGHT:
			return "RT"
		_:
			return "Axis %d%s" % [axis, suffix]


func _get_action_display_label(action: String) -> String:
	match action:
		"player_reset_camera":
			return "Reset Camera"
		"player_toggle_camera":
			return "Toggle Camera"
	var label := KeybindingsSettings.get_action_label(action)
	if label != action:
		return label
	return action.replace("_", " ").capitalize()


func _hud_toggle_name(element: String) -> String:
	var parts := element.split("_")
	var result := "Hud"
	for part in parts:
		result += part.capitalize()
	return "%sToggle" % result


func _style_button(button: Button, active: bool) -> void:
	button.add_theme_color_override("font_color", PAPER if active else INK)
	button.add_theme_color_override("font_focus_color", ORANGE)
	button.add_theme_color_override("font_pressed_color", PAPER)
	button.add_theme_color_override("font_hover_color", ORANGE)
	button.add_theme_color_override("font_disabled_color", DISABLED_INK)
	button.add_theme_font_override("font", readable_ui_font)
	button.add_theme_font_size_override("font_size", 22)
	button.add_theme_stylebox_override("normal", _button_style(ORANGE if active else Color("#f3e6d4"), true, TAB_BORDER))
	button.add_theme_stylebox_override("hover", _button_style(PAPER_LIGHT, true, ORANGE))
	button.add_theme_stylebox_override("pressed", _button_style(ORANGE, true, ORANGE))
	button.add_theme_stylebox_override("focus", _button_style(PAPER_LIGHT, true, ORANGE))


func _style_icon_button(button: Button) -> void:
	button.add_theme_color_override("font_color", INK)
	button.add_theme_color_override("font_focus_color", ORANGE)
	button.add_theme_color_override("font_pressed_color", ORANGE)
	button.add_theme_color_override("font_hover_color", ORANGE)
	button.add_theme_stylebox_override("normal", _button_style(Color.TRANSPARENT, false, Color.TRANSPARENT))
	button.add_theme_stylebox_override("hover", _button_style(Color.TRANSPARENT, false, Color.TRANSPARENT))
	button.add_theme_stylebox_override("pressed", _button_style(Color.TRANSPARENT, false, Color.TRANSPARENT))
	button.add_theme_stylebox_override("focus", _button_style(Color.TRANSPARENT, false, Color.TRANSPARENT))


func _style_tab_button(button: Button, active: bool) -> void:
	button.flat = false
	button.add_theme_color_override("font_color", ORANGE if active else INK)
	button.add_theme_color_override("font_focus_color", ORANGE)
	button.add_theme_color_override("font_pressed_color", ORANGE)
	button.add_theme_color_override("font_hover_color", ORANGE)
	button.add_theme_color_override("font_disabled_color", DISABLED_INK)
	button.add_theme_font_override("font", TAB_FONT)
	button.add_theme_font_size_override("font_size", 28)
	button.add_theme_stylebox_override("normal", _tab_style(active, false))
	button.add_theme_stylebox_override("hover", _tab_style(active, true))
	button.add_theme_stylebox_override("pressed", _tab_style(true, false))
	button.add_theme_stylebox_override("focus", _tab_style(active, true))


func _style_check_button(button: CheckButton) -> void:
	button.add_theme_font_override("font", readable_ui_font)
	button.add_theme_font_size_override("font_size", 20)
	button.add_theme_color_override("font_color", INK)
	button.add_theme_color_override("font_pressed_color", ORANGE)
	button.add_theme_color_override("font_hover_color", ORANGE)
	button.add_theme_color_override("font_focus_color", ORANGE)


func _style_slider(slider: HSlider) -> void:
	slider.add_theme_stylebox_override("slider", _slider_track_style(DISABLED_INK, 2))
	slider.add_theme_stylebox_override("grabber_area", _slider_track_style(ORANGE, 4))
	slider.add_theme_stylebox_override("grabber_area_highlight", _slider_track_style(ORANGE, 4))


func _slider_track_style(color: Color, thickness: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = thickness
	style.corner_radius_top_right = thickness
	style.corner_radius_bottom_right = thickness
	style.corner_radius_bottom_left = thickness
	style.content_margin_top = thickness
	style.content_margin_bottom = thickness
	return style


func _get_movement_setting_def(key: String) -> Dictionary:
	var settings := get_node_or_null("/root/Settings")
	if settings == null or not settings.has_method("get_controller_setting_defs"):
		return {}
	for def in settings.get_controller_setting_defs(MOVEMENT_SETTINGS_CONTROLLER):
		if str(def.get("key", "")) == key:
			return (def as Dictionary).duplicate(true)
	return {}


func _get_movement_setting_value(key: String, def: Dictionary) -> float:
	var settings := get_node_or_null("/root/Settings")
	if settings == null or not settings.has_method("get_controller_setting"):
		return float(def.get("default", 0.0))
	return float(settings.get_controller_setting(key, MOVEMENT_SETTINGS_CONTROLLER))


func _format_movement_setting_value(value: float, def: Dictionary) -> String:
	var format_text := str(def.get("format", "%.2f"))
	if format_text == "percent":
		return "%d%%" % roundi(clampf(value, 0.0, 1.0) * 100.0)
	var suffix := str(def.get("suffix", ""))
	return (format_text % value) + suffix


func _button_style(color: Color, border_visible: bool, border_color := ORANGE) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_width_left = 2 if border_visible else 0
	style.border_width_top = 2 if border_visible else 0
	style.border_width_right = 2 if border_visible else 0
	style.border_width_bottom = 2 if border_visible else 0
	style.border_color = border_color
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_right = 4
	style.corner_radius_bottom_left = 4
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = PAPER
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = INK
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_right = 4
	style.corner_radius_bottom_left = 4
	return style


func _embedded_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color.TRANSPARENT
	style.border_color = Color.TRANSPARENT
	style.content_margin_left = 0
	style.content_margin_top = 0
	style.content_margin_right = 0
	style.content_margin_bottom = 0
	return style


func _tab_style(active: bool, hovered: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#f3e6d4") if active else Color("#eadcc7")
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 0 if active else 2
	style.border_color = TAB_BORDER
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_right = 0
	style.corner_radius_bottom_left = 0
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 13 if active else 12
	style.content_margin_bottom = 13 if active else 5
	if active:
		style.expand_margin_bottom = 5
	if hovered:
		style.bg_color = Color("#f5ead8")
	return style


func _create_readable_ui_font() -> SystemFont:
	var font := SystemFont.new()
	font.font_names = PackedStringArray([
		"Avenir Next",
		"Helvetica Neue",
		"Arial",
		"Verdana",
	])
	return font


func _apply_readable_font(control: Control, size: int) -> void:
	control.add_theme_font_override("font", readable_ui_font)
	control.add_theme_font_size_override("font_size", size)


func _track_setting_changed(category: String, key: String, value: Variant) -> void:
	var analytics := get_tree().root.get_node_or_null("GameAnalytics")
	if analytics != null and analytics.has_method("track_setting_changed"):
		analytics.track_setting_changed(category, key, value)

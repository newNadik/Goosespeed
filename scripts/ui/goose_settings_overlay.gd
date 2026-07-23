class_name GooseSettingsOverlay
extends CanvasLayer

signal back_requested

const GooseMovesRuntimeScript := preload("res://scripts/player/goose_moves_runtime.gd")

@onready var root: Control = $Root
@onready var settings_menu = $Root/SettingsMenu
@onready var keybindings_menu = $Root/KeybindingsMenu

var syncing_visual_settings_controls := false
var flight_orientation_intensity_slider: HSlider
var flight_orientation_intensity_value: Label
var flight_orientation_slerp_slider: HSlider
var flight_orientation_slerp_value: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	settings_menu.back_requested.connect(on_settings_back_requested)
	settings_menu.keybindings_requested.connect(on_keybindings_requested)
	keybindings_menu.back_requested.connect(on_keybindings_back_requested)
	_apply_game_settings_scope(false)
	hide_settings()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo and Input.is_action_just_pressed(&"ui_cancel"):
		if keybindings_menu.visible:
			on_keybindings_back_requested()
			get_viewport().set_input_as_handled()
			return
		on_settings_back_requested()
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if visible and Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func show_settings() -> void:
	_lock_movement_settings()
	visible = true
	root.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	settings_menu.visible = true
	keybindings_menu.visible = false
	settings_menu.show_character_settings()
	_apply_game_settings_scope()
	_focus_character_settings()


func hide_settings() -> void:
	settings_menu.visible = false
	keybindings_menu.visible = false
	root.visible = false
	visible = false


func on_settings_back_requested() -> void:
	hide_settings()
	back_requested.emit()


func on_keybindings_requested() -> void:
	settings_menu.visible = false
	keybindings_menu.visible = true
	keybindings_menu.focus_first()


func on_keybindings_back_requested() -> void:
	keybindings_menu.visible = false
	settings_menu.visible = true
	_lock_movement_settings()
	settings_menu.show_character_settings()
	_apply_game_settings_scope()
	_focus_character_settings()


func _apply_game_settings_scope(include_visual_settings := true) -> void:
	var character_row := settings_menu.get_node_or_null("Panel/Margin/VBox/SettingsTabs/Character/CharacterRow") as Control
	if character_row != null:
		character_row.visible = false

	var character_option := settings_menu.get_node_or_null("Panel/Margin/VBox/SettingsTabs/Character/CharacterRow/CharacterOption") as BaseButton
	if character_option != null:
		character_option.disabled = true
	if not include_visual_settings:
		return
	_ensure_visual_settings_controls()
	_sync_visual_settings_controls()


func _focus_character_settings() -> void:
	if flight_orientation_intensity_slider != null and flight_orientation_intensity_slider.visible:
		flight_orientation_intensity_slider.grab_focus()
		return

	var preset_option := settings_menu.get_node_or_null("Panel/Margin/VBox/SettingsTabs/Character/PresetRow/PresetOption") as Control
	if preset_option != null and preset_option.visible:
		preset_option.grab_focus()
		return

	var keybindings_button := settings_menu.get_node_or_null("Panel/Margin/VBox/SettingsTabs/Character/KeybindingsButton") as Control
	if keybindings_button != null:
		keybindings_button.grab_focus()


func _lock_movement_settings() -> void:
	GooseMovesRuntimeScript.lock_settings_backend(get_node_or_null("/root/Settings"))


func _ensure_visual_settings_controls() -> void:
	var settings_box := settings_menu.get_node_or_null(
		"Panel/Margin/VBox/SettingsTabs/Character/ScrollContainer/ControllerSettingsBox"
	) as VBoxContainer
	if settings_box == null:
		return

	var existing_section := settings_box.get_node_or_null("GooseVisualSettings") as VBoxContainer
	if existing_section != null:
		if existing_section.is_queued_for_deletion():
			existing_section.name = "QueuedGooseVisualSettings"
		else:
			_bind_visual_settings_controls(existing_section)
			return

	var section := VBoxContainer.new()
	section.name = "GooseVisualSettings"
	section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section.add_theme_constant_override("separation", 8)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0.0, 8.0)
	section.add_child(spacer)

	var title := Label.new()
	title.name = "Title"
	title.text = "Goose visual"
	title.add_theme_font_size_override("font_size", 18)
	section.add_child(title)

	section.add_child(_create_visual_slider_row(
		"Flight tilt intensity",
		"FlightTiltIntensitySlider",
		"FlightTiltIntensityValue",
		0.0,
		1.0,
		0.05,
		_on_flight_orientation_intensity_changed,
	))
	section.add_child(_create_visual_slider_row(
		"Flight tilt smoothness",
		"FlightTiltSlerpRateSlider",
		"FlightTiltSlerpRateValue",
		1.0,
		20.0,
		0.5,
		_on_flight_orientation_slerp_changed,
	))

	settings_box.add_child(section)
	_bind_visual_settings_controls(section)


func _create_visual_slider_row(
	label_text: String,
	slider_name: String,
	value_name: String,
	min_value: float,
	max_value: float,
	step: float,
	callback: Callable
) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 12)

	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(150.0, 0.0)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)

	var slider := HSlider.new()
	slider.name = slider_name
	slider.custom_minimum_size = Vector2(180.0, 0.0)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = step
	slider.value_changed.connect(callback)
	row.add_child(slider)

	var value_label := Label.new()
	value_label.name = value_name
	value_label.custom_minimum_size = Vector2(54.0, 0.0)
	row.add_child(value_label)
	return row


func _bind_visual_settings_controls(section: Node) -> void:
	flight_orientation_intensity_slider = section.find_child(
		"FlightTiltIntensitySlider",
		true,
		false,
	) as HSlider
	flight_orientation_intensity_value = section.find_child(
		"FlightTiltIntensityValue",
		true,
		false,
	) as Label
	flight_orientation_slerp_slider = section.find_child(
		"FlightTiltSlerpRateSlider",
		true,
		false,
	) as HSlider
	flight_orientation_slerp_value = section.find_child(
		"FlightTiltSlerpRateValue",
		true,
		false,
	) as Label


func _sync_visual_settings_controls() -> void:
	if flight_orientation_intensity_slider == null or flight_orientation_slerp_slider == null:
		return
	syncing_visual_settings_controls = true
	flight_orientation_intensity_slider.set_value_no_signal(GooseGameSettings.flight_orientation_intensity)
	flight_orientation_slerp_slider.set_value_no_signal(GooseGameSettings.flight_orientation_slerp_rate)
	syncing_visual_settings_controls = false
	_update_visual_settings_value_labels()


func _update_visual_settings_value_labels() -> void:
	if flight_orientation_intensity_value != null:
		flight_orientation_intensity_value.text = "%.2f" % GooseGameSettings.flight_orientation_intensity
	if flight_orientation_slerp_value != null:
		flight_orientation_slerp_value.text = "%.1f" % GooseGameSettings.flight_orientation_slerp_rate


func _on_flight_orientation_intensity_changed(value: float) -> void:
	if syncing_visual_settings_controls:
		return
	GooseGameSettings.set_flight_orientation_intensity(value)
	_update_visual_settings_value_labels()


func _on_flight_orientation_slerp_changed(value: float) -> void:
	if syncing_visual_settings_controls:
		return
	GooseGameSettings.set_flight_orientation_slerp_rate(value)
	_update_visual_settings_value_labels()

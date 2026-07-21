class_name GooseBackendTuningPanel
extends VBoxContainer

const TUNING_KEYS := {
	"q3": [
		"movement_mode",
		"auto_jump",
		"crouch_slide",
		"wall_jump",
	],
	"platformer": [
		"max_run_speed",
		"ground_acceleration",
		"jump_velocity",
	],
}

@onready var title_label: Label = $TitleLabel
@onready var controls_box: VBoxContainer = $ControlsBox

var backend := ""
var control_data_by_key: Dictionary = {}


func _ready() -> void:
	rebuild(GooseGameSettings.movement_backend)


func rebuild(value: String) -> void:
	backend = value
	control_data_by_key.clear()
	for child in controls_box.get_children():
		child.queue_free()

	if not TUNING_KEYS.has(backend):
		title_label.text = "Backend Tuning"
		_add_empty_label()
		return

	title_label.text = "%s Tuning" % _backend_label(backend)
	for key in TUNING_KEYS[backend]:
		var def := _setting_def(key)
		if def.is_empty():
			continue
		_add_control(def)
	if controls_box.get_child_count() == 0:
		_add_empty_label()


func has_control(key: String) -> bool:
	return control_data_by_key.has(key)


func _add_control(def: Dictionary) -> void:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 10)
	controls_box.add_child(row)

	var label := Label.new()
	label.text = str(def["label"])
	label.custom_minimum_size = Vector2(150.0, 0.0)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)

	var key := str(def["key"])
	var value := Settings.get_controller_setting(key, _settings_backend())
	var control_type := str(def.get("control", "slider"))
	if control_type == "toggle":
		var toggle := CheckButton.new()
		toggle.set_pressed_no_signal(value >= 0.5)
		toggle.toggled.connect(_on_toggle_changed.bind(key))
		row.add_child(toggle)
		control_data_by_key[key] = {"toggle": toggle, "def": def}
	elif control_type == "option":
		var option := OptionButton.new()
		option.custom_minimum_size = Vector2(170.0, 0.0)
		option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for option_def in def.get("options", []):
			var index := option.item_count
			option.add_item(str(option_def["label"]))
			var option_value := float(option_def["value"])
			option.set_item_metadata(index, option_value)
			if is_equal_approx(option_value, value):
				option.select(index)
		option.item_selected.connect(_on_option_selected.bind(key, option))
		row.add_child(option)
		control_data_by_key[key] = {"option": option, "def": def}
	else:
		var slider := HSlider.new()
		slider.custom_minimum_size = Vector2(160.0, 0.0)
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.min_value = float(def["min"])
		slider.max_value = float(def["max"])
		slider.step = float(def["step"])
		slider.value = value
		slider.value_changed.connect(_on_slider_changed.bind(key))
		row.add_child(slider)

		var value_label := Label.new()
		value_label.custom_minimum_size = Vector2(72.0, 0.0)
		value_label.text = _format_value(value, def)
		row.add_child(value_label)
		control_data_by_key[key] = {"slider": slider, "label": value_label, "def": def}


func _add_empty_label() -> void:
	var label := Label.new()
	label.text = "No backend tuning yet"
	controls_box.add_child(label)


func _setting_def(key: String) -> Dictionary:
	for def in Settings.get_controller_setting_defs(_settings_backend()):
		if str(def["key"]) == key:
			return def
	return {}


func _settings_backend() -> String:
	if backend == GooseGameSettings.MOVEMENT_PLATFORMER:
		return Settings.CHARACTER_PLATFORMER
	return Settings.CHARACTER_Q3


func _backend_label(value: String) -> String:
	if value == GooseGameSettings.MOVEMENT_PLATFORMER:
		return "Platformer"
	if value == GooseGameSettings.MOVEMENT_BASIC:
		return "Basic"
	return "Q3"


func _on_toggle_changed(enabled: bool, key: String) -> void:
	Settings.set_controller_setting(key, 1.0 if enabled else 0.0, _settings_backend())


func _on_option_selected(index: int, key: String, option: OptionButton) -> void:
	Settings.set_controller_setting(key, float(option.get_item_metadata(index)), _settings_backend())


func _on_slider_changed(value: float, key: String) -> void:
	var data := control_data_by_key.get(key, {}) as Dictionary
	if data.has("label"):
		(data["label"] as Label).text = _format_value(value, data["def"] as Dictionary)
	Settings.set_controller_setting(key, value, _settings_backend())


func _format_value(value: float, def: Dictionary) -> String:
	return str(def.get("format", "%.2f")) % value + str(def.get("suffix", ""))

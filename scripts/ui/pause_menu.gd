class_name PauseMenu
extends CanvasLayer

const MAIN_MENU_SCENE := "res://scenes/ui/main_menu.tscn"
const ANIMATION_DURATION := 0.22
const CLOSED_OFFSET := Vector2(-920.0, 0.0)

@onready var menu_root: Control = $MenuRoot
@onready var scrim: ColorRect = $MenuRoot/Scrim
@onready var menu_background_shadow: TextureRect = $MenuRoot/MenuBackgroundShadow
@onready var menu_background: TextureRect = $MenuRoot/MenuBackground
@onready var resume_button: Button = $MenuRoot/MenuBackground/MarginContainer/VBoxContainer/ResumeButton
@onready var restart_button: Button = $MenuRoot/MenuBackground/MarginContainer/VBoxContainer/RestartButton
@onready var settings_button: Button = $MenuRoot/MenuBackground/MarginContainer/VBoxContainer/SettingsButton
@onready var main_menu_button: Button = $MenuRoot/MenuBackground/MarginContainer/VBoxContainer/MainMenuButton
@onready var quit_button: Button = $MenuRoot/MenuBackground/MarginContainer/VBoxContainer/QuitButton
@onready var settings_overlay = $GooseSettingsOverlay

var open := false
var menu_background_open_position := Vector2.ZERO
var menu_background_shadow_open_position := Vector2.ZERO
var scrim_open_color := Color.TRANSPARENT
var transition_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	menu_background_open_position = menu_background.position
	menu_background_shadow_open_position = menu_background_shadow.position
	scrim_open_color = scrim.color
	resume_button.pressed.connect(on_resume_pressed)
	restart_button.pressed.connect(on_restart_pressed)
	settings_button.pressed.connect(on_settings_pressed)
	main_menu_button.pressed.connect(on_main_menu_pressed)
	quit_button.pressed.connect(on_quit_pressed)
	settings_overlay.back_requested.connect(on_settings_back_requested)
	set_open(false, false)


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo or not Input.is_action_just_pressed(&"ui_cancel"):
		return
	if open and settings_overlay.visible:
		show_pause_menu_content()
		get_viewport().set_input_as_handled()
		return
	set_open(not open, true, true)
	get_viewport().set_input_as_handled()


func set_open(value: bool, update_mouse_mode := true, animate := false) -> void:
	if transition_tween:
		transition_tween.kill()
	open = value
	settings_overlay.hide_settings()
	if value:
		_show_pause_nodes()
		get_tree().paused = true
		if animate:
			_play_open_animation()
		else:
			_apply_open_state()
		resume_button.grab_focus()
		if update_mouse_mode:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		return

	if animate:
		_play_close_animation(update_mouse_mode)
	else:
		_apply_closed_state()
		get_tree().paused = false
		if update_mouse_mode:
			call_deferred("capture_mouse")


func capture_mouse() -> void:
	if not open and DisplayServer.window_is_focused():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func on_resume_pressed() -> void:
	set_open(false, true, true)


func on_restart_pressed() -> void:
	set_open(false, false)
	get_tree().paused = false
	get_tree().reload_current_scene()


func on_settings_pressed() -> void:
	set_pause_menu_content_visible(false)
	settings_overlay.show_settings()


func on_settings_back_requested() -> void:
	show_pause_menu_content()


func on_main_menu_pressed() -> void:
	set_open(false, false)
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func on_quit_pressed() -> void:
	get_tree().quit()


func show_pause_menu_content() -> void:
	settings_overlay.hide_settings()
	set_pause_menu_content_visible(true)
	settings_button.grab_focus()


func set_pause_menu_content_visible(value: bool) -> void:
	menu_background.visible = value
	menu_background_shadow.visible = value


func _show_pause_nodes() -> void:
	menu_root.visible = true
	set_pause_menu_content_visible(true)


func _apply_open_state() -> void:
	scrim.color = scrim_open_color
	menu_background.position = menu_background_open_position
	menu_background_shadow.position = menu_background_shadow_open_position


func _apply_closed_state() -> void:
	scrim.color = _get_closed_scrim_color()
	menu_background.position = menu_background_open_position + CLOSED_OFFSET
	menu_background_shadow.position = menu_background_shadow_open_position + CLOSED_OFFSET
	menu_root.visible = false
	set_pause_menu_content_visible(false)


func _play_open_animation() -> void:
	_apply_closed_state()
	_show_pause_nodes()
	transition_tween = create_tween()
	transition_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	transition_tween.set_parallel(true)
	transition_tween.tween_property(scrim, "color", scrim_open_color, ANIMATION_DURATION)
	transition_tween.tween_property(
		menu_background,
		"position",
		menu_background_open_position,
		ANIMATION_DURATION
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	transition_tween.tween_property(
		menu_background_shadow,
		"position",
		menu_background_shadow_open_position,
		ANIMATION_DURATION
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _play_close_animation(update_mouse_mode: bool) -> void:
	transition_tween = create_tween()
	transition_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	transition_tween.set_parallel(true)
	transition_tween.tween_property(scrim, "color", _get_closed_scrim_color(), ANIMATION_DURATION)
	transition_tween.tween_property(
		menu_background,
		"position",
		menu_background_open_position + CLOSED_OFFSET,
		ANIMATION_DURATION
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	transition_tween.tween_property(
		menu_background_shadow,
		"position",
		menu_background_shadow_open_position + CLOSED_OFFSET,
		ANIMATION_DURATION
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	transition_tween.finished.connect(_on_close_animation_finished.bind(update_mouse_mode))


func _on_close_animation_finished(update_mouse_mode: bool) -> void:
	_apply_closed_state()
	get_tree().paused = false
	if update_mouse_mode:
		call_deferred("capture_mouse")


func _get_closed_scrim_color() -> Color:
	return Color(scrim_open_color.r, scrim_open_color.g, scrim_open_color.b, 0.0)

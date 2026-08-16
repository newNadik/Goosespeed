class_name LevelSummaryPopup
extends CanvasLayer

signal restart_requested
signal continue_requested
signal main_menu_requested

@export var show_animation_duration := 0.28
@export var show_animation_offset := Vector2(0.0, -72.0)

@onready var root: Control = $Root
@onready var panel: PanelContainer = $Root/Panel
@onready var course_label: Label = $Root/Panel/Margin/VBox/Header/CourseLabel
@onready var status_label: Label = $Root/Panel/Margin/VBox/Header/StatusLabel
@onready var best_time_panel: Panel = $Root/Panel/Margin/VBox/Stats/TimeRow/BEST_TIME_Panel
@onready var time_value: Label = $Root/Panel/Margin/VBox/Stats/TimeRow/Value
@onready var best_row: HBoxContainer = $Root/Panel/Margin/VBox/Stats/BestRow
@onready var best_value: Label = $Root/Panel/Margin/VBox/Stats/BestRow/Value
@onready var coins_value: Label = $Root/Panel/Margin/VBox/Stats/CoinsRow/Value
@onready var wallet_value: Label = $Root/Panel/Margin/VBox/Stats/WalletRow/Value
@onready var restart_button: Button = $Root/Panel/Margin/VBox/Buttons/RestartButton
@onready var continue_button: Button = $Root/Panel/Margin/VBox/Buttons/ContinueButton
@onready var main_menu_button: Button = $Root/Panel/Margin/VBox/Buttons/MainMenuButton

var panel_rest_position := Vector2.ZERO
var show_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel_rest_position = panel.position
	restart_button.pressed.connect(func() -> void: restart_requested.emit())
	continue_button.pressed.connect(func() -> void: continue_requested.emit())
	main_menu_button.pressed.connect(func() -> void: main_menu_requested.emit())
	hide_summary()


func show_summary(
	course_name: String,
	time_seconds: float,
	best_time: float,
	is_new_best: bool,
	coins_collected: int,
	_coin_target: int,
	wallet_total: int
) -> void:
	course_label.text = course_name.to_upper()
	status_label.text = "NEW BEST" if is_new_best else "CLEARED"
	time_value.text = _format_time(time_seconds)
	best_time_panel.visible = is_new_best
	best_row.visible = best_time > 0.0 and not is_new_best
	best_value.text = _format_time(best_time)
	coins_value.text = str(maxi(coins_collected, 0))
	wallet_value.text = str(maxi(wallet_total, 0))
	root.visible = true
	_play_show_animation()
	restart_button.grab_focus()


func hide_summary() -> void:
	if show_tween != null:
		show_tween.kill()
		show_tween = null
	if panel != null:
		panel.position = panel_rest_position
		panel.modulate.a = 1.0
	root.visible = false


func is_summary_visible() -> bool:
	return root.visible


func _format_time(time_seconds: float) -> String:
	var safe_time := maxf(time_seconds, 0.0)
	return "%05.2fs" % safe_time


func _play_show_animation() -> void:
	if panel == null:
		return
	if show_tween != null:
		show_tween.kill()
	panel.position = panel_rest_position + show_animation_offset
	panel.modulate.a = 0.0
	show_tween = create_tween()
	show_tween.set_parallel(true)
	show_tween.set_ease(Tween.EASE_OUT)
	show_tween.set_trans(Tween.TRANS_CUBIC)
	show_tween.tween_property(panel, "position", panel_rest_position, show_animation_duration)
	show_tween.tween_property(panel, "modulate:a", 1.0, show_animation_duration)

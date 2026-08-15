class_name LevelSummaryPopup
extends CanvasLayer

signal restart_requested
signal continue_requested
signal main_menu_requested

@onready var root: Control = $Root
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


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
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
	coin_target: int,
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
	restart_button.grab_focus()


func hide_summary() -> void:
	root.visible = false


func is_summary_visible() -> bool:
	return root.visible


func _format_time(time_seconds: float) -> String:
	var safe_time := maxf(time_seconds, 0.0)
	return "%05.2fs" % safe_time

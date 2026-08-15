extends Node

const SUMMARY_SCENE := preload("res://scenes/ui/level_summary_popup.tscn")


func _ready() -> void:
	var summary := SUMMARY_SCENE.instantiate()
	add_child(summary)
	await get_tree().process_frame

	summary.show_summary("farm", 12.34, -1.0, false, 7, 10, 42)
	if not summary.is_summary_visible():
		push_error("Level summary did not show")
		get_tree().quit(1)
		return
	if summary.get_node("Root/Panel/Margin/VBox/Stats/BestRow").visible:
		push_error("Level summary best row should hide without a best time")
		get_tree().quit(1)
		return
	if summary.get_node("Root/Panel/Margin/VBox/Stats/TimeRow/BEST_TIME_Panel").visible:
		push_error("Level summary best badge should hide when finish is not a new best")
		get_tree().quit(1)
		return
	if not _label_contains(summary, "Root/Panel/Margin/VBox/Stats/CoinsRow/Label", "Tokens"):
		push_error("Level summary should label run coins as Tokens")
		get_tree().quit(1)
		return
	if not _label_contains(summary, "Root/Panel/Margin/VBox/Stats/CoinsRow/Value", "7"):
		push_error("Level summary should show tokens without target")
		get_tree().quit(1)
		return
	if not _label_contains(summary, "Root/Panel/Margin/VBox/Stats/WalletRow/Label", "Balance"):
		push_error("Level summary should label wallet as Balance")
		get_tree().quit(1)
		return

	summary.show_summary("farm", 10.0, 10.0, true, 12, 10, 54)
	if summary.get_node("Root/Panel/Margin/VBox/Stats/BestRow").visible:
		push_error("Level summary best row should hide when current run is a new best")
		get_tree().quit(1)
		return
	if not summary.get_node("Root/Panel/Margin/VBox/Stats/TimeRow/BEST_TIME_Panel").visible:
		push_error("Level summary best badge should show for a new best")
		get_tree().quit(1)
		return

	summary.show_summary("farm", 12.0, 10.0, false, 12, 10, 54)
	if not summary.get_node("Root/Panel/Margin/VBox/Stats/BestRow").visible:
		push_error("Level summary best row should show for existing non-new-best time")
		get_tree().quit(1)
		return

	print("Level summary popup OK")
	get_tree().quit(0)


func _label_contains(root: Node, path: NodePath, expected_text: String) -> bool:
	var label := root.get_node_or_null(path) as Label
	return label != null and label.text.contains(expected_text)

extends Node

const PLAYER_SCENE := preload("res://scenes/player/goose_player_root.tscn")
const HUD_SCENE := preload("res://scenes/ui/goose_game_hud.tscn")


func _ready() -> void:
	var player := PLAYER_SCENE.instantiate()
	var hud := HUD_SCENE.instantiate()
	add_child(player)
	add_child(hud)
	await get_tree().process_frame

	hud.set_player(player)
	hud.set_run_state(12.34, true)
	await get_tree().process_frame

	if hud.get_node_or_null("Root/TopLeftPanel") != null:
		push_error("HUD top-left status panel should be removed")
		get_tree().quit(1)
		return
	if not _label_contains(hud, "Root/TopRightPanel/Margin/VBox/TimerLabel", "12.34"):
		push_error("HUD timer label did not use run state")
		get_tree().quit(1)
		return
	for hint in [
		"Esc  Pause",
		"Shift  Walk",
		"Space  Jump / Hold Flight",
		"Ctrl  Crouch / Exit Flight",
		"Q  Honk",
	]:
		if not _hints_contain(hud, hint):
			push_error("HUD hints are missing %s" % hint)
			get_tree().quit(1)
			return

	print("Goose game HUD OK")
	get_tree().quit(0)


func _label_contains(root: Node, path: NodePath, expected_text: String) -> bool:
	var label := root.get_node_or_null(path) as Label
	return label != null and label.text.contains(expected_text)


func _hints_contain(hud: Node, expected_text: String) -> bool:
	var hints_list := hud.get_node_or_null("Root/HintsPanel/Margin/HintsList")
	if hints_list == null:
		return false
	for child in hints_list.get_children():
		var label := child as Label
		if label != null and label.visible and label.text.contains(expected_text):
			return true
	return false

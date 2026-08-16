class_name SceneTransitionFade
extends RefCounted

const LAYER_NAME := "SceneTransitionFadeLayer"
const RECT_NAME := "SceneTransitionFadeRect"
const FADE_COLOR := Color(0.101960786, 0.1882353, 0.27058825, 1.0)
const FADE_IN_DURATION := 0.5
const FADE_OUT_DURATION := 0.5


static func fade_in(tree: SceneTree, duration := FADE_IN_DURATION) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var rect := await _get_or_create_rect(tree)
	rect.color = Color(FADE_COLOR.r, FADE_COLOR.g, FADE_COLOR.b, 1.0)
	var tween := tree.create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(rect, "color:a", 0.0, maxf(duration, 0.01))
	await tween.finished
	var layer := rect.get_parent()
	if layer != null:
		layer.queue_free()


static func fade_out(tree: SceneTree, duration := FADE_OUT_DURATION) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var rect := await _get_or_create_rect(tree)
	rect.color = Color(FADE_COLOR.r, FADE_COLOR.g, FADE_COLOR.b, 0.0)
	var tween := tree.create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(rect, "color:a", 1.0, maxf(duration, 0.01))
	await tween.finished


static func cover(tree: SceneTree) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var rect := await _get_or_create_rect(tree)
	rect.color = Color(FADE_COLOR.r, FADE_COLOR.g, FADE_COLOR.b, 1.0)


static func get_fade_color() -> Color:
	return FADE_COLOR


static func _get_or_create_rect(tree: SceneTree) -> ColorRect:
	var layer := tree.root.get_node_or_null(LAYER_NAME) as CanvasLayer
	if layer == null:
		layer = CanvasLayer.new()
		layer.name = LAYER_NAME
		layer.layer = 120
		layer.process_mode = Node.PROCESS_MODE_ALWAYS

	var rect := layer.get_node_or_null(RECT_NAME) as ColorRect
	if rect == null:
		rect = ColorRect.new()
		rect.name = RECT_NAME
		rect.anchors_preset = Control.PRESET_FULL_RECT
		rect.anchor_right = 1.0
		rect.anchor_bottom = 1.0
		rect.grow_horizontal = Control.GROW_DIRECTION_BOTH
		rect.grow_vertical = Control.GROW_DIRECTION_BOTH
		rect.mouse_filter = Control.MOUSE_FILTER_STOP
		layer.add_child(rect)
	if not layer.is_inside_tree():
		tree.root.add_child.call_deferred(layer)
		await tree.process_frame
	return rect

class_name MenuPaperFitter
extends Node

@export var paper_path: NodePath
@export var shadow_path: NodePath
@export var design_height := 1080.0
@export var vertical_safe_margin := 24.0
@export var min_scale := 0.72

@onready var paper := get_node_or_null(paper_path) as Control
@onready var shadow := get_node_or_null(shadow_path) as Control


func _ready() -> void:
	get_viewport().size_changed.connect(update_layout)
	update_layout()


func update_layout() -> void:
	if paper == null:
		return

	var viewport_height := get_viewport().get_visible_rect().size.y
	if viewport_height <= 0.0 or design_height <= 0.0:
		return

	var usable_height = maxf(viewport_height - vertical_safe_margin * 2.0, 1.0)
	var fitted_scale := clampf(usable_height / design_height, min_scale, 1.0)
	paper.scale = Vector2(fitted_scale, fitted_scale)
	if shadow != null:
		shadow.scale = Vector2(fitted_scale, fitted_scale)

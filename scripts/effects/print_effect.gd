class_name PrintEffect
extends CanvasLayer

@export var print_enabled := true:
	set(value):
		print_enabled = value
		visible = value

@export_range(3.0, 12.0, 1.0) var colour_levels := 7.0:
	set(value):
		colour_levels = value
		_apply_shader_parameters()

@export_range(0.0, 1.0, 0.01) var effect_strength := 0.65:
	set(value):
		effect_strength = value
		_apply_shader_parameters()

@export_range(0.0, 1.0, 0.01) var dither_strength := 0.45:
	set(value):
		dither_strength = value
		_apply_shader_parameters()

@export_range(1.0, 4.0, 1.0) var pattern_scale := 1.0:
	set(value):
		pattern_scale = value
		_apply_shader_parameters()

@export_range(0.0, 1.0, 0.01) var shadow_start := 0.35:
	set(value):
		shadow_start = value
		_apply_shader_parameters()

@export_range(0.0, 1.0, 0.01) var shadow_end := 0.85:
	set(value):
		shadow_end = value
		_apply_shader_parameters()

@export_range(0.0, 1.0, 0.01) var tint_strength := 0.14:
	set(value):
		tint_strength = value
		_apply_shader_parameters()

@onready var screen_pass: ColorRect = $ScreenPass

var shader_material: ShaderMaterial


func _ready() -> void:
	visible = print_enabled
	if screen_pass.material is ShaderMaterial:
		shader_material = (screen_pass.material as ShaderMaterial).duplicate() as ShaderMaterial
		screen_pass.material = shader_material
	_apply_shader_parameters()


func _apply_shader_parameters() -> void:
	if shader_material == null:
		return
	shader_material.set_shader_parameter("colour_levels", colour_levels)
	shader_material.set_shader_parameter("effect_strength", effect_strength)
	shader_material.set_shader_parameter("dither_strength", dither_strength)
	shader_material.set_shader_parameter("pattern_scale", pattern_scale)
	shader_material.set_shader_parameter("shadow_start", shadow_start)
	shader_material.set_shader_parameter("shadow_end", shadow_end)
	shader_material.set_shader_parameter("tint_strength", tint_strength)

@tool
extends Node

@export var mesh_instance_path := NodePath("."):
	set(value):
		mesh_instance_path = value
		_material_instance = null
		_apply_albedo_color()

@export_range(0, 16, 1, "or_greater") var surface_index := 0:
	set(value):
		surface_index = value
		_material_instance = null
		_apply_albedo_color()

@export var albedo_color := Color.WHITE:
	set(value):
		albedo_color = value
		_apply_albedo_color()

var _material_instance: StandardMaterial3D


func _ready() -> void:
	_apply_albedo_color()


func _apply_albedo_color() -> void:
	if not is_inside_tree():
		return

	var mesh_instance := get_node_or_null(mesh_instance_path) as MeshInstance3D
	if mesh_instance == null:
		return

	if _material_instance == null:
		_material_instance = _get_material_instance(mesh_instance)

	if _material_instance == null:
		return

	_material_instance.albedo_color = albedo_color
	mesh_instance.set_surface_override_material(surface_index, _material_instance)


func _get_material_instance(mesh_instance: MeshInstance3D) -> StandardMaterial3D:
	var source_material := mesh_instance.get_surface_override_material(surface_index)
	if source_material == null:
		source_material = mesh_instance.get_active_material(surface_index)
	if source_material == null:
		return null

	var material := source_material.duplicate() as StandardMaterial3D
	return material

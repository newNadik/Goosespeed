@tool
extends MultiMeshInstance3D

@export var corn_mesh: Mesh:
	get:
		return _corn_mesh
	set(value):
		_corn_mesh = value
		_regenerate_if_allowed()

@export var field_size := Vector2(500.0, 70.0):
	get:
		return _field_size
	set(value):
		_field_size = value
		_regenerate_if_allowed()

@export_range(0.25, 20.0, 0.05) var spacing := 3.0:
	get:
		return _spacing
	set(value):
		_spacing = value
		_regenerate_if_allowed()

@export_range(0.0, 10.0, 0.05) var random_offset := 0.85:
	get:
		return _random_offset
	set(value):
		_random_offset = value
		_regenerate_if_allowed()

@export_range(0.05, 10.0, 0.05) var min_scale := 0.9:
	get:
		return _min_scale
	set(value):
		_min_scale = value
		_regenerate_if_allowed()

@export_range(0.05, 10.0, 0.05) var max_scale := 1.25:
	get:
		return _max_scale
	set(value):
		_max_scale = value
		_regenerate_if_allowed()

@export var y_offset := 0.0:
	get:
		return _y_offset
	set(value):
		_y_offset = value
		_regenerate_if_allowed()

@export var random_yaw := true:
	get:
		return _random_yaw
	set(value):
		_random_yaw = value
		_regenerate_if_allowed()

@export var auto_regenerate_in_editor := false
@export var generate_on_ready := false

@export var generation_seed := 1207:
	get:
		return _seed
	set(value):
		_seed = value
		_regenerate_if_allowed()

@export var regenerate := false:
	get:
		return false
	set(value):
		if value:
			_generate()

var _corn_mesh: Mesh
var _field_size := Vector2(500.0, 70.0)
var _spacing := 3.0
var _random_offset := 0.85
var _min_scale := 0.9
var _max_scale := 1.25
var _y_offset := 0.0
var _random_yaw := true
var _seed := 1207


func _ready() -> void:
	if generate_on_ready:
		_generate()


func _generate() -> void:
	if _corn_mesh == null or _spacing <= 0.0:
		multimesh = null
		return

	var columns: int = max(1, int(round(_field_size.x / _spacing)))
	var rows: int = max(1, int(round(_field_size.y / _spacing)))
	var instance_total := columns * rows

	var rng := RandomNumberGenerator.new()
	rng.seed = _seed

	var generated_multimesh := MultiMesh.new()
	generated_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	generated_multimesh.mesh = _corn_mesh
	generated_multimesh.instance_count = instance_total

	var index := 0
	for column in columns:
		for row in rows:
			var x := (float(column) - (float(columns) - 1.0) * 0.5) * _spacing
			var z := (float(row) - (float(rows) - 1.0) * 0.5) * _spacing
			x += rng.randf_range(-_random_offset, _random_offset)
			z += rng.randf_range(-_random_offset, _random_offset)

			var yaw := rng.randf_range(0.0, TAU) if _random_yaw else 0.0
			var instance_scale := rng.randf_range(_min_scale, _max_scale)
			var instance_basis := Basis(Vector3.UP, yaw).scaled(Vector3.ONE * instance_scale)
			generated_multimesh.set_instance_transform(
				index,
				Transform3D(instance_basis, Vector3(x, _y_offset, z))
			)
			index += 1

	multimesh = generated_multimesh
	custom_aabb = AABB(
		Vector3(-_field_size.x * 0.5, -4.0, -_field_size.y * 0.5),
		Vector3(_field_size.x, 24.0, _field_size.y)
	)


func _regenerate_if_allowed() -> void:
	if generate_on_ready or (Engine.is_editor_hint() and auto_regenerate_in_editor):
		_generate()

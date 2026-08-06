@tool
extends Path3D

const GENERATED_ROOT_NAME := "GeneratedPieces"

@export var piece_scene: PackedScene
@export_range(0.1, 100.0, 0.1) var spacing := 4.0
@export_range(0.0, 100.0, 0.1) var start_offset := 0.0
@export_range(0.0, 100.0, 0.1) var end_offset := 0.0
@export var y_offset := 0.0
@export var align_to_path := true
@export var rotation_offset_degrees := Vector3.ZERO
@export var clear_existing := true

@export var generate := false:
	get:
		return false
	set(value):
		if value:
			generate_pieces()


func generate_pieces() -> void:
	if curve == null:
		push_warning("PathPiecePlacer needs a Curve3D on the Path3D.")
		return

	if piece_scene == null:
		push_warning("PathPiecePlacer needs a piece_scene to instance.")
		return

	if spacing <= 0.0:
		push_warning("PathPiecePlacer spacing must be greater than 0.")
		return

	var path_length := curve.get_baked_length()
	var usable_length := path_length - start_offset - end_offset
	if usable_length < 0.0:
		push_warning("PathPiecePlacer offsets are longer than the path.")
		return

	var generated_root := _get_or_create_generated_root()
	if clear_existing:
		_clear_generated_root(generated_root)

	var distance := start_offset
	var index := 0
	while distance <= path_length - end_offset + 0.001:
		var piece := piece_scene.instantiate()
		piece.name = "Piece_%03d" % index
		generated_root.add_child(piece)

		if piece is Node3D:
			_place_piece(piece as Node3D, distance)

		_assign_instance_owner(piece, _get_scene_owner())
		distance += spacing
		index += 1


func _get_or_create_generated_root() -> Node3D:
	var existing := get_node_or_null(GENERATED_ROOT_NAME)
	if existing is Node3D:
		return existing as Node3D

	var generated_root := Node3D.new()
	generated_root.name = GENERATED_ROOT_NAME
	add_child(generated_root)
	_assign_owner(generated_root, _get_scene_owner())
	return generated_root


func _clear_generated_root(generated_root: Node) -> void:
	for child in generated_root.get_children():
		generated_root.remove_child(child)
		child.free()


func _place_piece(piece: Node3D, distance: float) -> void:
	var sampled_position := curve.sample_baked(distance)
	sampled_position.y += y_offset
	piece.position = sampled_position

	if not align_to_path:
		piece.rotation = _rotation_offset_radians()
		return

	var tangent := _sample_tangent(distance)
	if tangent.length_squared() <= 0.0001:
		piece.rotation = _rotation_offset_radians()
		return

	var yaw := atan2(-tangent.x, -tangent.z)
	piece.rotation = Vector3(0.0, yaw, 0.0) + _rotation_offset_radians()


func _rotation_offset_radians() -> Vector3:
	return Vector3(
		deg_to_rad(rotation_offset_degrees.x),
		deg_to_rad(rotation_offset_degrees.y),
		deg_to_rad(rotation_offset_degrees.z)
	)


func _sample_tangent(distance: float) -> Vector3:
	var path_length := curve.get_baked_length()
	var before_distance: float = max(0.0, distance - 0.25)
	var after_distance: float = min(path_length, distance + 0.25)

	if is_equal_approx(before_distance, after_distance):
		return Vector3.ZERO

	var before := curve.sample_baked(before_distance)
	var after := curve.sample_baked(after_distance)
	return (after - before).normalized()


func _get_scene_owner() -> Node:
	if owner != null:
		return owner

	var edited_root := get_tree().edited_scene_root if Engine.is_editor_hint() and get_tree() != null else null
	return edited_root if edited_root != null else self


func _assign_owner(node: Node, scene_owner: Node) -> void:
	if node != scene_owner:
		node.owner = scene_owner

	for child in node.get_children():
		_assign_owner(child, scene_owner)


func _assign_instance_owner(node: Node, scene_owner: Node) -> void:
	if node != scene_owner:
		node.owner = scene_owner

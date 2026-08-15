class_name CoinPickupBurst
extends Node3D

@export var duration := 0.28
@export var start_radius := 0.22
@export var end_radius := 1.05

var elapsed := 0.0
var rays: Array[MeshInstance3D] = []
var directions: Array[Vector2] = []
var materials: Array[BaseMaterial3D] = []


func _ready() -> void:
	_cache_rays()
	_face_camera()


func _process(delta: float) -> void:
	elapsed += delta
	var t := clampf(elapsed / duration, 0.0, 1.0)
	var eased_out := 1.0 - pow(1.0 - t, 3.0)
	var fade := 1.0 - smoothstep(0.44, 1.0, t)
	for i in rays.size():
		var direction := directions[i]
		var ray := rays[i]
		ray.position = Vector3(
			direction.x * lerpf(start_radius, end_radius, eased_out),
			direction.y * lerpf(start_radius, end_radius, eased_out),
			0.0
		)
		ray.scale = Vector3(1.0 - t * 0.45, 1.0 + t * 0.18, 1.0)
		var color := materials[i].albedo_color
		color.a = fade
		materials[i].albedo_color = color
	_face_camera()
	if elapsed >= duration:
		queue_free()


func _cache_rays() -> void:
	for child in get_children():
		var mesh_instance := child as MeshInstance3D
		if mesh_instance == null:
			continue
		rays.append(mesh_instance)
		var material := mesh_instance.get_active_material(0) as BaseMaterial3D
		if material == null:
			rays.pop_back()
			continue
		materials.append(material)

	var count: int = rays.size()
	if count == 0:
		queue_free()
		return
	for i in count:
		var angle := TAU * (float(i) / float(count))
		directions.append(Vector2(cos(angle), sin(angle)))
		rays[i].rotation.z = angle - PI * 0.5


func _face_camera() -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var target := camera.global_position
	var direction := target - global_position
	if direction.length_squared() < 0.001:
		return
	var up := camera.global_transform.basis.y.normalized()
	if up.is_zero_approx() or absf(direction.normalized().dot(up)) > 0.999:
		return
	look_at(target, up)

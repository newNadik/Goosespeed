extends Node

const PLAYER_SCENE := preload("res://scenes/player/goose_player_root.tscn")
const BACKENDS := [
	"basic",
	"q3",
	"platformer",
]


func _ready() -> void:
	for backend in BACKENDS:
		RuntimeConfig.movement_backend = backend
		var player := PLAYER_SCENE.instantiate()
		add_child(player)
		await get_tree().process_frame
		var controller: Node = player.get_active_controller()
		if controller == null:
			push_error("Backend %s did not create an active controller" % backend)
			get_tree().quit(1)
			return
		if controller.name != "ActiveMovementController":
			push_error("Backend %s active controller has unexpected name %s" % [backend, controller.name])
			get_tree().quit(1)
			return
		await get_tree().process_frame
		if backend == "platformer" and not _platformer_debug_visuals_are_hidden(controller):
			push_error("Platformer backend debug visuals are visible")
			get_tree().quit(1)
			return
		if backend == "platformer" and not await _platformer_facing_is_normalized(player):
			push_error("Platformer backend facing direction is not normalized to face_yaw")
			get_tree().quit(1)
			return
		player.queue_free()
		await get_tree().process_frame

	print("Movement backends OK: %d backends" % BACKENDS.size())
	get_tree().quit(0)


func _platformer_debug_visuals_are_hidden(controller: Node) -> bool:
	var body_mesh := controller.get_node_or_null("BodyMesh") as Node3D
	var face_marker := controller.get_node_or_null("FaceMarker") as Node3D
	return body_mesh != null and face_marker != null and not body_mesh.visible and not face_marker.visible


func _platformer_facing_is_normalized(player: Node) -> bool:
	var controller: Node = player.get_active_controller()
	controller.set("face_yaw", PI * 0.5)
	await get_tree().process_frame
	var state: RefCounted = player.movement_state_bridge.get_state()
	return state.facing_direction.is_equal_approx(Vector3.RIGHT)

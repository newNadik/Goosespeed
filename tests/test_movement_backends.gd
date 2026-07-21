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
		player.queue_free()
		await get_tree().process_frame

	print("Movement backends OK: %d backends" % BACKENDS.size())
	get_tree().quit(0)

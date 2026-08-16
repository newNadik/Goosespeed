extends Node

const HAT_PICKUP_SCENE := preload("res://scenes/hats/hat_pickup.tscn")

var original_straw_hat_unlocked := false
var original_straw_hat_equipped := false


func _ready() -> void:
	original_straw_hat_unlocked = GooseGameSettings.straw_hat_unlocked
	original_straw_hat_equipped = GooseGameSettings.straw_hat_equipped

	GooseGameSettings.straw_hat_unlocked = false
	GooseGameSettings.straw_hat_equipped = false
	GooseGameSettings.save_settings()

	var pickup := HAT_PICKUP_SCENE.instantiate()
	add_child(pickup)
	await get_tree().process_frame

	var pickup_sound := pickup.get_node_or_null("PickupSound") as AudioStreamPlayer3D
	if pickup_sound != null:
		pickup_sound.stream = null

	var sparkle_ring := pickup.get_node_or_null("hat/PrintedSparkleRing") as Sprite3D
	if sparkle_ring == null:
		_fail("Hat pickup is missing printed sparkle ring")
		return
	if sparkle_ring.texture == null or sparkle_ring.billboard == BaseMaterial3D.BILLBOARD_DISABLED:
		_fail("Hat pickup sparkle ring is not a textured billboard")
		return
	if pickup.get_node_or_null("PickupArea/CollisionShape3D") == null:
		_fail("Hat pickup is missing pickup collision")
		return

	var outsider := Node3D.new()
	add_child(outsider)
	if pickup.collect_from(outsider):
		_fail("Hat pickup accepted a non-player body")
		return
	if GooseGameSettings.straw_hat_unlocked or GooseGameSettings.straw_hat_equipped:
		_fail("Rejected hat pickup changed accessory state")
		return

	var player := Node3D.new()
	player.add_to_group(&"player")
	add_child(player)
	if not pickup.collect_from(player):
		_fail("Hat pickup did not accept player body")
		return
	if not GooseGameSettings.straw_hat_unlocked:
		_fail("Hat pickup did not unlock the straw hat")
		return
	if not GooseGameSettings.straw_hat_equipped:
		_fail("Hat pickup did not equip the straw hat")
		return
	if not bool(pickup.get("is_collected")) or pickup.visible:
		_fail("Hat pickup did not hide after collection")
		return

	_restore_accessory_state()
	print("Hat pickup OK")
	get_tree().quit(0)


func _fail(message: String) -> void:
	_restore_accessory_state()
	push_error(message)
	get_tree().quit(1)


func _restore_accessory_state() -> void:
	GooseGameSettings.straw_hat_unlocked = original_straw_hat_unlocked
	GooseGameSettings.straw_hat_equipped = original_straw_hat_equipped
	GooseGameSettings.save_settings()

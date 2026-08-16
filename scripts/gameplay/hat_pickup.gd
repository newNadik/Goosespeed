class_name HatPickup
extends Node3D

signal collected(hat_pickup: HatPickup)

const PICKUP_BURST_SCENE := preload("res://scenes/effects/coin_pickup_burst.tscn")
const ACCESSORY_ID := "straw_hat"

@onready var pickup_area: Area3D = $PickupArea
@onready var collision_shape: CollisionShape3D = $PickupArea/CollisionShape3D
@onready var pickup_sound_player: AudioStreamPlayer3D = $PickupSound

var collector_body: Node3D
var is_collected := false


func _ready() -> void:
	add_to_group(&"hat_pickups")
	if pickup_area != null and not pickup_area.body_entered.is_connected(_on_pickup_body_entered):
		pickup_area.body_entered.connect(_on_pickup_body_entered)
	if GooseGameSettings.is_accessory_unlocked(ACCESSORY_ID):
		_disable_pickup()


func set_collector_body(body: Node3D) -> void:
	collector_body = body


func reset_pickup() -> void:
	is_collected = false
	var unlocked := GooseGameSettings.is_accessory_unlocked(ACCESSORY_ID)
	visible = not unlocked
	set_process(not unlocked)
	if pickup_area != null:
		pickup_area.set_deferred(&"monitoring", not unlocked)
	if collision_shape != null:
		collision_shape.set_deferred(&"disabled", unlocked)


func collect_from(body: Node3D) -> bool:
	if is_collected:
		return false
	if collector_body != null and body != collector_body:
		return false
	if collector_body == null and not body.is_in_group(&"player"):
		return false
	is_collected = true
	var was_unlocked := GooseGameSettings.is_accessory_unlocked(ACCESSORY_ID)
	GooseGameSettings.unlock_accessory(ACCESSORY_ID, true)
	if not was_unlocked:
		_track_accessory_unlocked()
	_spawn_pickup_burst()
	_disable_pickup()
	if pickup_sound_player != null:
		pickup_sound_player.play()
	collected.emit(self)
	return true


func _on_pickup_body_entered(body: Node3D) -> void:
	collect_from(body)


func _disable_pickup() -> void:
	visible = false
	set_process(false)
	if pickup_area != null:
		pickup_area.set_deferred(&"monitoring", false)
	if collision_shape != null:
		collision_shape.set_deferred(&"disabled", true)


func _spawn_pickup_burst() -> void:
	var burst := PICKUP_BURST_SCENE.instantiate() as Node3D
	if burst == null:
		return
	var target_parent := get_tree().current_scene
	if target_parent == null:
		target_parent = get_parent()
	target_parent.add_child(burst)
	burst.global_position = global_position + Vector3.UP * 1.0


func _track_accessory_unlocked() -> void:
	var analytics := get_tree().root.get_node_or_null("GameAnalytics")
	if analytics != null and analytics.has_method("track_accessory_unlocked"):
		analytics.track_accessory_unlocked(
			ACCESSORY_ID,
			GooseGameSettings.is_accessory_equipped(ACCESSORY_ID)
		)

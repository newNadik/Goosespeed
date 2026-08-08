class_name CoinPickup
extends "res://scripts/props/spinning_prop.gd"

signal collected(coin: CoinPickup)

const PICKUP_BURST_SCENE := preload("res://scenes/effects/coin_pickup_burst.tscn")

@export var value := 1

@onready var pickup_area: Area3D = $PickupArea
@onready var collision_shape: CollisionShape3D = $PickupArea/CollisionShape3D
@onready var pickup_sound_player: AudioStreamPlayer3D = $PickupSound

var collector_body: Node3D
var is_collected := false


func _ready() -> void:
	add_to_group(&"coins")
	if pickup_area != null and not pickup_area.body_entered.is_connected(_on_pickup_body_entered):
		pickup_area.body_entered.connect(_on_pickup_body_entered)


func set_collector_body(value: Node3D) -> void:
	collector_body = value


func reset_pickup() -> void:
	is_collected = false
	visible = true
	set_process(true)
	if pickup_area != null:
		pickup_area.set_deferred(&"monitoring", true)
	if collision_shape != null:
		collision_shape.set_deferred(&"disabled", false)


func collect_from(body: Node3D) -> bool:
	if is_collected:
		return false
	if collector_body != null and body != collector_body:
		return false
	is_collected = true
	_spawn_pickup_burst()
	visible = false
	set_process(false)
	if pickup_area != null:
		pickup_area.set_deferred(&"monitoring", false)
	if collision_shape != null:
		collision_shape.set_deferred(&"disabled", true)
	if pickup_sound_player != null:
		pickup_sound_player.play()
	collected.emit(self)
	return true


func _on_pickup_body_entered(body: Node3D) -> void:
	collect_from(body)


func _spawn_pickup_burst() -> void:
	var burst := PICKUP_BURST_SCENE.instantiate() as Node3D
	if burst == null:
		return
	var target_parent := get_tree().current_scene
	if target_parent == null:
		target_parent = get_parent()
	target_parent.add_child(burst)
	burst.global_position = global_position + Vector3.UP * 1.0

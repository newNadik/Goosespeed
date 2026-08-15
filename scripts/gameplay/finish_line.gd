class_name FinishLine
extends StaticBody3D

const UNLOCK_BURST_SCENE := preload("res://scenes/effects/coin_pickup_burst.tscn")

@onready var coins_label: Label3D = $Node3D3/coins_label
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

var coin_count := 0
var coin_target := 0
var unlocked := false
var completed := false


func _ready() -> void:
	_update_label()


func set_coin_progress(current: int, target: int) -> void:
	coin_count = max(current, 0)
	coin_target = max(target, 0)
	var should_unlock := coin_target > 0 and coin_count >= coin_target
	if should_unlock and not unlocked:
		unlock_finish_line()
	else:
		_update_label()


func reset_finish_line(current: int = 0, target: int = 0) -> void:
	coin_count = max(current, 0)
	coin_target = max(target, 0)
	unlocked = false
	completed = false
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT
	if collision_shape != null:
		collision_shape.set_deferred(&"disabled", false)
	_update_label()


func unlock_finish_line() -> void:
	unlocked = true
	if collision_shape != null:
		collision_shape.set_deferred(&"disabled", true)
	_update_label()


func complete_finish_line() -> void:
	if completed:
		return
	completed = true
	unlocked = true
	_spawn_unlock_burst()
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED
	if collision_shape != null:
		collision_shape.set_deferred(&"disabled", true)


func is_unlocked() -> bool:
	return unlocked


func _update_label() -> void:
	if coins_label == null:
		return
	if coin_target > 0:
		coins_label.text = "%d / %d" % [coin_count, coin_target]
	else:
		coins_label.text = str(coin_count)


func _spawn_unlock_burst() -> void:
	var target_parent := get_tree().current_scene
	if target_parent == null:
		target_parent = get_parent()
	var offsets := [
		Vector3(-1.6, 2.2, 0.0),
		Vector3(0.0, 2.6, 0.0),
		Vector3(1.6, 2.2, 0.0),
	]
	for offset in offsets:
		var burst := UNLOCK_BURST_SCENE.instantiate() as Node3D
		if burst == null:
			continue
		target_parent.add_child(burst)
		burst.global_position = global_position + global_basis * offset

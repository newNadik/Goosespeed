extends Node3D

const PAUSE_MENU_SCENE := preload("res://scenes/ui/pause_menu.tscn")

@onready var level: Node3D = $PrimitiveTestLevel
@onready var player: Node = $GoosePlayerRoot
@onready var game_hud = $GooseGameHud
@onready var finish_area: Area3D = $FinishTrigger

var elapsed_time := 0.0
var finished := false


func _ready() -> void:
	_disable_embedded_level_runtime()
	_connect_volumes()
	finish_area.body_entered.connect(_on_finish_body_entered)
	player.set_spawn_transform(player.get_active_controller().global_transform)
	game_hud.set_player(player)
	add_child(PAUSE_MENU_SCENE.instantiate())
	_update_hud()


func _process(delta: float) -> void:
	if Input.is_action_just_pressed(&"player_restart"):
		_restart_run()
	if not finished:
		elapsed_time += delta
	_update_hud()


func _restart_run() -> void:
	elapsed_time = 0.0
	finished = false
	player.reset_to_spawn()


func _connect_volumes() -> void:
	var volumes := level.get_node_or_null("Volumes")
	if volumes == null:
		return
	for area in volumes.get_children():
		if not area is Area3D:
			continue
		(area as Area3D).body_entered.connect(_on_volume_body_entered.bind(area))
		(area as Area3D).body_exited.connect(_on_volume_body_exited.bind(area))


func _on_volume_body_entered(body: Node3D, area: Area3D) -> void:
	if body != player.get_active_controller():
		return
	var medium := StringName(area.get_meta("platformer_medium", area.get_meta("q3_volume_type", "air")))
	if medium == &"water":
		player.set_medium(&"water")


func _on_volume_body_exited(body: Node3D, area: Area3D) -> void:
	if body != player.get_active_controller():
		return
	var medium := StringName(area.get_meta("platformer_medium", area.get_meta("q3_volume_type", "air")))
	if medium == &"water":
		player.set_medium(&"air")


func _on_finish_body_entered(body: Node3D) -> void:
	if body == player.get_active_controller():
		finished = true


func _update_hud() -> void:
	game_hud.set_run_state(elapsed_time, finished)


func _disable_embedded_level_runtime() -> void:
	var prototype_settings := get_node_or_null("/root/Settings")
	if (
		prototype_settings != null
		and prototype_settings.has_signal("settings_changed")
		and level.has_method("on_settings_changed")
		and prototype_settings.is_connected("settings_changed", level.on_settings_changed)
	):
		prototype_settings.disconnect("settings_changed", level.on_settings_changed)

	var standalone_character = level.get("active_character")
	if standalone_character is Node:
		(standalone_character as Node).queue_free()
		level.set("active_character", null)
		level.set("active_character_id", "")

	var standalone_pause_menu := level.get_node_or_null("PauseMenu")
	if standalone_pause_menu != null:
		standalone_pause_menu.queue_free()

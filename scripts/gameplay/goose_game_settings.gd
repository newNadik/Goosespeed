extends Node

signal settings_changed

const GooseMovesRuntimeScript := preload("res://scripts/player/goose_moves_runtime.gd")
const SAVE_PATH := "user://goosespeed_settings.cfg"
const SECTION := "goosespeed"

var debug_hud_visible := true


func _ready() -> void:
	load_settings()
	call_deferred("_lock_goose_moves_backend")


func load_settings() -> void:
	var config := ConfigFile.new()
	var error := config.load(SAVE_PATH)
	if error != OK:
		_lock_goose_moves_backend()
		return

	debug_hud_visible = bool(config.get_value(SECTION, "debug_hud_visible", debug_hud_visible))
	_lock_goose_moves_backend()


func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value(SECTION, "debug_hud_visible", debug_hud_visible)
	var error := config.save(SAVE_PATH)
	if error != OK:
		push_warning("Failed to save GooseSpeed settings: %s" % error)


func _lock_goose_moves_backend() -> void:
	GooseMovesRuntimeScript.lock_settings_backend(get_node_or_null("/root/Settings"))

extends SceneTree

const GameAnalyticsScript := preload("res://scripts/core/game_analytics.gd")
const ANALYTICS_STATS_SYNC_PATH := "user://analytics_stats.cfg"


func _initialize() -> void:
	_clear_analytics_stats_sync()
	var original_stats_enabled := bool(ProjectSettings.get_setting("goosespeed/analytics/talo_stats_enabled", false))
	ProjectSettings.set_setting("goosespeed/analytics/talo_stats_enabled", true)
	_replace_autoload("GameAnalytics")
	_replace_autoload("Talo")

	var fake_talo := FakeTalo.new()
	fake_talo.name = "Talo"
	root.add_child(fake_talo)

	var analytics := GameAnalyticsScript.new()
	analytics.name = "GameAnalytics"
	root.add_child(analytics)

	await process_frame
	await process_frame

	if not analytics.identified:
		_fail("GameAnalytics did not identify the fake Talo player")
		return

	analytics.track("queued_before_ready", {"coins": 3})
	analytics.identified = false
	analytics.track("queued_event", {"value": 12, "enabled": true})
	analytics.identified = true
	analytics._flush_pending_events()
	await process_frame

	if fake_talo.events.tracked_events.is_empty():
		_fail("GameAnalytics did not flush queued events")
		return
	var queued_event := fake_talo.events.tracked_events.back() as Dictionary
	if queued_event["name"] != "queued_event":
		_fail("Unexpected queued event name: %s" % queued_event["name"])
		return
	if str(queued_event["props"].get("value", "")) != "12":
		_fail("GameAnalytics did not stringify event props")
		return
	if not queued_event["props"].has("store") or not queued_event["props"].has("build_channel"):
		_fail("GameAnalytics did not include base event props")
		return

	analytics.track_run_started("res://scenes/courses/farm/level_farm.tscn", "farm")
	await process_frame
	if not _has_event(fake_talo, "run_started"):
		_fail("Run start event was not tracked")
		return
	if not _has_stat(fake_talo, "level_play_count", 1.0):
		_fail("Level play count stat was not tracked")
		return

	analytics.track_run_finished(
		"res://scenes/courses/farm/level_farm.tscn",
		"farm",
		4.2,
		20,
		20,
		40,
		5.0,
		4.2,
		true
	)
	await process_frame
	await process_frame
	if not _has_event(fake_talo, "run_finished"):
		_fail("Run finish event was not tracked")
		return
	if not _has_stat(fake_talo, "level_best_time_seconds", 4.2):
		_fail("Initial best time stat value was not tracked")
		return
	if fake_talo.current_player.props.get("best_time_level_farm", "") != "4.2000":
		_fail("Course best time prop was not set")
		return
	analytics.track_level_best_time(
		"res://scenes/courses/farm/level_farm.tscn",
		"farm",
		3.7,
		4.2
	)
	await process_frame
	if not _has_stat(fake_talo, "level_best_time_seconds", -0.5):
		_fail("Best time stat sync delta was not tracked")
		return

	analytics.track_setting_changed("audio", "music_volume", 0.5)
	analytics.track_accessory_unlocked("straw_hat", true)
	analytics.track_accessory_equipped_changed("straw_hat", false)
	await process_frame
	if not _has_event(fake_talo, "setting_changed"):
		_fail("Setting change event was not tracked")
		return
	if not _has_event(fake_talo, "accessory_unlocked"):
		_fail("Accessory unlock event was not tracked")
		return
	if not _has_event(fake_talo, "accessory_equipped_changed"):
		_fail("Accessory equip event was not tracked")
		return
	if fake_talo.current_player.props.get("accessory_straw_hat_equipped", "") != "false":
		_fail("Accessory equipped player prop was not set")
		return
	if fake_talo.player_presence.updates.is_empty():
		_fail("Presence was not updated after identification")
		return

	ProjectSettings.set_setting("goosespeed/analytics/talo_stats_enabled", false)
	analytics.track_stat("missing_dashboard_stat", 1.0)
	await process_frame
	if _has_stat(fake_talo, "missing_dashboard_stat", 1.0):
		_fail("Disabled Talo stats should not call the stats API")
		return
	ProjectSettings.set_setting("goosespeed/analytics/talo_stats_enabled", original_stats_enabled)
	print("Game analytics OK")
	quit(0)


func _replace_autoload(node_name: String) -> void:
	var existing := root.get_node_or_null(node_name)
	if existing != null:
		root.remove_child(existing)
		existing.queue_free()


func _clear_analytics_stats_sync() -> void:
	if not FileAccess.file_exists(ANALYTICS_STATS_SYNC_PATH):
		return
	var user_dir := DirAccess.open("user://")
	if user_dir != null:
		user_dir.remove(ANALYTICS_STATS_SYNC_PATH.get_file())


func _has_event(fake_talo: FakeTalo, event_name: String) -> bool:
	for event in fake_talo.events.tracked_events:
		if str((event as Dictionary).get("name", "")) == event_name:
			return true
	return false


func _has_stat(fake_talo: FakeTalo, stat_name: String, change: float) -> bool:
	for stat in fake_talo.stats.tracked_stats:
		var data := stat as Dictionary
		if str(data.get("name", "")) == stat_name and is_equal_approx(float(data.get("change", 0.0)), change):
			return true
	return false


func _fail(message: String) -> void:
	push_error(message)
	quit(1)


class FakeTalo:
	extends Node

	var settings := FakeSettings.new()
	var players := FakePlayers.new()
	var events := FakeEvents.new()
	var stats := FakeStats.new()
	var player_presence := FakePresence.new()
	var current_player := FakePlayer.new()

	func _ready() -> void:
		players.fake_talo = self

	func has_identity() -> bool:
		return false


class FakeSettings:
	var access_key := "fake-key"


class FakePlayers:
	var fake_talo: FakeTalo
	var identify_calls: Array[Dictionary] = []
	var debounce_updates := 0

	func identify(service: String, identifier: String) -> FakePlayer:
		identify_calls.append({
			"service": service,
			"identifier": identifier,
		})
		return fake_talo.current_player

	func debounce_update() -> void:
		debounce_updates += 1


class FakeEvents:
	var tracked_events: Array[Dictionary] = []
	var flush_count := 0

	func track(event_name: String, props: Dictionary[String, String] = {}) -> void:
		tracked_events.append({
			"name": event_name,
			"props": props.duplicate(true),
		})

	func flush() -> void:
		flush_count += 1


class FakeStats:
	var tracked_stats: Array[Dictionary] = []

	func track(internal_name: String, change: float = 1.0):
		tracked_stats.append({
			"name": internal_name,
			"change": change,
		})
		return RefCounted.new()


class FakePresence:
	var updates: Array[Dictionary] = []

	func update_presence(online: bool, custom_status: String = ""):
		updates.append({
			"online": online,
			"custom_status": custom_status,
		})
		return RefCounted.new()


class FakePlayer:
	var props := {}

	func set_prop(key: String, value: String, _update := true) -> void:
		props[key] = value

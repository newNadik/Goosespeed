extends Node

const IDENTITY_PATH := "user://analytics_identity.cfg"
const STATS_SYNC_PATH := "user://analytics_stats.cfg"
const IDENTITY_SECTION := "identity"
const IDENTITY_KEY := "identifier"
const STATS_SYNC_SECTION := "stats_sync"
const IDENTITY_SERVICE := "goosespeed_anonymous"
const MAX_PENDING_EVENTS := 96
const MAX_PENDING_STATS := 64
const ACTIVE_TIME_STAT := "active_seconds"
const LEVEL_PLAY_COUNT_STAT := "level_play_count"
const LEVEL_BEST_TIME_STAT := "level_best_time_seconds"
const ACTIVE_TIME_FLUSH_INTERVAL := 60.0

var identified := false
var identifying := false
var gameplay_active := false
var _pending_events: Array[Dictionary] = []
var _pending_stats: Array[Dictionary] = []
var _flushing_events := false
var _flushing_stats := false
var _active_seconds_buffer := 0.0
var _active_flush_timer := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(true)
	call_deferred("_initialize")


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_IN:
			_update_presence(true, "active")
		NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED:
			_flush_active_time()
			_update_presence(false, "")
		NOTIFICATION_WM_CLOSE_REQUEST:
			_flush_active_time()
			_update_presence(false, "")
			flush()


func _process(delta: float) -> void:
	if not gameplay_active or get_tree().paused or not DisplayServer.window_is_focused():
		return
	_active_seconds_buffer += delta
	_active_flush_timer += delta
	if _active_flush_timer >= ACTIVE_TIME_FLUSH_INTERVAL:
		_flush_active_time()


func start_gameplay() -> void:
	gameplay_active = true
	_active_flush_timer = 0.0


func stop_gameplay() -> void:
	gameplay_active = false
	_flush_active_time()


func track(event_name: String, props := {}) -> void:
	var event := {
		"name": event_name,
		"props": _stringify_props(_with_base_props(props)) as Dictionary[String, String],
	}
	if not identified:
		_queue_event(event)
		return
	_send_event(event)


func track_run_started(course_path: String, course_name: String) -> void:
	track("run_started", {
		"course_path": course_path,
		"course_name": course_name,
	})
	_increment_player_number_prop(_course_prop_key("play_count", course_path), 1.0)
	track_stat(LEVEL_PLAY_COUNT_STAT, 1.0)
	start_gameplay()


func track_run_finished(
	course_path: String,
	course_name: String,
	elapsed_time: float,
	coins_collected: int,
	target_coins: int,
	total_coins: int,
	previous_best_time: float,
	best_time: float,
	new_best: bool
) -> void:
	stop_gameplay()
	track("run_finished", {
		"course_path": course_path,
		"course_name": course_name,
		"elapsed_time": elapsed_time,
		"coins_collected": coins_collected,
		"target_coins": target_coins,
		"total_coins": total_coins,
		"previous_best_time": previous_best_time,
		"best_time": best_time,
		"new_best": new_best,
	})
	if new_best and best_time > 0.0:
		track_level_best_time(course_path, course_name, best_time, previous_best_time)


func track_level_best_time(
	course_path: String,
	course_name: String,
	best_time: float,
	previous_best_time: float
) -> void:
	var sync_key := _course_prop_key(LEVEL_BEST_TIME_STAT, course_path)
	var previous_synced_best := _get_synced_stat_value(sync_key, 0.0)
	var change := best_time - previous_synced_best
	if not is_equal_approx(change, 0.0):
		track_stat(LEVEL_BEST_TIME_STAT, change)
		_set_synced_stat_value(sync_key, best_time)
	_set_player_prop(_course_prop_key("best_time", course_path), _value_to_string(best_time))
	track("level_best_time_recorded", {
		"course_path": course_path,
		"course_name": course_name,
		"best_time": best_time,
		"previous_best_time": previous_best_time,
		"previous_synced_best_time": previous_synced_best,
	})


func track_setting_changed(category: String, key: String, value: Variant) -> void:
	track("setting_changed", {
		"category": category,
		"key": key,
		"value": value,
	})


func track_accessory_unlocked(accessory: String, equipped: bool) -> void:
	track("accessory_unlocked", {
		"accessory": accessory,
		"equipped": equipped,
	})
	_set_player_prop("accessory_%s_unlocked" % accessory, "true")
	_set_player_prop("accessory_%s_equipped" % accessory, _value_to_string(equipped))


func track_accessory_equipped_changed(accessory: String, equipped: bool) -> void:
	track("accessory_equipped_changed", {
		"accessory": accessory,
		"equipped": equipped,
	})
	_set_player_prop("accessory_%s_equipped" % accessory, _value_to_string(equipped))


func track_stat(internal_name: String, change: float) -> void:
	if not _talo_stats_enabled():
		return
	if is_equal_approx(change, 0.0):
		return
	_pending_stats.append({
		"name": internal_name,
		"change": change,
	})
	if _pending_stats.size() > MAX_PENDING_STATS:
		_pending_stats.pop_front()
	_flush_pending_stats()


func flush() -> void:
	_flush_active_time()
	_flush_pending_events()
	_flush_pending_stats()


func _initialize() -> void:
	if identifying or identified:
		return
	var talo: Variant = _get_talo()
	if talo == null:
		return
	var settings: Variant = talo.get("settings")
	if settings == null:
		return
	var access_key := str(settings.get("access_key"))
	if access_key.is_empty():
		return
	identifying = true
	if talo.has_method("has_identity") and talo.has_identity():
		identified = true
	else:
		var identifier := _load_or_create_identifier()
		var player: Variant = await talo.players.identify(IDENTITY_SERVICE, identifier)
		identified = player != null
	identifying = false
	if not identified:
		return
	_sync_player_metadata()
	_update_presence(true, "active")
	_flush_pending_events()
	_flush_pending_stats()


func _load_or_create_identifier() -> String:
	var config := ConfigFile.new()
	if config.load(IDENTITY_PATH) == OK:
		var existing := str(config.get_value(IDENTITY_SECTION, IDENTITY_KEY, ""))
		if not existing.is_empty():
			return existing
	var identifier := "%s-%s-%s" % [
		Time.get_unix_time_from_system(),
		Time.get_ticks_usec(),
		randi(),
	]
	config.set_value(IDENTITY_SECTION, IDENTITY_KEY, identifier)
	var error := config.save(IDENTITY_PATH)
	if error != OK:
		push_warning("Failed to save analytics identity: %s" % error)
	return identifier


func _queue_event(event: Dictionary) -> void:
	_pending_events.append(event)
	if _pending_events.size() > MAX_PENDING_EVENTS:
		_pending_events.pop_front()


func _send_event(event: Dictionary) -> void:
	var talo: Variant = _get_talo()
	if talo == null or not identified:
		_queue_event(event)
		return
	var props := event["props"] as Dictionary[String, String]
	talo.events.track(str(event["name"]), props)
	if talo.events.has_method("flush"):
		await talo.events.flush()


func _flush_pending_events() -> void:
	if _flushing_events or not identified:
		return
	var talo: Variant = _get_talo()
	if talo == null:
		return
	_flushing_events = true
	while not _pending_events.is_empty() and identified:
		var event := _pending_events.pop_front() as Dictionary
		var props := event["props"] as Dictionary[String, String]
		talo.events.track(str(event["name"]), props)
		if talo.events.has_method("flush"):
			await talo.events.flush()
	_flushing_events = false


func _flush_pending_stats() -> void:
	if _flushing_stats or not identified:
		return
	var talo: Variant = _get_talo()
	if talo == null:
		return
	_flushing_stats = true
	while not _pending_stats.is_empty() and identified:
		var stat := _pending_stats.pop_front() as Dictionary
		var result: Variant = await talo.stats.track(str(stat["name"]), float(stat["change"]))
		if result == null:
			_pending_stats.push_front(stat)
			break
	_flushing_stats = false


func _flush_active_time() -> void:
	if _active_seconds_buffer < 1.0:
		return
	var seconds := floorf(_active_seconds_buffer)
	_active_seconds_buffer -= seconds
	_active_flush_timer = 0.0
	track_stat(ACTIVE_TIME_STAT, seconds)


func _sync_player_metadata() -> void:
	_set_player_prop("store", _get_store())
	_set_player_prop("platform", OS.get_name())
	_set_player_prop("build_channel", _get_build_channel())
	_set_player_prop("game_version", _get_game_version())


func _set_player_prop(key: String, value: String) -> void:
	if not identified:
		return
	var talo: Variant = _get_talo()
	if talo == null or talo.current_player == null:
		return
	talo.current_player.set_prop(key, value, false)
	if talo.players.has_method("debounce_update"):
		talo.players.debounce_update()


func _increment_player_number_prop(key: String, change: float) -> void:
	if not identified:
		return
	var talo: Variant = _get_talo()
	if talo == null or talo.current_player == null:
		return
	var current := 0.0
	if talo.current_player.has_method("get_prop"):
		current = float(talo.current_player.get_prop(key, "0"))
	_set_player_prop(key, _value_to_string(current + change))


func _update_presence(online: bool, status: String) -> void:
	if not identified:
		return
	var talo: Variant = _get_talo()
	if talo == null or talo.get("player_presence") == null:
		return
	await talo.player_presence.update_presence(online, status)


func _with_base_props(props: Dictionary) -> Dictionary:
	var result := {
		"store": _get_store(),
		"platform": OS.get_name(),
		"build_channel": _get_build_channel(),
	}
	for key in props.keys():
		result[str(key)] = props[key]
	return result


func _stringify_props(props: Dictionary) -> Dictionary[String, String]:
	var result: Dictionary[String, String] = {}
	for key in props.keys():
		result[str(key)] = _value_to_string(props[key])
	return result


func _value_to_string(value: Variant) -> String:
	match typeof(value):
		TYPE_BOOL:
			return "true" if bool(value) else "false"
		TYPE_FLOAT:
			return "%.4f" % float(value)
		TYPE_VECTOR2, TYPE_VECTOR3, TYPE_DICTIONARY, TYPE_ARRAY:
			return JSON.stringify(value)
		_:
			return str(value)


func _get_store() -> String:
	if OS.has_feature("itch"):
		return "itch"
	if OS.has_feature("web"):
		return "web"
	if OS.has_feature("steam"):
		return "steam"
	if OS.has_feature("app_store"):
		return "app_store"
	return "unknown"


func _get_build_channel() -> String:
	if OS.has_feature("talo_dev"):
		return "dev"
	if OS.has_feature("talo_live") or OS.has_feature("live") or OS.has_feature("web"):
		return "live"
	if OS.has_feature("debug"):
		return "dev"
	return "dev"


func _get_game_version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "0.0.0"))


func _talo_stats_enabled() -> bool:
	return bool(ProjectSettings.get_setting("goosespeed/analytics/talo_stats_enabled", false))


func _get_synced_stat_value(key: String, fallback: float) -> float:
	var config := ConfigFile.new()
	if config.load(STATS_SYNC_PATH) != OK:
		return fallback
	return float(config.get_value(STATS_SYNC_SECTION, key, fallback))


func _set_synced_stat_value(key: String, value: float) -> void:
	var config := ConfigFile.new()
	config.load(STATS_SYNC_PATH)
	config.set_value(STATS_SYNC_SECTION, key, value)
	var error := config.save(STATS_SYNC_PATH)
	if error != OK:
		push_warning("Failed to save analytics stat sync state: %s" % error)


func _course_prop_key(prefix: String, course_path: String) -> String:
	var course_id := course_path.get_file().get_basename()
	if course_id.is_empty():
		course_id = "unknown"
	return "%s_%s" % [prefix, course_id]


func _get_talo() -> Variant:
	return get_tree().root.get_node_or_null("Talo")

extends Node

@export var animation_player_path := NodePath("AnimationPlayer")
@export var animation_names: Array[String] = []
@export_range(0.1, 120.0, 0.1, "or_greater") var min_delay_seconds := 4.0
@export_range(0.1, 120.0, 0.1, "or_greater") var max_delay_seconds := 12.0
@export var force_non_looping := true

var _animation_player: AnimationPlayer
var _timer: Timer
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_animation_player = get_node_or_null(animation_player_path) as AnimationPlayer
	if _animation_player == null:
		push_warning("RandomAnimationPlayer could not find AnimationPlayer at %s." % animation_player_path)
		return

	_timer = Timer.new()
	_timer.one_shot = true
	add_child(_timer)
	_timer.timeout.connect(_on_timer_timeout)
	_schedule_next()


func _on_timer_timeout() -> void:
	var animation_name := _pick_animation_name()
	if animation_name == &"":
		_schedule_next()
		return

	var animation_duration := _play_animation(animation_name)
	_schedule_next(animation_duration)


func _play_animation(animation_name: StringName) -> float:
	if force_non_looping:
		_animation_player.get_animation(animation_name).loop_mode = Animation.LOOP_NONE

	_animation_player.stop()
	_animation_player.play(animation_name)

	var speed := maxf(absf(_animation_player.speed_scale), 0.001)
	return _animation_player.get_animation(animation_name).length / speed


func _schedule_next(extra_delay_seconds := 0.0) -> void:
	if _timer == null:
		return

	var min_delay := minf(min_delay_seconds, max_delay_seconds)
	var max_delay := maxf(min_delay_seconds, max_delay_seconds)
	_timer.start(extra_delay_seconds + _rng.randf_range(min_delay, max_delay))


func _pick_animation_name() -> StringName:
	var valid_animation_names: Array[StringName] = []
	for animation_name in animation_names:
		var candidate := StringName(animation_name)
		if candidate != &"" and _animation_player.has_animation(candidate):
			valid_animation_names.append(candidate)

	if valid_animation_names.is_empty():
		return &""

	return valid_animation_names[_rng.randi_range(0, valid_animation_names.size() - 1)]

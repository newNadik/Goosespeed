class_name GooseLoadingScreen
extends Control

const BACKGROUND_COLOUR := Color("#182f44")
const BACKGROUND_WASH_COLOUR := Color("#273f4f")
const VIGNETTE_COLOUR := Color("#0f2133")
const PRINT_SPECKLE_COLOUR := Color("#f1dfbd")
const PROGRESS_COLOUR := Color("#8fb8c5e6")
const VIGNETTE_CELL_SIZE := 24.0
const SPECKLE_SPACING := 36.0
const WALK_SPEED := 320.0
const STEP_INTERVAL := 0.24
const STEP_STRIDE := 78.0
const STEP_SIZE := Vector2(58.0, 57.0)
const STEP_ALPHA := 0.92
const STEP_LIFETIME := 0.48
const LOOP_RADIUS := 150.0
const FIRST_LOOP_X_RATIO := 0.34
const SECOND_LOOP_X_RATIO := 0.78
const LOOP_Y_OFFSET_RATIO := -0.16
const OFFSCREEN_DISTANCE := 180.0
const DELAY_DISTANCE := 160.0

@export var step_texture: Texture2D

var progress := 0.0
var _time := 0.0
var _distance := 0.0
var _step_timer := 0.0
var _next_foot_side := -1.0
var _planted_steps: Array[Dictionary] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(true)


func set_progress(value: float) -> void:
	progress = clampf(value, 0.0, 1.0)
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	_distance += WALK_SPEED * delta
	_step_timer += delta
	while _step_timer >= STEP_INTERVAL:
		_step_timer -= STEP_INTERVAL
		_plant_step()
	_update_planted_steps(delta)
	queue_redraw()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, BACKGROUND_COLOUR, true)
	_draw_printed_background(rect)
	_draw_planted_steps()
	_draw_progress_glow(rect)


func _plant_step() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return

	var route := _path_sample(_distance)
	var base_position := route["position"] as Vector2
	var direction := route["direction"] as Vector2

	var side_offset := Vector2(-direction.y, direction.x) * _next_foot_side * 24.0
	var stride_offset := direction * STEP_STRIDE * 0.5
	_planted_steps.append({
		"position": base_position + stride_offset + side_offset,
		"rotation": direction.angle() + PI * 0.5,
		"age": 0.0,
		"side": _next_foot_side,
	})
	if _planted_steps.size() > 2:
		_planted_steps.pop_front()
	_next_foot_side *= -1.0


func _update_planted_steps(delta: float) -> void:
	var kept_steps: Array[Dictionary] = []
	for step in _planted_steps:
		step["age"] = float(step["age"]) + delta
		if float(step["age"]) < STEP_LIFETIME:
			kept_steps.append(step)
	_planted_steps = kept_steps


func _path_sample(distance: float) -> Dictionary:
	var route_start_x := -STEP_STRIDE
	var route_end_x := size.x + OFFSCREEN_DISTANCE
	var center_y := size.y * 0.52
	var first_loop_entry := Vector2(size.x * FIRST_LOOP_X_RATIO, center_y)
	var second_loop_entry := Vector2(size.x * SECOND_LOOP_X_RATIO, center_y)
	var first_loop_center := first_loop_entry + Vector2(0.0, size.y * LOOP_Y_OFFSET_RATIO)
	var second_loop_center := second_loop_entry + Vector2(0.0, size.y * LOOP_Y_OFFSET_RATIO)
	var straight_one_length := first_loop_entry.x - route_start_x
	var loop_length := TAU * LOOP_RADIUS
	var straight_two_length := route_end_x - first_loop_entry.x
	var second_approach_start_x := size.x + DELAY_DISTANCE
	var second_approach_length := second_loop_entry.x + route_end_x - second_approach_start_x
	var straight_three_length := route_end_x - second_loop_entry.x
	var route_length := (
		straight_one_length
		+ loop_length
		+ straight_two_length
		+ DELAY_DISTANCE
		+ second_approach_length
		+ loop_length
		+ straight_three_length
	)
	var route_distance := fmod(distance, route_length)

	if route_distance < straight_one_length:
		return {
			"position": Vector2(route_start_x + route_distance, center_y),
			"direction": Vector2.RIGHT,
		}

	route_distance -= straight_one_length
	if route_distance < loop_length:
		var angle := (PI * 0.5) - route_distance / LOOP_RADIUS
		var direction := Vector2(sin(angle), -cos(angle)).normalized()
		return {
			"position": first_loop_center + Vector2(cos(angle), sin(angle)) * LOOP_RADIUS,
			"direction": direction,
		}

	route_distance -= loop_length
	if route_distance < straight_two_length:
		return {
			"position": Vector2(first_loop_entry.x + route_distance, center_y),
			"direction": Vector2.RIGHT,
		}

	route_distance -= straight_two_length
	if route_distance < DELAY_DISTANCE:
		return {
			"position": Vector2(route_end_x + route_distance, center_y),
			"direction": Vector2.RIGHT,
		}

	route_distance -= DELAY_DISTANCE
	if route_distance < second_approach_length:
		var x := second_approach_start_x + route_distance
		if x > route_end_x:
			x -= route_end_x - route_start_x
		return {
			"position": Vector2(x, center_y),
			"direction": Vector2.RIGHT,
		}

	route_distance -= second_approach_length
	if route_distance < loop_length:
		var angle := (PI * 0.5) - route_distance / LOOP_RADIUS
		var direction := Vector2(sin(angle), -cos(angle)).normalized()
		return {
			"position": second_loop_center + Vector2(cos(angle), sin(angle)) * LOOP_RADIUS,
			"direction": direction,
		}

	route_distance -= loop_length
	return {
		"position": Vector2(second_loop_entry.x + route_distance, center_y),
		"direction": Vector2.RIGHT,
	}



func _draw_planted_steps() -> void:
	if step_texture == null:
		return

	for step in _planted_steps:
		var age := float(step["age"])
		var fade_out := clampf((STEP_LIFETIME - age) / (STEP_LIFETIME * 0.45), 0.0, 1.0)
		var fade_in := clampf(age / (STEP_LIFETIME * 0.18), 0.0, 1.0)
		_draw_step_texture(
			step["position"],
			float(step["rotation"]),
			minf(fade_in, fade_out) * STEP_ALPHA,
			float(step["side"])
		)


func _draw_step_texture(center: Vector2, rotation: float, alpha: float, side: float) -> void:
	var texture_size := step_texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return

	var scale := minf(STEP_SIZE.x / texture_size.x, STEP_SIZE.y / texture_size.y)
	draw_set_transform(center, rotation, Vector2(scale * side, scale))
	var top_left := -texture_size * 0.5
	draw_texture(step_texture, top_left, Color(1.0, 1.0, 1.0, alpha))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_printed_background(rect: Rect2) -> void:
	draw_rect(rect, Color(BACKGROUND_WASH_COLOUR, 0.18), true)
	_draw_soft_vignette(rect)
	_draw_print_speckles(rect)


func _draw_soft_vignette(rect: Rect2) -> void:
	var center := rect.size * 0.5
	var max_distance := center.length()
	var columns := int(ceil(rect.size.x / VIGNETTE_CELL_SIZE))
	var rows := int(ceil(rect.size.y / VIGNETTE_CELL_SIZE))

	for row in rows:
		for column in columns:
			var cell_position := Vector2(column, row) * VIGNETTE_CELL_SIZE
			var cell_center := cell_position + Vector2.ONE * VIGNETTE_CELL_SIZE * 0.5
			var distance_ratio := cell_center.distance_to(center) / max_distance
			var edge_ratio := maxf(
				absf(cell_center.x - center.x) / center.x,
				absf(cell_center.y - center.y) / center.y
			)
			var alpha := smoothstep(0.48, 1.0, maxf(distance_ratio, edge_ratio)) * 0.52
			if alpha <= 0.01:
				continue
			var cell_rect := Rect2(cell_position, Vector2.ONE * VIGNETTE_CELL_SIZE)
			draw_rect(cell_rect, Color(VIGNETTE_COLOUR, alpha), true)


func _draw_print_speckles(rect: Rect2) -> void:
	var columns := int(ceil(rect.size.x / SPECKLE_SPACING))
	var rows := int(ceil(rect.size.y / SPECKLE_SPACING))
	for row in rows:
		for column in columns:
			var seed := float((column * 37 + row * 53) % 97) / 97.0
			if seed > 0.36:
				continue
			var x := float(column) * SPECKLE_SPACING + 7.0 + fmod(seed * 211.0, 18.0)
			var y := float(row) * SPECKLE_SPACING + 5.0 + fmod(seed * 157.0, 20.0)
			var radius := 0.8 + seed * 1.4
			var alpha := 0.028 + seed * 0.035
			draw_circle(Vector2(x, y), radius, Color(PRINT_SPECKLE_COLOUR, alpha))


func _draw_progress_glow(rect: Rect2) -> void:
	var glow_width := maxf(0.0, rect.size.x * progress)
	if glow_width <= 0.0:
		return
	var glow_rect := Rect2(0.0, rect.size.y - 8.0, glow_width, 8.0)
	draw_rect(glow_rect, PROGRESS_COLOUR, true)

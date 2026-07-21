extends Node3D

const PAUSE_MENU_SCENE := preload("res://scenes/ui/pause_menu.tscn")
const DEFAULT_SPAWN := Vector3(0.0, 1.2, 20.0)
const LABELED_FIXTURE_ROOTS := [
	"Cubes",
	"Stairs",
	"Ramps",
	"Kerbs",
	"LimitSlopes",
	"SurfaceFlags",
	"PlatformerSurfaces",
	"SurfaceClassSlopes",
	"Volumes",
]

@onready var player: Node = $GoosePlayerRoot
@onready var game_hud = $GooseGameHud
@onready var finish_area: Area3D = $FinishTrigger

var elapsed_time := 0.0
var finished := false


func _ready() -> void:
	_add_fixture_labels()
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
	for area in $Volumes.get_children():
		if not area is Area3D:
			continue
		(area as Area3D).body_entered.connect(_on_volume_body_entered.bind(area))
		(area as Area3D).body_exited.connect(_on_volume_body_exited.bind(area))


func _on_volume_body_entered(body: Node3D, area: Area3D) -> void:
	if body != player.get_active_controller():
		return
	var medium := StringName(area.get_meta("platformer_medium", area.get_meta("q3_volume_type", "air")))
	if medium == &"water" and player.get_active_controller().has_method("set_medium"):
		player.get_active_controller().set_medium(&"water")


func _on_volume_body_exited(body: Node3D, area: Area3D) -> void:
	if body != player.get_active_controller():
		return
	var medium := StringName(area.get_meta("platformer_medium", area.get_meta("q3_volume_type", "air")))
	if medium == &"water" and player.get_active_controller().has_method("set_medium"):
		player.get_active_controller().set_medium(&"air")


func _on_finish_body_entered(body: Node3D) -> void:
	if body == player.get_active_controller():
		finished = true


func _update_hud() -> void:
	game_hud.set_run_state(elapsed_time, finished)


func _add_fixture_labels() -> void:
	var labels_root := $FixtureLabels as Node3D
	for root_path in LABELED_FIXTURE_ROOTS:
		var root := get_node_or_null(root_path)
		if root == null:
			continue
		for fixture in root.get_children():
			if fixture is CSGBox3D or fixture is Area3D:
				_add_fixture_label(labels_root, fixture as Node3D)


func _add_fixture_label(labels_root: Node3D, fixture: Node3D) -> void:
	var label := Label3D.new()
	label.name = "%sLabel" % fixture.name
	label.text = _humanize_name(str(fixture.name))
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.pixel_size = 0.012
	label.font_size = 42
	label.outline_size = 10
	label.modulate = Color(1.0, 0.96, 0.78, 1.0)
	labels_root.add_child(label)
	label.global_position = fixture.global_position + (Vector3.UP * _fixture_label_height(fixture))


func _fixture_label_height(fixture: Node3D) -> float:
	if fixture is CSGBox3D:
		var box := fixture as CSGBox3D
		var half_size := box.size * 0.5
		var fixture_basis := box.global_transform.basis
		return (
			absf(fixture_basis.x.y) * half_size.x
			+ absf(fixture_basis.y.y) * half_size.y
			+ absf(fixture_basis.z.y) * half_size.z
			+ 0.65
		)
	if fixture is Area3D:
		var shape_node := fixture.get_node_or_null("CollisionShape3D") as CollisionShape3D
		if shape_node != null and shape_node.shape is BoxShape3D:
			return (shape_node.shape as BoxShape3D).size.y * 0.5 + 0.65
	return 1.0


func _humanize_name(value: String) -> String:
	var result := ""
	for index in value.length():
		var character := value[index]
		if index > 0 and character == character.to_upper() and character != character.to_lower():
			result += " "
		result += character
	return result.replace("_", " ")

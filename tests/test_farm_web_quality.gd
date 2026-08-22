extends Node

const FarmWebQualityScript := preload("res://scripts/courses/farm/farm_web_quality.gd")
const SpinningPropScript := preload("res://scripts/props/spinning_prop.gd")
const RENDERING_METHOD_SETTING := "rendering/renderer/rendering_method"
const VIEWPORT_3D_SCALE_PROPERTY := "scaling_3d_scale"


class MockSky:
	extends Node3D

	var cloudiness := 5
	var wind := 5
	var bird_spawn_interval_range := Vector2(8.0, 18.0)
	var bird_spawn_min_count := 1
	var bird_spawn_max_count := 2
	var update_interval := 0.0

	func set_cloudiness(value: int) -> void:
		cloudiness = value

	func set_wind(value: int) -> void:
		wind = value


func _ready() -> void:
	var original_rendering_method := str(ProjectSettings.get_setting(RENDERING_METHOD_SETTING, ""))
	var original_max_fps := Engine.max_fps
	var viewport := get_viewport()
	var original_render_scale_3d := float(viewport.get(VIEWPORT_3D_SCALE_PROPERTY))
	Engine.max_fps = 0
	viewport.set(VIEWPORT_3D_SCALE_PROPERTY, 1.0)

	ProjectSettings.set_setting(RENDERING_METHOD_SETTING, "forward_plus")
	var inactive_fixture := _build_fixture(false)
	add_child(inactive_fixture)
	await get_tree().process_frame
	await get_tree().process_frame
	if not _inactive_fixture_remained_unchanged(inactive_fixture):
		ProjectSettings.set_setting(RENDERING_METHOD_SETTING, original_rendering_method)
		Engine.max_fps = original_max_fps
		viewport.set(VIEWPORT_3D_SCALE_PROPERTY, original_render_scale_3d)
		get_tree().quit(1)
		return
	inactive_fixture.queue_free()

	ProjectSettings.set_setting(RENDERING_METHOD_SETTING, "gl_compatibility")
	var active_fixture := _build_fixture(false)
	add_child(active_fixture)
	await get_tree().process_frame
	await get_tree().process_frame
	if not _active_fixture_applied_settings(active_fixture):
		ProjectSettings.set_setting(RENDERING_METHOD_SETTING, original_rendering_method)
		Engine.max_fps = original_max_fps
		viewport.set(VIEWPORT_3D_SCALE_PROPERTY, original_render_scale_3d)
		get_tree().quit(1)
		return
	active_fixture.queue_free()
	await get_tree().process_frame
	if Engine.max_fps != 0:
		push_error("Farm web quality did not restore max FPS")
		ProjectSettings.set_setting(RENDERING_METHOD_SETTING, original_rendering_method)
		Engine.max_fps = original_max_fps
		viewport.set(VIEWPORT_3D_SCALE_PROPERTY, original_render_scale_3d)
		get_tree().quit(1)
		return
	if not is_equal_approx(float(viewport.get(VIEWPORT_3D_SCALE_PROPERTY)), original_render_scale_3d):
		push_error("Farm web quality did not restore 3D render scale")
		ProjectSettings.set_setting(RENDERING_METHOD_SETTING, original_rendering_method)
		Engine.max_fps = original_max_fps
		viewport.set(VIEWPORT_3D_SCALE_PROPERTY, original_render_scale_3d)
		get_tree().quit(1)
		return

	ProjectSettings.set_setting(RENDERING_METHOD_SETTING, original_rendering_method)
	Engine.max_fps = original_max_fps
	viewport.set(VIEWPORT_3D_SCALE_PROPERTY, original_render_scale_3d)
	print("Farm web quality OK")
	get_tree().quit(0)


func _build_fixture(force_enabled: bool) -> Node3D:
	var root := Node3D.new()
	root.name = "LevelFarm"

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 180.0
	root.add_child(sun)

	var world_environment := WorldEnvironment.new()
	world_environment.name = "WorldEnvironment"
	var environment := Environment.new()
	environment.ambient_light_energy = 0.5
	environment.fog_density = 0.02
	environment.fog_depth_begin = 100.0
	environment.fog_depth_end = 200.0
	environment.fog_sky_affect = 0.5
	environment.volumetric_fog_density = 0.003
	environment.adjustment_enabled = true
	environment.adjustment_saturation = 0.85
	environment.adjustment_contrast = 1.0
	world_environment.environment = environment
	root.add_child(world_environment)

	var sky := MockSky.new()
	sky.name = "Sky"
	root.add_child(sky)

	var corn_root := Node3D.new()
	corn_root.name = "FarmCornFields"
	root.add_child(corn_root)

	for index in 2:
		var corn_field := MultiMeshInstance3D.new()
		corn_field.name = "CornField%d" % index
		corn_field.visibility_range_end = 400.0
		corn_field.visibility_range_end_margin = 80.0
		corn_field.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		corn_root.add_child(corn_field)

	var buildings := Node3D.new()
	buildings.name = "buildings"
	root.add_child(buildings)

	var barn_mesh := MeshInstance3D.new()
	barn_mesh.name = "BarnMesh"
	barn_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	barn_mesh.visibility_range_end = 0.0
	barn_mesh.visibility_range_end_margin = 0.0
	buildings.add_child(barn_mesh)

	var cars := Node3D.new()
	cars.name = "cars"
	root.add_child(cars)

	var car_mesh := MeshInstance3D.new()
	car_mesh.name = "CarMesh"
	car_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	car_mesh.visibility_range_end = 0.0
	car_mesh.visibility_range_end_margin = 0.0
	cars.add_child(car_mesh)

	var mud := MeshInstance3D.new()
	mud.name = "mud"
	mud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	root.add_child(mud)

	var animals := Node3D.new()
	animals.name = "animals"
	root.add_child(animals)

	var animal_area := Area3D.new()
	animal_area.name = "ChickenWanderArea"
	animal_area.monitoring = true
	animal_area.monitorable = true
	animals.add_child(animal_area)

	var animal_collision := CollisionShape3D.new()
	animal_collision.name = "AnimalCollision"
	animal_collision.disabled = false
	animal_area.add_child(animal_collision)

	var animal_mesh := MeshInstance3D.new()
	animal_mesh.name = "AnimalMesh"
	animal_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	animals.add_child(animal_mesh)

	var decorative_animal := Node3D.new()
	decorative_animal.name = "Sheep"
	animals.add_child(decorative_animal)

	var animal_audio := AudioStreamPlayer3D.new()
	animal_audio.name = "AnimalAudio"
	animals.add_child(animal_audio)

	var coins := Node3D.new()
	coins.name = "coins"
	root.add_child(coins)

	var coin_area := Area3D.new()
	coin_area.name = "CoinArea"
	coin_area.monitoring = true
	coin_area.monitorable = true
	coins.add_child(coin_area)

	var coin_spinner := Node3D.new()
	coin_spinner.name = "CoinSpinner"
	coin_spinner.set_script(SpinningPropScript)
	coins.add_child(coin_spinner)

	var quality := FarmWebQualityScript.new()
	quality.name = "FarmWebQuality"
	quality.force_enabled = force_enabled
	root.add_child(quality)

	return root


func _inactive_fixture_remained_unchanged(root: Node3D) -> bool:
	var sun := root.get_node("Sun") as DirectionalLight3D
	var sky := root.get_node("Sky") as MockSky
	var environment := (root.get_node("WorldEnvironment") as WorldEnvironment).environment
	var corn_field := root.get_node("FarmCornFields/CornField0") as MultiMeshInstance3D
	var barn_mesh := root.get_node("buildings/BarnMesh") as MeshInstance3D
	var car_mesh := root.get_node("cars/CarMesh") as MeshInstance3D
	var animals := root.get_node("animals") as Node3D
	var animal_area := root.get_node("animals/ChickenWanderArea") as Area3D
	var animal_collision := root.get_node("animals/ChickenWanderArea/AnimalCollision") as CollisionShape3D
	var animal_mesh := root.get_node("animals/AnimalMesh") as MeshInstance3D
	var decorative_animal := root.get_node("animals/Sheep") as Node3D
	var coin_area := root.get_node("coins/CoinArea") as Area3D
	var coin_spinner := root.get_node("coins/CoinSpinner")
	if Engine.max_fps != 0:
		push_error("Inactive farm web quality changed max FPS")
		return false
	if not is_equal_approx(float(get_viewport().get(VIEWPORT_3D_SCALE_PROPERTY)), 1.0):
		push_error("Inactive farm web quality changed 3D render scale")
		return false
	if not is_equal_approx(sun.directional_shadow_max_distance, 180.0):
		push_error("Inactive farm web quality changed sun shadows")
		return false
	if sky.cloudiness != 5 or sky.wind != 5:
		push_error("Inactive farm web quality changed sky density")
		return false
	if not is_equal_approx(sky.update_interval, 0.0):
		push_error("Inactive farm web quality changed sky update interval")
		return false
	if not is_equal_approx(environment.ambient_light_energy, 0.5):
		push_error("Inactive farm web quality changed environment")
		return false
	if not is_equal_approx(corn_field.visibility_range_end, 400.0):
		push_error("Inactive farm web quality changed corn visibility")
		return false
	if barn_mesh.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_ON:
		push_error("Inactive farm web quality changed scenery shadows")
		return false
	if not is_equal_approx(barn_mesh.visibility_range_end, 0.0):
		push_error("Inactive farm web quality changed building visibility range")
		return false
	if not is_equal_approx(car_mesh.visibility_range_end, 0.0):
		push_error("Inactive farm web quality changed small scenery visibility range")
		return false
	if animal_mesh.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_ON:
		push_error("Inactive farm web quality changed animal shadows")
		return false
	if animals.process_mode != Node.PROCESS_MODE_INHERIT:
		push_error("Inactive farm web quality changed animal processing")
		return false
	if animal_area.process_mode != Node.PROCESS_MODE_INHERIT:
		push_error("Inactive farm web quality changed animal wander processing")
		return false
	if decorative_animal.process_mode != Node.PROCESS_MODE_INHERIT:
		push_error("Inactive farm web quality changed decorative animal processing")
		return false
	if not animal_area.monitoring or not animal_area.monitorable:
		push_error("Inactive farm web quality changed animal areas")
		return false
	if animal_collision.disabled:
		push_error("Inactive farm web quality changed animal collisions")
		return false
	if not coin_area.monitoring or not coin_area.monitorable:
		push_error("Inactive farm web quality changed coin areas")
		return false
	if not is_equal_approx(float(coin_spinner.get("update_interval")), 0.0):
		push_error("Inactive farm web quality changed coin spin interval")
		return false
	return true


func _active_fixture_applied_settings(root: Node3D) -> bool:
	var sun := root.get_node("Sun") as DirectionalLight3D
	var sky := root.get_node("Sky") as MockSky
	var environment := (root.get_node("WorldEnvironment") as WorldEnvironment).environment
	var corn_field := root.get_node("FarmCornFields/CornField0") as MultiMeshInstance3D
	var barn_mesh := root.get_node("buildings/BarnMesh") as MeshInstance3D
	var car_mesh := root.get_node("cars/CarMesh") as MeshInstance3D
	var mud := root.get_node("mud") as MeshInstance3D
	var animals := root.get_node("animals") as Node3D
	var animal_area := root.get_node("animals/ChickenWanderArea") as Area3D
	var animal_collision := root.get_node("animals/ChickenWanderArea/AnimalCollision") as CollisionShape3D
	var animal_mesh := root.get_node("animals/AnimalMesh") as MeshInstance3D
	var decorative_animal := root.get_node("animals/Sheep") as Node3D
	var coin_area := root.get_node("coins/CoinArea") as Area3D
	var coin_spinner := root.get_node("coins/CoinSpinner")
	if Engine.max_fps != 60:
		push_error("Farm web quality did not cap max FPS")
		return false
	if not is_equal_approx(float(get_viewport().get(VIEWPORT_3D_SCALE_PROPERTY)), 0.85):
		push_error("Farm web quality did not reduce 3D render scale")
		return false
	if not is_equal_approx(sun.directional_shadow_max_distance, 55.0):
		push_error("Farm web quality did not reduce sun shadow distance")
		return false
	if sky.cloudiness != 3 or sky.wind != 3:
		push_error("Farm web quality did not retune sky density")
		return false
	if sky.bird_spawn_min_count != 0 or sky.bird_spawn_max_count != 1:
		push_error("Farm web quality did not retune bird spawn count")
		return false
	if not is_equal_approx(sky.update_interval, 0.1):
		push_error("Farm web quality did not throttle sky updates")
		return false
	if not is_equal_approx(environment.ambient_light_energy, 0.42):
		push_error("Farm web quality did not retune ambient light")
		return false
	if not is_equal_approx(environment.fog_density, 0.012):
		push_error("Farm web quality did not retune fog")
		return false
	if not is_equal_approx(environment.volumetric_fog_density, 0.0):
		push_error("Farm web quality did not disable volumetric fog density")
		return false
	if not is_equal_approx(environment.adjustment_saturation, 1.05):
		push_error("Farm web quality did not retune saturation")
		return false
	if not is_equal_approx(corn_field.visibility_range_end, 160.0):
		push_error("Farm web quality did not reduce corn visibility range")
		return false
	if not is_equal_approx(corn_field.visibility_range_end_margin, 20.0):
		push_error("Farm web quality did not reduce corn visibility margin")
		return false
	if corn_field.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
		push_error("Farm web quality did not disable corn shadows")
		return false
	if barn_mesh.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
		push_error("Farm web quality did not disable building shadows")
		return false
	if not is_equal_approx(barn_mesh.visibility_range_end, 280.0):
		push_error("Farm web quality did not set building visibility range")
		return false
	if not is_equal_approx(barn_mesh.visibility_range_end_margin, 35.0):
		push_error("Farm web quality did not set building visibility margin")
		return false
	if not is_equal_approx(car_mesh.visibility_range_end, 180.0):
		push_error("Farm web quality did not set small scenery visibility range")
		return false
	if not is_equal_approx(car_mesh.visibility_range_end_margin, 25.0):
		push_error("Farm web quality did not set small scenery visibility margin")
		return false
	if mud.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
		push_error("Farm web quality did not disable top-level scenery shadows")
		return false
	if animal_mesh.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_ON:
		push_error("Farm web quality changed animal shadows")
		return false
	if animals.process_mode != Node.PROCESS_MODE_INHERIT:
		push_error("Farm web quality disabled the animal root")
		return false
	if animal_area.process_mode != Node.PROCESS_MODE_INHERIT:
		push_error("Farm web quality disabled chicken/pigeon wander processing")
		return false
	if decorative_animal.process_mode != Node.PROCESS_MODE_DISABLED:
		push_error("Farm web quality did not disable decorative animal processing")
		return false
	if animal_area.monitoring or animal_area.monitorable:
		push_error("Farm web quality did not disable animal areas")
		return false
	if not animal_collision.disabled:
		push_error("Farm web quality did not disable animal collisions")
		return false
	if not coin_area.monitoring or not coin_area.monitorable:
		push_error("Farm web quality changed coin areas")
		return false
	if not is_equal_approx(float(coin_spinner.get("update_interval")), 0.1):
		push_error("Farm web quality did not throttle coin spin")
		return false
	return true

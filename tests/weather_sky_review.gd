extends SceneTree
const World = preload("res://scripts/world/alpine_world.gd")
const Weather = preload("res://scripts/presentation/weather_controller.gd")
const Storm = preload("res://scripts/presentation/storm_effects.gd")
var world
var weather
var storm
var camera
var output = "res://artifacts/weather_upgrade/sky"
func _initialize() -> void: call_deferred("run")
func run() -> void:
	if DisplayServer.get_name()=="headless": quit(2); return
	root.size = Vector2i(1280,720); Engine.max_fps = 60
	world = World.new(); root.add_child(world); world._environment()
	world.assets = preload("res://scripts/presentation/alpine_assets.gd").new(world.cloud_lighting,world.quality)
	weather = Weather.new(); root.add_child(weather)
	storm = Storm.new(); root.add_child(storm); storm.layer_height = world.cloud_lighting.height_m
	var ground = MeshInstance3D.new(); ground.mesh = PlaneMesh.new(); ground.mesh.size = Vector2(10000,10000)
	ground.material_override = world.cloud_lighting.material(Color(0.88,0.93,1.0)); root.add_child(ground)
	camera = Camera3D.new(); root.add_child(camera); camera.position = Vector3(0,1100,0); camera.far = 14000
	camera.look_at(Vector3(0,1450,-3500))
	var manifest = []
	for preset in ["snowstorm","thunderstorm"]:
		weather.seed_stream(849205174); weather.set_time_of_day("day")
		weather.selected_preset = "cloudy"; weather.target_preset = preset; weather.automatic = true
		weather.phase = "blend"; weather.phase_seconds = 0; weather.duration = 45; weather.automatic_storm = true
		await clip(preset+"_approach_peak_recovery",240.0/450.0,450,2)
		manifest.append({"clip":preset+"_approach_peak_recovery","playback_seconds":15,"weather_seconds":240,"accelerated":true})
	weather.set_preset("thunderstorm"); weather.set_automatic(false); weather.set_time_of_day("dusk")
	for setting in [2,1,0]:
		var event = Storm.event(weather.variation_seed,0)
		camera.look_at(Vector3(sin(event.angle)*event.radius,storm.layer_height-200,cos(event.angle)*event.radius))
		weather.active_seconds = event.at-.2; storm.clear_transients(weather.active_seconds)
		await clip("lightning_%d" % setting,1.0/30.0,60,setting)
		manifest.append({"clip":"lightning_%d" % setting,"playback_seconds":2,"accelerated":false})
	preload("res://tests/test_report.gd").write(output+"/review.json",JSON.stringify(manifest,"\t"))
	storm.clear_transients(); storm.queue_free(); weather.queue_free(); world.queue_free(); ground.queue_free(); camera.queue_free()
	await process_frame; quit()
func clip(label: String, dt: float, frames: int, setting: int) -> void:
	DirAccess.make_dir_recursive_absolute(output+"/"+label)
	for frame in frames:
		weather.update_weather(dt,true)
		storm.update_storm(weather.state,true,setting,false,true,0)
		if label.begins_with("lightning") and frame in [5,6,7,10]:
			for i in storm.bolts.size():
				if storm.bolts[i].visible: print("LIGHTNING_SAMPLE ",label," frame=",frame," alpha=",storm.materials[i].albedo_color.a," screen=",camera.unproject_position(storm.bolts[i].position)," position=",storm.bolts[i].position)
		world.update_weather(weather.state,dt,true)
		await process_frame; await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_jpg(output+"/"+label+"/%03d.jpg" % frame,.86)
	print("WEATHER_SKY_MOTION ",label)

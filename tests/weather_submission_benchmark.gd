extends SceneTree
## Isolates world/weather submission cost; no solver, loading or capture work.
const World = preload("res://scripts/world/alpine_world.gd")
const Weather = preload("res://scripts/presentation/weather_controller.gd")
const Assets = preload("res://scripts/presentation/alpine_assets.gd")
const Graphics = preload("res://scripts/presentation/graphics_quality.gd")
const Costs = preload("res://scripts/diagnostics/frame_costs.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	if DisplayServer.get_name()=="headless": printerr("Native renderer required"); quit(2); return
	Engine.max_fps = 120
	root.size = Vector2i(640,360)
	var label = "weather_submission"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--benchmark-label="): label = arg.get_slice("=",1).validate_filename()
	var world = World.new(); root.add_child(world); world._environment()
	world.assets = Assets.new(world.cloud_lighting,Graphics.preset(2))
	var weather = Weather.new(); root.add_child(weather); weather.set_preset("clear")
	var source = StandardMaterial3D.new(); source.resource_name = "FC_Tree"
	world.assets.material_for(source)
	for i in 100: world.cloud_lighting.material(Color.WHITE)
	var rows = []
	for repetition in 3:
		for warmup in 120:
			weather.update_weather(1.0/120,true); world.update_weather(weather.state,1.0/120,true)
			await process_frame
		var samples = PackedFloat64Array()
		for sample in 480:
			weather.update_weather(1.0/120,true)
			var start = Time.get_ticks_usec()
			world.update_weather(weather.state,1.0/120,true)
			samples.append(Time.get_ticks_usec()-start)
			await process_frame
		rows.append(Costs.stats(samples))
		print("WEATHER_SUBMISSION ",repetition+1," ",JSON.stringify(rows[-1]))
	FileAccess.open("res://artifacts/fps_optimization/"+label+".json",FileAccess.WRITE).store_string(JSON.stringify({"scope":"World submission CPU microseconds, 100 cloud receivers plus one wind material; no full-descent or GPU performance claim","rows":rows},"\t"))
	world.queue_free(); weather.queue_free(); await process_frame
	quit(0)

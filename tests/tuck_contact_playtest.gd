extends "res://tests/skier_animation_playtest.gd"
## Real v13 terrain, identical start/input cases; captures and timing are separate.
const Definition = preload("res://scripts/world/mountain_definition.gd")
var field
var reference_handling = false
var timing = false
var reference_model = ""
var reference_scene = ""
var current_scene_path = "res://main.tscn"
var runtime_snapshot = ""
var fixtures_path = ""
var fixtures: Dictionary = {}
var solver_us: Array[float] = []
var failures: Array = []
var observer: Camera3D
var source_hashes: Dictionary = {}

func run() -> void:
	if DisplayServer.get_name()=="headless": quit(2); return
	var args = OS.get_cmdline_user_args()
	reference_handling = "--reference-handling" in args
	timing = "--timing" in args
	for argument in args:
		if argument.begins_with("--reference-model="): reference_model = argument.trim_prefix("--reference-model=")
		if argument.begins_with("--reference-scene="): reference_scene = argument.trim_prefix("--reference-scene=")
		if argument.begins_with("--current-scene="): current_scene_path = argument.trim_prefix("--current-scene=")
		if argument.begins_with("--runtime-snapshot="): runtime_snapshot = argument.trim_prefix("--runtime-snapshot=")
		if argument.begins_with("--fixtures="): fixtures_path = argument.trim_prefix("--fixtures=")
	if reference_handling and not FileAccess.file_exists(reference_scene):
		printerr("Reference capture requires a frozen scene/model"); quit(2); return
	if not fixtures_path.is_empty() and FileAccess.file_exists(fixtures_path):
		fixtures = JSON.parse_string(FileAccess.get_file_as_string(fixtures_path))
	output = "res://artifacts/tuck_contact_v21/"+("before" if reference_handling else "after")+("_timing" if timing else "_visual")
	DirAccess.make_dir_recursive_absolute(output)
	source_hashes = runtime_hashes()
	requested = Vector2i(3840,2160) if timing else Vector2i(1920,1080)
	field = Definition.generate(849205174,13)
	set_meta("mountain_to_load",{"definition":Definition.from_field(field,"Tuck and suspension validation"),"field":field})
	game = load(reference_scene if reference_handling else current_scene_path).instantiate()
	game.automated = true
	root.add_child(game); current_scene = game
	while not game.initialized or (game.loading and game.loading.busy): await process_frame
	game.set_process(false); game.set_physics_process(false)
	game.start_run(false); game.summit_ready = false; game.session.eligible = false; game.active = false
	game.sim.tuning = game.sim.tuning.duplicate()
	if not reference_handling: game.sim.tuning.arcade_carve_strength = 1.0
	game.effects.muted = true; game.hud.hide(); game.hud.hide_menu(); game.speed_periphery.hide()
	game.weather.set_preset("clear"); game.weather.set_time_of_day("day")
	game.display_settings.display_mode = "windowed"
	game.display_settings.upscaler = "fsr2" if timing else "native"
	game.display_settings.render_scale = .75 if timing else 1.0
	game.display_settings.fps_limit = 120
	game.display_settings.apply_display(root,requested); game.display_settings.apply_viewport(root)
	# With canvas stretching, WindowTexture.get_size() reports logical rather
	# than rendered dimensions. A 1:1 timing canvas makes it an exact size check.
	if timing: root.content_scale_size = requested
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	observer = Camera3D.new(); game.add_child(observer)
	observer.fov = 55; observer.near = .05; observer.far = 15000
	var layer = CanvasLayer.new(); root.add_child(layer)
	label = Label.new(); layer.add_child(label); label.position = Vector2(20,18)
	label.add_theme_font_size_override("font_size",22); label.visible = not timing
	for i in 120: await process_frame
	await RenderingServer.frame_post_draw
	# Timing reads the actual output texture dimensions without a GPU readback;
	# D3D12's 4K readback can exhaust the validation job before measurements.
	var actual = Vector2i(root.get_texture().get_size()) if timing else root.get_texture().get_image().get_size()
	if actual!=requested: printerr("Pixel mismatch: ",actual); quit(2); return
	if timing and (root.size!=requested or root.content_scale_size!=requested):
		printerr("Timing canvas/window must match output pixels"); quit(2); return
	if timing: process_frame.connect(measure_frame)
	for request in [
		{"name":"auto_tuck","steer":1.0,"kmh":120.0,"seconds":4.5},
		{"name":"small_bumps","steer":.15,"kmh":160.0,"seconds":6.0},
		{"name":"left_carve","steer":-1.0,"kmh":90.0,"seconds":4.0},
		{"name":"reversal","steer":1.0,"kmh":120.0,"seconds":5.0,"reverse":true}]:
		await ride(request)
	measuring = false
	if runtime_hashes()!=source_hashes: failures.append("Runtime sources changed during native run")
	var report = {"model":game.sim.MODEL_VERSION,"reference_handling":reference_handling,"unranked":not game.session.eligible,
		"seed":849205174,"generator":13,"cache_hit":field.cache_hit,"actual_pixels":[actual.x,actual.y],
		"pixel_verification":"texture dimensions with 1:1 window/canvas" if timing else "rendered image readback",
		"display":game.display_settings.report(root,actual),"device":RenderingServer.get_video_adapter_name(),
		"height_sha256":field.height_checksum,"obstacle_sha256":field.obstacle_checksum,"sources":source_hashes,
		"cases":rows,"failures":failures,"capture_overhead_included":not timing}
	if timing:
		report.frame_ms = stats(frames); report.render_cpu_ms = stats(render_cpu); report.gpu_ms = stats(gpu)
		report.solver_us = stats(solver_us); report.peak_video_bytes = peak_video; report.peak_engine_static_bytes = peak_static
	FileAccess.open(output+"/results.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("ARCADE_NATIVE ",output," failures=",failures)
	game.effects.stop_audio(); game.queue_free(); await process_frame
	quit(0 if failures.is_empty() else 1)

func ride(request: Dictionary) -> void:
	var fixture = find_fixture(request)
	if fixture.is_empty(): failures.append(request.name+": no clear supported fixture"); return
	var coordinates: Array = fixture.origin
	var origin = Vector3(coordinates[0],coordinates[1],coordinates[2])
	var heading: float = fixture.heading
	game.sim.reset(origin,heading); game.sim.prime_contacts(game.world.ski_surface)
	game.sim.velocity = game.sim.support_basis().z*request.kmh/3.6
	game.sim.effective_tuck = 1.0
	game.skier.reset_animation(game.sim); game.camera.reset(); game.effects.reset()
	var intent = RiderInput.new(); intent.tuck = 1.0
	var samples: Array = []
	var picture_folder = output+"/"+request.name
	if not timing: DirAccess.make_dir_recursive_absolute(picture_folder)
	# Warm the actual region and camera before recording frame timings.
	game.previous_position = game.sim.position
	game.intent = intent; game._process(DT)
	var warm_center: Vector3 = game.sim.position+Vector3.UP*.8
	place_observer(warm_center,heading)
	for i in 90: await process_frame
	measuring = timing; last_frame = 0
	var count = int(request.seconds*(120 if timing else 30))
	for frame in count:
		var seconds = frame/float(120 if timing else 30)
		intent.steer = steering_at(request,seconds)
		for tick in (1 if timing else 4):
			game.previous_position = game.sim.position
			var start = Time.get_ticks_usec()
			game.sim.step(DT,intent,game.world.ski_surface)
			if timing: solver_us.append(Time.get_ticks_usec()-start)
			game.skier.step_animation(DT,game.sim,intent,field)
		game.intent = intent; game.session.elapsed += DT*(1 if timing else 4)
		game._process(DT*(1 if timing else 4)); game.speed_periphery.hide()
		var center: Vector3 = game.sim.position+Vector3.UP*.8
		place_observer(center,game.sim.heading)
		label.text = ("REFERENCE" if reference_handling else "AUTO TUCK / CONTACT")+" / "+request.name.replace("_"," ").to_upper()
		if timing: await physics_frame
		else:
			await process_frame; await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_jpg(picture_folder+"/%04d.jpg"%frame,.92)
		if frame%(6 if timing else 3)==0:
			samples.append({"seconds":seconds,"position":[game.sim.position.x,game.sim.position.y,game.sim.position.z],
				"speed_kmh":game.sim.speed_kmh(),"roll_deg":rad_to_deg(game.sim.body.roll),"slip_deg":rad_to_deg(game.sim.slip_angle),"grounded":game.sim.grounded,"tuck":game.sim.effective_tuck,"load_n":game.sim.normal_load*game.sim.tuning.rider_mass,"reach_m":game.sim.support_offset_m})
		if game.sim.crashed: failures.append(request.name+": "+game.sim.crash_reason); break
	measuring = false
	rows.append({"name":request.name,"start":[origin.x,origin.y,origin.z],"heading":heading,"samples":samples,"crash":game.sim.crash_reason,"airtime_s":game.sim.total_airtime})

func place_observer(center: Vector3, yaw: float) -> void:
	var desired = center+Basis(Vector3.UP,yaw)*Vector3(2.8,1.3,-5.8)
	# Observer clearance is independent of the gameplay camera and solver.
	desired.y = maxf(desired.y,float(field.sample(desired.x,desired.z).height)+1.0)
	observer.position = desired
	observer.look_at(center); observer.make_current()

func steering_at(request: Dictionary, seconds: float) -> float:
	if request.name=="auto_tuck":
		if seconds>=.6 and seconds<.7: return 1.0
		if seconds>=1.4 and seconds<2.2: return 1.0
		if seconds>=2.2 and seconds<3.0: return -1.0
		return 0.0
	if request.name=="small_bumps": return .15*sin(seconds*2.0)
	return request.steer*(-1.0 if request.get("reverse",false) and seconds>=2.0 else 1.0)

func find_fixture(request: Dictionary) -> Dictionary:
	if fixtures.has(request.name): return fixtures[request.name]
	var models: Array = [preload("res://scripts/core/ski_simulation.gd")]
	if FileAccess.file_exists(reference_model): models.push_front(load(reference_model))
	for face in field.faces:
		for z in [2150.0,2050.0,2250.0,1950.0,1850.0,1700.0,1500.0,1100.0,800.0,2350.0,2450.0]:
			for side in [-1.0,1.0]:
				var x: float = face.glade_x(z,side) if z>1850 else face.gully_x(z,side)
				var point: Vector2 = face.to_world(Vector2(x,z))
				var origin = Vector3(point.x,field.sample(point.x,point.y).height,point.y)
				var valid = true
				var air: Array = []
				for model in models:
					var sim = model.new()
					sim.reset(origin,face.heading); sim.prime_contacts(game.world.ski_surface)
					sim.velocity = sim.support_basis().z*request.kmh/3.6; sim.effective_tuck = 1.0
					var intent = RiderInput.new(); intent.tuck = 1.0
					for tick in int(request.seconds*120):
						intent.steer = steering_at(request,tick/120.0)
						sim.step(DT,intent,game.world.ski_surface)
						if sim.crashed or sim.rock_contact>0.0: valid = false; break
					air.append(sim.total_airtime)
					if not valid: break
				if not valid: continue
				if request.name=="small_bumps":
					if air[-1]>.25: continue
					if air.size()>1 and (air[0]<.25 or air[-1]>air[0]*.4): continue
				elif air.any(func(value): return value>.1): continue
				var found = {"origin":[origin.x,origin.y,origin.z],"heading":face.heading,"preflight_airtime_s":air}
				fixtures[request.name] = found
				if not fixtures_path.is_empty(): FileAccess.open(fixtures_path,FileAccess.WRITE).store_string(JSON.stringify(fixtures,"\t"))
				return found
	return {}

func runtime_hashes() -> Dictionary:
	var result: Dictionary = {}
	# Normal skiing dependencies; the independent motion workshop is not loaded
	# by this harness. Prepared snapshots also hold its shared HUD/writer fixed.
	for folder in ["res://scripts/core","res://scripts/world","res://scripts/presentation","res://scripts/racing","res://scripts/ui","res://assets/graphics","res://config"]:
		hash_folder(folder,result)
	for path in ["res://main.tscn","res://scripts/main.gd","res://project.godot","res://tests/tuck_contact_playtest.gd"]:
		if not runtime_snapshot.is_empty() and FileAccess.file_exists(runtime_snapshot+"/"+path.trim_prefix("res://")): continue
		result[path] = FileAccess.get_sha256(path)
	if not runtime_snapshot.is_empty(): hash_folder(runtime_snapshot,result)
	for path in [reference_model,reference_scene,current_scene_path]:
		if FileAccess.file_exists(path): result[path] = FileAccess.get_sha256(path)
	return result

func hash_folder(folder: String, hashes: Dictionary) -> void:
	for name in DirAccess.get_files_at(folder):
		if name.get_extension() in ["gd","gdshader","gdshaderinc","tres"]:
			var path = folder+"/"+name
			# Optional prepared snapshots keep concurrent presentation work out
			# of the matched before/after runtime; hash the loaded copies instead.
			if not runtime_snapshot.is_empty() and FileAccess.file_exists(runtime_snapshot+"/"+path.trim_prefix("res://")): continue
			hashes[path] = FileAccess.get_sha256(path)
	for name in DirAccess.get_directories_at(folder): hash_folder(folder+"/"+name,hashes)

extends SceneTree
## Ordinary solver turns, fixed input/camera, separate screenshot-free timing.
const Definition = preload("res://scripts/world/mountain_definition.gd")
const OUTPUT = "res://artifacts/snow_contact_20260911"
const DT = 1.0/120.0
var game
var field
var observer: Camera3D
var output: String
var rows: Array = []
var failures: Array = []
var reference = false
var mountain = false
var timing = false
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var args = OS.get_cmdline_user_args()
	reference = "--reference" in args
	mountain = "--mountain" in args
	timing = "--timing" in args
	output = OUTPUT+("/mountain" if mountain else "/lab")+("_before" if reference else "_after")+("_timing" if timing else "")
	DirAccess.make_dir_recursive_absolute(output)
	if mountain:
		field = Definition.generate(849205174,15)
		set_meta("mountain_to_load",{"definition":Definition.from_field(field,"Snow contact review"),"field":field})
	else: set_meta("test_lab_fixture",true)
	game = load("res://main.tscn").instantiate()
	if reference:
		var source = FileAccess.get_file_as_string("res://scripts/main.gd").replace("res://scripts/presentation/speed_effects.gd",OUTPUT+"/baseline/scripts/presentation/speed_effects.gd").replace(",voice_speaking,skier.skis)",",voice_speaking)")
		preload("res://tests/test_report.gd").write(output+"/main_reference.gd",source)
		game.set_script(load(output+"/main_reference.gd"))
	game.automated = true
	root.add_child(game); current_scene = game
	while not game.initialized or (game.loading and game.loading.busy): await process_frame
	game.set_process(false); game.set_physics_process(false)
	field = game.field
	if mountain: game.start_run(false)
	else: game.start_speed_lab(130)
	game.summit_ready = false; game.active = true; game.session.eligible = false
	game.effects.muted = true; game.hud.hide(); game.hud.hide_menu()
	game.weather.set_preset("clear"); game.weather.set_time_of_day("day")
	game.set_graphics_quality(2)
	game.world.environment.sdfgi_enabled = false
	game.display_settings.display_mode = "windowed"
	game.display_settings.upscaler = "auto" if timing else "native"
	game.display_settings.render_scale = .75 if timing else 1.0
	game.display_settings.frame_generation = false
	game.display_settings.fps_limit = 120 if timing else 60
	var requested = Vector2i(3840,2160) if timing else Vector2i(1920,1080)
	game.display_settings.apply_display(root,requested); game.display_settings.apply_viewport(root)
	root.content_scale_size = requested
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	game.frame_costs.enabled = timing
	observer = Camera3D.new(); observer.fov = 58; observer.far = 15000
	game.add_child(observer)
	for mode in ["glide","left","right","reversal"]:
		if timing:
			# Rehearse the same contact/particle/shader workload before measuring.
			await ride(mode)
			rows.pop_back()
		await ride(mode)
	var actual = root.get_texture().get_image().get_size()
	if actual!=requested: failures.append("Output size mismatch")
	var sources = {}
	var active_snow_sources = {}
	for path in ["scripts/core/ski_simulation.gd","scripts/main.gd","scripts/presentation/skier_visual.gd","scripts/presentation/snow_response.gd","scripts/presentation/snow_tracks.gd","scripts/presentation/powder_surface.gd","scripts/presentation/speed_effects.gd","assets/graphics/powder_compute.gd","assets/graphics/ski_track.gdshader"]:
		sources[path] = FileAccess.get_sha256("res://"+path)
		if FileAccess.file_exists(OUTPUT+"/baseline/"+path): active_snow_sources[path] = FileAccess.get_sha256((OUTPUT+"/baseline/" if reference else "res://")+path)
	var report = {"scope":"Ordinary input through current solver; short snow-contact fixture, not full-descent performance or human acceptance", "reference":reference,"mountain":mountain,"timing":timing,"unranked":not game.session.eligible,"model":game.sim.MODEL_VERSION,"engine":Engine.get_version_info(),"device":RenderingServer.get_video_adapter_name(),"display":game.display_settings.report(root,actual),"sources":sources,"active_snow_sources":active_snow_sources,"cases":rows,"failures":failures}
	preload("res://tests/test_report.gd").write(output+"/results.json",JSON.stringify(report,"\t"))
	print("SNOW_CONTACT_RENDER ",output," failures=",failures)
	game.effects.stop_audio(); game.queue_free(); await process_frame
	quit(0 if failures.is_empty() else 1)
func ride(mode: String) -> void:
	var p = Vector3(0,0,600)
	if mountain:
		var fixtures: Array = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/planted_snow_v22.json")).fixtures
		for fixture in fixtures:
			if fixture.name=="face_4_band_2": p = Vector3(fixture.origin[0],0,fixture.origin[2])
	p.y = field.sample(p.x,p.z).height
	var normal: Vector3 = field.contact_normal(p.x,p.z)
	var heading = atan2(normal.x,normal.z)
	game.sim.reset(p,heading); game.sim.prime_contacts(game.world.ski_surface)
	game.sim.velocity = game.sim.support_basis().z*130.0/3.6
	game.previous_position = p; game.effects.reset(); game.skier.reset_animation(game.sim); game.camera.reset()
	game.camera.make_current(); game._process(0)
	for frame in 90: await process_frame
	game.frame_costs.reset()
	var controls = RiderInput.new(); controls.tuck = .2
	var samples: Array = []; var effect_us: Array[float] = []; var frame_ms: Array[float] = []; var gpu_ms: Array[float] = []
	var last_us = Time.get_ticks_usec()
	for frame in (240 if timing else 120):
		var seconds = frame/(120.0 if timing else 60.0)
		controls.steer = 0.0 if mode=="glide" or seconds<.30 else (-.85 if mode=="left" else .85)
		if mode=="reversal" and seconds>1.1: controls.steer = -.85
		for tick in (1 if timing else 2):
			game.previous_position = game.sim.position
			game.sim.step(DT,controls,game.world.ski_surface)
			game.skier.step_animation(DT,game.sim,controls,field)
		game.intent = controls
		var start = Time.get_ticks_usec()
		game._process(DT if timing else 2*DT)
		effect_us.append((Time.get_ticks_usec()-start)/1000.0)
		if not timing: place_observer()
		await process_frame
		var now = Time.get_ticks_usec()
		frame_ms.append((now-last_us)/1000.0); last_us = now
		gpu_ms.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
		if not timing and frame in [17,18,19,22,36,60,65,66,67,70,90,119]:
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_jpg(output+"/%s_%03d.jpg"%[mode,frame],.95)
		if frame in [19,36,60,67,90,119,239]: samples.append({"frame":frame,"position":str(game.sim.position),"steer":controls.steer,"grounded":game.sim.grounded,"responses":[game.effects.responses[0].report(),game.effects.responses[1].report()]})
		if game.sim.crashed:
			failures.append(mode+": "+game.sim.crash_reason); break
	if not timing:
		game.camera.make_current()
		for frame in 3: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_jpg(output+"/"+mode+"_chase.jpg",.95)
	rows.append({"mode":mode,"samples":samples,"budget":game.effects.snow_budget(),"scopes_us":game.frame_costs.report(),"frame_ms":stats(frame_ms) if timing else {},"gpu_ms":stats(gpu_ms) if timing else {},"presentation_ms":stats(effect_us) if timing else {}})
func place_observer() -> void:
	var p: Vector3 = game.sim.position
	var f: Vector3 = game.sim.ski_forward
	var r: Vector3 = game.sim.surface_normal.cross(f).normalized()
	observer.position = p+f*3.4-r*3.6+Vector3.UP*2.5
	observer.look_at(p-f*.3+Vector3.UP*.12)
	observer.make_current()
func stats(values: Array[float]) -> Dictionary:
	values.sort()
	var sum = 0.0
	for value in values: sum+=value
	return {"mean":sum/maxi(1,values.size()),"p95":values[int(values.size()*.95)],"p99":values[int(values.size()*.99)]}

extends "res://tests/skier_animation_playtest.gd"
## Matched v11 scripted motion clips or a separate screenshot-free 4K run.
const Definition = preload("res://scripts/world/mountain_definition.gd")
var field
var before = false
var timing = false
var evidence: Array = []
var tick_us: Array[float] = []
var failures: Array = []
var view_cameras: Dictionary = {}
var folder_label = ""

func run():
	if DisplayServer.get_name()=="headless": quit(2); return
	before = "--baseline-v15" in OS.get_cmdline_user_args()
	timing = "--timing" in OS.get_cmdline_user_args()
	folder_label = ("before" if before else "after")+("_timing" if timing else "_visual")
	output = "res://artifacts/skier_refinement_v16/"+folder_label
	DirAccess.make_dir_recursive_absolute(output)
	requested = Vector2i(3840,2160) if timing else Vector2i(960,720)
	field = Definition.generate(849205174,11)
	set_meta("mountain_to_load",{"definition":Definition.from_field(field,"Skier refinement"),"field":field})
	var scene = "res://artifacts/skier_refinement_v16/reference/main.tscn" if before else "res://main.tscn"
	if not FileAccess.file_exists(scene): printerr("Missing frozen v15 reference: ",scene); quit(2); return
	game = load(scene).instantiate(); game.automated = true
	root.add_child(game); current_scene = game
	while not game.initialized or (game.loading and game.loading.busy): await process_frame
	game.set_process(false); game.set_physics_process(false)
	game.start_run(false); game.summit_ready = false; game.session.eligible = false
	game.active = false # Manual ticks; render the completed pose exactly once.
	game.effects.muted = true; game.hud.hide(); game.hud.hide_menu(); game.speed_periphery.hide()
	game.weather.set_preset("clear"); game.weather.set_time_of_day("day")
	game.camera.effects_enabled = false
	game.display_settings.display_mode = "windowed"
	game.display_settings.upscaler = "fsr2" if timing else "native"
	game.display_settings.render_scale = .75 if timing else 1.0
	game.display_settings.fps_limit = 120
	game.display_settings.apply_display(root,requested); game.display_settings.apply_viewport(root)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	var overlay = CanvasLayer.new(); root.add_child(overlay)
	label = Label.new(); overlay.add_child(label); label.position = Vector2(18,14)
	label.add_theme_font_size_override("font_size",20)
	label.add_theme_color_override("font_shadow_color",Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x",2); label.add_theme_constant_override("shadow_offset_y",2)
	label.visible = not timing
	for view in ["chase","side","front"]:
		var camera = Camera3D.new(); game.add_child(camera)
		camera.fov = 55; camera.near = .05; camera.far = 15000
		view_cameras[view] = camera
	for i in 120: await process_frame
	await RenderingServer.frame_post_draw
	var actual = root.get_texture().get_image().get_size()
	if actual!=requested: printerr("Wrong output size ",actual); quit(2); return
	if timing: process_frame.connect(measure_frame)
	var scenarios = [
		{"name":"left_turn","steer":-1.0,"seconds":4.0},
		{"name":"right_turn","steer":1.0,"seconds":4.0},
		{"name":"prepared_hop","hop":true,"seconds":3.0},
		{"name":"large_jump","height":10.0,"up":4.0,"seconds":6.0},
		{"name":"small_landing","height":.6,"up":-2.0,"seconds":3.0},
		{"name":"medium_landing","height":2.0,"up":-4.0,"seconds":3.0},
		{"name":"large_landing","height":7.0,"up":-8.0,"seconds":4.0},
		{"name":"tree_glance","tree":true,"seconds":2.0},
		{"name":"rock_glance","tree":false,"seconds":2.0}]
	for request in scenarios: await ride(request)
	measuring = false
	var report = {"physics":game.sim.MODEL_VERSION,"seed":849205174,"version":11,"unranked":not game.session.eligible,"cases":evidence,"failures":failures,
		"actual_pixels":[actual.x,actual.y],"display":game.display_settings.report(root,actual),"device":RenderingServer.get_video_adapter_name(),
		"capture_overhead_included":not timing,"height_sha256":field.height_checksum,"obstacle_sha256":field.obstacle_checksum}
	if timing:
		report.frame_ms = stats(frames); report.render_cpu_ms = stats(render_cpu); report.render_gpu_ms = stats(gpu)
		report.fixed_tick_us = stats(tick_us); report.peak_video_bytes = peak_video; report.peak_engine_static_bytes = peak_static
	preload("res://tests/test_report.gd").write(output+"/results.json",JSON.stringify(report,"\t"))
	print("REFINEMENT_NATIVE_COMPLETE ",JSON.stringify(report))
	game.effects.stop_audio(); game.queue_free(); await process_frame
	quit(0 if failures.is_empty() else 1)

func ride(request: Dictionary):
	var face = field.faces[0]
	var z = 2150.0 if request.has("steer") else 820.0
	var x: float = face.glade_x(z,-1) if z>1850 else face.gully_x(z,-1)
	var p: Vector2 = face.to_world(Vector2(x,z))
	var origin = Vector3(p.x,field.sample(p.x,p.y).height+request.get("height",0.0),p.y)
	var heading: float = face.heading
	var speed = 120.0/3.6 if request.has("steer") else 20.0
	if request.has("tree") and not request.tree:
		var fixture: Dictionary = rock_fixture(field,origin)
		if fixture.is_empty(): failures.append(request.name+": no reachable mineral fixture"); return
		origin = fixture.origin; heading = fixture.heading; speed = 10.0
	elif request.has("tree"):
		var candidates: Array = field.obstacles.filter(func(ob): return ob.tree==request.tree and field.contact_normal(ob.position.x,ob.position.z).y>.80 and ob.position.distance_to(origin)<1000)
		candidates.sort_custom(func(a,b): return a.position.distance_squared_to(origin)<b.position.distance_squared_to(origin))
		if candidates.is_empty(): failures.append(request.name+": no obstacle fixture"); return
		var ob = candidates[0]
		var normal: Vector3 = field.contact_normal(ob.position.x,ob.position.z)
		var downhill: Vector3 = Vector3.DOWN.slide(normal).normalized()
		heading = atan2(downhill.x,downhill.z)
		origin = ob.position-downhill*(ob.radius+4.0)+normal.cross(downhill)*(ob.radius*.65)
		origin.y = field.sample(origin.x,origin.z).height
		speed = 14.0
	game.sim.reset(origin,heading); game.sim.prime_contacts(game.world.ski_surface)
	game.sim.velocity = game.sim.support_basis().z*speed+Vector3.UP*request.get("up",0.0)
	if request.get("height",0.0)>0:
		game.sim._begin_flight(game.sim.support_basis()); game.sim.reset_pose_history()
	game.sim.effective_tuck = 1.0 if request.has("steer") else 0.0
	game.skier.reset_animation(game.sim); game.camera.reset(); game.effects.reset()
	var intent = RiderInput.new()
	var captures: Array = []
	var hops = 0
	var max_impact = 0.0
	var minimum_margin = INF
	var count = int(request.seconds*(120 if timing else 30))
	measuring = timing; last_frame = 0
	for frame_index in count:
		var seconds: float = frame_index/float(120 if timing else 30)
		intent.steer = request.get("steer",0.0)*(1.0 if seconds<2.0 else -1.0)
		intent.tuck = 1.0 if request.has("steer") else 0.0
		intent.jump_held = request.get("hop",false) and seconds<.30
		for tick in (1 if timing else 4):
			intent.jump = request.get("hop",false) and game.sim.ticks==36
			var start = Time.get_ticks_usec()
			game.previous_position = game.sim.position
			game.sim.step(DT,intent,game.world.ski_surface)
			game.skier.step_animation(DT,game.sim,intent,field)
			if timing: tick_us.append(Time.get_ticks_usec()-start)
			if game.sim.jump_executed: hops += 1
			max_impact = maxf(max_impact,game.sim.landing_force)
		game.intent = intent; game.session.elapsed += DT*(1 if timing else 4)
		game._process(DT*(1 if timing else 4)); game.speed_periphery.hide()
		if not timing and not before and game.sim.grounded:
			minimum_margin = minf(minimum_margin,game.skier.animation.clearance_margin(game.skier.rendered_joints,game.skier.global_transform))
		var center: Vector3 = game.sim.position+Vector3.UP*.85
		var basis = Basis(Vector3.UP,heading)
		for view in (["chase"] if timing else ["chase","side","front"]):
			var offset = Vector3(0,1.0,-5.4) if view=="chase" else (Vector3(3.8,.6,0) if view=="side" else Vector3(.15,.55,3.8))
			var camera: Camera3D = view_cameras[view]
			camera.position = center+basis*offset; camera.look_at(center); camera.make_current()
			if timing: continue
			label.text = "%s / %s / %s"%["BEFORE" if before else "AFTER",request.name.replace("_"," ").to_upper(),view.to_upper()]
			await process_frame; await RenderingServer.frame_post_draw
			var picture = root.get_texture().get_image()
			var folder = output+"/"+request.name+"_"+view
			DirAccess.make_dir_recursive_absolute(folder)
			picture.save_jpg(folder+"/%04d.jpg"%frame_index,.90)
			if frame_index%15==0: picture.save_png(folder+"/%04d.png"%frame_index)
		if timing: await physics_frame
		if frame_index%(60 if timing else 15)==0:
			captures.append({"frame":frame_index,"seconds":seconds,"phase":game.skier.animation.phase,"grounded":game.sim.grounded,"position":str(game.sim.position),"reserve":game.sim.impacts.reserve})
		if game.sim.crashed: failures.append(request.name+": "+game.sim.crash_reason); break
	measuring = false
	var row = {"scenario":request.name,"hops":hops,"landings":game.skier.animation.landing_events,"impact_speed_mps":max_impact,"airtime_s":game.sim.total_airtime,"crash":game.sim.crash_reason,"samples":captures}
	if not before:
		row.collision_events = game.skier.animation.collision_events
		row.minimum_clearance_margin_m = minimum_margin if is_finite(minimum_margin) else null
	evidence.append(row)
	print("REFINEMENT_NATIVE_CASE ",request.name," model=",game.sim.MODEL_VERSION," crash=",game.sim.crash_reason)

static func rock_fixture(surface, near: Vector3) -> Dictionary:
	# v11 rocks are exact mineral hulls, not the archived cylinder list. Find
	# a short reachable strike using the actual solver, shared by both variants.
	var entries: Array = surface.geology.collision.entries.duplicate()
	entries.sort_custom(func(a,b): return a.aabb.get_center().distance_squared_to(near)<b.aabb.get_center().distance_squared_to(near))
	for index in mini(100,entries.size()):
		var box: AABB = entries[index].aabb
		for direction in [Vector3.RIGHT,Vector3.LEFT,Vector3.BACK,Vector3.FORWARD]:
			var a: Vector3 = box.get_center()+direction*(maxf(box.size.x,box.size.z)*.5+4.0)
			a.y = surface.sample(a.x,a.z).height
			var b: Vector3 = box.get_center(); b.y = surface.sample(b.x,b.z).height
			var hit: Dictionary = surface.geology.collision.sweep(a,b)
			if hit.is_empty() or absf(hit.normal.y)>.7: continue
			var approach: Vector3 = -hit.normal.slide(Vector3.UP).normalized()
			var origin: Vector3 = hit.position-approach*2.5
			origin.y = surface.sample(origin.x,origin.z).height
			var yaw = atan2(approach.x,approach.z)+.30
			var probe = preload("res://scripts/core/ski_simulation.gd").new()
			probe.reset(origin,yaw); probe.prime_contacts(surface)
			probe.velocity = probe.support_basis().z*10.0
			for tick in 90:
				probe.step(DT,RiderInput.new(),surface)
				var contact: Dictionary = probe.obstacle_contact
				if not contact.is_empty():
					if contact.reason=="ROCK IMPACT" and contact.closing_speed_mps>3.0 and not probe.crashed:
						return {"origin":origin,"heading":yaw,"mineral":entries[index].id}
					break
	return {}

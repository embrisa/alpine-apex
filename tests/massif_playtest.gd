extends "res://tests/technical_showcase_playtest.gd"
const MassifPilot = preload("res://tests/massif_pilot.gd")
var face_index = 0
var mountain_seed = 849205174
var smoke = false
var view_face = -1
var capture_render_sources: Dictionary = {}
func run() -> void:
	if DisplayServer.get_name()=="headless": quit(1); return
	version = Definition.CURRENT_VERSION
	OUTPUT = "res://artifacts/geology_v11/native"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--version="): version = int(arg.get_slice("=",1))
		if arg.begins_with("--face="): face_index = clampi(int(arg.get_slice("=",1)),0,5)
		if arg.begins_with("--view-face="): view_face = clampi(int(arg.get_slice("=",1)),0,5)
		if arg.begins_with("--seed="): mountain_seed = int(arg.get_slice("=",1))
		if arg.begins_with("--side="): side = -1 if int(arg.get_slice("=",1))<0 else 1
		if arg.begins_with("--weather="): weather = arg.get_slice("=",1)
		if arg.begins_with("--benchmark-label="): OUTPUT = "res://artifacts/pc_environment/"+arg.get_slice("=",1).validate_filename()
		if arg.begins_with("--benchmark-start="): start_z = clampi(int(arg.get_slice("=",1)),0,2400)
		if arg.begins_with("--benchmark-end="): end_z = clampi(int(arg.get_slice("=",1)),2450,2850)
		if arg.begins_with("--benchmark-resolution="):
			var parts = arg.get_slice("=",1).split("x")
			if parts.size()==2: requested_pixels = Vector2i(int(parts[0]),int(parts[1]))
	views = "--views" in OS.get_cmdline_user_args()
	smoke = "--smoke" in OS.get_cmdline_user_args()
	pov_forest = "--pov-forest" in OS.get_cmdline_user_args()
	if views: capture_render_sources=preload("res://tests/geology_render_identity.gd").sources()
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	field = Definition.generate(mountain_seed,version)
	if field==null: quit(2); return
	set_meta("mountain_to_load",{"definition":Definition.from_field(field,"Default Mountain"),"field":field})
	game = load("res://main.tscn").instantiate()
	game.automated = true
	root.add_child(game)
	current_scene = game
	# Native validation can use the same staged uploads as normal startup.
	# _ready yields during those stages; one process frame does not mean ready.
	while not game.initialized or (game.loading and game.loading.busy):
		if views or smoke: Engine.max_fps=30
		await process_frame
	if views or smoke: Engine.max_fps=30
	await process_frame
	game.set_physics_process(false)
	game.skier.animation_enabled = "--skier-animation-off" not in OS.get_cmdline_user_args()
	game.effects.muted = true
	game.weather.set_preset(weather)
	game.start_run(false)
	game.summit_ready = false
	game.session.eligible = false
	game.display_settings.apply_display(root,requested_pixels)
	if views or smoke: Engine.max_fps=30
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	for i in 3: await process_frame
	await RenderingServer.frame_post_draw
	actual_pixels = root.get_texture().get_image().get_size()
	if actual_pixels!=requested_pixels: printerr("Wrong output pixels: ",actual_pixels); quit(2); return
	if smoke:
		place_on_face(face_index,950,true)
		for i in 600: await process_frame
		await capture("smoke_face_%d" % face_index)
		var smoke_result = {"pixels":[actual_pixels.x,actual_pixels.y],"fps_cap":Engine.max_fps,"video_bytes":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED),"face":face_index,"height_sha256":field.height_checksum,"obstacle_sha256":field.obstacle_checksum,"staged_loading":game.staged_loading,"frames":600,"unranked":not game.session.eligible}
		preload("res://tests/test_report.gd").write(OUTPUT+"/smoke.json",JSON.stringify(smoke_result,"\t"))
		print("GEOLOGY_SMOKE ",JSON.stringify(smoke_result))
	elif views:
		await inspect_massif()
		preload("res://tests/test_report.gd").write(OUTPUT+"/views.json",JSON.stringify({"version":version,"seed":mountain_seed,"height_sha256":field.height_checksum,"obstacle_sha256":field.obstacle_checksum,"display":game.display_settings.report(root,actual_pixels),"captures":inspection_captures,"view_face":view_face,"staged_loading":game.staged_loading,"unranked":not game.session.eligible,"render_source_sha256":capture_render_sources},"\t"))
	else: await descent()
	var exit_code = 0 if views or smoke or (not game.sim.crashed and (field.reached_base(game.sim.position) or local_z()>=end_z)) else 1
	game.queue_free()
	await process_frame
	quit(exit_code)

func local_z() -> float:
	return field.faces[face_index].to_local(Vector2(game.sim.position.x,game.sim.position.z)).y

func place_on_face(index: int,z: float,close: bool = false) -> void:
	var face = field.faces[index]
	var x: float = face.gully_x(z,side) if z<1850 else face.glade_x(z,side)
	var p: Vector2 = face.to_world(Vector2(x,z))
	game.sim.reset(Vector3(p.x,field.sample(p.x,p.y).height,p.y),face.heading)
	game.sim.prime_contacts(field)
	game.previous_position = game.sim.position
	game.skier.reset_animation(game.sim)
	game.camera.close_view = close
	game.camera.reset()
	game.effects.reset()

func inspect_massif() -> void:
	game.active = false
	# A single-face inspection avoids repeated mountain previews, long camera
	# tours and quality swaps. Solid placement and the complete world are unchanged.
	if view_face<0:
		game.hud.show_menu("title")
		await capture("startup")
		await game.mountain_library.open()
		await capture("library")
		game.mountain_library.close()
	if "--ui-only" in OS.get_cmdline_user_args(): return
	game.hud.hide_menu()
	game.hud.root.hide()
	var inspected_faces: Array = range(6) if view_face<0 else [view_face]
	for index in inspected_faces:
		for z in [600,950,1600,2170]:
			place_on_face(index,z)
			await capture("face_%d_%d_chase" % [index,z])
		place_on_face(index,820,true)
		await capture("face_%d_powder_pov" % index)
	var observer = Camera3D.new()
	game.add_child(observer)
	observer.far = 15000
	observer.make_current()
	for index in inspected_faces:
		var face = field.faces[index]
		var p: Vector2 = face.to_world(Vector2(0,1400))
		var focus = Vector3(p.x,field.sample(p.x,p.y).height,p.y)
		var offset: Vector2 = face.to_world(Vector2(1000,1100))
		observer.position = focus+Vector3(offset.x,1100,offset.y)
		observer.look_at(focus)
		await capture("face_%d_overview" % index)
	if "geology" in field:
		for condition in ["clear","snowfall"]:
			game.weather.set_preset(condition)
			for index in inspected_faces:
				for placed in field.geology.placements:
					var row: Dictionary=field.geology.catalog.records[placed.asset]
					if placed.face!=index or not row.category in ["cliffs","huge_boulders","large"]: continue
					var focus: Vector3=placed.pose.origin
					focus.y=field.sample(focus.x,focus.z).height+minf(12,row.size_m.y*.15)
					var direction: Vector3=placed.pose.basis.orthonormalized()*Vector3(.35,0,1)
					observer.position=focus+direction*maxf(25,row.size_m.x*.75)
					observer.position.y=field.sample(observer.position.x,observer.position.z).height+3.0
					observer.look_at(focus)
					await capture("mineral_face_%d_%s" % [index,condition])
					break
				for category in ["huge_boulders","large"]:
					for placed in field.geology.placements:
						var row: Dictionary=field.geology.catalog.records[placed.asset]
						if placed.face!=index or row.category!=category or placed.ice: continue
						var focus: Vector3=placed.pose.origin
						focus.y=field.sample(focus.x,focus.z).height+minf(10,row.size_m.y*.18)
						var direction=placed.pose.basis.orthonormalized()*Vector3(.35,0,1)
						observer.position=focus+direction*maxf(18,row.size_m.x*.85)
						observer.position.y=field.sample(observer.position.x,observer.position.z).height+3.0
						observer.look_at(focus)
						await capture("crag_face_%d_%s_%s" % [index,category,condition])
						break
			for placed in field.geology.placements:
				var row: Dictionary=field.geology.catalog.records[placed.asset]
				if not placed.ice or row.category!="large": continue
				if view_face>=0 and placed.face!=view_face: continue
				var focus: Vector3=placed.pose.origin
				focus.y=field.sample(focus.x,focus.z).height+2.0
				var direction=placed.pose.basis.orthonormalized()*Vector3(.3,0,1)
				observer.position=focus+direction*maxf(18,row.size_m.x*.9)
				observer.position.y=field.sample(observer.position.x,observer.position.z).height+2.0
				observer.look_at(focus)
				await capture("ice_face_%d_%s" % [placed.face,condition])
				observer.position=focus+placed.pose.basis.orthonormalized()*Vector3(25,60,70)
				observer.position.y=maxf(observer.position.y,field.sample(observer.position.x,observer.position.z).height+25)
				observer.look_at(focus+placed.pose.basis.orthonormalized()*Vector3(0,0,20))
				await capture("ice_join_face_%d_%s" % [placed.face,condition])
		game.weather.set_preset("clear")
		if view_face>=0:
			observer.queue_free()
			game.camera.make_current()
			return
		for quality in [0,1,2]:
			game.set_graphics_quality(quality)
			Engine.max_fps=30
			for placed in field.geology.placements:
				if placed.face!=0 or field.geology.catalog.records[placed.asset].category!="cliffs": continue
				var focus: Vector3=placed.pose.origin
				focus.y=field.sample(focus.x,focus.z).height+5.0
				observer.position=focus+placed.pose.basis.orthonormalized()*Vector3(20,0,65)
				observer.position.y=field.sample(observer.position.x,observer.position.z).height+2.0
				observer.look_at(focus)
				await capture("mineral_quality_%d" % quality)
				break
		for distance_m in [25,100,250]:
			for placed in field.geology.placements:
				if placed.face!=0 or field.geology.catalog.records[placed.asset].category!="cliffs": continue
				var focus: Vector3=placed.pose.origin
				focus.y=field.sample(focus.x,focus.z).height+5.0
				observer.position=focus+placed.pose.basis.orthonormalized()*Vector3(.3,0,1).normalized()*distance_m
				observer.position.y=field.sample(observer.position.x,observer.position.z).height+3.0
				observer.look_at(focus)
				await capture("mineral_distance_%d" % distance_m)
				break
	observer.queue_free()
	game.camera.make_current()
	for quality in [0,1,2]:
		game.set_graphics_quality(quality)
		Engine.max_fps=30
		game.weather.set_preset("snowfall")
		place_on_face(0,2170,true)
		await capture("forest_quality_%d" % quality)
	# Moving clips use actual solver input and include readback overhead; these
	# are visual evidence only, separate from the uncaptured performance run.
	game.active = true
	game.set_process(false)
	var clips: Array = []
	for z in [820,2170]:
		place_on_face(0,z)
		var face = field.faces[0]
		game.sim.velocity = Vector3(sin(face.heading),0,cos(face.heading)).slide(game.sim.surface_normal).normalized()*14
		for frame in 180:
			game.intent = MassifPilot.intent(game.sim,field,0,side)
			for tick in 2:
				game.sim.step(MassifPilot.DT,game.intent,field)
				game.skier.step_animation(MassifPilot.DT,game.sim,game.intent,field)
			game._process(1.0/60)
			await process_frame
			if frame in [30,90,179]: await capture("motion_%d_%d" % [z,frame],0)
		clips.append({"section_m":z,"crash":game.sim.crash_reason,"position":str(game.sim.position),"duration_s":3})
	preload("res://tests/test_report.gd").write(OUTPUT+"/motion.json",JSON.stringify({"clips":clips,"unranked":true,"capture_overhead":true},"\t"))

func descent() -> void:
	var face = field.faces[face_index]
	game.sim.reset(field.launch_point(face.heading),face.heading)
	game.sim.prime_contacts(field)
	if start_z>0: place_on_face(face_index,start_z)
	game.previous_position = game.sim.position
	game.camera.reset()
	for i in 120: await process_frame
	process_frame.connect(_measure)
	recording = true
	var ticks = 0
	var pilot_us: Array[float]=[]
	for i in 100000:
		ticks = i+1
		if i%12==0:
			var pilot_begin=Time.get_ticks_usec()
			game.intent = pilot_intent()
			pilot_us.append(Time.get_ticks_usec()-pilot_begin)
		if i%2400==0: print("MASSIF_PROGRESS face=",face_index," tick=",i," local_z=",snappedf(local_z(),.1)," kmh=",snappedf(game.sim.speed_kmh(),.1))
		await physics_frame
		var begin = Time.get_ticks_usec()
		game.sim.step(MassifPilot.DT,game.intent,game.world.ski_surface)
		if game.skier.animation_enabled: game.skier.step_animation(MassifPilot.DT,game.sim,game.intent,field)
		physics_us.append(Time.get_ticks_usec()-begin)
		game.session.elapsed += MassifPilot.DT
		if pov_forest: game.camera.close_view = local_z()>1900 and local_z()<2450
		if game.sim.crashed or field.reached_base(game.sim.position) or (end_z<2850 and local_z()>=end_z): break
	recording = false
	var result = {"generator_version":version,"seed":mountain_seed,"face":face_index,"side":side,"finished":field.reached_base(game.sim.position),"section_completed":field.reached_base(game.sim.position) or local_z()>=end_z,"scope":"full_descent" if start_z==0 and end_z==2850 else "section_probe","crash":game.sim.crash_reason,"seconds":ticks*MassifPilot.DT,"peak_kmh":game.sim.peak_speed*3.6,"height_sha256":field.height_checksum,"obstacle_sha256":field.obstacle_checksum,"engine":Engine.get_version_info().string,"device":RenderingServer.get_video_adapter_name(),"actual_pixels":[actual_pixels.x,actual_pixels.y],"display":game.display_settings.report(root,actual_pixels),"frame_ms":frame_timing(frames),"forest_frame_ms":frame_timing(forest_frames),"render_gpu_ms":timing(gpu_ms),"render_cpu_ms":timing(render_cpu_ms),"physics_step_us":timing(physics_us),"draw_calls":timing(draws),"peak_video_bytes":peak_video_bytes,"world_build_ms":game.world.generation_ms,"generation_ms":field.generation_ms,"cache_hit":field.cache_hit,"weather":weather,"warmup_frames":120,"capture_overhead_included":false,"unranked":not game.session.eligible}
	result.wilderness = game.world.wilderness.report() if game.world.wilderness else {}
	result.max_frame_ms=frames.max() if not frames.is_empty() else 0.0
	result.pilot_version=pilot_version()
	result.pilot_input_us=timing(pilot_us)
	preload("res://tests/test_report.gd").write(OUTPUT+"/native_%d_%s.json" % [side,weather],JSON.stringify(result,"\t"))
	print("MASSIF_NATIVE ",JSON.stringify(result))
	await capture("finish_face_%d_%s" % [face_index,weather])

func pilot_intent() -> RiderInput:
	return MassifPilot.intent(game.sim,field,face_index,side)

func pilot_version() -> int: return MassifPilot.VERSION

func _measure() -> void:
	var now = Time.get_ticks_usec()
	if recording and previous_recording and last_frame>0:
		frames.append((now-last_frame)/1000.0)
		if local_z()>1900 and local_z()<2450: forest_frames.append((now-last_frame)/1000.0)
		var gpu = RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid())
		var cpu = RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid())
		if gpu>0: gpu_ms.append(gpu)
		if cpu>0: render_cpu_ms.append(cpu)
		draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		peak_video_bytes = maxf(peak_video_bytes,Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED))
	previous_recording = recording
	last_frame = now

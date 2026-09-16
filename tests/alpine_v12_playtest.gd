extends "res://tests/massif_playtest.gd"
## All-face rendering and short actual-input skiing clips; no record eligibility.
const Survey = preload("res://tests/alpine_route_survey.gd")
const RegionPilot = preload("res://tests/alpine_v12_pilot.gd")
var surveyed_path: Array = []

func descent() -> void:
	var report_path = "res://artifacts/alpine_v12/survey_%d.json" % mountain_seed
	var data = JSON.parse_string(FileAccess.get_file_as_string(report_path)) if FileAccess.file_exists(report_path) else null
	if data!=null and data.height_sha256==field.height_checksum and data.obstacle_sha256==field.obstacle_checksum:
		surveyed_path = data.surveys[face_index].paths[0 if side<0 else 1]
	else:
		var survey = Survey.survey(field,face_index)
		surveyed_path = survey.paths[0 if side<0 else 1].map(func(p): return [p.x,p.y])
	if surveyed_path.is_empty(): printerr("No traversable surveyed descent for native test"); return
	await super.descent()

func pilot_intent() -> RiderInput:
	return RegionPilot.intent(game.sim,field,face_index,surveyed_path)

func pilot_version() -> int: return RegionPilot.VERSION

func place_on_face(index: int,z: float,close: bool = false) -> void:
	if surveyed_path.is_empty(): super.place_on_face(index,z,close); return
	var x = 0.0
	for i in range(1,surveyed_path.size()):
		if surveyed_path[i][1]<z: continue
		var a = surveyed_path[i-1]
		var b = surveyed_path[i]
		var span: float = b[1]-a[1]
		x = lerpf(a[0],b[0],clampf((z-a[1])/span,0,1)) if absf(span)>.001 else b[0]
		break
	var face = field.faces[index]
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
	game.set_process(false)
	game.hud.hide_menu()
	game.hud.root.hide()
	for source in ["scripts/world/generators/alpine_face_v12.gd","scripts/world/generators/alpine_massif_v12.gd","scripts/world/mountain_geology_v12.gd","scripts/world/heightfield_surface.gd","tests/alpine_v12_playtest.gd"]:
		capture_render_sources[source] = FileAccess.get_sha256("res://"+source)
	if "--terrain-benchmark" in OS.get_cmdline_user_args():
		await terrain_benchmark()
		return
	var observer = Camera3D.new()
	game.add_child(observer)
	observer.far = 15000
	var inspected: Array = range(6) if view_face<0 else [view_face]
	var sites: Array = []
	var forest_only = "--forest-only" in OS.get_cmdline_user_args()
	for index in inspected:
		var face = field.faces[index]
		var focus2: Vector2 = face.to_world(Vector2(0,1360))
		var focus = Vector3(focus2.x,field.sample(focus2.x,focus2.y).height,focus2.y)
		var offset: Vector2 = face.to_world(Vector2(1150,2150))
		observer.position = focus+Vector3(offset.x,1700,offset.y)
		observer.look_at(focus)
		observer.make_current()
		if not forest_only: await capture("face_%d_overview" % index)
		var woodland = forest_site(index)
		var woods_focus = Vector3(woodland.x,field.sample(woodland.x,woodland.y).height,woodland.y)
		var woods_offset: Vector2 = face.to_world(Vector2(150,130))
		observer.position = woods_focus+Vector3(woods_offset.x,150,woods_offset.y)
		observer.look_at(woods_focus)
		await capture("face_%d_forest_region" % index)
		observer.position = woods_focus+Vector3(0,2.0,0)
		var look: Vector2 = face.to_world(Vector2(35,65))
		observer.look_at(Vector3(woodland.x+look.x,field.sample(woodland.x+look.x,woodland.y+look.y).height+1.6,woodland.y+look.y))
		await capture("face_%d_forest_glade" % index)
		if forest_only: continue
		game.camera.make_current()
		for z in [780,1480,2220]:
			var target: Vector2 = face.to_world(Vector2(z*(-.22 if z==1480 else .25),z))
			var p = safe_site(target)
			game.sim.reset(Vector3(p.x,field.sample(p.x,p.y).height,p.y),face.heading)
			game.sim.prime_contacts(field)
			game.previous_position = game.sim.position
			game.skier.reset_animation(game.sim)
			game.camera.close_view = false
			game.camera.reset()
			game._process(0)
			await capture("face_%d_%d_ski" % [index,z])
			sites.append({"face":index,"section":z,"position":[p.x,p.y]})
	observer.queue_free()
	var clips: Array = []
	game.set_process(false)
	for site in sites:
		if site.section==1480 or not site.face in [0,3]: continue
		var p = Vector2(site.position[0],site.position[1])
		var face = field.faces[site.face]
		game.sim.reset(Vector3(p.x,field.sample(p.x,p.y).height,p.y),face.heading)
		game.sim.prime_contacts(field)
		game.sim.velocity = Vector3(sin(face.heading),0,cos(face.heading)).slide(game.sim.surface_normal).normalized()*12
		game.camera.reset()
		game.active = true
		var rendered_frames = 0
		for frame in 180:
			var input = RiderInput.new()
			input.brake = clampf((game.sim.speed_kmh()-48)/20,0,1)
			for tick in 2:
				game.sim.step(1.0/120,input,field)
				game.skier.step_animation(1.0/120,game.sim,input,field)
			game._process(1.0/60)
			await process_frame
			rendered_frames = frame+1
			if frame in [30,90,179]: await capture("motion_%d_%d_%d" % [site.face,site.section,frame],0)
			if game.sim.crashed: break
		clips.append({"face":site.face,"section":site.section,"crash":game.sim.crash_reason,"seconds":rendered_frames/60.0,"position":str(game.sim.position)})
	preload("res://tests/test_report.gd").write(OUTPUT+"/motion.json",JSON.stringify({"clips":clips,"sites":sites,"unranked":true,"capture_overhead":true},"\t"))
	if "--benchmark-after-views" in OS.get_cmdline_user_args(): await terrain_benchmark()

func safe_site(target: Vector2) -> Vector2:
	for ring in range(0,9):
		for i in 12:
			var p = target+Vector2.from_angle(i*TAU/12)*ring*12.0
			if field.rock_fraction_at(p.x,p.y)<.25 and field.contact_normal(p.x,p.y).y>.7 and Survey.clear_at(field,p,8): return p
	return target

func forest_site(index: int) -> Vector2:
	var face = field.faces[index]
	var chosen: Vector2 = face.to_world(Vector2(450,2200))
	var best = -1
	for passage in face.forest_passages:
		var q: Vector2 = passage.start.lerp(passage.finish,.5)+(passage.finish-passage.start).orthogonal().normalized()*passage.bend
		var p: Vector2 = safe_site(face.to_world(q))
		var trunks = 0
		for ob in field.obstacles:
			if Vector2(ob.position.x,ob.position.z).distance_squared_to(p)<70*70: trunks += 1
		if trunks>best and field.rock_fraction_at(p.x,p.y)<.35 and field.contact_normal(p.x,p.y).y>.72:
			best = trunks
			chosen = p
	return safe_site(chosen)

func terrain_benchmark() -> void:
	# Short, real-input ski samples distributed across all six faces. This is
	# representative traversal timing, not a full-descent or human-feel gate.
	Engine.max_fps = 120
	game.set_process(true)
	process_frame.connect(_measure)
	var segments: Array = []
	for index in 6:
		face_index = index
		var face = field.faces[index]
		for z in [900,2200]:
			var p = forest_site(index) if z==2200 else safe_site(face.to_world(Vector2(z*.25,z)))
			game.sim.reset(Vector3(p.x,field.sample(p.x,p.y).height,p.y),face.heading)
			game.sim.prime_contacts(field)
			game.skier.reset_animation(game.sim)
			game.previous_position = game.sim.position
			game.camera.reset()
			game.camera.close_view = false
			game.active = false
			for i in 120: await process_frame
			game.sim.velocity = Vector3(sin(face.heading),0,cos(face.heading)).slide(game.sim.surface_normal).normalized()*14
			game.active = true
			frames.clear(); gpu_ms.clear(); render_cpu_ms.clear(); physics_us.clear(); draws.clear()
			previous_recording = false
			recording = true
			var completed_ticks = 0
			for tick in 480:
				await physics_frame
				var input = RiderInput.new()
				input.brake = clampf((game.sim.speed_kmh()-48)/18,0,1)
				var begin = Time.get_ticks_usec()
				game.sim.step(1.0/120,input,game.world.ski_surface)
				game.skier.step_animation(1.0/120,game.sim,input,field)
				physics_us.append(Time.get_ticks_usec()-begin)
				completed_ticks = tick+1
				if game.sim.crashed: break
			recording = false
			segments.append({"face":index,"section_m":z,"seconds":completed_ticks/120.0,"crash":game.sim.crash_reason,"frame_ms":frame_timing(frames),"render_gpu_ms":timing(gpu_ms),"render_cpu_ms":timing(render_cpu_ms),"physics_step_us":timing(physics_us),"draw_calls":timing(draws)})
			print("ALPINE_TIMING_SEGMENT ",index," ",z," ",segments[-1].frame_ms)
	var result = {"scope":"twelve_four_second_ski_samples","generator_version":version,"seed":mountain_seed,"height_sha256":field.height_checksum,"obstacle_sha256":field.obstacle_checksum,"device":RenderingServer.get_video_adapter_name(),"actual_pixels":[actual_pixels.x,actual_pixels.y],"display":game.display_settings.report(root,actual_pixels),"segments":segments,"peak_video_bytes":peak_video_bytes,"world_build_ms":game.world.generation_ms,"warmup_frames_per_segment":120,"capture_overhead_included":false,"unranked":not game.session.eligible}
	result.source_sha256 = capture_render_sources
	preload("res://tests/test_report.gd").write(OUTPUT+"/terrain_timing.json",JSON.stringify(result,"\t"))

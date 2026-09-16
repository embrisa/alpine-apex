extends "res://tests/massif_playtest.gd"
## All-face rendering and short actual-input skiing clips; no record eligibility.
const Survey = preload("res://tests/alpine_v13_route_survey.gd")
const RegionPilot = preload("res://tests/alpine_v13_pilot.gd")
var surveyed_path: Array = []
var recorded_inputs: Array=[]
var input_trace_path=""
var comparison_sites: Dictionary = {}
var captured_sites: Dictionary = {}

func matched_site(label: String, fallback: Vector2) -> Vector2:
	var p=fallback
	if comparison_sites.has(label): p=Vector2(comparison_sites[label][0],comparison_sites[label][1])
	captured_sites[label]=[p.x,p.y]
	return p

func descent() -> void:
	var report_path = "res://artifacts/alpine_v13/survey_%d.json" % mountain_seed
	var data = JSON.parse_string(FileAccess.get_file_as_string(report_path)) if FileAccess.file_exists(report_path) else null
	if data!=null and data.height_sha256==field.height_checksum and data.obstacle_sha256==field.obstacle_checksum:
		surveyed_path = data.surveys[face_index].paths[0 if side<0 else 1]
	else:
		var survey = Survey.survey(field,face_index)
		surveyed_path = survey.paths[0 if side<0 else 1].map(func(p): return [p.x,p.y])
	if surveyed_path.is_empty(): printerr("No traversable surveyed descent for native test"); return
	# Successful headless inputs remove route-planning cost from frame timings.
	# The native game still executes every normal 120 Hz physics step and collision.
	input_trace_path="res://artifacts/alpine_v13/inputs_%d_%d.json" % [face_index,0 if side<0 else 1]
	if start_z==0 and FileAccess.file_exists(input_trace_path):
		var trace=JSON.parse_string(FileAccess.get_file_as_string(input_trace_path))
		if trace.result.finished and trace.result.crash.is_empty() and trace.height_sha256==field.height_checksum and trace.obstacle_sha256==field.obstacle_checksum and trace.model==game.sim.MODEL_VERSION and trace.simulation_sha256==FileAccess.get_sha256("res://scripts/core/ski_simulation.gd") and trace.tuning_sha256==FileAccess.get_sha256("res://config/ski_default.tres"):
			recorded_inputs=trace.commands
	await super.descent()
	var result_path=OUTPUT+"/native_%d_%s.json" % [side,weather]
	var result=JSON.parse_string(FileAccess.get_file_as_string(result_path))
	result.input_source="recorded ordinary input" if not recorded_inputs.is_empty() else "live test pilot"
	result.input_trace_sha256=FileAccess.get_sha256(input_trace_path) if not recorded_inputs.is_empty() else ""
	preload("res://tests/test_report.gd").write(result_path,JSON.stringify(result,"\t"))

func pilot_intent() -> RiderInput:
	var index=floori(float(game.sim.ticks)/12)
	if index<recorded_inputs.size():
		var command=recorded_inputs[index]
		var input=RiderInput.new()
		input.steer=command[0]; input.tuck=command[1]; input.brake=command[2]; input.jump=command[3]
		return input
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
	motion="--motion" in OS.get_cmdline_user_args()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--matched-sites="):
			var data=JSON.parse_string(FileAccess.get_file_as_string(arg.get_slice("=",1)))
			if not data is Dictionary: printerr("Missing matched-view sites"); quit(2); return
			comparison_sites=data
	game.active = false
	game.set_process(false)
	game.hud.hide_menu()
	game.hud.root.hide()
	for source in ["scripts/world/generators/alpine_face_v13.gd","scripts/world/generators/alpine_massif_v13.gd","scripts/world/mountain_geology_v13.gd","scripts/world/heightfield_surface.gd","tests/alpine_v13_playtest.gd"]:
		capture_render_sources[source] = FileAccess.get_sha256("res://"+source)
	for source in ["scripts/presentation/density_forest.gd","assets/graphics/pc_lod.gdshaderinc","assets/graphics/pc_forest_tree.gdshader","assets/graphics/pc_forest_shadow.gdshader","assets/graphics/pc_tree_impostor.gdshader","assets/graphics/trees/manifest.json","scripts/main.gd","scripts/core/ski_simulation.gd","config/ski_default.tres","scripts/presentation/skier_animation.gd","scripts/presentation/skier_full_motion.gd"]:
		capture_render_sources[source]=FileAccess.get_sha256("res://"+source)
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
		var woodland = matched_site("%d:woods" % index,forest_site(index))
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
			var p = matched_site("%d:%d" % [index,z],safe_site(target))
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
	preload("res://tests/test_report.gd").write(OUTPUT+"/view_sites.json",JSON.stringify(captured_sites,"\t"))
	if "--stills-only" in OS.get_cmdline_user_args():
		if "--benchmark-after-views" in OS.get_cmdline_user_args(): await terrain_benchmark()
		return
	var clips: Array = []
	Engine.max_fps=60 # Two 120 Hz simulation ticks per captured render frame.
	game.set_process(false)
	for site in sites:
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
			if frame%3==0: await capture("motion_%d_%d_%03d" % [site.face,site.section,frame],0)
			if game.sim.crashed: break
		clips.append({"face":site.face,"section":site.section,"crash":game.sim.crash_reason,"seconds":rendered_frames/60.0,"position":str(game.sim.position)})
	preload("res://tests/test_report.gd").write(OUTPUT+"/motion.json",JSON.stringify({"clips":clips,"sites":sites,"unranked":true,"capture_overhead":true,"capture_fps_cap":60,"saved_frames_per_simulation_second":20,"simulation_ticks_per_frame":2},"\t"))
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
		for id in field.nearby_obstacle_indices(Vector3(p.x,0,p.y),70):
			var tree_position: Vector3 = preload("res://scripts/world/obstacle_access.gd").position(field,id)
			if Vector2(tree_position.x,tree_position.z).distance_squared_to(p)<70*70: trunks += 1
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
			segments[-1].start_position=[p.x,p.y]
			if game.world.scenery.density_forest!=null:
				segments[-1].forest_rendering=game.world.scenery.density_forest.report()
			var mineral_node=game.world.minerals
			segments[-1].macro_texture_residency={"high_assets":mineral_node.high_macros.keys(),"macro_asset_count":mineral_node.macro_bounds.size(),"pending_updates":mineral_node.pending_macros.size()}
			segments[-1].crash_body_audit=crash_body_audit()
			if not segments[-1].crash_body_audit.ok: push_error("Native nearby crash bodies differ from scenery contracts")
			print("ALPINE_TIMING_SEGMENT ",index," ",z," ",segments[-1].frame_ms)
	var result = {"scope":"twelve_four_second_ski_samples","generator_version":version,"seed":mountain_seed,"height_sha256":field.height_checksum,"obstacle_sha256":field.obstacle_checksum,"device":RenderingServer.get_video_adapter_name(),"actual_pixels":[actual_pixels.x,actual_pixels.y],"display":game.display_settings.report(root,actual_pixels),"segments":segments,"peak_video_bytes":peak_video_bytes,"world_build_ms":game.world.generation_ms,"warmup_frames_per_segment":120,"capture_overhead_included":false,"unranked":not game.session.eligible}
	result.source_sha256 = capture_render_sources
	result.changed_sources=[]
	for source in capture_render_sources:
		if FileAccess.get_sha256("res://"+source)!=capture_render_sources[source]: result.changed_sources.append(source)
	result.trees=field.obstacles.size()
	result.minerals=field.geology.statistics
	preload("res://tests/test_report.gd").write(OUTPUT+"/terrain_timing.json",JSON.stringify(result,"\t"))

func crash_body_audit() -> Dictionary:
	# Outside measured frames: verify the populated world's actual native bodies.
	var crash=game.crash_collision
	var ok=true
	for id in field.nearby_obstacle_indices(crash.last_center,174.999):
		ok=ok and crash.obstacles.has(id)
	for id in crash.obstacles:
		var body=crash.obstacles[id]
		var ob=field.obstacles[id]
		var shape=body.get_child(0).shape
		ok=ok and is_equal_approx(shape.radius,ob.radius) and is_equal_approx(shape.height,ob.height)
		ok=ok and body.position.is_equal_approx(ob.position+Vector3.UP*ob.height*.5)
		ok=ok and body.collision_layer==8 and body.collision_mask==16 and body.get_meta("audio_material")==2
	return {"ok":ok,"trunk_bodies":crash.obstacles.size(),"mineral_bodies":crash.mineral_bodies.size()}

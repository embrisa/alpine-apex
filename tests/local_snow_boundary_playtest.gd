extends SceneTree
## Bounded current-Standard motion fixture. --scenario=boundary is synthetic;
## ride_glide/ride_carve use ordinary input and the unchanged fixed-step solver.
const Mountain = preload("res://tests/validation_mountain.gd")
const Definition = preload("res://scripts/world/mountain_definition.gd")
const InputFrame = preload("res://scripts/core/rider_input.gd")
const Frozen = "res://artifacts/orchestration_20260912/boundary/baseline/"
const Stats = preload("res://scripts/diagnostics/frame_costs.gd")
const Quality = preload("res://scripts/presentation/graphics_quality.gd")
const Route = preload("res://tests/local_snow_boundary_route.gd")
const Footprint = preload("res://scripts/world/mountain_footprint.gd")
# Explicit current-test provenance, not a relaxed general selection identity.
const V3_PRODUCER_SHA256 = "30e10690ea69cc1fc63944d89f65dc4d4a3b25e532a95b950376f9f2ad2c3923"
const REMAINING_CASES = [
	{"id":"low_sun", "scenario":"boundary", "preset":10, "deformation":"preset", "weather":"clear", "daylight":"dusk", "upscaler":"native"},
	{"id":"retained_edge", "scenario":"terrain_edge", "preset":10, "deformation":"preset", "weather":"clear", "daylight":"dusk", "upscaler":"native"},
	{"id":"overcast_on", "scenario":"boundary", "preset":4, "deformation":"on", "weather":"cloudy", "daylight":"day", "upscaler":"auto"},
	{"id":"overcast_carve", "scenario":"ride_carve", "preset":4, "deformation":"on", "weather":"cloudy", "daylight":"day", "upscaler":"auto"},
	{"id":"snow_reset", "scenario":"ride_glide", "preset":4, "deformation":"on", "weather":"cloudy", "daylight":"day", "upscaler":"auto"},
	{"id":"overcast_off", "scenario":"boundary", "preset":4, "deformation":"off", "weather":"cloudy", "daylight":"day", "upscaler":"auto"}
]
var game
var field
var observer: Camera3D
var output = "res://artifacts/local_snow_boundary"
var scenario = "boundary"
var reference = false
var timing = false
var seconds = 15.0
var preset = 7
var deformation = "preset"
var weather = "clear"
var daylight = "day"
var upscaler = "native"
var requested = Vector2i(1920,1080)
var fps = 30
var repeats = 1
var speed_kmh = 130.0
var start_xz = Vector2.INF
var heading_override = NAN
var rows: Array = []
var telemetry: Array = []
var failures: Array[String] = []
var sources: Dictionary = {}
var identity: Dictionary = {}
var phase = ""
var scenarios: Array[String] = []
var batch_output = ""
var batch_reports: Array = []
var batch_failures: Array[String] = []
var selection_path = ""
var selection_mode = ""
var selection: Dictionary = {}
var selection_sha256 = ""
var route_identity: Dictionary = {}
var weather_initial: Dictionary = {}
var movement_stats: Dictionary = {}
var last_sample: Dictionary = {}
var route_max_error_m = 0.0
var base_output = ""
var boundary_origin = Vector2.INF
var boundary_heading = NAN
var synthetic_speed = 130.0
var matrix = ""
var case_id = ""
var route_proof = false
var expected_selection_sha256 = ""
var edge_site: Dictionary = {}
var edge_rows = 0
var case_settings: Dictionary = {}
var snow_reset_stats: Dictionary = {}
var snow_gpu_reads: Array = []
var snow_gpu_ready = false
var snow_gpu_result: Dictionary = {}
var reset_budget: Dictionary = {}

func _initialize() -> void: call_deferred("run")

func run() -> void:
	if DisplayServer.get_name()=="headless": printerr("Native render required"); quit(2); return
	var args = OS.get_cmdline_user_args()
	timing = "--timing" in args; reference = "--reference" in args
	if timing: requested = Vector2i(3840,2160); upscaler = "auto"; fps = 120; repeats = 3; scenario = "ride_glide"
	if "--4k" in args: requested = Vector2i(3840,2160)
	for arg in args:
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		if arg.begins_with("--scenario="): scenario = arg.trim_prefix("--scenario=")
		if arg.begins_with("--scenarios="): scenario = arg.trim_prefix("--scenarios=")
		if arg.begins_with("--selection="): selection_path = arg.trim_prefix("--selection=")
		if arg.begins_with("--matrix="): matrix = arg.trim_prefix("--matrix=")
		if arg.begins_with("--route-proof="): selection_path = arg.trim_prefix("--route-proof="); route_proof = true; selection_mode = "reuse"
		if arg.begins_with("--route-proof-sha256="): expected_selection_sha256 = arg.trim_prefix("--route-proof-sha256=")
		if arg.begins_with("--selection-mode="): selection_mode = arg.trim_prefix("--selection-mode=")
		if arg.begins_with("--preset="): preset = int(arg.get_slice("=",1))
		if arg.begins_with("--deformation="): deformation = arg.get_slice("=",1)
		if arg.begins_with("--weather="): weather = arg.get_slice("=",1)
		if arg.begins_with("--daylight="): daylight = arg.get_slice("=",1)
		if arg.begins_with("--upscaler="): upscaler = arg.get_slice("=",1)
		if arg.begins_with("--seconds="): seconds = clampf(float(arg.get_slice("=",1)),1,30)
		if arg.begins_with("--speed-kmh="): speed_kmh = float(arg.get_slice("=",1))
		if arg.begins_with("--repeats="): repeats = clampi(int(arg.get_slice("=",1)),1,3)
		if arg.begins_with("--origin="):
			var coords = arg.get_slice("=",1).split(","); start_xz = Vector2(float(coords[0]),float(coords[1]))
		if arg.begins_with("--heading="): heading_override = float(arg.get_slice("=",1))
	if not matrix.is_empty():
		if matrix!="remaining" or timing or seconds!=15.0 or repeats!=1 or not route_proof:
			printerr("--matrix=remaining requires a pinned --route-proof, 15-second visuals and one repeat"); quit(2); return
		scenario = "boundary,terrain_edge,ride_carve,ride_glide"
	if route_proof and (expected_selection_sha256.length()!=64 or FileAccess.get_sha256(selection_path)!=expected_selection_sha256 or (timing and scenario!="ride_glide")):
		printerr("Route proof requires its exact SHA-256; selected timing is glide only"); quit(2); return
	for item in scenario.split(",",false):
		var name = item.strip_edges()
		if name in scenarios or name not in ["boundary","ride_glide","ride_carve","terrain_edge"] or (timing and name in ["boundary","terrain_edge"]):
			printerr("Choose unique boundary/terrain_edge visual or ride_glide/ride_carve scenarios"); quit(2); return
		scenarios.append(name)
	if scenarios.is_empty(): printerr("Empty scenario list"); quit(2); return
	var ordinary_batch = scenarios.size()>1 and ("ride_glide" in scenarios or "ride_carve" in scenarios)
	if ordinary_batch and (selection_path.is_empty() or selection_mode not in ["create","reuse"] or seconds!=15.0):
		printerr("Ordinary batch requires --seconds=15 --selection=<shared.json> --selection-mode=create|reuse; ordinary initial speed is 60 km/h"); quit(2); return
	if not selection_path.is_empty():
		if selection_mode not in ["create","reuse"] or seconds!=15.0:
			printerr("Route selection requires create/reuse and 15 seconds"); quit(2); return
		if (selection_mode=="create" and FileAccess.file_exists(selection_path)) or (selection_mode=="reuse" and not FileAccess.file_exists(selection_path)):
			printerr("Selection create must be fresh; reuse must exist: "+selection_path); quit(2); return
	if scenarios.size()==1 and scenarios[0].begins_with("ride_") and not selection_path.is_empty(): speed_kmh = Route.RIDE_SPEED_KMH
	base_output = output; synthetic_speed = speed_kmh
	if not matrix.is_empty():
		batch_output = output+("/before_remaining_matrix" if reference else "/after_remaining_matrix")
		output = batch_output
	elif scenarios.size()>1:
		batch_output = output+"/%s_batch_q%d_%s_%s_%s_%s_%s"%["before" if reference else "after",preset,deformation,upscaler,weather,daylight,"timing" if timing else "motion"]
		output = batch_output
	else: output = scenario_output(scenarios[0],speed_kmh)
	if not fresh_directory(output): quit(2); return
	field = Mountain.load_standard()
	if field==null: quit(2); return
	set_meta("mountain_to_load",{"definition":Definition.from_field(field,"Local snow boundary fixture"),"field":field})
	game = instantiate_fixture_game()
	if game==null: printerr("Fixture scene setup failed: ",failures); quit(2); return
	game.automated = true
	root.add_child(game); current_scene = game
	while not game.initialized or (game.loading and game.loading.busy): await process_frame
	game.set_process(false); game.set_physics_process(false)
	game.session.record_directory = output+"/isolated_records"
	game.session.benchmark_path = output+"/isolated_benchmark.json"
	game.start_run(false); game.summit_ready = false; game.active = true; game.session.eligible = false
	game.effects.muted = true; game.hud.hide(); game.hud.hide_menu()
	game.weather.set_preset(weather); game.weather.set_time_of_day(daylight)
	game.weather.set_automatic(false); game.weather.set_time_cycle(false)
	game.set_graphics_preset(preset)
	if reference: await install_reference()
	if not failures.is_empty(): await finish(); return
	var profile = Quality.numbered(preset)
	if deformation!="preset": profile.snow_local_deformation = deformation=="on"
	game.effects.powder_surface.apply_quality(profile)
	game.display_settings.display_mode = "windowed"
	game.display_settings.upscaler = upscaler; game.display_settings.render_scale = .75 if upscaler!="native" else 1.0
	game.display_settings.frame_generation = false; game.display_settings.fps_limit = fps
	game.display_settings.terrain_gi = false; game.world.environment.sdfgi_enabled = false
	game.display_settings.apply_display(root,requested); game.display_settings.apply_viewport(root)
	root.content_scale_size = requested
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	game.frame_costs.enabled = timing
	observer = Camera3D.new(); observer.fov = 65; observer.far = 15000; game.add_child(observer)
	if not start_xz.is_finite(): start_xz = choose_site()
	boundary_origin = start_xz; boundary_heading = heading_override
	# Snapshot once, then restore the same weather clock at each independent case.
	game.weather.seed_stream(field.seed_value)
	weather_initial = game.weather.snapshot()
	for key in ["visual_time","active_seconds","free_seconds","phase_seconds","cloud_x","cloud_z","race_elapsed"]: weather_initial[key] = 0.0
	weather_initial.cloud_offset = Vector2.ZERO
	sources = source_hashes()
	if not selection_path.is_empty(): prepare_selection()
	for failure in failures: batch_failures.append("setup: "+failure)
	var case_plan = REMAINING_CASES.duplicate(true) if not matrix.is_empty() else []
	if case_plan.is_empty():
		for name in scenarios: case_plan.append({"id":name,"scenario":name})
	for spec in case_plan:
		scenario = spec.scenario; case_id = spec.id; rows = []; telemetry = []; failures = []; edge_site = {}
		if not matrix.is_empty(): profile = configure_matrix_case(spec)
		start_xz = boundary_origin; heading_override = boundary_heading; speed_kmh = synthetic_speed
		if scenario=="terrain_edge":
			edge_site = choose_retained_edge()
			if edge_site.is_empty(): fail_once("No valid retained-terrain edge found; terrain_edge coverage missing")
			else: start_xz = Vector2(edge_site.origin[0],edge_site.origin[1])
		if scenario.begins_with("ride_") and not selection_path.is_empty():
			if selection.get("selected",{}).is_empty():
				output = scenario_output(scenario,Route.RIDE_SPEED_KMH)
				var skipped = {"scenario":scenario,"output":output,"skipped":true,"reason":"No valid shared preflight selection",
					"failures":["Missing ordinary coverage: no valid shared preflight route"],"missing_coverage":selection.get("missing_coverage",[])}
				if batch_output.is_empty() or fresh_directory(output): write_json(output+"/results.json",skipped)
				batch_reports.append(skipped)
				continue
			var chosen: Dictionary = selection.selected
			start_xz = Vector2(chosen.origin[0],chosen.origin[1]); heading_override = chosen.heading
			speed_kmh = Route.RIDE_SPEED_KMH
		case_settings = settings_identity(profile)
		output = scenario_output(scenario,speed_kmh)
		if not batch_output.is_empty() and not fresh_directory(output):
			batch_failures.append("Refused existing scenario output: "+output); break
		game.session.record_directory = output+"/isolated_records"
		game.session.benchmark_path = output+"/isolated_benchmark.json"
		for repeat in repeats:
			if scenario=="terrain_edge" and edge_site.is_empty(): break
			if timing: await run_case(repeat,true,profile)
			await run_case(repeat,false,profile)
			if not failures.is_empty(): break
		if sources!=source_hashes(): failures.append("Source changed during capture/timing")
		await write_report()
		batch_reports.append({"id":case_id,"scenario":scenario,"output":output,"cases":rows.duplicate(true),"failures":failures.duplicate()})
		for failure in failures: batch_failures.append(scenario+": "+failure)
	if not selection_path.is_empty() and route_identity!=Route.physical_identity(field,game.world.ski_surface,game.sim.tuning,fps):
		batch_failures.append("Physics/terrain/prop identity changed during batch")
	if not selection_sha256.is_empty() and FileAccess.get_sha256(selection_path)!=selection_sha256:
		batch_failures.append("Shared selection artifact changed during batch")
	if not batch_output.is_empty():
		if not write_json(batch_output+"/batch_results.json",{"world_loads":1,"matrix":matrix,"case_plan":case_plan,"scenarios":scenarios,"reports":batch_reports,"failures":batch_failures,
			"selection":selection_path,"selection_sha256":selection_sha256,"missing_coverage":selection.get("missing_coverage",[]),"sources":sources,
			"scope":"One cached Standard world; isolated scenario resets. Capture metrics do not establish frame-time or artistic acceptance."}):
			batch_failures.append("Could not save batch report")
	game.effects.stop_audio(); game.queue_free(); await process_frame
	quit(0 if batch_failures.is_empty() else 1)

func choose_site() -> Vector2:
	var site: Vector2 = field.faces[3].to_world(Vector2(120,650))
	for i in 81:
		var p = site+Vector2((i%9)-4,(i/9)-4)*16.0
		if field.rock_fraction_at(p.x,p.y)>.1 or field.contact_normal(p.x,p.y).y<.7: continue
		if field.nearby_obstacle_indices(Vector3(p.x,field.sample(p.x,p.y).height,p.y),20).is_empty(): return p
	return site

func reset_case() -> void:
	var n: Vector3 = game.world.ski_surface.contact_normal(start_xz.x,start_xz.y)
	var heading = heading_override if is_finite(heading_override) else atan2(n.x,n.z)
	Route.initialize_sim(game.sim,game.world.ski_surface,start_xz,heading,speed_kmh)
	game.intent = InputFrame.new()
	game.previous_position = game.sim.position; game.effects.reset(); game.skier.reset_animation(game.sim); game.camera.reset()
	game.session.elapsed = 0.0; game.session.previous_elapsed = 0.0
	game.weather.restore(weather_initial)
	movement_stats = {}; last_sample = {}; route_max_error_m = 0.0; edge_rows = 0
	snow_reset_stats = {}; snow_gpu_reads = []; reset_budget = {}
	game.active = true; game.session.eligible = false; game.camera.make_current(); game._process(0)
	game.display_settings.reset_history(); phase = ""

func run_case(repeat: int, warmup: bool, profile) -> void:
	game.effects.powder_surface.apply_quality(profile)
	reset_case()
	for frame in 90: await process_frame
	game.frame_costs.reset()
	var previous_budget: Dictionary = game.effects.powder_surface.budget()
	var fsr_before: Dictionary = game.display_settings.fsr_status()
	var physics_trace = PackedFloat64Array()
	var frame_ms = PackedFloat64Array(); var cpu_ms = PackedFloat64Array(); var gpu_ms = PackedFloat64Array()
	var update_ms = PackedFloat64Array(); var video_peak = 0.0
	var controls = InputFrame.new(); controls.tuck = .2
	var duration = 3.0 if warmup else seconds
	var count = roundi(duration*fps)
	var last_us = Time.get_ticks_usec()
	var captures = output+"/frames_%02d"%repeat
	if not timing and not warmup and not fresh_directory(captures): fail_once("Capture directory was not fresh"); return
	var completed = 0
	for frame in count:
		var t = float(frame)/fps
		var started = Time.get_ticks_usec()
		if case_id=="snow_reset" and not timing: update_snow_reset_phase(frame,profile)
		if scenario in ["boundary","terrain_edge"]: synthetic_frame(t,profile)
		else:
			if case_id!="snow_reset": phase = scenario
			controls = Route.controls_at(scenario,t)
			for tick in 120/fps:
				game.previous_position = game.sim.position
				game.sim.step(1.0/120.0,controls,game.world.ski_surface)
				game.skier.step_animation(1.0/120.0,game.sim,controls,field)
			game.intent = controls; game._process(1.0/fps)
			if not warmup and not selection.get("selected",{}).is_empty(): verify_route_frame(frame)
		update_ms.append((Time.get_ticks_usec()-started)/1000.0)
		await process_frame
		var now = Time.get_ticks_usec()
		frame_ms.append((now-last_us)/1000.0); last_us = now
		cpu_ms.append(RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()))
		gpu_ms.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
		video_peak = maxf(video_peak,Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED))
		if timing and not warmup:
			var p: Vector3 = game.sim.position
			var v: Vector3 = game.sim.velocity
			physics_trace.append_array(PackedFloat64Array([p.x,p.y,p.z,v.x,v.y,v.z,game.sim.heading,float(game.sim.grounded),game.sim.ticks]))
		if not timing and not warmup:
			await RenderingServer.frame_post_draw
			if root.get_texture().get_image().save_jpg(captures+"/%05d.jpg"%frame,.96)!=OK: fail_once("Could not save capture")
			var budget_now: Dictionary = game.effects.powder_surface.budget()
			if scenario in ["boundary","terrain_edge"]: verify_synthetic_sample(budget_now,profile)
			var edge_sample = verify_edge_sample() if scenario=="terrain_edge" else {}
			var render_control = inspect_render_control()
			var snow_sample = verify_snow_reset_frame(frame,budget_now) if case_id=="snow_reset" else {}
			if case_id=="snow_reset" and frame in [14,29,30,59]: await capture_snow_gpu(frame,budget_now)
			var ski_rows: Array = []
			for i in 2:
				var ski = game.sim.skis[i]
				ski_rows.append({"p":Route.v3(ski.position),"grounded":ski.grounded,"load_n":ski.load_n,"edge_angle":ski.edge_angle,
					"rock":game.world.ski_surface.rock_fraction_at(ski.position.x,ski.position.z),"snow_depth_m":ski.snow_depth,
					"response":game.effects.responses[i].report(),"rendered_contact":Route.v3(game.effects.responses[i].contact_position),
					"rendered_forward":Route.v3(game.effects.responses[i].contact_forward),"live_active":game.effects.snow_tracks.live_active[i]})
			telemetry.append({"repeat":repeat,"frame":frame,"seconds":t,"phase":phase,"p":str(game.sim.position),"rendered_p":str(game.skier.global_position),
				"p_xyz":Route.v3(game.sim.position),"rendered_xyz":Route.v3(game.skier.global_position),"velocity":Route.v3(game.sim.velocity),
				"heading":game.sim.heading,"speed_kmh":game.sim.speed_kmh(),"steer":controls.steer,"grounded":game.sim.grounded,"skis":ski_rows,
				"powder":budget_now,"render_control":render_control,"snow_reset":snow_sample,"edge_geometry":edge_sample,"live_gpu_strokes":Array(game.effects.snow_tracks.live_gpu_strokes()),
				"material_patch":Route.material_probe(game.world.ski_surface,game.skier.global_position)})
		completed += 1
		if game.sim.crashed and scenario.begins_with("ride_"):
			failures.append("Bounded solver ride ended early: "+game.sim.crash_reason); break
	if warmup: return
	if scenario=="boundary" and not timing: verify_synthetic_coverage(profile)
	if scenario=="terrain_edge" and not timing:
		if edge_rows!=count: fail_once("Incomplete retained-edge geometry coverage")
		if seconds==15.0 and not reference and profile.snow_local_deformation and movement_stats.get("terrain_edge",{}).get("storage_moves",0)<2:
			fail_once("Vacuous retained-edge recenter coverage")
	if case_id=="snow_reset": verify_snow_reset_coverage()
	var temporal = verify_temporal(fsr_before)
	var budget: Dictionary = game.effects.powder_surface.budget()
	rows.append({"repeat":repeat,"simulated_seconds":float(completed)/fps,"ticks":completed*(120/fps),"stop":"duration" if completed==count else "crash",
		"frame_ms":Stats.stats(frame_ms) if timing else {},"cpu_ms":Stats.stats(cpu_ms) if timing else {},"gpu_ms":Stats.stats(gpu_ms) if timing else {},
		"update_ms":Stats.stats(update_ms) if timing else {},"video_peak_bytes":video_peak,"budget":budget,
		"dispatch_delta":budget.dispatch_frames-previous_budget.dispatch_frames,"upload_bytes_delta":budget.uploaded_bytes-previous_budget.uploaded_bytes,
		"support_upload_delta":budget.get("support_uploaded_bytes",0)-previous_budget.get("support_uploaded_bytes",0),"frame_scopes":game.frame_costs.report(),
		"counter_baseline":previous_budget,"counter_delta":counter_delta(previous_budget,budget),"movement":movement_stats,
		"temporal":temporal,"snow_reset":snow_reset_stats,"snow_gpu_reads":snow_gpu_reads,"settings_sha256":JSON.stringify(case_settings,"",true,true).sha256_text(),
		"physics_trace_sha256":Route.digest(physics_trace.to_byte_array()) if timing else "", "physics_trace_samples":physics_trace.size()/9,
		"warmup_seconds":3.0 if timing else 0.0,"center_validation":"unavailable_in_before_budget" if reference else ("active" if profile.snow_local_deformation else "not_applicable_deformation_off"),
		"route_trace_max_error_m":route_max_error_m,"capture_count":completed if not timing else 0,
		"solver_ticks":game.sim.ticks if scenario.begins_with("ride_") else 0,"synthetic_pose_samples":completed if scenario in ["boundary","terrain_edge"] else 0})
	print("LOCAL_SNOW_BOUNDARY_CASE ",JSON.stringify(rows[-1]))

func synthetic_frame(t: float, profile) -> void:
	var offset = Vector2.ZERO
	var next_phase = "hold"
	if t>=1 and t<4: offset = Vector2((t-1)*4,0); next_phase = "x_thresholds"
	elif t>=4 and t<7: offset = Vector2(12,(t-4)*4); next_phase = "z_thresholds"
	elif t>=7 and t<9: offset = Vector2(12,12)+Vector2.ONE*(t-7)*35; next_phase = "fast_diagonal"
	elif t>=9 and t<10.5: offset = Vector2(82,82)+Vector2.ONE*sin((t-9)*TAU*2)*2.2; next_phase = "threshold_reversal"
	elif t>=10.5 and t<11.5: offset = Vector2(82,82); next_phase = "air_landing"
	elif t>=11.5 and t<12.5: offset = Vector2(-40,-40); next_phase = "teleport_hold"
	elif t>=12.5 and t<13.5: offset = Vector2(-40,-40); next_phase = "deformation_off"
	elif t>=13.5: offset = Vector2(-40,-40)+Vector2(t-13.5,0)*4; next_phase = "deformation_restored"
	if scenario=="terrain_edge":
		var inward = Vector2(edge_site.inward[0],edge_site.inward[1])
		var tangent = inward.orthogonal()
		offset = tangent*sin(t*.8)*8.0+inward*sin(t*1.1)*3.0
		next_phase = "terrain_edge"
	if next_phase!=phase:
		if next_phase=="teleport_hold": game.effects.reset(); game.camera.reset(); game.display_settings.reset_history()
		if next_phase in ["deformation_off","deformation_restored"]:
			var q = profile.duplicate(); q.snow_local_deformation = next_phase=="deformation_restored" and profile.snow_local_deformation
			game.effects.powder_surface.apply_quality(q)
		phase = next_phase
	var xz = start_xz+offset
	var p = Vector3(xz.x,field.sample(xz.x,xz.y).height,xz.y)
	var normal: Vector3 = field.contact_normal(p.x,p.z)
	var forward = Vector3.BACK.slide(normal).normalized()
	var right = normal.cross(forward).normalized()
	var airborne = scenario!="terrain_edge" and t>=10.5 and t<11.0
	if airborne: p.y += sin((t-10.5)*TAU)*1.5
	var sim = game.sim
	var movement: Vector3 = (p-sim.position)*fps
	if phase in ["hold","teleport_hold","deformation_off"] or movement.length()>100: movement = Vector3.ZERO
	sim.position = p; game.previous_position = p; sim.surface_normal = normal; sim.ski_forward = forward
	sim.heading = atan2(forward.x,forward.z); sim.velocity = movement
	sim.grounded = not airborne; sim.crashed = false; sim.edge_angle = .35; sim.slip_angle = .03; sim.normal_load = 9.81
	for ski in sim.skis:
		ski.position = p+right*ski.side*.24; ski.previous_position = ski.position
		ski.normal = normal; ski.forward = forward; ski.grounded = not airborne
		ski.load_n = 500 if not airborne else 0; ski.grip_n = ski.load_n*.65; ski.edge_angle = .35; ski.slip_angle = .03
		ski.snow_depth = field.snow_depth_at(ski.position.x,ski.position.z); ski.penetration = .06
		ski.orientation = Basis(right,normal,forward); ski.previous_orientation = ski.orientation
	sim.body._pose(sim,1.0/fps); sim.body.pose_frame = Transform3D(sim.support_basis(),p)
	sim.body.previous_pose_frame = sim.body.pose_frame; sim.body.previous_joints = sim.body.joints.duplicate(); sim.body.previous_rotations = sim.body.rotations.duplicate()
	sim.facing_pose.capture(sim,true)
	game._process(1.0/fps)
	if game.skier.global_position.distance_to(p)>.001:
		failures.append("Synthetic rendered rider did not follow the completed pose at "+str(t))
	observer.position = p-forward*8-right*3+Vector3.UP*4
	observer.look_at(p+forward*8); observer.make_current()
	if scenario=="terrain_edge":
		var inward = Vector3(edge_site.inward[0],0,edge_site.inward[1])
		observer.position = p+inward*9+Vector3.UP*6
		observer.look_at(p-inward*7)

func install_reference() -> void:
	# Frozen CURRENT source, never an older snow-contact baseline. Resource paths
	# are rewritten only inside ignored output. The reset adapter supplies the
	# new lifecycle call without changing the old visual/update implementation.
	if not FileAccess.file_exists(Frozen+"manifest.json"):
		failures.append("Missing frozen current-source baseline"); return
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Frozen+"manifest.json"))
	var target = output+"/reference_resources/"
	for path in manifest.sha256:
		if FileAccess.get_sha256(Frozen+path)!=manifest.sha256[path]: failures.append("Baseline hash mismatch: "+path); return
	for path in manifest.sha256:
		var source = FileAccess.get_file_as_string(Frozen+path)
		for dependency in manifest.sha256: source = source.replace("res://"+dependency,target+dependency)
		if path=="scripts/presentation/powder_surface.gd":
			source += "\nfunc reset() -> void:\n\tlast_revision = -1\n\tcenter = Vector2.INF\n\t_visibility(false)\n"
		DirAccess.make_dir_recursive_absolute((target+path).get_base_dir())
		FileAccess.open(target+path,FileAccess.WRITE).store_string(source)
	game.effects.powder_surface.queue_free(); await process_frame; await process_frame
	for material in [game.world.snow_material,game.effects.snow_tracks.material]:
		var original: String = material.shader.resource_path.trim_prefix("res://")
		material.shader = load(target+original)
	var previous = load(target+"scripts/presentation/powder_surface.gd").new()
	game.effects.add_child(previous); game.effects.powder_surface = previous
	previous.bind(game.effects.snow_tracks,game.world,game.graphics)
	var deadline = Time.get_ticks_msec()+10000
	while not previous.available and Time.get_ticks_msec()<deadline: await process_frame
	if not previous.available: failures.append("Reference powder GPU did not initialize")
	identity.baseline = manifest

func source_hashes() -> Dictionary:
	var result = {}
	for path in ["scripts/main.gd","scripts/core/ski_simulation.gd","scripts/presentation/powder_surface.gd","scripts/presentation/snow_tracks.gd","scripts/presentation/snow_response.gd","scripts/presentation/speed_effects.gd",
		"assets/graphics/powder_surface.gdshader","assets/graphics/powder_surface.gdshaderinc","assets/graphics/alpine_surface_fragment.gdshaderinc","assets/graphics/powder_compute.gd","tests/local_snow_boundary_playtest.gd","tests/local_snow_boundary_route.gd","scripts/world/mountain_footprint.gd","scripts/presentation/pc_graphics_settings.gd","scripts/presentation/graphics_presets.gd","scripts/presentation/weather_controller.gd","config/weather/cloudy.tres"]:
		result[path] = FileAccess.get_sha256("res://"+path)
	if not timing:
		result.merge(shader_closure(["res://assets/graphics/alpine_surface.gdshader","res://assets/graphics/powder_surface.gdshader","res://assets/graphics/ski_track.gdshader"]))
		result["main.tscn"] = FileAccess.get_sha256("res://main.tscn")
	return result

func write_report() -> void:
	await RenderingServer.frame_post_draw
	# Timing performs no GPU image readback, even outside measured frames.
	var actual = root.size if timing else root.get_texture().get_image().get_size()
	if actual!=requested: failures.append("Output pixel mismatch")
	if game.session.eligible or game.preferences_enabled: failures.append("Fixture lost record/preference isolation")
	if not timing:
		identity.loaded_shader_closure = shader_closure([game.world.snow_material.shader.resource_path,game.effects.powder_surface.material.shader.resource_path,game.effects.snow_tracks.material.shader.resource_path])
		identity.loaded_powder_script_sha256 = FileAccess.get_sha256(game.effects.powder_surface.get_script().resource_path)
		var compute_path = game.effects.powder_surface.get_script().resource_path.replace("scripts/presentation/powder_surface.gd","assets/graphics/powder_compute.gd")
		identity.loaded_compute_source = {"path":compute_path,"sha256":FileAccess.get_sha256(compute_path)}
		identity.material_scope = "Frozen original material/compute closure versus current; fixed interpolation is not pixel-identical material provenance. No crystal substitution."
	var report = {"reference":reference,"scenario":scenario,"case_id":case_id,"matrix":matrix,"synthetic":scenario in ["boundary","terrain_edge"],"timing":timing,"capture_in_timing":false,
		"unranked":not game.session.eligible,"personal_preferences_enabled":game.preferences_enabled,"seed":field.seed_value,"generator":Definition.CURRENT_VERSION,
		"height_sha256":field.height_checksum,"cache_hit":field.cache_hit,"origin":str(start_xz),"heading_override":str(heading_override),"speed_kmh":speed_kmh,
		"engine":Engine.get_version_info(),"engine_sha256":FileAccess.get_sha256(OS.get_executable_path()),"device":RenderingServer.get_video_adapter_name(),"driver":RenderingServer.get_current_rendering_driver_name(),
		"display":game.display_settings.report(root,actual),"sources":sources,"identity":identity,"cases":rows,"telemetry":telemetry,"failures":failures,
		"selection":selection_path,"selection_sha256":selection_sha256,"route_proof":route_proof,"missing_coverage":selection.get("missing_coverage",[]),
		"settings_identity":case_settings,"edge_site":edge_site,"start_xz":[start_xz.x,start_xz.y],
		"physics_terrain_identity":route_identity,"imported_producer_sha256":V3_PRODUCER_SHA256 if route_proof else "",
		"pixel_verification":"Window size, no image readback" if timing else "Captured image size",
		"scope":"Bounded scenario only. No full-descent performance or human/controller acceptance. Chronological captures require visual review."}
	write_json(output+"/results.json",report)
	print("LOCAL_SNOW_BOUNDARY_RENDER ",output," failures=",failures)

func finish() -> void:
	await write_report()
	game.effects.stop_audio(); game.queue_free(); await process_frame
	quit(0 if failures.is_empty() else 1)

func scenario_output(name: String, speed: float) -> String:
	var directory = batch_output if not batch_output.is_empty() else base_output
	return directory+"/%s_%s_q%d_%s_%s_%s_%s_%dkmh_%s"%["before" if reference else "after",name,preset,deformation,upscaler,weather,daylight,roundi(speed),"timing" if timing else "motion"]

func fresh_directory(path: String) -> bool:
	if DirAccess.dir_exists_absolute(path) or FileAccess.file_exists(path):
		printerr("Refusing to overwrite existing output: "+path); return false
	var error = DirAccess.make_dir_recursive_absolute(path)
	if error!=OK: printerr("Could not create output: "+path+" error="+str(error)); return false
	return true

func write_json(path: String, data: Dictionary) -> bool:
	if FileAccess.file_exists(path):
		fail_once("Refusing to overwrite "+path); return false
	var error = DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if error!=OK: fail_once("Cannot create report directory "+path); return false
	var file = FileAccess.open(path,FileAccess.WRITE)
	if file==null: fail_once("Cannot write "+path); return false
	file.store_string(JSON.stringify(data,"\t",true,true)); file.flush()
	if file.get_error()!=OK: fail_once("Incomplete report "+path); return false
	return true

func prepare_selection() -> void:
	if route_proof: prepare_route_proof(); return
	route_identity = Route.physical_identity(field,game.world.ski_surface,game.sim.tuning,fps)
	if selection_mode=="create":
		selection = Route.select(field,game.world.ski_surface,game.sim.tuning,boundary_origin,fps)
		selection.physics_terrain_identity = route_identity
		selection.boundary_origin = [boundary_origin.x,boundary_origin.y]
		selection.boundary_heading = boundary_heading if is_finite(boundary_heading) else null
		if not write_json(selection_path,selection):
			batch_failures.append("Could not save fresh route selection"); selection = {}; return
	else:
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(selection_path))
		if not parsed is Dictionary or parsed.get("schema",-1)!=Route.VERSION or parsed.get("physics_terrain_identity",{})!=route_identity or not Route.valid_selection(parsed,fps):
			batch_failures.append("Shared route selection schema/physics/terrain/prop identity mismatch"); return
		selection = parsed
		boundary_origin = Vector2(selection.boundary_origin[0],selection.boundary_origin[1])
		boundary_heading = selection.boundary_heading if selection.boundary_heading!=null else NAN
	selection_sha256 = FileAccess.get_sha256(selection_path)
	if selection.get("selected",{}).is_empty(): batch_failures.append("Missing ordinary coverage: no safe shared preflight route")
	for gap in selection.get("missing_coverage",[]): print("LOCAL_SNOW_BOUNDARY_MISSING_COVERAGE ",gap)
	# Persist diagnostics beside this mode even if the shared selection is elsewhere.
	if not batch_output.is_empty(): write_json(batch_output+"/selection_receipt.json",selection)

func verify_route_frame(frame: int) -> void:
	if route_proof:
		# Glide inputs are constant: 120 Hz timing and 30 Hz capture have identical
		# solver ticks. Check every fourth timing tick against the existing trace.
		var stride = int(fps/30)
		if (frame+1)%stride!=0: return
		frame = int((frame+1)/stride)-1
	var trace: Array = selection.selected.rides[scenario].trace
	if frame>=trace.size(): fail_once("Ordinary capture exceeds preflight trace"); return
	var expected: Dictionary = trace[frame]
	var error = game.sim.position.distance_to(Route.from3(expected.p))
	route_max_error_m = maxf(route_max_error_m,error)
	if not game.sim.position.is_finite() or not game.sim.velocity.is_finite() or not is_finite(game.sim.heading) or error>.001 or game.sim.velocity.distance_to(Route.from3(expected.v))>.001 or absf(angle_difference(game.sim.heading,expected.heading))>.00001 or game.sim.grounded!=expected.grounded or game.sim.ticks!=expected.ticks:
		fail_once("Ordinary solver diverged from shared preflight at frame "+str(frame))

func fail_once(message: String) -> void:
	if message not in failures: failures.append(message)

func counter_delta(before: Dictionary, after: Dictionary) -> Dictionary:
	var result = {}
	for key in ["dispatch_frames","uploaded_bytes","upload_calls","support_uploaded_bytes","support_upload_calls","presentations"]:
		if before.has(key) and after.has(key): result[key] = after[key]-before[key]
	return result

func verify_synthetic_sample(budget: Dictionary, profile) -> void:
	var p: Vector3 = game.skier.global_position
	var expected_visual = Vector2(p.x,p.z)
	var origin = Vector2(field.X_MIN,field.Z_MIN)
	var expected_storage = origin+(expected_visual-origin).snapped(Vector2.ONE*4.0)
	var should_enable: bool = profile.snow_local_deformation and phase!="deformation_off"
	if bool(budget.enabled)!=should_enable: fail_once("Unexpected powder activation in "+phase)
	if not movement_stats.has(phase): movement_stats[phase] = {"frames":0,"grounded_frames":0,"visual_moves":0,"storage_moves":0,"max_rendered_error_m":0.0,"max_center_error_m":0.0}
	var stats: Dictionary = movement_stats[phase]
	stats.frames += 1
	if game.sim.grounded: stats.grounded_frames += 1
	stats.max_rendered_error_m = maxf(stats.max_rendered_error_m,p.distance_to(game.sim.position))
	if not should_enable and not last_sample.is_empty() and not last_sample.enabled:
		if budget.dispatch_frames!=last_sample.dispatch_frames: fail_once("Disabled powder continued dispatching")
	if reference:
		# Frozen budget has no visual/storage/support/presentation fields.
		stats.center_assertion = "not_available_in_frozen_budget"
	elif should_enable:
		for key in ["visual_center","storage_center","support_upload_calls","presentations"]:
			if not budget.has(key): fail_once("After budget missing "+key); return
		var visual: Vector2 = budget.visual_center
		var storage: Vector2 = budget.storage_center
		stats.max_center_error_m = maxf(stats.max_center_error_m,visual.distance_to(expected_visual))
		if not visual.is_finite() or not storage.is_finite() or visual.distance_to(expected_visual)>.001 or storage.distance_to(expected_storage)>.001:
			fail_once("After mapping failed to follow/recenter in "+phase)
		if not last_sample.is_empty() and last_sample.enabled:
			var visual_moved = visual.distance_to(last_sample.visual_center)>.001
			var storage_moved = storage.distance_to(last_sample.storage_center)>.001
			if last_sample.phase==phase:
				if visual_moved: stats.visual_moves += 1
				if storage_moved: stats.storage_moves += 1
			if storage_moved and budget.support_upload_calls<=last_sample.support_upload_calls:
				fail_once("Recenter did not upload support in "+phase)
			if visual_moved and budget.presentations<=last_sample.presentations:
				fail_once("Moved visual center was not presented in "+phase)
		elif not last_sample.is_empty() and budget.support_upload_calls<=last_sample.support_upload_calls:
			fail_once("Re-enabled patch did not rebuild support")
	last_sample = budget.duplicate(); last_sample.phase = phase

func verify_synthetic_coverage(profile) -> void:
	if seconds!=15.0: return # legacy shorter diagnostic is explicitly partial
	var expected = {"hold":30,"x_thresholds":90,"z_thresholds":90,"fast_diagonal":60,"threshold_reversal":45,"air_landing":30,"teleport_hold":30,"deformation_off":30,"deformation_restored":45}
	for name in expected:
		if movement_stats.get(name,{}).get("frames",0)!=expected[name]: fail_once("Incomplete synthetic phase "+name)
	if movement_stats.get("air_landing",{}).get("grounded_frames",0)!=15: fail_once("Missing synthetic air/landing samples")
	if reference or not profile.snow_local_deformation: return
	for name in {"x_thresholds":2,"z_thresholds":2,"fast_diagonal":15,"threshold_reversal":2,"deformation_restored":1}:
		var stats: Dictionary = movement_stats.get(name,{})
		var minimum: int = {"x_thresholds":2,"z_thresholds":2,"fast_diagonal":15,"threshold_reversal":2,"deformation_restored":1}[name]
		if stats.get("storage_moves",0)<minimum or stats.get("visual_moves",0)<minimum:
			fail_once("Vacuous synthetic movement/recenter coverage in "+name)

func configure_matrix_case(spec: Dictionary):
	preset = spec.preset; deformation = spec.deformation; weather = spec.weather; daylight = spec.daylight; upscaler = spec.upscaler
	game.set_graphics_preset(preset)
	if deformation!="preset":
		game.display_settings.set_graphics_value("snow_local_deformation",deformation=="on")
		game.apply_graphics_configuration()
	game.display_settings.upscaler = upscaler
	game.display_settings.render_scale = 1.0 if upscaler=="native" else .75
	game.display_settings.frame_generation = false; game.display_settings.terrain_gi = false
	game.world.environment.sdfgi_enabled = false
	game.display_settings.apply_display(root,requested); game.display_settings.apply_viewport(root)
	game.weather.set_preset(weather); game.weather.set_time_of_day(daylight)
	game.weather.set_automatic(false); game.weather.set_time_cycle(false); game.weather.seed_stream(field.seed_value)
	weather_initial = game.weather.snapshot()
	for key in ["visual_time","active_seconds","free_seconds","phase_seconds","cloud_x","cloud_z","race_elapsed"]: weather_initial[key] = 0.0
	weather_initial.cloud_offset = Vector2.ZERO
	if reference:
		for material in [game.world.snow_material,game.effects.snow_tracks.material]:
			if "/reference_resources/" not in material.shader.resource_path: fail_once("Quality change lost the frozen shader reference")
	return game.graphics

func settings_identity(profile) -> Dictionary:
	return {"display":game.display_settings.snapshot(),"profile":profile.snapshot(),"weather":weather,"daylight":daylight,
		"output":[requested.x,requested.y],"sample_fps":fps,"initial_speed_kmh":60.0 if scenario.begins_with("ride_") and not selection_path.is_empty() else speed_kmh}

func prepare_route_proof() -> void:
	route_identity = Route.physical_identity(field,game.world.ski_surface,game.sim.tuning,fps)
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(selection_path))
	if not parsed is Dictionary or not Route.valid_selection(parsed,30) or parsed.get("selected",{}).is_empty():
		batch_failures.append("Pinned v3 route has no complete safe pair"); return
	var expected = route_identity.duplicate(true)
	expected.fixture_sha256 = V3_PRODUCER_SHA256
	expected.fps = 30.0
	if parsed.get("physics_terrain_identity",{})!=expected:
		batch_failures.append("Pinned v3 route physical/terrain/engine/selector identity mismatch"); return
	if timing:
		var origin = Vector2(parsed.selected.origin[0],parsed.selected.origin[1])
		if boundary_origin.distance_to(origin)>.001 or not is_finite(boundary_heading) or absf(angle_difference(boundary_heading,parsed.selected.heading))>.0000001:
			batch_failures.append("Timing --origin/--heading must exactly match the selected real glide"); return
	selection = parsed; selection_sha256 = FileAccess.get_sha256(selection_path)
	boundary_origin = Vector2(selection.boundary_origin[0],selection.boundary_origin[1])
	boundary_heading = selection.boundary_heading if selection.boundary_heading!=null else NAN
	for gap in selection.get("missing_coverage",[]): print("LOCAL_SNOW_BOUNDARY_MISSING_COVERAGE ",gap)
	if not batch_output.is_empty(): write_json(batch_output+"/selection_receipt.json",selection)

func verify_temporal(before: Dictionary) -> Dictionary:
	var after: Dictionary = game.display_settings.fsr_status()
	var delta = int(after.get("upscale_dispatches",0))-int(before.get("upscale_dispatches",0))
	var required = upscaler!="native"
	if game.display_settings.frame_generation or after.get("frame_generation_active",false): fail_once("Unexpected frame generation")
	if absf(root.scaling_3d_scale-(.75 if required else 1.0))>.00001: fail_once("Wrong native/75-percent render scale")
	if required:
		if root.scaling_3d_mode!=Viewport.SCALING_3D_MODE_FSR2 or root.msaa_3d!=Viewport.MSAA_DISABLED: fail_once("Temporal viewport configuration inactive")
		if str(after.get("active_upscaler_version","")).is_empty(): fail_once("Temporal backend did not identify an active version")
		if after.get("engine_integration",false) and delta<=0: fail_once("No native temporal dispatches during the case")
	return {"required":required,"before":before,"after":after,"upscale_dispatch_delta":delta,
		"proof":"native provider dispatch delta" if after.get("engine_integration",false) else "built-in FSR2 viewport; no provider dispatch counter"}

func choose_retained_edge() -> Dictionary:
	if not Footprint.enabled(field): return {}
	# Bounded metadata search around 64 radial locations, not a mountain bake.
	# Keep the entire 13.5 m diagnostic ring inside the physical height grid.
	for angle_index in 64:
		var direction = Vector2(sin(angle_index*TAU/64),cos(angle_index*TAU/64))
		var near = direction*Footprint.radius(direction)
		var grid_center = (near/32.0).floor()*32.0+Vector2.ONE*16
		for z in range(-1,2):
			for x in range(-1,2):
				var center = grid_center+Vector2(x,z)*32
				if not Footprint.owns_cell(center): continue
				for outward in [Vector2.RIGHT,Vector2.LEFT,Vector2.UP,Vector2.DOWN]:
					var midpoint: Vector2 = center+outward*16
					if not field.bounds().grow(-24).has_point(midpoint) or Footprint.owns_cell(midpoint+outward*.125): continue
					var origin: Vector2 = midpoint-outward*6
					if field.rock_fraction_at(origin.x,origin.y)>.5 or field.contact_normal(origin.x,origin.y).y<.65: continue
					return {"origin":[origin.x,origin.y],"midpoint":[midpoint.x,midpoint.y],"inward":[-outward.x,-outward.y],
						"kind":"retained 32 m terrain/scenery join; physical height-grid edge is NOT crossed","footprint_revision":Footprint.REVISION}
	return {}

func verify_edge_sample() -> Dictionary:
	var p: Vector3 = game.skier.global_position
	var xz = Vector2(p.x,p.z)
	var center_owned = field.bounds().has_point(xz) and Footprint.owns_cell(xz)
	var inside = 0
	var outside = 0
	for i in 16:
		var q = xz+Vector2(cos(i*TAU/16),sin(i*TAU/16))*13.5
		if not field.bounds().has_point(q): fail_once("Edge diagnostic escaped the physical height grid")
		if Footprint.owns_cell(q): inside += 1
		else: outside += 1
	if not center_owned or inside==0 or outside==0: fail_once("Invalid/vacuous retained-edge sample")
	else: edge_rows += 1
	return {"center_owned":center_owned,"ring_owned":inside,"ring_unowned":outside,"ring_radius_m":13.5,
		"material_query_scope":"support-grid material outside the retained mesh is not proof of rendered snow"}

func write_fixture_source(path: String, content: String) -> bool:
	if FileAccess.file_exists(path): fail_once("Refusing existing fixture source "+path); return false
	if DirAccess.make_dir_recursive_absolute(path.get_base_dir())!=OK: return false
	var file = FileAccess.open(path,FileAccess.WRITE)
	if file==null: fail_once("Cannot write fixture source "+path); return false
	file.store_string(content); file.flush()
	return file.get_error()==OK

func instantiate_fixture_game():
	if timing: return load("res://main.tscn").instantiate()
	var original = FileAccess.get_file_as_string("res://scripts/main.gd")
	var scene = FileAccess.get_file_as_string("res://main.tscn")
	var needle = "var fraction = Engine.get_physics_interpolation_fraction() if active else 1.0"
	if original.count(needle)!=1 or scene.count('"res://scripts/main.gd"')!=1:
		fail_once("Cannot uniquely pin Main's actual render fraction"); return null
	var replacement = "var fraction = 1.0\n\tset_meta(\"boundary_actual_render_fraction\",fraction)\n\tset_meta(\"boundary_unpinned_clock_fraction\",Engine.get_physics_interpolation_fraction())"
	var rewritten = original.replace(needle,replacement)
	var target = output+"/fixture_runtime/"
	var rewritten_scene = scene.replace('"res://scripts/main.gd"','"'+target+'main_fixed.gd"')
	if not write_fixture_source(target+"main_fixed.gd",rewritten) or not write_fixture_source(target+"main_fixed.tscn",rewritten_scene): return null
	identity.render_control = {"mode":"visual fixture Main copy; fraction=1.0", "main_source_sha256":FileAccess.get_sha256("res://scripts/main.gd"),
		"main_wrapper_sha256":FileAccess.get_sha256(target+"main_fixed.gd"),"scene_source_sha256":FileAccess.get_sha256("res://main.tscn"),
		"scene_wrapper_sha256":FileAccess.get_sha256(target+"main_fixed.tscn"),"replacement_count":1,"wrapper":target+"main_fixed.gd"}
	var packed = load(target+"main_fixed.tscn")
	return packed.instantiate() if packed else null

func pose_values(pose: Transform3D) -> Array:
	return [Route.v3(pose.origin),Route.v3(pose.basis.x),Route.v3(pose.basis.y),Route.v3(pose.basis.z)]

func inspect_render_control() -> Dictionary:
	var actual = float(game.get_meta("boundary_actual_render_fraction",-1.0))
	var expected: Vector3 = game.sim.facing_pose.frame.origin
	var error = game.skier.global_position.distance_to(expected)
	if actual!=1.0 or not is_finite(error) or error>.001: fail_once("Main fixed-fraction/completed-root assertion failed")
	var camera = root.get_camera_3d()
	var ski_poses: Array = []
	for visual in game.skier.skis: ski_poses.append(pose_values(visual.global_transform))
	return {"actual_fraction":actual,"unused_clock_fraction":game.get_meta("boundary_unpinned_clock_fraction",-1.0),
		"completed_root_error_m":error,"expected_root":Route.v3(expected),"camera":pose_values(camera.global_transform) if camera else [],
		"camera_fov":camera.fov if camera else 0.0,"ski_poses":ski_poses,
		"scope":"Actual Main pose interpolation pinned. Compare camera/equipment rows between modes; materials/particles/temporal jitter are not declared pixel-identical."}

func update_snow_reset_phase(frame: int, profile) -> void:
	phase = "snow_before" if frame<15 else ("snow_off" if frame<30 else ("snow_restored" if frame<60 else "ride_after_snow_reset"))
	if frame not in [15,30]: return
	# Cosmetic histories only. Continue the ordinary production solver unchanged.
	game.effects.reset()
	var empty = game.effects.snow_tracks.written==0 and game.effects.snow_tracks.live_active.count(true)==0
	if not empty: fail_once("Snow reset retained old player history/live slots")
	var q = profile.duplicate(); q.snow_local_deformation = frame==30
	game.effects.powder_surface.apply_quality(q)
	reset_budget = game.effects.powder_surface.budget().duplicate()
	snow_reset_stats["reset_%d"%frame] = {"player_history_empty":empty,"budget_before_new_frame":reset_budget.duplicate()}

func snow_footprint(center: Vector3, forward: Vector3) -> Dictionary:
	var surface = game.world.ski_surface
	var across = Vector3.UP.cross(forward).normalized()
	var points: Array = []
	var valid = center.is_finite() and forward.is_finite() and across.length_squared()>.5
	for along in [-game.sim.tuning.ski_length*.5,0.0,game.sim.tuning.ski_length*.5+.12]:
		for side in [-.15,0.0,.15]:
			var p = center+forward*along+across*side
			var inside = field.bounds().has_point(Vector2(p.x,p.z)) and Footprint.owns_cell(Vector2(p.x,p.z))
			var rock: float = surface.rock_fraction_at(p.x,p.z)
			var depth: float = surface.snow_depth_at(p.x,p.z)
			var sample_value: Dictionary = surface.sample(p.x,p.z)
			var clearance: float = (p.y-sample_value.height)*sample_value.normal.y
			var snow = inside and rock<.5 and depth>.01 and is_finite(clearance)
			valid = valid and snow
			points.append({"p":Route.v3(p),"retained":inside,"rock":rock,"loose_depth_m":depth,"clearance_m":clearance})
	return {"snow":valid,"points":points,"scope":"Actual nine-point material/depth/void evidence; production response separately owns contact acceptance."}

func verify_snow_reset_frame(frame: int, budget: Dictionary) -> Dictionary:
	if frame>=60: return {}
	var should_enable = frame<15 or frame>=30
	if bool(budget.enabled)!=should_enable: fail_once("Wrong activation during "+phase)
	if not should_enable and budget.dispatch_frames!=reset_budget.dispatch_frames: fail_once("Disabled snow reset interval dispatched powder")
	if not snow_reset_stats.has(phase): snow_reset_stats[phase] = {"frames":0,"both_accepted_snow_frames":0,"per_ski_accepted":[0,0]}
	var stats: Dictionary = snow_reset_stats[phase]
	stats.frames += 1
	var packet: PackedFloat32Array = game.effects.snow_tracks.live_gpu_strokes()
	var accepted: Array = []
	var both = game.sim.grounded and not game.sim.crashed
	for i in 2:
		var ski = game.sim.skis[i]
		var response = game.effects.responses[i]
		var physical = snow_footprint(ski.position,ski.forward)
		var rendered = snow_footprint(response.contact_position,response.contact_forward)
		var ok = ski.grounded and physical.snow and rendered.snow and response.track_contact and response.track_depth_m>.0001 and game.effects.snow_tracks.live_active[i] and packet[i*8+5]>.0001
		if ok: stats.per_ski_accepted[i] += 1
		both = both and ok
		accepted.append({"accepted":ok,"physical":physical,"rendered":rendered,"packet_depth_m":packet[i*8+5],"reason":response.track_reason})
	if both: stats.both_accepted_snow_frames += 1
	else: fail_once("Snow reset interval lacks two genuinely accepted snowy footprints: "+phase)
	if frame>=30 and budget.dispatch_frames<=reset_budget.dispatch_frames: fail_once("Re-enabled snow never reconstructed")
	return {"phase":phase,"both_accepted":both,"skis":accepted,"written_since_reset":game.effects.snow_tracks.written,
		"dispatches_since_transition":budget.dispatch_frames-reset_budget.get("dispatch_frames",budget.dispatch_frames)}

func capture_snow_gpu(frame: int, budget: Dictionary) -> void:
	var powder = game.effects.powder_surface
	if powder.rd==null or not powder.buffer_rid.is_valid() or not powder.surface_rid.is_valid():
		fail_once("Snow GPU resources unavailable; restoration coverage missing"); return
	var expected: PackedFloat32Array = game.effects.snow_tracks.live_gpu_strokes()
	var center: Vector2 = powder.center
	var enabled: bool = budget.enabled
	if enabled and not center.is_finite(): fail_once("Enabled GPU atlas has no finite mapping"); return
	snow_gpu_ready = false
	RenderingServer.call_on_render_thread(read_snow_gpu.bind(powder,powder.track_history.capacity*32))
	var deadline = Time.get_ticks_msec()+10000
	while not snow_gpu_ready and Time.get_ticks_msec()<deadline: await process_frame
	if not snow_gpu_ready: fail_once("Bounded snow GPU readback timed out"); return
	var bytes: PackedByteArray = snow_gpu_result.live
	var map_bytes: PackedByteArray = snow_gpu_result.surface
	if bytes.size()!=64 or map_bytes.size()!=256*256*4: fail_once("Unexpected bounded snow GPU readback size"); return
	var packet = bytes.to_float32_array()
	var map = Image.create_from_data(256,256,false,Image.FORMAT_RGH,map_bytes)
	var row = {"frame":frame,"phase":phase,"enabled":enabled,"center":[center.x,center.y] if center.is_finite() else [],"live":Array(packet),
		"mapping_scope":"active atlas" if enabled else "disabled stale allocation; no active center/relief assertion",
		"live_sha256":Route.digest(bytes),"surface_sha256":Route.digest(map_bytes),"accepted_live":Array(expected),"matches_accepted_packet":bytes==expected.to_byte_array(),
		"dispatch_frames":budget.dispatch_frames,"player_written":game.effects.snow_tracks.written,"live_relief":[],"old_relief":[]}
	var positive = 0
	for i in 2:
		var offset = i*8
		if not enabled: row.live_relief.append({"not_applicable":"deformation_off"}); continue
		var world = Vector2((packet[offset]+packet[offset+2])*.5,(packet[offset+1]+packet[offset+3])*.5)
		var relief = relief_probe(map,world,center) if packet[offset+5]>.0001 else {"inside":false,"max_abs_height_m":0.0}
		row.live_relief.append(relief)
		if packet[offset+5]>.0001 and relief.inside and relief.max_abs_height_m>.00001: positive += 1
	row.positive_gpu_slots = positive
	var required = 2
	var physical_depths: Array = []
	for response in game.effects.responses: physical_depths.append(response.depth_m if response.snow_contact else 0.0)
	if reference:
		required = 0
		for depth in physical_depths:
			if depth>.0001: required += 1
	row.physical_response_depths_m = physical_depths
	row.required_gpu_slots = required if enabled else 0
	if enabled:
		# Frozen Powder reconstructs only physically loaded live slots; its
		# historical zero low-load slot must not invalidate the control schema.
		if required<1 or positive<required: fail_once("Enabled snow has no required fresh GPU live/relief proof")
		if not reference and not row.matches_accepted_packet: fail_once("After GPU live slots differ from genuinely accepted ribbons")
	if frame==30:
		if snow_gpu_reads.size()!=2: fail_once("Missing pre/off GPU evidence")
		else:
			var previous: Array = snow_gpu_reads[0].live
			if row.live_sha256==snow_gpu_reads[1].live_sha256: fail_once("Re-enable reused the old GPU live stamp")
			for i in 2:
				var offset = i*8
				if previous[offset+5]<=.0001: continue
				var point = Vector2((previous[offset]+previous[offset+2])*.5,(previous[offset+1]+previous[offset+3])*.5)
				var old = relief_probe(map,point,center); row.old_relief.append(old)
				if not old.inside or old.max_abs_height_m>.00001: fail_once("Old snow mark was not demonstrably cleared on reset/re-enable")
	if frame in [30,59] and budget.dispatch_frames<=reset_budget.dispatch_frames: fail_once("Fresh GPU data has no new dispatch")
	if frame==59 and game.effects.snow_tracks.written<=0: fail_once("No newly retained real snow marks within restored window")
	snow_gpu_reads.append(row)

func read_snow_gpu(powder, offset: int) -> void:
	var result = {"live":powder.rd.buffer_get_data(powder.buffer_rid,offset,64),"surface":powder.rd.texture_get_data(powder.surface_rid,0)}
	call_deferred("receive_snow_gpu",result)

func receive_snow_gpu(result: Dictionary) -> void:
	snow_gpu_result = result; snow_gpu_ready = true

func relief_probe(map: Image, world: Vector2, center: Vector2) -> Dictionary:
	var pixel = (world-center+Vector2.ONE*16.0)*8.0
	var inside = pixel.x>=2 and pixel.y>=2 and pixel.x<254 and pixel.y<254
	var maximum = 0.0
	if inside:
		for y in range(-2,3):
			for x in range(-2,3): maximum = maxf(maximum,absf(map.get_pixel(int(pixel.x)+x,int(pixel.y)+y).r))
	return {"world":[world.x,world.y],"inside":inside,"max_abs_height_m":maximum,"pixel_radius":2}

func verify_snow_reset_coverage() -> void:
	for name in {"snow_before":15,"snow_off":15,"snow_restored":30}:
		var required: int = {"snow_before":15,"snow_off":15,"snow_restored":30}[name]
		var stats: Dictionary = snow_reset_stats.get(name,{})
		if stats.get("frames",0)!=required or stats.get("both_accepted_snow_frames",0)!=required: fail_once("Missing positive snow reset coverage: "+name)
	if snow_gpu_reads.size()!=4: fail_once("Missing bounded GPU reset/re-enable probes")
	snow_reset_stats.coverage = "runtime gates passed; pixel review pending" if failures.is_empty() else "missing or failed; inspect failures and per-frame probes"

func shader_closure(roots: Array) -> Dictionary:
	var result = {}
	var pending = roots.duplicate()
	var include = RegEx.new(); include.compile('#include\\s+"([^"\\r\\n]+)"')
	while not pending.is_empty():
		var path: String = pending.pop_back()
		if result.has(path): continue
		if not FileAccess.file_exists(path): result[path] = "MISSING"; fail_once("Missing shader closure source: "+path); continue
		result[path] = FileAccess.get_sha256(path)
		var content = FileAccess.get_file_as_string(path)
		for match_value in include.search_all(content):
			var dependency: String = match_value.get_string(1)
			pending.append(dependency if dependency.begins_with("res://") else path.get_base_dir().path_join(dependency))
	return result

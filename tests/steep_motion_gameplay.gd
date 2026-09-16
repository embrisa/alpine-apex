extends "res://tests/skier_animation_playtest.gd"
## Matched current v13 gameplay and physics; native full-curve A/B and timing.
const Definition = preload("res://scripts/world/mountain_definition.gd")
var field
var before = false
var timing = false
var evidence: Array = []
var tick_us: Array[float] = []
var failures: Array = []
var view_cameras: Dictionary = {}
var folder_label = ""
var motion_step_us: Array[float] = []
var motion_interpolation_us: Array[float] = []
var motion_fit_us: Array[float] = []
var binding_us: Array[float] = []
var character_us: Array[float] = []

func run():
	if DisplayServer.get_name()=="headless": quit(2); return
	before = "--procedural" in OS.get_cmdline_user_args()
	var motion_baseline = ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--motion-baseline="): motion_baseline = argument.trim_prefix("--motion-baseline=")
	timing = "--timing" in OS.get_cmdline_user_args()
	folder_label = ("before" if before else "after")+("_timing" if timing else "_visual")
	if not motion_baseline.is_empty(): folder_label = "before_visual"
	if "--quick" in OS.get_cmdline_user_args(): folder_label += "_quick"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--case="): folder_label += "_case_"+argument.get_slice("=",1).validate_filename()
	output = "res://artifacts/steep_motion_gameplay/"+folder_label
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence="): output = "res://artifacts/"+argument.get_slice("=",1).validate_filename()+"/"+folder_label
	DirAccess.make_dir_recursive_absolute(output)
	requested = Vector2i(3840,2160) if timing else Vector2i(1280,900)
	field = Definition.generate(849205174,13)
	set_meta("mountain_to_load",{"definition":Definition.from_field(field,"Full-curve motion validation"),"field":field})
	var scene = "res://main.tscn"
	if not FileAccess.file_exists(scene): printerr("Missing production scene: ",scene); quit(2); return
	game = load(scene).instantiate(); game.automated = true
	root.add_child(game); current_scene = game
	while not game.initialized or (game.loading and game.loading.busy): await process_frame
	game.set_process(false); game.set_physics_process(false)
	game.skier.animation.full_motion.enabled = not before
	if not motion_baseline.is_empty(): game.skier.animation.full_motion = load(motion_baseline).new()
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
		{"name":"neutral_glide","steer":0.0,"speed_kmh":60.0,"tuck":0.0,"seconds":3.0},
		{"name":"gentle_turn","steer":.2,"speed_kmh":60.0,"tuck":0.0,"seconds":4.0},
		{"name":"edge_change","steer":-.85,"speed_kmh":60.0,"tuck":0.0,"seconds":4.0},
		{"name":"tuck_to_turn","steer":.8,"turn_start":1.0,"tuck":1.0,"speed_kmh":90.0,"seconds":4.0},
		{"name":"braking_skid","steer":.3,"brake":.8,"slip":.20,"tuck":0.0,"speed_kmh":60.0,"seconds":3.0},
		{"name":"prepared_hop","hop":true,"seconds":3.0},
		{"name":"natural_departure","natural":true,"speed_kmh":90.0,"seconds":4.0},
		{"name":"small_landing","height":.6,"up":-2.0,"seconds":3.0},
		{"name":"large_landing","height":7.0,"up":-8.0,"seconds":4.0},
		{"name":"one_ski_landing","height":2.0,"up":-3.0,"roll":.15,"seconds":3.0},
		{"name":"low_reserve_recovery","steer":.2,"tuck":0.0,"speed_kmh":50.0,"reserve":.25,"seconds":4.0},
		{"name":"safety_grab","height":16.0,"up":6.0,"trick":"grab","seconds":4.0},
		{"name":"mute_grab","height":16.0,"up":6.0,"trick":"grab","grab_style":"mute","seconds":4.0},
		{"name":"spin_release","height":28.0,"up":8.0,"trick":"spin","seconds":5.0},
		{"name":"flip_release","height":28.0,"up":8.0,"trick":"flip","seconds":5.0},
		{"name":"switch_flip","height":28.0,"up":8.0,"trick":"flip","switch":true,"seconds":5.0},
		{"name":"switch_turn","steer":-.7,"tuck":0.0,"speed_kmh":60.0,"switch":true,"seconds":4.0},
		{"name":"near_landing_override","height":12.0,"up":4.0,"assist":true,"override":true,"seconds":4.0}]
	if "--skid-review" in OS.get_cmdline_user_args():
		scenarios = [
			{"name":"pelvis_glide","steer":0.0,"tuck":0.0,"speed_kmh":60.0,"seconds":2.0},
			{"name":"pelvis_tuck","steer":0.0,"tuck":1.0,"speed_kmh":90.0,"seconds":2.0},
			{"name":"skid_left","steer":1.0,"slip":deg_to_rad(60.0),"speed_kmh":120.0,"sustain":true,"tuck":0.0,"z":900.0,"seconds":4.0},
			{"name":"skid_right","steer":-1.0,"slip":deg_to_rad(-60.0),"speed_kmh":120.0,"sustain":true,"tuck":0.0,"z":900.0,"seconds":4.0}]
	if "--pelvis-review" in OS.get_cmdline_user_args():
		scenarios = [
			{"name":"pelvis_glide","steer":0.0,"tuck":0.0,"speed_kmh":60.0,"seconds":2.0},
			{"name":"pelvis_tuck","steer":0.0,"tuck":1.0,"speed_kmh":90.0,"seconds":3.0},
			{"name":"pelvis_carve_left","steer":.2,"tuck":0.0,"speed_kmh":90.0,"sustain":true,"seconds":3.0},
			{"name":"pelvis_carve_right","steer":-.2,"tuck":0.0,"speed_kmh":90.0,"sustain":true,"seconds":3.0},
			{"name":"pelvis_tuck_carve","steer":.2,"turn_start":1.0,"tuck":1.0,"speed_kmh":90.0,"sustain":true,"seconds":3.0}]
	if "--compact-review" in OS.get_cmdline_user_args():
		scenarios = [
			{"name":"compact_glide","steer":0.0,"tuck":0.0,"speed_kmh":60.0,"seconds":2.0},
			{"name":"compact_tuck","steer":0.0,"tuck":1.0,"speed_kmh":90.0,"seconds":3.0},
			{"name":"compact_jump","hop":true,"speed_kmh":60.0,"seconds":3.0},
			{"name":"compact_big_air","height":16.0,"up":6.0,"seconds":3.0},
			{"name":"compact_tuck_turn","steer":.2,"turn_start":1.0,"tuck":1.0,"speed_kmh":90.0,"sustain":true,"seconds":3.0}]
	if timing:
		scenarios = [
			# Repeat the validated short corridor; eight seconds of unattended
			# straight travel exits this curved glade and hits a v13 tree.
			{"name":"neutral_glide_1","steer":0.0,"speed_kmh":60.0,"tuck":0.0,"seconds":3.0},
			{"name":"neutral_glide_2","steer":0.0,"speed_kmh":60.0,"tuck":0.0,"seconds":3.0},
			{"name":"neutral_glide_3","steer":0.0,"speed_kmh":60.0,"tuck":0.0,"seconds":2.0},
			{"name":"tuck_to_turn","steer":.8,"turn_start":1.0,"tuck":1.0,"speed_kmh":90.0,"seconds":8.0},
			{"name":"safety_grab","height":16.0,"up":6.0,"trick":"grab","seconds":4.0},
			{"name":"flip_release","height":28.0,"up":8.0,"trick":"flip","seconds":5.0},
			{"name":"one_ski_landing","height":2.0,"up":-3.0,"roll":.15,"seconds":4.0}]
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--case="): scenarios = scenarios.filter(func(r): return r.name==argument.get_slice("=",1))
	if "--quick" in OS.get_cmdline_user_args():
		scenarios = [{"name":"neutral_glide","steer":0.0,"tuck":0.0,"speed_kmh":60.0,"seconds":2.0},
			{"name":"tuck","steer":0.0,"tuck":1.0,"speed_kmh":90.0,"seconds":2.0},
			{"name":"left_turn","steer":-.7,"tuck":0.0,"speed_kmh":60.0,"seconds":3.0},
			{"name":"safety_grab","height":16.0,"up":6.0,"trick":"grab","seconds":3.0}]
	if "--tuck-review" in OS.get_cmdline_user_args():
		scenarios = [
			{"name":"deep_tuck","steer":0.0,"tuck":1.0,"speed_kmh":90.0,"seconds":3.0},
			{"name":"tuck_release_return","steer":0.0,"tuck":1.0,"cycle_tuck":true,"speed_kmh":60.0,"seconds":3.0},
			{"name":"tuck_to_turn","steer":.8,"turn_start":1.0,"tuck":1.0,"speed_kmh":90.0,"seconds":4.0},
			{"name":"switch_tuck","steer":-.45,"turn_start":1.0,"tuck":1.0,"speed_kmh":60.0,"switch":true,"seconds":3.0},
			{"name":"safety_grab","height":16.0,"up":6.0,"trick":"grab","seconds":4.0},
			{"name":"mute_grab","height":16.0,"up":6.0,"trick":"grab","grab_style":"mute","seconds":4.0}]
	for request in scenarios: await ride(request)
	measuring = false
	var report = {"physics":game.sim.MODEL_VERSION,"seed":849205174,"version":13,"unranked":not game.session.eligible,"cases":evidence,"failures":failures,
		"actual_pixels":[actual.x,actual.y],"display":game.display_settings.report(root,actual),"device":RenderingServer.get_video_adapter_name(),
		"capture_overhead_included":not timing,"quality":game.graphics.label(),"height_sha256":field.height_checksum,"obstacle_sha256":field.obstacle_checksum}
	report.sources = {}
	if not motion_baseline.is_empty(): report.motion_baseline = {"path":motion_baseline,"sha256":FileAccess.get_sha256(motion_baseline)}
	for source in ["scripts/presentation/skier_anatomy.gd","scripts/presentation/skier_visual.gd","scripts/presentation/skier_animation.gd","scripts/presentation/skier_full_motion.gd","scripts/core/ski_simulation.gd","scripts/core/landing_assist.gd","scripts/core/impact_recovery.gd","assets/animation/steep_ski_motion.res","scripts/main.gd","scripts/world/generators/alpine_massif_v13.gd","scripts/world/alpine_world.gd","scripts/presentation/graphics_quality.gd","project.godot"]:
		assert(FileAccess.file_exists("res://"+source))
		report.sources[source] = FileAccess.get_sha256("res://"+source)
	if timing:
		report.frame_ms = stats(frames); report.render_cpu_ms = stats(render_cpu); report.render_gpu_ms = stats(gpu)
		report.fixed_tick_us = stats(tick_us); report.peak_video_bytes = peak_video; report.peak_engine_static_bytes = peak_static
		report.motion_cost_us = {"fixed_tick_sampler":stats(motion_step_us),"render_interpolation":stats(motion_interpolation_us),"source_pose_fitting":stats(motion_fit_us),"physical_leg_fitting":stats(binding_us),"complete_character_pose":stats(character_us)}
	preload("res://tests/test_report.gd").write(output+"/results.json",JSON.stringify(report,"\t"))
	print("MOTION_NATIVE_COMPLETE cases=",evidence.size()," physics=",game.sim.MODEL_VERSION," failures=",failures," output=",output)
	game.effects.stop_audio(); game.queue_free(); await process_frame
	quit(0 if failures.is_empty() else 1)

func ride(request: Dictionary):
	var face = field.faces[0]
	var z: float = request.get("z",2150.0 if request.has("steer") else 820.0)
	var x: float = face.glade_x(z,-1) if z>1850 else face.gully_x(z,-1)
	var p: Vector2 = face.to_world(Vector2(x,z))
	var origin = Vector3(p.x,field.sample(p.x,p.y).height+request.get("height",0.0),p.y)
	var heading: float = face.heading
	var speed: float = request.get("speed_kmh",120.0 if request.has("steer") else 72.0)/3.6
	if request.get("natural",false):
		var site = natural_fixture()
		if site.is_empty(): failures.append("No actual natural departure fixture"); return
		origin = site.origin; heading = site.heading; speed = site.speed
	game.skier.animation.full_motion.grab_style = request.get("grab_style","safety")
	game.sim.reset(origin,heading); game.sim.prime_contacts(game.world.ski_surface)
	game.sim.velocity = game.sim.support_basis().z*speed+Vector3.UP*request.get("up",0.0)
	if request.has("slip"):
		game.sim.velocity = game.sim.velocity.rotated(game.sim.surface_normal,request.slip)
	if request.get("height",0.0)>0:
		game.sim._begin_flight(game.sim.support_basis()); game.sim.reset_pose_history()
	game.sim.effective_tuck = request.get("tuck",1.0 if request.has("steer") else 0.0)
	game.sim.impacts.reserve = request.get("reserve",1.0)
	game.sim.impacts.since_hit = 0.0 if request.has("reserve") else 60.0
	if request.has("assist"): game.sim.tuning.landing_assist_enabled = request.assist
	else: game.sim.tuning.landing_assist_enabled = false
	if request.get("switch",false):
		game.sim.facing_backward = true; game.sim.facing_pose.capture(game.sim,true)
	if request.has("roll"):
		game.sim.flight_frame *= Basis(Vector3.BACK,request.roll)
		game.sim.reset_pose_history()
	game.skier.reset_animation(game.sim); game.camera.reset(); game.effects.reset()
	var intent = RiderInput.new()
	var captures: Array = []
	var hops = 0
	var max_impact = 0.0
	var minimum_margin = INF
	var count = int(request.seconds*(120 if timing else 30))
	var orientation_trace = []
	var max_air_step = 0.0
	var max_air_acceleration = 0.0
	measuring = timing; last_frame = 0
	var motion_trace = []; var sampler_us: Array[float] = []; var fitting_us: Array[float] = []; var final_pose_us: Array[float] = []
	var interpolation_us: Array[float] = []; var leg_fit_us: Array[float] = []; var character_pose_us: Array[float] = []
	for frame_index in count:
		var seconds: float = frame_index/float(120 if timing else 30)
		intent.steer = request.get("steer",0.0)*(1.0 if seconds<2.0 or request.get("sustain",false) else -1.0)
		if seconds<request.get("turn_start",0.0): intent.steer = 0.0
		intent.tuck = request.get("tuck",1.0 if request.has("steer") else 0.0)
		if request.get("cycle_tuck",false): intent.tuck = 0.0 if seconds>=.75 and seconds<1.75 else 1.0
		intent.brake = request.get("brake",0.0)
		intent.air_yaw = 1.0 if request.get("trick","")=="spin" and seconds<1.39 else 0.0
		intent.air_pitch = 1.0 if request.get("trick","")=="flip" and seconds<1.655 else 0.0
		intent.grab = request.get("trick","")=="grab" and seconds>.3 and seconds<1.8
		if request.get("override",false): intent.steer = .6 if seconds>=1.25 and seconds<1.55 else 0.0
		intent.jump_held = request.get("hop",false) and seconds<.30
		for tick in (1 if timing else 4):
			intent.jump = request.get("hop",false) and game.sim.ticks==36
			var start = Time.get_ticks_usec()
			game.previous_position = game.sim.position
			var old_frame: Basis = game.sim.support_basis()
			var was_air: bool = not game.sim.grounded
			game.sim.step(DT,intent,game.world.ski_surface)
			if was_air and not game.sim.grounded and game.sim.time_since_landing>DT and game.sim.skis[0].landing_speed==0.0 and game.sim.skis[1].landing_speed==0.0:
				max_air_step = maxf(max_air_step,angular_delta(old_frame,game.sim.support_basis()))
				if not before: max_air_acceleration = maxf(max_air_acceleration,game.sim.air_control.angular_acceleration.length())
			game.skier.step_animation(DT,game.sim,intent,field)
			if timing: tick_us.append(Time.get_ticks_usec()-start)
			if game.sim.jump_executed: hops += 1
			max_impact = maxf(max_impact,game.sim.landing_force)
		game.intent = intent; game.session.elapsed += DT*(1 if timing else 4)
		var pose_start = Time.get_ticks_usec()
		game._process(DT*(1 if timing else 4)); game.speed_periphery.hide()
		if not timing and not before and game.sim.grounded:
			minimum_margin = minf(minimum_margin,game.skier.animation.clearance_margin(game.skier.rendered_joints,game.skier.global_transform))
		final_pose_us.append(Time.get_ticks_usec()-pose_start)
		var full = game.skier.animation.full_motion
		sampler_us.append(full.step_microseconds); fitting_us.append(full.fit_microseconds)
		interpolation_us.append(full.interpolation_microseconds)
		leg_fit_us.append(game.skier.leg_fit_microseconds); character_pose_us.append(game.skier.pose_microseconds)
		if timing:
			motion_step_us.append(full.step_microseconds); motion_interpolation_us.append(full.interpolation_microseconds)
			motion_fit_us.append(full.fit_microseconds); binding_us.append(game.skier.leg_fit_microseconds); character_us.append(game.skier.pose_microseconds)
		if not timing:
			var row = {"seconds":seconds,"tick":game.sim.ticks,"grounded":game.sim.grounded,"diagnostics":full.diagnostics.duplicate(),"clips":full.weights.duplicate(true),"joints":{},"requested":{},"rotations":{},"physical_position":str(game.sim.position)}
			row.steering = {"input":intent.steer,"requested_yaw_rad_s":game.sim.steering_requested_yaw,"applied_yaw_rad_s":game.sim.steering_applied_yaw,"transfer_factor":game.sim.steering_transfer_factor,"skid_factor":game.sim.steering_slip_factor,"stall_age_s":game.sim.steering_stall_age,"heading_rad":game.sim.heading,"ski_heading_rad":game.sim.skis[0].heading,"slip_rad":game.sim.slip_angle,"roll_rad":game.sim.body.roll,"normal_load_m_s2":game.sim.normal_load}
			for id in game.skier.rendered_joints:
				row.joints[id] = var_to_str(game.skier.rendered_joints[id])
				if full.requested_joints.has(id): row.requested[id] = var_to_str(full.requested_joints[id])
			for id in game.skier.rendered_rotations: row.rotations[id] = var_to_str(game.skier.rendered_rotations[id].get_rotation_quaternion())
			motion_trace.append(row)
		var center: Vector3 = game.sim.position+Vector3.UP*.85
		if request.name in ["flip_release","switch_flip"]: center = game.sim.position+game.sim.support_basis().y*.70
		var basis = Basis(Vector3.UP,heading)
		for view in (["chase"] if timing else (["chase","side","front"] if "--tuck-review" in OS.get_cmdline_user_args() else ["chase","side"])):
			var offset = Vector3(0,1.0,-5.4) if view=="chase" else (Vector3(3.8,.6,0) if view=="side" else Vector3(.15,.55,3.8))
			var camera: Camera3D = view_cameras[view]
			camera.position = center+basis*offset; camera.look_at(center); camera.make_current()
			if timing: continue
			if "--quick" in OS.get_cmdline_user_args() and frame_index%8!=0: continue
			label.text = "%s / %s / %s"%["PROCEDURAL" if before else "FULL CURVES",request.name.replace("_"," ").to_upper(),view.to_upper()]
			await process_frame; await RenderingServer.frame_post_draw
			var picture = root.get_texture().get_image()
			var folder = output+"/"+request.name+"_"+view
			DirAccess.make_dir_recursive_absolute(folder)
			picture.save_jpg(folder+"/%04d.jpg"%frame_index,.90)
			if frame_index%15==0: picture.save_png(folder+"/%04d.png"%frame_index)
		if timing: await physics_frame
		if frame_index%(60 if timing else 15)==0:
			captures.append({"frame":frame_index,"seconds":seconds,"phase":game.skier.animation.phase,"grounded":game.sim.grounded,"position":str(game.sim.position),"reserve":game.sim.impacts.reserve})
		if not timing:
			var q: Quaternion = game.sim.support_basis().get_rotation_quaternion()
			var rq: Quaternion = game.skier.global_basis.get_rotation_quaternion()
			orientation_trace.append({"seconds":seconds,"physical_q":[q.x,q.y,q.z,q.w],"rendered_q":[rq.x,rq.y,rq.z,rq.w],"grounded":game.sim.grounded,"assist_weight":game.sim.landing_assist.strength,"prediction_age":game.sim.landing_assist.prediction_age,"prediction_valid":game.sim.landing_assist.valid,"manual":[intent.steer,intent.air_pitch,intent.air_yaw]})
		if game.sim.crashed:
			if not request.get("expect_crash",false): failures.append(request.name+": "+game.sim.crash_reason)
			game.skier.ragdoll.start(game.sim)
			if not timing:
				for crash_frame in 60:
					await physics_frame
					game.skier.pose(game.sim)
					var focus: Vector3 = game.skier.ragdoll.focus()
					view_cameras.front.position = focus+basis*Vector3(.15,.55,3.8)
					view_cameras.front.look_at(focus)
					view_cameras.front.make_current()
					await RenderingServer.frame_post_draw
					var folder = output+"/"+request.name+"_crash"
					DirAccess.make_dir_recursive_absolute(folder)
					root.get_texture().get_image().save_jpg(folder+"/%04d.jpg"%crash_frame,.9)
			game.skier.ragdoll.stop()
			break
	measuring = false
	var row = {"scenario":request.name,"hops":hops,"landings":game.skier.animation.landing_events,"impact_speed_mps":max_impact,"airtime_s":game.sim.total_airtime,"crash":game.sim.crash_reason,"samples":captures}
	if not before:
		row.collision_events = game.skier.animation.collision_events
		row.minimum_clearance_margin_m = minimum_margin if is_finite(minimum_margin) else null
	row.max_air_step_deg = rad_to_deg(max_air_step)
	row.max_air_acceleration_rad_s2 = max_air_acceleration
	row.orientation_trace = orientation_trace
	preload("res://tests/test_report.gd").write(output+"/"+request.name+"_motion.json",JSON.stringify({"trace":motion_trace,"sampler_us":stats(sampler_us),"fitting_us":stats(fitting_us),"interpolation_us":stats(interpolation_us),"leg_fit_us":stats(leg_fit_us),"character_pose_us":stats(character_pose_us),"all_presentation_us":stats(final_pose_us)},"\t"))
	evidence.append(row)
	print("MOTION_NATIVE_CASE ",request.name," model=",game.sim.MODEL_VERSION," crash=",game.sim.crash_reason)

func natural_fixture() -> Dictionary:
	# Find a reproducible supported start that leaves the ACTUAL v13 surface
	# without a hop or a test teleport. Native originals/terrain stay unchanged.
	for face in field.faces:
		for z in [700.0,820.0,950.0,1100.0]:
			for x in [-.18*z,0.0,.18*z]:
				var p: Vector2 = face.to_world(Vector2(x,z))
				var origin = Vector3(p.x,field.sample(p.x,p.y).height,p.y)
				var trial = preload("res://scripts/core/ski_simulation.gd").new()
				trial.reset(origin,face.heading); trial.prime_contacts(game.world.ski_surface)
				trial.velocity = trial.support_basis().z*25.0
				var neutral = RiderInput.new()
				var supported = 0; var air = 0
				for tick in 360:
					trial.step(DT,neutral,game.world.ski_surface)
					if trial.crashed: break
					if trial.grounded: supported += 1
					elif supported>12: air += 1
				if air>12 and not trial.crashed: return {"origin":origin,"heading":face.heading,"speed":25.0}
	return {}

static func angular_delta(a: Basis,b: Basis) -> float:
	var q = (b*a.transposed()).get_rotation_quaternion().normalized()
	return 2.0*atan2(Vector3(q.x,q.y,q.z).length(),absf(q.w))

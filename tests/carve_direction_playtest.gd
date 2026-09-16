extends "res://tests/carve_direction_capture.gd"
## Render the same steering fixtures through the production chase camera.
var chase
var snow: MeshInstance3D
var caption: Label
var steep_entry = false
var baseline_motion = ""
var proportional = false
var residual = false
var capture_fps_limit = 120
const Residual = preload("res://tests/carve_residual_capture.gd")
const Proportional = preload("res://tests/carve_proportional_capture.gd")

func run():
	for arg in OS.get_cmdline_user_args():
		if arg=="--proportional": proportional=true
		if arg=="--residual": residual=true
		if arg.begins_with("--capture-fps-limit="): capture_fps_limit=clampi(int(arg.trim_prefix("--capture-fps-limit=")),1,120)
		if arg=="--steep-entry": steep_entry=true
		if arg.begins_with("--baseline-motion="): baseline_motion=arg.trim_prefix("--baseline-motion=")
	await super.run()

func capture_cases() -> Array:
	return Residual.CASES.duplicate() if residual else Proportional.CASES.duplicate() if proportional else super.capture_cases()

func intent_at(name: String, tick: int):
	return Residual.test_intent(name,tick) if residual else Proportional.test_intent(name,tick) if proportional else super.intent_at(name,tick)

func reset_sim(name: String, fixture: Dictionary):
	var sim=super.reset_sim(name,fixture)
	if residual:
		sim.velocity=sim.support_basis().z*(40.0 if "40" in name else 25.0)
		sim.reset_pose_history()
	return sim

func source_hashes() -> Dictionary:
	var hashes = super.source_hashes()
	if residual:hashes["res://tests/carve_residual_capture.gd"]=FileAccess.get_sha256("res://tests/carve_residual_capture.gd")
	hashes["res://tests/carve_direction_playtest.gd"] = FileAccess.get_sha256("res://tests/carve_direction_playtest.gd")
	if steep_entry: hashes["res://tests/carve_entry_capture.gd"] = FileAccess.get_sha256("res://tests/carve_entry_capture.gd")
	if proportional: hashes["res://tests/carve_proportional_capture.gd"] = FileAccess.get_sha256("res://tests/carve_proportional_capture.gd")
	if not baseline_motion.is_empty():
		hashes[baseline_motion] = FileAccess.get_sha256(baseline_motion)
		for dependency in ["downhill_posture.gd","action_posture.gd"]:
			var path=baseline_motion.get_base_dir()+"/"+dependency
			if FileAccess.file_exists(path):hashes[path]=FileAccess.get_sha256(path)
	return hashes

func capture_sequence(name: String, fixture: Dictionary):
	if DisplayServer.get_name()=="headless":
		report.failures.append("Playtest needs a renderer"); return
	if chase==null: setup_gameplay()
	if proportional and name.begins_with("mirror"): field.cross_gradient=-.22
	if steep_entry:
		field=preload("res://tests/carve_entry_capture.gd").EntrySlope.new()
		fixture.grade=.7;fixture.cross_gradient=0.0
	if not baseline_motion.is_empty():skier.animation.full_motion=load(baseline_motion).new()
	var normal: Vector3 = field.sample(0,0).normal
	var forward = Vector3.BACK.slide(normal).normalized()
	snow.basis = Basis(normal.cross(forward),normal,forward)
	var sim = reset_sim(name,fixture); skier.reset_animation(sim); chase.reset()
	var destination = output+"/"+name
	DirAccess.make_dir_recursive_absolute(destination)
	var trace = []
	for frame in (int(Residual.capture_frames(name)/2) if residual else 105):
		for sub in 4:
			var input = intent_at(name,frame*4+sub)
			sim.step(DT,input,field); skier.step_animation(DT,sim,input,field)
		skier.pose(sim,1.0)
		chase.update_camera(sim,field,sim.position,1.0/30.0)
		var steer: float = intent_at(name,frame*4+3).steer
		caption.text = "%s | steer %+.2f | %.2f s"%[name,steer,sim.ticks*DT]
		await process_frame; await RenderingServer.frame_post_draw
		var picture = root.get_texture().get_image()
		assert(picture.get_size()==Vector2i(1280,720))
		picture.save_jpg(destination+"/%04d.jpg"%frame,.94)
		trace.append({"frame":frame,"tick":sim.ticks,"input":steer,"camera":pack(chase.global_transform),
			"physical_position":pack(sim.position),"physical_bank":sim.body.roll,"diagnostics":pack(skier.animation.full_motion.diagnostics)})
		if sim.crashed: report.failures.append(name+": "+sim.crash_reason); break
	preload("res://tests/test_report.gd").write(output+"/"+name+".json",JSON.stringify({"frames":trace,"fixture":fixture},"\t"))
	report.scenarios.append({"name":name,"frames":trace.size(),"fixture":pack(fixture)})
	report.capture_fps = 30
	report.render_fps_cap = capture_fps_limit
	if residual:report.notes=["240 unsteered warm-up ticks, then the residual regression inputs.","Fixed 120 Hz solver and 30 Hz captured chronology; wall-clock render cap changes capture throughput only."]
	report.pixels = [1280,720]
	report.scope = "Live production solver, skier and chase camera on analytic snow planes; unranked visual reproduction, no full-mountain scenery or performance claim."
	print("CARVE_DIRECTION_PLAYTEST ",name," frames=",trace.size())

func setup_gameplay():
	root.size = Vector2i(1280,720); root.title = "Alpine Apex | Steering direction regression"
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO; root.content_scale_factor = 1.0
	Engine.max_fps = capture_fps_limit
	var env = WorldEnvironment.new(); env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("9ac2df")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("e7efff"); env.environment.ambient_light_energy = .8
	scene.add_child(env)
	var sun = DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-40,-25,0)
	sun.light_energy = 1.4; sun.shadow_enabled = true; scene.add_child(sun)
	snow = MeshInstance3D.new(); var plane = PlaneMesh.new(); plane.size = Vector2(1500,1500); snow.mesh = plane
	var material = StandardMaterial3D.new(); material.albedo_color = Color("ecf4ff"); material.roughness = .9
	snow.material_override = material; scene.add_child(snow)
	chase = preload("res://scripts/presentation/chase_camera.gd").new(); scene.add_child(chase); chase.current = true
	var overlay = CanvasLayer.new(); root.add_child(overlay); caption = Label.new(); overlay.add_child(caption)
	caption.position = Vector2(18,14); caption.add_theme_font_size_override("font_size",22)
	caption.add_theme_color_override("font_color",Color.BLACK)

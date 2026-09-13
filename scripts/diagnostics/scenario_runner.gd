extends SceneTree
## Production solver and final poses on retained 4 m fixtures; no session/records.
const Probe = preload("res://tests/small_landing_probe.gd")
const Evidence = preload("res://scripts/diagnostics/scenario_evidence.gd")
const Pose = preload("res://scripts/diagnostics/case_pose.gd")
const DT = 1.0/120.0
var output = ""
var scenario = ""
var capture = false
var capture_fps = 15
var seconds = -1.0
var view = "side"
var scene: Node3D
var skier
var camera: Camera3D
var riding_camera

func _initialize() -> void: call_deferred("run")
func fail(message: String) -> void: printerr("SCENARIO_ERROR ",message); quit(2)

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--scenario="): scenario=arg.trim_prefix("--scenario=")
		elif arg.begins_with("--output="): output=arg.trim_prefix("--output=")
		elif arg.begins_with("--seconds="): seconds=arg.trim_prefix("--seconds=").to_float()
		elif arg.begins_with("--capture-fps="): capture_fps=arg.trim_prefix("--capture-fps=").to_int()
		elif arg.begins_with("--view="): view=arg.trim_prefix("--view=")
		elif arg=="--capture": capture=true
		else: fail("Unknown scenario option: "+arg); return
	var catalog = JSON.parse_string(FileAccess.get_file_as_string("res://scripts/diagnostics/scenarios.json"))
	if not catalog is Dictionary or catalog.get("schema")!=1 or not catalog.scenarios.has(scenario): fail("Unknown scenario/catalog"); return
	var spec: Dictionary = catalog.scenarios[scenario]
	if seconds<0: seconds=spec.seconds
	if not is_finite(seconds) or seconds<.25 or seconds>60 or capture_fps<1 or capture_fps>30 or view not in ["side","chase"]: fail("Invalid duration, capture rate or view"); return
	if capture and DisplayServer.get_name()=="headless": fail("Capture requires a rendered run"); return
	if output.is_empty() or DirAccess.dir_exists_absolute(output): fail("Choose a fresh output directory"); return
	if DirAccess.make_dir_recursive_absolute(output)!=OK: fail("Cannot create output"); return
	var start = Time.get_ticks_usec()
	var source = Evidence.identity()
	var fixture: Dictionary = spec.fixture.duplicate(true)
	var field = preload("res://scripts/diagnostics/test_map.gd").create(spec.map,fixture)
	if field==null: fail("Missing or invalid selected map: "+str(spec.get("map",""))); return
	var sim = Probe.rider(field,fixture)
	var report = Evidence.envelope(scenario,{"fixture":fixture,"ticks":roundi(seconds/DT),"input_producer":"tests/small_landing_probe.gd"},source)
	report.identity.model=sim.MODEL_VERSION
	report.tuning=Evidence.Recorder.tuning_data(sim.tuning)
	report.requested_seconds=seconds; report.metrics=spec.metrics
	report.map = field.fixture_descriptor()
	report.camera={"view":view,"resolution":[1280,720],"fov":48,"capture_fps":capture_fps}
	if capture: await prepare_scene(field,sim)
	report.setup_seconds=(Time.get_ticks_usec()-start)/1000000.0
	var rows: Array = [Evidence.sample(sim,0,null,field)]
	var previous: Dictionary = rows[0].state
	var next_capture=1
	var stop_reason="duration"
	var sample_start=Time.get_ticks_usec()
	if capture: await capture_frame(report,sim,0,field)
	for tick in roundi(seconds/DT):
		var intent=Probe.input(tick,fixture)
		sim.step(DT,intent,field)
		if capture: skier.step_animation(DT,sim,intent,field)
		var row=Evidence.sample(sim,tick+1,intent,field)
		row.events=Evidence.events(previous,row.state)
		if sim.jump_executed: row.events.append("jump")
		for event in row.events: report.events.append({"tick":tick+1,"name":event})
		rows.append(row); previous=row.state
		if not sim.position.is_finite() or not sim.velocity.is_finite(): report.failures.append("Non-finite solver state"); stop_reason="invalid_state"; break
		if capture and ((tick+1)*capture_fps>=next_capture*120 or tick+1==roundi(seconds/DT) or not row.events.is_empty()):
			await capture_frame(report,sim,tick+1,field)
			if (tick+1)*capture_fps>=next_capture*120: next_capture+=1
		elif (tick+1)%120==0: await process_frame
		if not field.ski_bounds().has_point(Vector2(sim.position.x,sim.position.z)):
			report.failures.append("Fixture boundary reached before required coverage")
			stop_reason="fixture_boundary"; break
		if sim.crashed:
			report.failures.append("Unexpected crash before required duration")
			stop_reason="crash"; break
	report.execution_seconds=(Time.get_ticks_usec()-sample_start)/1000000.0
	report.actual_ticks=rows[-1].tick; report.actual_seconds=rows[-1].time
	report.stop_reason=stop_reason; report.stable_sources=source.sources==Evidence.identity().sources
	if not report.stable_sources: report.failures.append("Source changed during the run")
	report.status="complete" if report.failures.is_empty() else "failed"
	if Evidence.write(output+"/telemetry.json",rows)!=OK or Evidence.write(output+"/manifest.json",report)!=OK: fail("Cannot flush evidence"); return
	print("SCENARIO_RESULT ",JSON.stringify({"scenario":scenario,"output":output,"status":report.status,"ticks":report.actual_ticks,"stop":stop_reason}))
	if scene: scene.queue_free(); await process_frame
	quit(0 if report.failures.is_empty() else 1)

func prepare_scene(field,sim) -> void:
	root.size=Vector2i(1280,720); root.content_scale_size=root.size; root.unfocusable=true
	scene=Node3D.new(); root.add_child(scene)
	var light=DirectionalLight3D.new(); light.rotation_degrees=Vector3(-45,-25,0); light.light_energy=2; light.shadow_enabled=true; scene.add_child(light)
	var env=WorldEnvironment.new(); env.environment=Environment.new()
	env.environment.background_mode=Environment.BG_COLOR; env.environment.background_color=Color(.38,.49,.62)
	env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR; env.environment.ambient_light_color=Color(.8,.87,1); env.environment.ambient_light_energy=.7; scene.add_child(env)
	var builder=SurfaceTool.new(); builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Same triangulation and samples as support, across the bounded fixture.
	for z in range(int(field.Z_MIN),int(field.bounds().end.y),4):
		for x in range(int(field.X_MIN),int(field.bounds().end.x),4):
			for offset in [Vector2(0,0),Vector2(4,0),Vector2(0,4),Vector2(4,0),Vector2(4,4),Vector2(0,4)]:
				var p=Vector2(x,z)+offset; var sample: Dictionary=field.sample(p.x,p.y)
				builder.set_color(Color(.84,.89,.95) if (x/4+z/4)%2==0 else Color(.79,.85,.92))
				builder.set_normal(sample.normal); builder.add_vertex(Vector3(p.x,sample.height,p.y))
	var mesh=MeshInstance3D.new(); mesh.mesh=builder.commit()
	var material=StandardMaterial3D.new(); material.vertex_color_use_as_albedo=true; material.cull_mode=BaseMaterial3D.CULL_DISABLED; mesh.material_override=material; scene.add_child(mesh)
	skier=preload("res://scripts/presentation/skier_visual.gd").new(); skier.preview_only=true; scene.add_child(skier)
	camera=Camera3D.new(); camera.fov=48; camera.near=.05; scene.add_child(camera)
	riding_camera=preload("res://scripts/presentation/chase_camera.gd").new(); scene.add_child(riding_camera)
	await process_frame
	skier.reset_animation(sim)

func capture_frame(report: Dictionary,sim,tick: int,field) -> void:
	skier.pose(sim,1.0)
	var target: Vector3=sim.position+sim.support_basis().y*.65
	camera.position=target+sim.support_basis()*Vector3(3.8,1,-1.5); camera.look_at(target); camera.make_current()
	if view=="chase": riding_camera.update_camera(sim,field,sim.position,1.0/capture_fps); riding_camera.make_current()
	var active_camera: Camera3D=riding_camera if view=="chase" else camera
	await process_frame
	await RenderingServer.frame_post_draw
	var name="frame_%06d.jpg"%tick
	if root.get_texture().get_image().save_jpg(output+"/"+name,.88)!=OK: report.failures.append("Cannot save "+name); return
	report.captures.append({"tick":tick,"time":tick/120.0,"path":name,"pose":Pose.capture(skier),"camera":Pose.camera_capture(active_camera),"state_origin":"current_solver"})

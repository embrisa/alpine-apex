extends SceneTree
## Matched 15-second controller-like turns with the production skier/camera.
const Probe=preload("res://tests/firm_carve_suite.gd")
const Visual=preload("res://scripts/presentation/skier_visual.gd")
var output=""; var reference=false; var depth=.02; var view="chase"
func _initialize(): call_deferred("run")
static func command(t: float) -> RiderInput:
	var input=RiderInput.new()
	input.tuck=1.0 if t<5.0 or t>=13.0 else 0.0
	if t>=1.0 and t<4.0:
		input.steer=Probe.DIAGONAL*(1.0 if t<2.5 else -1.0); input.tuck=Probe.DIAGONAL
	elif t>=5.0 and t<9.0: input.steer=1.0 if t<7.0 else -1.0
	elif t>=10.0 and t<12.0: input.steer=.85*(1.0 if fmod(t-10.0,1.0)<.5 else -1.0)
	elif t>=12.0 and t<13.0: input.steer=.2
	return input
func run():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
		if arg.begins_with("--depth="): depth=float(arg.trim_prefix("--depth="))
		if arg.begins_with("--view="): view=arg.trim_prefix("--view=")
		if arg=="--reference": reference=true
	if output.is_empty() or FileAccess.file_exists(output+"/results.json"): printerr("Choose fresh output"); quit(2); return
	DirAccess.make_dir_recursive_absolute(output)
	var hashes={}
	var sources=["scripts/core/ski_simulation.gd","scripts/core/ski_tuning.gd","scripts/core/rider_body.gd","config/ski_default.tres","scripts/presentation/skier_visual.gd","scripts/presentation/skier_full_motion.gd","scripts/presentation/skier_animation.gd","scripts/presentation/skier_anatomy.gd","scripts/presentation/action_posture.gd","scripts/presentation/pole_push_pose.gd","scripts/presentation/chase_camera.gd","assets/animation/steep_ski_motion.res","assets/graphics/models/skier_v7.glb","tests/firm_carve_capture.gd"]
	if reference:
		for path in ["ski_simulation.gd","rider_body.gd","reference_tuning.gd"]: sources.append("artifacts/firm_carve/baseline-source/"+path)
	for path in sources:
		hashes[path]=FileAccess.get_sha256("res://"+path)
	root.size=Vector2i(1280,720); root.content_scale_size=root.size; root.unfocusable=true
	var scene=Node3D.new(); root.add_child(scene)
	var light=DirectionalLight3D.new(); light.rotation_degrees=Vector3(-45,-25,0); light.light_energy=2; light.shadow_enabled=true; scene.add_child(light)
	var environment=WorldEnvironment.new(); environment.environment=Environment.new(); environment.environment.background_mode=Environment.BG_COLOR
	environment.environment.background_color=Color(.38,.49,.62); environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color=Color(.8,.87,1); environment.environment.ambient_light_energy=.7; scene.add_child(environment)
	var field=Probe.SnowPlane.new(); field.depth=depth
	var st=SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z in range(-120,720,4):
		for x in range(-480,480,4):
			for offset in [Vector2(0,0),Vector2(4,0),Vector2(0,4),Vector2(4,0),Vector2(4,4),Vector2(0,4)]:
				var p=Vector2(x,z)+offset; var s=field.sample(p.x,p.y)
				st.set_color(Color(.84,.89,.95) if (x/4+z/4)%2==0 else Color(.79,.85,.92)); st.set_normal(s.normal); st.add_vertex(Vector3(p.x,s.height,p.y))
	var mesh=MeshInstance3D.new(); mesh.mesh=st.commit(); var material=StandardMaterial3D.new(); material.vertex_color_use_as_albedo=true; material.cull_mode=BaseMaterial3D.CULL_DISABLED
	mesh.material_override=material; scene.add_child(mesh)
	var skier=Visual.new(); skier.preview_only=true; scene.add_child(skier)
	var camera=Camera3D.new(); camera.fov=48; camera.near=.05; scene.add_child(camera)
	var chase=preload("res://scripts/presentation/chase_camera.gd").new(); scene.add_child(chase)
	var model=load("res://artifacts/firm_carve/baseline-source/ski_simulation.gd") if reference else Probe.Sim
	var tuning=load("res://config/ski_default.tres").duplicate(true)
	if reference:
		tuning=load("res://artifacts/firm_carve/baseline-source/reference_tuning.gd").new()
	var sim=model.new(tuning); sim.reset(Vector3.ZERO); sim.prime_contacts(field); sim.velocity=sim.support_basis().z*120/3.6; sim.effective_tuck=1.0
	skier.reset_animation(sim)
	var rows=[]; var poses=[]; var max_joint_step=0.0; var previous={}; var recovery_entries=0; var recovering=false
	for frame in 450:
		for substep in 4:
			var input=command(sim.ticks*Probe.DT); sim.step(Probe.DT,input,field); skier.step_animation(Probe.DT,sim,input,field)
			recovery_entries+=int(sim.body.recovering_pose and not recovering); recovering=sim.body.recovering_pose
			skier.pose(sim,1.0)
			if not previous.is_empty():
				for key in skier.rendered_joints: max_joint_step=maxf(max_joint_step,previous[key].distance_to(skier.rendered_joints[key]))
			previous=skier.rendered_joints.duplicate()
		var target: Vector3=sim.position+sim.support_basis().y*.65
		if view=="chase": chase.update_camera(sim,field,sim.position,4*Probe.DT); chase.make_current()
		else: camera.position=target+sim.support_basis()*Vector3(4.8,1.1,-1.5); camera.look_at(target); camera.make_current()
		rows.append({"tick":sim.ticks,"position":[sim.position.x,sim.position.y,sim.position.z],"speed":sim.speed_kmh(),"roll":sim.body.roll,"slip":sim.slip_angle,"recovering":recovering})
		var pose={"frame":frame,"tick":sim.ticks,"grounded":sim.grounded,"root":pack(skier.global_transform),"poles":[],"final_bones":[]}
		for pole in skier.poles: pose.poles.append(pack(pole.global_transform))
		for bone in skier.skeleton.get_bone_count(): pose.final_bones.append(pack(skier.skeleton.get_bone_global_pose(bone)))
		poses.append(pose)
		await process_frame; await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_jpg(output+"/frame_%03d.jpg"%frame,.9)
	var stable=true
	for path in hashes: stable=stable and hashes[path]==FileAccess.get_sha256("res://"+path)
	FileAccess.open(output+"/results.json",FileAccess.WRITE).store_string(JSON.stringify({"model":model.MODEL_VERSION,"reference":reference,"depth":depth,"view":view,"engine":Engine.get_version_info().string,"sources":hashes,"stable_sources":stable,"ticks":sim.ticks,"crash":sim.crash_reason,"rows":rows,"recovery_entries":recovery_entries,"max_joint_step":max_joint_step,"human_acceptance":false}))
	DirAccess.make_dir_recursive_absolute(output+"/capture")
	var captured_sources={}
	for path in hashes: captured_sources["res://"+path]=hashes[path]
	FileAccess.open(output+"/capture/manifest.json",FileAccess.WRITE).store_string(JSON.stringify({"stable_sources":stable,"sources":captured_sources,"failures":[],"model":model.MODEL_VERSION,"reference":reference}))
	FileAccess.open(output+"/capture/firm_carve.json",FileAccess.WRITE).store_string(JSON.stringify({"frames":poses}))
	print("FIRM_CARVE_CAPTURE ",output," ticks=",sim.ticks," stable=",stable," crash=",sim.crash_reason)
	scene.queue_free(); await process_frame; quit(0 if stable and not sim.crashed else 1)

static func pack(value: Transform3D) -> Dictionary:
	return {"origin":[value.origin.x,value.origin.y,value.origin.z],"basis":[[value.basis.x.x,value.basis.x.y,value.basis.x.z],[value.basis.y.x,value.basis.y.y,value.basis.y.z],[value.basis.z.x,value.basis.z.y,value.basis.z.z]]}

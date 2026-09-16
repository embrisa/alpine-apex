extends SceneTree
## Native production skier on the exact mountain section used by contact checks.
const Probe=preload("res://tests/terrain_settle_probe.gd")
var output=""
var reference=""
var view="side"
func _initialize(): call_deferred("run")
func run():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output="res://"+arg.trim_prefix("--output=")
		if arg.begins_with("--reference-assist="): reference="res://"+arg.trim_prefix("--reference-assist=")
		if arg.begins_with("--view="): view=arg.trim_prefix("--view=")
	if output.is_empty() or FileAccess.file_exists(output+"/results.json"): printerr("Choose fresh --output"); quit(2); return
	DirAccess.make_dir_recursive_absolute(output)
	var sources=source_hashes()
	var field=preload("res://tests/validation_mountain.gd").load_standard()
	if field==null: quit(2); return
	root.size=Vector2i(1280,720); root.content_scale_size=root.size; root.unfocusable=true
	var scene=Node3D.new(); root.add_child(scene)
	var light=DirectionalLight3D.new(); light.rotation_degrees=Vector3(-45,-25,0); light.light_energy=2; light.shadow_enabled=true; scene.add_child(light)
	var env=WorldEnvironment.new(); env.environment=Environment.new(); env.environment.background_mode=Environment.BG_COLOR
	env.environment.background_color=Color(.38,.49,.62); env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color=Color(.8,.87,1); env.environment.ambient_light_energy=.7; scene.add_child(env)
	# Physical 4 m triangles; no height smoothing, second surface or scenery force.
	var st=SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z in range(-1440,-1000,4):
		for x in range(1400,2040,4):
			for offset in [Vector2(0,0),Vector2(4,0),Vector2(0,4),Vector2(4,0),Vector2(4,4),Vector2(0,4)]:
				var p=Vector2(x,z)+offset; var s=field.sample(p.x,p.y)
				st.set_color(Color(.84,.89,.95) if (x/4+z/4)%2==0 else Color(.79,.85,.92))
				st.set_normal(s.normal); st.add_vertex(Vector3(p.x,s.height,p.y))
	var terrain=MeshInstance3D.new(); terrain.mesh=st.commit()
	var mat=StandardMaterial3D.new(); mat.vertex_color_use_as_albedo=true; mat.cull_mode=BaseMaterial3D.CULL_DISABLED
	terrain.material_override=mat; scene.add_child(terrain)
	var skier=preload("res://scripts/presentation/skier_visual.gd").new(); skier.preview_only=true; scene.add_child(skier)
	var camera=Camera3D.new(); camera.fov=48; camera.near=.05; scene.add_child(camera); camera.make_current()
	var chase=preload("res://scripts/presentation/chase_camera.gd").new(); scene.add_child(chase); chase.close_view=view=="first_person"
	var sim=Probe.rider(field,Probe.ROUGH,reference); skier.reset_animation(sim)
	var intent=Probe.input(); var rows: Array=[]; var pose_frames: Array=[]
	for frame in 450:
		for substep in 4:
			sim.step(Probe.DT,intent,field); skier.step_animation(Probe.DT,sim,intent,field)
			rows.append(Probe.Hop.sample(sim,field))
		skier.pose(sim,1.0); skier.body_pivot.visible=view!="first_person"
		var target: Vector3=sim.position+sim.support_basis().y*.65
		camera.position=target+sim.support_basis()*Vector3(4.8,1.1,-1.5); camera.look_at(target)
		if view in ["chase","first_person"]: chase.update_camera(sim,field,sim.position,4*Probe.DT); chase.make_current()
		if frame<240: continue # Same 8 s ordinary-input lead-in; capture final 7 s.
		var pose={"frame":frame-240,"tick":sim.ticks,"grounded":sim.grounded,"root":pack(skier.global_transform),"poles":[],"final_bones":[]}
		for pole in skier.poles: pose.poles.append(pack(pole.global_transform))
		for bone in skier.skeleton.get_bone_count(): pose.final_bones.append(pack(skier.skeleton.get_bone_global_pose(bone)))
		pose_frames.append(pose)
		await process_frame
		if DisplayServer.get_name()!="headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_jpg(output+"/frame_%03d.jpg"%(frame-240),.9)
	var report={"fixture":Probe.ROUGH,"ticks":sim.ticks,"crash":sim.crash_reason,"rows":rows,"model":Probe.Hop.Sim.MODEL_VERSION,"reference_assist":reference,"native":DisplayServer.get_name()!="headless","engine":Engine.get_version_info(),"sources":sources,"stable_sources":sources==source_hashes(),"view":view,"height":field.height_checksum,"rendered_scenery":false,"human_acceptance":false}
	preload("res://tests/test_report.gd").write(output+"/results.json",JSON.stringify(report))
	DirAccess.make_dir_recursive_absolute(output+"/capture")
	preload("res://tests/test_report.gd").write(output+"/capture/manifest.json",JSON.stringify({"stable_sources":report.stable_sources,"sources":sources,"failures":[]}))
	preload("res://tests/test_report.gd").write(output+"/capture/landing.json",JSON.stringify({"frames":pose_frames}))
	print("TERRAIN_SETTLE_CAPTURE ",output," ticks=",sim.ticks," frames=",pose_frames.size()," stable=",report.stable_sources)
	scene.queue_free(); await process_frame; quit()
func pack(value: Transform3D):
	return {"origin":[value.origin.x,value.origin.y,value.origin.z],"basis":[[value.basis.x.x,value.basis.x.y,value.basis.x.z],[value.basis.y.x,value.basis.y.y,value.basis.y.z],[value.basis.z.x,value.basis.z.y,value.basis.z.z]]}
func source_hashes():
	var result={}
	for file in ["scripts/core/ski_simulation.gd","scripts/core/snow_contact_assist.gd","scripts/core/ski_contact.gd","scripts/core/snow_contact_response.gd","scripts/core/snow_crush_contact.gd","scripts/core/ski_tuning.gd","scripts/core/rider_body.gd","config/ski_default.tres","scripts/presentation/skier_visual.gd","scripts/presentation/skier_animation.gd","scripts/presentation/skier_full_motion.gd","scripts/presentation/pole_push_pose.gd","scripts/presentation/chase_camera.gd","assets/animation/apex_ski_motion.gd","assets/animation/steep_ski_motion.res","assets/graphics/models/skier_v7.glb","tests/terrain_settle_probe.gd","tests/terrain_settle_capture.gd"]:
		result["res://"+file]=FileAccess.get_sha256("res://"+file)
	if not reference.is_empty(): result[reference]=FileAccess.get_sha256(reference)
	return result

extends SceneTree
## Final production skier on a bounded 4 m fixture, with no record/input owner.
const Probe = preload("res://tests/small_landing_probe.gd")
var output = ""
var view = "side"
var fixture = {"amplitude":0.0,"wavelength":32.0,"depth":.2,"kmh":60.0,"hop":true,"seconds":4.0}
func _initialize(): call_deferred("run")
func run():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output="res://"+arg.trim_prefix("--output=").trim_prefix("res://")
		if arg.begins_with("--view="): view=arg.trim_prefix("--view=")
		if arg=="--tuck": fixture.tuck=1.0
		if arg=="--uneven": fixture={"amplitude":.6,"wavelength":16.0,"depth":.06,"angle":.5,"kmh":120.0,"steer":.15,"tuck":1.0,"hop":true,"seconds":4.0}
	if output.is_empty() or FileAccess.file_exists(output+"/results.json"): printerr("Use a fresh --output"); quit(2); return
	DirAccess.make_dir_recursive_absolute(output)
	var sources=source_hashes()
	root.size=Vector2i(1280,720); root.content_scale_size=root.size
	root.unfocusable=true
	var scene=Node3D.new(); root.add_child(scene)
	var light=DirectionalLight3D.new(); light.rotation_degrees=Vector3(-45,-25,0); light.light_energy=2.0; light.shadow_enabled=true; scene.add_child(light)
	var env=WorldEnvironment.new(); env.environment=Environment.new()
	env.environment.background_mode=Environment.BG_COLOR; env.environment.background_color=Color(.38,.49,.62)
	env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR; env.environment.ambient_light_color=Color(.8,.87,1); env.environment.ambient_light_energy=.7
	scene.add_child(env)
	var field=Probe.surface(fixture)
	var surface_tool=SurfaceTool.new(); surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z in range(-20,220,4):
		for x in range(-48,48,4):
			for offset in [Vector2(0,0),Vector2(4,0),Vector2(0,4),Vector2(4,0),Vector2(4,4),Vector2(0,4)]:
				var p=Vector2(x,z)+offset; var sample=field.sample(p.x,p.y)
				surface_tool.set_color(Color(.84,.89,.95) if (x/4+z/4)%2==0 else Color(.79,.85,.92))
				surface_tool.set_normal(sample.normal); surface_tool.add_vertex(Vector3(p.x,sample.height,p.y))
	var mesh=MeshInstance3D.new(); mesh.mesh=surface_tool.commit()
	var mat=StandardMaterial3D.new(); mat.vertex_color_use_as_albedo=true; mat.cull_mode=BaseMaterial3D.CULL_DISABLED; mesh.material_override=mat; scene.add_child(mesh)
	var skier=preload("res://scripts/presentation/skier_visual.gd").new(); skier.preview_only=true; scene.add_child(skier)
	var camera=Camera3D.new(); camera.fov=48.0; camera.near=.05; scene.add_child(camera); camera.make_current()
	var riding_camera=preload("res://scripts/presentation/chase_camera.gd").new(); scene.add_child(riding_camera)
	riding_camera.close_view=view=="first_person"
	var sim=Probe.rider(field,fixture); skier.reset_animation(sim)
	var rows: Array=[]; var contact_tick=-1; var last_joints: Dictionary={}; var max_step=0.0
	for frame in 240:
		for substep in 2:
			var tick=frame*2+substep; var intent=Probe.input(tick,fixture)
			sim.step(Probe.DT,intent,field); skier.step_animation(Probe.DT,sim,intent,field)
			if contact_tick<0 and sim.time_since_landing==0.0: contact_tick=sim.ticks
		skier.pose(sim,1.0)
		skier.body_pivot.visible=view!="first_person" # Match the production camera owner.
		var target: Vector3=sim.position+sim.support_basis().y*.65
		camera.position=target+sim.support_basis()*Vector3(3.8,1.0,-1.5)
		camera.look_at(target)
		if view in ["chase","first_person"]:
			riding_camera.update_camera(sim,field,sim.position,2*Probe.DT)
			riding_camera.make_current()
		var feet: Vector3=(skier.rendered_joints.RightFoot+skier.rendered_joints.LeftFoot)*.5
		var hip: Vector3=skier.rendered_joints.Hips-feet
		if not last_joints.is_empty():
			for key in skier.rendered_joints: max_step=maxf(max_step,last_joints[key].distance_to(skier.rendered_joints[key]))
		last_joints=skier.rendered_joints.duplicate()
		var row=Probe.sample(sim,field)
		row.hip_height=hip.y; row.hip_forward=hip.z; row.impact_drop=skier.animation.current.impact_drop
		row.absorbed=skier.animation.current.absorbed; row.impact_posture=skier.animation.full_motion.impact_posture
		row.animation_events=skier.animation.landing_events; rows.append(row)
		row.frame=frame; row.root=pack_transform(skier.global_transform)
		row.poles=skier.poles.map(func(pole): return pack_transform(pole.global_transform))
		row.final_bones=[]
		for bone in skier.skeleton.get_bone_count(): row.final_bones.append(pack_transform(skier.skeleton.get_bone_global_pose(bone)))
		await process_frame
		if DisplayServer.get_name()!="headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_jpg(output+"/frame_%03d.jpg"%frame,.88)
	var report={"fixture":fixture,"model":Probe.Sim.MODEL_VERSION,"contact_tick":contact_tick,"max_joint_step_60hz":max_step,"rows":rows,"native":DisplayServer.get_name()!="headless","engine":Engine.get_version_info(),"human_acceptance":false,"sources":sources,"stable_sources":sources==source_hashes(),"view":view}
	FileAccess.open(output+"/results.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	DirAccess.make_dir_recursive_absolute(output+"/capture")
	FileAccess.open(output+"/capture/manifest.json",FileAccess.WRITE).store_string(JSON.stringify({"stable_sources":report.stable_sources,"sources":sources,"failures":[]}))
	FileAccess.open(output+"/capture/landing.json",FileAccess.WRITE).store_string(JSON.stringify({"frames":rows}))
	print("SMALL_LANDING_CAPTURE ",output," contact=",contact_tick," max_joint_step=",max_step)
	scene.queue_free(); await process_frame; quit()

func pack_transform(value: Transform3D) -> Dictionary:
	return {"origin":[value.origin.x,value.origin.y,value.origin.z],"basis":[[value.basis.x.x,value.basis.x.y,value.basis.x.z],[value.basis.y.x,value.basis.y.y,value.basis.y.z],[value.basis.z.x,value.basis.z.y,value.basis.z.z]]}

func source_hashes() -> Dictionary:
	var hashes={}
	for path in ["scripts/core/ski_simulation.gd","scripts/core/ski_contact.gd","scripts/core/snow_contact_assist.gd","scripts/core/snow_contact_response.gd","scripts/core/rider_body.gd","config/ski_default.tres","scripts/presentation/skier_animation.gd","scripts/presentation/skier_animation_tuning.gd","scripts/presentation/skier_full_motion.gd","scripts/presentation/skier_visual.gd","scripts/presentation/action_posture.gd","scripts/presentation/skier_anatomy.gd","scripts/presentation/chase_camera.gd","assets/animation/apex_ski_motion.gd","assets/animation/steep_ski_motion.res","assets/graphics/models/skier_v7.glb","tests/small_landing_probe.gd","tests/small_landing_capture.gd"]:
		hashes["res://"+path]=FileAccess.get_sha256("res://"+path)
	return hashes

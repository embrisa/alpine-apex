extends SceneTree
## One shared real 120 Hz solver; two independent production presentation chains.
const Sim=preload("res://scripts/core/ski_simulation.gd")
const Intent=preload("res://scripts/core/rider_input.gd")
const TestPlane=preload("res://tests/physics_suite.gd").TestPlane
const Visual=preload("res://scripts/presentation/skier_visual.gd")
const Motion=preload("res://art_source/animation/cascadeur_evaluation_20260910_r6/evaluation_motion.gd")
const Equipment=preload("res://scripts/presentation/skier_equipment.gd")
const BASE="res://art_source/animation/cascadeur_evaluation_20260910_r6/"
const REV="res://artifacts/pose_review/revisions/cascadeur-20260910-r6-"
const DT=1.0/120.0
const CASES=["straight","compression","steering_left","steering_right","tuck_overlap"]
var visuals=[]
var import_report={}
var rigs=[]
var failures=[]
var stage_trace=[]
var chase=preload("res://scripts/presentation/chase_camera.gd").new()
func _initialize():call_deferred("run")
func pack(v):
	if v is Vector3:return [v.x,v.y,v.z]
	if v is Quaternion:return [v.x,v.y,v.z,v.w]
	if v is Basis:return [pack(v.x),pack(v.y),pack(v.z)]
	if v is Transform3D:return {"origin":pack(v.origin),"basis":pack(v.basis)}
	if v is Dictionary:
		var out={};for k in v:out[k]=pack(v[k])
		return out
	if v is Array:
		var out=[];for item in v:out.append(pack(item))
		return out
	return v
func write(path,data):FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(data,"\t"))
func hashes():
	var h={}
	for directory in ["res://scripts/core","res://scripts/presentation","res://config"]:hash_dir(directory,h)
	for file in ["project.godot","assets/animation/steep_ski_motion.res","tests/physics_suite.gd"]:h["res://"+file]=FileAccess.get_sha256("res://"+file)
	for name in ["skier_v7","ski_detailed_v1","ski_detailed_v1_left","binding_detailed_v2","skier_v7_boot_right","skier_v7_boot_left","pole_detailed_v1"]:
		var file="res://assets/graphics/models/"+name+".glb";h[file]=FileAccess.get_sha256(file)
	for name in ["gameplay_capture.gd","evaluation_motion.gd","ready_compression_r6_animation.glb"]:h[BASE+name]=FileAccess.get_sha256(BASE+name)
	return h
func hash_dir(path,h):
	for name in DirAccess.get_files_at(path):
		if name.get_extension() in ["gd","json","tres","gdshader","gdshaderinc"]:h[path+"/"+name]=FileAccess.get_sha256(path+"/"+name)
	for name in DirAccess.get_directories_at(path):hash_dir(path+"/"+name,h)
func load_candidate():
	var doc=GLTFDocument.new();var state=GLTFState.new()
	assert(doc.append_from_file(BASE+"ready_compression_r6_animation.glb",state)==OK)
	var imported=doc.generate_scene(state);root.add_child(imported)
	var skeleton:Skeleton3D=imported.find_children("*","Skeleton3D",true,false)[0]
	var player:AnimationPlayer=imported.find_children("*","AnimationPlayer",true,false)[0]
	assert(skeleton.get_bone_count()==24 and imported.find_children("*","MeshInstance3D",true,false).is_empty())
	player.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var name="";for item in player.get_animation_list():
		if item!="RESET":name=item
	assert(is_equal_approx(player.get_animation(name).length,2.0));player.play(name);player.advance(0)
	var lib=Motion.library;var visual=visuals[0];var values=PackedFloat32Array();var max_fk=0.0;var max_rest=0.0
	var prior=[]
	for frame in 121:
		player.seek(frame/60.0,true);skeleton.force_update_all_bone_transforms()
		var lp=skeleton.get_bone_global_pose(skeleton.find_bone("LeftFoot"));var rp=skeleton.get_bone_global_pose(skeleton.find_bone("RightFoot"))
		var support=(lp.basis*visual.rest[visual.bone_ids.LeftFoot].basis.inverse()).orthonormalized().slerp((rp.basis*visual.rest[visual.bone_ids.RightFoot].basis.inverse()).orthonormalized(),.5)
		var center=(lp.origin+rp.origin)*.5;var globals=[];var positions=[];var this_frame=[]
		for i in lib.names.size():
			var id:String=lib.names[i];var other=skeleton.find_bone(id);assert(other>=0)
			var parent:int=lib.parents[i];var op=skeleton.get_bone_parent(other)
			assert((skeleton.get_bone_name(op) if op>=0 else "")== (lib.names[parent] if parent>=0 else ""))
			var rest:Transform3D=visual.rest[visual.bone_ids[id]]
			max_rest=maxf(max_rest,rest.origin.distance_to(lib.rest[i].origin))
			var pose=skeleton.get_bone_global_pose(other)
			var delta=(support.transposed()*pose.basis*rest.basis.inverse()).orthonormalized();var pos=support.transposed()*(pose.origin-center)
			globals.append(delta);positions.append(pos)
			var local:Basis=globals[parent].transposed()*delta if parent>=0 else delta
			var q=local.get_rotation_quaternion().normalized()
			if frame>0 and prior[i].dot(q)<0:q=-q
			this_frame.append(q);values.append_array(PackedFloat32Array([pos.x,pos.y,pos.z,q.x,q.y,q.z,q.w]))
			if parent>=0:max_fk=maxf(max_fk,(positions[parent]+globals[parent]*(rest.origin-lib.rest[parent].origin)).distance_to(pos))
		prior=this_frame
	import_report={"samples":121,"resampled_hz":60,"source_samples":61,"source_hz":30,"max_fk_reconstruction_m":max_fk,"max_library_rest_position_difference_m":max_rest,"root_policy":"Mean calibrated sole rotation and ankle center removed exactly as production exporter. Solver owns world movement."}
	assert(max_fk<.0002 and max_rest<.0001)
	imported.free();return {"duration":2.0,"frames":121,"values":values}
func input_at(name,t):
	var input=Intent.new()
	if name=="compression":input.tuck=.55*smoothstep(.75,1.65,t)*(1.0-smoothstep(1.8,2.75,t))
	if name=="tuck_overlap":input.tuck=smoothstep(.6,1.25,t)*(1.0-smoothstep(2.1,3.0,t))
	if name.begins_with("steering"):
		var light=.12*smoothstep(.3,.5,t)*(1.0-smoothstep(1.1,1.3,t))
		var strong=.65*smoothstep(1.45,1.65,t)*(1.0-smoothstep(2.3,2.5,t))
		input.steer=(light+strong)*(-1.0 if name.ends_with("left") else 1.0)
	return input
func invariant(sim):
	return [sim.position,sim.velocity,sim.ticks,sim.body.roll,sim.body.pitch,sim.body.joints.duplicate(true),sim.body.rotations.duplicate(true),sim.skis[0].position,sim.skis[1].position,sim.skis[0].orientation,sim.skis[1].orientation]
func row_for(visual,sim,name,frame,t):
	var full=visual.animation.full_motion;var input=input_at(name,t)
	var row={"frame":frame,"tick":sim.ticks,"time":t,"grounded":sim.grounded,"phase":full.phase,"input":pack({"steer":input.steer,"tuck":input.tuck}),"state":pack(visual.animation.current),"diagnostics":pack(full.diagnostics),"clips":pack(full.weights),"substituted":pack(full.substituted),"root":pack(visual.global_transform),"joints":pack(visual.rendered_joints),"rotations":pack(visual.rendered_rotations),"requested":pack(full.requested_joints),"requested_rotations":pack(full.requested_rotations),"physical_position":pack(sim.position),"physical_velocity":pack(sim.velocity),"body_roll_rad":sim.body.roll,"speed_mps":sim.velocity.length(),"ski_edges_rad":[sim.skis[0].edge_angle,sim.skis[1].edge_angle],"ski_loads_n":[sim.skis[0].load_n,sim.skis[1].load_n],"skis":[],"poles":[],"final_bones":[]}
	for i in visual.skeleton.get_bone_count():row.final_bones.append(pack(visual.skeleton.get_bone_global_pose(i)))
	for ski in visual.skis:row.skis.append(pack(ski.global_transform))
	for pole in visual.poles:row.poles.append(pack(pole.global_transform))
	var source=full.landmarks(full.sample_raw(full.candidate,full.clip_time()))
	row.candidate_source=pack(source)
	row.gameplay_camera={"transform":pack(chase.global_transform),"fov":chase.fov,"aspect":16.0/9.0}
	row.stages=pack(full.stages)
	return row
func run():
	for variant in ["production","gameplay"]:
		assert(not FileAccess.file_exists(REV+variant+"/capture/manifest.json"),"Preserve previous capture")
		DirAccess.make_dir_recursive_absolute(REV+variant+"/capture")
	var sources=hashes()
	root.add_child(chase)
	for enabled in [false,true]:
		var visual=Visual.new();visual.preview_only=true;root.add_child(visual);visuals.append(visual)
		visual.animation.full_motion=Motion.new();visual.animation.full_motion.use_candidate=enabled
	await process_frame
	var candidate=load_candidate()
	for visual in visuals:visual.animation.full_motion.candidate=candidate
	for i in visuals[0].skeleton.get_bone_count():rigs.append({"name":visuals[0].skeleton.get_bone_name(i),"parent":visuals[0].skeleton.get_bone_parent(i),"rest":pack(visuals[0].rest[i])})
	var counts=[];var selections={};var reasons={}
	for name in CASES:
		var plane=TestPlane.new(.25);var sim=Sim.new();sim.reset(Vector3.ZERO);sim.prime_contacts(plane);sim.velocity=sim.support_basis().z*18.0;sim.reset_pose_history();chase.reset()
		for visual in visuals:
			visual.animation.full_motion.evaluation_time=-1.0;visual.animation.full_motion.ready_only=name=="straight";visual.reset_animation(sim)
		for tick in 120:
			sim.step(DT,Intent.new(),plane)
			for visual in visuals:visual.step_animation(DT,sim,Intent.new(),plane)
			if tick%4==3:chase.update_camera(sim,plane,sim.position,1.0/30.0)
		var traces=[[],[]]
		for frame in 121:
			if frame>0:
				for sub in 4:
					var t=((frame-1)*4+sub+1)*DT;var input=input_at(name,t);sim.step(DT,input,plane)
					var before=invariant(sim)
					for visual in visuals:
						visual.animation.full_motion.evaluation_time=t;visual.step_animation(DT,sim,input,plane)
					assert(before==invariant(sim),"Animation wrote physical state")
			chase.update_camera(sim,plane,sim.position,1.0/30.0)
			for i in 2:
				var before=invariant(sim);visuals[i].pose(sim,1.0);visuals[i].skeleton.force_update_all_bone_transforms()
				assert(before==invariant(sim),"Presentation wrote physical state")
				traces[i].append(row_for(visuals[i],sim,name,frame,frame/30.0))
			if not sim.grounded or sim.crashed:failures.append(name+" unexpected support loss/crash frame "+str(frame))
		for i in 2:write(REV+(["production","gameplay"][i])+"/capture/"+name+".json",{"name":name,"rig":rigs,"fixture":{"gradient":.25,"initial_speed_mps":18,"warmup_ticks":120},"frames":traces[i]})
		counts.append({"name":name,"frames":121})
		selections[name]=[0,15,30,51,69,81,96,120]
		reasons[name]={"0":"After 120 real warmup ticks; no candidate contribution","15":"Candidate entry and light steering","30":"Full candidate contribution; light steering hold","51":"Source compression peak; strong steering entry","69":"Edited source recovery; strong steering/release boundary","81":"End of two-second source and residual turning","96":"Candidate exit completes; tuck release","120":"Settled production recovery"}
		print("CASCADEUR_GAMEPLAY_CAPTURE ",name," frames=121 grounded=",sim.grounded)
	var after=hashes();assert(sources==after)
	for variant in ["production","gameplay"]:
		var folder=REV+variant+"/"
		write(folder+"capture/manifest.json",{"version":1,"capture_fps":30,"simulation_hz":120,"frame_origin":0,"physics":Sim.MODEL_VERSION,"unranked":true,"variant":variant,"scope":"Real solver on deterministic 14-degree plane; production presentation chain. No race, records or replay. Candidate source slot selection exists only in test subclass.","phase_mapping":"Source t=clamp(evaluation_time-.7,0,2); ready-only t=0. Forward navigation slots including straight tuck blend in .2-.7s, out 2.7-3.2s. No landing or jump mapping.","sources":sources,"sources_after":after,"stable_sources":sources==after,"failures":failures,"scenarios":counts,"engine":Engine.get_version_info(),"engine_sha256":FileAccess.get_sha256(OS.get_executable_path()),"engine_path":OS.get_executable_path(),"rig":rigs,"import":import_report})
		write(folder+"selection.json",selections);write(folder+"selection_reasons.json",reasons)
	write(BASE+"gameplay_import_audit.json",import_report)
	for visual in visuals:visual.free()
	print("CASCADEUR_GAMEPLAY_COMPLETE failures=",failures);quit(0 if failures.is_empty() else 1)

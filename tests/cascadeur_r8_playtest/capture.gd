extends "res://art_source/animation/cascadeur_carving_20260910_r7/gameplay_capture.gd"
const TrialSim=preload("res://tests/cascadeur_r8_playtest/simulation.gd")
const SnowPlaneFixture=preload("res://tests/physics_suite.gd").SnowPlane
const Asset=preload("res://tests/cascadeur_r7_playtest/candidate_asset.gd")
var revision_base="res://artifacts/pose_review/revisions/cascadeur-20260911-r8-01-"

func make_simulations():return [Sim.new(),TrialSim.new()]
func experiment_for(sim):return TrialSim.EXPERIMENT_ID if sim is TrialSim else "production-model-%d"%sim.MODEL_VERSION

func hashes():
	var result=super.hashes()
	hash_dir("res://tests/cascadeur_r8_playtest",result)
	result["res://scripts/main.gd"]=FileAccess.get_sha256("res://scripts/main.gd")
	return result

func row_for(visual,sim,name,frame,t):
	var row=super.row_for(visual,sim,name,frame,t)
	row.physics_experiment=experiment_for(sim)
	row.snow_contacts=[]
	for ski in sim.skis:
		row.snow_contacts.append({"position":pack(ski.position),"normal":pack(ski.normal),"load_n":ski.load_n,"penetration_m":ski.penetration,"support_sink_m":ski.crush_m,"pressure_sink_m":ski.crush.effective_pressure_m if sim is TrialSim else 0.0,"support_height":ski.height_reference})
	return row

func run():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--revision-base="):revision_base=arg.trim_prefix("--revision-base=")
	for variant in ["before","after"]:
		assert(not FileAccess.file_exists(revision_base+variant+"/capture/manifest.json"),"Preserve prior attempt")
		DirAccess.make_dir_recursive_absolute(revision_base+variant+"/capture")
	var sources=hashes();root.add_child(chase)
	for i in 2:
		var visual=Visual.new();visual.preview_only=true;root.add_child(visual);visuals.append(visual)
		visual.animation.full_motion=Motion.new()
	await process_frame
	var candidate=Asset.load_for(visuals[0])
	for visual in visuals:visual.animation.full_motion.candidate=candidate
	for i in visuals[0].skeleton.get_bone_count():rigs.append({"name":visuals[0].skeleton.get_bone_name(i),"parent":visuals[0].skeleton.get_bone_parent(i),"rest":pack(visuals[0].rest[i])})
	var counts=[];var selections={};var reasons={};var identities=[]
	for name in CASES:
		var field=SnowPlaneFixture.new(.25);field.depth=.22
		var sims=make_simulations()
		identities=[experiment_for(sims[0]),experiment_for(sims[1])]
		for i in 2:
			var sim=sims[i];sim.reset(Vector3.ZERO);sim.prime_contacts(field);sim.velocity=sim.support_basis().z*18;sim.reset_pose_history()
			visuals[i].reset_animation(sim)
		for tick in 120:
			for i in 2:
				sims[i].step(DT,Intent.new(),field);visuals[i].step_animation(DT,sims[i],Intent.new(),field)
		var traces=[[],[]]
		for frame in 121:
			if frame>0:
				for sub in 4:
					var t=((frame-1)*4+sub+1)*DT;var input=input_at(name,t)
					for i in 2:
						var sim=sims[i];sim.step(DT,input,field);var invariant_before=invariant(sim)
						visuals[i].step_animation(DT,sim,input,field)
						assert(invariant_before==invariant(sim),"Animation changed physics")
			for i in 2:
				var sim=sims[i];var invariant_before=invariant(sim)
				visuals[i].pose(sim,1.0);visuals[i].skeleton.force_update_all_bone_transforms()
				assert(invariant_before==invariant(sim),"Fitting changed physics")
				# A canonical chase offset avoids camera smoothing history becoming
				# another variable. Full review cameras independently match framing.
				chase.global_transform=Transform3D(sim.support_basis(),sim.position)*Transform3D(Basis.IDENTITY,Vector3(0,2.2,-5.0))
				chase.look_at(sim.position+sim.support_basis().y*.75,sim.support_basis().y);chase.fov=65
				traces[i].append(row_for(visuals[i],sim,name,frame,frame/30.0))
				if not sim.grounded or sim.crashed:failures.append(name+" variant "+str(i)+" support/crash frame "+str(frame))
		for i in 2:write(revision_base+(["before","after"][i])+"/capture/"+name+".json",{"name":name,"rig":rigs,"fixture":{"gradient":.25,"snow_depth_m":.22,"initial_speed_mps":18,"warmup_ticks":120},"frames":traces[i]})
		counts.append({"name":name,"frames":121})
		selections[name]=[0,15,27,42,54,75,93,108,120]
		reasons[name]={"0":"Settled neutral","15":"Light entry","27":"Light turn","42":"Strong entry or reversal","54":"Loading leg","75":"Held bank / tuck transition","93":"Steer release","108":"Residual bank","120":"Late response"}
		print("R8_CAPTURE ",name," frames=121")
	var after=hashes();assert(sources==after)
	for variant in ["before","after"]:
		var folder=revision_base+variant+"/"
		write(folder+"capture/manifest.json",{"version":1,"capture_fps":30,"simulation_hz":120,"frame_origin":0,"physics":identities[0 if variant=="before" else 1],"base_model":Sim.MODEL_VERSION,"unranked":true,"variant":variant,"scope":"Same inputs and start, separate simulations on 22 cm snow. R7 hands in both. Pressure support changes physical contacts; trajectories and physical poses are expected to differ. No identical-physics claim.","sources":sources,"sources_after":after,"stable_sources":sources==after,"failures":failures,"scenarios":counts,"engine":Engine.get_version_info(),"engine_sha256":FileAccess.get_sha256(OS.get_executable_path()),"engine_path":OS.get_executable_path(),"rig":rigs})
		write(folder+"selection.json",selections);write(folder+"selection_reasons.json",reasons)
	for visual in visuals:visual.free()
	print("R8_CAPTURE_COMPLETE failures=",failures);quit(0 if failures.is_empty() else 1)

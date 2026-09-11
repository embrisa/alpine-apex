extends "res://tests/cascadeur_r8_playtest/capture.gd"
## A fresh live-source coordinate check; not a replacement for frozen movies.
func run():
	var sources=hashes()
	root.add_child(chase)
	for i in 2:
		var visual=Visual.new();visual.preview_only=true;root.add_child(visual);visuals.append(visual)
		visual.animation.full_motion=Motion.new()
	await process_frame
	var candidate=Asset.load_for(visuals[0])
	for visual in visuals:visual.animation.full_motion.candidate=candidate
	for i in visuals[0].skeleton.get_bone_count():rigs.append({"name":visuals[0].skeleton.get_bone_name(i),"parent":visuals[0].skeleton.get_bone_parent(i),"rest":pack(visuals[0].rest[i])})
	var field=SnowPlaneFixture.new(.25);field.depth=.22
	var sims=[Sim.new(),TrialSim.new()]
	for i in 2:
		var sim=sims[i];sim.reset(Vector3.ZERO);sim.prime_contacts(field);sim.velocity=sim.support_basis().z*18;sim.reset_pose_history()
		visuals[i].reset_animation(sim)
	for tick in 120:
		for i in 2:
			sims[i].step(DT,Intent.new(),field);visuals[i].step_animation(DT,sims[i],Intent.new(),field)
	for tick in 216:
		var input=input_at("steering_right",(tick+1)*DT)
		for i in 2:
			sims[i].step(DT,input,field);visuals[i].step_animation(DT,sims[i],input,field)
	var report={"scope":"One fresh coordinate sample on live source, not a rendered or controller review.","base_model":sims[0].MODEL_VERSION,"experiment":TrialSim.EXPERIMENT_ID,"frame":54,"time_s":1.8,"sources":sources,"engine":Engine.get_version_info(),"variants":{}}
	for i in 2:
		var sim=sims[i];var visual=visuals[i]
		visual.pose(sim,1.0);visual.skeleton.force_update_all_bone_transforms()
		var positions=[]
		for ski in visual.skis:positions.append(ski.global_transform*preload("res://scripts/presentation/skier_equipment.gd").BOOT_ORIGIN)
		report.variants[["before","after"][i]]={"boot_origins":pack(positions),"world_y_gap_m":absf(positions[0].y-positions[1].y),"grounded":sim.grounded,"crashed":sim.crashed,"row":row_for(visual,sim,"steering_right",54,1.8)}
		assert(sim.grounded and not sim.crashed)
	report.sources_after=hashes();report.stable_sources=report.sources==report.sources_after
	assert(report.stable_sources)
	var output="res://artifacts/cascadeur_r8_current_coordinates"
	DirAccess.make_dir_recursive_absolute(output)
	write(output+"/probe.json",report)
	print("R8_CURRENT_COORDINATES model=",report.base_model," before_gap_m=",report.variants.before.world_y_gap_m," after_gap_m=",report.variants.after.world_y_gap_m)
	for visual in visuals:visual.free()
	quit()

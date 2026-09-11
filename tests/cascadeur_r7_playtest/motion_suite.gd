extends SceneTree
const Visual=preload("res://scripts/presentation/skier_visual.gd")
const Candidate=preload("res://tests/cascadeur_r7_playtest/live_motion.gd")
const Asset=preload("res://tests/cascadeur_r7_playtest/candidate_asset.gd")
const Sim=preload("res://scripts/core/ski_simulation.gd")
const Intent=preload("res://scripts/core/rider_input.gd")
const PlaneFixture=preload("res://tests/physics_suite.gd").TestPlane
func _initialize():call_deferred("run")
func invariant(sim):
	return [sim.position,sim.velocity,sim.ticks,sim.body.joints.duplicate(true),sim.body.rotations.duplicate(true),sim.skis[0].position,sim.skis[1].position,sim.skis[0].orientation,sim.skis[1].orientation]
func run():
	var visual=Visual.new();visual.preview_only=true;root.add_child(visual)
	var baseline=Visual.new();baseline.preview_only=true;root.add_child(baseline)
	await process_frame
	var motion=Candidate.new();motion.candidate=Asset.load_for(visual);motion.candidate_enabled=false;visual.animation.full_motion=motion
	var sim=Sim.new();var field=PlaneFixture.new(.25);sim.reset(Vector3.ZERO);sim.prime_contacts(field);sim.velocity=sim.support_basis().z*18
	visual.reset_animation(sim);baseline.reset_animation(sim)
	var seen_source=false;var baseline_exact=true
	for tick in 720:
		var intent=Intent.new();intent.steer=.55 if tick<250 else -.55 if tick<500 else .3
		if tick==180:motion.candidate_enabled=true
		if tick==480:motion.candidate_enabled=false
		sim.step(1.0/120.0,intent,field);var before=invariant(sim)
		for v in [baseline,visual]:v.step_animation(1.0/120.0,sim,intent,field);v.pose(sim,1.0)
		assert(invariant(sim)==before,"Presentation changed the solver")
		if tick<180:baseline_exact=baseline_exact and motion.current==baseline.animation.full_motion.current
		seen_source=seen_source or motion.applied_amount>.2
	assert(baseline_exact and seen_source and not sim.crashed)
	assert(motion.candidate_amount==0 and motion.applied_amount==0)
	var restored_error=0.0
	for i in motion.current.size():restored_error=maxf(restored_error,motion.current[i].angle_to(baseline.animation.full_motion.current[i]))
	assert(restored_error<.001,"Toggle must converge to production")
	var sample=motion.sample_clip("NAV_MED_FWD",0,true);var unchanged=sample.duplicate(true)
	motion.candidate_amount=1
	for state in [{"steer":0.0,"tuck":0.0},{"steer":.6,"tuck":0.0}]:
		motion.refine_authored_pose(sample,state,Vector3.ZERO)
		assert(sample==unchanged,"Unweighted ground/flight actions must not change")
	visual.reset_animation(sim);assert(motion.candidate_amount==0 and motion.applied_amount==0)
	visual.free();baseline.free()
	print("CASCADEUR_CARVING_MOTION_RESULTS ",JSON.stringify({"passed":true,"invariant_ticks":720,"disabled_matches_production_exactly":baseline_exact,"source_effect":seen_source,"restored_error_rad":restored_error,"zero_action_unchanged":true,"reset":true}));quit()

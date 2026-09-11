extends SceneTree
const Visual=preload("res://scripts/presentation/skier_visual.gd")
const Candidate=preload("res://tests/cascadeur_r6_playtest/live_motion.gd")
const Asset=preload("res://tests/cascadeur_r6_playtest/candidate_asset.gd")
const Base=preload("res://scripts/presentation/skier_full_motion.gd")
const Sim=preload("res://scripts/core/ski_simulation.gd")
const Intent=preload("res://scripts/core/rider_input.gd")
const PlaneFixture=preload("res://tests/physics_suite.gd").TestPlane
func _initialize():call_deferred("run")
func invariant(sim):
	return [sim.position,sim.velocity,sim.ticks,sim.body.joints.duplicate(true),sim.body.rotations.duplicate(true),sim.skis[0].position,sim.skis[1].position,sim.skis[0].orientation,sim.skis[1].orientation]
func run():
	var visual=Visual.new();visual.preview_only=true;root.add_child(visual);await process_frame
	var motion=Candidate.new();motion.candidate=Asset.load_for(visual);visual.animation.full_motion=motion
	var sim=Sim.new();var field=PlaneFixture.new(.25);sim.reset(Vector3.ZERO);sim.prime_contacts(field);sim.velocity=sim.support_basis().z*18;visual.reset_animation(sim)
	var seen_peak=false;var seen_source=false
	for tick in 480:
		var intent=Intent.new();intent.tuck=.65 if tick>=30 and tick<240 else 0.0;intent.steer=.12 if tick>100 and tick<180 else 0.0
		if tick==300:motion.candidate_enabled=false
		sim.step(1.0/120.0,intent,field);var before=invariant(sim)
		visual.step_animation(1.0/120.0,sim,intent,field);visual.pose(sim,1.0)
		assert(invariant(sim)==before,"Presentation changed the solver")
		seen_source=seen_source or motion.candidate_amount>.99
		seen_peak=seen_peak or absf(motion.candidate_time-1.0)<.01
	assert(seen_source and seen_peak and not sim.crashed)
	assert(motion.candidate_amount==0.0)
	var expected=Base.new().sample_clip("NAV_MED_FWD",.5,true);var actual=motion.sample_clip("NAV_MED_FWD",.5,true)
	assert(actual.root==expected.root and actual.q==expected.q,"Production toggle must restore unmodified source samples")
	motion.candidate_enabled=true;motion.replay()
	var intent=Intent.new();sim.step(1.0/120.0,intent,field);visual.step_animation(1.0/120.0,sim,intent,field)
	assert(motion.candidate_time==0.0 and not motion.pending_replay)
	var phase=motion.candidate_time;motion.hold();assert(motion.candidate_time==phase)
	visual.reset_animation(sim);assert(motion.candidate_time==2.0 and motion.candidate_amount==0.0)
	visual.free();print("CASCADEUR_LIVE_MOTION_RESULTS ",JSON.stringify({"passed":true,"invariant_ticks":480,"source_playback":true,"production_restored":true,"replay_and_reset":true}));quit()

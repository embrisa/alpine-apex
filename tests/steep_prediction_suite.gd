extends SceneTree
const Sim = preload("res://scripts/core/ski_simulation.gd")
const TestPlane = preload("res://tests/physics_suite.gd").TestPlane
const DT = 1.0/120.0
func _initialize():
	var rows = []
	var failures = []
	var checks = 0
	for slope in [-.2,0.0,.46]:
		for height in [.6,4.0,12.0]:
			var surface = TestPlane.new(slope)
			var sim = Sim.new(); sim.reset(Vector3(0,height,0)); sim.prime_contacts(surface)
			sim._begin_flight(sim.support_basis()); sim.velocity = Vector3(0,-3,20)
			var estimates = []
			var actual_time = -1.0; var actual_normal = Vector3.UP
			var peak_samples = 0
			for tick in 1200:
				var air: bool = not sim.grounded
				sim.step(DT,RiderInput.new(),surface)
				peak_samples = maxi(peak_samples,sim.landing_assist.prediction_samples)
				if sim.landing_assist.valid and sim.landing_assist.prediction_age<DT*.5:
					estimates.append({"time":tick*DT+sim.predicted_landing_time,"normal":sim.predicted_landing_normal})
				if air and (sim.grounded or sim.time_since_landing<DT*.5):
					actual_time = (tick+1)*DT; actual_normal = sim.surface_normal; break
			var max_error = 0.0; var max_normal_error = 0.0
			for estimate in estimates:
				max_error = maxf(max_error,absf(estimate.time-actual_time))
				max_normal_error = maxf(max_normal_error,rad_to_deg(estimate.normal.angle_to(actual_normal)))
			checks += 3
			if actual_time<0 or estimates.is_empty(): failures.append("Missing landing/prediction: "+str([slope,height]))
			if max_error>.10 or max_normal_error>1.0: failures.append("Prediction error: "+str([slope,height,max_error,max_normal_error]))
			if peak_samples>76 or sim.landing_assist.valid: failures.append("Budget/stale prediction: "+str([slope,height]))
			rows.append({"slope":slope,"height_m":height,"actual_contact_s":actual_time,"estimates":estimates.size(),"max_time_error_s":max_error,"max_normal_error_deg":max_normal_error,"max_queries":peak_samples})
	var report = {"checks":checks,"failures":failures,"cases":rows,"scope":"Planar exact heightfield fixtures; predicted times compared to first actual contact at 120 Hz"}
	DirAccess.make_dir_recursive_absolute("res://artifacts/steep_animation_physics_upgrade")
	preload("res://tests/test_report.gd").write("res://artifacts/steep_animation_physics_upgrade/prediction.json",JSON.stringify(report,"\t"))
	print("STEEP_PREDICTION ",JSON.stringify(report)); quit(0 if failures.is_empty() else 1)

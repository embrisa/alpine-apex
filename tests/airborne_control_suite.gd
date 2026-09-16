extends SceneTree
const Sim = preload("res://scripts/core/ski_simulation.gd")
const TestPlane = preload("res://tests/physics_suite.gd").TestPlane
const Cross = preload("res://tests/physics_suite.gd").CrossSlope
const Replay = preload("res://scripts/racing/run_replay.gd")
const DT = 1.0/120.0
var checks = 0
var failures: Array = []
var metrics: Dictionary = {}
class Uneven extends RefCounted:
	func sample(x,z): return {"height":-.46*z+.08*sin(x*3.0),"normal":Vector3(-.24*cos(x*3.0),1,.46).normalized()}
	func sweep_obstacle(_a,_b): return ""
func _initialize(): call_deferred("run")
func check(ok: bool,label: String):
	checks += 1
	print("PASS: " if ok else "FAIL: ",label)
	if not ok: failures.append(label)
func setup(surface, height: float = 0.0, speed: float = 30.0):
	var sim = Sim.new()
	sim.reset(Vector3(0,height,0))
	sim.prime_contacts(surface)
	sim.velocity = sim.support_basis().z*speed
	if height>0: sim.grounded = false
	return sim
func run():
	parity()
	pole_enabled_air_parity()
	assistance()
	anatomy()
	replay_checks()
	camera_parity()
	DirAccess.make_dir_recursive_absolute("res://artifacts/jump_v13")
	preload("res://tests/test_report.gd").write("res://artifacts/jump_v13/control_results.json",JSON.stringify({"checks":checks,"failures":failures,"metrics":metrics},"\t"))
	print("AIRBORNE_CONTROL_RESULTS ",JSON.stringify({"checks":checks,"failures":failures,"metrics":metrics}))
	quit(0 if failures.is_empty() else 1)
func parity():
	# Isolate the original body/contact parity contract. Model 29 intentionally
	# gives forward and switch different grounded push/tuck behavior at low speed.
	var surface_labels = ["flat","slope .46","slope 1.0","cross-slope","uneven"]
	var surface_index = 0
	metrics.facing_parity = []
	for surface in [TestPlane.new(0),TestPlane.new(.46),TestPlane.new(1.0),Cross.new(),Uneven.new()]:
		for altitude in [0.0,6.0]:
			var a = setup(surface,altitude)
			var b = setup(surface,altitude)
			a.tuning.pole_push_enabled = false
			b.tuning.pole_push_enabled = false
			b.facing_backward = true
			b.facing_pose.capture(b,true)
			var equal = true
			var first_difference: Dictionary = {}
			var intent = RiderInput.new()
			for tick in 720:
				intent.steer = .6 if tick<90 else (-.6 if tick<180 else 0.0)
				intent.tuck = 1.0 if tick<240 else .3
				intent.brake = .7 if tick>=360 and tick<540 else 0.0
				intent.jump = tick==300
				a.step(DT,intent,surface)
				b.step(DT,intent,surface)
				equal = equal and a.position==b.position and a.velocity==b.velocity and a.body.joints==b.body.joints and a.impacts.reserve==b.impacts.reserve and a.crashed==b.crashed and a.contact_count==b.contact_count
				if not equal and first_difference.is_empty():
					first_difference = {"tick":tick,"position_error_m":a.position.distance_to(b.position),"velocity_error_mps":a.velocity.distance_to(b.velocity),"body_equal":a.body.joints==b.body.joints,"reserve":[a.impacts.reserve,b.impacts.reserve],"crashed":[a.crashed,b.crashed],"contacts":[a.contact_count,b.contact_count],"effective_tuck":[a.effective_tuck,b.effective_tuck],"pole_acceleration":[a.pole_push_acceleration,b.pole_push_acceleration],"pole_reason":[a.pole_push.reason,b.pole_push.reason]}
			metrics.facing_parity.append({"surface":surface_labels[surface_index],"altitude":altitude,"poles_enabled":false,"ticks":720,"first_difference":first_difference})
			check(equal,"Body/contact forward/backward parity with poles disabled on both riders: %s, altitude %s"%[surface_labels[surface_index],altitude])
		surface_index += 1
	var surface = TestPlane.new(.46)
	var a = setup(surface)
	var b = Sim.new()
	b.reset(Vector3.ZERO,PI)
	b.prime_contacts(surface)
	b.velocity = a.velocity
	a.step(DT,RiderInput.new(),surface)
	b.step(DT,RiderInput.new(),surface)
	metrics.reversed_spawn_position_error_m = a.position.distance_to(b.position)
	metrics.reversed_spawn_velocity_error_mps = a.velocity.distance_to(b.velocity)
	check(absf(angle_difference(a.heading,b.heading))<.00001 and b.facing_backward,"A physically reversed starting ski axis becomes switch facing")
	check(a.velocity.distance_to(b.velocity)<.001,"Reversed-axis initialization retains equivalent physical handling")
	b.velocity = Vector3.ZERO
	var backward = b.facing_backward
	for tick in 20: b._orient_travel_axis()
	check(b.facing_backward==backward,"At rest the facing convention does not oscillate")
	for terrain in [TestPlane.new(.46),Cross.new(),Uneven.new()]:
		a = setup(terrain)
		b = Sim.new()
		b.reset(Vector3.ZERO,PI)
		b.prime_contacts(terrain)
		b.velocity = a.velocity
		var error = 0.0
		var input = RiderInput.new()
		for tick in 360:
			input.steer = .6 if tick<120 else -.6
			input.tuck = .8
			input.brake = .5 if tick>240 else 0.0
			a.step(DT,input,terrain)
			b.step(DT,input,terrain)
			error = maxf(error,maxf(a.position.distance_to(b.position),a.velocity.distance_to(b.velocity)))
		check(error<.001,"Actual reversed ski-axis handling matches on uneven/cross-slope terrain; error %.6f"%error)
func pole_enabled_air_parity():
	# Forward held below the flat pushing cap, with neither brake nor preparation:
	# real unsupported flight must prevent propulsion, not a speed/action cutoff.
	var surface = TestPlane.new(0.0)
	var forward = setup(surface,50.0,7.0)
	var backward = setup(surface,50.0,7.0)
	var control = setup(surface,50.0,7.0)
	forward.tuning.pole_push_enabled = true
	backward.tuning.pole_push_enabled = true
	control.tuning.pole_push_enabled = false
	backward.facing_backward = true
	backward.facing_pose.capture(backward,true)
	for rider in [forward,backward,control]: rider._begin_flight(rider.support_basis())
	var intent = RiderInput.new(); intent.tuck = 1.0
	var air_ticks = 0
	var below_cap_ticks = 0
	var equal = true
	var no_force = true
	var first_difference = -1
	for tick in 120:
		for rider in [forward,backward,control]: rider.step(DT,intent,surface)
		if not forward.grounded and not backward.grounded and not control.grounded and forward.contact_count==0 and backward.contact_count==0 and control.contact_count==0 and not forward.crashed and not backward.crashed and not control.crashed: air_ticks += 1
		if forward.pole_push_limit_mps>0.0 and backward.pole_push_limit_mps>0.0 and forward.velocity.slide(forward.surface_normal).length()<forward.pole_push_limit_mps and backward.velocity.slide(backward.surface_normal).length()<backward.pole_push_limit_mps: below_cap_ticks += 1
		equal = equal and forward.position==backward.position and forward.position==control.position and forward.velocity==backward.velocity and forward.velocity==control.velocity
		no_force = no_force and forward.pole_push_acceleration==0.0 and backward.pole_push_acceleration==0.0 and control.pole_push_acceleration==0.0 and forward.pole_push_power==0.0 and backward.pole_push_power==0.0 and control.pole_push_power==0.0
		if (not equal or not no_force) and first_difference<0: first_difference = tick
	metrics.pole_enabled_air_parity = {"ticks":120,"air_ticks":air_ticks,"below_cap_ticks":below_cap_ticks,"entry_speed_mps":7.0,"forward_held":intent.tuck,"enabled":[forward.tuning.pole_push_enabled,backward.tuning.pole_push_enabled,control.tuning.pole_push_enabled],"first_difference_tick":first_difference,"positions_equal":equal,"zero_power_and_acceleration":no_force}
	check(air_ticks==120 and below_cap_ticks==120 and forward.tuning.pole_push_enabled and backward.tuning.pole_push_enabled and not control.tuning.pole_push_enabled and not forward.facing_backward and backward.facing_backward,"Pole-enabled facing fixture stays airborne below the push cap for every forward-held tick")
	check(equal and no_force,"Pole-enabled forward and switch flight match the disabled control's exact trajectory every tick with zero pole power/force")

func assistance():
	var surface = TestPlane.new(.46)
	var sim = setup(surface,50.0)
	sim.tuning.landing_assist_enabled = true
	sim.heading = .8
	var intent = RiderInput.new()
	intent.tuck = 1.0
	intent.brake = .5
	intent.jump_held = true
	for tick in 12: sim.step(DT,intent,surface)
	check(sim.landing_assist_strength<.00001,"Centered steering waits 100 ms despite other held controls")
	for tick in 48: sim.step(DT,intent,surface)
	check(sim.landing_assist_strength>.999,"Centered steering reaches full help after the 400 ms gradual blend")
	intent.steer = .001
	sim.step(DT,intent,surface)
	check(sim.landing_assist_strength==0,"Even small post-deadzone steering overrides on the next tick")
	intent.steer = 0
	for tick in 8: sim.step(DT,intent,surface)
	check(sim.landing_assist_strength==0,"A brief neutral reversal cannot engage help")
	sim.clear_input_buffer()
	check(sim.predicted_landing_time<0 and sim.landing_assist.neutral_seconds==0,"Input cancellation clears prediction and pending assistance")
	var a = setup(surface,100.0)
	a.tuning.landing_assist_enabled = true
	var b = setup(surface,100.0)
	b.tuning.landing_assist_enabled = false
	for rider in [a,b]: rider.heading = .6; rider.body.roll_velocity = .6
	for tick in 240:
		a.step(DT,intent,surface)
		b.step(DT,intent,surface)
	check(a.position==b.position and a.velocity==b.velocity,"Orientation help preserves exact free-flight translation with matching inputs")
	check(a.landing_assist.prediction_samples<=76 and not a.landing_assist.valid,"Prediction has a fixed work bound and ignores distant terrain")
	for reverse in [false,true]:
		sim = setup(surface,6.0)
		sim.tuning.landing_assist_enabled = true
		sim.facing_backward = reverse
		sim.heading = .65
		var yaw_error = INF
		var tilt_error = INF
		var peak_samples = 0
		for tick in 400:
			var was_air: bool = not sim.grounded
			var frame: Basis = sim.support_basis()
			var travel: Vector3 = sim.velocity.slide(surface.sample(sim.position.x,sim.position.z).normal).normalized()
			var before_yaw = acos(clampf(frame.z.dot(travel),-1,1))
			var before_tilt = acos(clampf(frame.y.dot(surface.sample(sim.position.x,sim.position.z).normal),-1,1))
			sim.step(DT,intent,surface)
			peak_samples = maxi(peak_samples,sim.landing_assist.prediction_samples)
			if was_air and sim.grounded:
				yaw_error = rad_to_deg(before_yaw)
				tilt_error = rad_to_deg(before_tilt)
				break
		metrics["landing_%s"%reverse] = {"yaw_error_deg":yaw_error,"tilt_error_deg":tilt_error,"samples":peak_samples,"reserve":sim.impacts.reserve}
		check(yaw_error<40 and tilt_error<40 and not sim.crashed,"Assisted %s landing remains bounded while incomplete alignment is allowed"%reverse)
		check(sim.facing_backward==reverse,"Landing help preserves selected forward/backward facing %s"%reverse)
func anatomy():
	var surface = TestPlane.new(.46)
	var sim = setup(surface,100.0)
	sim.body.roll_velocity = 2.0
	sim.body.pitch_velocity = 1.0
	var intent = RiderInput.new()
	var peak = Vector2.ZERO
	var minimum_hips = INF
	for tick in 480:
		intent.steer = 1.0 if tick<240 else -1.0
		sim.step(DT,intent,surface)
		peak = peak.max(Vector2(absf(sim.body.roll),absf(sim.body.pitch)))
		minimum_hips = minf(minimum_hips,sim.body.joints.Hips.y)
	metrics.air_pose = {"roll_max_rad":peak.x,"pitch_max_rad":peak.y,"minimum_hips_y_m":minimum_hips}
	check(peak.x<=1.15001 and peak.y<=.70001 and minimum_hips>.2,"Sustained airborne reversals cannot orbit the body around the boots")
	check(sim.landing_assist_strength==0,"Anatomical constraints work while the player owns steering")
func replay_checks():
	var surface = TestPlane.new(.46)
	var sim = setup(surface,8.0)
	sim.facing_backward = true
	sim.facing_pose.capture(sim,true)
	var replay = Replay.new()
	replay.begin(sim,Replay.key("air-fixture"))
	for tick in 60:
		sim.step(DT,RiderInput.new(),surface)
		replay.record(DT,(tick+1)*DT,sim,RiderInput.new(),1.0 if tick==59 else -1.0)
	# Neutral sample poses complete the codec fixture; physical flight is unchanged.
	preload("res://tests/ghost_replay_fixture.gd").attach_sample_poses(replay)
	var data = replay.to_data()
	var decoded = Replay.decode(data,replay.compatibility,.5)
	check(Replay.VERSION==7 and decoded!=null and decoded.samples==replay.samples and decoded.inputs==replay.inputs and decoded.sample_times==replay.sample_times,"Replay v7 round-trips recorded backward flight and exact physical/input frames")
	if decoded==null: return
	if decoded!=null:
		var pose = decoded.pose_at(.5)
		check(pose.basis.is_equal_approx(sim.facing_pose.frame.basis) and pose.skis[0].basis.is_equal_approx(sim.facing_pose.orientations[0]),"Ghost retains actual rider and ski orientation in flight")
	var bad = data.duplicate(true)
	var corrupt: PackedByteArray = Marshalls.base64_to_raw(data.payload)
	# Prefix + JSON header + all float64 sample times precede physical frames.
	var quaternion_offset: int = 32+corrupt.decode_u32(8)+corrupt.decode_u32(12)*8+Replay.FRAME_START*4
	var original: float = corrupt.decode_float(quaternion_offset)
	corrupt.encode_float(quaternion_offset,8.0)
	bad.payload = Marshalls.raw_to_base64(corrupt)
	check(Replay.decode(bad,replay.compatibility,.5)==null,"Replay rejects invalid physical orientation quaternions in binary payload")
	corrupt.encode_float(quaternion_offset,original)
	bad.payload = Marshalls.raw_to_base64(corrupt)
	check(Replay.decode(bad,replay.compatibility,.5)!=null,"Restoring only the corrupt quaternion component restores a valid replay")
	bad = data.duplicate(true)
	bad.version = 2
	check(Replay.decode(bad,replay.compatibility,.5)==null,"Previous replay formats remain incompatible")

func camera_parity():
	var a = setup(TestPlane.new(.46))
	var b = setup(TestPlane.new(.46))
	b.facing_backward = true
	for close in [false,true]:
		var first = preload("res://scripts/presentation/chase_camera.gd").new()
		var second = preload("res://scripts/presentation/chase_camera.gd").new()
		root.add_child(first)
		root.add_child(second)
		first.close_view = close
		second.close_view = close
		for tick in 120:
			first.set_stick_look(Vector2(.2,-.1))
			second.set_stick_look(Vector2(.2,-.1))
			first.update_camera(a,TestPlane.new(.46),a.position,DT)
			second.update_camera(b,TestPlane.new(.46),b.position,DT)
		check(first.transform.is_equal_approx(second.transform) and first.look_yaw==second.look_yaw,"Camera anticipation and manual look match in both facings; first-person %s"%close)
		first.queue_free()
		second.queue_free()

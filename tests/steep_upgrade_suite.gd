extends "res://tests/skier_animation_suite.gd"
## New model boundaries: quaternion continuity, playable intent, shared signals.
const OUTPUT = "res://artifacts/steep_animation_physics_upgrade"
var results = {}

static func angular_delta(a: Basis, b: Basis) -> float:
	var q = (b*a.transposed()).get_rotation_quaternion().normalized()
	return 2.0*atan2(Vector3(q.x,q.y,q.z).length(),absf(q.w))

func run():
	skier = preload("res://scripts/presentation/skier_visual.gd").new()
	# Preserve the v17 scalar-profile shape/attachment regression. Production
	# full-curve replay, flips, twist and skeletal links have their own suite.
	skier.animation.full_motion.enabled = false
	root.add_child(skier); await process_frame
	air_rotations()
	assistance_boundaries()
	physics_authority()
	replay_and_input()
	signals_and_recovery()
	failed_rotation_contact()
	check(metrics.boot_gap_m<.0005 and metrics.length_error_m<.002,"Full rotations and grab retain exact bindings and fixed limb lengths")
	check(metrics.cuff_side_deg<12 and metrics.cuff_flex_min_deg>-5 and metrics.cuff_flex_max_deg<40,"Rotation poses retain the existing cuff limits")
	check(metrics.spine_length_error_m<.00001 and metrics.chest_attachment_error_m<.00001,"Motion profiles retain spine and shoulder attachment")
	results.merge({"checks":checks,"failures":failures,"anatomy":metrics,"physics":Sim.MODEL_VERSION,"replay":Replay.VERSION})
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	FileAccess.open(OUTPUT+"/focused.json",FileAccess.WRITE).store_string(JSON.stringify(results,"\t"))
	print("STEEP_UPGRADE_RESULTS ",JSON.stringify(results))
	skier.queue_free(); await process_frame; quit(0 if failures.is_empty() else 1)

func air_rotations():
	var plane = TestPlane.new(.46)
	var rows = []
	for kind in ["spin","flip","grab"]:
		for switch_entry in [false,true]:
			var sim = setup(plane,200.0)
			sim.velocity = Vector3(0,-5,25)
			sim._begin_flight(sim.support_basis())
			sim.facing_backward = switch_entry; sim.facing_pose.capture(sim,true)
			sim.tuning.landing_assist_enabled = true
			var neutral = setup(plane,200.0); neutral.velocity = sim.velocity
			neutral._begin_flight(neutral.support_basis())
			neutral.tuning.landing_assist_enabled = false
			var intent = RiderInput.new()
			var max_step = 0.0
			var max_acceleration = 0.0
			var max_joint_step = 0.0
			var last_pose = {}
			var max_linear_error = 0.0
			var peak_grab = 0.0
			for tick in 420:
				var rotation: float = absf(sim.air_control.integrated_yaw if kind=="spin" else sim.air_control.integrated_pitch)
				# Release before the remaining physical angular motion finishes.
				intent.air_yaw = 1.0 if kind=="spin" and rotation<TAU-sim.air_control.angular_velocity.length_squared()/(2.0*sim.tuning.air_rotation_braking) and tick<220 else 0.0
				intent.air_pitch = 1.0 if kind=="flip" and rotation<TAU-sim.air_control.angular_velocity.length_squared()/(2.0*sim.tuning.air_rotation_braking) and tick<360 else 0.0
				intent.grab = kind=="grab" and tick>=30 and tick<170
				var old: Basis = sim.support_basis()
				sim.step(DT,intent,plane); neutral.step(DT,RiderInput.new(),plane)
				skier.step_animation(DT,sim,intent,plane); inspect(sim)
				max_step = maxf(max_step,angular_delta(old,sim.support_basis()))
				max_acceleration = maxf(max_acceleration,sim.air_control.angular_acceleration.length())
				max_linear_error = maxf(max_linear_error,sim.velocity.distance_to(neutral.velocity)+sim.position.distance_to(neutral.position))
				peak_grab = maxf(peak_grab,skier.animation.current.get("grab",0.0))
				if not last_pose.is_empty():
					for id in skier.rendered_joints: max_joint_step = maxf(max_joint_step,last_pose[id].distance_to(skier.rendered_joints[id]))
				last_pose = skier.rendered_joints.duplicate()
				check_frame(sim.support_basis())
			var rotation: float = absf(sim.air_control.integrated_yaw if kind=="spin" else sim.air_control.integrated_pitch)
			check(max_linear_error<.00001,kind+": controls and pose add no lift or propulsion")
			check(max_step<sim.tuning.air_rotation_rate_limit*DT+.00001 and max_acceleration<=sim.tuning.air_rotation_braking+.002,kind+": bounded angular speed and acceleration")
			check(max_joint_step<.08,kind+": no local anatomy discontinuity through full rotation")
			if kind!="grab":
				check(absf(rotation-TAU)<.12,kind+": player command and release execute one controllable full rotation")
				check(sim.air_control.angular_velocity.length()<.001 and sim.landing_assist.strength==0,kind+": release stops gradually; no automatic flip completion")
			else: check(peak_grab>.95 and skier.animation.current.get("grab",0.0)<.01,"Grab blends in and releases while poles remain attached")
			rows.append({"kind":kind,"switch":switch_entry,"rotation_deg":rad_to_deg(rotation),"max_step_deg":rad_to_deg(max_step),"max_acceleration_rad_s2":max_acceleration,"max_joint_step_m":max_joint_step,"linear_error":max_linear_error})
	results.rotations = rows

func check_frame(frame: Basis):
	if not frame.is_finite() or absf(frame.determinant()-1.0)>.00001:
		check(false,"Physical rotation remains finite and normalized")

func assistance_boundaries():
	var plane = TestPlane.new(.46)
	var rows = []
	for enabled in [false,true]:
		var sim = setup(plane,8.0); sim.velocity = Vector3(15,-5,25)
		sim._begin_flight(Basis(Vector3.RIGHT,.6)); sim.tuning.landing_assist_enabled = enabled
		var intent = RiderInput.new()
		var max_step = 0.0; var max_acceleration = 0.0; var max_speed = 0.0
		var trace = []
		var valid_seen = false; var readiness = 0.0
		for tick in 360:
			# Isolate orientation from genuine contact impulses and trajectory.
			if tick==90: plane.gradient = -.3
			if tick==150: sim.position.y = 200.0
			if tick==210: sim.position.y = 8.0
			if tick==240: sim.tuning.landing_assist_enabled = false
			if tick==280: sim.tuning.landing_assist_enabled = enabled
			var before: Basis = sim.support_basis()
			var old_omega: Vector3 = sim.air_control.angular_velocity
			sim.landing_assist.step(DT,sim,intent,plane); sim.air_control.step(DT,sim,intent)
			max_step = maxf(max_step,angular_delta(before,sim.support_basis()))
			max_acceleration = maxf(max_acceleration,(sim.air_control.angular_velocity-old_omega).length()/DT)
			max_speed = maxf(max_speed,sim.air_control.angular_velocity.length())
			valid_seen = valid_seen or sim.landing_assist.valid
			readiness = maxf(readiness,skier.animation.landing_readiness(sim,plane))
			check_frame(sim.support_basis())
			if tick%4==0: trace.append({"tick":tick,"omega":str(sim.air_control.angular_velocity),"assist_accel":str(sim.air_control.assist_acceleration),"q":str(sim.support_basis().get_rotation_quaternion()),"valid":sim.landing_assist.valid,"age":sim.landing_assist.prediction_age,"weight":sim.landing_assist.strength,"samples":sim.landing_assist.prediction_samples})
			if sim.landing_assist.prediction_samples>76: check(false,"Prediction stays within 76 samples")
		check(valid_seen,"Prediction remains available independently of assistance")
		check(max_speed<=deg_to_rad(20)+.00001 and max_acceleration<=deg_to_rad(60)+.002,"Acquisition, changing slope, expiry and toggles respect actual assist speed/acceleration")
		if not enabled: check(max_step<.00001 and max_speed==0,"Disabled assistance cannot rotate the physical frame")
		var old: Basis = sim.support_basis(); var old_omega: Vector3 = sim.air_control.angular_velocity
		intent.air_pitch = .4
		sim.landing_assist.step(DT,sim,intent,plane); sim.air_control.step(DT,sim,intent)
		check(sim.air_control.manual_active and sim.air_control.assist_acceleration==Vector3.ZERO and sim.landing_assist.strength==0,"Manual intent immediately owns angular acceleration")
		check(angular_delta(old,sim.support_basis())<.04 and (sim.air_control.angular_velocity-old_omega).length()<=sim.tuning.air_rotation_braking*DT+.0001,"Manual handover preserves orientation and angular history")
		rows.append({"enabled":enabled,"max_speed_deg_s":rad_to_deg(max_speed),"max_acceleration_deg_s2":rad_to_deg(max_acceleration),"max_step_deg":rad_to_deg(max_step),"trace":trace})
	results.assistance = rows

func physics_authority():
	var plane = TestPlane.new(.46)
	var reference = []
	for fps in [0,30,60,120,144,240]:
		var sim = setup(plane,200.0); sim.velocity = Vector3(0,-2,22); sim._begin_flight(sim.support_basis())
		var intent = RiderInput.new()
		var render_time = 0.0
		for tick in 300:
			intent.air_pitch = .6 if tick<180 else 0.0; intent.grab = tick>40 and tick<160
			sim.step(DT,intent,plane)
			if fps>0:
				skier.step_animation(DT,sim,intent,plane)
				while render_time<=(tick+1)*DT:
					skier.pose(sim,clampf((render_time-tick*DT)/DT,0,1)); render_time += 1.0/fps
			var snapshot: Array = Array(Replay.snapshot((tick+1)*DT,sim))
			snapshot.append_array([sim.impacts.reserve,sim.body.com.x,sim.body.com.y,sim.body.com.z,sim.body.inertia.x,sim.body.inertia.y])
			if fps==0: reference.append(snapshot)
			elif snapshot!=reference[tick]: check(false,"Render schedule changed physical snapshot"); break
		if fps>0: check(Array(Replay.snapshot(2.5,sim))==reference[-1].slice(0,Replay.WIDTH),"Animation at %d FPS leaves physical replay state identical"%fps)

func replay_and_input():
	var sim = setup(TestPlane.new(),100.0); sim._begin_flight(sim.support_basis())
	var intent = RiderInput.new(); intent.air_pitch = -.6; intent.air_yaw = .3; intent.grab = true
	var copy = intent.copy()
	check(copy.air_pitch==intent.air_pitch and copy.air_yaw==intent.air_yaw and copy.grab,"Input copy preserves every new action")
	var recording = Replay.new(); var identity = Replay.key("v17-air-test")
	recording.begin(sim,identity)
	for tick in 12:
		sim.step(DT,intent,TestPlane.new()); recording.record(DT,(tick+1)*DT,sim,intent,1.0 if tick==11 else -1.0)
	# These neutral poses complete an input/physics codec fixture, not an animation capture.
	preload("res://tests/ghost_replay_fixture.gd").attach_sample_poses(recording)
	var data: Dictionary = recording.to_data()
	var decoded = Replay.decode(data,identity,.1)
	check(Replay.VERSION==7 and Replay.INPUT_WIDTH==9 and decoded!=null and decoded.inputs.size()==12*Replay.INPUT_WIDTH and decoded.inputs==recording.inputs and decoded.samples==recording.samples and decoded.sample_times==recording.sample_times,"Replay v7 validates nine fields per tick and preserves recorded physical/input frames")
	if decoded==null: return
	if decoded!=null:
		var restored = decoded.input_at(5)
		check(absf(restored.air_pitch-intent.air_pitch)<.000001 and absf(restored.air_yaw-intent.air_yaw)<.000001 and restored.grab,"Replay input reader restores pitch/yaw/grab")
	data.version = 3; check(Replay.decode(data,identity,.1)==null,"Earlier replay layout is rejected cleanly")
	var bad = recording.to_data()
	var corrupt: PackedByteArray = Marshalls.base64_to_raw(bad.payload)
	# Float32 inputs immediately precede the final per-tick kind bytes.
	var input_offset: int = corrupt.size()-recording.inputs.size()*4-recording.tick_kinds.size()
	var pitch_offset: int = input_offset+4*4
	var original: float = corrupt.decode_float(pitch_offset)
	corrupt.encode_float(pitch_offset,NAN)
	bad.payload = Marshalls.raw_to_base64(corrupt)
	check(Replay.decode(bad,identity,.1)==null,"Nonfinite rotation intent in the binary input section is rejected")
	corrupt.encode_float(pitch_offset,original)
	bad.payload = Marshalls.raw_to_base64(corrupt)
	check(Replay.decode(bad,identity,.1)!=null,"Restoring only nonfinite pitch intent restores a valid replay")

func signals_and_recovery():
	var plane = TestPlane.new()
	var sim = setup(plane); sim.velocity = sim.support_basis().z*15
	var intent = RiderInput.new(); intent.steer = .4
	advance(sim,intent,plane,30)
	check(sim.motion.tick==sim.ticks and sim.motion.velocity_world_mps==sim.velocity and sim.motion.skis[0].load_n==sim.skis[0].load_n,"Reusable motion view describes the completed physical tick")
	var mass: Vector3 = sim.body.com
	var reserve: float = sim.impacts.reserve
	for i in 15: skier.animation.sample(float(i)/15)
	check(sim.body.com==mass and sim.impacts.reserve==reserve,"Arbitrary sampling cannot change mass or reserve")
	sim.impacts.reserve = .25; sim.impacts.since_hit = 0.0
	advance(sim,intent,plane,60)
	check(skier.animation.current.get("impairment",0.0)>.25,"Low reserve creates readable cosmetic recovery")
	var current = skier.animation.current.duplicate(); skier.animation.hold()
	check(skier.animation.sample(.1)==current,"Pause freezes every motion blend")
	sim.reset(Vector3.ZERO); sim.prime_contacts(plane); skier.reset_animation(sim)
	check(sim.air_control.angular_velocity==Vector3.ZERO and sim.motion.landing_episode==0 and skier.animation.current.get("grab",0.0)==0,"Restart resets rotation, event and grab histories")

func failed_rotation_contact():
	var plane = TestPlane.new()
	var rows = []
	for reserve in [1.0,.08]:
		var sim = setup(plane,4.0)
		sim.velocity = Vector3(0,-8,20)
		sim._begin_flight(sim.support_basis())
		sim.impacts.reserve = reserve
		var intent = RiderInput.new(); intent.air_pitch = 1.0
		var touched = false
		for tick in 180:
			sim.step(DT,intent,plane)
			skier.step_animation(DT,sim,intent,plane)
			if sim.time_since_landing==0.0 or sim.crashed:
				touched = true; break
		check(touched and sim.landing_force>0.0 and sim.impacts.reserve<reserve,"An unfinished rotation receives actual impact and reserve cost")
		var incomplete_phase = fposmod(absf(sim.air_control.integrated_pitch),TAU)
		check(incomplete_phase>.2 and incomplete_phase<TAU-.2,"The contact fixture reaches terrain partway through a player-commanded flip, including repeated flips")
		if reserve<.1:
			check(sim.crashed and sim.crash_reason.contains("HARD LANDING"),"An unfinished hard landing exhausts reserve through the existing contact path")
			skier.pose(sim)
			var hips: Transform3D = skier.skeleton.global_transform*skier.skeleton.get_bone_global_pose(skier.bone_ids.Hips)
			var omega: Vector3 = sim.body.pose_frame.basis*Vector3(sim.body.pitch_velocity,0,sim.body.roll_velocity)+sim.air_control.angular_velocity
			skier.ragdoll.start(sim)
			check(skier.ragdoll.bone_world("Hips").origin.distance_to(hips.origin)<.0005,"Rotating crash starts from the final composed hips without a neutral reset")
			check(skier.ragdoll.bodies.Hips.angular_velocity.distance_to(omega)<.0001,"Rotating crash transfers the physical whole-body angular velocity")
			skier.ragdoll.stop()
		else: check(not sim.crashed,"Reserve permits rough recovery without introducing a balance death")
		rows.append({"initial_reserve":reserve,"reserve":sim.impacts.reserve,"impact_mps":sim.landing_force,"crash":sim.crash_reason})
	results.failed_rotation_contacts = rows

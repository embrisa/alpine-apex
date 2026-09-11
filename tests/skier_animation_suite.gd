extends SceneTree
const Sim = preload("res://scripts/core/ski_simulation.gd")
const Motion = preload("res://scripts/presentation/skier_animation.gd")
const TestPlane = preload("res://tests/physics_suite.gd").TestPlane
const Replay = preload("res://scripts/racing/run_replay.gd")
const DT = 1.0/120.0
var failures: Array[String] = []
var checks = 0
var skier
var baseline_air = false
var metrics = {"length_error_m":0.0,"boot_gap_m":0.0,"cuff_side_deg":0.0,"cuff_flex_min_deg":0.0,"cuff_flex_max_deg":0.0,"max_joint_step_m":0.0,
	"spine_length_error_m":0.0,"chest_attachment_error_m":0.0,"neck_angle_deg":0.0,"spine_joint_angle_deg":0.0}
func _initialize(): call_deferred("run")
func check(value: bool, label: String):
	checks += 1
	if not value: failures.append(label)
	print("PASS: " if value else "FAIL: ",label)
func setup(surface, altitude: float = 0.0):
	var sim = Sim.new()
	if baseline_air:
		# Comparison fixture only: isolate procedural posture checks from air tuning.
		sim.tuning.air_spin_rate = 4.5; sim.tuning.air_flip_rate = 3.8; sim.tuning.air_steer_rate = .65
		sim.tuning.air_rotation_acceleration = 10.0; sim.tuning.air_rotation_braking = 10.0; sim.tuning.air_rotation_rate_limit = 4.5
	sim.reset(Vector3(0,altitude,0))
	sim.prime_contacts(surface)
	skier.reset_animation(sim)
	return sim
func advance(sim, intent, surface, count: int):
	for tick in range(count):
		sim.step(DT,intent,surface)
		sim.motion.capture(sim,DT)
		skier.step_animation(DT,sim,intent,surface)
func inspect(sim, alpha: float = 1.0):
	skier.pose(sim,alpha)
	var torso: Dictionary = skier.rendered_joints
	var bases: Dictionary = skier.rendered_rotations
	for pair in [["Hips","Spine02"],["Spine02","Spine01"],["Spine01","Spine"],["Spine","neck"],["neck","Head"]]:
		var length: float = sim.Body.REST[pair[0]].distance_to(sim.Body.REST[pair[1]])
		metrics.spine_length_error_m = maxf(metrics.spine_length_error_m,absf(torso[pair[0]].distance_to(torso[pair[1]])-length))
	for pair in [["Spine02","Spine01"],["Spine01","Spine"],["Spine","neck"],["neck","Head"]]:
		var angle = rad_to_deg(bases[pair[0]].get_rotation_quaternion().angle_to(bases[pair[1]].get_rotation_quaternion()))
		if pair[1] in ["neck","Head"]: metrics.neck_angle_deg = maxf(metrics.neck_angle_deg,angle)
		else: metrics.spine_joint_angle_deg = maxf(metrics.spine_joint_angle_deg,angle)
	for id in ["LeftShoulder","RightShoulder","LeftArm","RightArm","neck"]:
		# Upper arms attach through articulated clavicles, not directly to Spine.
		var parent: String = id.replace("Arm","Shoulder") if id.ends_with("Arm") else "Spine"
		var attached: Vector3 = torso[parent]+bases[parent]*(sim.Body.REST[id]-sim.Body.REST[parent])
		metrics.chest_attachment_error_m = maxf(metrics.chest_attachment_error_m,attached.distance_to(torso[id]))
	for index in range(2):
		var prefix = "Right" if index==0 else "Left"
		var points: Dictionary = skier.rendered_joints
		for pair in [["UpLeg","Leg"],["Leg","Foot"],["Arm","ForeArm"],["ForeArm","Hand"]]:
			var expected: float = sim.Body.REST[prefix+pair[0]].distance_to(sim.Body.REST[prefix+pair[1]])
			metrics.length_error_m = maxf(metrics.length_error_m,absf(points[prefix+pair[0]].distance_to(points[prefix+pair[1]])-expected))
		var expected_ankle: Vector3 = skier.skis[index].get_child(1).global_transform*Vector3(0,skier._origin(prefix+"Foot").y,0)
		metrics.boot_gap_m = maxf(metrics.boot_gap_m,skier.to_global(points[prefix+"Foot"]).distance_to(expected_ankle))
		var boot: Basis = skier.rendered_rotations[prefix+"Foot"]
		var axis: Vector3 = boot.transposed()*(points[prefix+"Leg"]-points[prefix+"Foot"]).normalized()
		metrics.cuff_side_deg = maxf(metrics.cuff_side_deg,absf(rad_to_deg(atan2(axis.x,axis.y))))
		metrics.cuff_flex_min_deg = minf(metrics.cuff_flex_min_deg,rad_to_deg(atan2(axis.z,axis.y)))
		metrics.cuff_flex_max_deg = maxf(metrics.cuff_flex_max_deg,rad_to_deg(atan2(axis.z,axis.y)))

func run():
	baseline_air = "--baseline-air-rates" in OS.get_cmdline_user_args()
	skier = preload("res://scripts/presentation/skier_visual.gd").new()
	# This suite specifies the retained procedural comparison's authored shape.
	# Full-curve contacts/continuity are covered in steep_motion_suite.gd.
	skier.animation.full_motion.enabled = false
	root.add_child(skier)
	await process_frame
	var plane = TestPlane.new(0.0)
	var sim = setup(plane)
	var intent = RiderInput.new()
	inspect(sim)
	var neutral: float = skier.rendered_joints.Hips.y
	intent.jump_held = true
	advance(sim,intent,plane,24)
	inspect(sim)
	check(skier.animation.current.prepare>.99 and neutral-skier.rendered_joints.Hips.y>.075,"Holding jump creates a visibly compressed preparation in 0.2 seconds")
	var prep_curve: float = spine_curve_degrees()
	check(prep_curve>15 and skier.rendered_joints.Spine.z-skier.rendered_joints.Hips.z>.20,"Preparation rounds the spine and bends the chest forward")
	var hold: Dictionary = skier.animation.current.duplicate()
	advance(sim,intent,plane,120)
	check(absf(skier.animation.current.prepare-hold.prepare)<.00001 and sim.grounded and not sim.jump_executed,"Long hold remains steady and cannot launch or charge the jump")
	inspect(sim)
	check(spine_curve_degrees()>prep_curve and spine_curve_degrees()<29,"Spine follows compression smoothly and settles at bounded flexion")
	intent.jump_held = false
	intent.jump = true
	advance(sim,intent,plane,1)
	check(sim.jump_executed and not sim.grounded and skier.animation.phase=="takeoff","Only an executed hop starts the powered takeoff")
	intent.jump = false
	advance(sim,intent,plane,10)
	check(not sim.jump_executed and skier.animation.current.extension>.8,"Hop telemetry lasts one tick; animation carries the extension")
	intent.steer = .8
	intent.brake = .7
	advance(sim,intent,plane,12)
	inspect(sim,.5)
	check(skier.animation.current.air>.9 and skier.animation.current.steer>.4 and skier.animation.current.brake>.3,"Existing airborne controls produce bounded body-balance targets")
	var saw_ready = false
	var saw_landing = false
	for i in range(150):
		advance(sim,intent,plane,1)
		saw_ready = saw_ready or skier.animation.current.ready>.05
		saw_landing = saw_landing or skier.animation.phase=="landing"
		inspect(sim,.5)
	check(saw_ready and saw_landing,"Real ballistic hop anticipates terrain and interrupts flight for impact absorption")
	check(skier.animation.landing_events==1,"A normal two-ski hop generates one landing reaction")
	# Ordinary airborne release must not manufacture a hop event.
	sim = setup(plane,20)
	intent = RiderInput.new()
	intent.jump = true
	advance(sim,intent,plane,1)
	check(not sim.jump_executed and skier.animation.takeoff_power<1,"Unsupported release cannot trigger a powered takeoff")
	# Genuine early release is consumed when support returns through the buffer.
	sim = setup(plane,.04)
	sim.velocity = Vector3(0,-1,0)
	advance(sim,intent,plane,1)
	var buffered = sim.jump_executed
	intent.jump = false
	for i in range(8):
		advance(sim,intent,plane,1)
		buffered = buffered or sim.jump_executed
	check(buffered,"Buffered landing release emits the same successful-hop marker")
	# Deterministic takeoff from a physical ledge, using the existing test surface.
	var ledge = preload("res://tests/jump_suite.gd").Ledge.new()
	sim = setup(ledge)
	sim.velocity = Vector3(0,0,20)
	advance(sim,RiderInput.new(),ledge,20)
	check(not sim.grounded and skier.animation.takeoff_power==.20,"Natural ledge release uses softer unloading rather than a powered hop")
	# Layer geometry, high-speed reversals and the cosmetic snow burial path.
	var slope = TestPlane.new(.46)
	sim = setup(slope)
	intent = RiderInput.new()
	intent.tuck = 1
	sim.velocity = Vector3.BACK.slide(sim.surface_normal).normalized()*20
	advance(sim,intent,slope,240)
	inspect(sim)
	var back: Vector3 = skier.rendered_joints.Spine-skier.rendered_joints.Hips
	var back_degrees = 90.0-rad_to_deg(back.angle_to(Vector3.UP))
	check(absf(back_degrees-30)<3,"Curved tuck retains an overall back angle approximately 30 degrees above the ski plane")
	var tuck_curve: float = spine_curve_degrees()
	check(tuck_curve>20 and tuck_curve<27,"Deep tuck distributes forward curvature across the lumbar and chest links")
	var lower: Vector3 = skier.rendered_joints.Spine02-skier.rendered_joints.Hips
	var middle: Vector3 = skier.rendered_joints.Spine01-skier.rendered_joints.Spine02
	var upper: Vector3 = skier.rendered_joints.Spine-skier.rendered_joints.Spine01
	check(lower.cross(middle).x>0 and middle.cross(upper).x>0,"Both spinal bends curve forward instead of hinging at a single joint")
	check(skier.rendered_rotations.Head.is_equal_approx(sim.body.rotations.Head),"Neck counterbalances the curved chest while the head keeps its physical forward gaze")
	check(absf(skier.rendered_joints.RightHand.x-skier.rendered_joints.LeftHand.x)<.18,"Tuck brings the hands together and closes the arm silhouette")
	var last_points: Dictionary = skier.rendered_joints.duplicate()
	for tick in range(480):
		intent.steer = .85 if tick%160<80 else -.85
		intent.tuck = .5
		intent.jump_held = tick>400
		advance(sim,intent,slope,1)
		for alpha in [0.0,.5,1.0]: inspect(sim,alpha)
		for id in skier.rendered_joints:
			metrics.max_joint_step_m = maxf(metrics.max_joint_step_m,skier.rendered_joints[id].distance_to(last_points[id]))
		last_points = skier.rendered_joints.duplicate()
	check(absf(skier.animation.current.carve)>.05,"Loaded carving drives body angulation")
	check(metrics.max_joint_step_m<.08,"Rapid reversals/preparation do not snap rendered joints by more than 8 cm per tick")
	skier.snow_burial_enabled = true
	for ski in sim.skis: ski.penetration = .12
	inspect(sim,.5)
	skier.snow_burial_enabled = false
	check(metrics.length_error_m<.002,"Composed limbs retain their physical segment lengths")
	check(metrics.boot_gap_m<.0005,"Animated feet remain attached to rigid bindings, including snow burial")
	check(metrics.cuff_side_deg<12 and metrics.cuff_flex_min_deg>-5 and metrics.cuff_flex_max_deg<40,"New poses retain the cuff side/flex envelope")
	# Contact fixtures isolate strength/cluster timing from terrain difficulty.
	var depths: Array[float] = []
	var landing_curves: Array[float] = []
	for speed in [2.0,6.0,12.0]:
		sim = setup(plane)
		sim.ticks += 1
		sim.skis[0].landing_speed = speed
		sim.skis[1].landing_speed = speed
		sim.motion.capture(sim,DT)
		skier.step_animation(DT,sim,RiderInput.new(),plane)
		var duration: float = skier.animation.landing_duration
		var peak = 0.0
		var peak_curve = 0.0
		for tick in range(140):
			sim.ticks += 1
			for ski in sim.skis: ski.landing_speed = 0
			sim.motion.capture(sim,DT)
			skier.step_animation(DT,sim,RiderInput.new(),plane)
			peak = maxf(peak,skier.animation.current.impact_drop)
			inspect(sim)
			peak_curve = maxf(peak_curve,spine_curve_degrees())
		depths.append(peak)
		landing_curves.append(peak_curve)
		check(skier.animation.current.impact==0 and skier.animation.landing_events==1,"Landing %.0f m/s settles once after %.2f seconds"%[speed,duration])
		check(spine_curve_degrees()<7,"Landing %.0f m/s releases spinal flexion after absorption"%speed)
	check(depths[0]<depths[1] and depths[1]<depths[2] and depths[2]>.17,"Small, medium and large impacts produce progressively deeper absorption")
	check(landing_curves[0]<landing_curves[1] and landing_curves[1]<landing_curves[2] and landing_curves[2]>20,"Impact strength also scales the flexible back follow-through")
	sim = setup(plane)
	for tick in range(20):
		sim.ticks += 1
		sim.skis[0].landing_speed = 3.0 if tick<10 else 9.0
		sim.motion.capture(sim,DT)
		skier.step_animation(DT,sim,RiderInput.new(),plane)
	check(skier.animation.landing_events==1 and skier.animation.landing_age>.14 and skier.animation.landing_speed==9,"Contact cluster upgrades strength without restarting the reaction")
	check(skier.animation.current.impact_side<-.1,"One-ski impact biases the absorbing side")
	sim = setup(plane)
	for tick in range(60):
		sim.ticks += 1
		sim.skis[0].landing_speed = .3
		sim.motion.capture(sim,DT)
		skier.step_animation(DT,sim,RiderInput.new(),plane)
	check(skier.animation.landing_events==0,"Negligible contact chatter does not trigger a landing animation")
	# Deliberately overlap deep tuck/preparation, a hard impact and a reversal;
	# the visual reach limiter must remain safe at combined extremes too.
	sim = setup(slope)
	intent = RiderInput.new()
	intent.tuck = 1.0
	advance(sim,intent,slope,240)
	for tick in range(90):
		intent.steer = .85 if tick<45 else -.85
		intent.jump_held = tick<30
		advance(sim,intent,slope,1)
		if tick==20:
			sim.ticks += 1
			sim.skis[0].landing_speed = 12.0
			sim.motion.capture(sim,DT)
			skier.step_animation(DT,sim,intent,slope)
		for alpha in [0.0,.5,1.0]: inspect(sim,alpha)
	check(metrics.length_error_m<.002 and metrics.cuff_side_deg<12 and metrics.cuff_flex_max_deg<40,"Overlapping tuck, preparation, hard impact and reversal preserve reach/cuff constraints")
	# Renderer schedules cannot alter the simulation, animation, or recordings.
	var reference: Array = []
	var repeat_stable = true
	for fps in [30,60,120,144,240]:
		sim = setup(plane)
		var control = Sim.new()
		if baseline_air: control.tuning = sim.tuning.duplicate()
		control.reset(Vector3.ZERO)
		control.prime_contacts(plane)
		intent = RiderInput.new()
		var render_time = 0.0
		for tick in range(180):
			intent.tuck = .8
			intent.jump_held = tick<24
			intent.jump = tick==24
			intent.steer = sin(tick*.025)*.5
			advance(sim,intent,plane,1)
			control.step(DT,intent,plane)
			while render_time<float(tick+1)*DT:
				skier.pose(sim,fmod(render_time,DT)/DT)
				render_time += 1.0/fps
		var actual = [Replay.snapshot(1.5,sim),sim.body.angular_momentum,sim.impacts.reserve,skier.animation.current.duplicate()]
		check(Replay.snapshot(1.5,sim)==Replay.snapshot(1.5,control) and sim.body.angular_momentum==control.body.angular_momentum,"Animation preserves exact simulation/recorded poses at %d FPS"%fps)
		if reference.is_empty(): reference = actual
		repeat_stable = repeat_stable and actual==reference
	check(repeat_stable,"All render schedules produce identical animation and simulation states")
	var before = skier.animation.current.duplicate()
	for i in range(100): skier.pose(sim,.5)
	check(before==skier.animation.current,"Repeated rendering cannot advance animation")
	skier.animation.hold()
	check(skier.animation.sample(0)==skier.animation.sample(1),"Pause/resume collapses animation interpolation without rewinding")
	sim.reset(Vector3.ZERO)
	sim.prime_contacts(plane)
	advance(sim,RiderInput.new(),plane,1)
	check(skier.animation.landing_events==0 and skier.animation.current.prepare==0,"Restart discards stale phase and landing history")
	check(skier.animation.prediction_samples<=8,"Landing anticipation has a fixed eight-sample upper bound")
	# A composed crash must begin from precisely that pose and keep incoming
	# momentum; no neutral-frame reset is allowed in PhysicalBone startup.
	intent = RiderInput.new()
	intent.tuck = 1.0
	advance(sim,intent,plane,180)
	skier.pose(sim)
	var composed = skier.desired.duplicate()
	sim.velocity = Vector3(0,-2,20)
	sim.crash("ANIMATION HANDOFF TEST")
	skier.ragdoll.start(sim)
	var handed_off = true
	var momentum = Vector3.ZERO
	for id in skier.ragdoll.bodies:
		var physical = skier.ragdoll.bodies[id]
		var expected: Transform3D = skier.skeleton.global_transform*composed[skier.bone_ids[id]]*physical.body_offset
		handed_off = handed_off and physical.global_transform.is_equal_approx(expected)
		momentum += physical.linear_velocity*physical.mass
	check(handed_off and composed==skier.desired,"Crash seeds every physical segment from the exact composed animation pose")
	check((momentum/sim.tuning.rider_mass).distance_to(sim.velocity)<.001,"Animated crash handoff retains incoming total momentum")
	skier.ragdoll.stop()
	check(metrics.length_error_m<.002 and metrics.cuff_side_deg<12 and metrics.cuff_flex_max_deg<40,"All landing strengths also preserve rendered limb/cuff constraints")
	check(metrics.spine_length_error_m<.00001,"Every spinal and neck segment keeps its rest length across motion and interpolation")
	check(metrics.chest_attachment_error_m<.00001,"Shoulders and neck remain rigidly attached to the moving upper chest")
	check(metrics.spine_joint_angle_deg<20 and metrics.neck_angle_deg<60,"Combined tuck, jump and landing keep spinal and neck bends bounded")
	DirAccess.make_dir_recursive_absolute("res://artifacts/skier_animation")
	var result = {"checks":checks,"failures":failures,"metrics":metrics,"impact_peaks_m":depths,"tuck_back_degrees":back_degrees,"tuck_curve_degrees":tuck_curve,"landing_curve_degrees":landing_curves,"baseline_air_rates":baseline_air}
	var result_path = "res://artifacts/skier_animation/animation_results_air_baseline.json" if baseline_air else "res://artifacts/skier_animation/animation_results.json"
	FileAccess.open(result_path,FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("SKIER_ANIMATION_RESULTS ",JSON.stringify(result))
	skier.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

func spine_curve_degrees() -> float:
	var points: Dictionary = skier.rendered_joints
	return rad_to_deg((points.Spine02-points.Hips).angle_to(points.Spine-points.Spine01))

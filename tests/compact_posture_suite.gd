extends SceneTree
## Measure final silhouette through production ticks and the final skeleton writer.
const Sim = preload("res://scripts/core/ski_simulation.gd")
const Visual = preload("res://scripts/presentation/skier_visual.gd")
const TestSlope = preload("res://tests/physics_suite.gd").TestPlane
const Replay = preload("res://scripts/racing/run_replay.gd")
const DT = 1.0/120.0
var checks = 0
var failures: Array[String] = []
var rows: Dictionary = {}
func _initialize(): call_deferred("run")
func check(ok: bool, description: String):
	checks += 1
	if not ok: failures.append(description)
	print("PASS: " if ok else "FAIL: ",description)
func run():
	var before = "--baseline" in OS.get_cmdline_user_args()
	var visual = Visual.new(); visual.preview_only = true; root.add_child(visual); await process_frame
	if before: visual.animation.full_motion = load("res://artifacts/compact_posture/baseline/skier_full_motion.gd").new()
	for scenario in ["glide","tuck","carve","tuck_carve","light_carve_left","light_carve_right","prepare","hop","big_air"]:
		var sim = Sim.new(); var control = Sim.new(); var surface = TestSlope.new(.30)
		for model in [sim,control]:
			model.reset(Vector3(0,16 if scenario=="big_air" else 0,0)); model.prime_contacts(surface)
			model.velocity = model.support_basis().z*25
			if scenario=="big_air": model._begin_flight(model.support_basis()); model.velocity += Vector3.UP*6
		visual.reset_animation(sim)
		var intent = RiderInput.new(); var same = true
		var samples: Array = []; var last = {}; var joint_step = 0.0; var settled_pole_back = 1.0
		var peak_step = {}
		for tick in 480:
			intent.tuck = 1.0 if scenario in ["tuck","tuck_carve","light_carve_left","light_carve_right"] else 0.0
			intent.steer = .2 if scenario in ["carve","tuck_carve"] else 0.0
			if scenario.begins_with("light_carve"): intent.steer = -.06 if scenario.ends_with("left") else .06
			intent.jump_held = scenario in ["prepare","hop"] and tick<90
			intent.jump = scenario=="hop" and tick==90
			sim.step(DT,intent,surface); control.step(DT,intent,surface)
			visual.step_animation(DT,sim,intent,surface); visual.pose(sim)
			same = same and Replay.snapshot(tick*DT,sim)==Replay.snapshot(tick*DT,control) and sim.body.com==control.body.com
			var j = visual.rendered_joints; var r = visual.rendered_rotations
			for bone in last:
				var distance: float = j[bone].distance_to(last[bone])
				if distance>joint_step:
					joint_step = distance
					peak_step = {"tick":sim.ticks,"bone":bone,"phase":visual.animation.full_motion.phase,"grounded":sim.grounded,"impact":visual.animation.current.impact}
			last = j.duplicate()
			var observe = tick>=120
			if scenario=="prepare": observe = tick>=30 and tick<90
			if scenario=="hop": observe = tick>=90 and tick<150
			if scenario=="big_air": observe = tick>=150 and tick<240
			if not observe: continue
			var feet: Vector3 = (j.LeftFoot+j.RightFoot)*.5
			var hips: Vector3 = j.Hips-feet
			var knee = 0.0; var pole_out = 0.0; var pole_back = 1.0; var cuff_flex = 0.0; var hip_clearance = INF; var thigh_clearance = INF
			var hip_distance = 0.0; var hip_vertical = 0.0
			var shaft_lateral = 0.0; var tip_left = -INF; var tip_right = INF; var hand_forward = 0.0
			var up: Vector3 = (r.LeftFoot.y+r.RightFoot.y).normalized()
			var forward: Vector3 = (r.LeftFoot.z+r.RightFoot.z).slide(up).normalized()
			var lateral = up.cross(forward).normalized()
			for prefix in ["Left","Right"]:
				knee += rad_to_deg((j[prefix+"Leg"]-j[prefix+"UpLeg"]).angle_to(j[prefix+"Foot"]-j[prefix+"Leg"]))* .5
				pole_out = maxf(pole_out,absf((r[prefix+"Hand"]*Vector3.FORWARD).dot(r.Spine.x)))
				var cuff: Vector3 = r[prefix+"Foot"].transposed()*(j[prefix+"Leg"]-j[prefix+"Foot"]).normalized()
				cuff_flex = maxf(cuff_flex,rad_to_deg(atan2(cuff.z,cuff.y)))
				var pole = visual.poles[0 if prefix=="Right" else 1]
				var grip: Vector3 = pole.position; var shaft: Vector3 = -pole.basis.y
				shaft_lateral=maxf(shaft_lateral,absf(shaft.dot(lateral)))
				var tip: float=(grip+shaft*1.18-j.Hips).dot(lateral)
				tip_left=maxf(tip_left,tip); tip_right=minf(tip_right,tip)
				hand_forward=maxf(hand_forward,(j[prefix+"Hand"]-j.Spine).dot(forward))
				pole_back = minf(pole_back,-shaft.dot((r.LeftFoot.z+r.RightFoot.z).normalized()))
				var at: float = (j.Hips-grip).dot(forward)/minf(-.001,shaft.dot(forward))
				var side = -1.0 if prefix=="Right" else 1.0
				var passage: Vector3 = grip+shaft*at-j.Hips
				hip_clearance = minf(hip_clearance,side*passage.dot(lateral)-.17)
				hip_distance = maxf(hip_distance,absf(passage.dot(lateral)))
				hip_vertical = maxf(hip_vertical,absf(passage.dot(up)))
				for leg in ["Left","Right"]:
					var pair = Geometry3D.get_closest_points_between_segments(grip,grip+shaft*1.18,j[leg+"UpLeg"],j[leg+"Leg"])
					thigh_clearance = minf(thigh_clearance,pair[0].distance_to(pair[1])-.09)
			if scenario=="prepare" and tick>=60: settled_pole_back=minf(settled_pole_back,pole_back)
			samples.append({"time":(tick+1)*DT,"hips_y":hips.y,"hips_z":hips.z,"knee":knee,
				"hands":absf((j.LeftHand-j.RightHand).dot(r.Spine.x)),"elbows":absf((j.LeftForeArm-j.RightForeArm).dot(r.Spine.x)),"pole_out":pole_out,"pole_back":pole_back,"cuff_flex":cuff_flex,"hip_clearance":hip_clearance,"hip_distance":hip_distance,"hip_vertical":hip_vertical,"thigh_clearance":thigh_clearance,"shaft_lateral":shaft_lateral,"pole_tip_width":tip_left-tip_right,"hand_forward":hand_forward,"downhill":visual.animation.full_motion.downhill_amount})
		var result = {"peak_step":peak_step,"settled_pole_back":settled_pole_back,"max_joint_step":joint_step,"physics_equal":same,"samples":samples.size(),"crash":sim.crash_reason}
		for key in ["hips_y","hips_z","knee","hands","elbows","pole_out","pole_back","cuff_flex","hip_clearance","hip_distance","hip_vertical","thigh_clearance","shaft_lateral","pole_tip_width","hand_forward","downhill"]:
			var values: Array = []; var sum = 0.0
			for sample in samples: values.append(sample[key]); sum += sample[key]
			values.sort(); result[key] = {"mean":sum/values.size(),"min":values[0],"max":values[-1]}
		rows[scenario] = result
		check(same and not sim.crashed,scenario+": physical run is unchanged")
		check(joint_step<.08,scenario+": final joints stay continuous")
	if not before:
		check(rows.tuck.knee.mean>85.0 and rows.tuck.knee.mean<100.0,"Deep tuck keeps a folded thigh without forcing the additional knee compression")
		check(rows.tuck.hips_y.mean<.56 and rows.tuck.hips_y.mean>.40 and rows.tuck.hips_z.mean>-.24 and rows.tuck.hips_z.mean<-.08,"Reviewed tuck retains feasible compression with the pelvis advanced over the boots")
		check(rows.tuck.hands.max<.38 and rows.tuck.hands.min>.12 and rows.tuck.elbows.max<.55,"Reviewed tuck gathers connected hands and keeps elbows close to the ribs")
		check(rows.tuck.shaft_lateral.max<.28 and rows.tuck.pole_tip_width.max<.74,"tuck: the full pole shafts and tips stay within the compact silhouette")
		check(rows.tuck.hand_forward.max<.30 and rows.tuck.elbows.max<.52,"tuck: hands stay near the chest and elbows remain beside the body")
		check(rows.tuck.hip_clearance.min>0 and rows.tuck.thigh_clearance.min>0 and rows.tuck.pole_back.min>.70,"Actual tuck shafts trail backward outside the hips and both thigh volumes throughout the source loop")
		for scenario in ["glide","tuck"]:
			check(rows[scenario].hip_distance.max<.30 and rows[scenario].hip_vertical.max<(.20 if scenario=="glide" else .14),scenario+": shafts pass close beside the hips, within the lateral and vertical corridor")
		check(rows.glide.hands.min>.40 and rows.glide.hands.max<.65 and rows.carve.hands.min>.60,"Regular downhill uses forward ready carry while carving retains source counterbalance")
		# Free carving is checked against the tucked silhouette below. Its
		# amplitude follows balance telemetry; it need not reproduce source sway.
		for scenario in ["carve","tuck_carve"]:
			check(rows[scenario].downhill.mean<.25 and rows[scenario].hands.mean>rows.tuck.hands.mean+.12,scenario+": sustained loaded carving restores free balance arms")
		# A 6% correction must retain most of the compact tuck. The former
		# full-release assertion encoded the proportional-carving defect.
		for scenario in ["light_carve_left","light_carve_right"]:
			check(rows[scenario].downhill.min>.75 and rows[scenario].hands.max<rows.tuck.hands.max+.12,scenario+": a light correction retains proportional compact carry")
		var cuff_ok = true
		for row in rows.values(): cuff_ok = cuff_ok and row.cuff_flex.max<24.1
		check(cuff_ok,"Final shins respect the 24-degree visual cuff envelope")
		# A jump crouch now sweeps the arms beside the hips before departure.
		# The tight racing-tuck hand and hip corridors do not describe this action.
		check(rows.prepare.hands.mean>.45 and rows.prepare.hands.max<.85 and rows.prepare.elbows.max<.80,"Jump preparation separates the hands beside the hips while keeping a bounded elbow sweep")
		check(rows.prepare.hip_clearance.min>0 and rows.prepare.thigh_clearance.min>0 and rows.prepare.pole_back.min>0 and rows.prepare.settled_pole_back>.70,"Preparation shafts clear both thighs and hips through the sweep, then settle into backward carry")
		# Action review a17 accepts a brief 82.4 cm readiness brace: the connected
		# arms open for balance before contact. Narrower targets clipped the jacket.
		# This is a visual action envelope, not an anatomical joint-angle limit.
		check(rows.hop.hands.max<.85 and rows.hop.elbows.max<.85,"Ordinary takeoff retains free balance arms without the broad sustained-flight counterbalance")
		check(rows.big_air.hands.max>.75 and rows.big_air.hands.mean>rows.hop.hands.mean+.15,"Larger, sustained flight still permits open counterbalance")
	DirAccess.make_dir_recursive_absolute("res://artifacts/boot_posture_correction")
	var result = {"checks":checks,"failures":failures,"cases":rows,"physics":Sim.MODEL_VERSION}
	preload("res://tests/test_report.gd").write("res://artifacts/boot_posture_correction/"+("before_metrics" if before else "after_metrics")+".json",JSON.stringify(result,"\t"))
	print("COMPACT_POSTURE ",checks," checks, ",failures.size()," failures")
	visual.queue_free(); await process_frame; quit(0 if failures.is_empty() else 1)

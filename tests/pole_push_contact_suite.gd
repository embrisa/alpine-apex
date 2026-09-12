extends SceneTree
## Actual production final-pose contact, with matched unmodified solver ticks.
## No session/PB/preferences. Native chronology and actual mesh audit still required.
const Fixtures = preload("res://tests/pole_push_suite.gd")
const Visual = preload("res://scripts/presentation/skier_visual.gd")
const PolePose = preload("res://scripts/presentation/pole_push_pose.gd")
const Anatomy = preload("res://scripts/presentation/skier_anatomy.gd")
const Body = preload("res://scripts/core/rider_body.gd")
const DT = 1.0/120.0
var checks = 0
var failures: Array = []
var cases: Array = []
var only = PackedStringArray()
var seconds = 0.0
var trace = false
var output = "res://artifacts/orchestration_20260912/poles/contact_d/validation/contact.json"

func _initialize() -> void: call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
	print("PASS: " if ok else "FAIL: ",label)

func intent_at(name: String, tick: int):
	var intent = RiderInput.new(); intent.tuck = 1.0 if tick<1500 else 0.0
	if name=="brake_departure":
		intent.brake = .5 if tick>=480 and tick<600 else 0.0
		intent.jump_held = tick>=960 and tick<990; intent.jump = tick==990
	return intent

func plain(value):
	if value is Vector3: return [value.x,value.y,value.z]
	if value is Array:
		var result: Array = []
		for item in value: result.append(plain(item))
		return result
	if value is Dictionary:
		var result = {}
		for key in value: result[key] = plain(value[key])
		return result
	return value

func context(sim, diag: Dictionary) -> Dictionary:
	return {"frame":sim.ticks/2-1,"tick":sim.ticks,"phase":sim.pole_push_phase,"power":sim.pole_push_power,"acceleration_mps2":sim.pole_push_acceleration,"intensity":sim.pole_push_intensity,"speed_mps":sim.velocity.length(),"grounded":sim.grounded,"target_stage":diag.get("pole_target_stage","unknown"),"contact_weight":diag.get("tip_contact_weight",0.0),"carry_weight":diag.get("tip_carry_weight",0.0),"wrist_targets":diag.get("tip_wrist_targets",[]),"elbow_fit_rad":diag.get("tip_elbow_fit_rad",[]),"reach_residual_m":diag.get("tip_reach_residual_m",[])}

func peak(rows: Array, row: Dictionary) -> void:
	rows.append(row)
	rows.sort_custom(func(a,b): return a.magnitude_m>b.magnitude_m)
	if rows.size()>12: rows.resize(12)

func cycle_receipt(cycle: Dictionary, complete: bool) -> Dictionary:
	var covered: bool = complete and cycle.first_phase<=.16 and cycle.last_phase>=.92 and cycle.front_count>0 and cycle.back_count>0
	var spans: Array = []
	if cycle.front_count>0 and cycle.back_count>0:
		for side in 2: spans.append(cycle.front[side]-cycle.back[side])
	return {"first_tick":cycle.first_tick,"last_tick":cycle.last_tick,"first_phase":cycle.first_phase,"last_phase":cycle.last_phase,"covered":covered,"complete":complete,"early_force_frames":cycle.front_count,"late_force_frames":cycle.back_count,"directional_sweep_m":spans}

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		if arg.begins_with("--only="): only = arg.trim_prefix("--only=").split(",")
		if arg.begins_with("--seconds="): seconds = maxf(3.0,float(arg.trim_prefix("--seconds=")))
		if arg=="--trace": trace = true
	check(PolePose.contact_weight(0.0)==1 and PolePose.contact_weight(.06)==1 and PolePose.contact_weight(.70318)==1 and PolePose.contact_weight(.76)==1 and PolePose.contact_weight(.90)==0 and PolePose.contact_weight(.99)>.98,"full loaded contact, released midpoint and anticipatory next plant share a continuous wrap")
	var projection_step = 0.0; var last_projection = Vector3.ZERO
	for n in 201:
		var anchor = Vector3(0,0,-.70-float(n)*.002)
		var wanted = PolePose.wrist_on_sphere(Vector3(0,.84,.16),Vector3(0,1.24,.18),anchor,1.164,.46)
		if n>0: projection_step = maxf(projection_step,wanted.distance_to(last_projection))
		last_projection = wanted
	check(projection_step<.012,"finite reach projection does not collapse at arm/pole sphere tangency")
	var visual = Visual.new(); visual.preview_only = true; root.add_child(visual); await process_frame
	for spec in [["flat",0.0,0.0,6.0],["fast",0.0,10.0,6.0],["brake_departure",0.0,0.0,13.0],["gentle",10.0,0.0,6.0],["steep15",20.0,0.0,6.0],["steep10",28.0,0.0,6.0],["steep5",34.0,0.0,6.0]]:
		var name: String = spec[0]
		if not only.is_empty() and not name in only: continue
		var surface = Fixtures.SlopePlane.new(spec[1])
		var sim = Fixtures.make_sim(surface,spec[2]); var control = Fixtures.make_sim(surface,spec[2])
		visual.reset_animation(sim); visual.pose(sim,1.0)
		var last = {}; var last_tips: Array = []; var last_anchors: Array = []; var last_power = 0.0
		var unchanged = true; var lower_body_unchanged = true; var finite = true; var phase_equal = true
		var max_height = 0.0; var max_anchor_gap = 0.0; var gap_sum = 0.0; var force_poles = 0; var force_frames = 0
		var max_grip = 0.0; var max_bone = 0.0; var max_step = 0.0; var max_tip_step = 0.0
		var max_wrist_swing = 0.0; var max_wrist_twist = 0.0; var sweep_front = -INF; var sweep_back = INF
		var unsupported_fit = false; var worst: Array = []; var fit_us = 0; var pose_count = 0
		var last_meta = {}; var joint_peaks = {}; var joint_steps: Array = []; var tip_steps: Array = []; var contact_peaks: Array = []; var trace_rows: Array = []
		var cycles: Array = []; var cycle = {}; var minimum_cycle_sweep = INF; var covered_cycles = 0
		var repeatable_pose = true; var contact_us = 0.0; var total_probes = 0; var fitted_arms = 0
		var duration: float = minf(spec[3],seconds) if seconds>0 else spec[3]
		for tick in int(duration/DT):
			var intent = intent_at(name,tick)
			sim.step(DT,intent,surface); control.step(DT,intent,surface)
			visual.step_animation(DT,sim,intent,surface)
			phase_equal = phase_equal and visual.animation.full_motion.pole_phase==sim.pole_push_phase
			if tick%2==0: continue
			var started = Time.get_ticks_usec(); visual.pose(sim,1.0); fit_us += Time.get_ticks_usec()-started; pose_count += 1
			unchanged = unchanged and sim.position==control.position and sim.velocity==control.velocity and sim.body.joints==control.body.joints and sim.pole_push_phase==control.pole_push_phase
			var joints: Dictionary = visual.rendered_joints.duplicate(); var rotations: Dictionary = visual.rendered_rotations.duplicate()
			var diag: Dictionary = visual.animation.full_motion.diagnostics.duplicate(true)
			var anchors: Array = diag.get("tip_anchors",[])
			var meta = context(sim,diag)
			contact_us += diag.get("pole_contact_cpu_us",0.0)
			for probes in diag.get("tip_arm_probes",[]): total_probes += probes; fitted_arms += 1
			if trace: trace_rows.append({"state":meta,"joints":joints,"anchors":anchors,"height_m":diag.get("tip_ground_height_m",[]),"gap_m":diag.get("tip_gap_m",[])})
			var tips: Array = []
			for id in joints:
				finite = finite and joints[id].is_finite()
				if last.has(id):
					var step: float = joints[id].distance_to(last[id]); max_step = maxf(max_step,step)
					var row = {"magnitude_m":step,"joint":id,"from":last[id],"to":joints[id],"previous":last_meta,"current":meta}
					peak(joint_steps,row)
					if not joint_peaks.has(id) or step>joint_peaks[id].magnitude_m: joint_peaks[id] = row
			last = joints
			for i in 2:
				var prefix = "Right" if i==0 else "Left"; var hand = prefix+"Hand"; var elbow = prefix+"ForeArm"
				var offset = Vector3(-.070 if i==0 else .070,0,.018)
				var grip: Vector3 = visual.to_global(joints[hand]+rotations[hand]*offset)
				max_grip = maxf(max_grip,grip.distance_to(visual.poles[i].global_position))
				var tip: Vector3 = visual.poles[i].global_transform*Vector3(0,-PolePose.TIP_LENGTH,0)
				tips.append(tip)
				for pair in [[prefix+"Shoulder",prefix+"Arm"],[prefix+"Arm",elbow],[elbow,hand]]:
					var connected: Vector3 = joints[pair[0]]+rotations[pair[0]]*(Body.REST[pair[1]]-Body.REST[pair[0]])
					max_bone = maxf(max_bone,connected.distance_to(joints[pair[1]]))
				if sim.pole_push_acceleration>0.0:
					var sample: Dictionary = surface.sample(tip.x,tip.z)
					var height: float = (tip-Vector3(tip.x,sample.height,tip.z)).dot(sample.normal)
					max_height = maxf(max_height,absf(height)); force_poles += 1
					var gap = tip.distance_to(anchors[i]) if anchors.size()==2 else INF
					max_anchor_gap = maxf(max_anchor_gap,gap); gap_sum += gap
					peak(contact_peaks,{"magnitude_m":gap,"side":i,"actual_tip":tip,"anchor":anchors[i] if anchors.size()==2 else Vector3.INF,"height_m":height,"current":meta})
					if absf(height)>.04 or gap>.18: worst.append({"tick":sim.ticks,"side":i,"phase":sim.pole_push_phase,"power":sim.pole_push_power,"height_m":height,"anchor_gap_m":gap})
					var axis: Vector3 = (Body.REST[hand]-Body.REST[elbow]).normalized()
					var local: Basis = rotations[elbow].transposed()*rotations[hand]
					var twist = Anatomy.twist_angle(local,axis)
					max_wrist_twist = maxf(max_wrist_twist,absf(twist))
					max_wrist_swing = maxf(max_wrist_swing,Anatomy.vector((local*Basis(axis,-twist)).get_rotation_quaternion()).length())
					if last_tips.size()==2 and last_power>0.0 and anchors==last_anchors:
						var step: float = tip.distance_to(last_tips[i]); max_tip_step = maxf(max_tip_step,step)
						peak(tip_steps,{"magnitude_m":step,"side":i,"from":last_tips[i],"to":tip,"anchor":anchors[i],"previous":last_meta,"current":meta})
			if sim.pole_push_acceleration>0.0: force_frames += 1
			# Intensity>.5 selects only 17/180 B fast smoke samples and misses the
			# loaded stroke. Require both wrists to sweep backward DURING force in
			# every complete phase-covered cycle, preserving the original 12 cm gate.
			if not cycle.is_empty() and (sim.pole_push_phase<cycle.last_phase or not sim.pole_push.active):
				cycles.append(cycle_receipt(cycle,sim.pole_push_phase<cycle.last_phase)); cycle = {}
			if sim.pole_push.active:
				if cycle.is_empty(): cycle = {"first_tick":sim.ticks,"first_phase":sim.pole_push_phase,"front":[-INF,-INF],"back":[INF,INF],"front_count":0,"back_count":0}
				cycle.last_tick = sim.ticks; cycle.last_phase = sim.pole_push_phase
				var early: bool = sim.pole_push_acceleration>0 and sim.pole_push_phase>=.06 and sim.pole_push_phase<=.35
				var late: bool = sim.pole_push_acceleration>0 and sim.pole_push_phase>=.55 and sim.pole_push_phase<=.76
				if early: cycle.front_count += 1
				if late: cycle.back_count += 1
				for side in 2:
					var prefix = "Right" if side==0 else "Left"
					var reach: float = (joints[prefix+"Hand"]-joints[prefix+"Arm"]).z
					if early: cycle.front[side] = maxf(cycle.front[side],reach)
					if late: cycle.back[side] = minf(cycle.back[side],reach)
			if sim.pole_push_intensity>.5:
				var reach: float = (joints.RightHand-joints.RightArm).z
				sweep_front = maxf(sweep_front,reach); sweep_back = minf(sweep_back,reach)
			unsupported_fit = unsupported_fit or (not sim.grounded and diag.get("tip_contact_weight",0.0)>0.0)
			last_tips = tips; last_anchors = anchors; last_power = sim.pole_push_acceleration; last_meta = meta
			# Recompose without the new contact fit at exactly the same state.
			# Source torso, physical pelvis/skis and leg fitting must match exactly.
			var without = visual.animation.full_motion.sample(1.0); without.pole_plant = 0.0; without.pole_carry = 0.0
			visual.pose(sim,1.0,without)
			# Keep the exact fitter input at ranked neighboring frames for a cheap
			# independent IK reproducer; no additional simulation or pose call.
			meta.fit_input_joints = {}; meta.fit_input_rotations = {}
			meta.fit_anchors = anchors; meta.fit_normals = visual.animation.full_motion.pole_target_normals.duplicate()
			meta.fit_root = {"origin":visual.global_position,"basis":[visual.global_basis.x,visual.global_basis.y,visual.global_basis.z]}
			for prefix in ["Right","Left"]:
				for part in ["Shoulder","Arm","ForeArm","Hand"]:
					var id: String = prefix+part
					meta.fit_input_joints[id] = visual.rendered_joints[id]
					var basis: Basis = visual.rendered_rotations[id]
					meta.fit_input_rotations[id] = [basis.x,basis.y,basis.z]
			for id in ["Hips","Spine02","Spine01","Spine","RightUpLeg","RightLeg","RightFoot","LeftUpLeg","LeftLeg","LeftFoot"]:
				lower_body_unchanged = lower_body_unchanged and joints[id]==visual.rendered_joints[id] and rotations[id].is_equal_approx(visual.rendered_rotations[id])
			if tick%60==1:
				# Interleaved preview, fractional renders and repeated same-tick pose
				# reads must not alter completed contact state or depend on call order.
				visual.pose(sim,.25); visual.pose(sim,.75); visual.pose(sim,1.0)
				for id in joints:
					repeatable_pose = repeatable_pose and joints[id].is_equal_approx(visual.rendered_joints[id])
					if rotations.has(id): repeatable_pose = repeatable_pose and rotations[id].is_equal_approx(visual.rendered_rotations[id])
		if not cycle.is_empty(): cycles.append(cycle_receipt(cycle,false))
		for receipt in cycles:
			if not receipt.covered: continue
			covered_cycles += 1
			for span in receipt.directional_sweep_m: minimum_cycle_sweep = minf(minimum_cycle_sweep,span)
		check(unchanged and phase_equal,name+": presentation preserves identical solver ticks and phase")
		check(lower_body_unchanged,name+": source torso, pelvis and physical leg fitting survive contact correction")
		check(force_frames>5,name+": real loaded frames were exercised")
		check(max_height<=.04,name+": all force frames keep actual rigid tips within 4 cm of snow")
		check(max_anchor_gap<=.18 and gap_sum/maxi(force_poles,1)<=.05,name+": fixed plant tracking has no large residual or persistent slide")
		check(max_tip_step<=.10,name+": loaded tips do not snap within one fixed plant")
		check(max_bone<.0002 and max_grip<.0001,name+": connected arms and fixed glove grips remain rigid")
		check(max_wrist_swing<=deg_to_rad(80.01) and max_wrist_twist<=deg_to_rad(30.01),name+": wrist remains inside existing carry envelope")
		check(finite and max_step<.14,name+": complete entry/load/release joints remain finite and continuous")
		check(covered_cycles>0 and minimum_cycle_sweep>.12,name+": each complete loaded stroke retains at least 12 cm of authored backward sweep in BOTH wrists")
		check(repeatable_pose,name+": contact is independent of duplicate, preview and fractional pose reads")
		check(not unsupported_fit,name+": no contact fitting in flight")
		cases.append({"name":name,"force_frames":force_frames,"tip_height_abs_max_m":max_height,"anchor_gap_max_m":max_anchor_gap,"anchor_gap_mean_m":gap_sum/maxi(force_poles,1),"tip_step_max_m":max_tip_step,"joint_step_max_m":max_step,"bone_error_max_m":max_bone,"grip_error_max_m":max_grip,"wrist_sweep_m":sweep_front-sweep_back,"fit_cpu_mean_us":float(fit_us)/maxi(pose_count,1),"worst_frames":worst,"duration_seconds":duration,"frames":pose_count,"pole_contact_cpu_mean_us":contact_us/maxi(pose_count,1),"arm_probes_mean":float(total_probes)/maxi(fitted_arms,1),"joint_peaks":joint_peaks,"worst_joint_steps":joint_steps,"worst_tip_steps":tip_steps,"worst_contacts":contact_peaks,"covered_cycles":covered_cycles,"minimum_loaded_cycle_sweep_m":minimum_cycle_sweep if covered_cycles>0 else null,"cycles":cycles,"trace":trace_rows})
	check(not cases.is_empty(),"requested fixture selection exercised at least one scenario")
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(plain({"checks":checks,"failures":failures,"cases":cases,"scope":"Actual final-pose analytic fixtures; consecutive 60 Hz joint deltas exclude the initial unstepped reset pose. Not native/clothing/controller acceptance."}),"\t"))
	print("POLE_CONTACT_RESULTS ",JSON.stringify({"checks":checks,"failures":failures,"output":output}))
	visual.queue_free(); await process_frame; quit(0 if failures.is_empty() else 1)

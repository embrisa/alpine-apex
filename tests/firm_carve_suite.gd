extends SceneTree
## Path response under ordinary input. No session, PB writes, or velocity servo.
const Sim = preload("res://scripts/core/ski_simulation.gd")
const DT = 1.0/120.0
const DIAGONAL = (.70710678-.12)/.88
const REFERENCE = "res://tests/fixtures/firm_carve_v34.json"
var checks=0
var failures: Array[String]=[]
func check(ok: bool, label: String):
	checks+=1
	if not ok: failures.append(label); printerr("FAIL: ",label)

class SnowPlane extends RefCounted:
	var depth = .16
	var cross_grade = 0.0
	var grade = .46
	func sample(x: float, z: float) -> Dictionary:
		return {"height":cross_grade*x-grade*z,"normal":Vector3(-cross_grade,1,grade).normalized()}
	func snow_depth_at(_x: float, _z: float) -> float: return depth
	func sweep_obstacle(_a: Vector3, _b: Vector3) -> String: return ""

static func measure(model, spec: Dictionary, overrides: Dictionary = {}, trace: bool = false, values = null) -> Dictionary:
	var sim = model.new(values if values!=null else load("res://config/ski_default.tres").duplicate(true))
	for key in overrides: sim.tuning.set(key,overrides[key])
	var field = SnowPlane.new(); field.depth=spec.depth; field.cross_grade=spec.cross
	sim.reset(Vector3.ZERO); sim.prime_contacts(field)
	var normal: Vector3 = field.sample(0,0).normal
	var forward = Vector3.BACK.slide(normal).normalized()
	var right = normal.cross(forward)
	sim.velocity=forward*spec.kmh/3.6; sim.effective_tuck=spec.tuck
	var input=RiderInput.new(); input.tuck=spec.tuck
	var row={"spec":spec,"time_1_deg":-1.0,"time_10_deg":-1.0,"time_45_deg":-1.0,"radius_45_m":-1.0,"speed_45_kmh":-1.0,
		"response_s":-1.0,"radius_at_45_m":-1.0,"peak_slip_deg":0.0,"recovery_ticks":0,"recovery_entries":0,"counterbank_ticks":0,"air_ticks":0,"trace":[],"samples":{}}
	var angle=0.0; var previous_heading=0.0; var distance=0.0; var reverse_tick=-1
	var response_ticks=0; var was_recovering=false
	# A reversal begins after the same 30-degree path excursion in each model.
	# Comparing after equal seconds would start from different turn phases.
	var count=600 if spec.mode=="reverse" else 360
	for tick in count:
		if spec.mode=="reverse" and reverse_tick<0 and angle>=deg_to_rad(30): reverse_tick=tick
		input.steer=spec.amount*spec.direction
		if reverse_tick>=0: input.steer*=-1.0
		if spec.mode=="release" and tick>=120: input.steer=0.0
		if spec.mode=="rapid": input.steer*=1.0 if tick%90<45 else -1.0
		var position: Vector3=sim.position; var speed: float=sim.speed_kmh(); var old_angle=angle
		sim.step(DT,input,field)
		var heading=atan2(sim.velocity.dot(right),sim.velocity.dot(forward))
		var delta=angle_difference(previous_heading,heading)*-spec.direction
		angle+=delta; previous_heading=heading
		var segment: float=position.distance_to(sim.position)
		for degrees in [1,10,45]:
			var key="time_%d_deg"%degrees
			if row[key]<0 and angle>=deg_to_rad(degrees):
				var fraction=clampf((deg_to_rad(degrees)-old_angle)/maxf(delta,.00000001),0,1)
				row[key]=(tick+fraction)*DT
				if degrees==45:
					row.radius_45_m=(distance+fraction*segment)/deg_to_rad(45)
					row.speed_45_kmh=lerpf(speed,sim.speed_kmh(),fraction)
					row.radius_at_45_m=sim.velocity.length()*DT/maxf(delta,.00000001)
		distance+=segment
		if reverse_tick>=0:
			response_ticks=response_ticks+1 if delta/DT<-deg_to_rad(5) else 0
			if response_ticks>=6 and row.response_s<0: row.response_s=(tick-reverse_tick-4)*DT
		row.peak_slip_deg=maxf(row.peak_slip_deg,absf(rad_to_deg(sim.slip_angle)))
		row.recovery_ticks+=int(sim.body.recovering_pose)
		row.recovery_entries+=int(sim.body.recovering_pose and not was_recovering)
		was_recovering=sim.body.recovering_pose
		row.counterbank_ticks+=int(absf(input.steer)>.25 and sim.body.roll*input.steer<-.1)
		row.air_ticks+=int(not sim.grounded)
		var local_tick=tick-reverse_tick if reverse_tick>=0 else tick
		if local_tick in [29,59,119] or trace:
			var sample={"s":(local_tick+1)*DT,"turn_deg":rad_to_deg(angle),"speed_kmh":sim.speed_kmh(),"travel_yaw":delta/DT,
				"input":input.steer,"requested_yaw":sim.steering_requested_yaw,"applied_yaw":sim.steering_applied_yaw,
				"transfer":sim.steering_transfer_factor,"slip_factor":sim.steering_slip_factor,"roll":sim.body.roll,"roll_velocity":sim.body.roll_velocity,
				"edge":[sim.skis[0].edge_angle,sim.skis[1].edge_angle],"load":sim.normal_load,"slip_deg":rad_to_deg(sim.slip_angle),
				"cop":sim.body.cop.x,"requested_cop":sim.body.requested_cop.x,"lateral":sim.lateral_acceleration,
				"recovering":sim.body.recovering_pose,"position":[sim.position.x,sim.position.y,sim.position.z]}
			if trace: row.trace.append(sample)
			if local_tick in [29,59,119]: row.samples[str(local_tick+1)]=sample
		if sim.crashed: break
		if reverse_tick>=0 and tick-reverse_tick>=179: break
	row.end_speed_kmh=sim.speed_kmh(); row.turn_deg=rad_to_deg(angle); row.crash=sim.crash_reason
	row.reverse_tick=reverse_tick; row.ticks=sim.ticks
	return row

func _initialize(): call_deferred("run")
func run():
	var output="artifacts/firm_carve/current.json"; var variants=[{}]; var trace=false; var full=false; var measure_only=false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
		if arg.begins_with("--variants="): variants=JSON.parse_string(FileAccess.get_file_as_string(arg.trim_prefix("--variants=")))
		if arg=="--trace": trace=true
		if arg=="--full": full=true
		if arg=="--measure-only": measure_only=true
	var rows=[]
	for variant in variants:
		for kmh in [60,120,160]:
			for depth in [.02,.16]:
				for cross in ([0.0,.2,-.2] if full else [0.0]):
					for direction in ([-1.0,1.0] if full else [1.0]):
						for amount in ([.2,DIAGONAL,1.0] if full else [DIAGONAL,1.0]):
							for mode in (["hold","reverse","release","rapid"] if full else ["hold","reverse"]):
								var spec={"kmh":kmh,"depth":depth,"cross":cross,"direction":direction,"amount":amount,"mode":mode,"tuck":DIAGONAL if amount==DIAGONAL else 0.0}
								var row=measure(Sim,spec,variant,trace); row.variant=variant; rows.append(row)
		print("FIRM_CARVE_VARIANT ",JSON.stringify(variant)," rows=",rows.size())
	if not measure_only and variants==[{}]:
		acceptance(rows)
		contracts()
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify({"model":Sim.MODEL_VERSION,"checks":checks,"failures":failures,"rows":rows},"\t"))
	print("FIRM_CARVE_RESULT ",output," cases=",rows.size()," checks=",checks," failures=",failures.size()); quit(0 if failures.is_empty() else 1)

func acceptance(rows: Array):
	var captured: Array=JSON.parse_string(FileAccess.get_file_as_string(REFERENCE)).rows
	var entry_ratios=[]; var reversal_ratios=[]; var radius_ratios=[]
	for row in rows:
		var matching=captured.filter(func(old): return case_key(old.spec)==case_key(row.spec))
		check(matching.size()==1,"Exactly one captured reference: "+str(row.spec))
		if matching.size()!=1: continue
		var old: Dictionary=matching[0]; var spec: Dictionary=row.spec
		check(row.crash.is_empty() and row.air_ticks==0,"Snow turning retains support: "+str(spec))
		if spec.amount<=.2:
			check(absf(row.turn_deg-old.turn_deg)<=maxf(.01,absf(old.turn_deg)*.05),"Small correction retains its travel response: "+str(spec))
			continue
		# Primary fall-line calibration separates entry delay from established
		# curvature; mirrored/cross-slope/release cases above protect support.
		if spec.cross!=0.0 or spec.direction!=1.0: continue
		if spec.mode=="hold":
			check(row.time_1_deg<=old.time_1_deg+DT,"Turn entry never becomes slower: "+str(spec))
			check(row.radius_45_m>0 and row.speed_45_kmh>=old.speed_45_kmh*.95,"Tighter path retains speed at the same angle: "+str(spec))
			check(row.peak_slip_deg<18.0,"Firm carve avoids broadside sliding: "+str(spec))
			if old.time_1_deg>.15: entry_ratios.append(row.time_1_deg/old.time_1_deg)
			radius_ratios.append(row.radius_45_m/old.radius_45_m)
		if spec.mode=="reverse":
			check(row.response_s>0 and row.response_s<=old.response_s+DT,"Reversal remains prompt: "+str(spec))
			if old.response_s>.15: reversal_ratios.append(row.response_s/old.response_s)
	check(entry_ratios.size()==6 and average(entry_ratios)<=.80,"At least 20% faster mean entry in the six delayed shallow-snow cases")
	check(reversal_ratios.size()==6 and average(reversal_ratios)<=.80,"At least 20% faster mean reversal in the six delayed shallow-snow cases")
	check(radius_ratios.size()==12 and average(radius_ratios)<=.85,"At least 15% tighter mean 45-degree arc across full and diagonal input")

static func average(values: Array) -> float:
	var sum=0.0
	for value in values: sum+=value
	return sum/maxi(1,values.size())

static func case_key(spec: Dictionary) -> String:
	# JSON decodes all numbers as floats; dictionary identity is type-sensitive.
	return "%d/%.3f/%.3f/%.0f/%.9f/%s/%.9f"%[spec.kmh,spec.depth,spec.cross,spec.direction,spec.amount,spec.mode,spec.tuck]

func contracts():
	var field=SnowPlane.new(); field.grade=0.0
	for depth in [.02,.16]:
		field.depth=depth
		var sim=Sim.new(); sim.reset(Vector3.ZERO); sim.prime_contacts(field); sim.velocity=Vector3.BACK*40
		var input=RiderInput.new(); input.steer=1.0
		var passive=true; var rate_limited=true; var supported_grip=true
		for tick in 360:
			if tick==180: input.steer=-1.0
			var energy: float=sim.velocity.slide(Vector3.UP).length_squared()
			var edges=[sim.skis[0].edge_angle,sim.skis[1].edge_angle]
			sim.step(DT,input,field)
			passive=passive and sim.velocity.slide(Vector3.UP).length_squared()<=energy+.0005
			for i in 2:
				rate_limited=rate_limited and absf(sim.skis[i].edge_angle-edges[i])<=3.0*DT+.000001
				supported_grip=supported_grip and (sim.skis[i].grounded or is_zero_approx(sim.skis[i].grip_n))
		check(passive and not sim.crashed,"Flat-snow carving/reversal cannot add tangential energy, depth="+str(depth))
		check(rate_limited and supported_grip,"Both real cuff motors retain rate and support limits, depth="+str(depth))

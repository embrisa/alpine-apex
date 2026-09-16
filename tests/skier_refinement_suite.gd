extends "res://tests/skier_animation_suite.gd"
## Physical outcomes, composed anatomy and event lifecycles for model v16.
const OUTPUT = "res://artifacts/skier_refinement_v16"
var results: Dictionary = {}

class Wall extends RefCounted:
	var armed = true
	var reason = "TREE"
	func sample(_x: float,_z: float) -> Dictionary: return {"height":0.0,"normal":Vector3.UP}
	func contact_normal(_x: float,_z: float) -> Vector3: return Vector3.UP
	func sweep_obstacle(a: Vector3,b: Vector3) -> String:
		return reason if armed and a.z<5.0 and b.z>=5.0 else ""
	func sweep_obstacle_contact(a: Vector3,b: Vector3) -> Dictionary:
		if sweep_obstacle(a,b).is_empty(): return {}
		return {"position":a.lerp(b,(5.0-a.z)/(b.z-a.z)),"normal":Vector3(-.7,0,-.7).normalized()}

func run():
	skier = preload("res://scripts/presentation/skier_visual.gd").new()
	root.add_child(skier)
	await process_frame
	active_turns()
	neutral_alignment()
	turn_posture()
	flight_and_landing()
	collisions()
	check(metrics.boot_gap_m<.0005 and metrics.length_error_m<.002,"All new motions retain rigid bindings and limb lengths")
	check(metrics.cuff_side_deg<12 and metrics.cuff_flex_min_deg>-5 and metrics.cuff_flex_max_deg<40,"New motions stay inside the existing cuff envelope")
	check(metrics.spine_length_error_m<.00001 and metrics.chest_attachment_error_m<.00001,"Spine, shoulders and neck retain exact attachment")
	results.merge({"model":Sim.MODEL_VERSION,"checks":checks,"failures":failures,"anatomy":metrics,"unranked":true})
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	preload("res://tests/test_report.gd").write(OUTPUT+"/regression.json",JSON.stringify(results,"\t"))
	print("SKIER_REFINEMENT_RESULTS ",JSON.stringify(results))
	skier.queue_free(); await process_frame
	quit(0 if failures.is_empty() else 1)

func active_turns():
	var fixture = preload("res://tests/downhill_control_suite.gd")
	var reference: Array = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/downhill_v15.json")).turns
	var maximum = 0.0
	for row in reference:
		var actual: Dictionary = fixture.turn_fixture(Sim,row.kmh,row.tuck,row.steer,row.reverse)
		for key in ["turn_deg","speed_2s_kmh","exit_kmh","max_slip_deg","airtime_s","response_s","min_ski_load_n","max_ski_load_n"]:
			maximum = maxf(maximum,absf(actual[key]-row[key]))
		check(actual.crash.is_empty() and actual.airtime_s==0.0 and actual.min_ski_load_n>=0 and actual.max_slip_deg<20,
			"Model 17 retains support and bounded slip: %.0f km/h, tuck %.0f, steer %.1f, reversal %s"%[row.kmh,row.tuck,row.steer,row.reverse])

	results.active_turn_max_difference = maximum

func neutral_alignment():
	var plane = TestPlane.new(.46)
	for speed in [0.0,1.0,3.0,10.0,200.0/3.6]:
		var sim = setup(plane)
		sim.tuning.ground_assist_enabled = true
		sim.velocity = Vector3(.2,0,1).slide(sim.surface_normal).normalized()*speed
		var intent = RiderInput.new()
		var before: float = sim.heading
		for tick in 12: sim.landing_assist.step(DT,sim,intent,plane)
		check(sim.heading==before,"Ground alignment waits 100 ms at %.1f m/s"%speed)
		var peak_rate = 0.0
		for tick in 108:
			var old: float = sim.heading
			sim.landing_assist.step(DT,sim,intent,plane)
			peak_rate = maxf(peak_rate,absf(angle_difference(old,sim.heading))/DT)
		check(peak_rate<=deg_to_rad(6.0)+.00001,"Ground yaw stays within 6 degrees/s at %.1f m/s"%speed)
		check(sim.heading==before if speed<=2.0 else sim.heading>before,"Low-speed hold or travel alignment at %.1f m/s"%speed)
		intent.brake = .1; before = sim.heading
		for tick in 60: sim.landing_assist.step(DT,sim,intent,plane)
		check(absf(sim.landing_assist.ground_velocity)<.00001,"Braking gradually releases ground assistance at %.1f m/s"%speed)
		before = sim.heading
		intent.brake = 0; intent.steer = .001
		sim.landing_assist.step(DT,sim,intent,plane)
		check(sim.heading==before and sim.landing_assist.ground_strength==0,"Small steering immediately overrides ground assistance")
	var sim = setup(plane,100.0)
	sim.tuning.landing_assist_enabled = true
	sim.grounded = false; sim.velocity = Vector3(12,-5,25); sim._begin_flight(Basis.IDENTITY)
	var intent = RiderInput.new()
	var max_rate = 0.0
	for tick in 120:
		var old: Basis = sim.support_basis()
		sim.landing_assist.step(DT,sim,intent,plane)
		sim.air_control.step(DT,sim,intent)
		var delta: Quaternion = (old.inverse()*sim.support_basis()).get_rotation_quaternion()
		# atan2 retains precision for sub-degree fixed-tick rotations; acos(dot)
		# quantizes this small angle in Godot's single-precision Basis storage.
		var angle: float = 2.0*atan2(Vector3(delta.x,delta.y,delta.z).length(),absf(delta.w))
		max_rate = maxf(max_rate,angle/DT)
	check(max_rate<deg_to_rad(20.01) and sim.heading>.03,"Long-flight equipment follows travel within the 20 degrees/s rate bound")
	results.free_flight_max_rate_degrees_s = rad_to_deg(max_rate)
	sim.velocity = Vector3.DOWN*20
	var old: Basis = sim.support_basis()
	for tick in 60:
		sim.landing_assist.step(DT,sim,intent,plane)
		sim.air_control.step(DT,sim,intent)
	check(sim.air_control.angular_velocity.length()<.00001,"Vertical flight releases undefined travel targets without erasing angular history")
	for direction in [-1.0,1.0]:
		sim = setup(plane); sim.velocity = sim.support_basis().z*200/3.6
		for tick in 720:
			intent.steer = direction if tick<240 else 0.0
			advance(sim,intent,plane,1)
		check(not sim.crashed and sim.grounded and absf(sim.body.roll)<.5,"200 km/h turn release settles with positive support")

func turn_posture():
	var plane = TestPlane.new(.46)
	var min_margin = INF
	var peak_bank = 0.0
	var peak_tilt = 0.0
	var maximum_step = 0.0
	for speed in [60.0,120.0,200.0]:
		for direction in [-1.0,1.0]:
			var sim = setup(plane)
			sim.velocity = sim.support_basis().z*speed/3.6
			var intent = RiderInput.new(); intent.tuck = 1.0
			var last: Dictionary = {}
			for tick in 480:
				intent.steer = direction if tick<240 else -direction
				intent.jump_held = tick>400
				advance(sim,intent,plane,1)
				for alpha in [0.0,.5,1.0]:
					inspect(sim,alpha)
					min_margin = minf(min_margin,skier.animation.clearance_margin(skier.rendered_joints,skier.global_transform))
				var torso: Basis = skier.rendered_rotations.Spine
				peak_bank = maxf(peak_bank,absf(rad_to_deg(atan2(-torso.y.x,torso.y.y))))
				peak_tilt = maxf(peak_tilt,rad_to_deg(acos(clampf(torso.y.dot(Vector3.UP),-1,1))))
				if not last.is_empty():
					for id in skier.rendered_joints: maximum_step = maxf(maximum_step,last[id].distance_to(skier.rendered_joints[id]))
				last = skier.rendered_joints.duplicate()
	check(min_margin>=-.002,"Hard turns and reversals keep hips/chest/head/hands above clearance margins")
	check(peak_bank<=32.1 and peak_tilt<=78.1,"Combined turn/preparation posture bounds chest bank and total tilt")
	check(maximum_step<.08,"Final clearance and reversal corrections keep joint travel below 8 cm/tick")
	results.turn_pose = {"minimum_clearance_margin_m":min_margin,"peak_chest_bank_degrees":peak_bank,"peak_torso_tilt_degrees":peak_tilt,"maximum_joint_step_m":maximum_step}

func flight_and_landing():
	var plane = TestPlane.new(.46)
	for held in [0.0,1.0]:
		var sim = setup(plane,10.0)
		sim.grounded = false; sim._begin_flight(sim.support_basis()); sim.velocity = Vector3(0,4,25)
		skier.reset_animation(sim); skier.animation.takeoff_age = 0.0
		var intent = RiderInput.new(); intent.tuck = held
		advance(sim,intent,plane,36); inspect(sim)
		check(skier.animation.current.compact>.9 and not sim.grounded,"Athletic flight gathers by 0.30 seconds with tuck %.0f"%held)
		if held==0: check(sim.effective_tuck==0,"Automatic knee gathering does not grant aerodynamic tuck")
		var ready = false
		var landed = false
		var peak_absorption = 0.0
		for tick in 720:
			advance(sim,intent,plane,1); inspect(sim)
			ready = ready or (not sim.grounded and skier.animation.current.ready>.05)
			landed = landed or skier.animation.landing_events>0
			peak_absorption = maxf(peak_absorption,skier.animation.current.impact_drop+skier.animation.current.absorbed*skier.animation.current.impact)
		check(ready and landed and not sim.crashed,"Large jump anticipates slope and lands with tuck %.0f"%held)
		check(peak_absorption<=.2001,"Physical and cosmetic landing compression share a 20 cm budget")
		check(skier.animation.current.impact==0 and skier.animation.current.recoil==0,"Landing settles without repeating a rebound")
	var sim = setup(plane,4)
	sim.grounded = false; sim.landing_assist.valid = true; sim.landing_assist.time_to_contact = .35
	check(skier.animation.landing_readiness(sim,plane)>0,"Readiness starts before the previous quarter-second window")

func collisions():
	for reason in ["TREE","ROCK"]:
		var wall = Wall.new(); wall.reason = reason
		var sim = setup(wall); sim.velocity = Vector3(0,0,18)
		var intent = RiderInput.new()
		var saw = false
		var peak = 0.0
		for tick in 180:
			advance(sim,intent,wall,1); inspect(sim)
			var contact: Dictionary = sim.obstacle_contact
			if not contact.is_empty():
				saw = true; wall.armed = false
				check(contact.reason==reason and contact.closing_speed_mps>1 and contact.normal.length()>.99,"Real %s sweep emits directional contact telemetry"%reason)
				contact.clear()
				check(not sim.obstacle_contact.is_empty(),"Obstacle telemetry does not expose a mutable solver dictionary")
			peak = maxf(peak,skier.animation.current.recoil)
		check(saw and peak>.1 and skier.animation.collision_events==1 and not sim.crashed,"Surviving %s has one visible recoil"%reason)
		check(sim.obstacle_contact.is_empty() and skier.animation.current.recoil==0,"Contact telemetry clears next tick and recoil settles")
		sim.impacts.abrade(DT,.04)
		advance(sim,intent,wall,30)
		check(skier.animation.collision_events==1,"Rock abrasion cannot trigger another collision animation")
		sim.reset(Vector3.ZERO); skier.reset_animation(sim)
		check(sim.obstacle_contact.is_empty() and skier.animation.collision_events==0,"Reset clears contact and recoil history")
	# Repeated contact probes upgrade one expression without resetting its age.
	var plane = TestPlane.new()
	var sim = setup(plane)
	for tick in 24:
		sim.ticks += 1
		sim._obstacle_contact = {"normal":Vector3.LEFT,"closing_speed_mps":4.0 if tick<12 else 9.0,"reason":"ROCK"}
		sim.motion.capture(sim,DT)
		skier.step_animation(DT,sim,RiderInput.new(),plane)
	check(skier.animation.collision_events==1 and skier.animation.collision_age>.18 and skier.animation.collision_speed==9,"Collision cluster upgrades strength without restarting")

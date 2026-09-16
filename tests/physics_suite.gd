extends SceneTree
const Sim = preload("res://scripts/core/ski_simulation.gd")
const Intent = preload("res://scripts/core/rider_input.gd")
const Tuning = preload("res://scripts/core/ski_tuning.gd")
const Terrain = preload("res://scripts/world/test_slope.gd")
const Session = preload("res://scripts/core/run_session.gd")
const DT = 1.0 / 120.0
var failures: Array[String] = []
var checks: int = 0
var metrics: Dictionary = {}
var timing = preload("res://tests/validation_timing.gd").new("physics_suite")

class TestPlane:
	extends RefCounted
	var gradient: float
	func _init(slope: float = 0.46) -> void:
		gradient = slope
	func sample(_x: float,z: float) -> Dictionary:
		return {"height": -z*gradient,"normal": Vector3(0,1,gradient).normalized()}
	func sweep_obstacle(_a: Vector3,_b: Vector3) -> String:
		return ""

class Crest:
	extends TestPlane
	func sample(_x: float,z: float) -> Dictionary:
		var bell = exp(-pow((z-35.0)/12.0,2))
		var height_value = -z*0.46+6*bell
		var derivative = -0.46-12*(z-35)/144.0*bell
		return {"height":height_value,"normal":Vector3(0,1,-derivative).normalized()}

class SnowPlane:
	extends TestPlane
	var depth: float = 0.15
	func snow_depth_at(_x: float, _z: float) -> float:
		return depth

class SmoothSnowTerrain:
	extends Terrain
	func snow_relief_at(_x: float, _z: float) -> float:
		return 0.0

class CrossSlope:
	extends TestPlane
	func sample(x: float,z: float) -> Dictionary:
		return {"height":x*0.2-z*0.46,"normal":Vector3(-0.2,1,0.46).normalized()}

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, name_value: String) -> void:
	checks += 1
	if not condition:
		failures.append(name_value)
		printerr("FAIL: ",name_value)
	else:
		print("PASS: ",name_value)

func make_sim(surface,kmh: float = 0.0,yaw: float = 0.0):
	var sim = Sim.new(Tuning.new())
	sim.reset(Vector3(0,surface.sample(0,0).height,0),yaw)
	sim.velocity = Vector3(sin(yaw),0,cos(yaw)).slide(surface.sample(0,0).normal).normalized()*kmh/3.6
	return sim

func advance(sim,surface,seconds: float,frame = null) -> void:
	var controls = Intent.new() if frame == null else frame
	for i in range(roundi(seconds/DT)):
		sim.step(DT,controls,surface)

func run() -> void:
	timing.mark("straight_speed")
	var slope = TestPlane.new()
	var straight = make_sim(slope)
	var tuck = Intent.new()
	tuck.tuck = 1.0
	advance(straight,slope,20,tuck)
	metrics.straight_20s_kmh = straight.speed_kmh()
	check(straight.speed_kmh()>125 and straight.speed_kmh()<145,"A 25-degree pitch builds elite speed gradually, below extreme territory at 20 s")
	check(straight.grounded and not straight.crashed,"Clean racing on a smooth steep slope remains stable")
	var upright = make_sim(slope)
	advance(upright,slope,20)
	metrics.upright_20s_kmh = upright.speed_kmh()
	check(straight.speed_kmh()>upright.speed_kmh()+15,"Tuck reduces air resistance and preserves more speed")
	timing.mark("speed_calibration")
	_speed_calibration()
	timing.mark("steering_direction")
	_steering_direction()
	timing.mark("handling")
	var gentle = make_sim(slope,90)
	var sharp = make_sim(slope,90)
	var neutral = make_sim(slope,90)
	for i in range(1200):
		var a = Intent.new()
		a.steer = sin(i*DT*2.0)*0.18
		var b = Intent.new()
		b.steer = sin(i*DT*2.0)*0.9
		gentle.step(DT,a,slope)
		sharp.step(DT,b,slope)
		neutral.step(DT,Intent.new(),slope)
	metrics.turns_kmh = {"straight":neutral.speed_kmh(),"gentle":gentle.speed_kmh(),"sharp":sharp.speed_kmh()}
	check(neutral.speed_kmh()>gentle.speed_kmh() and gentle.speed_kmh()>sharp.speed_kmh()+5,"Shallow carving costs less speed than aggressive turns")
	var skid = make_sim(slope,100)
	var skid_reference = make_sim(slope,100)
	skid.heading = deg_to_rad(30)
	advance(skid,slope,1)
	advance(skid_reference,slope,1)
	metrics.skid_kmh = {"skid":skid.speed_kmh(),"aligned":skid_reference.speed_kmh()}
	check(not skid.crashed and skid.speed_kmh()<skid_reference.speed_kmh()-5,"Recoverable sideways skidding costs substantially more speed than aligned gliding")
	var broadside = make_sim(slope,100)
	broadside.heading = PI/2
	advance(broadside,slope,1)
	check(not broadside.crashed and broadside.impacts.reserve==1.0,"Broadside skidding cannot cause a balance death or spend impact reserve")
	var uphill = make_sim(slope,100,PI)
	advance(uphill,slope,2)
	check(uphill.speed_kmh()<65,"Uphill movement rapidly spends momentum")
	var brake = make_sim(slope,120)
	var braking = Intent.new()
	braking.brake = 1.0
	advance(brake,slope,8,braking)
	check(brake.speed_kmh()<0.5,"Braking stops and holds a stationary skier on the test slope")
	var shallow_surface = TestPlane.new(0.2)
	var shallow = make_sim(shallow_surface)
	advance(shallow,shallow_surface,5)
	var steep = make_sim(slope)
	advance(steep,slope,5)
	check(steep.speed_kmh()>shallow.speed_kmh()*1.5,"Slope angle determines gravitational acceleration")
	var cross_surface = CrossSlope.new()
	var cross_sim = make_sim(cross_surface,100)
	advance(cross_sim,cross_surface,2)
	check(absf(angle_difference(cross_sim.heading,atan2(cross_sim.ski_forward.x,cross_sim.ski_forward.z)))<0.0001,"Cross-slope contact preserves the handling axis azimuth, including neutral alignment")
	timing.mark("energy")
	_energy_test()
	timing.mark("snow")
	_snow_tests()
	timing.mark("air")
	_air_tests(slope)
	timing.mark("render_rate_determinism")
	_determinism_test(slope)
	timing.mark("terrain_construction")
	_terrain_tests()
	timing.mark("tick_timing")
	_timing_test()
	timing.finish()
	metrics.checks = checks
	metrics.failures = failures
	var file = preload("res://tests/test_report.gd").open_write("res://artifacts/physics_results.json")
	file.store_string(JSON.stringify(metrics,"\t"))
	print("PHYSICS_RESULTS ",JSON.stringify(metrics))
	print("%d/%d checks passed" % [checks-failures.size(),checks])
	quit(0 if failures.is_empty() else 1)

func _steering_direction() -> void:
	var flat = TestPlane.new(0)
	for yaw in [0.0, PI / 2.0, PI]:
		var rider_right = Vector3(sin(yaw),0,cos(yaw)).cross(Vector3.UP)
		for direction in [-1.0,1.0]:
			var rider = make_sim(flat,60,yaw)
			var controls = Intent.new()
			controls.steer = direction
			advance(rider,flat,0.5,controls)
			check(rider.position.dot(rider_right)*direction>0.05 and rider.ski_forward.dot(rider_right)*direction>0.05 and rider.edge_angle*direction<0.0,"Steer %s turns and edges toward rider-%s at yaw %.2f" % [direction,direction,yaw])

func _energy_test() -> void:
	var flat = TestPlane.new(0)
	var sim = make_sim(flat,150)
	sim.tuning.gravity_multiplier = 0
	var previous_energy: float = sim.velocity.length_squared()
	var never_gained = true
	for i in range(2400):
		var controls = Intent.new()
		controls.steer = sin(i*0.07)
		sim.step(DT,controls,flat)
		var energy: float = sim.velocity.length_squared()
		if energy>previous_energy+0.0001:
			never_gained = false
		previous_energy = energy
	check(never_gained,"Turning and friction never inject kinetic energy on a flat plane")

func _air_tests(slope) -> void:
	var sim = make_sim(slope,60)
	var jump = Intent.new()
	jump.jump = true
	sim.step(DT,jump,slope)
	check(not sim.grounded,"Hop releases snow contact")
	advance(sim,slope,1.5)
	check(sim.grounded and not sim.crashed and sim.total_airtime>0.2,"Small aligned jump lands without crashing")
	var air = make_sim(slope,60)
	air.grounded = false
	air.position.y += 100
	air.velocity = Vector3(0,0,20)
	var air_controls = Intent.new()
	air_controls.steer = 1.0
	advance(air,slope,1,air_controls)
	check(absf(air.velocity.x)<0.0001 and air.velocity.z<20,"Air steering cannot create lateral velocity or slope propulsion")
	var impact = make_sim(slope)
	impact.grounded = false
	impact.position.y = 0.1
	impact.velocity = Vector3(0,-20,0)
	advance(impact,slope,0.1)
	check(not impact.crashed and impact.impacts.reserve<1.0,"First hard landing spends impact reserve instead of automatically crashing")
	var crest_surface = Crest.new()
	var crest = make_sim(crest_surface,150)
	advance(crest,crest_surface,1.5)
	check(crest.total_airtime>0.05,"Convex terrain releases contact without an artificial jump trigger")

func _determinism_test(slope) -> void:
	var results: Array = []
	for fps in [30,60,120,144,240]:
		var sim = make_sim(slope)
		var accumulator = 0.0
		var ticks = 0
		for frame_idx in range(fps*20):
			accumulator += 1.0/fps
			while accumulator+0.00000001 >= DT:
				var controls = Intent.new()
				controls.steer = 0.15*sin(ticks*DT)
				controls.tuck = 1
				sim.step(DT,controls,slope)
				accumulator -= DT
				ticks += 1
		results.append({"fps":fps,"ticks":ticks,"position":sim.position,"velocity":sim.velocity})
	var same = true
	for result in results:
		if result.ticks!=2400 or result.position.distance_to(results[0].position)>0.00001 or result.velocity.distance_to(results[0].velocity)>0.00001:
			same = false
	check(same,"Identical tick inputs produce identical motion at 30/60/120/144/240 render FPS")
	metrics.render_rate_independence = same

func _terrain_tests() -> void:
	var field = Terrain.new()
	var smooth_snow = SmoothSnowTerrain.new()
	var relief_min = INF
	var relief_max = -INF
	var relief_matches = true
	for z in range(160,201):
		for x in range(88,105):
			var point: Vector3 = field.vertex(x,z)
			var difference: float = point.y-smooth_snow.vertex(x,z).y
			relief_min = minf(relief_min,difference)
			relief_max = maxf(relief_max,difference)
			relief_matches = relief_matches and absf(difference-field.snow_relief_at(point.x,point.z))<0.0002
	metrics.snow_relief_range_m = relief_max-relief_min
	check(relief_matches and relief_max-relief_min>0.75,"Wind drifts add real raised/depressed geometry, shared by terrain vertices and collision")
	var same = Terrain.new()
	var other = Terrain.new(34920)
	check(field.heights==same.heights and field.obstacles==same.obstacles,"Same generator version and seed reconstruct identical terrain and obstacles")
	check(field.heights!=other.heights,"Different seeds vary the laboratory landforms")
	timing.mark("terrain_support")
	var mesh_matches = true
	for z in range(0,field.NZ-1,23):
		for x in range(0,field.NX-1,11):
			var a: Vector3 = field.vertex(x,z)
			var b: Vector3 = field.vertex(x+1,z)
			var c: Vector3 = field.vertex(x,z+1)
			var p = a*0.2+b*0.3+c*0.5
			if absf(field.sample(p.x,p.z).height-p.y)>0.001:
				mesh_matches = false
	check(mesh_matches,"Collision samples lie on the rendered mesh triangles")
	var ob = field.obstacles[0]
	var a: Vector3 = ob.position+Vector3(-12,0.5,0)
	var b: Vector3 = ob.position+Vector3(12,0.5,0)
	check(not field.sweep_obstacle(a,b).is_empty(),"Swept collision catches a thin obstacle between endpoints")
	check(field.sweep_obstacle(a+Vector3.UP*50,b+Vector3.UP*50).is_empty(),"Aerial passage above an obstacle does not falsely collide")
	timing.mark("laboratory_descent")
	var sim = Sim.new(Tuning.new())
	sim.reset(field.spawn_point())
	var controls = Intent.new()
	controls.tuck = 1
	var start = Time.get_ticks_usec()
	var session = Session.new()
	session.eligible = false
	var max_tick = 0.0
	var tick_count = 0
	# These measurements share the exact same reset, terrain, input and 120 Hz
	# trajectory. Observe them here instead of replaying it twice more. Dedicated
	# render-rate and terrain reconstruction determinism checks remain separate.
	var launch_speed = -1.0
	var bands = {}
	var collecting_bands = true
	for i in range(10000):
		var before: Vector3 = sim.position
		var tick_start = Time.get_ticks_usec()
		sim.step(DT,controls,field)
		max_tick = maxf(max_tick,Time.get_ticks_usec()-tick_start)
		tick_count += 1
		if tick_count == 1200: launch_speed = sim.speed_kmh()
		if collecting_bands and i < 7200:
			for threshold in [30,60,90,120,150,165,200]:
				if sim.speed_kmh() >= threshold and not bands.has(str(threshold)):
					bands[str(threshold)] = tick_count*DT
			if sim.position.z >= 1450 or sim.crashed: collecting_bands = false
		if session.step(DT,before,sim.position) or sim.crashed:
			break
	metrics.laboratory_descent = {"seconds":session.elapsed,"finished":session.finished,"peak_kmh":sim.peak_speed*3.6,"airtime":sim.total_airtime,"crashed":sim.crashed,"reason":sim.crash_reason,"position":str(sim.position),"mean_tick_us":float(Time.get_ticks_usec()-start)/tick_count,"max_tick_us":max_tick}
	check(session.finished and not sim.crashed,"Default clean fall-line descent reaches the finish without a forced crash")
	check(sim.peak_speed*3.6>125 and sim.peak_speed*3.6<160,"Clean laboratory line earns elite speed without reaching the extreme risk zone")
	check(sim.total_airtime<0.05,"Clean laboratory line retains snow contact")
	metrics.launch_10s_kmh = launch_speed
	check(launch_speed>40 and launch_speed<65,"Opening apron stays in ordinary skiing speeds after ten seconds")
	metrics.laboratory_speed_band_seconds = bands

func _speed_calibration() -> void:
	var tuck = Intent.new()
	tuck.tuck = 1.0
	var measured = {}
	for degrees in [10,25,35,55]:
		var plane = TestPlane.new(tan(deg_to_rad(degrees)))
		var rider = make_sim(plane)
		advance(rider,plane,90,tuck)
		measured[str(degrees)] = rider.speed_kmh()
		check(not rider.crashed,"Aligned %d-degree planar descent has no automatic speed crash" % degrees)
	metrics.sustained_pitch_kmh = measured
	check(measured["10"]>75 and measured["10"]<95,"Ordinary pitch settles below racing speed even tucked")
	check(measured["25"]>130 and measured["25"]<150,"Sustained racing pitch settles in elite territory")
	check(measured["35"]>160 and measured["35"]<175,"Very steep pitch can enter extreme territory")
	check(measured["55"]>200,"Exceptional 55-degree pitch can exceed 200 km/h without a cap")
	var flat = TestPlane.new(0)
	var careful = make_sim(flat,90)
	var extreme = make_sim(flat,200)
	# A modest heading error is now forgiving even at exceptional speed.
	careful.heading = deg_to_rad(12)
	extreme.heading = deg_to_rad(12)
	advance(careful,flat,0.4)
	advance(extreme,flat,0.4)
	check(careful.balance>.95 and extreme.balance>.95 and not extreme.crashed,"Brief 12-degree heading errors are recoverable at 90 and 200 km/h")
	careful = make_sim(flat,90)
	extreme = make_sim(flat,200)
	# Larger heading errors spend momentum, not an impact reserve.
	careful.heading = deg_to_rad(20)
	extreme.heading = deg_to_rad(20)
	advance(careful,flat,0.4)
	advance(extreme,flat,0.4)
	metrics.slip_impact_reserve = {"90_kmh":careful.impacts.reserve,"200_kmh":extreme.impacts.reserve}
	check(not careful.crashed and not extreme.crashed and careful.impacts.reserve==1.0 and extreme.impacts.reserve==1.0,"Heading errors at 90 and 200 km/h do not spend impact reserve")
	var tucked_turn = make_sim(TestPlane.new(),120)
	advance(tucked_turn,TestPlane.new(),2,tuck)
	tuck.steer = 0.8
	advance(tucked_turn,TestPlane.new(),1,tuck)
	check(tucked_turn.effective_tuck<0.40,"Hard steering opens the aerodynamic tuck to regain leverage")
	tuck.steer = 0.0
	tuck.brake = 1.0
	advance(tucked_turn,TestPlane.new(),1,tuck)
	check(tucked_turn.effective_tuck<0.02,"Braking opens the tuck even with the tuck control held")

func _timing_test() -> void:
	var session = Session.new()
	session.finish_z = 10.04
	session.eligible = false
	session.step(DT,Vector3(0,0,10),Vector3(0,0,10.1))
	check(session.finished and absf(session.elapsed-DT*0.4)<0.00001,"Finish time interpolates within a physics tick to sub-millisecond resolution")
	var gated = Session.new()
	gated.eligible = false
	gated.step(DT,Vector3(80,0,1449),Vector3(80,0,1451))
	check(not gated.finished,"A finish crossing outside the gate is rejected")
	check(Session.format_time(59.9996)=="01:00.000","Millisecond rounding carries correctly into the next minute")

func _snow_tests() -> void:
	var snow = SnowPlane.new(0.0)
	var packed = TestPlane.new(0.0)
	var soft_rider = make_sim(snow,50)
	var firm_rider = make_sim(packed,50)
	advance(soft_rider,snow,2.0)
	advance(firm_rider,packed,2.0)
	check(soft_rider.speed_kmh()<firm_rider.speed_kmh() and soft_rider.snow_drag>0.0,"Loose snow dissipates more speed than an identical packed plane")
	var slow = make_sim(snow,15)
	var fast = make_sim(snow,120)
	slow.step(DT,Intent.new(),snow)
	fast.step(DT,Intent.new(),snow)
	check(slow.snow_penetration>fast.snow_penetration and slow.snow_penetration<=snow.depth,"Speed reduces ski penetration through planing, bounded by layer depth")
	var skid = make_sim(snow,50)
	var aligned = make_sim(snow,50)
	skid.heading = 0.4
	skid.step(DT,Intent.new(),snow)
	aligned.step(DT,Intent.new(),snow)
	check(skid.snow_drag>aligned.snow_drag*3.0,"Skidding ploughs substantially more loose snow than clean gliding")
	var air = make_sim(snow,60)
	air.grounded = false
	air.position.y = 100.0
	advance(air,snow,0.25)
	check(air.snow_drag==0.0 and air.snow_penetration==0.0,"Airborne skis receive no snow force or penetration")
	var energy_rider = make_sim(snow,80)
	var passive = true
	var previous = energy_rider.velocity.length_squared()
	for tick in range(900):
		var controls = Intent.new()
		controls.steer = sin(tick*DT*2.0)*0.5
		energy_rider.step(DT,controls,snow)
		var current = energy_rider.velocity.length_squared()
		passive = passive and current<=previous+0.0001 and energy_rider.position.is_finite()
		previous = current
	check(passive,"Loaded snow turns remain passive and finite through stopping")
	var shallow = SnowPlane.new(0.0)
	shallow.depth = 0.025
	var shallow_rider = make_sim(shallow,50)
	shallow_rider.step(DT,Intent.new(),shallow)
	check(aligned.snow_drag>shallow_rider.snow_drag and aligned.snow_penetration>shallow_rider.snow_penetration,"Deeper loose deposits increase penetration and resistance")
	var field = Terrain.new()
	var copy = Terrain.new()
	check(field.snow_depth_at(32,612)==copy.snow_depth_at(32,612) and absf(field.snow_depth_at(32,612)-field.snow_depth_at(32.1,612))<0.001,"Snow deposits are seeded, repeatable and spatially continuous")
	_snow_schedule_test(snow)

func _snow_schedule_test(snow) -> void:
	var outcomes: Array = []
	for fps in [30,60,144,240]:
		var rider = make_sim(snow,80)
		var accumulator = 0.0
		var tick = 0
		for frame in range(fps*4):
			accumulator += 1.0/fps
			while accumulator+0.00000001>=DT:
				var controls = Intent.new()
				controls.steer = sin(tick*DT)*0.2
				rider.step(DT,controls,snow)
				accumulator -= DT
				tick += 1
		outcomes.append([rider.position,rider.velocity,rider.snow_drag,rider.snow_penetration])
	check(outcomes[0]==outcomes[1] and outcomes[0]==outcomes[2] and outcomes[0]==outcomes[3],"Snow forces remain independent of 30/60/144/240 FPS render scheduling")

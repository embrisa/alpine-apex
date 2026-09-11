extends SceneTree
## Authoritative 4 m geometry, support reach, passive energy and real takeoff.
const Sim = preload("res://scripts/core/ski_simulation.gd")
const Heightfield = preload("res://scripts/world/heightfield_surface.gd")
const TestPlane = preload("res://tests/physics_suite.gd").TestPlane
const Crest = preload("res://tests/physics_suite.gd").Crest
const Ledge = preload("res://tests/jump_suite.gd").Ledge
const DT = 1.0/120.0
const OUTPUT = "res://artifacts/handling_v15"
var checks = 0
var failures: Array[String] = []

class Ripple extends Heightfield:
	func _init(amplitude: float = .10, wavelength: float = 16.0) -> void:
		X_MIN=-64.0; Z_MIN=-64.0; NX=33; NZ=193
		heights.resize(NX*NZ)
		for iz in NZ:
			var z = Z_MIN+iz*CELL
			for ix in NX:
				heights[iz*NX+ix] = -z*.46+amplitude*cos(z*TAU/wavelength)
	func sweep_obstacle(_a: Vector3,_b: Vector3) -> String: return ""

class OneSki extends TestPlane:
	func sample(x: float,z: float) -> Dictionary:
		return {"height":-z*.46-(.65 if x>0.0 else 0.0),"normal":Vector3(0,1,.46).normalized()}

func _initialize() -> void: call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr("FAIL: ",label)

static func measure(model, surface, speed: float, seconds: float, steer: float = 0.0, overrides: Dictionary = {}, origin: Vector3 = Vector3.ZERO, yaw: float = 0.0) -> Dictionary:
	var sim = model.new()
	for key in overrides: sim.tuning.set(key,overrides[key])
	origin.y = surface.sample(origin.x,origin.z).height
	sim.reset(origin,yaw)
	sim.prime_contacts(surface)
	sim.velocity = sim.support_basis().z*speed/3.6
	var input = RiderInput.new()
	input.tuck = 1.0
	var launches = 0
	var longest = 0.0
	var max_clearance = 0.0
	var min_load = INF
	var max_load = 0.0
	var max_reach = 0.0
	var foot_error = 0.0
	var unloaded_grip = 0.0
	var reasons = {}
	var rock_ticks = 0
	var measured_ticks = 0
	var telemetry: Array = []
	for tick in roundi(seconds/DT):
		input.steer = steer*sin(tick*DT*2.0)
		var supported: bool = sim.grounded
		sim.step(DT,input,surface)
		measured_ticks += 1
		if sim.rock_contact>0.0: rock_ticks += 1
		if supported and not sim.grounded:
			launches += 1
			var reason: String = sim.takeoff_reason if "takeoff_reason" in sim else "v14 reach/curvature"
			reasons[reason] = reasons.get(reason,0)+1
		longest = maxf(longest,sim.airtime)
		max_clearance = maxf(max_clearance,sim.position.y-surface.sample(sim.position.x,sim.position.z).height)
		for ski in sim.skis:
			min_load = minf(min_load,ski.load_n)
			max_load = maxf(max_load,ski.load_n)
			if ski.grounded:
				max_reach = maxf(max_reach,absf(sim.position.y-ski.height_reference))
				var crush_y: float = ski.crush_vertical_m if "crush_vertical_m" in ski else 0.0
				foot_error = maxf(foot_error,absf(ski.position.y+crush_y-surface.sample(ski.position.x,ski.position.z).height))
			else: unloaded_grip = maxf(unloaded_grip,absf(ski.grip_n))
		if tick%12==0:
			telemetry.append({"s":tick*DT,"speed_kmh":sim.speed_kmh(),"clearance_m":sim.position.y-surface.sample(sim.position.x,sim.position.z).height,
				"load_n":[sim.skis[0].load_n,sim.skis[1].load_n],"contact":[sim.skis[0].grounded,sim.skis[1].grounded]})
		if sim.crashed: break
	return {"speed":speed,"airtime_s":sim.total_airtime,"launches":launches,"longest_flight_s":longest,
		"duration_s":measured_ticks*DT,"rock_seconds":rock_ticks*DT,"origin":[origin.x,origin.y,origin.z],"heading":yaw,
		"max_clearance_m":max_clearance,"min_load_n":min_load,"max_load_n":max_load,"max_reach_m":max_reach,
		"foot_error_m":foot_error,"unloaded_grip_n":unloaded_grip,"exit_kmh":sim.speed_kmh(),"crash":sim.crash_reason,
		"takeoff_reasons":reasons,"telemetry":telemetry}

func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	var baseline = "--baseline" in OS.get_cmdline_user_args()
	var model = load("res://artifacts/handling_v15/reference/ski_simulation.gd") if baseline else Sim
	var rows: Array = []
	for amplitude in [.05,.15,.30]:
		for speed in [60.0,120.0,160.0,200.0]:
			var row = measure(model,Ripple.new(amplitude),speed,6.0,.025)
			row.amplitude_m = amplitude
			rows.append(row)
			if baseline: continue
			var label = "%.2f m ripple, %.0f km/h" % [amplitude,speed]
			check(row.crash.is_empty(),label+": controlled terrain passage")
			check(row.min_load_n>=0 and row.unloaded_grip_n==0,label+": unilateral support and zero aerial grip")
			check(row.max_reach_m<=.281 and row.foot_error_m<.001,label+": bounded reach and exact ski contact")
			if amplitude==.05 and speed<=160: check(row.airtime_s<DT*2,label+": gentle bumps retain contact")
	if not baseline:
		var crest = measure(model,Crest.new(),150,1.5)
		check(crest.airtime_s>.05,"A genuine convex crest still launches naturally")
		var ledge = measure(model,Ledge.new(),72,.15)
		check(ledge.airtime_s>.04 and ledge.max_clearance_m>11.9,"A cliff retains incoming momentum without snapping down")
		var one = model.new()
		var field = OneSki.new()
		one.reset(Vector3.ZERO); one.prime_contacts(field)
		check(one.contact_count==1 and one.normal_load>0,"One ski supports independently when the other cannot reach")
		_energy_and_hop()
	var output = OUTPUT+("/baseline_contact.json" if baseline else "/contact.json")
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify({"model":model.MODEL_VERSION,"checks":checks,"failures":failures,"bumps":rows,"unranked":true},"\t"))
	print("DOWNHILL_CONTACT_RESULTS ",JSON.stringify({"checks":checks,"failures":failures,"path":output}))
	quit(0 if failures.is_empty() else 1)

func _energy_and_hop() -> void:
	var field = TestPlane.new(0.0)
	var sim = Sim.new()
	sim.tuning.gravity_multiplier=0.0
	sim.tuning.aerodynamic_drag=0.0
	sim.tuning.ski_friction=0.0
	sim.tuning.snow_resistance=0.0
	sim.reset(Vector3(0,-.05,0)); sim.prime_contacts(field)
	var initial_energy = .5*sim.tuning.support_stiffness*.05*.05
	var peak_energy = initial_energy
	var input = RiderInput.new()
	for tick in 240:
		sim.step(DT,input,field)
		var compression = minf(sim.position.y,0.0)
		var energy = .5*sim.velocity.length_squared()+.5*sim.tuning.support_stiffness*compression*compression
		peak_energy = maxf(peak_energy,energy)
	check(peak_energy<=initial_energy*1.03,"Damped normal compliance does not create mechanical energy")
	for offset in [-.05,0.0,.04]:
		sim = Sim.new(); sim.reset(Vector3(0,offset,0)); sim.prime_contacts(field)
		input.jump=true
		sim.step(DT,input,field)
		check(sim.jump_executed and not sim.grounded and sim.velocity.y>3.0,"Hop immediately releases supported compression %.2f m" % offset)
		input.jump=false

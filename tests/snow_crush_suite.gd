extends SceneTree
const Sim = preload("res://scripts/core/ski_simulation.gd")
const Heightfield = preload("res://scripts/world/heightfield_surface.gd")
const Spray = preload("res://scripts/presentation/snow_response.gd")
const DT = 1.0/120.0
const OUTPUT = "res://artifacts/snow_grounding_v28/banks"
var checks = 0
var failures: Array = []
var rows: Array = []

class Bank extends Heightfield:
	var depth = .35
	var rock = false
	var gradient = .46
	func _init(height: float = .30, width: float = 8.0, angle: float = 0.0, count: int = 1, slope: float = .46) -> void:
		gradient = slope
		X_MIN = -128; Z_MIN = -32; NX = 65; NZ = 65
		heights.resize(NX*NZ)
		for z in NZ:
			for x in NX:
				var p = Vector2(X_MIN+x*CELL,Z_MIN+z*CELL)
				var along = p.rotated(angle).y
				var rise = 0.0
				for i in count:
					rise = maxf(rise,height*maxf(0.0,1.0-absf(along-(16.0+i*24.0))/(width*.5)))
				heights[z*NX+x] = -p.y*gradient+rise
	func snow_depth_at(_x: float,_z: float) -> float: return depth
	func rock_fraction_at(_x: float,_z: float) -> float: return 1.0 if rock else 0.0
	func sweep_obstacle(_a: Vector3,_b: Vector3) -> String: return ""
	func sweep_obstacle_contact(_a: Vector3,_b: Vector3) -> Dictionary: return {}

func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr("FAIL: ",label)

static func rider(field, speed: float, enabled: bool = true):
	var sim = Sim.new()
	if not enabled: sim.tuning.snow_crush_max_m = 0.0
	sim.reset(Vector3(0,field.sample(0,0).height,0)); sim.prime_contacts(field)
	sim.velocity = sim.support_basis().z*speed/3.6
	return sim

static func crossing(field, flat, speed: float, posture: int, enabled: bool = true, seconds: float = 1.8) -> Dictionary:
	var sim = rider(field,speed,enabled); var reference = rider(flat,speed,enabled)
	var intent = RiderInput.new(); intent.tuck = 1.0 if posture==1 else 0.0; intent.steer = .15 if posture==2 else 0.0
	if posture==1: sim.effective_tuck = 1.0; reference.effective_tuck = 1.0
	var result = {"air_ticks":0,"speed_error":0.0,"peak_crush_m":0.0,"peak_vertical_m":0.0,"peak_lift_m":0.0,"peak_impact":0.0,"reach_m":0.0,"contact_error_m":0.0,"unloaded_grip":0.0,"min_load":INF,"crash":"","spray_peak":0.0,"peak_energy":0.0,"peak_crush_rate":0.0,"exit_crush_m":0.0}
	var response = Spray.new()
	result.min_crushing_kmh = -1.0
	result.max_crushing_kmh = 0.0
	for tick in roundi(seconds/DT):
		sim.step(DT,intent,field); reference.step(DT,intent,flat)
		if not sim.grounded: result.air_ticks += 1
		result.speed_error = maxf(result.speed_error,absf(sim.velocity.length()/maxf(reference.velocity.length(),.1)-1.0))
		result.peak_lift_m = maxf(result.peak_lift_m,sim.position.y-flat.sample(sim.position.x,sim.position.z).height)
		result.peak_impact = maxf(result.peak_impact,sim.landing_force)
		result.peak_energy = maxf(result.peak_energy,.5*sim.velocity.length_squared()+9.81*sim.position.y)
		for ski in sim.skis:
			if ski.crush_m>.001:
				result.min_crushing_kmh = sim.speed_kmh() if result.min_crushing_kmh<0.0 else minf(result.min_crushing_kmh,sim.speed_kmh())
				result.max_crushing_kmh = maxf(result.max_crushing_kmh,sim.speed_kmh())
			result.peak_crush_m = maxf(result.peak_crush_m,ski.crush_m)
			result.peak_vertical_m = maxf(result.peak_vertical_m,ski.crush_vertical_m)
			result.peak_crush_rate = maxf(result.peak_crush_rate,ski.crush_rate_m_s)
			result.min_load = minf(result.min_load,ski.load_n)
			if ski.grounded:
				result.reach_m = maxf(result.reach_m,absf(sim.position.y-ski.height_reference))
				result.contact_error_m = maxf(result.contact_error_m,absf(ski.position.y+ski.crush_vertical_m-field.sample(ski.position.x,ski.position.z).height))
			else: result.unloaded_grip = maxf(result.unloaded_grip,absf(ski.grip_n))
			response.sample(sim,ski,field)
			result.spray_peak = maxf(result.spray_peak,response.powder)
		if sim.crashed: result.crash = sim.crash_reason; break
	result.exit_speed_error = sim.velocity.length()/maxf(reference.velocity.length(),.1)-1.0
	result.exit_kmh = sim.speed_kmh()
	result.exit_crush_m = maxf(sim.skis[0].crush_m,sim.skis[1].crush_m)
	return result

func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	var edge = "--edge" in OS.get_cmdline_user_args()
	var quick = "--quick" in OS.get_cmdline_user_args() or edge
	var contract_only = "--contracts" in OS.get_cmdline_user_args()
	for amplitude in ([] if contract_only else ([.30] if quick else [.10,.20,.30])):
		for width in ([4.0 if edge else 8.0] if quick else [4.0,8.0,16.0]):
			for angle in ([.35 if edge else 0.0] if quick else [0.0,.35]):
				var field = Bank.new(amplitude,width,angle)
				var flat = Bank.new(0.0)
				for depth in ([.35] if quick else [.04,.35]):
					field.depth = depth; flat.depth = depth
					for speed in ([30.0,120.0,200.0] if quick else [30.0,60.0,80.0,120.0,160.0,200.0]):
						for posture in ([2] if edge else ([0] if quick else [0,1,2])):
							var row = crossing(field,flat,speed,posture,true,4.0 if speed==30.0 else 1.8)
							row.amplitude = amplitude; row.width = width; row.angle = angle; row.depth = depth; row.speed = speed; row.posture = posture
							rows.append(row)
							var label = "%.2fm/%.0fm angle%.2f depth%.2f %.0fkmh stance%d"%[amplitude,width,angle,depth,speed,posture]
							check(row.crash.is_empty(),label+": no crash")
							check(row.min_load>=0 and row.unloaded_grip==0 and row.reach_m<=.281,label+": unilateral support and leg reach")
							check(row.peak_crush_m<=minf(.30,depth)+.0001 and row.peak_vertical_m<=.3001 and row.contact_error_m<.001,label+": bounded physical crush and exact ski contact")
							check(row.exit_crush_m<.001,label+": crushing clears after the isolated bank")
							if speed>=30 and depth>=.30:
								check(row.air_ticks<=2 and row.peak_impact<.01,label+": no launch or bottom-out")
								check(row.speed_error<=.01 and absf(row.exit_speed_error)<=.01,label+": no bank speed penalty or boost")
								check(row.peak_lift_m<=.10,label+": minimal body lift")
	if not quick: contracts()
	var report_name = "/contracts.json" if contract_only else ("/quick.json" if quick else "/contact.json")
	FileAccess.open(OUTPUT+report_name,FileAccess.WRITE).store_string(JSON.stringify({"model":Sim.MODEL_VERSION,"checks":checks,"failures":failures,"cases":rows},"\t"))
	print("SNOW_CRUSH checks=",checks," cases=",rows.size()," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)

func contracts() -> void:
	var field = Bank.new(); var flat = Bank.new(0.0)
	var before = crossing(field,flat,200,0,false)
	var after = crossing(field,flat,200,0,true)
	check(after.peak_lift_m<before.peak_lift_m and after.speed_error<before.speed_error,"Sharp bank improves lift and speed against disabled crush")
	check(after.peak_crush_rate>0 and after.spray_peak>crossing(flat,flat,200,0).spray_peak*2,"Crushing supplies a bounded visible snow burst")
	for speed in [30.0,60.0,80.0]:
		var slow_bank = Bank.new(.30,8,0,1,0.0); var slow_flat = Bank.new(0,8,0,1,0.0)
		var slow = crossing(slow_bank,slow_flat,speed,0,true,4.8)
		print("CRUSH_SLOW ",speed," ",JSON.stringify(slow))
		check(slow.peak_crush_m>.20 and slow.air_ticks<=2 and slow.peak_impact<.01,"Ordinary-speed bank absorbs without a launch or bottom-out at %.0f km/h"%speed)
		if speed>=60.0:
			check(slow.min_crushing_kmh>=30.0 and slow.speed_error<=.01,"Fully activated flat-bank crossing retains the 1% speed budget")
		else:
			# With ordinary drag/ploughing, a 30 km/h entry coasts far below
			# full activation before this flat bank. Keep that partial-blend
			# result visible; the main downhill matrix tests full 30 km/h yield.
			check(slow.max_crushing_kmh<30.0,"Slow flat fixture explicitly exercises partial activation")
	field.rock = true; flat.rock = true
	check(crossing(field,flat,200,0)==crossing(field,flat,200,0,false),"Rock response is unchanged")
	field = Bank.new(.30,8,0,5,0.0); flat = Bank.new(0,8,0,1,0.0)
	var repeated = crossing(field,flat,200,0,true,2.8)
	check(repeated.air_ticks<=10 and repeated.speed_error<=.01,"Consecutive banks preserve support and speed")
	check(repeated.peak_energy<=.5*pow(200.0/3.6,2)+.01,"Repeated crushing cannot add mechanical energy on level snow")
	var coast = rider(field,200)
	for property in ["aerodynamic_drag","ski_friction","snow_resistance","snow_ploughing","skidding_friction"]:
		coast.tuning.set(property,0.0)
	var initial_energy: float = .5*coast.velocity.length_squared()
	var peak_energy = initial_energy
	for tick in 300:
		coast.step(DT,RiderInput.new(),field)
		peak_energy = maxf(peak_energy,.5*coast.velocity.length_squared()+9.81*coast.position.y)
	print("CRUSH_COAST_ENERGY initial=",initial_energy," peak=",peak_energy)
	check(peak_energy<=initial_energy+.05,"Repeated banks add no energy even without forward friction or air drag")
	var sim = rider(field,200)
	while sim.position.z<14.0: sim.step(DT,RiderInput.new(),field)
	var state = [sim.skis[0].crush.origin,sim.skis[0].crush.normal,sim.skis[0].crush_m,sim.skis[0].crush_rate_m_s]
	for i in 20:
		sim._support_sample(field,sim.position)
		sim._update_contacts(field,DT,false)
		Spray.new().sample(sim,sim.skis[0],field)
	check(state==[sim.skis[0].crush.origin,sim.skis[0].crush.normal,sim.skis[0].crush_m,sim.skis[0].crush_rate_m_s],"Repeated force and presentation probes do not advance crush")
	var hop = RiderInput.new(); hop.jump = true; sim.step(DT,hop,field)
	check(sim.jump_executed and not sim.grounded and sim.skis[0].crush_m==0 and not sim.skis[0].crush.enabled,"Deliberate hop clears crushing immediately")
	sim.reset(Vector3.ZERO); sim.prime_contacts(field)
	check(sim.skis[0].crush_m==0 and not sim.skis[0].crush.initialized,"Restart and contact priming clear transient crushing")
	sim = rider(field,200)
	while sim.position.z<14.0: sim.step(DT,RiderInput.new(),field)
	field.rock = true; sim.step(DT,RiderInput.new(),field)
	check(sim.skis[0].crush_m==0 and sim.skis[0].crush_rate_m_s==0 and not sim.skis[0].crush.enabled,"Crossing onto rock clears all crushing history")
	field.rock = false
	var a = rider(field,200); var b = rider(field,200)
	var repeatable = true
	for tick in 240:
		var intent = RiderInput.new(); intent.steer = .15*sin(tick*DT*2)
		a.step(DT,intent,field); b.step(DT,intent,field)
		for ski in b.skis: ski.crush.sample(field,ski.position.x+1,ski.position.z+1)
		repeatable = repeatable and a.position==b.position and a.velocity==b.velocity and a.skis[0].crush_m==b.skis[0].crush_m
	check(repeatable,"Extra read-only contact samples cannot change fixed-tick replay")
	var large = crossing(Bank.new(1.5,8),Bank.new(0),200,0)
	check(large.air_ticks>2 and large.peak_crush_m<=.3001,"Larger terrain exhausts crushing and still produces flight")

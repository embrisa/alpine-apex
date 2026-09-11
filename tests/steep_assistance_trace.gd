extends SceneTree
## Isolated prediction-boundary trace. Position jumps below are test fixtures,
## not game teleport handling; no contact impulse can obscure the assist rate.
const Sim = preload("res://scripts/core/ski_simulation.gd")
const Surface = preload("res://tests/physics_suite.gd").TestPlane
const DT = 1.0/120.0
const OUTPUT = "res://artifacts/steep_animation_physics_upgrade"

func _initialize():
	var results = []
	for variant in ["v16","off","gradual"]:
		var model = load(OUTPUT+"/reference/ski_simulation.gd") if variant=="v16" else Sim
		var sim = model.new()
		var surface = Surface.new(.46)
		sim.reset(Vector3(0,1000,0)); sim.prime_contacts(surface)
		sim._begin_flight(Basis(Vector3.RIGHT,-.70))
		sim.velocity = Vector3(8,-18,25)
		sim.tuning.landing_assist_enabled = variant!="off"
		var input = RiderInput.new()
		var old_velocity = Vector3.ZERO
		var max_speed = 0.0; var max_acceleration = 0.0
		var rows = []
		for tick in 360:
			if tick==90: sim.position.y = .8
			if tick==180: surface.gradient = -.25
			if tick==240: sim.position.y = 1000.0
			var frame: Basis = sim.support_basis()
			sim.landing_assist.step(DT,sim,input,surface)
			if variant!="v16": sim.air_control.step(DT,sim,input)
			var q: Quaternion = (sim.support_basis()*frame.transposed()).get_rotation_quaternion().normalized()
			if q.w<0: q = -q
			var axis = Vector3(q.x,q.y,q.z)
			var angle = 2.0*atan2(axis.length(),maxf(0,q.w))
			var velocity = axis.normalized()*angle/DT
			max_speed = maxf(max_speed,velocity.length())
			max_acceleration = maxf(max_acceleration,(velocity-old_velocity).length()/DT)
			old_velocity = velocity
			rows.append({"tick":tick,"valid":sim.landing_assist.valid,"weight":sim.landing_assist.strength,"angular_velocity_rad_s":[velocity.x,velocity.y,velocity.z],"orientation":str(sim.support_basis().get_rotation_quaternion())})
		results.append({"variant":variant,"max_degrees_s":rad_to_deg(max_speed),"max_degrees_s2":rad_to_deg(max_acceleration),"trace":rows})
	FileAccess.open(OUTPUT+"/assistance_trace.json",FileAccess.WRITE).store_string(JSON.stringify(results,"\t"))
	for row in results: print(row.variant," max deg/s ",row.max_degrees_s," max deg/s2 ",row.max_degrees_s2)
	quit()

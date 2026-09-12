extends RefCounted
## Bounded ordinary-input landing diagnostics on the production 4 m heightfield.
const Sim = preload("res://scripts/core/ski_simulation.gd")
const Ripple = preload("res://tests/planted_snow_probe.gd").SnowRipple
const DT = 1.0/120.0

static func surface(fixture: Dictionary):
	var field = Ripple.new(fixture.get("amplitude",.3),fixture.get("wavelength",16.0),fixture.get("depth",.2),fixture.get("angle",0.0))
	field.rock_fraction = fixture.get("rock",0.0)
	if fixture.get("flat",false):
		for z in field.NZ:
			for x in field.NX: field.heights[z*field.NX+x] = 0.0
	return field

static func rider(field, fixture: Dictionary):
	var sim = Sim.new()
	sim.reset(Vector3(0,field.sample(0,0).height,0)); sim.prime_contacts(field)
	sim.velocity = sim.support_basis().z*fixture.get("kmh",60.0)/3.6
	sim.effective_tuck = fixture.get("tuck",0.0)
	return sim

static func input(tick: int, fixture: Dictionary):
	var intent = RiderInput.new()
	intent.tuck = fixture.get("tuck",0.0)
	intent.steer = fixture.get("steer",0.0)
	intent.jump_held = fixture.get("hop",true) and tick>=6 and tick<30
	intent.jump = fixture.get("hop",true) and tick==30
	return intent

static func sample(sim, field) -> Dictionary:
	var skis: Array = []
	for ski in sim.skis:
		skis.append({"grounded":ski.grounded,"load":ski.load_n,"clearance":ski.clearance_m,
			"normal_speed":ski.normal_speed_ms,"compression":ski.compression_m,"crush":ski.crush_m,
			"normal":[ski.normal.x,ski.normal.y,ski.normal.z],"landing":ski.landing_speed})
	var raw: Dictionary = field.sample(sim.position.x,sim.position.z)
	return {"tick":sim.ticks,"grounded":sim.grounded,"jump":sim.jump_executed,
		"position":[sim.position.x,sim.position.y,sim.position.z],"velocity":[sim.velocity.x,sim.velocity.y,sim.velocity.z],
		"normal_speed":sim.velocity.dot(raw.normal),"clearance":sim.position.y-raw.height,
		"load":sim.normal_load,"takeoff":sim.takeoff_reason,"assist":sim.snow_contact_assist.release_reason,
		"correction":sim.snow_contact_assist.correction_m_s,"impact":sim.landing_force,
		"landing_age":sim.time_since_landing,"body_height":sim.body.pelvis_height,"skis":skis}

static func measure(fixture: Dictionary, trace: Array) -> Dictionary:
	var field = surface(fixture)
	var sim = rider(field,fixture)
	var launches: Array = []; var landings: Array = []
	var jumps = 0; var air_ticks = 0; var peak_clearance = 0.0; var peak_normal = 0.0
	for tick in roundi(fixture.get("seconds",4.0)/DT):
		var grounded: bool = sim.grounded
		sim.step(DT,input(tick,fixture),field)
		var row = sample(sim,field); trace.append(row)
		if sim.jump_executed: jumps += 1
		if grounded and not sim.grounded: launches.append(row)
		if (not grounded and sim.grounded) or sim.time_since_landing<DT*.5: landings.append(row)
		if not sim.grounded: air_ticks += 1
		peak_clearance = maxf(peak_clearance,row.clearance)
		peak_normal = maxf(peak_normal,row.normal_speed)
		if sim.crashed: break
	return {"fixture":fixture,"launches":launches,"landings":landings,"jumps":jumps,
		"airtime":air_ticks*DT,"peak_clearance":peak_clearance,"peak_normal":peak_normal,
		"ticks":sim.ticks,"crash":sim.crash_reason,"final_grounded":sim.grounded}

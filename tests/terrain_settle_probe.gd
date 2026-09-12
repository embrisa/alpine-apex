extends RefCounted
## Current 4 m mountain contacts, fixed inputs, bounded duration, no session/PBs.
const Hop = preload("res://tests/small_landing_probe.gd")
const DT = 1.0/120.0
const ROUGH = {"name":"rough_snow","x":1495.18078613281,"z":-1111.85363769531,"kmh":160.0,"seconds":15.0}
const SMOOTH = {"name":"smooth_snow","x":-299.268585205078,"z":1178.92468261719,"kmh":160.0,"seconds":15.0}

static func rider(field, fixture: Dictionary, reference_assist: String = ""):
	var sim=Hop.Sim.new(load("res://config/ski_default.tres").duplicate())
	if not reference_assist.is_empty(): sim.snow_contact_assist=load(reference_assist).new()
	var n: Vector3=field.contact_normal(fixture.x,fixture.z)
	sim.reset(Vector3(fixture.x,field.sample(fixture.x,fixture.z).height,fixture.z),atan2(n.x,n.z))
	sim.prime_contacts(field); sim.velocity=sim.support_basis().z*fixture.kmh/3.6; sim.effective_tuck=1.0
	return sim

static func input():
	var intent=RiderInput.new(); intent.tuck=1.0
	return intent

static func measure(field, fixture: Dictionary, rows: Array, reference_assist: String = "") -> Dictionary:
	var sim=rider(field,fixture,reference_assist); var intent=input()
	var flights: Array=[]; var flight={}; var reach=0.0; var unsupported_grip=0.0; var min_load=INF
	for tick in roundi(fixture.seconds/DT):
		var grounded: bool=sim.grounded
		sim.step(DT,intent,field)
		var row=Hop.sample(sim,field); rows.append(row)
		if grounded and not sim.grounded:
			flight={"tick":sim.ticks,"duration":0.0,"height":0.0,"reason":sim.takeoff_reason}; flights.append(flight)
		if not sim.grounded and not flight.is_empty():
			flight.duration+=DT; flight.height=maxf(flight.height,row.clearance)
		for ski in sim.skis:
			min_load=minf(min_load,ski.load_n)
			if ski.grounded: reach=maxf(reach,absf(ski.clearance_m))
			else: unsupported_grip=maxf(unsupported_grip,absf(ski.grip_n))
		if sim.crashed: break
	return {"fixture":fixture,"ticks":sim.ticks,"airtime":sim.total_airtime,"flights":flights,"crash":sim.crash_reason,"exit_kmh":sim.speed_kmh(),"reach":reach,"min_load":min_load,"unsupported_grip":unsupported_grip}

extends RefCounted
## Shared fixed-input contact measurements; never opens a session or saves a PB.
const DT = 1.0/120.0
const Heightfield = preload("res://scripts/world/heightfield_surface.gd")

class ContactOnly extends RefCounted:
	var terrain
	func _init(value) -> void: terrain = value
	func sample(x: float,z: float) -> Dictionary: return terrain.sample(x,z)
	func contact_normal(x: float,z: float) -> Vector3: return terrain.contact_normal(x,z)
	func snow_depth_at(x: float,z: float) -> float: return terrain.snow_depth_at(x,z)
	func rock_fraction_at(x: float,z: float) -> float: return terrain.rock_fraction_at(x,z)
	func sweep_obstacle_contact(_a: Vector3,_b: Vector3) -> Dictionary: return {}
	func sweep_obstacle(_a: Vector3,_b: Vector3) -> String: return ""

class SnowRipple extends Heightfield:
	var depth = .16
	var rock_fraction = 0.0
	func _init(amplitude: float = .15, wavelength: float = 32.0, loose: float = .16, angle: float = 0.0) -> void:
		depth = loose
		X_MIN = -256; Z_MIN = -128; NX = 129; NZ = 225
		heights.resize(NX*NZ)
		for z in NZ:
			for x in NX:
				var p = Vector2(X_MIN+x*CELL,Z_MIN+z*CELL).rotated(angle)
				heights[z*NX+x] = -(Z_MIN+z*CELL)*.46+amplitude*cos(p.y*TAU/wavelength)
	func snow_depth_at(_x: float,_z: float) -> float: return depth
	func rock_fraction_at(_x: float,_z: float) -> float: return rock_fraction
	func sweep_obstacle_contact(_a: Vector3,_b: Vector3) -> Dictionary: return {}
	func sweep_obstacle(_a: Vector3,_b: Vector3) -> String: return ""

static func measure(model, field, fixture: Dictionary, overrides: Dictionary = {}) -> Dictionary:
	var sim = model.new()
	for key in overrides: sim.tuning.set(key,overrides[key])
	var p: Array = fixture.get("origin",[0,0,0])
	var origin = Vector3(p[0],field.sample(p[0],p[2]).height,p[2])
	sim.reset(origin,fixture.get("heading",0.0)); sim.prime_contacts(field)
	sim.velocity = sim.support_basis().z*fixture.get("kmh",120.0)/3.6
	sim.effective_tuck = 1.0
	var intent = RiderInput.new(); intent.tuck = 1.0
	var short_events = 0; var launches = 0; var air_ticks = 0; var short_ticks = 0
	var max_reach = 0.0; var foot_error = 0.0; var min_load = INF; var unsupported_grip = 0.0
	var peak_load = 0.0; var bottom_outs = 0; var rock_ticks = 0; var slip_sum = 0.0
	var previous_landing = 0.0; var used_ticks = 0; var reasons = {}; var samples: Array = []
	var joules = 0.0
	var peak_crush = 0.0
	var initial_travel = atan2(sim.velocity.x,sim.velocity.z)
	var travel_angle = 0.0; var initiation_s = -1.0; var reversal_s = -1.0; var turn_2s = 0.0
	var response_s = -1.0
	var turn_sign = -signf(fixture.get("steer",.15))
	for tick in roundi(fixture.get("seconds",6.0)/DT):
		var seconds = tick*DT
		intent.steer = steering(fixture,seconds)
		var was_grounded: bool = sim.grounded
		var previous_travel = atan2(sim.velocity.x,sim.velocity.z)
		sim.step(DT,intent,field)
		var travel_delta = angle_difference(previous_travel,atan2(sim.velocity.x,sim.velocity.z))*turn_sign
		travel_angle += travel_delta
		if response_s<0 and was_grounded and travel_delta/DT>.03: response_s = (tick+1)*DT
		if initiation_s<0 and travel_angle>deg_to_rad(1): initiation_s = (tick+1)*DT
		if fixture.get("input","")=="reversal" and seconds>=2.0 and reversal_s<0 and travel_delta/DT<-.03: reversal_s = seconds-2.0+DT
		if tick==239: turn_2s = rad_to_deg(travel_angle)
		used_ticks += 1
		if not sim.grounded:
			air_ticks += 1
			if was_grounded:
				launches += 1
				reasons[sim.takeoff_reason] = reasons.get(sim.takeoff_reason,0)+1
		elif air_ticks>0:
			if air_ticks<=30: short_events += 1; short_ticks += air_ticks
			air_ticks = 0
		if sim.landing_force>previous_landing+.1 and sim.grounded: bottom_outs += 1
		previous_landing = sim.landing_force
		if sim.rock_contact>0.0: rock_ticks += 1
		slip_sum += absf(sim.slip_angle)
		for ski in sim.skis:
			if "crush_m" in ski: peak_crush = maxf(peak_crush,ski.crush_m)
			min_load = minf(min_load,ski.load_n); peak_load = maxf(peak_load,ski.load_n)
			if ski.grounded:
				max_reach = maxf(max_reach,absf(sim.position.y-ski.height_reference))
				var crush_y: float = ski.crush_vertical_m if "crush_vertical_m" in ski else 0.0
				foot_error = maxf(foot_error,absf(ski.position.y+crush_y-field.sample(ski.position.x,ski.position.z).height))
			else: unsupported_grip = maxf(unsupported_grip,absf(ski.grip_n))
			if "normal_dissipated_j" in ski: joules += ski.normal_dissipated_j
		if tick%24==0:
			samples.append({"s":seconds,"p":[sim.position.x,sim.position.y,sim.position.z],"kmh":sim.speed_kmh(),"load":sim.normal_load,"slip":sim.slip_angle,"grounded":sim.grounded,"reach":sim.support_offset_m})
		if sim.crashed: break
	return {"short_events":short_events,"short_airtime_s":short_ticks*DT,"launches":launches,"airtime_s":sim.total_airtime,
		"duration_s":used_ticks*DT,"exit_kmh":sim.speed_kmh(),"crash":sim.crash_reason,"rock_s":rock_ticks*DT,
		"min_load_n":min_load,"peak_load_n":peak_load,"reach_m":max_reach,"foot_error_m":foot_error,"unsupported_grip_n":unsupported_grip,
		"impact_events":bottom_outs,"mean_slip_rad":slip_sum/maxi(used_ticks,1),"reasons":reasons,"dissipated_j":joules,"samples":samples,
		"initiation_s":initiation_s,"response_s":response_s,"reversal_s":reversal_s,"turn_2s_deg":turn_2s,"initial_travel":initial_travel,"peak_crush_m":peak_crush}

static func steering(fixture: Dictionary, seconds: float) -> float:
	var steer: float = fixture.get("steer",.15)
	match fixture.get("input","ripple"):
		"glide": return 0.0
		"carve": return steer
		"reversal": return steer if seconds<2.0 else -steer
	return steer*sin(seconds*2.0)

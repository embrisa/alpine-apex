extends RefCounted
## Fixed-tick double-pole actuator. No Nodes, contacts, root motion or velocity assignment.
const TerrainMaterial = preload("res://scripts/core/terrain_material.gd")
# Vector3 components use float32 even though scalar GDScript floats are double.
const VECTOR_EPSILON = 1.1920928955078125e-7
var phase = 0.0
var cycle_phase = 0.0
var intensity = 0.0
var power = 0.0
var acceleration = 0.0
var limit_mps = 0.0
var grade_degrees = 0.0
var cadence_hz = 0.0
var cycles = 0
var active = false
var reason = "reset"

func reset(why: String = "reset") -> void:
	phase = 0.0; cycle_phase = 0.0; intensity = 0.0; power = 0.0; acceleration = 0.0
	limit_mps = 0.0; grade_degrees = 0.0; cadence_hz = 0.0
	cycles = 0; active = false; reason = why

static func speed_limit(grade: float, tuning) -> float:
	var angles: PackedFloat32Array = tuning.pole_push_grades_degrees
	var speeds: PackedFloat32Array = tuning.pole_push_speeds_kmh
	assert(angles.size()==speeds.size() and angles.size()>=2)
	if grade<=angles[0]: return speeds[0]/3.6
	for i in range(1,angles.size()):
		if grade<=angles[i]:
			return lerpf(speeds[i-1],speeds[i],smoothstep(angles[i-1],angles[i],grade))/3.6
	return 0.0

static func stroke_power(at: float) -> float:
	# Reach/plant -> loaded backward stroke -> release/recovery. Smooth ramps,
	# average .60 over a cycle. Source keys use these same phase landmarks.
	return smoothstep(.06,.16,at)*(1.0-smoothstep(.66,.76,at))

func eligibility(sim, intent) -> String:
	if not sim.tuning.pole_push_enabled: return "disabled"
	if sim.crashed: return "crashed"
	if not sim.grounded or sim.contact_count!=2 or sim.normal_load<.5: return "unsupported"
	if intent.tuck<=.001: return "released"
	if intent.brake>.001: return "braking"
	if intent.jump or intent.jump_held or sim.jump_buffer_remaining>.000001: return "jump"
	if sim.facing_backward: return "switch"
	if absf(intent.steer)>=sim.tuning.pole_push_steer_cutoff: return "strong turn"
	if absf(sim.body.roll)>sim.tuning.pole_push_bank_cutoff: return "banked"
	if sim.snow_contact_assist.suppressed: return "rough support"
	for ski in sim.skis:
		if not ski.grounded or ski.normal_acceleration<=.1: return "unloaded ski"
		if ski.material_kind!=TerrainMaterial.Kind.SNOW: return "rock"
		if ski.normal.dot(sim.surface_normal)<cos(sim.tuning.pole_push_normal_tolerance): return "rough support"
	return ""

func advance(dt: float, sim, intent, incoming_tangent_speed: float) -> Vector3:
	acceleration = 0.0; power = 0.0
	var normal: Vector3 = sim.surface_normal
	# support_basis preserves the intended horizontal heading on a cross-slope.
	# Measuring this projected direction's rise handles traverses correctly.
	var forward: Vector3 = sim.support_basis().z.slide(normal).normalized()
	grade_degrees = rad_to_deg(asin(clampf(forward.y,-1.0,1.0)))
	limit_mps = speed_limit(maxf(0.0,grade_degrees),sim.tuning)
	var tangent: Vector3 = sim.velocity.slide(normal)
	var speed = tangent.length()
	var forward_speed = tangent.dot(forward)
	var lateral_speed = tangent.slide(forward).length()
	# Retain the preceding completed speed through this tick's contact changes.
	# Neither contact dissipation nor resistance may enable a stroke at the cap.
	# Four float32 epsilons cover vector construction/projection/length rounding:
	# nominal 40/3.6 becomes 11.111110687 in a Vector3, below its scalar cap.
	# Conservatively remove only this microscopic boundary band (0.00002 km/h
	# at 40); never enlarge the cap or apply a tolerance to a positive force.
	var eligibility_speed = maxf(speed,incoming_tangent_speed)
	var capped = eligibility_speed>=limit_mps-4.0*VECTOR_EPSILON*maxf(1.0,limit_mps)
	reason = eligibility(sim,intent)
	if reason.is_empty() and forward_speed < -sim.tuning.pole_push_rollback_mps: reason = "rollback"
	if reason.is_empty() and lateral_speed>sim.tuning.pole_push_sideways_mps: reason = "sideways"
	if reason.is_empty() and limit_mps<=.001: reason = "slope cutoff"
	var taper = 1.0-smoothstep(limit_mps*sim.tuning.pole_push_taper_start,limit_mps,eligibility_speed) if not capped and limit_mps>.001 else 0.0
	var slope_fade = 1.0-smoothstep(sim.tuning.pole_push_fade_degrees,sim.tuning.pole_push_grades_degrees[-1],maxf(0.0,grade_degrees))
	var demand = clampf(intent.tuck,0.0,1.0)*slope_fade
	# Do not restart at each cap crossing. Phase continues through the speed
	# taper while input remains eligible, avoiding extra plants/threshold boosts.
	if not reason.is_empty():
		active = false
		intensity = move_toward(intensity,0.0,dt*sim.tuning.pole_push_blend_rate)
		if intensity<=.000001: phase = 0.0
		return Vector3.ZERO
	if not active:
		phase = 0.0; cycle_phase = 0.0
		active = true
	cadence_hz = lerpf(sim.tuning.pole_push_cadence_hz,sim.tuning.pole_push_uphill_cadence_hz,smoothstep(0.0,34.0,maxf(0.0,grade_degrees)))
	var fast = smoothstep(2.0,40.0/3.6,speed)
	cadence_hz = lerpf(cadence_hz,sim.tuning.pole_push_fast_cadence_hz,fast)
	cycle_phase += dt*cadence_hz
	if cycle_phase>=1.0: cycles += 1
	cycle_phase = fposmod(cycle_phase,1.0)
	# Shorten physical contact at speed: a long planted stroke at 40 km/h
	# would sweep several metres beyond arm/pole reach. Retiming is solver-owned;
	# presentation samples this completed authored phase without its own clock.
	var contact_end = lerpf(.76,.26,fast)
	phase = cycle_phase*.76/contact_end if cycle_phase<=contact_end else .76+(cycle_phase-contact_end)*.24/(1.0-contact_end)
	intensity = move_toward(intensity,demand*taper,dt*sim.tuning.pole_push_blend_rate)
	var stroke = stroke_power(phase)
	power = stroke*demand*taper
	# Independent positive thrust, not gravity cancellation. Extra uphill power
	# pays the real gravity/resistance during the shorter loaded stroke only.
	var uphill_gravity = maxf(0.0,-sim.gravity_vector.dot(forward))
	var peak = minf(sim.tuning.pole_push_max_acceleration,lerpf(sim.tuning.pole_push_acceleration,sim.tuning.pole_push_fast_acceleration,fast)+uphill_gravity*sim.tuning.pole_push_uphill_power)
	acceleration = peak*power
	# Bound only this tick's added impulse to the tangent-speed sphere. This
	# does not clamp carried speed, lift the rider or brake a high-momentum entry.
	if capped:
		acceleration = 0.0; power = 0.0
	else:
		var available = sqrt(maxf(0.0,limit_mps*limit_mps-lateral_speed*lateral_speed))-forward_speed
		acceleration = minf(acceleration,maxf(0.0,available)/maxf(dt,.000001))
	reason = "power" if acceleration>0.0 else "recovery" if taper>0.0 else "speed limit"
	return forward*acceleration

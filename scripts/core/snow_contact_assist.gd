extends RefCounted
## Arcade snow retention. Only the fixed-step owner calls advance(); ordinary
## contact/presentation probes remain read-only. This removes separating kinetic
## energy, never snaps position or adds its impulse to compressive load/grip.
const TerrainMaterial = preload("res://scripts/core/terrain_material.gd")
var correction_m_s = 0.0
var dissipated_j_per_kg = 0.0
var eligible_skis = 0
var release_reason = "reset"
var suppressed = false
var settled_s = 0.0
var last_tick = -1

func reset(reason: String = "reset") -> void:
	correction_m_s = 0.0
	dissipated_j_per_kg = 0.0
	eligible_skis = 0
	release_reason = reason
	suppressed = false
	settled_s = 0.0
	last_tick = -1

func advance(dt: float, sim, surface, jump_pending: bool) -> Vector3:
	if last_tick==sim.ticks: return Vector3.ZERO
	last_tick = sim.ticks
	correction_m_s = 0.0
	dissipated_j_per_kg = 0.0
	eligible_skis = 0
	var tuning = sim.tuning
	if not tuning.snow_contact_assist_enabled:
		release_reason = "disabled"
		return Vector3.ZERO
	if jump_pending:
		suppressed = false; settled_s = 0.0
		release_reason = "jump"
		return Vector3.ZERO
	if not sim.grounded or sim.contact_count==0 or sim.normal_load<=0.0:
		release_reason = "unsupported"
		return Vector3.ZERO
	if not surface.has_method("snow_depth_at"):
		release_reason = "no loose snow"
		return Vector3.ZERO
	var direction = Vector3(sim.velocity.x,0.0,sim.velocity.z).normalized()
	if direction.length_squared()<.5:
		release_reason = "stationary"
		return Vector3.ZERO
	var next_root: Vector3 = sim.position+sim.velocity*dt
	var next_normal: Vector3 = sim._contact_normal(surface,next_root.x,next_root.z)
	var forward = Vector3(sin(sim.heading),-(next_normal.x*sin(sim.heading)+next_normal.z*cos(sim.heading))/maxf(next_normal.y,.05),cos(sim.heading)).normalized()
	var next_right = next_normal.cross(forward).normalized()
	var current_frame: Basis = sim.support_basis()
	var weighted_normal = Vector3.ZERO
	var strength = 0.0
	var separating = false
	var sharp = false
	var snow_count = 0
	for ski in sim.skis:
		if not ski.grounded or ski.load_n<=0.0: continue
		var now: Vector3 = sim.position+current_frame.x*ski.side*tuning.half_stance
		var ahead: Vector3 = next_root+next_right*ski.side*tuning.half_stance
		if TerrainMaterial.at(surface,now.x,now.z)==TerrainMaterial.Kind.ROCK or TerrainMaterial.at(surface,ahead.x,ahead.z)==TerrainMaterial.Kind.ROCK: continue
		var depth = minf(surface.snow_depth_at(now.x,now.z),surface.snow_depth_at(ahead.x,ahead.z))
		if depth<=0.0: continue
		snow_count += 1
		var current_sample: Dictionary = ski.crush.sample(surface,now.x,now.z)
		var predicted_sample: Dictionary = ski.crush.sample(surface,ahead.x,ahead.z)
		if now.y-current_sample.height>tuning.leg_extension or ahead.y-predicted_sample.height>tuning.leg_extension: continue
		# Read the actual height profile along travel on the same 4 m surface.
		# A triangle's sideways normal change is not a downhill takeoff.
		var behind = ahead-direction*4.0
		var beyond = ahead+direction*4.0
		var a: Dictionary = surface.sample(behind.x,behind.z)
		var b: Dictionary = surface.sample(ahead.x,ahead.z)
		var c: Dictionary = surface.sample(beyond.x,beyond.z)
		# Only a convex break suppresses retention. Concave landing pockets
		# keep absorption; chords also preserve ledges with parallel normals.
		var change = atan2(b.height-a.height,4.0)-atan2(c.height-b.height,4.0)
		if change>tuning.snow_contact_lip_angle:
			sharp = true
			continue
		eligible_skis += 1
		var share: float = ski.load_n/maxf(sim.tuning.rider_mass*sim.normal_load,.001)
		var weight = share*smoothstep(0.0,tuning.snow_contact_full_depth_m,depth)
		strength += weight
		weighted_normal += predicted_sample.normal*weight
		separating = separating or sim.velocity.dot(current_sample.normal)>.02
	if sharp:
		suppressed = true; settled_s = 0.0
		release_reason = "sharp lip"
		return Vector3.ZERO
	if snow_count==0:
		suppressed = false; settled_s = 0.0
		release_reason = "rock or bare"
		return Vector3.ZERO
	if eligible_skis==0 or strength<=0.0:
		settled_s = 0.0
		release_reason = "reach"
		return Vector3.ZERO
	if suppressed:
		settled_s = 0.0 if separating else settled_s+dt
		if settled_s+0.000001<tuning.snow_contact_settle_time:
			release_reason = "lip recovery"
			return Vector3.ZERO
		suppressed = false; settled_s = 0.0
	var normal = weighted_normal.normalized()
	var outward = maxf(0.0,sim.velocity.dot(normal))
	# Retain some separating motion over rounded snow.
	strength *= clampf(tuning.snow_contact_strength,0.0,1.0)
	correction_m_s = minf(outward*clampf(strength,0.0,1.0),tuning.snow_contact_max_correction_m_s)
	var correction = -normal*correction_m_s
	dissipated_j_per_kg = maxf(0.0,.5*(sim.velocity.length_squared()-(sim.velocity+correction).length_squared()))
	release_reason = "holding" if correction_m_s>0.0 else "settled"
	return correction

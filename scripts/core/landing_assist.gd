extends RefCounted
## Explicit orientation help. No Nodes, linear forces, or input substitution.
const SAMPLES = 32
const REFINEMENTS = 6
var neutral_seconds = 0.0
var strength = 0.0
var valid = false
var time_to_contact = 0.0
var contact_normal = Vector3.UP
var contact_position = Vector3.ZERO
var predicted_velocity = Vector3.ZERO
var prediction_samples = 0
var prediction_age = 1.0
var ground_strength = 0.0
var target_frame = Basis.IDENTITY
var target_initialized = false
var requested_angular_velocity = Vector3.ZERO
var ground_velocity = 0.0

func reset() -> void:
	requested_angular_velocity = Vector3.ZERO
	ground_velocity = 0.0
	neutral_seconds = 0.0
	strength = 0.0
	ground_strength = 0.0
	target_initialized = false
	clear_prediction()

func clear_prediction() -> void:
	valid = false
	time_to_contact = 0.0
	prediction_age = 1.0
	prediction_samples = 0
	contact_normal = Vector3.UP
	contact_position = Vector3.ZERO
	predicted_velocity = Vector3.ZERO

func step(dt: float, sim, intent, surface, already_counted: bool = false) -> void:
	if sim.crashed:
		reset()
		return
	ground_strength = 0.0
	strength = 0.0
	requested_angular_velocity = Vector3.ZERO
	if sim.grounded:
		clear_prediction()
	else:
		prediction_age += dt
		time_to_contact = maxf(0.0,time_to_contact-dt)
		if prediction_age>=1.0/30.0-0.000001:
			predict(sim,surface)
			prediction_age = 0.0
	var manual: bool = absf(intent.steer)+absf(intent.air_pitch)+absf(intent.air_yaw)+(absf(intent.air_tilt) if not sim.grounded else 0.0)>.000001 or intent.grab
	if manual:
		neutral_seconds = 0.0
		target_initialized = false
		# Stop targeting immediately, but retire the previously applied yaw rate
		# gradually. Erasing it here produced a velocity step on manual handover.
		# The player's steering is applied independently before this call.
		ground_velocity = move_toward(ground_velocity,0.0,sim.tuning.ground_assist_acceleration*dt)
		if sim.grounded: sim.heading = wrapf(sim.heading+ground_velocity*dt,-PI,PI)
		return
	if not already_counted: neutral_seconds += dt
	var weight: float = smoothstep(sim.tuning.landing_assist_delay,sim.tuning.landing_assist_delay+sim.tuning.landing_assist_blend,neutral_seconds)
	if sim.grounded:
		var goal = 0.0
		if sim.tuning.ground_assist_enabled and intent.brake<=.000001:
			ground_strength = weight*smoothstep(2.0,5.0,sim.velocity.length())
			var travel: Vector3 = sim.velocity.slide(sim.surface_normal)
			if Vector2(travel.x,travel.z).length_squared()>1.0:
				var error = wrapf(atan2(travel.x,travel.z)-sim.heading,-PI*.5,PI*.5)
				goal = clampf(error*2.0,-sim.tuning.neutral_ground_alignment_rate,sim.tuning.neutral_ground_alignment_rate)*ground_strength*smoothstep(deg_to_rad(2),deg_to_rad(8),absf(error))
		ground_velocity = move_toward(ground_velocity,goal,sim.tuning.ground_assist_acceleration*dt)
		sim.heading = wrapf(sim.heading+ground_velocity*dt,-PI,PI)
		return
	ground_velocity = 0.0
	if not sim.tuning.landing_assist_enabled or sim.air_control.orientation_flight:
		target_initialized = false
		return
	var frame: Basis = sim.support_basis()
	var along: Vector3 = predicted_velocity.slide(contact_normal) if valid else sim.velocity
	if along.length_squared()<4.0 or Vector2(along.x,along.z).length_squared()<1.0:
		target_initialized = false
		return
	along = along.normalized()
	# A switch rider remains switch. Select the equivalent ski line nearest
	# the existing frame, without changing the facing flag during free flight.
	if along.dot(frame.z)<0.0: along = -along
	var up: Vector3 = contact_normal if valid else Vector3.UP.slide(along).normalized()
	var target = Basis(up.cross(along).normalized(),up,along).orthonormalized()
	if not target_initialized:
		target_frame = frame
		target_initialized = true
	target_frame = target_frame.slerp(target,1.0-exp(-4.0*dt)).orthonormalized()
	var error_q = (target_frame*frame.transposed()).get_rotation_quaternion().normalized()
	if error_q.w<0.0: error_q = -error_q
	var axis = Vector3(error_q.x,error_q.y,error_q.z)
	var angle = 2.0*atan2(axis.length(),maxf(0.0,error_q.w))
	strength = weight
	if axis.length_squared()>.000000001:
		requested_angular_velocity = axis.normalized()*minf(sim.tuning.neutral_air_alignment_rate,angle*2.0)*strength

func predict(sim, surface) -> void:
	valid = false
	prediction_samples = 0
	var frame: Basis = sim.support_basis()
	var p: Vector3 = sim.position
	var v: Vector3 = sim.velocity
	var horizon: float = clampf(sim.tuning.landing_assist_horizon,0.05,1.0)
	var increment = horizon/SAMPLES
	var drag: float = sim.tuning.aerodynamic_drag*lerpf(1.0,sim.tuning.tuck_drag_ratio,sim.effective_tuck)
	for index in range(SAMPLES):
		var previous = p
		v += sim.gravity_vector*increment
		v /= 1.0+drag*v.length()*increment
		p += v*increment
		var sample = footprint(surface,p,frame,sim.tuning.half_stance)
		if sample.is_empty(): return
		if p.y>sample.height or v.dot(sample.normal)>=0.0: continue
		var lo = 0.0
		var hi = 1.0
		for refinement in range(REFINEMENTS):
			var mid = (lo+hi)*.5
			var point = previous.lerp(p,mid)
			var probe = footprint(surface,point,frame,sim.tuning.half_stance)
			if probe.is_empty(): return
			if point.y>probe.height: lo = mid
			else: hi = mid; sample = probe
		contact_position = previous.lerp(p,hi)
		contact_normal = sample.normal
		predicted_velocity = v
		time_to_contact = (index+hi)*increment
		valid = true
		return

func footprint(surface, root: Vector3, frame: Basis, half_stance: float) -> Dictionary:
	var highest = -INF
	var normal = Vector3.UP
	for side in [-1.0,1.0]:
		var offset: Vector3 = frame.x*side*half_stance
		var p = root+offset
		if surface.has_method("bounds") and not surface.bounds().has_point(Vector2(p.x,p.z)): return {}
		if surface.has_method("ski_bounds") and not surface.ski_bounds().has_point(Vector2(p.x,p.z)): return {}
		var sample: Dictionary = surface.sample(p.x,p.z)
		prediction_samples += 1
		if sample.height-offset.y>highest:
			highest = sample.height-offset.y
			normal = sample.normal
	return {"height":highest,"normal":normal}

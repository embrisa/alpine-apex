class_name SkiSimulation
extends RefCounted
const MODEL_VERSION = 12
const Contact = preload("res://scripts/core/ski_contact.gd")
const Body = preload("res://scripts/core/rider_body.gd")
const ImpactRecovery = preload("res://scripts/core/impact_recovery.gd")
## Two unilateral ski contacts coupled to an articulated rider balance model.
## Heading is ski orientation; velocity is never assigned from heading or input.
## The surface provides sample(x,z) -> {height, normal}, sweep_obstacle(from,to),
## and optionally snow_depth_at(x,z) -> loose-layer depth in metres.
var tuning: SkiTuning
var skis: Array = [Contact.new(-1.0),Contact.new(1.0)]
var body = Body.new()
var impacts = ImpactRecovery.new()
var contacts_initialized = false
var contact_count = 0
var support_height = 0.0
var force_acceleration = Vector3.ZERO
var air_acceleration = Vector3.ZERO
var requested_lateral_acceleration = 0.0
var position: Vector3 = Vector3.ZERO
var velocity: Vector3 = Vector3.ZERO
var heading: float = 0.0
var edge_angle: float = 0.0
var grounded: bool = true
var crashed: bool = false
var crash_reason: String = ""
var balance: float = 1.0 # Legacy diagnostic compatibility only; no balance health/death.
var airtime: float = 0.0
var total_airtime: float = 0.0
var peak_speed: float = 0.0
var acceleration: float = 0.0
var slip_angle: float = 0.0
var slope_angle: float = 0.0
var normal_load: float = 9.81
var friction_force: float = 0.0
## Loose snow depth / effective ski penetration in metres; drag in m/s².
var snow_depth: float = 0.0
var snow_penetration: float = 0.0
var snow_drag: float = 0.0
var gravity_contribution: float = 0.0
## Decaying normal impact speed in m/s, retained name for existing presentation.
var landing_force: float = 0.0
var time_since_landing: float = 60.0 # s, capped; distinguishes impact from recovery feedback
var effective_tuck: float = 0.0
var edge_load: float = 0.0
var lateral_acceleration: float = 0.0
var balance_pressure: float = 0.0 # Retired diagnostic; no pressure damage.
var surface_normal: Vector3 = Vector3.UP
var fall_line: Vector3 = Vector3.FORWARD
var ski_forward: Vector3 = Vector3.BACK
var gravity_vector: Vector3 = Vector3.DOWN * 9.81
var ticks: int = 0
var flight_frame = Basis.IDENTITY
var flight_heading = 0.0
var flight_initialized = false
var landing_support_positions: Array[Vector3] = []
var jump_buffer_remaining: float = 0.0

func _init(values: SkiTuning = null) -> void:
	tuning = values if values != null else SkiTuning.new()

func reset(spawn: Vector3, yaw: float = 0.0) -> void:
	position = spawn
	velocity = Vector3.ZERO
	heading = yaw
	edge_angle = 0.0
	grounded = true
	crashed = false
	crash_reason = ""
	balance = 1.0
	airtime = 0.0
	total_airtime = 0.0
	peak_speed = 0.0
	acceleration = 0.0
	slip_angle = 0.0
	landing_force = 0.0
	time_since_landing = 60.0
	effective_tuck = 0.0
	edge_load = 0.0
	lateral_acceleration = 0.0
	balance_pressure = 0.0
	friction_force = 0.0
	snow_depth = 0.0
	snow_penetration = 0.0
	snow_drag = 0.0
	gravity_contribution = 0.0
	normal_load = 9.81
	ticks = 0
	flight_initialized = false
	landing_support_positions.clear()
	clear_input_buffer()
	body.reset()
	impacts.reset()
	contacts_initialized = false
	contact_count = 0
	force_acceleration = Vector3.ZERO
	air_acceleration = Vector3.ZERO
	requested_lateral_acceleration = 0.0
	for ski in skis: ski.reset(spawn,yaw,tuning.half_stance)

func step(dt: float, intent: RiderInput, surface) -> void:
	if crashed:
		return
	ticks += 1
	balance = 1.0
	impacts.step(dt,grounded and normal_load>0.0,tuning)
	# A release may wait briefly for support, but cannot create an air impulse.
	if intent.jump:
		jump_buffer_remaining = tuning.jump_buffer_time
	var supported_at_start = grounded and contacts_initialized and contact_count>0 and normal_load>0.0
	var old_position = position
	var old_speed = velocity.length()
	var old_velocity = velocity
	landing_support_positions.clear()
	var previous_support = [skis[0].grounded,skis[1].grounded]
	for ski in skis:
		ski.previous_position = ski.position
		ski.previous_orientation = ski.orientation
		ski.landing_speed = 0.0
	var n: Vector3 = _contact_normal(surface,position.x,position.z)
	surface_normal = n
	gravity_vector = Vector3.DOWN * 9.81 * tuning.gravity_multiplier
	var downhill = gravity_vector.slide(n)
	fall_line = downhill.normalized()
	slope_angle = rad_to_deg(acos(clampf(n.y, -1.0, 1.0)))
	landing_force = move_toward(landing_force, 0.0, dt * 12.0)
	time_since_landing = minf(60.0,time_since_landing+dt)
	# Opening the stance to turn/brake sacrifices the deepest aerodynamic tuck.
	# A tuck reduces available edging leverage; it is never a throttle.
	var tuck_target = clampf(intent.tuck, 0.0, 1.0) * (1.0 - 0.75 * smoothstep(0.12, 0.85, absf(intent.steer))) * (1.0 - clampf(intent.brake, 0.0, 1.0))
	effective_tuck = lerpf(effective_tuck, tuck_target, 1.0 - exp(-tuning.tuck_response * dt))
	edge_load = 0.0
	lateral_acceleration = 0.0
	requested_lateral_acceleration = 0.0
	balance_pressure = 0.0
	snow_depth = 0.0
	snow_penetration = 0.0
	snow_drag = 0.0
	var steer_rate = tuning.steering_sensitivity / (1.0 + old_speed * tuning.high_speed_steering_reduction)
	if grounded and old_speed>3.0:
		# Transfer body weight before driving the skis through an edge change.
		# The balance controller still receives the player's full steering intent.
		if body.roll*intent.steer<0.0:
			steer_rate *= lerpf(tuning.turn_transfer_yaw_fraction,1.0,1.0-smoothstep(.03,.30,absf(body.roll)))
		var travel_heading = atan2(velocity.x,velocity.z)
		var heading_slip = wrapf(travel_heading-heading,-PI,PI)
		# Ease further yaw into excessive slip; countersteering remains available.
		# Only equipment yaw is limited. Snow forces still turn the trajectory.
		if heading_slip*intent.steer>0.0:
			steer_rate *= 1.0-smoothstep(deg_to_rad(8.0),deg_to_rad(18.0),absf(heading_slip))*smoothstep(3.0,12.0,old_speed)
	# Air steering can orient the equipment but cannot steer the centre of mass.
	# Positive intent means rider-right. With forward=(sin(yaw),0,cos(yaw)),
	# rider-right is forward.cross(UP), so right turns DECREASE yaw.
	heading = wrapf(heading - intent.steer * steer_rate * dt * (1.0 if grounded else 0.42), -PI, PI)
	edge_angle = lerpf(edge_angle, -intent.steer * deg_to_rad(tuning.maximum_edge_angle), 1.0 - exp(-tuning.edge_response * lerpf(1.0, 0.70, effective_tuck) * dt))
	var takeoff_frame = support_basis()
	_update_contacts(surface,dt)
	n = surface_normal
	# Consume before predictive contact/next-height release wins this tick. The
	# cached frame belongs to actual support at its start, not an air grace period.
	var supported_now = grounded and contact_count>0 and normal_load>0.0
	if (intent.jump or jump_buffer_remaining>0.000001) and (supported_at_start or supported_now):
		if supported_now: takeoff_frame = support_basis()
		velocity += takeoff_frame.y*tuning.jump_impulse
		clear_input_buffer()
		_begin_flight(takeoff_frame)
	jump_buffer_remaining = maxf(0.0,jump_buffer_remaining-dt)
	if grounded:
		# Check the actual next height as well as the filtered support normal.
		# A ledge can fall away inside the normal stencil. Snow cannot pull the
		# rider down to it; retain incoming momentum and start a ballistic step.
		var ballistic = position+velocity*dt+gravity_vector*dt*dt
		var resting_offset = position.y-_support_sample(surface,position).height
		if ballistic.y-_support_sample(surface,ballistic).height-resting_offset>.025:
			_begin_flight(support_basis())
	downhill = gravity_vector.slide(n)
	fall_line = downhill.normalized()
	ski_forward = support_basis().z
	var side = n.cross(ski_forward).normalized()
	var forward_speed = velocity.dot(ski_forward)
	var side_speed = velocity.dot(side)
	slip_angle = atan2(side_speed, maxf(absf(forward_speed), 0.01))
	if grounded:
		velocity = velocity.slide(n)
		var edge = absf(edge_angle) / deg_to_rad(tuning.maximum_edge_angle)
		var grip_limit = 0.0
		var grip_limits: Array[float] = []
		requested_lateral_acceleration = -signf(side_speed)*minf(absf(side_speed)*tuning.carving_strength,normal_load*tuning.edge_grip*lerpf(.42,1.0,edge))
		var balance_grip: float = body.available_lateral(signf(requested_lateral_acceleration),normal_load,tuning)
		for ski in skis:
			grip_limits.append(0.0)
			if not ski.grounded: continue
			var ski_side: Vector3 = ski.normal.cross(ski.forward).normalized()
			var sideways: float = velocity.dot(ski_side)
			var ski_edge: float = absf(ski.edge_angle)/deg_to_rad(tuning.maximum_edge_angle)
			var limit: float = ski.normal_acceleration*tuning.edge_grip*lerpf(.42,1.0,ski_edge)*lerpf(1.0,tuning.tuck_grip_ratio,effective_tuck)
			grip_limits[grip_limits.size()-1] = limit
			ski.slip_angle = atan2(sideways,maxf(absf(velocity.dot(ski.forward)),.01))
			grip_limit += limit
		edge_load = clampf(absf(side_speed)*tuning.carving_strength/maxf(grip_limit,.01),0.0,1.0)
		# Slip costs speed through snow work; it never drains a health meter.
		var skid_drag = tuning.skidding_friction * absf(sin(slip_angle)) * maxf(normal_load, 0.0)
		# Optional equipment-neutral surface contract. Legacy/ideal planes have
		# no loose layer. Planing reduces penetration with speed; load and
		# sideways displacement increase passive snow work, never propulsion.
		if surface.has_method("snow_depth_at"):
			for ski in skis:
				if not ski.grounded: continue
				ski.snow_depth = clampf(surface.snow_depth_at(ski.position.x,ski.position.z),0.0,.35)
				var pressure: float = clampf(ski.normal_acceleration*contact_count/9.81,0.0,4.0)
				var planing = .20+.70/(1.0+pow(old_speed/12.0,2.0))
				ski.penetration = minf(ski.snow_depth,ski.snow_depth*planing*sqrt(pressure))
				var cutting = .09+2.0*absf(sin(ski.slip_angle))+clampf(intent.brake,0.0,1.0)
				ski.snow_drag = minf(6.0/maxi(contact_count,1),ski.penetration*ski.normal_acceleration*tuning.snow_ploughing*cutting)*smoothstep(0.0,1.0,old_speed)
				snow_drag += ski.snow_drag
				snow_depth += ski.snow_depth/maxi(contact_count,1)
				snow_penetration += ski.penetration/maxi(contact_count,1)
		friction_force = tuning.ski_friction * maxf(normal_load, 0.0) * (1.0 + edge * edge * 0.4) + tuning.snow_resistance + snow_drag + skid_drag + intent.brake * tuning.braking_deceleration
		friction_force = minf(friction_force,body.available_braking(signf(velocity.dot(ski_forward)),normal_load,tuning))
		# Edge grip and sliding/braking resistance act through the SAME feet.
		# Apply resistance first, leaving at least half the lateral capacity
		# for edging. Then grip uses the remaining support. This retains turn
		# and snow drag without spending the same balance capacity twice.
		var lateral_fraction = absf(velocity.normalized().dot(side))
		if lateral_fraction>.001:
			friction_force = minf(friction_force,balance_grip*.5/lateral_fraction)
		friction_force = minf(friction_force,velocity.length()/dt)
		velocity = velocity.move_toward(Vector3.ZERO, friction_force * dt)
		balance_grip = maxf(0.0,balance_grip-friction_force*lateral_fraction)
		var lateral_before = velocity
		for i in range(skis.size()):
			var ski = skis[i]
			if not ski.grounded: continue
			var ski_side: Vector3 = ski.normal.cross(ski.forward).normalized()
			var sideways: float = velocity.dot(ski_side)
			var share: float = ski.normal_acceleration/maxf(normal_load,.001)
			var demand: float = absf(lateral_before.dot(ski_side))*tuning.carving_strength*share
			var applied: float = minf(minf(demand,minf(grip_limits[i],balance_grip*share)),absf(sideways)/dt)
			velocity -= ski_side*signf(sideways)*applied*dt
			ski.grip_n = applied*tuning.rider_mass
		lateral_acceleration = (velocity-lateral_before).dot(side)/dt
		# Static braking can hold on the test slope. Gravity is otherwise the
		# only source of downhill acceleration; tuck only changes air drag.
		if not (intent.brake > 0.8 and velocity.length() < 0.2 and downhill.length() < tuning.braking_deceleration):
			velocity += downhill * dt
		gravity_contribution = downhill.dot(velocity.normalized())
	if not grounded:
		velocity += gravity_vector * dt
		airtime += dt
		total_airtime += dt
		normal_load = 0.0
		friction_force = 0.0
		gravity_contribution = gravity_vector.dot(velocity.normalized())
	# Quadratic drag is integrated analytically for stability at extreme speeds.
	var drag = tuning.aerodynamic_drag * lerpf(1.0, tuning.tuck_drag_ratio, effective_tuck)
	var before_drag = velocity
	velocity /= 1.0 + drag * velocity.length() * dt
	air_acceleration = (velocity-before_drag)/dt
	position += velocity * dt
	var next_ground = _support_sample(surface,position)
	if grounded:
		position.y = next_ground.height
		# A passive surface cannot add kinetic energy when its normal changes.
		velocity = velocity.slide(_contact_normal(surface,position.x,position.z))
	elif position.y <= next_ground.height:
		# The short segment is swept against the heightfield to locate impact.
		var lo = 0.0
		var hi = 1.0
		for i in range(8):
			var mid = (lo + hi) * 0.5
			var p = old_position.lerp(position, mid)
			if p.y > _support_sample(surface,p).height:
				lo = mid
			else:
				hi = mid
		position = old_position.lerp(position, hi)
		var contact = _support_sample(surface,position)
		# The collision impulse belongs to the triangle actually struck. The
		# filtered support frame may already lean over a nearby cliff edge.
		contact.normal = surface.sample(position.x,position.z).normal
		position.y = contact.height
		var impact = maxf(0.0, -velocity.dot(contact.normal))
		landing_force = impact
		time_since_landing = 0.0
		for ski in skis:
			if absf(position.y-ski.height_reference)<.04: ski.landing_speed = impact
		var tolerance = tuning.landing_tolerance * (1.0 + effective_tuck * tuning.landing_absorption)
		# A glancing brush cannot deliver a large edge-catch impulse. Scale the
		# alignment penalty by the normal impact it can actually transmit; the
		# old speed-only penalty repeatedly punished tiny terrain recontacts.
		var bad_alignment = minf(impact,absf(sin(slip_angle))*velocity.length()*.16)
		if impacts.hit(impact+bad_alignment,tolerance,"HARD LANDING",tuning):
			crash("IMPACT LIMIT / HARD LANDING")
		else:
			# Retain the footprint that delivered the impulse even if a convex
			# landing immediately releases again. The body must receive that
			# reaction, independently of the next tick's contact prediction.
			var impact_frame = support_basis()
			for ski in skis:
				var foot: Vector3 = position+impact_frame.x*ski.side*tuning.half_stance
				var height_value: float = surface.sample(foot.x,foot.z).height
				if foot.y-height_value<=tuning.leg_extension+.015:
					landing_support_positions.append(Vector3(foot.x,height_value,foot.z))
			velocity = velocity.slide(contact.normal) * (1.0 - minf(0.25, bad_alignment * 0.025))
			grounded = true
			flight_initialized = false
			airtime = 0.0
			# Spend the rest of the tick after impact. Discarding it makes early
			# grazing contacts at a crest repeatedly consume an entire tick and
			# pins the skier to the lip. Never snap across a falling ledge here.
			var remaining = dt*(1.0-hi)
			var end = position+velocity*remaining
			var end_ground = _support_sample(surface,end)
			if end.y-end_ground.height>.025:
				_begin_flight(support_basis())
				# Gravity and drag have already been integrated once this tick.
				position = end
			else:
				position = end
				position.y = end_ground.height
	_resolve_obstacle(surface,old_position)
	_update_contacts(surface,dt,false)
	for i in range(2):
		if skis[i].grounded and not previous_support[i]:
			skis[i].landing_speed = maxf(0.0,-old_velocity.dot(skis[i].normal))
	# body.step applies this tick's landing reaction through the actual support
	# footprint, including a single ski. An extra one-ski angular kick here
	# would count that impulse twice and tip an otherwise aligned landing.
	force_acceleration = (velocity-old_velocity)/dt
	body.step(dt,self,intent,force_acceleration)
	# Articulated body tilt and sideways slip cannot cause a fall.
	peak_speed = maxf(peak_speed, velocity.length())
	acceleration = (velocity.length() - old_speed) / dt

func _resolve_obstacle(surface, from: Vector3) -> void:
	if crashed: return
	# Keep the reason-only API for older surfaces and obstacle-free test adapters.
	var reason: String = surface.sweep_obstacle(from,position)
	if reason.is_empty(): return
	if not surface.has_method("sweep_obstacle_contact"):
		crash(reason) # No contact geometry: cannot safely infer a glancing hit.
		return
	var hit: Dictionary = surface.sweep_obstacle_contact(from,position)
	if hit.is_empty() or hit.get("boundary",false):
		crash(reason)
		return
	var normal: Vector3 = hit.normal
	var closing = maxf(0.0,-velocity.dot(normal))
	position = hit.position+normal*.02
	if impacts.hit(closing,tuning.obstacle_impact_reference,reason,tuning):
		crash("IMPACT LIMIT / "+reason)
	else:
		# Surviving a hit still stops its inward momentum at the actual contact.
		# Tangential motion may slide along the envelope; no phasing through it.
		if velocity.dot(normal)<0.0: velocity = velocity.slide(normal)

func clear_input_buffer() -> void:
	jump_buffer_remaining = 0.0

func crash(reason: String) -> void:
	clear_input_buffer()
	crashed = true
	crash_reason = reason

func speed_kmh() -> float:
	return velocity.length() * 3.6

func _contact_normal(surface,x: float,z: float) -> Vector3:
	if surface.has_method("contact_normal"):
		return surface.contact_normal(x,z)
	return surface.sample(x,z).normal

func support_basis() -> Basis:
	if not grounded and flight_initialized:
		# Equipment yaw is allowed in flight. Pitch/roll never track terrain
		# metres below the skis, and orientation never redirects velocity.
		return Basis(Vector3.UP,angle_difference(flight_heading,heading))*flight_frame
	var n = surface_normal
	var f = Vector3(sin(heading),-(n.x*sin(heading)+n.z*cos(heading))/maxf(n.y,.05),cos(heading)).normalized()
	return Basis(n.cross(f).normalized(),n,f)

func _begin_flight(frame: Basis) -> void:
	flight_frame = frame
	flight_heading = heading
	flight_initialized = true
	grounded = false
	contact_count = 0
	normal_load = 0.0
	for ski in skis:
		ski.grounded = false
		ski.load_n = 0.0
		ski.normal_acceleration = 0.0

func _support_sample(surface, root: Vector3) -> Dictionary:
	var frame = support_basis()
	var heights: Array[float] = []
	for ski in skis:
		var offset: Vector3 = frame.x*ski.side*tuning.half_stance
		heights.append(float(surface.sample(root.x+offset.x,root.z+offset.z).height)-offset.y)
	var high = maxf(heights[0],heights[1])
	var low = minf(heights[0],heights[1])
	return {"height":(high+low)*.5 if grounded and high-low<=tuning.leg_extension else high,"normal":_contact_normal(surface,root.x,root.z)}

func _update_contacts(surface, dt: float, advance_motors: bool = true) -> void:
	# The shared reference frame describes terrain geometry, not pressure.
	# Weighting its normal by boot load feeds load transfer back into body lean
	# and can rotate the ground frame when only the rider's pressure changed.
	# Each ski retains its own normal and independent unilateral support load.
	surface_normal = _contact_normal(surface,position.x,position.z)
	var frame = support_basis()
	if not grounded and not flight_initialized:
		_begin_flight(frame)
	var was_grounded = grounded
	var shares: Vector2 = body.load_fractions if body.initialized else Vector2(.5,.5)
	var supported: Array[bool] = []
	var share_sum = 0.0
	contact_count = 0
	for i in range(2):
		var ski = skis[i]
		# Independently loaded boots transmit the edging command at different rates.
		if advance_motors:
			# Each loaded ski has its own boot/edge response and yaw.
			ski.heading = lerp_angle(ski.heading,heading,1.0-exp(-60.0*dt*(.8+.4*shares[i])))
			# A rigid cuff cannot roll independently through a nearly upright
			# shin. Edge engagement follows the rider's bank, with a small range
			# for angulation. Input still requests lean through the balance loop.
			var bank: float = body.roll if body.initialized else 0.0
			var edge_goal = clampf(edge_angle,-bank-.10,-bank+.10)
			var edge_limit = deg_to_rad(tuning.maximum_edge_angle)
			edge_goal = clampf(edge_goal,-edge_limit,edge_limit)
			var edge_response_value = lerpf(ski.edge_angle,edge_goal,1.0-exp(-32.0*dt*(.65+shares[i])))
			# Bound cuff rotation even during a fast reversal or recovery. This
			# applies to the physical contact, not only to its rendered mesh.
			ski.edge_angle = move_toward(ski.edge_angle,edge_response_value,3.0*dt)
		ski.probe(surface,position,frame,velocity,gravity_vector,dt,tuning.half_stance)
		var touching: bool = grounded and position.y-ski.height_reference<=tuning.leg_extension+.015
		var carrying: bool = touching and ski.gross_load>=maxf(0.0,tuning.minimum_load)
		supported.append(carrying)
		if carrying:
			contact_count += 1
			share_sum += maxf(shares[i],.001)
	normal_load = 0.0
	support_height = 0.0
	for i in range(2):
		var fraction: float = maxf(shares[i],.001)/maxf(share_sum,.001) if supported[i] else 0.0
		skis[i].finish(position,frame,tuning.half_stance,dt,tuning.leg_extension,tuning.rider_mass,fraction,supported[i])
		normal_load += skis[i].normal_acceleration
		if supported[i]:
			support_height += skis[i].height_reference/contact_count
	if was_grounded and contact_count==0:
		_begin_flight(frame)
	else:
		grounded = contact_count>0
	contacts_initialized = true

func prime_contacts(surface) -> void:
	# Explicit initialization used by restart/tools, never called from rendering.
	surface_normal = _contact_normal(surface,position.x,position.z)
	gravity_vector = Vector3.DOWN*9.81*tuning.gravity_multiplier
	_update_contacts(surface,1.0/120.0)
	body.step(1.0/120.0,self,preload("res://scripts/core/rider_input.gd").new(),Vector3.ZERO)
	reset_pose_history()

func reset_pose_history() -> void:
	# Pause/resume and teleports discard render history without advancing the
	# contact or balance solver. The next tick starts from this completed pose.
	body.previous_pose_frame = body.pose_frame
	body.previous_joints = body.joints.duplicate()
	body.previous_rotations = body.rotations.duplicate()
	for ski in skis:
		ski.previous_position = ski.position
		ski.previous_orientation = ski.orientation

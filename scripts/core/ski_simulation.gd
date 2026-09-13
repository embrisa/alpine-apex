class_name SkiSimulation
extends RefCounted
const MODEL_VERSION = 33
const TerrainMaterial = preload("res://scripts/core/terrain_material.gd")
const Contact = preload("res://scripts/core/ski_contact.gd")
const Body = preload("res://scripts/core/rider_body.gd")
const ImpactRecovery = preload("res://scripts/core/impact_recovery.gd")
## Two unilateral ski contacts coupled to an articulated rider balance model.
## Heading is the travel-oriented ski axis; facing_heading includes visual switch.
## Velocity is never assigned from heading or input.
## The surface provides sample(x,z) -> {height, normal}, sweep_obstacle(from,to),
## optionally snow_depth_at(x,z) -> loose-layer depth in metres,
## and rock_fraction_at(x,z) -> fixed terrain material coverage in [0,1].
var tuning: SkiTuning
var skis: Array = [Contact.new(-1.0),Contact.new(1.0)]
var body = Body.new()
var impacts = ImpactRecovery.new()
var landing_assist = preload("res://scripts/core/landing_assist.gd").new()
var air_control = preload("res://scripts/core/air_rotation.gd").new()
var snow_contact_assist = preload("res://scripts/core/snow_contact_assist.gd").new()
var pole_push = preload("res://scripts/core/pole_propulsion.gd").new()
var pole_push_phase: float:
	get: return pole_push.phase
var pole_push_intensity: float:
	get: return pole_push.intensity
var pole_push_power: float:
	get: return pole_push.power
var pole_push_acceleration: float:
	get: return pole_push.acceleration
var pole_push_limit_mps: float:
	get: return pole_push.limit_mps
var pole_push_grade_degrees: float:
	get: return pole_push.grade_degrees
var motion = preload("res://scripts/core/rider_motion_state.gd").new()
var facing_pose = preload("res://scripts/core/rider_facing_pose.gd").new()
# Handling yaw describes the travel-oriented ski axis. The half turn is visual.
var facing_backward = false
var facing_heading: float:
	get: return wrapf(heading+(PI if facing_backward else 0.0),-PI,PI)
var landing_assist_strength: float:
	get: return landing_assist.strength
var predicted_landing_time: float:
	get: return landing_assist.time_to_contact if landing_assist.valid else -1.0
var predicted_landing_normal: Vector3:
	get: return landing_assist.contact_normal
var contacts_initialized = false
var contact_count = 0
var support_height = 0.0
var force_acceleration = Vector3.ZERO
var air_acceleration = Vector3.ZERO
var requested_lateral_acceleration = 0.0
var turn_demand = 0.0 # rad/s, shared travel-oriented yaw and bank request
## Completed input-to-ski steering diagnostics, rad/s and unitless factors.
var steering_requested_yaw = 0.0
var steering_applied_yaw = 0.0
var steering_transfer_factor = 1.0
var steering_slip_factor = 1.0
var steering_stall_age = 0.0 # s, continuous blocked request; not a general input delay
var carve_blend = 0.0 # Current supported snow command; no shared tuning mutation.
var snow_control_blend = 0.0 # supported high-input snow stance; no airborne authority
var support_offset_m = 0.0 # signed root height above the shared ski support
var takeoff_reason = "" # diagnostic, retained until the next release/reset
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
var rock_contact: float = 0.0 # Fraction of current support load carried by rock.
var rock_wear_rate: float = 0.0 # Reserve fraction/s, completed contact tick.
var gravity_contribution: float = 0.0
## Decaying normal impact speed in m/s, retained name for existing presentation.
var landing_force: float = 0.0
var time_since_landing: float = 60.0 # s, capped; distinguishes impact from recovery feedback
var landing_episode_age: float = 60.0 # s since first touchdown; recontacts cannot extend it
var landing_episode_fit: float = 0.0 # weakest pre-touchdown fit in this contact episode
var effective_tuck: float = 0.0
var tuck_steering_time: float = 0.0 # s of sustained steering beyond the correction window
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
var _jump_executed = false
var jump_executed: bool:
	get: return _jump_executed # Completed-tick telemetry, never an input/force.
var _obstacle_contact: Dictionary = {}
var obstacle_contact: Dictionary:
	get: return _obstacle_contact.duplicate() # Completed tick, no mutable solver alias.

func _init(values: SkiTuning = null) -> void:
	tuning = values if values != null else SkiTuning.new()

func reset(spawn: Vector3, yaw: float = 0.0) -> void:
	air_control.reset()
	snow_contact_assist.reset()
	motion.reset()
	_obstacle_contact.clear()
	_jump_executed = false
	position = spawn
	velocity = Vector3.ZERO
	heading = yaw
	facing_backward = false
	facing_pose.initialized = false
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
	landing_episode_age = 60.0
	landing_episode_fit = 0.0
	effective_tuck = 0.0
	tuck_steering_time = 0.0
	edge_load = 0.0
	lateral_acceleration = 0.0
	balance_pressure = 0.0
	friction_force = 0.0
	rock_contact = 0.0
	rock_wear_rate = 0.0
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
	turn_demand = 0.0
	steering_requested_yaw = 0.0; steering_applied_yaw = 0.0
	steering_transfer_factor = 1.0; steering_slip_factor = 1.0
	steering_stall_age = 0.0
	carve_blend = 0.0
	snow_control_blend = 0.0
	support_offset_m = 0.0
	takeoff_reason = ""
	for ski in skis: ski.reset(spawn,yaw,tuning.half_stance)

func step(dt: float, intent: RiderInput, surface) -> void:
	_jump_executed = false
	_obstacle_contact.clear()
	if crashed:
		return
	ticks += 1
	var rebased_spawn = _orient_travel_axis()
	if rebased_spawn and contacts_initialized:
		# Prime the same physical rest pose in the canonical travel frame. A
		# reversed spawn's old slope-relative preload is not angular momentum.
		body.reset()
		_update_contacts(surface,dt,false)
		body.step(dt,self,preload("res://scripts/core/rider_input.gd").new(),Vector3.ZERO)
	balance = 1.0
	# A release may wait briefly for support, but cannot create an air impulse.
	if intent.jump:
		jump_buffer_remaining = tuning.jump_buffer_time
	var supported_at_start = grounded and contacts_initialized and contact_count>0 and normal_load>0.0
	var old_position = position
	var old_speed = velocity.length()
	var old_velocity = velocity
	var pole_incoming_speed = velocity.slide(surface_normal).length()
	landing_support_positions.clear()
	var previous_support = [skis[0].grounded,skis[1].grounded]
	for ski in skis:
		ski.previous_position = ski.position
		ski.previous_orientation = ski.orientation
		ski.landing_speed = 0.0
		ski.crush.begin_tick(surface,ski.position,velocity,ski.grounded and grounded,tuning)
	var n: Vector3 = _contact_normal(surface,position.x,position.z)
	surface_normal = n
	gravity_vector = Vector3.DOWN * 9.81 * tuning.gravity_multiplier
	var downhill = gravity_vector.slide(n)
	fall_line = downhill.normalized()
	slope_angle = rad_to_deg(acos(clampf(n.y, -1.0, 1.0)))
	landing_force = move_toward(landing_force, 0.0, dt * 12.0)
	time_since_landing = minf(60.0,time_since_landing+dt)
	landing_episode_age = minf(60.0,landing_episode_age+dt)
	# Forward pushes on slow supported snow and opens into tuck at its limit.
	# Tiny corrections and short taps retain tuck, while
	# sustained steering automatically opens the stance without reducing control.
	# Float32 replay inputs must make the same boundary decision as live input.
	var steering_outside_tuck = absf(intent.steer)>tuning.tuck_correction_window+.000001
	if steering_outside_tuck and intent.tuck>0.0:
		tuck_steering_time = minf(1.0,tuck_steering_time+dt)
	else:
		tuck_steering_time = 0.0
	var turning = tuck_steering_time>tuning.tuck_steering_window+.000001
	var tuck_target = clampf(intent.tuck,0.0,1.0)*(1.0-clampf(intent.brake,0.0,1.0))
	if tuning.pole_push_enabled and grounded:
		var push_grade = rad_to_deg(asin(clampf(support_basis().z.y,-1.0,1.0)))
		var push_limit = pole_push.speed_limit(maxf(0.0,push_grade),tuning)
		if push_limit>.001 and not facing_backward:
			tuck_target *= smoothstep(push_limit*.80,push_limit,velocity.slide(n).length())
	if steering_outside_tuck:
		# The grace window retains an existing tuck; it cannot start a new
		# crouch when forward and steering are pressed together.
		tuck_target = 0.0 if turning else minf(tuck_target,effective_tuck)
	var tuck_rate = tuning.tuck_open_response if tuck_target<effective_tuck else tuning.tuck_response
	effective_tuck = lerpf(effective_tuck, tuck_target, 1.0 - exp(-tuck_rate * dt))
	edge_load = 0.0
	lateral_acceleration = 0.0
	requested_lateral_acceleration = 0.0
	balance_pressure = 0.0
	snow_depth = 0.0
	snow_penetration = 0.0
	snow_drag = 0.0
	var steering = signf(intent.steer)*pow(clampf(absf(intent.steer),0,1),tuning.steering_input_exponent)
	carve_blend = tuning.carving_blend(intent.steer,old_speed)*(1.0-rock_contact) if grounded else 0.0
	var carving_strength = tuning.carving_strength*lerpf(1.0,tuning.arcade_carving_ratio,carve_blend)
	var edge_grip = tuning.edge_grip*lerpf(1.0,tuning.arcade_grip_ratio,carve_blend)
	var steer_rate = tuning.steering_sensitivity / (1.0 + old_speed * tuning.high_speed_steering_reduction)
	steer_rate *= lerpf(1.0,tuning.arcade_yaw_ratio,carve_blend)
	# Supported high-speed snow stance improves pressure response through the
	# physical COM/inertia. Small corrections and flight keep their own stance.
	var loaded_depth = 0.0
	for ski in skis:
		if ski.grounded and ski.material_kind==TerrainMaterial.Kind.SNOW: loaded_depth = maxf(loaded_depth,ski.snow_depth)
	snow_control_blend = carve_blend*smoothstep(60.0/3.6,120.0/3.6,old_speed)*smoothstep(0.0,.12,loaded_depth)
	# Read actual support at this tick's start; the air controller owns flight.
	steer_rate *= lerpf(1.0,tuning.rock_steering_ratio,rock_contact if grounded else 0.0)
	turn_demand = -steering*steer_rate
	steering_requested_yaw = turn_demand
	steering_transfer_factor = 1.0; steering_slip_factor = 1.0
	if not grounded or old_speed<=1.5 or absf(intent.steer)<.001: steering_stall_age = 0.0
	if grounded and old_speed>1.5:
		var travel_heading = atan2(velocity.x,velocity.z)
		var heading_slip = wrapf(travel_heading-heading,-PI*.5,PI*.5)
		var skid_weight = smoothstep(deg_to_rad(8.0),deg_to_rad(18.0),absf(heading_slip))*smoothstep(1.5,5.0,old_speed)
		var raw_skid_factor = 1.0-skid_weight if heading_slip*intent.steer>0.0 else 1.0
		steering_stall_age = steering_stall_age+dt if raw_skid_factor<.05 and absf(intent.steer)>.001 else 0.0
		# Ordinary edge regulation is unchanged. A real skid, or a continuously
		# blocked command, releases the old edge restriction instead of waiting
		# indefinitely for travel velocity to align with the immobile skis.
		var skid_release = maxf(smoothstep(deg_to_rad(18.0),deg_to_rad(30.0),absf(heading_slip)),smoothstep(.12,.25,steering_stall_age))
		# Transfer body weight before driving the skis through an edge change.
		# Keep the old supporting edge while pressure moves the COM across the
		# skis. Removing that reaction early topples the still-banked rider.
		if body.roll*intent.steer<0.0:
			var transfer_yaw = lerpf(tuning.turn_transfer_yaw_fraction,tuning.high_speed_transfer_yaw_fraction,smoothstep(60.0/3.6,120.0/3.6,old_speed))
			var carve_transfer = tuning.carving_transfer_yaw(old_speed)
			transfer_yaw = lerpf(transfer_yaw,carve_transfer,carve_blend)
			var release_bank = lerpf(.30,tuning.arcade_transfer_release_bank,carve_blend)
			var finish_bank = lerpf(.03,tuning.arcade_transfer_finish_bank,carve_blend)
			steering_transfer_factor = lerpf(transfer_yaw,1.0,1.0-smoothstep(finish_bank,release_bank,absf(body.roll)))
			# A sliding edge cannot justify waiting for a complete carve transfer.
			# Retain manual ski rotation while actual grip/pressure recover.
			steering_transfer_factor = lerpf(steering_transfer_factor,maxf(steering_transfer_factor,tuning.skid_steering_authority),skid_release)
		# Never veto manual yaw at a skid threshold. The old zero at 18 degrees
		# could lock the skis for seconds while anticipation kept demanding bank.
		# Softly reduce deeper-skid yaw; countersteering stays available. Do not
		# multiply two restrictions into another effective steering lock.
		if heading_slip*intent.steer>0.0:
			steering_slip_factor = lerpf(raw_skid_factor,maxf(raw_skid_factor,tuning.skid_steering_authority),skid_release)
		steer_rate *= lerpf(steering_transfer_factor*steering_slip_factor,minf(steering_transfer_factor,steering_slip_factor),skid_release)
	# Air steering can orient the equipment but cannot steer the centre of mass.
	# Positive intent means travel-right, including switch. With the handling
	# forward=(sin(yaw),0,cos(yaw)), right turns DECREASE yaw.
	steering_applied_yaw = -steering*steer_rate if grounded else 0.0
	if grounded: heading = wrapf(heading + steering_applied_yaw * dt, -PI, PI)
	# Grounded neutral yaw precedes contact/motor evaluation. The existing snow
	# reactions, never an assigned velocity, respond to the new equipment axis.
	var alignment_counted = grounded
	if alignment_counted: landing_assist.step(dt,self,intent,surface)
	edge_angle = lerpf(edge_angle, -intent.steer * deg_to_rad(tuning.maximum_edge_angle), 1.0 - exp(-tuning.edge_response * lerpf(1.0, tuning.tuck_edge_response_ratio, effective_tuck) * dt))
	var takeoff_frame = support_basis()
	# One bounded dissipative correction, while the preceding completed tick
	# still owns real support. Neither contact probe may integrate this again.
	velocity += snow_contact_assist.advance(dt,self,surface,intent.jump or jump_buffer_remaining>0.000001)
	# Release the bank-following cuff restriction for small/neutral intent.
	# Actual edges still follow the loaded, rate-limited physical motors.
	_update_contacts(surface,dt,true,1.0-smoothstep(.10,.25,absf(intent.steer)))
	n = surface_normal
	# Consume before predictive contact/next-height release wins this tick. The
	# cached frame belongs to actual support at its start, not an air grace period.
	var supported_now = grounded and contact_count>0 and normal_load>0.0
	if (intent.jump or jump_buffer_remaining>0.000001) and (supported_at_start or supported_now):
		if supported_now: takeoff_frame = support_basis()
		velocity += takeoff_frame.y*tuning.jump_impulse
		_jump_executed = true
		clear_input_buffer()
		_begin_flight(takeoff_frame,"hop")
	jump_buffer_remaining = maxf(0.0,jump_buffer_remaining-dt)
	if grounded:
		# A real drop beyond leg reach starts flight with incoming momentum.
		# Small height changes are handled by compression, never a root snap.
		var ballistic = position+velocity*dt+gravity_vector*dt*dt
		if ballistic.y-_support_sample(surface,ballistic).height>tuning.leg_extension:
			_begin_flight(support_basis(),"reach")
	if not grounded:
		landing_assist.step(dt,self,intent,surface,alignment_counted)
		air_control.step(dt,self,intent)
	for ski in skis: ski.complete_snow_work(dt,tuning.rider_mass)
	downhill = gravity_vector.slide(n)
	fall_line = downhill.normalized()
	ski_forward = support_basis().z
	var side = n.cross(ski_forward).normalized()
	var forward_speed = velocity.dot(ski_forward)
	var side_speed = velocity.dot(side)
	slip_angle = atan2(side_speed, maxf(absf(forward_speed), 0.01))
	rock_wear_rate = tuning.rock_reserve_drain*rock_contact*smoothstep(.5,3.0,old_speed) if grounded else 0.0
	impacts.step(dt,grounded and normal_load>0.0 and rock_contact==0.0,tuning)
	var rock_exhausted = impacts.abrade(dt,rock_wear_rate)
	# Evaluate exactly once, after jump/departure/contact eligibility and before
	# resistance. Cap eligibility also reads the preceding completed speed;
	# contact dissipation earlier in this tick cannot open high-speed propulsion.
	# The returned force lies entirely in the current support tangent plane.
	var pole_acceleration: Vector3 = pole_push.advance(dt,self,intent,pole_incoming_speed)
	if grounded:
		var normal_speed = velocity.dot(n)
		velocity = velocity.slide(n)
		var edge = absf(edge_angle) / deg_to_rad(tuning.maximum_edge_angle)
		var grip_limit = 0.0
		var grip_limits: Array[float] = []
		var snow_holds: Array[float] = []
		var snow_engagements: Array[float] = []
		requested_lateral_acceleration = -signf(side_speed)*minf(absf(side_speed)*carving_strength,normal_load*edge_grip*lerpf(.42,1.0,edge))
		var balance_grip: float = body.available_lateral(signf(requested_lateral_acceleration),normal_load,tuning)
		balance_grip *= lerpf(1.0,tuning.rock_grip_ratio,rock_contact)
		for ski in skis:
			grip_limits.append(0.0)
			snow_holds.append(0.0)
			snow_engagements.append(0.0)
			if not ski.grounded: continue
			var ski_side: Vector3 = ski.normal.cross(ski.forward).normalized()
			var sideways: float = velocity.dot(ski_side)
			var ski_edge: float = absf(ski.edge_angle)/deg_to_rad(tuning.maximum_edge_angle)
			var ski_grip: float = tuning.edge_grip if ski.material_kind==TerrainMaterial.Kind.ROCK else edge_grip
			var limit: float = ski.normal_acceleration*ski_grip*lerpf(.42,1.0,ski_edge)*lerpf(1.0,tuning.tuck_grip_ratio,effective_tuck)
			if ski.material_kind==TerrainMaterial.Kind.SNOW:
				var pressure: float = clampf(ski.normal_acceleration*contact_count/9.81,0.0,4.0)
				var planing = .20+.70/(1.0+pow(old_speed/12.0,2.0))
				ski.penetration = minf(ski.snow_depth,ski.snow_depth*planing*sqrt(pressure)+ski.compression_m*.35)
				# Embedded ski sides displace snow even with a flat base. This
				# passive resistance is not an edge-balancing force: the old COM
				# cap made 20 cm powder slide exactly like 2 cm packed snow.
				var engagement = smoothstep(.04,.16,ski.snow_depth)*smoothstep(.005,.035,ski.penetration)
				snow_engagements[snow_engagements.size()-1] = engagement
				snow_holds[snow_holds.size()-1] = ski.normal_acceleration*tuning.snow_edge_cutting*engagement*(tuning.edge_grip/1.6)
			if ski.material_kind==TerrainMaterial.Kind.ROCK: limit *= tuning.rock_grip_ratio
			grip_limits[grip_limits.size()-1] = limit
			ski.slip_angle = atan2(sideways,maxf(absf(velocity.dot(ski.forward)),.01))
			grip_limit += limit
		edge_load = clampf(absf(side_speed)*carving_strength/maxf(grip_limit,.01),0.0,1.0)
		# Slip costs speed through snow work; it never drains a health meter.
		var skid_drag = lerpf(tuning.skidding_friction,tuning.rock_skidding_friction,rock_contact) * absf(sin(slip_angle)) * maxf(normal_load, 0.0)
		# Optional equipment-neutral surface contract. Legacy/ideal planes have
		# no loose layer. Planing reduces penetration with speed; load and
		# sideways displacement increase passive snow work, never propulsion.
		if surface.has_method("snow_depth_at"):
			for ski in skis:
				if not ski.grounded or ski.material_kind==TerrainMaterial.Kind.ROCK: continue
				var cutting = .09+2.0*absf(sin(ski.slip_angle))+clampf(intent.brake,0.0,1.0)
				ski.snow_drag = minf(6.0/maxi(contact_count,1),ski.penetration*ski.normal_acceleration*tuning.snow_ploughing*cutting)*smoothstep(0.0,1.0,old_speed)
				snow_drag += ski.snow_drag
				snow_depth += ski.snow_depth/maxi(contact_count,1)
				snow_penetration += ski.penetration/maxi(contact_count,1)
		friction_force = lerpf(tuning.ski_friction*(1.0+edge*edge*.4),tuning.rock_friction,rock_contact)*maxf(normal_load,0.0) + lerpf(tuning.snow_resistance,tuning.rock_resistance,rock_contact) + snow_drag + skid_drag + intent.brake*tuning.braking_deceleration
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
			var ski_carving: float = tuning.carving_strength if ski.material_kind==TerrainMaterial.Kind.ROCK else carving_strength
			ski_carving = lerpf(ski_carving,maxf(ski_carving,tuning.snow_lateral_response*tuning.carving_strength/9.0),snow_engagements[i])
			var demand: float = absf(lateral_before.dot(ski_side))*ski_carving*share
			if ski.material_kind==TerrainMaterial.Kind.ROCK: demand *= tuning.rock_grip_ratio
			# The balance loop receives the resulting acceleration and responds
			# through its normal pressure controller. Snow cannot propel, snap
			# velocity onto a heading, or exert any unsupported lateral force.
			var capacity = minf(grip_limits[i],balance_grip*share)+snow_holds[i]
			var applied: float = minf(minf(demand,capacity),absf(sideways)/dt)
			velocity -= ski_side*signf(sideways)*applied*dt
			ski.grip_n = applied*tuning.rider_mass
			ski.complete_traction(applied,grip_limits[i]+snow_holds[i])
		lateral_acceleration = (velocity-lateral_before).dot(side)/dt
		velocity += n*normal_speed
		# Full gravity and the actual unilateral reaction advance normal motion.
		# Snow friction above operates only in the tangent plane.
		velocity += n*(gravity_vector.dot(n)+normal_load)*dt
		# Static braking can hold on the test slope. Gravity is otherwise the
		# source of downhill acceleration independent of optional pole thrust.
		if not (intent.brake > 0.8 and velocity.length() < 0.2 and downhill.length() < tuning.braking_deceleration):
			velocity += downhill * dt
		gravity_contribution = downhill.dot(velocity.normalized())
		velocity += pole_acceleration*dt
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
		# Only the hard compression stop constrains position. It removes inward
		# momentum and reports a real bottom-out impact through the usual reserve.
		if position.y<next_ground.max_height-tuning.leg_extension:
			var struck: Vector3 = surface.sample(position.x,position.z).normal
			var closing = maxf(0.0,-velocity.dot(struck))
			position.y = next_ground.max_height-tuning.leg_extension
			if closing>0.0: velocity = velocity.slide(struck)
			landing_force = maxf(landing_force,closing)
			var exhausted: bool
			if landing_episode_age<tuning.impact_contact_grace:
				# The compression stop is still part of the landing. Grounded
				# support has already aligned its frame, so retain touchdown fit.
				var tolerance = tuning.landing_tolerance*(1.0+effective_tuck*tuning.landing_absorption)
				exhausted = impacts.landing_hit(closing,0.0,tolerance,landing_episode_fit,"BOTTOM OUT",tuning)
			else:
				exhausted = impacts.hit(closing,tuning.landing_tolerance,"BOTTOM OUT",tuning)
			if exhausted: crash("IMPACT LIMIT / BOTTOM OUT")
	elif position.y <= next_ground.height and velocity.dot(next_ground.normal)<0.0:
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
		var landing_axis = support_basis().z.slide(contact.normal).normalized()
		var bad_alignment = minf(impact,absf(velocity.dot(contact.normal.cross(landing_axis)))*.16)
		var fit = _landing_fit(support_basis(),contact.normal,velocity)
		if landing_episode_age>=tuning.impact_contact_grace:
			landing_episode_age = 0.0
			landing_episode_fit = fit
		else:
			landing_episode_fit = minf(landing_episode_fit,fit)
		if impacts.landing_hit(impact,bad_alignment,tolerance,landing_episode_fit,"HARD LANDING",tuning):
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
			# Spend the unconsumed tick without teleporting to the next height.
			var remaining = dt*(1.0-hi)
			var end = position+velocity*remaining
			var end_ground = _support_sample(surface,end)
			if end.y-end_ground.height>tuning.leg_extension:
				_begin_flight(support_basis(),"landing reach")
			position = end
	_resolve_obstacle(surface,old_position)
	_update_contacts(surface,dt,false)
	# Touchdown/soft recatch can change the support frame after the translation
	# stop was sampled. Close that same hard constraint against the completed
	# ski footprint before body/pose capture; this never extends support reach.
	if grounded:
		var floor_height = -INF
		for ski in skis:
			if ski.grounded: floor_height = maxf(floor_height,ski.height_reference-tuning.leg_extension)
		if position.y<floor_height-.00025:
			var struck: Vector3 = surface.sample(position.x,position.z).normal
			var closing = maxf(0.0,-velocity.dot(struck))
			position.y = floor_height
			if closing>0.0: velocity = velocity.slide(struck)
			landing_force = maxf(landing_force,closing)
			if landing_episode_age<tuning.impact_contact_grace:
				if impacts.landing_hit(closing,0.0,tuning.landing_tolerance*(1.0+effective_tuck*tuning.landing_absorption),landing_episode_fit,"BOTTOM OUT",tuning): crash("IMPACT LIMIT / BOTTOM OUT")
			elif impacts.hit(closing,tuning.landing_tolerance,"BOTTOM OUT",tuning): crash("IMPACT LIMIT / BOTTOM OUT")
			_update_contacts(surface,dt,false)
	for i in range(2):
		var ski = skis[i]
		ski.crush.complete_tick(surface,ski.position,dt,ski.grounded)
		if skis[i].grounded and not previous_support[i]:
			skis[i].landing_speed = maxf(0.0,-old_velocity.dot(skis[i].normal))
	# body.step applies this tick's landing reaction through the actual support
	# footprint, including a single ski. An extra one-ski angular kick here
	# would count that impulse twice and tip an otherwise aligned landing.
	force_acceleration = (velocity-old_velocity)/dt
	body.step(dt,self,intent,force_acceleration)
	if rock_exhausted and not crashed: crash("IMPACT LIMIT / ROCK WEAR")
	# Articulated body tilt and sideways slip cannot cause a fall.
	peak_speed = maxf(peak_speed, velocity.length())
	acceleration = (velocity.length() - old_speed) / dt
	if crashed: landing_assist.reset()
	elif grounded: landing_assist.clear_prediction()
	facing_pose.capture(self)
	motion.capture(self,dt)

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
	if closing>0.0:
		_obstacle_contact = {"normal":normal,"closing_speed_mps":closing,"reason":reason}
	position = hit.position+normal*.02
	if impacts.hit(closing,tuning.obstacle_impact_reference,reason,tuning):
		crash("IMPACT LIMIT / "+reason)
	else:
		# Surviving a hit still stops its inward momentum at the actual contact.
		# Tangential motion may slide along the envelope; no phasing through it.
		if velocity.dot(normal)<0.0: velocity = velocity.slide(normal)

func clear_input_buffer() -> void:
	jump_buffer_remaining = 0.0
	landing_assist.reset()
	pole_push.reset("input cleared")

func _orient_travel_axis() -> bool:
	# Flight owns a full quaternion. Reversing its yaw axis at 90 degrees
	# during a spin/flip would exchange the legs and cancel the rotation.
	if not grounded: return false
	# The ski line has no preferred tip. Rebase only once clearly travelling
	# toward its other end; the band also retains direction at rest/broadside.
	var forward = Vector3(sin(heading),0,cos(heading))
	var motion = Vector3(velocity.x,0,velocity.z)
	if motion.dot(forward)>=-maxf(1.0,motion.length()*.12): return false
	var old_frame = support_basis()
	heading = wrapf(heading+PI,-PI,PI)
	facing_backward = not facing_backward
	edge_angle = -edge_angle
	if flight_initialized:
		flight_frame = old_frame*Basis(Vector3.UP,PI)
		flight_heading = heading
	skis.reverse()
	for i in range(2):
		var ski = skis[i]
		ski.side = -1.0 if i==0 else 1.0
		ski.heading = wrapf(ski.heading+PI,-PI,PI)
		ski.edge_angle = -ski.edge_angle
		ski.orientation *= Basis(Vector3.UP,PI)
	body.load_fractions = Vector2(body.load_fractions.y,body.load_fractions.x)
	# Before the first moving tick this is spawn setup, not a turn impulse.
	return ticks==1 and body.initialized

func crash(reason: String) -> void:
	clear_input_buffer()
	crashed = true
	crash_reason = reason

func speed_kmh() -> float:
	return velocity.length() * 3.6

func _contact_normal(surface,x: float,z: float) -> Vector3:
	if grounded and (skis[0].crush.yielding or skis[1].crush.yielding):
		return (skis[0].crush.sample(surface,x,z).normal+skis[1].crush.sample(surface,x,z).normal).normalized()
	if surface.has_method("contact_normal"):
		return surface.contact_normal(x,z)
	return surface.sample(x,z).normal

func support_basis() -> Basis:
	if not grounded and flight_initialized:
		# Manual rotation and optional help integrate this retained frame once
		# per tick. Remote terrain cannot tilt it through the support sampler.
		return flight_frame
	var n = surface_normal
	var f = Vector3(sin(heading),-(n.x*sin(heading)+n.z*cos(heading))/maxf(n.y,.05),cos(heading)).normalized()
	return Basis(n.cross(f).normalized(),n,f)

func _landing_fit(frame: Basis, normal: Vector3, incoming: Vector3) -> float:
	# Only the physical equipment frame and struck triangle participate.
	# Cosmetic posture, flight height and absolute travel speed add no damage.
	if not frame.is_finite() or frame.determinant()<=.000001 or normal.length_squared()<.000001:
		return 0.0
	var n = normal.normalized()
	var up_dot = frame.y.normalized().dot(n)
	if up_dot<=0.0: return 0.0
	var axis = frame.z.slide(n)
	if axis.length_squared()<.000001: return 0.0
	var tilt = acos(clampf(up_dot,-1.0,1.0))
	var fit = 1.0-smoothstep(tuning.landing_tilt_full,tuning.landing_tilt_none,tilt)
	var travel = incoming.slide(n)
	if travel.length_squared()>=pow(tuning.landing_travel_min_speed,2):
		# Either tip may lead: visual switch/facing cannot change absorption.
		var angle = acos(clampf(absf(axis.normalized().dot(travel.normalized())),0.0,1.0))
		fit *= 1.0-smoothstep(tuning.landing_travel_full,tuning.landing_travel_none,angle)
	return fit

func _begin_flight(frame: Basis, reason: String = "unsupported") -> void:
	snow_contact_assist.reset(reason)
	pole_push.reset(reason)
	carve_blend = 0.0
	snow_control_blend = 0.0
	if grounded or not flight_initialized: air_control.reset()
	if grounded or not flight_initialized: takeoff_reason = reason
	flight_frame = frame
	flight_heading = heading
	flight_initialized = true
	grounded = false
	contact_count = 0
	normal_load = 0.0
	rock_contact = 0.0
	for ski in skis:
		ski.crush.reset()
		ski.grounded = false
		ski.load_n = 0.0
		ski.normal_acceleration = 0.0
		ski.grip_n = 0.0

func _support_sample(surface, root: Vector3) -> Dictionary:
	var sampled_normal = _contact_normal(surface,root.x,root.z)
	var frame = support_basis()
	if grounded:
		# Sample the footprint in the frame that _update_contacts will use at
		# this location. Using the previous normal let cross-slope frame rotation
		# move the hard stop by centimetres beyond the 28 cm geometric limit.
		var f = Vector3(sin(heading),-(sampled_normal.x*sin(heading)+sampled_normal.z*cos(heading))/maxf(sampled_normal.y,.05),cos(heading)).normalized()
		frame = Basis(sampled_normal.cross(f).normalized(),sampled_normal,f)
	var heights: Array[float] = []
	for ski in skis:
		var offset: Vector3 = frame.x*ski.side*tuning.half_stance
		heights.append(ski.crush.height_at(surface,root.x+offset.x,root.z+offset.z)-offset.y)
	var high = maxf(heights[0],heights[1])
	var low = minf(heights[0],heights[1])
	return {"height":(high+low)*.5 if grounded and high-low<=tuning.leg_extension else high,"max_height":high,"normal":sampled_normal}

func _update_contacts(surface, dt: float, advance_motors: bool = true, edge_release: float = 0.0) -> void:
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
			# Active turns keep engagement near the rider's bank. Weak/released
			# intent frees this aggregate restriction so actual boot motors and
			# the constrained leg fit can unwind together.
			var bank: float = body.roll if body.initialized else 0.0
			var edge_goal = clampf(edge_angle,-bank-.10,-bank+.10)
			# A pressure-limited body can counterbank under loose-snow resistance.
			# Do not turn that outward bank into an opposite boot command. Release
			# the restriction continuously over its existing 0.10 rad allowance;
			# the same loaded response and motor rate still advance the real cuffs.
			var counterbank_release = smoothstep(0.0,.10,bank*signf(edge_angle)) if was_grounded else 0.0
			edge_goal = lerpf(edge_goal,edge_angle,maxf(edge_release,counterbank_release))
			var edge_limit = deg_to_rad(tuning.maximum_edge_angle)
			edge_goal = clampf(edge_goal,-edge_limit,edge_limit)
			var edge_response_value = lerpf(ski.edge_angle,edge_goal,1.0-exp(-32.0*dt*(.65+shares[i])))
			# Bound cuff rotation even during a fast reversal or recovery. This
			# applies to the physical contact, not only to its rendered mesh.
			ski.edge_angle = move_toward(ski.edge_angle,edge_response_value,3.0*dt)
		ski.probe(surface,position,frame,velocity,gravity_vector,dt,tuning.half_stance,tuning.support_stiffness,tuning.support_damping,tuning.support_damping_limit,tuning)
		# A momentary suspension unload must not latch full flight until the
		# rider root touches snow. Descending skis can regain a real positive
		# reaction inside existing leg reach, only just after an unloaded edge.
		# Ordinary yaw still carries the rider, but must not turn small steering
		# corrections over ripples into jumps. Deliberate pitch/tricks keep flight.
		var recatch: bool = (not was_grounded and takeoff_reason=="unloaded"
			and airtime<=tuning.support_recatch_time and not air_control.trick_flight and not air_control.tilt_flight
			and ski.normal_speed_ms<=0.0 and ski.normal_speed_ms>=-tuning.support_recatch_speed)
		var touching: bool = (was_grounded or recatch) and ski.clearance_m<=tuning.leg_extension
		var carrying: bool = touching and ski.gross_load>maxf(0.0,tuning.minimum_load)
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
		_begin_flight(frame,"reach" if minf(skis[0].clearance_m,skis[1].clearance_m)>tuning.leg_extension else "unloaded")
	else:
		grounded = contact_count>0
		if grounded and not was_grounded:
			flight_initialized = false
			airtime = 0.0
	contacts_initialized = true
	rock_contact = 0.0
	for ski in skis:
		if ski.grounded and ski.material_kind==TerrainMaterial.Kind.ROCK:
			rock_contact += ski.normal_acceleration/maxf(normal_load,.001)
	rock_contact = clampf(rock_contact,0.0,1.0)
	support_offset_m = position.y-_support_sample(surface,position).height

func prime_contacts(surface) -> void:
	pole_push.reset("primed")
	snow_contact_assist.reset("primed")
	# Explicit initialization used by restart/tools, never called from rendering.
	for ski in skis: ski.clear_snow_response()
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
	facing_pose.capture(self,true)

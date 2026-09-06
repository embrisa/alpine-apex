extends RefCounted
## Test-only steering target. This file is never loaded by the game or generator.
const DT = 1.0/120.0

static func target_x(field,z: float,side: int) -> float:
	if field.GENERATOR_VERSION>=6:
		return field.gully_x(z,side) if z<1850 else field.glade_x(z,side)
	if z<940:
		return field.gully_x(z,side)*smoothstep(480,940,z)
	if z<1850: return field.gully_x(z,side)
	return field.glade_x(z,side)

static func intent(sim,field,side: int,overspeed: bool = false) -> RiderInput:
	var input = RiderInput.new()
	var speed = sim.speed_kmh()
	var lookahead = clampf(sim.velocity.length()*1.25,16,55)
	if field.GENERATOR_VERSION>=6: lookahead = clampf(sim.velocity.length()*3.0,26,65)
	var p: Vector3 = sim.position
	var target = Vector2(target_x(field,p.z+lookahead,side),p.z+lookahead)
	var preferred = atan2(target.x-p.x,lookahead)
	var best = preferred
	var best_cost = INF
	# A short sweep chooses among ordinary heading requests when a boulder is
	# in the way. It does not move the rider or change the terrain/collisions.
	for i in range(-5,6):
		var heading = preferred+i*.09
		var direction = Vector3(sin(heading),0,cos(heading))
		var cost = absf(i)*.8
		var last = p
		for k in range(1,5):
			var next = p+direction*lookahead*k/4.0
			next.y = field.sample(next.x,next.z).height
			for offset in [-2.0,0.0,2.0]:
				var across = Vector3(direction.z,0,-direction.x)*offset
				if not field.sweep_obstacle(last+across,next+across).is_empty(): cost += 45
			last = next
		if cost<best_cost:
			best_cost = cost
			best = heading
	if field.GENERATOR_VERSION>=6:
		best -= clampf(sim.slip_angle*.35,-.25,.25)
	input.steer = clampf(-angle_difference(sim.heading,best)*1.6,-.8,.8)
	var target_speed = 65.0
	if p.z<1050: target_speed = 60.0
	if p.z>1100 and p.z<1600: target_speed = 50.0
	if p.z>1700: target_speed = 45.0
	if field.GENERATOR_VERSION>=6:
		target_speed = 32.0 if p.z<1850 else 25.0
	input.brake = 0.0 if overspeed else clampf((speed-target_speed)/12,0,1)
	if field.GENERATOR_VERSION>=6 and not overspeed:
		input.brake *= 1-smoothstep(.06,.30,absf(input.steer))*.75
	input.tuck = .9 if overspeed else .1
	return input

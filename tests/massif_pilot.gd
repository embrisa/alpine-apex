extends RefCounted
## Test-only survey pilot: ordinary rider input, never imported by game code.
const DT = 1.0/120.0
const VERSION = 3
static func intent(sim,field,face_index: int,side: int = -1) -> RiderInput:
	var face = field.faces[face_index]
	var p: Vector3 = sim.position
	var q: Vector2 = face.to_local(Vector2(p.x,p.z))
	var lookahead = clampf(sim.velocity.length()*1.5,16,32)
	var z = q.y+lookahead
	var x: float = face.gully_x(z,side) if z<1850 else face.glade_x(z,side)
	var target: Vector2 = face.to_world(Vector2(x,z))
	var preferred = atan2(target.x-p.x,target.y-p.z)
	var best = preferred
	var best_cost = INF
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
				if not field.sweep_obstacle(last+across,next+across).is_empty(): cost += 1000
				# Model v14 makes exposed rock a sustained contact hazard. Survey
				# the same material field used by both skis before choosing input.
				if field.has_method("rock_fraction_at"):
					cost += maxf(0,field.rock_fraction_at(next.x+across.x,next.z+across.z)-.30)*24.0
			last = next
		if cost<best_cost:
			best_cost = cost
			best = heading
	best -= clampf(sim.slip_angle*.35,-.25,.25)
	var input = RiderInput.new()
	input.steer = clampf(-angle_difference(sim.heading,best)*1.6,-.8,.8)
	var target_speed = 28.0 if q.y<1850 else 23.0
	# Avoid holding the brakes throughout an unavoidable rock band: lingering
	# there spends the entire contact reserve. Resume the survey pace on snow.
	if field.has_method("rock_fraction_at") and field.rock_fraction_at(p.x,p.z)>.4:
		target_speed=60.0
	input.brake = clampf((sim.speed_kmh()-target_speed)/12,0,1)
	input.tuck = .1
	return input

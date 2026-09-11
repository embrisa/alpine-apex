extends RefCounted
## Ordinary input along a test-survey polyline; never used by the game.
const VERSION = 4
const DT = 1.0/120
const Survey = preload("res://tests/alpine_v13_route_survey.gd")
static func intent(sim,field,face_index: int,path: Array) -> RiderInput:
	var face = field.faces[face_index]
	var p: Vector3 = sim.position
	var q: Vector2 = face.to_local(Vector2(p.x,p.z))
	# Build gliding speed on the clear summit before steering onto the survey.
	# Steering toward its offset first node at rest can keep both skis braking.
	if Vector2(p.x,p.z).length()<120:
		var launch = RiderInput.new()
		launch.tuck = .35
		return launch
	var lookahead = clampf(sim.velocity.length()*1.3,12,30)
	var nearest = INF
	var segment = 0
	var along = 0.0
	for i in range(1,path.size()):
		var a = Vector2(path[i-1][0],path[i-1][1])
		var b = Vector2(path[i][0],path[i][1])
		var t = clampf((q-a).dot(b-a)/maxf((b-a).length_squared(),.001),0,1)
		var distance_m = q.distance_squared_to(a.lerp(b,t))
		if distance_m<nearest:
			nearest = distance_m; segment = i; along = t
	var local_target = Vector2(path[-1][0],path[-1][1])
	var remaining = lookahead
	for i in range(maxi(1,segment),path.size()):
		var a = Vector2(path[i-1][0],path[i-1][1])
		var b = Vector2(path[i][0],path[i][1])
		if i==segment: a = a.lerp(b,along)
		var length_m = a.distance_to(b)
		if remaining<=length_m:
			local_target = a.lerp(b,remaining/maxf(length_m,.001)); break
		remaining -= length_m
	if q.y>path[-1][1]: local_target = q+Vector2(0,lookahead)
	var target: Vector2 = face.to_world(local_target)
	var preferred = atan2(target.x-p.x,target.y-p.z)
	# Continue through the runout instead of steering back toward the finite
	# survey endpoint. This is ordinary input, not a position/velocity correction.
	if Vector2(p.x,p.z).length()>2700: preferred=atan2(p.x,p.z)
	var normal: Vector3 = field.contact_normal(p.x,p.z)
	var fall_line = atan2(normal.x,normal.z)
	var best = preferred
	var best_cost = INF
	for i in range(-10,11):
		var heading = fall_line+i*.13
		var direction = Vector2(sin(heading),cos(heading))
		var cost = absf(angle_difference(preferred,heading))*3.0+absf(i)*.06
		cost += absf(angle_difference(sim.heading,heading))*.5
		var previous_height = p.y
		for k in range(1,5):
			var at = Vector2(p.x,p.z)+direction*lookahead*k/4.0
			var h: float = field.sample(at.x,at.y).height
			cost += maxf(0,h-previous_height+.25)*8
			var grade = (previous_height-h)/(lookahead/4.0)
			cost += maxf(0,grade-.95)*18
			cost += maxf(0,.72-field.contact_normal(at.x,at.y).y)*25
			cost += maxf(0,field.rock_fraction_at(at.x,at.y)-.25)*10
			if not Survey.clear_at(field,at,Survey.EDGE_CLEARANCE): cost += 200
			previous_height = h
		if cost<best_cost:
			best_cost = cost
			best = heading
	best -= clampf(sim.slip_angle*.30,-.20,.20)
	var input = RiderInput.new()
	input.steer = clampf(-angle_difference(sim.heading,best)*2.2,-1.0,1.0)
	var target_kmh=clampf(40.0-absf(angle_difference(sim.heading,preferred))*16.0,23.0,40.0)
	input.brake = clampf((sim.speed_kmh()-target_kmh)/10,0,1)
	input.tuck = .10
	if sim.speed_kmh()<3 and Vector2(p.x,p.z).length()>180:
		input.steer=clampf(-angle_difference(sim.heading,fall_line)*2.2,-1.0,1.0)
		input.tuck=1.0
		input.brake=0.0
		input.jump=sim.ticks%240==0
	return input

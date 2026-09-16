extends RefCounted
const Obstacles = preload("res://scripts/world/obstacle_access.gd")
## Bounded read-only presentation survey of the existing 4 m surface and cylinders.
const INTERVAL = 0.1
const MAX_HEIGHT_SAMPLES = 24
const MAX_OBSTACLES = 128
const REQUIRED = {"terrain_steep":1.0,"terrain_cliff":0.3,"terrain_tight":0.3,"terrain_open":3.0}
var elapsed: float = 0.0
var previous = Vector3.ZERO
var initialized: bool = false
var passed: Dictionary = {}
var duration: Dictionary = {}
var outside: Dictionary = {}
var armed: Dictionary = {}
var was_constrained: bool = false
var candidates: Array[String] = []
var near_passes: Array[Dictionary] = []
var height_samples: int = 0
var obstacle_checks: int = 0
var limited: bool = false
var collision_since_sample: bool = false
var last_update_us: int = 0
var max_update_us: int = 0

## Height-only terrain reads use the allocation-free exact query when the
## surface offers one; laboratory stubs with only sample() keep working.
var height_surface = null
var height_direct: bool = false

func _height(surface, x: float, z: float) -> float:
	if surface!=height_surface:
		height_surface = surface
		height_direct = surface!=null and surface.has_method("sample_height")
	return surface.sample_height(x,z) if height_direct else surface.sample(x,z).height
var total_update_us: int = 0
var update_count: int = 0

func reset() -> void:
	near_passes.clear()
	elapsed = 0.0
	initialized = false
	passed.clear()
	duration.clear()
	outside.clear()
	armed.clear()
	was_constrained = false
	collision_since_sample = false
	candidates.clear()

func sample(sim, field, dt: float) -> Array[String]:
	candidates.clear()
	near_passes.clear()
	if field == null or sim.crashed: return candidates
	if not initialized:
		previous = sim.position
		initialized = true
	if not sim.obstacle_contact.is_empty(): collision_since_sample = true
	elapsed += dt
	if elapsed < INTERVAL-0.000001: return candidates
	var used = elapsed
	elapsed = 0.0
	var start = Time.get_ticks_usec()
	height_samples = 0
	obstacle_checks = 0
	limited = false
	var position: Vector3 = sim.position
	var speed: float = sim.velocity.length()
	if previous.distance_to(position) > maxf(30.0,speed*0.3):
		reset() # Teleport or discontinuity must never sound like a close pass.
		return candidates
	_survey(sim,field,used)
	previous = position
	collision_since_sample = false
	last_update_us = Time.get_ticks_usec()-start
	max_update_us = maxi(max_update_us,last_update_us)
	total_update_us += last_update_us
	update_count += 1
	return candidates

func _survey(sim, field, dt: float) -> void:
	if not ("obstacles" in field and "obstacle_grid" in field) or not field.has_method("ski_bounds"):
		return
	var p: Vector3 = sim.position
	var p2 = Vector2(p.x,p.z)
	var a = Vector2(previous.x,previous.z)
	var travel = Vector2(sim.velocity.x,sim.velocity.z)
	var speed: float = sim.velocity.length()
	if travel.length_squared() < 1.0: return
	var forward = travel.normalized()
	var right = Vector2(-forward.y,forward.x)
	var ahead = p2+forward*32.0
	var region = Rect2(a,Vector2.ZERO).expand(p2).expand(ahead).grow(8.0)
	var bounds: Rect2 = field.ski_bounds()
	var heights: Array[float] = []
	var certain = true
	for i in 9:
		var at = p2+forward*float(i*4)
		if not bounds.has_point(at):
			certain = false
			break
		height_samples += 1
		heights.append(_height(field,at.x,at.y))
	var normal: Vector3 = sim.surface_normal
	var cliff = false
	if certain and normal.y > 0.1:
		for i in range(1,5):
			var tangent = heights[0]-(normal.x*forward.x+normal.z*forward.y)*float(i*4)/normal.y
			if tangent-heights[i] >= 8.0: cliff = true
	var checked: Dictionary = {}
	var near_candidates: Array = []
	var left = INF
	var right_clear = INF
	var open = true
	var center2d = region.get_center()
	var query_center = Vector3(center2d.x,p.y,center2d.y)
	for id in field.nearby_obstacle_indices(query_center,region.size.length()*.5+4.0):
		if checked.has(id): continue
		if obstacle_checks >= MAX_OBSTACLES:
			limited = true
			break
		checked[id] = true
		obstacle_checks += 1
		var ob: Dictionary = Obstacles.record(field,id)
		var center: Vector3 = ob.position
		var center2 = Vector2(center.x,center.z)
		var radius: float = float(ob.radius)+0.35
		var delta = p2-a
		var fraction = clampf((center2-a).dot(delta)/maxf(delta.length_squared(),0.000001),0,1)
		var closest = a.lerp(p2,fraction)
		var gap = closest.distance_to(center2)-radius
		var height = lerpf(previous.y,p.y,fraction)
		var overlapping: bool = height < center.y+float(ob.height) and height+1.6 > center.y
		if speed >= 15.0 and gap > 0.0 and gap <= 1.0 and overlapping and not collision_since_sample and not passed.has(id) and (p2-center2).dot(forward)>0.0:
			near_candidates.append({"id":id,"position":center,"gap_m":gap,"reason":"TREE" if ob.get("tree",false) else "ROCK"})
		var offset = center2-p2
		var along = offset.dot(forward)
		var lateral = offset.dot(right)
		if certain and along >= 0.0 and along <= 30.0:
			var at = clampf(along/4.0,0,7.999)
			var ground = lerpf(heights[int(at)],heights[int(at)+1],fmod(at,1.0))
			if center.y >= ground+1.6 or center.y+float(ob.height) <= ground: continue
			if absf(lateral)-radius < 6.0: open = false
			if along <= 24.0:
				if lateral < 0.0: left = minf(left,-lateral-radius)
				else: right_clear = minf(right_clear,lateral-radius)
	# A truncated query cannot establish an empty corridor or a clean passage.
	if not limited and not near_candidates.is_empty():
		candidates.append("nearmiss")
		for entry in near_candidates:
			passed[entry.id] = entry.position
			near_passes.append(entry)
	for id in passed.keys():
		if p.distance_to(passed[id]) > 40.0: passed.erase(id)
	if limited or not certain:
		duration.clear()
		return
	var slope: float = rad_to_deg(acos(clampf(normal.y,-1.0,1.0)))
	var steep: bool = sim.grounded and (slope >= 45.0 or (float(duration.get("terrain_steep",0.0))>0 and slope>=35.0))
	var tight: bool = is_finite(left) and is_finite(right_clear) and left>0 and right_clear>0 and left+right_clear>=1.5 and left+right_clear<=6.0
	var constrained: bool = steep or cliff or tight
	if constrained: was_constrained = true
	var eligible: bool = sim.grounded and speed >= 10.0
	_condition("terrain_steep",steep and eligible,dt)
	_condition("terrain_cliff",cliff and eligible,dt)
	_condition("terrain_tight",tight and eligible,dt)
	_condition("terrain_open",was_constrained and not constrained and open and eligible,dt)
	if "terrain_open" in candidates: was_constrained = false

func _condition(event: String, active: bool, dt: float) -> void:
	if active:
		outside[event] = 0.0
		duration[event] = float(duration.get(event,0.0))+dt
		if bool(armed.get(event,true)) and float(duration[event]) >= float(REQUIRED[event])-0.000001:
			armed[event] = false
			candidates.append(event)
	else:
		duration[event] = 0.0
		outside[event] = float(outside.get(event,0.0))+dt
		if float(outside[event]) >= 5.0: armed[event] = true

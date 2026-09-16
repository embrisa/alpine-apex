extends RefCounted
## Audio-only swept capsules over final render poses. No collision Nodes/queries,
## pose writes, solver state or random state. Four equipment owners, six pairs.
const Events = preload("res://scripts/presentation/riding_audio_events.gd")
const Attachment = preload("res://scripts/presentation/skier_equipment.gd")
enum Surface { CARBON, METAL, COMPOSITE }
const MAX_PROXIES = 12
const MAX_SWEEP_STEPS = 24
const SEPARATION_M = .02
const REARM_SECONDS = .08
var previous: Array[Dictionary] = []
var cross_owner_pairs = PackedInt32Array()
var previous_anchor = Vector3.ZERO
var touching: Dictionary = {}
var clock = 0.0
var last_mode = ""
var max_update_us = 0
var sweep_exhausted = 0
var event_count = 0
var reset_serial = 0

func reset() -> void:
	reset_serial += 1
	previous.clear()
	cross_owner_pairs.clear()
	touching.clear()
	clock = 0.0
	last_mode = ""

static func proxy(owner: int, a: Vector3, b: Vector3, radius: float, surface: int) -> Dictionary:
	return {"owner":owner,"a":a,"b":b,"radius":radius,"surface":surface}

static func snapshot(visual) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not is_instance_valid(visual) or visual.poles.size()!=2 or visual.skis.size()!=2: return result
	for i in 2:
		var p: Transform3D = visual.poles[i].global_transform
		result.append(proxy(i,p*Vector3(0,-.14,0),p*Vector3(0,-1.10,0),.009,Surface.CARBON))
		result.append(proxy(i,p*Vector3(0,-1.10,0),p*Vector3(0,-1.18,0),.009,Surface.METAL))
		var s: Transform3D = visual.skis[i].global_transform
		# Narrow edge capsules and the composite topsheet follow the exported ski.
		for side in [-1.0,1.0]:
			result.append(proxy(i+2,s*Vector3(side*.055,0,-.96),s*Vector3(side*.055,0,1.05),.009,Surface.METAL))
		result.append(proxy(i+2,s*Vector3(0,.008,-.94),s*Vector3(0,.008,1.02),.045,Surface.COMPOSITE))
		var binding = s.translated_local(Attachment.BINDING_ORIGIN)
		result.append(proxy(i+2,binding*Vector3(0,.04,-.15),binding*Vector3(0,.04,.15),.055,Surface.METAL))
	return result

func sample(proxies: Array[Dictionary], anchor: Vector3, dt: float, mode: String, listener: Transform3D = Transform3D.IDENTITY) -> Array[Dictionary]:
	var started = Time.get_ticks_usec()
	var events: Array[Dictionary] = []
	if not is_finite(dt) or dt<=0.0: return events
	if mode.is_empty() or proxies.is_empty() or proxies.size()>MAX_PROXIES or not anchor.is_finite():
		reset()
		return events
	# Remove whole-skier translation before sweeping: downhill speed alone must
	# not turn a quiet fixed equipment pose into a contact or a costly sweep.
	var current: Array[Dictionary] = []
	for p in proxies:
		if not p.a.is_finite() or not p.b.is_finite() or not is_finite(p.radius) or p.radius<=0:
			reset()
			return events
		current.append(proxy(p.owner,p.a-anchor,p.b-anchor,p.radius,p.surface))
	var initialize = previous.size()!=current.size() or mode!=last_mode or dt>.10 or anchor.distance_to(previous_anchor)>30
	if not initialize:
		for i in current.size():
			if current[i].owner!=previous[i].owner or current[i].surface!=previous[i].surface or current[i].a.distance_to(previous[i].a)>3 or current[i].b.distance_to(previous[i].b)>3:
				initialize = true
				break
	if initialize:
		reset()
		# Ownership is unchanged between resets (validated above). Cache only the
		# pair topology; current and swept geometry is still tested every frame.
		for i in current.size():
			for j in range(i+1,current.size()):
				if current[i].owner!=current[j].owner:
					cross_owner_pairs.append(i); cross_owner_pairs.append(j)
	clock += dt
	# Each linearly swept endpoint stays inside this union. Expanded boxes
	# conservatively include capsule radii and the contact rearm margin, so
	# separated pairs cannot touch at either endpoint or between frames.
	var swept_bounds: Array[AABB] = []
	for i in current.size():
		var a: Dictionary = current[i]
		var bounds = AABB(a.a,Vector3.ZERO).expand(a.b)
		if not initialize: bounds = bounds.expand(previous[i].a).expand(previous[i].b)
		swept_bounds.append(bounds.grow(a.radius+SEPARATION_M))
	var near: Dictionary = {}
	var candidates: Dictionary = {}
	for pair_index in range(0,cross_owner_pairs.size(),2):
		var i = cross_owner_pairs[pair_index]
		var j = cross_owner_pairs[pair_index+1]
		if not swept_bounds[i].intersects(swept_bounds[j]): continue
		var a: Dictionary = current[i]
		var b: Dictionary = current[j]
		var key: int = mini(a.owner,b.owner)*4+maxi(a.owner,b.owner)
		var pair = Geometry3D.get_closest_points_between_segments(a.a,a.b,b.a,b.b)
		var gap: float = pair[0].distance_to(pair[1])-a.radius-b.radius
		if gap<=.0002 or (touching.has(key) and gap<=SEPARATION_M): near[key] = true
		if initialize or touching.has(key): continue
		var hit = _sweep(previous[i],a,previous[j],b,dt)
		if hit.is_empty(): continue
		near[key] = true
		if hit.speed<.12: continue
		var profile = Events.EquipmentProfile.MIXED_KNOCK
		if a.surface==Surface.CARBON and b.surface==Surface.CARBON: profile = Events.EquipmentProfile.SHAFT_TICK
		elif a.surface==Surface.METAL and b.surface==Surface.METAL: profile = Events.EquipmentProfile.METAL_CLINK
		elif a.surface==Surface.CARBON or b.surface==Surface.CARBON: profile = Events.EquipmentProfile.SHAFT_TICK
		var world_position: Vector3 = hit.position+previous_anchor.lerp(anchor,hit.fraction)
		var direction = (world_position-listener.origin).normalized()
		var event = Events._equipment(profile,minf(hit.speed,35),clampf(direction.dot(listener.basis.x),-1,1),clampf(hit.speed/12,0,1))
		if not candidates.has(key) or event.speed>candidates[key].speed: candidates[key] = event
	for key in near: touching[key] = clock
	for key in touching.keys():
		if not near.has(key) and clock-touching[key]>=REARM_SECONDS: touching.erase(key)
	# The controller coalesces these with same-jolt telemetry rattles.
	for key in candidates: events.append(candidates[key])
	event_count += events.size()
	previous = current
	previous_anchor = anchor
	last_mode = mode
	max_update_us = maxi(max_update_us,Time.get_ticks_usec()-started)
	return events

func _sweep(old_a: Dictionary, a: Dictionary, old_b: Dictionary, b: Dictionary, dt: float) -> Dictionary:
	var da0: Vector3 = a.a-old_a.a
	var da1: Vector3 = a.b-old_a.b
	var db0: Vector3 = b.a-old_b.a
	var db1: Vector3 = b.b-old_b.b
	var bound = maxf(maxf((da0-db0).length(),(da0-db1).length()),maxf((da1-db0).length(),(da1-db1).length()))
	if bound<.00001: return {}
	var fraction = 0.0
	for step in MAX_SWEEP_STEPS:
		var a0: Vector3 = old_a.a+da0*fraction
		var a1: Vector3 = old_a.b+da1*fraction
		var b0: Vector3 = old_b.a+db0*fraction
		var b1: Vector3 = old_b.b+db1*fraction
		var closest = Geometry3D.get_closest_points_between_segments(a0,a1,b0,b1)
		var distance = closest[0].distance_to(closest[1])
		var gap: float = distance-a.radius-b.radius
		if gap<=.0002:
			var sa = clampf((closest[0]-a0).dot(a1-a0)/maxf((a1-a0).length_squared(),.000001),0,1)
			var sb = clampf((closest[1]-b0).dot(b1-b0)/maxf((b1-b0).length_squared(),.000001),0,1)
			var relative = (da0.lerp(da1,sa)-db0.lerp(db1,sb))/dt
			var normal = (closest[0]-closest[1])/maxf(distance,.000001)
			return {"speed":maxf(0,-relative.dot(normal)),"position":closest[0].lerp(closest[1],.5),"fraction":fraction}
		# Conservative advancement cannot skip thin contact even at low FPS.
		fraction += maxf((gap-.0001)/bound,.000001)
		if fraction>1: return {}
	sweep_exhausted += 1
	return {}

extends RefCounted
## Temporary plastic yield at one moving ski, in normal metres. The incoming
## contact plane is retained only while snow rises through it; it never pulls
## the skier toward terrain. All samples are bounded by the unchanged surface
## and its loose depth. No map edits, spring energy, drag or velocity writes.
const TerrainMaterial = preload("res://scripts/core/terrain_material.gd")
var initialized = false
var enabled = false
var origin = Vector3.ZERO
var normal = Vector3.UP
var strength = 0.0
var maximum_m = 0.0
var amount_m = 0.0
var rate_m_s = 0.0
var vertical_m = 0.0
var yielding = false
var travel_m = 0.0
var last_point = Vector3.ZERO
var release_distance_m = 24.0

func reset() -> void:
	initialized = false
	enabled = false
	strength = 0.0
	maximum_m = 0.0
	origin = Vector3.ZERO
	normal = Vector3.UP
	amount_m = 0.0
	rate_m_s = 0.0
	vertical_m = 0.0
	yielding = false
	travel_m = 0.0
	last_point = Vector3.ZERO
	release_distance_m = 24.0

func begin_tick(surface, point: Vector3, speed: Vector3, supported: bool, tuning) -> void:
	# Only the fixed-step owner advances this history. Queries below are pure.
	if not supported or not surface.has_method("snow_depth_at"):
		reset()
		return
	strength = smoothstep(tuning.snow_crush_start_kmh/3.6,tuning.snow_crush_full_kmh/3.6,speed.length())
	maximum_m = maxf(0.0,tuning.snow_crush_max_m)
	enabled = strength>0.0 and maximum_m>0.0
	if not enabled:
		reset()
		return
	if TerrainMaterial.at(surface,point.x,point.z)==TerrainMaterial.Kind.ROCK:
		reset()
		return
	var raw: Dictionary = surface.sample(point.x,point.z)
	if not initialized:
		origin = Vector3(point.x,raw.height,point.z)
		normal = raw.normal
		initialized = true
		last_point = point
	if yielding: travel_m += Vector2(point.x-last_point.x,point.z-last_point.z).length()
	last_point = point
	# The entry test certifies a local bank, not an indefinitely extended plane.
	# Fade its final metres so small triangle fitting errors cannot accumulate
	# into burial far beyond the bank, including while turning across it.
	if yielding and travel_m>=release_distance_m:
		origin = Vector3(point.x,raw.height,point.z)
		normal = raw.normal
		yielding = false
		travel_m = 0.0
		return
	# Rebase after leaving the pile. A short forward probe also protects the
	# incoming plane from the existing normal filter seeing a bank early.
	var direction = Vector3(speed.x,0.0,speed.z).normalized()
	var ahead = point+direction*2.0
	var rise = raw.height-plane_height(point.x,point.z)
	var next_rise: float = surface.sample(ahead.x,ahead.z).height-plane_height(ahead.x,ahead.z)
	# At a triangle edge the height can already be zero while its outgoing
	# slope still belongs to the bank. Adopting that slope creates a fictitious
	# rising layer on the clear snow beyond a diagonal bank.
	var clear_plane: bool = rise<=.0001 and next_rise<=.0001 and raw.normal.dot(normal)>.99999
	if clear_plane and yielding and surface.has_method("contact_normal"):
		# The distributed normal still sees two metres behind the ski. Keep
		# the yielded plane until that stencil clears too; otherwise the bank's
		# trailing normal gives downhill force without a corresponding descent.
		clear_plane = surface.contact_normal(point.x,point.z).dot(normal)>.99999
	if rise<-.002 or clear_plane:
		origin = Vector3(point.x,raw.height,point.z)
		normal = raw.normal
		yielding = false
		travel_m = 0.0
	elif yielding or minor_bank_ahead(surface,point,direction):
		if not yielding: travel_m = 0.0
		yielding = true
	else:
		# A sustained slope change is terrain, not a loose bank. Do not hold
		# an old plane into the mountain's broad concavities or real takeoffs.
		origin = Vector3(point.x,raw.height,point.z)
		normal = raw.normal
		yielding = false
	strength *= 1.0-smoothstep(maxf(4.0,release_distance_m-4.0),release_distance_m,travel_m)

func minor_bank_ahead(surface, point: Vector3, direction: Vector3) -> bool:
	var peak = 0.0
	var last_rise = 0.0
	# A bank must return to the incoming slope within this bounded footprint.
	# Samples are from the same 4 m triangles; no generator tags or visual mask.
	for distance in [0.0,4.0,8.0,12.0,16.0,20.0,24.0]:
		var p = point+direction*distance
		last_rise = surface.sample(p.x,p.z).height-plane_height(p.x,p.z)
		if last_rise>maximum_m+.005 or last_rise<-.04: return false
		peak = maxf(peak,last_rise)
		# Stop at the first clear trough. A second separate bank must not
		# invalidate this one just because it falls at the far probe endpoint.
		if distance>=4.0 and peak>.002 and absf(last_rise)<.02 and last_rise<peak*.2:
			release_distance_m = minf(24.0,distance+4.0)
			return true
	return false

func plane_height(x: float, z: float) -> float:
	return origin.y-((x-origin.x)*normal.x+(z-origin.z)*normal.z)/maxf(normal.y,.05)

func height_at(surface, x: float, z: float) -> float:
	var height: float = surface.sample(x,z).height
	return height-compression_at(surface,x,z,height)/maxf(normal.y,.05)

func compression_at(surface, x: float, z: float, height: float) -> float:
	if not enabled or not yielding or TerrainMaterial.at(surface,x,z)==TerrainMaterial.Kind.ROCK: return 0.0
	var capacity = minf(maxf(0.0,surface.snow_depth_at(x,z)),maximum_m*normal.y)
	return minf(maxf(0.0,height-plane_height(x,z))*normal.y,capacity)*strength

func contact_normal_at(surface, x: float, z: float) -> Vector3:
	if enabled and yielding: return sample(surface,x,z).normal
	return surface.contact_normal(x,z) if surface.has_method("contact_normal") else surface.sample(x,z).normal

func sample(surface, x: float, z: float) -> Dictionary:
	var raw: Dictionary = surface.sample(x,z)
	var support_normal: Vector3 = surface.contact_normal(x,z) if surface.has_method("contact_normal") else raw.normal
	var result = {"height":raw.height,"normal":support_normal,"crush_m":0.0,"crush_vertical_m":0.0}
	if not enabled or not yielding or TerrainMaterial.at(surface,x,z)==TerrainMaterial.Kind.ROCK: return result
	var depth: float = maxf(0.0,surface.snow_depth_at(x,z))
	var capacity = minf(depth,maximum_m*normal.y)
	if capacity<=0.0: return result
	var rise: float = raw.height-plane_height(x,z)
	var demand = maxf(0.0,rise)*normal.y
	var crushed = minf(demand,capacity)*strength
	result.crush_m = crushed
	result.crush_vertical_m = crushed/maxf(normal.y,.05)
	result.height -= result.crush_vertical_m
	# Inside the yielding layer the incoming plane supplies contact direction.
	# At the depth stop the actual terrain carries load again. Before that stop
	# the yielded height is a plane: blending in the bank normal early would
	# inject a spurious uphill reaction even though the contact is still flat.
	var weight = float(demand<=capacity+.000001 and rise>=-.0001)*strength
	result.normal = support_normal.lerp(normal,weight).normalized()
	return result

func complete_tick(surface, point: Vector3, dt: float, supported: bool) -> void:
	if not supported:
		reset()
		return
	var next = compression_at(surface,point.x,point.z,surface.sample(point.x,point.z).height) if enabled and yielding else 0.0
	rate_m_s = maxf(0.0,next-amount_m)/maxf(dt,.0001)
	amount_m = next
	vertical_m = next/maxf(normal.y,.05)

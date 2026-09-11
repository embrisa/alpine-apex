extends RefCounted
const AlpineBiomes = preload("res://scripts/world/mountain_data.gd")
## Presentation-only shared ridge network; no physical RNG or image writes.
const VERSION = 3
const OUTER_RADIUS_M = 18000.0
const RING_RADII = [9000.0,13200.0,OUTER_RADIUS_M]
const SECTORS = 8
const EDGE_SEGMENTS = 1024
const COLLAR_M = 192.0
const BIN_M = 4096.0
var seed_value: int
var origin = Vector2.ZERO
var apron_center = Vector2.ZERO
var apron_half: float = 4096.0
var physical_bounds: Rect2
var valley_height: float
var snowline: float
var ridges: Array[Dictionary] = []
var ridge_bins: Dictionary = {}
var noise = FastNoiseLite.new()
var detail = FastNoiseLite.new()
var mountain
var height_cache: Dictionary = {}
var sample_cache: Dictionary = {}

func configure(source, field) -> void:
	mountain = source
	seed_value = (source.seed_value ^ 0x57A1D39) & 0x7fffffff
	origin = source.ORIGIN
	apron_half = source.EXTENT*0.5
	apron_center = origin+Vector2.ONE*apron_half
	physical_bounds = field.bounds()
	ridges.clear(); ridge_bins.clear(); clear_cache()
	noise.seed = seed_value; noise.frequency = 0.00036; noise.fractal_octaves = 3
	detail.seed = seed_value+371; detail.frequency = 0.0014; detail.fractal_octaves = 2
	var foot: float = field.sample(0,2850).height
	valley_height = foot-900.0
	snowline = foot+950.0
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_value
	for band in 3:
		var count: int = [5,6,7][band]
		var phase = rng.randf_range(-PI,PI)
		for i in count:
			var angle = phase+TAU*(float(i)+rng.randf_range(-0.22,0.22))/count
			var radial = Vector2.from_angle(angle)
			var axis = radial.rotated(rng.randf_range(0.65,1.7))
			var center = apron_center+radial*([6600.0,11700.0,16000.0][band]+rng.randf_range(-650,650))
			var length_m = rng.randf_range(1900,3000)
			var width = rng.randf_range(1050,1650)
			var summit = rng.randf_range(2300,3100)+band*430.0
			var bend = center+radial*rng.randf_range(-400,500)
			_add_ridge(center-axis*length_m,bend,summit*.66,summit,width,rng.randf_range(-PI,PI))
			_add_ridge(bend,center+axis*length_m,summit,summit*rng.randf_range(.58,.86),width*.85,rng.randf_range(-PI,PI))
			_add_ridge(bend,center-radial*rng.randf_range(1900,3300),summit*.86,summit*.20,width*.62,rng.randf_range(-PI,PI))

func _add_ridge(a: Vector2,b: Vector2,ha: float,hb: float,width: float,phase: float) -> void:
	var id = ridges.size()
	ridges.append({"a":a,"delta":b-a,"length_squared":a.distance_squared_to(b),"ha":ha,"hb":hb,"width":width,"phase":phase})
	var margin = Vector2.ONE*width*2.8
	var lo = ((a.min(b)-margin)/BIN_M).floor(); var hi = ((a.max(b)+margin)/BIN_M).floor()
	for z in range(int(lo.y),int(hi.y)+1):
		for x in range(int(lo.x),int(hi.x)+1):
			var key = Vector2i(x,z)
			if not ridge_bins.has(key): ridge_bins[key] = []
			ridge_bins[key].append(id)

func clear_cache() -> void:
	height_cache.clear(); sample_cache.clear()

func edge_point(index: int) -> Vector2:
	var i = posmod(index,EDGE_SEGMENTS)
	var t = float(i%256)*32.0
	match i/256:
		0: return origin+Vector2(t,0)
		1: return origin+Vector2(apron_half*2,t)
		2: return origin+Vector2(apron_half*2-t,apron_half*2)
		_: return origin+Vector2(0,apron_half*2-t)

func ring_point(index: int, band: int, fraction: float) -> Vector2:
	var edge = edge_point(index)
	var direction = (edge-apron_center).normalized()
	var inner = edge if band==0 else apron_center+direction*RING_RADII[band-1]
	return inner.lerp(apron_center+direction*RING_RADII[band],fraction)

func blend_at(p: Vector2) -> float:
	var distance_m = p.distance_to(p.clamp(physical_bounds.position,physical_bounds.end))
	var end_m = 760.0+noise.get_noise_2d(p.x+740,p.y-320)*220.0
	return smoothstep(COLLAR_M,end_m,distance_m)

func height_at(p: Vector2) -> float:
	var key = Vector2i((p*1000.0).round())
	if height_cache.has(key): return height_cache[key]
	var h = _height_uncached(Vector2(key)/1000.0)
	height_cache[key] = h
	return h

func _height_uncached(p: Vector2) -> float:
	# Geometry needs a broad shoulder; compressing a kilometre of drop into the
	# material transition would turn the protected collar into a square cliff.
	var distance_m = p.distance_to(p.clamp(physical_bounds.position,physical_bounds.end))
	var blend = smoothstep(COLLAR_M,1700.0+noise.get_noise_2d(p.x+740,p.y-320)*600.0,distance_m)
	if blend<=0.0: return mountain.sample_height(p)
	var broad = noise.get_noise_2d(p.x,p.y)
	var relief = 0.0
	for id in ridge_bins.get(Vector2i((p/BIN_M).floor()),[]):
		var ridge: Dictionary = ridges[id]
		var t = clampf((p-ridge.a).dot(ridge.delta)/ridge.length_squared,0,1)
		var ridge_distance: float = p.distance_to(ridge.a+ridge.delta*t)/ridge.width
		if ridge_distance>2.8: continue
		var crest = lerpf(ridge.ha,ridge.hb,t)*(0.90+0.10*cos(t*TAU*1.7+ridge.phase))
		var h = crest*exp(-pow(ridge_distance,1.35))
		var smoothing = maxf(0,160.0-absf(relief-h))
		relief = maxf(relief,h)+smoothing*smoothing/640.0
	var cuts = absf(detail.get_noise_2d(p.x+1200,p.y-870))
	var h = valley_height+broad*180.0+relief*(.94+broad*.10)-cuts*230.0*smoothstep(250,1100,relief)
	return lerpf(mountain.sample_height(p),h,blend) if blend<1.0 else h

func normal_at(p: Vector2) -> Vector3:
	return sample_at(p).normal

func sample_at(p: Vector2) -> Dictionary:
	var key = Vector2i((p*1000.0).round())
	if sample_cache.has(key): return sample_cache[key]
	p = Vector2(key)/1000.0
	var h = height_at(p)
	var west = height_at(p-Vector2(32,0)); var east = height_at(p+Vector2(32,0))
	var north = height_at(p-Vector2(0,32)); var south = height_at(p+Vector2(0,32))
	var n = Vector3(west-east,64,north-south).normalized()
	var hollow = clampf(((west+east+north+south)*.25-h)/12.0,-1,1)
	var variation = noise.get_noise_2d(p.x-415,p.y+710)
	var exposure = clampf(.5+n.dot(Vector3(.7,0,-.7))*.5,0,1)
	var snow = AlpineBiomes.snow_coverage(n,hollow,exposure,detail.get_noise_2d(p.x,p.y))
	var forest = (1.0-smoothstep(snowline-1050,snowline-250,h))*smoothstep(.63,.88,n.y)
	forest *= smoothstep(-.25,.22,noise.get_noise_2d(p.x+4000,p.y))
	var result = {"height":h,"normal":n,"mask":Color(snow,forest,clampf(.5+variation,0,1),clampf(.5+hollow*.35,0,1)),"blend":blend_at(p)}
	sample_cache[key] = result
	return result

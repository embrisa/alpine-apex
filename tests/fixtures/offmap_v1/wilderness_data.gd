extends RefCounted
## Small, presentation-only annulus. No collision, height images or physical RNG.
const VERSION = 1
const OUTER_RADIUS_M = 18000.0
const RING_RADII = [9000.0,13200.0,OUTER_RADIUS_M]
const SECTORS = 8
const EDGE_SEGMENTS = 1024 # Every 32 m vertex of the existing 8.192 km apron.
var seed_value: int
var origin = Vector2.ZERO
var apron_center = Vector2.ZERO
var apron_half: float = 4096.0
var valley_height: float
var snowline: float
var peaks: Array[Dictionary] = []
var noise = FastNoiseLite.new()
var detail = FastNoiseLite.new()
var mountain

func configure(source, field) -> void:
	mountain = source
	seed_value = (source.seed_value ^ 0x57A1D39) & 0x7fffffff
	origin = source.ORIGIN
	apron_half = source.EXTENT*0.5
	apron_center = origin+Vector2.ONE*apron_half
	noise.seed = seed_value
	noise.frequency = 0.00036
	noise.fractal_octaves = 3
	detail.seed = seed_value+371
	detail.frequency = 0.0014
	detail.fractal_octaves = 2
	var foot = field.sample(0,2850).height if field.is_summit_mountain() else field.sample(0,field.finish_z).height
	valley_height = foot-850.0
	snowline = foot+500.0
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_value
	for band in 3:
		var count = [9,12,15][band]
		var phase = rng.randf_range(-PI,PI)
		for i in count:
			var angle = phase+TAU*(float(i)+rng.randf_range(-0.3,0.3))/count
			var radius = [7400.0,11100.0,15500.0][band]+rng.randf_range(-800,800)
			peaks.append({"position":apron_center+Vector2.from_angle(angle)*radius,
				"axis":Vector2.from_angle(angle+rng.randf_range(-1.8,1.8)),
				"width":rng.randf_range(1000,1900),"length":rng.randf_range(1500,2850),
				"height":rng.randf_range(2200,3400)+band*500.0})

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

func height_at(p: Vector2) -> float:
	var edge = p.clamp(origin,origin+Vector2.ONE*apron_half*2.0)
	var apron_distance = p.distance_to(edge)
	if apron_distance<0.01: return mountain.sample_height(edge)
	var broad = noise.get_noise_2d(p.x,p.y)
	var h = valley_height+broad*230.0
	var relief = 0.0
	for peak in peaks:
		var delta: Vector2 = p-peak.position
		if delta.length_squared()>35000000.0: continue
		var u: float = delta.dot(peak.axis)/peak.length
		var v: float = delta.cross(peak.axis)/peak.width
		var distance = sqrt(u*u+v*v)
		if distance>2.8: continue
		var crest = exp(-pow(distance,1.45))*peak.height
		relief = maxf(relief,crest)
	# Ridge cuts have world-space continuity; they never imply a preferred route.
	var cuts = absf(detail.get_noise_2d(p.x+1200,p.y-870))
	h += relief*(0.85+0.15*broad)-cuts*360.0*smoothstep(300,1100,relief)
	return lerpf(mountain.sample_height(edge),h,smoothstep(0,950,apron_distance)) if apron_distance<950 else h

func normal_at(p: Vector2) -> Vector3:
	return Vector3(height_at(p-Vector2(96,0))-height_at(p+Vector2(96,0)),192,
		height_at(p-Vector2(0,96))-height_at(p+Vector2(0,96))).normalized()

func color_at(p: Vector2, height: float, normal: Vector3) -> Color:
	var variation = noise.get_noise_2d(p.x-415,p.y+710)
	var rock = Color("3c4149").lerp(Color("687078"),clampf(0.5+variation,0,1))
	var forest = (1.0-smoothstep(snowline-650,snowline-100,height))*smoothstep(0.68,0.9,normal.y)
	forest *= smoothstep(-0.3,0.2,noise.get_noise_2d(p.x+4000,p.y))
	rock = rock.lerp(Color("1c302c"),forest*0.9)
	var snow = smoothstep(snowline-500,snowline+500,height)*smoothstep(0.64,0.94,normal.y+variation*0.12)
	var color = rock.lerp(Color("dce4e8"),snow)
	var edge = p.clamp(origin,origin+Vector2.ONE*apron_half*2.0)
	# Continue the apron snow color across the geometric seam before revealing
	# valley vegetation; a hard material border would expose its square footprint.
	var transition = smoothstep(100,1400+variation*350,p.distance_to(edge))
	return Color("dce4e8").lerp(color,transition).srgb_to_linear()

extends "res://scripts/world/heightfield_surface.gd"
## V13: denser technical ecology over unchanged v12 support. snowy cirques, local tributaries, broken scarps and ecological regions.
## One immutable support grid. Generation has
## no Nodes, rider state, rendering quality, or preferred player racing line.
const Face = preload("res://scripts/world/generators/alpine_face_v13.gd")
const GENERATOR_ID = "alpine-drainage"
const GENERATOR_VERSION = 13
const DEFAULT_SEED = 849205174
const FACE_COUNT = 6
const TREE_TARGET = 200000
const FOOT_RADIUS = 2850.0
const MASK_ORIGIN = Vector2(-3072,-3072)
const MASK_SIZE = Vector2i(1537,1537)
var faces: Array = []
var parameters: Dictionary
var features: Array[Dictionary] = []
var jumps: Array[Dictionary] = []
var powder_deposits: Array[Dictionary] = []
var exposure_image: Image
var generation_ms: float
var generation_stages: Dictionary = {}
var height_checksum: String
var obstacle_checksum: String
var face_phase: float
var cache_hit = false
var tree_placement_grid: Dictionary = {}
var geology = preload("res://scripts/world/mountain_geology_v13.gd").new()

func _init(mountain_seed: int = DEFAULT_SEED,bake_surface: bool = true) -> void:
	if bake_surface and not preload("res://scripts/diagnostics/test_world_policy.gd").require_full("Full mountain generator"): return
	var begin = Time.get_ticks_usec()
	seed_value = mountain_seed
	X_MIN = MASK_ORIGIN.x
	Z_MIN = MASK_ORIGIN.y
	NX = MASK_SIZE.x
	NZ = MASK_SIZE.y
	finish_z = FOOT_RADIUS
	boundary_message = "MOUNTAIN BOUNDARY"
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_value
	parameters = {"pitch":rng.randf_range(.69,.77),"phase":rng.randf_range(-PI,PI),"spurs":rng.randi_range(3,4),"bend":rng.randf_range(.08,.17),"relief":rng.randf_range(100,145)}
	face_phase = rng.randf_range(-PI/6,PI/6)
	noise.seed = seed_value
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = .003
	noise.fractal_octaves = 2
	features.append({"name":"Summit · choose any direction","position":Vector2.ZERO})
	for i in FACE_COUNT:
		var face = Face.new(self,i,face_phase+TAU*i/FACE_COUNT)
		faces.append(face)
		for form in face.landforms:
			features.append({"name":"Face %d · %s" % [i+1,form.name],"position":face.to_world(form.position)})
		features.append({"name":"Face %d · forest glades" % (i+1),"position":face.to_world(face.clearings[0].position)})
		features.append({"name":"Face %d · powder basin" % (i+1),"position":face.to_world(face.bowls[0].position)})

		for deposit in face.powder_deposits:
			powder_deposits.append({"position":face.to_world(deposit.position),"radius":deposit.radius,"height":deposit.height,"face":i,"local_position":deposit.position})
	if not bake_surface: return
	heights = _parallel_rows(_landform_rows)
	generation_stages.landforms_ms = (Time.get_ticks_usec()-begin)/1000.0
	geology.prepare(self)
	_sculpt_snow()
	_accumulate_powder()
	generation_stages.surface_ms = (Time.get_ticks_usec()-begin)/1000.0
	geology.finish(self)
	_scatter()
	_scatter_open_slopes()
	generation_stages.obstacles_ms = (Time.get_ticks_usec()-begin)/1000.0
	exposure_image = Image.create_from_data(NX,NZ,false,Image.FORMAT_RGBA8,_parallel_rows(_exposure_rows,true))
	geology.paint_exposure(self)
	_open_woodland_connections()
	height_checksum = _digest(heights.to_byte_array())
	var bytes = PackedByteArray()
	for ob in obstacles:
		bytes.append_array(PackedFloat64Array([ob.position.x,ob.position.y,ob.position.z,ob.radius,ob.height,ob.scale,ob.yaw,1.0 if ob.tree else 0.0]).to_byte_array())
	bytes.append_array(geology.fingerprint().to_utf8_buffer())
	obstacle_checksum = _digest(bytes)
	generation_ms = (Time.get_ticks_usec()-begin)/1000.0

func adjacent_faces(p: Vector2) -> Array:
	var sector = wrapf(atan2(p.x,p.y)-face_phase,0,TAU)/(TAU/FACE_COUNT)
	var left = floori(sector)
	return [faces[left],faces[(left+1)%FACE_COUNT]]

func _landform_rows(first_row: int,last_row: int) -> PackedFloat32Array:
	var values = PackedFloat32Array()
	values.resize((last_row-first_row)*NX)
	for iz in range(first_row,last_row):
		for ix in NX:
			var p = Vector2(X_MIN+ix*CELL,Z_MIN+iz*CELL)
			var h = foundation_height(p.x,p.y)
			var delta = 0.0
			if p.length_squared()>180*180 and p.length_squared()<2830*2830:
				for face in adjacent_faces(p):
					var q: Vector2 = face.to_local(p)
					var weight: float = face.sector_weight(q.x,q.y)
					if weight>0: delta += (face._shaped_height(q.x,q.y,h)-h)*weight*smoothstep(220,640,q.y)
			values[(iz-first_row)*NX+ix] = h+delta
	return values

func foundation_height(x: float,z: float) -> float:
	var r = Vector2(x,z).length()
	var h = 4300.0-.24*(sqrt(r*r+16)-4)
	h -= (parameters.pitch-.24)*_ramp(r,24,160)
	h += (parameters.pitch-.12)*_ramp(r,2310,470)
	if r<.001: return h
	var angle = atan2(x,z)
	# Settle the large massif relief before the shallow runout begins. Fading
	# deep valleys into an already flat apron would create uphill basin closures.
	var envelope = smoothstep(80,850,r)*(1-smoothstep(1700,2350,r))
	# Broad asymmetric spurs and an elongated shoulder break the circular cone.
	# Low angular frequency gives each spur room for a snow face and a traverse.
	var backbone = .13*parameters.pitch*r*cos(2*(angle-parameters.phase))
	h += envelope*(backbone+parameters.relief*.85*(cos(parameters.spurs*(angle+parameters.bend*sin(r*.0012))+parameters.phase)+.24*sin(angle*3+parameters.phase)))
	h -= .10*(_ramp(r,500,150)-_ramp(r,810,200))
	h -= .08*(_ramp(r,1350,160)-_ramp(r,1670,220))
	return h+noise.get_noise_2d(x,z)*2.0*smoothstep(100,400,r)

func _sculpt_snow() -> void:
	heights = _parallel_rows(_snow_rows)

func _snow_rows(first_row: int,last_row: int) -> PackedFloat32Array:
	var sculpted = heights.slice(first_row*NX,last_row*NX)
	for iz in range(first_row,last_row):
		for ix in NX:
			var p = Vector2(X_MIN+ix*CELL,Z_MIN+iz*CELL)
			if p.length_squared()<260*260 or p.length_squared()>2800*2800: continue
			for face in adjacent_faces(p):
				var q: Vector2 = face.to_local(p)
				var weight: float = face.sector_weight(q.x,q.y)
				if weight<=0: continue
				var relief_weight: float = face.snow_relief_weight(q.x,q.y)*weight
				if relief_weight>0: sculpted[(iz-first_row)*NX+ix] += face.snow_relief_at(q.x,q.y)*relief_weight
	return sculpted

func _accumulate_powder() -> void:
	var accumulated = heights.duplicate()
	for deposit in powder_deposits:
		var face = faces[deposit.face]
		var p: Vector2 = deposit.position
		var extent = maxf(deposit.radius.x,deposit.radius.y)*2
		for iz in range(maxi(0,floori((p.y-extent-Z_MIN)/CELL)),mini(NZ,ceili((p.y+extent-Z_MIN)/CELL)+1)):
			for ix in range(maxi(0,floori((p.x-extent-X_MIN)/CELL)),mini(NX,ceili((p.x+extent-X_MIN)/CELL)+1)):
				var world_p = Vector2(X_MIN+ix*CELL,Z_MIN+iz*CELL)
				var q: Vector2 = face.to_local(world_p)
				var local: Vector2 = (q-deposit.local_position)/deposit.radius
				if local.length_squared()>=4: continue
				var falloff = exp(-local.length_squared()*1.7)*(1-smoothstep(1.5,2,local.length()))
				var weight: float = face.powder_region(q.x,q.y)*face.sector_weight(q.x,q.y)*smoothstep(.58,.80,render_normal(world_p.x,world_p.y).y)*(1-face.landing_weight(q.x,q.y))
				accumulated[iz*NX+ix] += deposit.height*falloff*weight
	heights = accumulated

func _scatter() -> void:
	for face in faces:
		var rng = RandomNumberGenerator.new()
		rng.seed = face.seed_value+50771
		var visited: Dictionary = {}
		# Sample woodland area at trunk spacing, rather than spending a small
		# uniform candidate budget across square kilometres of open mountain.
		const SPACING = 4.8
		for stand in face.stands:
			var extent: float = maxf(stand.radius.x,stand.radius.y)*1.4
			for iz in range(floori((stand.position.y-extent)/SPACING),ceili((stand.position.y+extent)/SPACING)+1):
				for ix in range(floori((stand.position.x-extent)/SPACING),ceili((stand.position.x+extent)/SPACING)+1):
					var key = Vector2i(ix,iz)
					if visited.has(key): continue
					visited[key] = true
					var q = Vector2(ix,iz)*SPACING+Vector2(rng.randf_range(-2.4,2.4),rng.randf_range(-2.4,2.4))
					var density: float = face.stand_density(q.x,q.y)*face.sector_weight(q.x,q.y)
					if rng.randf()>density: continue
					var p: Vector2 = face.to_world(q)
					if contact_normal(p.x,p.y).y<.68 or face.exposure_at(q.x,q.y).r>.38: continue
					var altitude: float = sample(p.x,p.y).height
					var stature = lerpf(.65,1.08,1-smoothstep(face.treeline_height-320,face.treeline_height+60,altitude))
					var maturity = lerpf(.8,1.35,smoothstep(.1,.7,density))
					_put_obstacle(p,true,rng.randf_range(.9,1.65)*stature*maturity,rng)

func _scatter_open_slopes() -> void:
	# Independent sparse-ecology stream: broad coverage between woodland bodies,
	# with noise-thinned openings and the same physical trunk spacing contract.
	var rng=RandomNumberGenerator.new()
	rng.seed=seed_value ^ 0x513A75E
	const SPACING=4.5
	var extent=ceili(2780/SPACING)
	for iz in range(-extent,extent+1):
		for ix in range(-extent,extent+1):
			var p=Vector2(ix,iz)*SPACING+Vector2(rng.randf_range(-1.2,1.2),rng.randf_range(-1.2,1.2))
			if p.length_squared()<950*950 or p.length_squared()>2780*2780: continue
			var nearby=adjacent_faces(p)
			var face=nearby[0]
			var q: Vector2=face.to_local(p)
			var other_q: Vector2=nearby[1].to_local(p)
			if nearby[1].sector_weight(other_q.x,other_q.y)>face.sector_weight(q.x,q.y):
				face=nearby[1]; q=other_q
			var density: float=face.scattered_density(q.x,q.y)
			if rng.randf()>density or face.stand_density(q.x,q.y)>.25: continue
			if contact_normal(p.x,p.y).y<.68 or face.exposure_at(q.x,q.y).r>.38: continue
			var altitude: float=sample(p.x,p.y).height
			var stature=lerpf(.65,1.08,1-smoothstep(face.treeline_height-320,face.treeline_height+60,altitude))
			_put_obstacle(p,true,rng.randf_range(.85,1.65)*stature,rng,"scattered")

func _put_obstacle(p: Vector2,tree: bool,scale_value: float,rng: RandomNumberGenerator,ecology: String="woodland") -> void:
	if not tree: return # Only trunks use cylinder obstacles; minerals have shared convex collision.
	if not geology.clear(Vector3(p.x,0,p.y),.46*scale_value+2): return
	for face in adjacent_faces(p):
		if face.drop_protected(face.to_local(p),.46*scale_value+2): return
	var radius = (.46 if tree else 1.35)*scale_value
	for gz in range(floori((p.y-6)/6),floori((p.y+6)/6)+1):
		for gx in range(floori((p.x-6)/6),floori((p.x+6)/6)+1):
			for idx in tree_placement_grid.get(Vector2i(gx,gz),[]):
				var other = obstacles[idx]
				if p.distance_to(Vector2(other.position.x,other.position.z))<maxf(4.2,radius+other.radius+2): return
	var key=Vector2i(floori(p.x/6),floori(p.y/6))
	if not tree_placement_grid.has(key): tree_placement_grid[key]=[]
	tree_placement_grid[key].append(obstacles.size())
	add_obstacle({"position":Vector3(p.x,sample(p.x,p.y).height,p.y),"radius":radius,"height":11.0*scale_value,"scale":scale_value,"yaw":rng.randf_range(-PI,PI),"tree":tree,"powder_cap":false,"ecology":ecology})

func _open_woodland_connections() -> void:
	# Keep finite woodland openings connected to their margins, and let narrow
	# snow beside steep stone remain traversable. This reads physical terrain
	# and ecological regions only; no survey graph, rider or preferred line.
	build_material_map()
	var retained: Array=[]
	for ob in obstacles:
		var p=Vector2(ob.position.x,ob.position.z)
		var opening=false
		for i in 8:
			var at=p+Vector2.from_angle(i*TAU/8)*12.0
			if contact_normal(at.x,at.y).y<.64 or rock_fraction_at(at.x,at.y)>.45:
				opening=true; break
		if not opening:
			for face in adjacent_faces(p):
				var q: Vector2=face.to_local(p)
				opening=face.woodland_opening(q)
				if opening: break
		if not opening: retained.append(ob)
	var original_count=obstacles.size()
	obstacles=[]
	obstacle_grid.clear()
	tree_placement_grid.clear()
	# Uniform deterministic thinning preserves coverage instead of truncating
	# generation order at a particular face or elevation.
	var rng=RandomNumberGenerator.new()
	rng.seed=seed_value ^ 0xD31517
	var remaining=retained.size()
	var wanted=mini(TREE_TARGET,remaining)
	for ob in retained:
		if rng.randi_range(0,remaining-1)<wanted:
			add_obstacle(ob); wanted-=1
		remaining-=1
	print("ALPINE_V13_WOODLAND ",original_count," candidates; ",obstacles.size()," connected-woodland trunks")

func environment_weight(x: float,z: float) -> float:
	var r = Vector2(x,z).length()
	return smoothstep(180,340,r)*(1-smoothstep(2630,2830,r))

func exposure_at(x: float,z: float) -> Color:
	var result = Color(0,0,0,1)
	for face in adjacent_faces(Vector2(x,z)):
		var q: Vector2 = face.to_local(Vector2(x,z))
		var weight: float = face.sector_weight(q.x,q.y)
		if weight>0: result.r += face.exposure_at(q.x,q.y).r*weight
	return result

func stand_density(x: float,z: float) -> float:
	var value = 0.0
	for face in adjacent_faces(Vector2(x,z)):
		var q: Vector2 = face.to_local(Vector2(x,z))
		value += face.stand_density(q.x,q.y)*face.sector_weight(q.x,q.y)
	return value

func powder_region(x: float,z: float) -> float:
	var value = 0.0
	if environment_weight(x,z)<=0: return value
	for face in adjacent_faces(Vector2(x,z)):
		var q: Vector2 = face.to_local(Vector2(x,z))
		value += face.powder_region(q.x,q.y)*face.sector_weight(q.x,q.y)
	return clampf(value,0,1)

func snow_depth_at(x: float,z: float) -> float:
	var packed = .035+.065*clampf(.5+noise.get_noise_2d(x+917,z-531),0,1)
	return lerpf(packed,.24+.07*sin(x*.031+sin(z*.019)),powder_region(x,z))

func in_landing_fan(x: float,z: float) -> bool:
	for face in adjacent_faces(Vector2(x,z)):
		var q: Vector2 = face.to_local(Vector2(x,z))
		if face.landing_weight(q.x,q.y)>.01: return true
	return false

func render_normal(x: float,z: float) -> Vector3:
	var ix = roundi((x-X_MIN)/CELL)
	var iz = roundi((z-Z_MIN)/CELL)
	if ix>0 and ix<NX-1 and iz>0 and iz<NZ-1:
		return Vector3(heights[iz*NX+ix-1]-heights[iz*NX+ix+1],8,heights[(iz-1)*NX+ix]-heights[(iz+1)*NX+ix]).normalized()
	return contact_normal(x,z)

func continuation_height(x: float,z: float) -> float:
	return sample(x,z).height if bounds().has_point(Vector2(x,z)) else foundation_height(x,z)

func is_summit_mountain() -> bool: return true
func spawn_point() -> Vector3: return Vector3(0,sample(0,0).height,0)
func spawn_heading() -> float: return face_phase
func launch_point(heading: float) -> Vector3:
	var p = Vector2(sin(heading),cos(heading))*16
	return Vector3(p.x,sample(p.x,p.y).height,p.y)
func reached_base(position: Vector3) -> bool: return Vector2(position.x,position.z).length()>=FOOT_RADIUS
func descent_progress(position: Vector3) -> float: return clampf(Vector2(position.x,position.z).length()/FOOT_RADIUS*100,0,100)

static func _ramp(distance_value: float,start: float,length_value: float) -> float:
	var u = clampf((distance_value-start)/length_value,0,1)
	return length_value*(u*u*u-.5*u*u*u*u)+maxf(0,distance_value-start-length_value)

static func _digest(bytes: PackedByteArray) -> String:
	var context = HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()

func _parallel_rows(bake: Callable, bytes: bool = false):
	var count = mini(6,maxi(1,OS.get_processor_count()-2))
	if "--massif-serial" in OS.get_cmdline_user_args(): count = 1
	var jobs: Array = []
	for i in count:
		var work = bake.bind(floori(float(NZ*i)/count),floori(float(NZ*(i+1))/count))
		var thread = Thread.new()
		if count==1 or thread.start(work)!=OK:
			jobs.append(work.call())
		else: jobs.append(thread)
	var joined = PackedByteArray() if bytes else PackedFloat32Array()
	for job in jobs:
		joined.append_array(job.wait_to_finish() if job is Thread else job)
	return joined

func _exposure_rows(first_row: int,last_row: int) -> PackedByteArray:
	var data = PackedByteArray()
	data.resize((last_row-first_row)*NX*4)
	for iz in range(first_row,last_row):
		for ix in NX:
			var color = exposure_at(X_MIN+ix*CELL,Z_MIN+iz*CELL)
			var offset = ((iz-first_row)*NX+ix)*4
			data[offset] = clampi(roundi(color.r*255),0,255)
			data[offset+3] = clampi(roundi(color.a*255),0,255)
	return data

func sweep_obstacle_contact(from: Vector3, to: Vector3) -> Dictionary:
	var original = super.sweep_obstacle_contact(from,to)
	if original.get("boundary",false): return original
	var mineral = geology.collision.sweep(from,to)
	return mineral if not mineral.is_empty() and mineral.fraction<float(original.get("fraction",INF)) else original

func geology_clear(point: Vector3, radius: float) -> bool:
	return geology.clear(point,radius)

func ray_geology(from: Vector3, to: Vector3, radius: float = 0.0) -> Dictionary:
	return geology.collision.sweep(from,to,Vector3.ONE*radius,Vector3.ZERO)

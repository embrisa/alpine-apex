extends SceneTree
## Differential tests against the authoritative sample and retained full channel query.
const Surface = preload("res://scripts/world/heightfield_surface.gd")
const Massif = preload("res://scripts/world/generators/alpine_massif_v17.gd")
const Crush = preload("res://scripts/core/snow_crush_contact.gd")
var checks = 0
var failures: Array = []

class MutableAdapter extends "res://scripts/world/heightfield_surface.gd":
	var rise = 3.0
	var calls = 0
	func sample(x: float,z: float) -> Dictionary:
		calls += 1
		return {"height":rise+x*.25-z*.5,"normal":Vector3(-.25,1,.5).normalized()}

class InheritedAdapter extends MutableAdapter:
	pass

class MassifAdapter extends "res://scripts/world/generators/alpine_massif_v17.gd":
	var rise = 7.0
	func _init() -> void: super(849205174,false)
	func sample(x: float,z: float) -> Dictionary:
		return {"height":rise+x*.5-z*.25,"normal":Vector3(-.5,1,.25).normalized()}

class DuckAdapter extends RefCounted:
	var rise = 5.0
	func sample(x: float,z: float) -> Dictionary:
		return {"height":rise+x-z,"normal":Vector3(-1,1,1).normalized()}

func _initialize() -> void: call_deferred("run")
func check(value: bool,label: String) -> void:
	checks += 1
	if not value: failures.append(label); printerr("FAIL ",label)

func original_normal(field,x: float,z: float) -> Vector3:
	var dx: float = field.sample(x+2,z).height-field.sample(x-2,z).height
	var dz: float = field.sample(x,z+2).height-field.sample(x,z-2).height
	return Vector3(-dx,4,-dz).normalized()

# Explicit current reference: the pre-optimization powder equations, using the
# production full channel query so narrow-query and zero-weight gates are tested.
func original_face_powder(face,x: float,z: float) -> float:
	var weight = 0.0
	for bowl_id in face.bowl_grid.get(Vector2i(floori(x/face.REGION_CELL),floori(z/face.REGION_CELL)),[]):
		var bowl: Dictionary = face.bowls[bowl_id]
		var q: Vector2 = (Vector2(x,z)-bowl.position)/bowl.radius
		weight = maxf(weight,(1-smoothstep(.35,1.1,q.length()))*.80)
	return maxf(weight,face.channel_values(x,z).y*.65)*smoothstep(350,600,z)*(1-smoothstep(2500,2740,z))

func original_powder(field,x: float,z: float) -> float:
	var value = 0.0
	if field.environment_weight(x,z)<=0: return value
	for face in field.adjacent_faces(Vector2(x,z)):
		var q: Vector2 = face.to_local(Vector2(x,z))
		value += original_face_powder(face,q.x,q.y)*face.sector_weight(q.x,q.y)
	return clampf(value,0,1)

func original_depth(field,x: float,z: float) -> float:
	var cover = clampf(.5+field.noise.get_noise_2d(x+917,z-531),0,1)
	var thick = .19+.08*cover
	return minf(.35,lerpf(thick,.28+.04*sin(x*.031+sin(z*.019)),original_powder(field,x,z))+minf(.06,Massif.TreeSnow.sample_delta(field,field.tree_snow_height,x,z)*.12))

func run() -> void:
	var rng = RandomNumberGenerator.new(); rng.seed = 89113
	var surface = Surface.new()
	surface.NX=9; surface.NZ=7; surface.X_MIN=-16; surface.Z_MIN=-12
	surface.heights.resize(surface.NX*surface.NZ)
	for i in surface.heights.size(): surface.heights[i]=rng.randf_range(-30,30)
	var same = true; var normals = true; var samples = 0
	for z in range(-4,30):
		for x in range(-4,38):
			for shift in [Vector2.ZERO,Vector2(.00001,-.00001),Vector2(.125,.875),Vector2(.875,.126)]:
				var p = Vector2(x-16,z-12)+shift
				same = same and surface.sample_height(p.x,p.y)==surface.sample(p.x,p.y).height
				normals = normals and surface.contact_normal(p.x,p.y)==original_normal(surface,p.x,p.y)
				samples+=1
	check(same,"Exact triangle heights: halves, diagonals, vertices, edges and bounds (%d samples)"%samples)
	check(normals,"Exact four-metre contact normals")
	check(surface.get_script()==surface._height_query_script,"Baked surface selects the allocation-free height path")
	for i in surface.heights.size(): surface.heights[i]+=2
	surface.X_MIN-=4; surface.Z_MIN+=4; surface.seed_value+=1
	check(surface.sample_height(1,2)==surface.sample(1,2).height,"Height/bounds/seed mutation has no stale values")
	for adapter in [MutableAdapter.new(),InheritedAdapter.new()]:
		# Give the override a valid but deliberately different baked grid.
		adapter.NX=2; adapter.NZ=2; adapter.heights=PackedFloat32Array([99,99,99,99])
		check(adapter.sample_height(2,3)==2.0,"Direct/inherited sample override wins over a populated grid")
		adapter.rise=13; adapter.calls=0
		check(adapter.contact_normal(2,3)==Vector3(-1,4,2).normalized() and adapter.calls==4,"Contact stencil calls the mutable virtual sample four times")
		check(adapter.sample_height(2,3)==12.0,"Adapter mutations are immediately visible")
	var duck = DuckAdapter.new(); var crush = Crush.new()
	check(crush.height_at(duck,2,3)==4.0,"Duck-typed surface without the new API remains supported")
	duck.rise=9
	check(crush.height_at(duck,2,3)==8.0,"Duck-typed mutation remains visible")
	var massif_adapter=MassifAdapter.new()
	check(massif_adapter.sample_height(2,4)==7.0,"A massif subclass retains its own sample authority")
	massif_adapter.rise=17
	check(massif_adapter.sample_height(2,4)==17.0 and massif_adapter.contact_normal(2,4)==Vector3(-2,4,1).normalized(),"Mutable massif adapter remains live through the contact stencil")
	var points: Array[Vector2] = []
	for i in 9000: points.append(Vector2(rng.randf_range(-3100,3100),rng.randf_range(-3100,3100)))
	for seed_number in [849205174,849205175,12345]:
		var field = Massif.new(seed_number,false)
		var exact_depth = true; var exact_channel = true
		for face in field.faces:
			for channel in face.channels:
				for t in [0.0,.000001,.13,.5,.84,.999999,1.0]:
					var z: float = lerpf(channel.start.y,channel.finish.y,t)
					var centre: float = lerpf(channel.start.x,channel.finish.x,t)+channel.bend*sin(t*PI)*sin(t*PI+channel.phase)
					var width: float = channel.width*lerpf(.75,1.15,t)
					for across in [-.480001,-.48,-.16,0,.16,.479999,.48,.480001]:
						var x = centre+width*across
						exact_channel = exact_channel and face.channel_floor_weight(x,z)==face.channel_values(x,z).y
			for angle in [-35.00001,-35.0,-25.0,0.0,25.0,35.0,35.00001]:
				for radius in [0,180,340,350,600,2500,2630,2740,2830,2850]:
					var p: Vector2=face.to_world(Vector2(0,radius).rotated(deg_to_rad(angle)))
					exact_depth = exact_depth and field.snow_depth_at(p.x,p.y)==original_depth(field,p.x,p.y)
		for p in points:
			exact_depth = exact_depth and field.snow_depth_at(p.x,p.y)==original_depth(field,p.x,p.y)
		check(exact_channel,"Exact float32 channel floors at overlap/envelope/across transitions seed=%d"%seed_number)
		check(exact_depth,"Exact continuous depth across faces, seeds, bounds and snow fades seed=%d"%seed_number)
		# Exercise tree addition, in-place mutation and a fresh field lifetime.
		field.tree_snow_height.resize(field.NX*field.NZ)
		field.tree_snow_height.fill(.4)
		check(field.snow_depth_at(800,-800)==original_depth(field,800,-800),"Tree-deposit addition remains exact")
		field.tree_snow_height.fill(.9); field.noise.seed+=1
		check(field.snow_depth_at(800,-800)==original_depth(field,800,-800),"Tree/noise mutations have no stale depth")
		# A modified channel is queried live; no immutable-coefficient assumption.
		var face = field.faces[0]; var channel=face.channels[0]; channel.bend+=7
		var z: float=lerpf(channel.start.y,channel.finish.y,.5)
		var x: float=lerpf(channel.start.x,channel.finish.x,.5)+channel.bend*sin(PI*.5)*sin(PI*.5+channel.phase)
		check(face.channel_floor_weight(x,z)==face.channel_values(x,z).y and face.channel_floor_weight(x,z)>0,"Channel mutation remains live")
		field.NX=2; field.NZ=2; field.X_MIN=0; field.Z_MIN=0; field.heights=PackedFloat32Array([1,2,3,4])
		check(field.sample_height(1,2)==field.sample(1,2).height and field.get_script()==field._height_query_script,"Generated massif selects the exact height path")
	print("TERRAIN_QUERY_RESULTS %d checks; %d failures"%[checks,failures.size()])
	quit(0 if failures.is_empty() else 1)

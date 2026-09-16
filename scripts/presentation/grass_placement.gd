extends RefCounted
## Stateless presentation cells. Never consumes or modifies generation RNG/data.
const CELL = 16.0
const CANDIDATES = 160
const SHAPES = ["alpine_tuft_02","forest_fan_02","meadow_clump_02"]
var field
var noise = FastNoiseLite.new()
var heights = {}
func _init(surface, asset_heights: Dictionary = {}) -> void:
	field = surface; heights = asset_heights
	noise.seed = field.seed_value+73129
	noise.frequency = .065; noise.fractal_octaves = 2

func habitat(p: Vector2) -> Dictionary:
	if not field.bounds().grow(-1.0).has_point(p): return {}
	var support: Dictionary = field.sample(p.x,p.y)
	if support.normal.y<.70: return {}
	var rock: float = smoothstep(.42,.58,field.rock_fraction_at(p.x,p.y))
	var snow: float = 1.0-rock # Exactly the visible contact-material coverage.
	var forest: float = clampf(field.stand_density(p.x,p.y),0,1) if field.has_method("stand_density") else 0.0
	var suitable: float = field.environment_weight(p.x,p.y) if field.has_method("environment_weight") else 1.0
	var powder: float = field.powder_region(p.x,p.y) if field.has_method("powder_region") else 0.0
	var depth: float = maxf(0,field.snow_depth_at(p.x,p.y)) if field.has_method("snow_depth_at") else 0.0
	# Ice uses the existing exposure green channel; raw snow mantle is not cover.
	if "exposure_image" in field and field.exposure_image:
		var pixel = Vector2i(((p-field.MASK_ORIGIN)/4.0).round())
		if pixel.x>=0 and pixel.y>=0 and pixel.x<field.exposure_image.get_width() and pixel.y<field.exposure_image.get_height():
			if field.exposure_image.get_pixelv(pixel).g>.12: return {}
	if suitable<.15 or (snow>.5 and (powder>.55 or depth>.29)): return {}
	# Keep large clear snowfields: tall snow grass favors sheltered forest edges.
	var density: float = lerpf(.20,.92,forest)*suitable
	if snow>.9 and forest<.10: density *= .16
	return {"height":support.height,"normal":support.normal,"coverage":snow,"depth":depth,"forest":forest,"density":density,"powder":powder}

func cell(key: Vector2i) -> Array:
	var result: Array = []
	var rng = RandomNumberGenerator.new()
	rng.seed = hash("grass-v1:%d:%d:%d" % [field.seed_value,key.x,key.y])
	var origin = Vector2(key)*CELL
	# Stable cells and candidate order make reduced density a strict subset.
	for i in CANDIDATES:
		var p = origin+Vector2(rng.randf(),rng.randf())*CELL
		var chance = rng.randf(); var scale_value = rng.randf_range(.85,1.18)
		var yaw = rng.randf_range(-PI,PI); var phase = rng.randf(); var rank = rng.randf()
		var patch = smoothstep(-.12,.28,noise.get_noise_2d(p.x,p.y))
		if chance>patch: continue
		var h = habitat(p)
		if h.is_empty() or chance>patch*h.density: continue
		var shape: String = SHAPES[1] if h.forest>.3 else SHAPES[2 if h.coverage>.2 else 0]
		var finish: String = "snow" if h.coverage>.72 else ("dusted" if h.coverage>.12 else "green")
		var id = shape+"_"+finish
		var blade_height: float = heights.get(id,.42)*scale_value
		var burial: float = h.depth*h.coverage
		if blade_height*h.normal.y-burial<.075: continue
		var anchor = Vector3(p.x,h.height,p.y)
		# Mineral overlay grass owns elevated surfaces. Exclude terrain under its
		# independent mineral bounds rather than burying duplicate tufts in rocks.
		if _mineral_overlap(anchor): continue
		var up: Vector3 = h.normal
		var forward = Vector3(sin(yaw),0,cos(yaw)).slide(up).normalized()
		var right = up.cross(forward).normalized()
		var pose = Transform3D(Basis(right,up,right.cross(up)).scaled(Vector3.ONE*scale_value),anchor-Vector3.UP*(burial+.012))
		result.append({"pose":pose,"asset":id,"rank":rank,"phase":phase,"coverage":h.coverage,"burial":burial,"height":blade_height,"forest":h.forest,"support":h.height})
	result.sort_custom(func(a,b): return a.rank<b.rank)
	return result

func prepare_cell(key: Vector2i, density: float, mesh_bounds: Dictionary) -> Array:
	return pack(cell(key),density,mesh_bounds)

static func pack(items: Array, density: float, mesh_bounds: Dictionary) -> Array:
	# Worker-owned arrays and value bounds only. Mesh resources, scene nodes and
	# RenderingServer publication stay on the main thread. Both LODs share data.
	var groups: Dictionary = {}
	for item in items:
		if item.rank>=density: continue
		if not groups.has(item.asset): groups[item.asset]=[]
		groups[item.asset].append(item)
	var result: Array = []
	for id in groups:
		var members: Array=groups[id]
		var buffer=PackedFloat32Array(); buffer.resize(members.size()*16)
		var boxes: Array[AABB]=[AABB(),AABB()]
		var meshes: Array[AABB]=[mesh_bounds[id+"_lod1"],mesh_bounds[id+"_lod2"]]
		for i in members.size():
			var item: Dictionary=members[i]
			var pose: Transform3D=item.pose
			var offset=i*16
			buffer[offset]=pose.basis.x.x; buffer[offset+1]=pose.basis.y.x; buffer[offset+2]=pose.basis.z.x; buffer[offset+3]=pose.origin.x
			buffer[offset+4]=pose.basis.x.y; buffer[offset+5]=pose.basis.y.y; buffer[offset+6]=pose.basis.z.y; buffer[offset+7]=pose.origin.y
			buffer[offset+8]=pose.basis.x.z; buffer[offset+9]=pose.basis.y.z; buffer[offset+10]=pose.basis.z.z; buffer[offset+11]=pose.origin.z
			buffer[offset+12]=item.phase; buffer[offset+13]=item.height; buffer[offset+14]=item.coverage; buffer[offset+15]=1.0
			for lod in 2:
				var box: AABB=pose*meshes[lod]
				boxes[lod]=box if i==0 else boxes[lod].merge(box)
		result.append({"asset":id,"buffer":buffer,"bounds":[boxes[0].grow(.65),boxes[1].grow(.65)]})
	return result

func _mineral_overlap(p: Vector3) -> bool:
	if not "geology" in field or field.geology==null: return false
	var collision = field.geology.collision
	for index in collision.candidates(p,p,.4):
		var box: AABB = collision.entries[index].aabb.grow(.35)
		if p.x>=box.position.x and p.x<=box.end.x and p.z>=box.position.z and p.z<=box.end.z and box.end.y>p.y-.05: return true
	return false

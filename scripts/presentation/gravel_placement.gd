extends RefCounted
## Cosmetic tile placement over immutable authoritative terrain, never cached.
const CELL=8.0
const TILE=.5
const PATCH_CELL=12.0
const Grass=preload("res://scripts/presentation/grass_placement.gd")
var field
var mode="all"
var mask: Image
var grass_source
func _init(source,selected: String="all") -> void:
	field=source; mode=selected; grass_source=Grass.new(field)
func patch(key: Vector2i) -> Vector3:
	var rng=RandomNumberGenerator.new(); rng.seed=hash("gravel-v1:%d:%d:%d" % [field.seed_value,key.x,key.y])
	if rng.randf()>.74: return Vector3.ZERO
	return Vector3(key.x*PATCH_CELL+rng.randf_range(3,9),key.y*PATCH_CELL+rng.randf_range(3,9),rng.randf_range(1.3,3.0))
func suitable(p: Vector2) -> bool:
	if not field.bounds().grow(-1).has_point(p) or field.rock_fraction_at(p.x,p.y)<.60: return false
	if field.sample(p.x,p.y).normal.y<.78: return false
	if "exposure_image" in field and field.exposure_image:
		var pixel=Vector2i(((p-field.MASK_ORIGIN)/4).round())
		if field.exposure_image.get_pixelv(pixel).g>.12: return false
	return true
func cell(key: Vector2i) -> Array:
	mask=Image.create(18,18,false,Image.FORMAT_R8); mask.fill(Color.WHITE)
	if mode=="off": return []
	var origin=Vector2(key)*CELL
	var candidates=[]
	for z in 16:
		for x in 16:
			if suitable(origin+Vector2(x+.5,z+.5)*TILE): candidates.append(Vector2i(x,z))
	if candidates.is_empty(): return []
	var result=[]; var roots=[]; var patches=[]; var boxes=[]
	var grass_key=Vector2i((origin/Grass.CELL).floor())
	for z in range(-1,2):
		for x in range(-1,2):
			for item in grass_source.cell(grass_key+Vector2i(x,z)):
				var p: Vector3=item.pose.origin
				if Rect2(origin-Vector2.ONE*1.75,Vector2.ONE*(CELL+3.5)).has_point(Vector2(p.x,p.z)): roots.append(Vector2(p.x,p.z))
	# One texel halo makes separately published neighboring cells agree before
	# either neighbor becomes resident. Linear sampling cannot reveal old slots.
	for mz in range(-1,17):
		for mx in range(-1,17):
			mask.set_pixel(mx+1,mz+1,Color(smoothstep(1.1,1.5,grass_distance_at(origin+Vector2(mx+.5,mz+.5)*TILE,roots)),0,0))
	var patch_key=Vector2i((origin/PATCH_CELL).floor())
	for z in range(-1,2):
		for x in range(-1,2):
			var p=patch(patch_key+Vector2i(x,z))
			if p.z>0: patches.append(p)
	if "geology" in field and field.geology:
		var center=Vector3(origin.x+CELL*.5,0,origin.y+CELL*.5)
		for index in field.geology.collision.candidates(center,center,CELL): boxes.append(field.geology.collision.entries[index].aabb.grow(.4))
	for z in int(CELL/TILE):
		for x in int(CELL/TILE):
			var p=origin+Vector2(x,z)*TILE
			if not suitable(p+Vector2.ONE*TILE*.5): continue
			var allowed=true
			for corner in [Vector2.ZERO,Vector2(TILE,0),Vector2(0,TILE),Vector2.ONE*TILE]:
				if not suitable(p+corner): allowed=false; break
			if not allowed: continue
			var grass_distance=grass_distance_at(p+Vector2.ONE*TILE*.5,roots)
			if grass_distance<.74: continue
			var height: float=field.sample(p.x,p.y).height
			for box in boxes:
				if Rect2(Vector2(box.position.x,box.position.z),Vector2(box.size.x,box.size.z)).intersects(Rect2(p,Vector2.ONE*TILE)) and box.end.y>height-.1: allowed=false; break
			if not allowed: continue
			var chosen=Vector3.ZERO
			for candidate in patches:
				if (p+Vector2.ONE*TILE*.5).distance_to(Vector2(candidate.x,candidate.y))<candidate.z+.4: chosen=candidate; break
			var dense=chosen.z>0
			if (mode=="dense" and not dense) or (mode=="sparse" and dense): continue
			var variant=posmod(hash("gravel-tile:%d:%d:%d" % [field.seed_value,roundi(p.x/TILE),roundi(p.y/TILE)]),4)
			result.append({"asset":("dense_" if dense else "sparse_")+str(variant),"origin":Vector3(p.x,height,p.y),"patch":Color(chosen.x,chosen.y,chosen.z,float(dense)),"count":275 if dense else 2})
	return result

func grass_distance_at(p: Vector2,roots: Array) -> float:
	var distance_m=10.0
	for root in roots: distance_m=minf(distance_m,root.distance_to(p))
	return distance_m

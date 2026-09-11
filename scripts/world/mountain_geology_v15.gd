extends RefCounted
## Seeded geological assemblages, final seating and bounded foundation stamps.
const Catalog = preload("res://scripts/world/mineral_catalog.gd")
const Collision = preload("res://scripts/world/mineral_collision.gd")
const VERSION = 5
const Settings = preload("res://scripts/world/generation_settings.gd")
var job
var density: float = 1.0
const STAMP_LIMIT_M = 8.0
const STAMP_RADIUS_M = 16.0
var catalog = Catalog.new()
var collision = Collision.new()
var placements: Array = []
var reserved: Dictionary = {}
var statistics: Dictionary = {"rejected":0,"stamped_vertices":0,"max_stamp_m":0.0}
var candidate_id = 0
var foundations_finished = false

func prepare(field) -> void:
	job = field.job
	density = field.generation_settings.mineral_density
	var rng = RandomNumberGenerator.new()
	rng.seed = field.seed_value ^ 0x47454F12
	# Rock sources first; each has a coherent debris fan below its own scarp.
	for face in field.faces:
		if job.is_cancelled(): return
		for crag in face.crags:
			var family: String = ["wall","layered_wall","corner","recess","overhang_wall","buttress"][rng.randi_range(0,5)]
			for attempt in 6:
				var id = catalog.choose("cliffs",family,rng)
				var q: Vector2 = crag.position+Vector2(rng.randf_range(-.22,.22)*crag.width,0)
				q.y = face.crag_z(crag,q.x)+rng.randf_range(-12,12)
				var source = _place(field,face,id,q,rng,.62)
				if not source.is_empty():
					source.debris = true
					break
		for rib in face.ribs:
			if rng.randf()>.36: continue
			var huge = rng.randf()<.38
			var category = "huge_boulders" if huge else "large"
			var families = ["erratic","block","split","dome","overhang","monolith"] if huge else ["outcrop","sedimentary","cliff","fractured","rounded"]
			var source = _place(field,face,catalog.choose(category,families[rng.randi_range(0,families.size()-1)],rng),rib.position,rng,.52 if huge else .22)
			if not source.is_empty(): source.debris=true
		# Sheltered, upper, north-facing pockets. Glacier pieces always share an apron.
		if cos(face.heading)<.35:
			var z = rng.randf_range(780,1110)
			var q = Vector2(face.gully_x(z,-1)-rng.randf_range(55,90),z)
			_place(field,face,catalog.choose("large","glacier",rng),q,rng,.26)
	_stamp_foundations(field)

func finish(field) -> void:
	foundations_finished=true
	# Snow sculpting is complete: bury foundations again if the surface receded.
	var accepted: Array = []
	for placed in placements:
		var record: Dictionary = catalog.records[placed.asset]
		var shift = 0.0
		for local in record.seating:
			var p: Vector3 = placed.pose*local
			shift=minf(shift,float(field.height_at(p.x,p.z))-p.y-.08)
		placed.pose.origin.y += shift
		if _visible(field,placed.pose,record): accepted.append(placed)
		else: statistics.rejected += 1
	placements=accepted
	_rebuild_reservations()
	var sources = placements.duplicate()
	var rng=RandomNumberGenerator.new(); rng.seed=field.seed_value ^ 0x7A10512
	for source in sources:
		if job.is_cancelled(): return
		var face=field.faces[source.face]
		var q: Vector2=face.to_local(Vector2(source.pose.origin.x,source.pose.origin.z))
		var record: Dictionary=catalog.records[source.asset]
		var ice: bool=record.family=="glacier"
		var width: float=maxf(record.size_m.x,record.size_m.z)*.5
		var count=18 if ice else (68 if record.category=="cliffs" else 30)
		for i in roundi(count*density):
			var distance_m=rng.randf_range(width*.6+4,width+110 if not ice else width+14)
			var cross_m=rng.randf_range(-1,1)*distance_m*.70
			var p=q+Vector2(cross_m,distance_m)
			if ice:
				var end=q+Vector2(0,maxf(65,record.size_m.z+40))
				var side=-1 if absf(q.x-face.gully_x(q.y,-1))<absf(q.x-face.gully_x(q.y,1)) else 1
				end.x=face.gully_x(end.y,side)
				var t=rng.randf_range(.15,.72)
				var apron_width=maxf(8,record.size_m.x*.40)
				p=q.lerp(end,t)+Vector2(sin(t*PI)*sin(t*5.0+source.id)*apron_width*.35,0)
				p.x+=rng.randf_range(-.2,.2)*apron_width*(1.0-t*.42)
			var category="medium" if i%4==0 else "small"
			# Fallen debris uses compact fragments. Upright outcrop/cliff modules
			# belong to bedrock sources, not repeated miniature walls in talus.
			var family="glacier" if ice else (["fractured","sedimentary"][rng.randi_range(0,1)])
			_place(field,face,catalog.choose(category,family,rng),p,rng,.16 if category=="medium" else .35)
	# Small erratics form local pockets below scarps, not stripes beside a lane.
	for face in field.faces:
		if job.is_cancelled(): return
		for pocket in face.debris_pockets:
			for i in roundi(100*density):
				var q: Vector2 = pocket.position+Vector2(rng.randfn(0,.62)*pocket.radius.x,rng.randfn(0,.62)*pocket.radius.y)
				_place(field,face,catalog.choose("medium" if i%5==0 else "small","rounded",rng),q,rng,.30)
	# Smaller upright modules remain available as deeply embedded bedrock
	# extensions on exposed source shoulders, away from the fallen debris fans.
	var shoulder_rng=RandomNumberGenerator.new(); shoulder_rng.seed=field.seed_value ^ 0xBED120
	for source in sources:
		if job.is_cancelled(): return
		if source.ice: continue
		var face=field.faces[source.face]
		var q: Vector2=face.to_local(Vector2(source.pose.origin.x,source.pose.origin.z))
		var size: Vector3=catalog.records[source.asset].size_m
		var width: float=maxf(size.x,size.z)*source.pose.basis.get_scale().x*.5
		for i in 4:
			var p=q+Vector2((-1 if i%2==0 else 1)*shoulder_rng.randf_range(width*.85,width*1.25+4),-shoulder_rng.randf_range(0,24))
			if face.exposure_at(p.x,p.y).r<.55: continue
			var category="small" if i<2 else "medium"
			var family="outcrop" if i%2==0 else "cliff"
			_place(field,face,catalog.choose(category,family,shoulder_rng),p,shoulder_rng,.55)
	_add_technical_regions(field)
	# Collision is prepared once after tree snow and final mineral seating.
	statistics.placements=placements.size()
	statistics.categories={}; statistics.faces=[0,0,0,0,0,0]; statistics.assets={}
	for placed in placements:
		var category: String=catalog.records[placed.asset].category
		statistics.categories[category]=int(statistics.categories.get(category,0))+1
		statistics.faces[placed.face]+=1
		statistics.assets[placed.asset]=int(statistics.assets.get(placed.asset,0))+1
	statistics.unique_assets=statistics.assets.size()

func _place(field, face, asset: String, q: Vector2, rng: RandomNumberGenerator, burial: float) -> Dictionary:
	candidate_id+=1
	var record: Dictionary=catalog.records[asset]
	var p: Vector2=face.to_world(q)
	var scale_value=rng.randf_range(.88,1.12)
	var radius: float=Vector2(record.size_m.x,record.size_m.z).length()*.5*scale_value
	if face.sector_weight(q.x,q.y)<.65 or _protected(field,p,radius+5): return _reject()
	if not clear(Vector3(p.x,0,p.y),maxf(.8,radius*.65)): return _reject()
	var n: Vector3=field.sample(p.x,p.y).normal
	if n.y<(.28 if record.category in ["cliffs","huge_boulders"] else .50): return _reject()
	var yaw=atan2(n.x,n.z) if record.category=="cliffs" else face.heading+face.geology_angle+rng.randf_range(-.35,.35)
	if record.family=="rounded": yaw=rng.randf_range(-PI,PI)
	var basis=Basis(Vector3.UP,yaw).scaled(Vector3.ONE*scale_value)
	if record.category in ["small","medium"]:
		# Fallen stones settle along their supporting slope. Leaving thin layered
		# fragments upright would bury them entirely or expose an uphill wedge.
		var up=Vector3.UP.slerp(n,.92).normalized()
		var forward=Vector3(sin(yaw),0,cos(yaw)).slide(up).normalized()
		var right=up.cross(forward).normalized()
		basis=Basis(right,up,right.cross(up)).scaled(Vector3.ONE*scale_value)
	var low=INF; var offsets: Array[float]=[]
	for local in record.seating:
		var v: Vector3=basis*local+Vector3(p.x,0,p.y)
		var required: float=field.height_at(v.x,v.z)-v.y-.10
		low=minf(low,required); offsets.append(required)
	if offsets.is_empty(): return _reject()
	offsets.sort()
	var h: float=field.height_at(p.x,p.y)-record.size_m.y*scale_value*burial
	# Only macro forms may lift a foundation; small stones always bury into it.
	var macro: bool=record.category in ["cliffs","huge_boulders","large"]
	var lift=5.0 if macro and not foundations_finished else 0.0
	h=minf(h,low+lift)
	var pose=Transform3D(basis,Vector3(p.x,h,p.y))
	if not _visible(field,pose,record): return _reject()
	var moss=record.family!="glacier" and q.y>1900 and n.y>.60 and rng.randf()<.22
	var placed={"id":candidate_id,"asset":asset,"pose":pose,"face":face.index,"solid":true,
		"snow":.24 if moss else rng.randf_range(.55,.90),"moss":.7 if moss else 0.0,"grass":moss and rng.randf()<.35,
		"ice":record.family=="glacier","debris":false}
	placements.append(placed)
	_reserve(placed,record)
	return placed

func _add_technical_regions(field) -> void:
	# Add to the completed v12 geology. No new foundation stamps, ice aprons,
	# terrain edits or consumption of its random streams.
	statistics.baseline_placements=placements.size()
	for face in field.faces:
		if job.is_cancelled(): return
		var rng=RandomNumberGenerator.new()
		rng.seed=face.seed_value ^ 0xD31351
		var start=placements.size()
		var present = 0
		for placed in placements:
			if placed.face==face.index: present += 1
		var requested = roundi(Settings.MINERAL_BASELINE*density)
		var target = maxi(0,floori(float(requested*(face.index+1))/6)-floori(float(requested*face.index)/6)-present)
		var pockets: Array[Vector2]=[]
		for band in 4:
			for column in 5:
				var z=rng.randf_range(590+band*480,930+band*480)
				pockets.append(Vector2((column-2)*.16*z+rng.randf_range(-.055,.055)*z,z))
		for attempt in roundi(18000*density):
			if attempt%128==0:
				if job.is_cancelled(): return
				job.advance(128)
			if placements.size()-start>=target: break
			rng.seed=Settings.stream(face.seed_value,71,attempt)
			var centre: Vector2=pockets[attempt%pockets.size()]
			var q=centre+Vector2(rng.randfn(0,80),rng.randfn(0,115))
			# Broad scatter between debris pockets gives isolated decision points.
			if attempt%3==0:
				q.y=rng.randf_range(530,2570)
				q.x=rng.randf_range(-.43,.43)*q.y
			var choice=attempt%40
			var category="cliffs" if choice==0 else ("huge_boulders" if choice==1 else ("large" if choice<6 else ("medium" if choice<32 else "small")))
			var family: String=["rounded","fractured","sedimentary"][rng.randi_range(0,2)]
			if category=="cliffs": family=["wall","layered_wall","buttress"][rng.randi_range(0,2)]
			elif category=="huge_boulders": family=["erratic","block","dome"][rng.randi_range(0,2)]
			elif category=="large" and choice==2: family="outcrop"
			var asset=catalog.choose(category,family,rng)
			var size: Vector3=catalog.records[asset].size_m
			if face.drop_protected(q,Vector2(size.x,size.z).length()*.6+5): continue
			_place(field,face,asset,q,rng,.22 if category=="large" else .24)

func _reject() -> Dictionary:
	statistics.rejected+=1
	return {}

func _visible(field, pose: Transform3D, record: Dictionary) -> bool:
	var top=pose*Vector3(0,record.size_m.y,0)
	return top.y-float(field.height_at(top.x,top.z))>maxf(.05,record.size_m.y*.35)

func _protected(field, p: Vector2, radius: float) -> bool:
	var r=p.length()
	if r-radius<360 or r+radius>2690: return true
	for face in field.adjacent_faces(p):
		var q: Vector2=face.to_local(p)
		if face.sector_weight(q.x,q.y)<.01: continue
		# Preserve each natural opening across the whole mineral footprint.
		if face.natural_opening(q,radius): return true
	return false

func _reserve(placed: Dictionary, record: Dictionary) -> void:
	var box: AABB=placed.pose*record.aabb
	var rect=Rect2(Vector2(box.position.x,box.position.z),Vector2(box.size.x,box.size.z))
	for z in range(floori(rect.position.y/64),floori(rect.end.y/64)+1):
		for x in range(floori(rect.position.x/64),floori(rect.end.x/64)+1):
			var key=Vector2i(x,z)
			if not reserved.has(key): reserved[key]=[]
			reserved[key].append(rect)

func clear(point: Vector3, radius: float) -> bool:
	var p=Vector2(point.x,point.z)
	for z in range(floori((p.y-radius)/64),floori((p.y+radius)/64)+1):
		for x in range(floori((p.x-radius)/64),floori((p.x+radius)/64)+1):
			for rect in reserved.get(Vector2i(x,z),[]):
				if rect.grow(radius).has_point(p): return false
	return true

func _stamp_foundations(field) -> void:
	var original: PackedFloat32Array=field.heights.duplicate()
	var changes: Dictionary={}
	for placed in placements:
		if job and job.is_cancelled(): return
		var record: Dictionary=catalog.records[placed.asset]
		for local in record.seating:
			var p: Vector3=placed.pose*local
			var lift: float=clampf(p.y+.12-field.height_at(p.x,p.z),0,STAMP_LIMIT_M)
			if lift<=0: continue
			for z in range(floori((p.z-STAMP_RADIUS_M-field.Z_MIN)/4),ceili((p.z+STAMP_RADIUS_M-field.Z_MIN)/4)+1):
				for x in range(floori((p.x-STAMP_RADIUS_M-field.X_MIN)/4),ceili((p.x+STAMP_RADIUS_M-field.X_MIN)/4)+1):
					if x<1 or z<1 or x>=field.NX-1 or z>=field.NZ-1: continue
					var location=Vector2(field.X_MIN+x*4,field.Z_MIN+z*4)
					var distance_m=location.distance_to(Vector2(p.x,p.z))
					if distance_m>=STAMP_RADIUS_M or _protected(field,location,0): continue
					var weight=1.0-smoothstep(0,STAMP_RADIUS_M,distance_m)
					var index=z*field.NX+x
					changes[index]=maxf(changes.get(index,0.0),lift*weight)
	for index in changes:
		var delta: float=minf(changes[index],STAMP_LIMIT_M)
		field.heights[index]=original[index]+delta
		statistics.max_stamp_m=maxf(statistics.max_stamp_m,delta)
	statistics.stamped_vertices=changes.size()

func _rebuild_reservations() -> void:
	reserved.clear()
	for placed in placements:
		_reserve(placed,catalog.records[placed.asset])

func _reindex() -> void:
	collision=Collision.new()
	for placed in placements:
		if job and job.is_cancelled(): return
		collision.add(placed,catalog.records[placed.asset])

func restore(saved: Array, stats: Dictionary) -> void:
	placements=saved; statistics=stats
	_rebuild_reservations(); _reindex()
	_freeze()

func _freeze() -> void:
	for placed in placements: placed.make_read_only()
	placements.make_read_only()

func fingerprint() -> String:
	var context = HashingContext.new(); context.start(HashingContext.HASH_SHA256)
	context.update(var_to_bytes([VERSION,catalog.fingerprint]))
	for placed in placements:
		if job and job.is_cancelled(): return ""
		context.update(var_to_bytes([placed.id,placed.asset,placed.pose,placed.solid]))
	return context.finish().hex_encode()

func paint_exposure(field) -> void:
	# Additional solids do not repaint v12's snow/contact material underneath.
	for placed in placements.slice(0,int(statistics.get("baseline_placements",placements.size()))):
		var record: Dictionary=catalog.records[placed.asset]
		if record.category=="small": continue
		if placed.ice:
			if record.category=="large": _paint_ice_apron(field,placed,record)
			continue
		var box: AABB=placed.pose*record.aabb
		var radius=Vector2(box.size.x,box.size.z)*.65+Vector2(5,5)
		var centre=Vector2(placed.pose.origin.x,placed.pose.origin.z)
		for z in range(maxi(0,floori((centre.y-radius.y-field.Z_MIN)/4)),mini(field.NZ,ceili((centre.y+radius.y-field.Z_MIN)/4)+1)):
			for x in range(maxi(0,floori((centre.x-radius.x-field.X_MIN)/4)),mini(field.NX,ceili((centre.x+radius.x-field.X_MIN)/4)+1)):
				var p=Vector2(field.X_MIN+x*4,field.Z_MIN+z*4)
				var d=(p-centre)/radius
				var weight=1.0-smoothstep(.45,1.0,d.length())
				if weight<=0 or _protected(field,p,0): continue
				var color: Color=field.exposure_image.get_pixel(x,z)
				var n: Vector3=field.sample(p.x,p.y).normal
				color.r=maxf(color.r,weight*(1.0-smoothstep(.60,.88,n.y))*.85)
				color.a=maxf(color.a,weight)
				field.exposure_image.set_pixel(x,z,color)

func _paint_ice_apron(field, placed: Dictionary, record: Dictionary) -> void:
	# One irregular downslope apron connects the parent seracs and fragments to
	# their sheltered snow drainage. Separate oval deposits around each fragment
	# made the glacier look planted in circular collars.
	var face=field.faces[placed.face]
	var start: Vector2=face.to_local(Vector2(placed.pose.origin.x,placed.pose.origin.z))
	var finish=start+Vector2(0,maxf(65,record.size_m.z+40))
	var side=-1 if absf(start.x-face.gully_x(start.y,-1))<absf(start.x-face.gully_x(start.y,1)) else 1
	finish.x=face.gully_x(finish.y,side)
	var width=maxf(8,record.size_m.x*.40)
	var a: Vector2=face.to_world(start)
	var b: Vector2=face.to_world(finish)
	var minimum=a.min(b)-Vector2.ONE*(width+12)
	var maximum=a.max(b)+Vector2.ONE*(width+12)
	for z in range(maxi(0,floori((minimum.y-field.Z_MIN)/4)),mini(field.NZ,ceili((maximum.y-field.Z_MIN)/4)+1)):
		for x in range(maxi(0,floori((minimum.x-field.X_MIN)/4)),mini(field.NX,ceili((maximum.x-field.X_MIN)/4)+1)):
			var p=Vector2(field.X_MIN+x*4,field.Z_MIN+z*4)
			var q: Vector2=face.to_local(p)
			var t=clampf((q-start).dot(finish-start)/(finish-start).length_squared(),0,1)
			var axis=start.lerp(finish,t)+Vector2(sin(t*PI)*sin(t*5.0+placed.id)*width*.35,0)
			var ragged=sin(q.y*.095+float(placed.id))*.25+sin(q.x*.17+q.y*.063)*.20
			var radius=width*(1.0-t*.42)*(1.0+ragged)
			var weight=1.0-smoothstep(radius*.45,radius,q.distance_to(axis))
			if weight<=0: continue
			var color: Color=field.exposure_image.get_pixel(x,z)
			color.g=maxf(color.g,weight*.90*(1.0-t*.85))
			color.r=lerpf(color.r,.78*(1.0-t*.3),weight*.72)
			color.a=maxf(color.a,weight)
			field.exposure_image.set_pixel(x,z,color)

extends RefCounted
## Portable, data-only authoring document. Never changes the production library.
const VERSION = 1
const FPS = 60.0
const LIBRARY = preload("res://assets/animation/steep_ski_motion.res")
const ROOT_DIR = "user://animation_workshop"
const RECOVERY = ROOT_DIR+"/recovery.apexmotion"
var data: Dictionary = {}
var history = UndoRedo.new()
var path = ""
var error = ""
var revision = 0
var clipboard: Array = []

func _init() -> void:
	history.max_steps = 160
	var rig = {"names":Array(LIBRARY.data.names),"parents":Array(LIBRARY.data.parents),"rest":[]}
	for transform in LIBRARY.data.rest:
		rig.rest.append([vec(transform.origin),vec(transform.basis.x),vec(transform.basis.y),vec(transform.basis.z)])
	data = {"version":VERSION,"fps":60,"title":"Skier motion review","revision":0,"rig":rig,
		"identity":{"library":FileAccess.get_sha256("res://assets/animation/steep_ski_motion.res"),"rig":FileAccess.get_sha256("res://assets/graphics/models/skier_v7.glb"),"engine":Engine.get_version_info().string},
		"conventions":{"units":"metres, seconds, radians","frame_origin":0,"rotation_order":"YXZ","composition":"source quaternion * correction quaternion; regions in creation order","root":"pelvis position relative to mean source ankle; no world trajectory","axes":"right-handed; +Y up, +Z toes/forward, +X skier left in the rest pose","quaternion":"normalized [x,y,z,w], parent-relative orientation in model rest axes","rig_rest":"model-space rest transforms: [origin, basis.x, basis.y, basis.z]","fk":"R[root]=q[root]; R[i]=R[parent]*q[i]; p[root]=pelvis; p[i]=p[parent]+R[parent]*(rest[i].origin-rest[parent].origin); final skin basis=R[i]*rest[i].basis"},
		"sources":{},"variants":[],"comments":[],"preview":{"context":"grounded","slope":0.0,"stance":0.44,"tuck":0.0,"grab":1.0}}

static func vec(v: Vector3) -> Array: return [v.x,v.y,v.z]
static func v3(a: Array) -> Vector3: return Vector3(a[0],a[1],a[2])
static func quat(q: Quaternion) -> Array: return [q.x,q.y,q.z,q.w]
static func q4(a: Array) -> Quaternion: return Quaternion(a[0],a[1],a[2],a[3]).normalized()
static func uid() -> String: return Crypto.new().generate_random_bytes(12).hex_encode()

func commit(label: String, before: Dictionary) -> void:
	var after = snapshot()
	history.create_action(label)
	history.add_do_method(_restore.bind(after))
	history.add_undo_method(_restore.bind(before))
	history.commit_action()

func _restore(value: Dictionary) -> void:
	data = snapshot_of(value)
	revision += 1
	data.revision = revision

func snapshot() -> Dictionary: return snapshot_of(data)

static func snapshot_of(value: Dictionary) -> Dictionary:
	# Source sample arrays and rig transforms are immutable. Share their payloads
	# across undo states instead of copying megabytes on every mouse gesture.
	var editable = value.duplicate(false)
	editable.erase("sources"); editable.erase("rig")
	var result = editable.duplicate(true)
	result.sources = value.sources.duplicate(false)
	result.rig = value.rig
	return result

func resize_region(r: Dictionary, start: float, end: float, duration: float) -> void:
	# Keep the zero boundary keys outside all authored interior keys.
	var old_start: float = r.start; var old_end: float = r.end
	var inner_start = duration; var inner_end = 0.0
	for channels in r.tracks.values():
		for track in channels:
			for k in track:
				if absf(k.v)<.00001 and (absf(k.t-old_start)<.00001 or absf(k.t-old_end)<.00001): continue
				inner_start = minf(inner_start,k.t); inner_end = maxf(inner_end,k.t)
	r.start = clampf(start,0,maxf(0,minf(end-1.0/60,inner_start-1.0/60)))
	r.end = clampf(end,minf(duration,maxf(r.start+1.0/60,inner_end+1.0/60)),duration)
	for channels in r.tracks.values():
		for track in channels:
			for k in track:
				if absf(k.v)>.00001: continue
				if absf(k.t-old_start)<.00001: k.t = r.start
				elif absf(k.t-old_end)<.00001: k.t = r.end
			track.sort_custom(func(a,b): return a.t<b.t)

func dispose() -> void:
	# UndoRedo is an Object and its Callables retain this RefCounted document.
	if is_instance_valid(history):
		history.clear_history()
		history.free()
	history = null

func add_variant(source: String, title: String = "") -> String:
	if not LIBRARY.data.clips.has(source): return ""
	var before = snapshot()
	if not data.sources.has(source):
		var clip = LIBRARY.data.clips[source]
		data.sources[source] = {"duration":clip.duration,"frames":clip.frames,"values":Array(clip.values)}
	var clip = data.sources[source]
	var id = uid()
	data.variants.append({"id":id,"name":title if not title.is_empty() else source.capitalize()+" · edit","source":source,
		"duration":(int(clip.frames)-1)/FPS,"mapping":[[0.0,0.0],[(int(clip.frames)-1)/FPS,(int(clip.frames)-1)/FPS]],"regions":[],"reviewed":false})
	commit("Create working copy",before)
	return id

func variant(id: String) -> Dictionary:
	for item in data.variants:
		if item.id==id: return item
	return {}

func duplicate_variant(id: String, title: String) -> String:
	var before = snapshot()
	var item = variant(id).duplicate(true)
	if item.is_empty(): return ""
	item.id = uid(); item.name = title
	for region in item.regions: region.id = uid()
	data.variants.append(item); commit("Duplicate variant",before)
	return item.id

func source_time(item: Dictionary, time: float) -> float:
	var mapping: Array = item.mapping
	return sample_pairs(mapping,clampf(time,0,item.duration))

static func sample_pairs(keys: Array, time: float) -> float:
	if time<=float(keys[0][0]): return keys[0][1]
	for i in range(1,keys.size()):
		if time<=float(keys[i][0]): return lerpf(keys[i-1][1],keys[i][1],inverse_lerp(keys[i-1][0],keys[i][0],time))
	return keys[-1][1]

func source_pose(source: String, time: float) -> Dictionary:
	var clip: Dictionary = data.sources[source] if data.sources.has(source) else LIBRARY.data.clips[source]
	var cursor = clampf(time*FPS,0,int(clip.frames)-1)
	var a = int(cursor); var b = mini(a+1,int(clip.frames)-1); var f = cursor-a
	var values = clip.values
	var count: int = data.rig.names.size()
	var rotations: Array[Quaternion] = []
	for i in count:
		var ai = (a*count+i)*7+3; var bi = (b*count+i)*7+3
		var qa = Quaternion(values[ai],values[ai+1],values[ai+2],values[ai+3]).normalized()
		var qb = Quaternion(values[bi],values[bi+1],values[bi+2],values[bi+3]).normalized()
		rotations.append(qa.slerp(qb,f).normalized())
	var ai = a*count*7; var bi = b*count*7
	return {"q":rotations,"root":Vector3(values[ai],values[ai+1],values[ai+2]).lerp(Vector3(values[bi],values[bi+1],values[bi+2]),f)}

func evaluate(id: String, time: float, edited: bool = true) -> Dictionary:
	var item = variant(id)
	var result = source_pose(item.source,source_time(item,time))
	if not edited: return result
	for region in item.regions:
		if region.muted or time<float(region.start)-.000001 or time>float(region.end)+.000001: continue
		for bone in region.tracks:
			var index: int = data.rig.names.find(bone)
			if index<0: continue
			var channels: Array = region.tracks[bone]
			var values: Array = []
			for keys in channels: values.append(curve(keys,time))
			var q = Basis.from_euler(Vector3(values[0],values[1],values[2]),EULER_ORDER_YXZ).get_rotation_quaternion()
			result.q[index] = (result.q[index]*q).normalized()
			if bone=="Hips": result.root += Vector3(values[3],values[4],values[5])
	return result

static func curve(keys: Array, time: float) -> float:
	if keys.is_empty(): return 0.0
	if time<=float(keys[0].t): return keys[0].v
	for i in range(1,keys.size()):
		var a: Dictionary = keys[i-1]; var b: Dictionary = keys[i]
		if time>float(b.t): continue
		var span = float(b.t)-float(a.t)
		if span<=0: return b.v
		var u = (time-float(a.t))/span
		if is_equal_approx(time,float(b.t)): return b.v
		if a.mode=="constant": return a.v
		if a.mode=="linear": return lerpf(a.v,b.v,u)
		return (2*u*u*u-3*u*u+1)*float(a.v)+(u*u*u-2*u*u+u)*float(a.out)*span+(-2*u*u*u+3*u*u)*float(b.v)+(u*u*u-u*u)*float(b.get("in",0.0))*span
	return keys[-1].v

static func key(time: float, value: float) -> Dictionary:
	return {"id":uid(),"t":time,"v":value,"in":0.0,"out":0.0,"mode":"cubic"}

static func continuous_angles(q: Quaternion, reference: Vector3) -> Vector3:
	var first = Basis(q).get_euler(EULER_ORDER_YXZ)
	var alternate = Vector3(PI-first.x,first.y+PI,first.z+PI)
	for axis in 3:
		first[axis] = reference[axis]+wrapf(first[axis]-reference[axis],-PI,PI)
		alternate[axis] = reference[axis]+wrapf(alternate[axis]-reference[axis],-PI,PI)
	return first if first.distance_squared_to(reference)<=alternate.distance_squared_to(reference) else alternate

func correct_pose(id: String, time: float, wanted: Dictionary, bones: Array, smooth: bool = true) -> String:
	var item = variant(id)
	var region: Dictionary = {}
	if not smooth and not item.regions.is_empty() and item.regions[-1].get("kind","")=="keys": region = item.regions[-1]
	var reuse = not region.is_empty()
	if reuse: region.muted = true
	var original = evaluate(id,time)
	if reuse: region.muted = false
	else: region = {"id":uid(),"kind":"smooth" if smooth else "keys","name":"Pose at frame %d"%roundi(time*FPS),"start":maxf(0,time-.15) if smooth else 0.0,"end":minf(item.duration,time+.15) if smooth else item.duration,"muted":false,"tracks":{}}
	for bone in bones:
		var index: int = data.rig.names.find(bone)
		if index<0: continue
		var q: Quaternion = original.q[index].inverse()*wanted.q[index]
		var reference = Vector3.ZERO
		if reuse and region.tracks.has(bone):
			for axis in 3: reference[axis] = curve(region.tracks[bone][axis],time)
		var angles = continuous_angles(q,reference)
		var translation: Vector3 = wanted.root-original.root if bone=="Hips" else Vector3.ZERO
		var values = [angles.x,angles.y,angles.z,translation.x,translation.y,translation.z]
		var channels: Array = []
		for axis in values.size():
			var value: float = values[axis]
			if reuse and region.tracks.has(bone):
				var track: Array = region.tracks[bone][axis]
				if axis<3: value = curve(track,time)+wrapf(value-curve(track,time),-PI,PI)
				var found = false
				for k in track:
					if absf(float(k.t)-time)<.00001: k.v = value; found = true
				if not found: track.append(key(time,value)); track.sort_custom(func(a,b): return a.t<b.t)
				channels.append(track); continue
			var keys: Array = []
			if smooth and time>float(region.start)+.00001: keys.append(key(region.start,0))
			keys.append(key(time,value))
			if smooth and time<float(region.end)-.00001: keys.append(key(region.end,0))
			channels.append(keys)
		region.tracks[bone] = channels
	if not reuse: item.regions.append(region)
	return region.id

func fk(pose: Dictionary) -> Dictionary:
	var joints = {}; var rotations = {}
	for i in data.rig.names.size():
		var bone: String = data.rig.names[i]; var p = int(data.rig.parents[i])
		var local = Basis(pose.q[i])
		if p<0:
			joints[bone] = pose.root; rotations[bone] = local
		else:
			var parent: String = data.rig.names[p]
			rotations[bone] = rotations[parent]*local
			joints[bone] = joints[parent]+rotations[parent]*(v3(data.rig.rest[i][0])-v3(data.rig.rest[p][0]))
	return {"joints":joints,"rotations":rotations}

func mirror(pose: Dictionary) -> Dictionary:
	var result = pose.duplicate(true)
	for i in data.rig.names.size():
		var bone: String = data.rig.names[i]
		var other = bone.replace("Left","Right") if bone.begins_with("Left") else bone.replace("Right","Left")
		var q: Quaternion = pose.q[data.rig.names.find(other)]
		result.q[i] = Quaternion(q.x,-q.y,-q.z,q.w)
	result.root.x = -result.root.x
	return result

func ik(pose: Dictionary, endpoint: String, target: Vector3, hint: Vector3 = Vector3.INF) -> Array:
	var side = "Left" if endpoint.begins_with("Left") else "Right"
	var arm = endpoint.ends_with("Hand")
	var upper = side+("Arm" if arm else "UpLeg"); var lower = side+("ForeArm" if arm else "Leg")
	var world = fk(pose)
	var a: Vector3 = world.joints[upper]; var b: Vector3 = world.joints[lower]; var c: Vector3 = world.joints[endpoint]
	var l1 = a.distance_to(b); var l2 = b.distance_to(c)
	var delta = target-a
	var distance = clampf(delta.length(),absf(l1-l2)+.00001,l1+l2-.00001)
	if delta.length()<.000001: delta = Vector3.DOWN
	var axis = delta.normalized(); target = a+axis*distance
	var direction = ((b if hint==Vector3.INF else hint)-a).slide(axis)
	if direction.length()<.00001: direction = axis.cross(Vector3.RIGHT if absf(axis.x)<.8 else Vector3.UP)
	var x = (l1*l1-l2*l2+distance*distance)/(2*distance)
	var joint = a+axis*x+direction.normalized()*sqrt(maxf(0,l1*l1-x*x))
	for entry in [[upper,lower,joint-a],[lower,endpoint,target-joint]]:
		world = fk(pose)
		var index: int = data.rig.names.find(entry[0]); var parent: int = data.rig.parents[index]
		var from: Vector3 = (world.joints[entry[1]]-world.joints[entry[0]]).normalized()
		var desired: Basis = Basis(Quaternion(from,entry[2].normalized()))*world.rotations[entry[0]]
		var parent_rotation: Basis = world.rotations[data.rig.names[parent]] if parent>=0 else Basis.IDENTITY
		pose.q[index] = (parent_rotation.inverse()*desired).get_rotation_quaternion().normalized()
	return [upper,lower]

static func split_curve(keys: Array, at: float) -> void:
	for i in range(1,keys.size()):
		var a: Dictionary = keys[i-1]; var b: Dictionary = keys[i]
		if at<=a.t+.000001 or at>=b.t-.000001: continue
		var span: float = b.t-a.t; var u: float = (at-a.t)/span
		var slope = 0.0
		if a.mode=="linear": slope = (b.v-a.v)/span
		elif a.mode=="cubic":
			slope = (6*u*u-6*u)*a.v/span+(3*u*u-4*u+1)*a.out+(-6*u*u+6*u)*b.v/span+(3*u*u-2*u)*b["in"]
		var inserted = key(at,curve(keys,at)); inserted.mode = a.mode; inserted["in"] = slope; inserted.out = slope
		keys.insert(i,inserted); return

func retime(id: String, start: float, end: float, new_start: float, new_end: float) -> void:
	if end-start<1.0/FPS or new_start<0 or new_end-new_start<1.0/FPS: return
	var item = variant(id)
	if start>0 and new_start<1.0/FPS or item.duration+new_end-end>600: return
	var before = snapshot()
	var mapping: Array = item.mapping
	for t in [start,end]:
		if not mapping.any(func(k): return absf(float(k[0])-t)<.00001): mapping.append([t,source_time(item,t)])
	mapping.sort_custom(func(a,b): return a[0]<b[0])
	# Rescale the lead-in and ripple the tail, preserving a monotonic map at zero.
	var warp = func(t): return t*new_start/start if t<start and start>0 else (t+(new_end-end) if t>end else remap(t,start,end,new_start,new_end))
	for pair in mapping: pair[0] = warp.call(pair[0])
	for region in item.regions:
		region.start = warp.call(region.start); region.end = warp.call(region.end)
		for channels in region.tracks.values():
			for keys in channels:
				# Split a crossing cubic exactly before applying different time scales.
				split_curve(keys,start); split_curve(keys,end)
				for k in keys:
					var lead_scale = new_start/start if start>0 else 1.0
					var range_scale = (new_end-new_start)/(end-start)
					k["in"] /= lead_scale if k.t<=start and start>0 else (range_scale if k.t<=end else 1.0)
					k.out /= lead_scale if k.t<start and start>0 else (range_scale if k.t<end else 1.0)
					k.t = warp.call(k.t)
	item.duration = warp.call(item.duration)
	if start==0 and new_start>0: item.mapping.push_front([0.0,item.mapping[0][1]])
	commit("Retime range",before)

func trim(id: String, start: float, end: float) -> void:
	var item = variant(id); start = clampf(start,0,item.duration); end = clampf(end,start,item.duration)
	if end-start<1.0/FPS: return
	var before = snapshot()
	var mapping: Array = [[0.0,source_time(item,start)]]
	for pair in item.mapping:
		if pair[0]>start and pair[0]<end: mapping.append([pair[0]-start,pair[1]])
	mapping.append([end-start,source_time(item,end)])
	item.mapping = mapping; item.duration = end-start
	for region in item.regions:
		region.start -= start; region.end -= start
		for channels in region.tracks.values():
			for keys in channels:
				for k in keys: k.t -= start
	commit("Trim clip",before)

func save_to(destination: String, recovery: bool = false) -> Error:
	data.revision = revision
	var result = atomic_json(destination,data)
	if result==OK and not recovery: path = destination
	error = "" if result==OK else "Could not save project (error %d). Previous save retained."%result
	return result

static func atomic_json(destination: String, value: Dictionary) -> Error:
	var absolute = ProjectSettings.globalize_path(destination)
	var result = DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	if result!=OK: return result
	var file = FileAccess.open(absolute+".tmp",FileAccess.WRITE)
	if file==null: return FileAccess.get_open_error()
	file.store_string(JSON.stringify(value)); file.flush()
	result = file.get_error(); file.close()
	if result!=OK: return result
	# Windows rename cannot replace an existing file. Keep a last-good backup.
	if FileAccess.file_exists(absolute):
		if FileAccess.file_exists(absolute+".bak"): DirAccess.remove_absolute(absolute+".bak")
		result = DirAccess.rename_absolute(absolute,absolute+".bak")
		if result!=OK: return result
	result = DirAccess.rename_absolute(absolute+".tmp",absolute)
	if result!=OK and FileAccess.file_exists(absolute+".bak"): DirAccess.rename_absolute(absolute+".bak",absolute)
	return result

func load_from(source: String) -> bool:
	error = "Project file does not exist."
	for candidate in [source,source+".bak"]:
		if not FileAccess.file_exists(candidate): continue
		var file = FileAccess.open(candidate,FileAccess.READ)
		if file==null: error = "Project is unreadable."; continue
		if file.get_length()>64*1024*1024: error = "Project exceeds 64 MiB."; file.close(); continue
		var parser = JSON.new(); var parsed_result = parser.parse(file.get_as_text()); file.close()
		if parsed_result!=OK: error = "Malformed project JSON at line %d."%parser.get_error_line(); continue
		var parsed = parser.data
		error = validate(parsed)
		if not error.is_empty(): continue
		# Add descriptive conventions introduced during version 1 without changing motion.
		var conventions: Dictionary = data.conventions.duplicate(true); conventions.merge(parsed.conventions,true); parsed.conventions = conventions
		data = parsed; revision = int(data.get("revision",0)); path = source; history.clear_history()
		return true
	return false

static func finite_numbers(value: Variant) -> bool:
	if value is float: return is_finite(value)
	if value is Array:
		for child in value:
			if not finite_numbers(child): return false
	if value is Dictionary:
		for child in value.values():
			if not finite_numbers(child): return false
	return true

static func number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))

static func identifier(value: Variant) -> bool:
	if not value is String or value.length()!=24: return false
	for c in value:
		if not c in "0123456789abcdef": return false
	return true

static func validate(value: Variant) -> String:
	if not value is Dictionary or value.get("version",0)!=VERSION: return "Unsupported workshop project version."
	for name in ["rig","sources","identity","preview"]:
		if not value.get(name) is Dictionary: return "Missing "+name
	for name in ["variants","comments"]:
		if not value.get(name) is Array: return "Missing "+name
	if not value.get("title") is String or not number(value.get("revision")) or value.get("fps")!=60 or not value.get("conventions") is Dictionary: return "Invalid project metadata."
	for name in ["library","rig","engine"]:
		if not value.identity.get(name) is String: return "Invalid source identity."
	if value.has("camera"):
		var camera = value.camera
		if not camera is Dictionary: return "Invalid camera settings."
		for name in ["yaw","pitch","distance"]:
			if not number(camera.get(name)): return "Invalid camera value."
		if camera.distance<.1 or camera.distance>100 or not camera.get("orthographic") is bool or camera.get("comparison") not in ["Your edit","Original","Constrained result","Side by side","Overlay"]: return "Invalid camera mode."
		if not camera.get("focus") is Array or camera.focus.size()!=3: return "Invalid camera focus."
		for component in camera.focus:
			if not number(component): return "Invalid camera focus."
	if not finite_numbers(value): return "Project contains non-finite numbers."
	var rig: Dictionary = value.rig
	if not rig.get("names") is Array or not rig.get("parents") is Array or rig.names.size()!=LIBRARY.data.names.size() or rig.parents.size()!=LIBRARY.data.parents.size(): return "Project uses a different skeleton."
	for i in rig.names.size():
		if not rig.names[i] is String or not number(rig.parents[i]): return "Invalid bone identifier."
		if str(rig.names[i])!=str(LIBRARY.data.names[i]) or float(rig.parents[i])!=float(LIBRARY.data.parents[i]): return "Project uses a different skeleton."
	if not rig.get("rest") is Array or rig.rest.size()!=rig.names.size(): return "Invalid rest transforms."
	for row in rig.rest:
		if not row is Array or row.size()!=4: return "Invalid rest transform."
		for vector in row:
			if not vector is Array or vector.size()!=3: return "Invalid rest vector."
			for component in vector:
				if not number(component): return "Invalid rest component."
	if value.preview.get("context","") not in ["grounded","airborne","safety","mute"]: return "Invalid preview context."
	for name in ["slope","stance","tuck","grab"]:
		if not number(value.preview.get(name)): return "Invalid preview value."
	if value.preview.slope<0 or value.preview.slope>45 or value.preview.stance<.25 or value.preview.stance>.8 or value.preview.tuck<0 or value.preview.tuck>1 or value.preview.grab<0 or value.preview.grab>1: return "Preview settings outside supported ranges."
	for clip in value.sources.values():
		if not clip is Dictionary or not clip.get("values") is Array or not clip.get("frames") is float and not clip.get("frames") is int: return "Invalid source clip."
		if clip.frames<2 or clip.frames>36000 or clip.values.size()!=int(clip.frames)*rig.names.size()*7: return "Invalid source sample count."
		for component in clip.values:
			if not number(component): return "Invalid source component."
		for i in range(3,clip.values.size(),7):
			var length = Vector4(clip.values[i],clip.values[i+1],clip.values[i+2],clip.values[i+3]).length()
			if length<.5 or length>1.5: return "Invalid source quaternion."
	var ids: Array = []
	for item in value.variants:
		if not item is Dictionary: return "Invalid variant."
		for name in ["id","name","source"]:
			if not item.get(name) is String: return "Invalid variant identity."
		if not identifier(item.id) or ids.has(item.id) or not value.sources.has(item.source): return "Missing source or duplicate variant."
		ids.append(item.id)
		if not item.get("duration") is float and not item.get("duration") is int: return "Invalid duration."
		if item.duration<=0 or item.duration>600 or not item.get("mapping") is Array or item.mapping.size()<2 or not item.get("regions") is Array: return "Invalid clip timeline."
		var previous = -INF
		for pair in item.mapping:
			if not pair is Array or pair.size()!=2: return "Invalid time mapping."
			if not number(pair[0]) or not number(pair[1]) or float(pair[0])<=previous: return "Invalid time mapping."
			previous = float(pair[0])
		for region in item.regions:
			if not region is Dictionary or not region.get("tracks") is Dictionary: return "Invalid correction."
			for name in ["id","name","start","end","muted"]:
				if not region.has(name): return "Incomplete correction."
			if not identifier(region.id) or not region.name is String or not region.muted is bool or not number(region.start) or not number(region.end) or region.end<region.start: return "Invalid correction metadata."
			for bone in region.tracks:
				if not rig.names.has(bone) or not region.tracks[bone] is Array or region.tracks[bone].size()!=6: return "Invalid bone channels."
				for keys in region.tracks[bone]:
					if not keys is Array: return "Invalid keys."
					previous = -INF
					for k in keys:
						if not k is Dictionary: return "Invalid key."
						for name in ["id","t","v","in","out","mode"]:
							if not k.has(name): return "Incomplete key."
						if not identifier(k.id) or not number(k.t) or not number(k.v) or not number(k["in"]) or not number(k.out): return "Invalid key values."
						if float(k.t)<=previous or k.mode not in ["constant","linear","cubic"]: return "Invalid key sequence."
						previous = float(k.t)
	for note in value.comments:
		if not note is Dictionary or not ids.has(note.get("variant","")) or not note.get("text") is String or not note.get("evidence") is Dictionary: return "Invalid comment."
		if not identifier(note.get("id")) or not number(note.get("start")) or not number(note.get("end")) or not note.get("bones") is Array or not note.get("priority") is String or not note.get("status") is String: return "Invalid comment metadata."
		if note.priority not in ["Normal","High","Low"] or note.status not in ["Open","Resolved","Reference"] or note.end<note.start: return "Invalid comment state."
		for bone in note.bones:
			if bone not in rig.names: return "Invalid comment bone."
		if not number(note.evidence.get("revision")) or not note.evidence.get("frames") is Array: return "Invalid comment evidence."
		for frame in note.evidence.frames:
			if not frame is Dictionary or not frame.get("image_png") is String or not number(frame.get("time")) or not number(frame.get("frame")): return "Invalid captured frame."
	return ""

func identity_changed() -> bool:
	return data.identity.library!=FileAccess.get_sha256("res://assets/animation/steep_ski_motion.res") or data.identity.rig!=FileAccess.get_sha256("res://assets/graphics/models/skier_v7.glb")

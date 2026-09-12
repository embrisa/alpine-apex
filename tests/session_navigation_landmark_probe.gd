extends RefCounted
## Bounded physical-field/camera fixture selection; never rendered visibility proof.
const Race = preload("res://scripts/racing/race_definition.gd")
const Navigation = preload("res://scripts/racing/session_navigation.gd")
var field
var sim
var camera # Production ChaseCamera, also supplied by the minimal fixture.
var style: Dictionary
var deadline_ms: int = 0
var receipts: Array = []
var camera_trace: Array = []
var rejected: Dictionary = {}
var examined: int = 0
var tree_metadata: Dictionary = {}
var tree_boxes: Dictionary = {}
var bounds_sources: Dictionary = {}
var largest_tree_radius: float = 0.0
var largest_tree_top_per_scale: float = 0.0
const TREE_MANIFEST = "res://assets/graphics/trees/manifest.json"
const Placement = preload("res://scripts/presentation/forest_placement.gd")

func prepare_tree_bounds() -> String:
	# Read only 72 tiny GLB JSON headers (~105 KB), not meshes or imported resources.
	# These are the production local LOD envelopes, with the same wind allowance.
	# Alpha cutouts and exact displaced triangles still require native pixel review.
	if not tree_metadata.is_empty(): return ""
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TREE_MANIFEST))
	bounds_sources[TREE_MANIFEST.trim_prefix("res://")] = FileAccess.get_sha256(TREE_MANIFEST)
	for row in manifest.assets:
		var boxes: Array[AABB] = []
		for model in row.models:
			var path: String = "res://"+model.path
			var file = FileAccess.open(path,FileAccess.READ)
			if file==null: return "tree_bounds_open: "+path
			if file.get_32()!=0x46546c67 or file.get_32()!=2: return "tree_bounds_glb: "+path
			file.get_32()
			var length = file.get_32()
			if length>65536 or file.get_32()!=0x4e4f534a: return "tree_bounds_header: "+path
			var data: Dictionary = JSON.parse_string(file.get_buffer(length).get_string_from_utf8())
			file.close()
			if data.nodes.size()!=1: return "tree_bounds_nodes: "+path
			for key in data.nodes[0]:
				if key not in ["mesh","name"]: return "tree_bounds_transform: "+path
			var box = AABB()
			var first = true
			for primitive in data.meshes[int(data.nodes[0].mesh)].primitives:
				var accessor: Dictionary = data.accessors[int(primitive.attributes.POSITION)]
				if not accessor.has("min") or not accessor.has("max"): return "tree_bounds_accessor: "+path
				var part = AABB(vec(accessor.min),vec(accessor.max)-vec(accessor.min))
				box = part if first else box.merge(part)
				first = false
			if first: return "tree_bounds_empty: "+path
			boxes.append(box)
			var checksum = FileAccess.get_sha256(path)
			if checksum!=model.sha256: return "tree_bounds_identity: "+path
			bounds_sources[model.path] = checksum
		if boxes.size()!=3: return "tree_bounds_lods: "+str(row.id)
		var woody = boxes[0].merge(boxes[1])
		var card = boxes[2]
		var half_width = maxf(absf(card.position.x),absf(card.end.x))
		var bounds = woody.merge(AABB(Vector3(-half_width,card.position.y,-half_width),Vector3(half_width*2,card.size.y,half_width*2)))
		bounds = bounds.grow(float(row.height_m)*.34)
		var root_max = maxf(boxes[0].position.y+maxf(.025,boxes[0].size.y*.008),boxes[1].position.y+maxf(.025,boxes[1].size.y*.008))
		tree_metadata[row.id] = {"bounds":bounds,"woody":woody,"root_max":root_max,"height_m":float(row.height_m)}
		var reach = Vector2(maxf(absf(bounds.position.x),absf(bounds.end.x)),maxf(absf(bounds.position.z),absf(bounds.end.z))).length()
		largest_tree_radius = maxf(largest_tree_radius,reach*field.tree_data.max_radius/.46*10.5/float(row.height_m))
		largest_tree_top_per_scale = maxf(largest_tree_top_per_scale,bounds.end.y*10.5/float(row.height_m))
	return ""

func tree_box(id: int) -> AABB:
	if tree_boxes.has(id): return tree_boxes[id]
	# Match ForestPlacement's deterministic family, variant, scale and yaw exactly.
	var p: Vector3 = field.tree_data.positions[id]
	var region = hash("%d:%d:%d" % [field.seed_value,floori(p.x/256),floori(p.z/256)])
	var mixed = 1 if posmod(hash(Vector2(p.x,p.z)),5)==0 else 0
	var family: String = ["spruce","fir","pine"][posmod(region+mixed,3)]
	if posmod(hash(Vector2(p.x,p.z)),7)==0: family = ["birch","snag","split_snag"][posmod(region,3)]
	var variant = 1+posmod(hash("%s_%d_%d_%d" % [family,floori(p.x/48),floori(p.z/48),field.seed_value]),4)
	var asset = "forest_%s_%02d" % [Placement.FAMILY[family],variant]
	var metadata: Dictionary = tree_metadata[asset]
	var scale_value: float = field.tree_data.dimensions[id].z*10.5/metadata.height_m
	var pose = Transform3D(Basis(Vector3.UP,field.tree_data.yaws[id]).scaled(Vector3.ONE*scale_value),p)
	var box: AABB = pose*metadata.bounds
	# Bound the existing downward root seating without loading root vertex buffers.
	# The 4 m terrain vertex minimum over the woody footprint bounds every root.
	var footprint: AABB = pose*metadata.woody
	var low = p.y
	var x0 = floorf((footprint.position.x-field.X_MIN)/4.0)*4.0+field.X_MIN
	var z0 = floorf((footprint.position.z-field.Z_MIN)/4.0)*4.0+field.Z_MIN
	var nx = ceili((footprint.end.x-x0)/4.0)+1
	var nz = ceili((footprint.end.z-z0)/4.0)+1
	for z in nz:
		for x in nx: low = minf(low,field.height_at(x0+x*4.0,z0+z*4.0))
	var shift = minf(0.0,low-p.y-metadata.root_max*scale_value-.09)
	box.position.y += shift
	box.size.y -= shift # Union of all possible downward seated bounds and unseated top.
	tree_boxes[id] = box
	return box

static func segment_hits_box(origin: Vector3, target: Vector3, box: AABB) -> bool:
	var delta = target-origin
	var entry = 0.0
	var leave = 1.0
	for axis in 3:
		if absf(delta[axis])<.000001:
			if origin[axis]<box.position[axis] or origin[axis]>box.end[axis]: return false
			continue
		var a = (box.position[axis]-origin[axis])/delta[axis]
		var b = (box.end[axis]-origin[axis])/delta[axis]
		entry = maxf(entry,minf(a,b))
		leave = minf(leave,maxf(a,b))
		if entry>leave: return false
	return true

func expired() -> bool:
	return deadline_ms>0 and Time.get_ticks_msec()>=deadline_ms

func place(plan: Dictionary) -> void:
	var p: Vector3 = plan.position
	sim.reset(p,plan.heading)
	sim.prime_contacts(field)
	sim.velocity = sim.support_basis().z*float(plan.kmh)/3.6
	camera.reset()
	camera.close_view = false
	camera.effects_enabled = true
	camera_trace = []
	for frame in 60:
		camera.update_camera(sim,field,p,1.0/60.0,false,true,false)
		if frame in [0,11,59]:
			camera_trace.append({"frame":frame+1,"position":camera.global_position,
				"rotation":camera.global_rotation,"fov":camera.fov,"slope_degrees":rad_to_deg(camera.slope_pitch)})
	camera.make_current()

func camera_data() -> Dictionary:
	return {"position":camera.global_position,"basis":camera.global_basis,
		"rotation":camera.global_rotation,"fov":camera.fov,"near":camera.near,"far":camera.far,
		"keep_aspect":camera.keep_aspect,"viewport":camera.get_viewport().get_visible_rect().size,
		"settle_trace":camera_trace.duplicate(true),"settings":camera.settings.snapshot()}

func terrain_clear(origin: Vector3, target: Vector3) -> bool:
	var steps = maxi(2,ceili(Vector2(origin.x-target.x,origin.z-target.z).length()/4.0))
	for i in range(1,steps):
		if i%64==0 and expired(): return false
		var p = origin.lerp(target,float(i)/steps)
		if float(field.sample(p.x,p.z).height)>p.y: return false
	return true

func tree_sphere(id: int) -> Vector4:
	# Deliberately conservative screening proxy, not a renderer mesh or foliage aid.
	# Render placement scales assets to 10.5 * scale; physical height is 11 * scale.
	# A sphere of one physical height + 2 m includes generous crown/wind margins.
	var p: Vector3 = field.tree_data.positions[id]
	var height: float = field.tree_data.dimensions[id].y
	return Vector4(p.x,p.y+height*.5,p.z,height+2.0)

func tree_ray_blocker(origin: Vector3, target: Vector3, ids: PackedInt32Array) -> int:
	# Clip to the actual camera near plane; bounds entirely behind it cannot shade.
	var target_depth = -camera.to_local(target).z
	origin = origin.lerp(target,clampf(camera.near/maxf(target_depth,camera.near),0,1))
	var delta = Vector2(target.x-origin.x,target.z-origin.z)
	var padding = largest_tree_radius/maxf(delta.length(),.001)
	for i in ids.size():
		if i%128==0 and expired(): return -2
		var p: Vector3 = field.tree_data.positions[ids[i]]
		var offset = Vector2(p.x-origin.x,p.z-origin.z)
		var t = clampf(offset.dot(delta)/maxf(delta.length_squared(),.001),0,1)
		if (offset-delta*t).length_squared()>largest_tree_radius*largest_tree_radius: continue
		var low_y = minf(origin.lerp(target,clampf(t-padding,0,1)).y,origin.lerp(target,clampf(t+padding,0,1)).y)
		# Seating only lowers trees. Skip far-below-ray boxes before root-grid work.
		if low_y>p.y+field.tree_data.dimensions[ids[i]].z*largest_tree_top_per_scale: continue
		if segment_hits_box(origin,target,tree_box(ids[i])): return ids[i]
	return -1

func evaluate(plan: Dictionary, use_canopy: bool = true) -> Dictionary:
	var issues: Array[String] = []
	var anchor: Vector3 = plan.anchor
	var error: String = Race.point_error(plan.position,field)
	if not error.is_empty(): return {"issues":["observer_snow: "+error]}
	var seated = Navigation.anchor(field,anchor)
	if not seated.error.is_empty() or (seated.has("position") and seated.position.distance_to(anchor)>.1):
		return {"issues":["anchor_support_changed"]}
	var horizontal = Vector2(plan.position.x-anchor.x,plan.position.z-anchor.z).length()
	if absf(horizontal-float(plan.distance_m))>.1: return {"issues":["distance_mismatch"]}
	place(plan)
	var origin = camera.global_position
	var frame = camera.get_viewport().get_visible_rect()
	var inset = frame.grow(-frame.size.y*.03)
	# The v15 packing convention supplies an upper bound without a full population scan.
	var largest_sphere: float = field.tree_data.max_radius/0.46*11.0+2.0
	var near_ids: PackedInt32Array = field.tree_data.nearby(origin,largest_sphere+4.0)
	var near_hits: Array = []
	for id in near_ids:
		var sphere = tree_sphere(id)
		if origin.distance_to(Vector3(sphere.x,sphere.y,sphere.z))<sphere.w+4.0:
			near_hits.append(id)
	var result = {"issues":issues,"camera":camera_data(),"anchor":anchor,
		"distance_horizontal_m":horizontal,"camera_to_base_m":origin.distance_to(anchor),
		"nearby_canopy_proxy_ids":near_hits,"in_frame_heights_m":[],"terrain_clear_heights_m":[],
		"open_ray_heights_m":[],"ray_blockers":[],"projected_span_fraction":0.0,
		"note":"Terrain/geology rays and seated production LOD bounds only. Nearby spheres are audit data, never a veto. Bounds include empty/alpha space and wind; no pixel visibility or controller acceptance."}
	# No camera-near or whole-viewport veto. Only the three exposed shaft rays
	# intersecting finite seated LOD bounds can reject canopy; behind/side trees pass.
	var segment_ids: PackedInt32Array = field.tree_data.nearby((origin+anchor)*.5,horizontal*.5+largest_tree_radius+8.0)
	var min_y = INF
	var max_y = -INF
	var radius: float = style.radius_m
	# Entirely below navigation's own fade; no borrowing finish's 2000 m top.
	for height in range(25,int(minf(style.height_m,style.fade_start_m))+1,25):
		if expired(): issues.append("search_budget"); break
		var sample = anchor+Vector3.UP*float(height)
		var depth = -camera.to_local(sample).z
		if depth<camera.near or depth>camera.far: continue
		var screen = camera.unproject_position(sample)
		if not inset.has_point(screen): continue
		result.in_frame_heights_m.append(height)
		if not terrain_clear(origin,sample): continue
		result.terrain_clear_heights_m.append(height)
		var open = true
		for side in [-1.0,0.0,1.0]:
			var edge = sample+camera.global_basis.x*radius*side
			if not terrain_clear(origin,edge): open = false; break
			if not field.ray_geology(origin,edge).is_empty():
				result.ray_blockers.append({"height":height,"reason":"geology","side":side})
				open = false; break
			if use_canopy:
				var blocker = tree_ray_blocker(origin,edge,segment_ids)
				if blocker!=-1:
					result.ray_blockers.append({"height":height,"tree_id":blocker,"side":side})
					open = false; break
		if open:
			result.open_ray_heights_m.append(height)
			min_y = minf(min_y,screen.y); max_y = maxf(max_y,screen.y)
	result.base_terrain_clear = terrain_clear(origin,anchor+Vector3.UP*4.0)
	result.hundred_m_terrain_clear = terrain_clear(origin,anchor+Vector3.UP*100.0)
	if result.open_ray_heights_m.size()>=3: result.projected_span_fraction = (max_y-min_y)/frame.size.y
	if result.in_frame_heights_m.is_empty(): issues.append("shaft_outside_frustum")
	if result.open_ray_heights_m.size()<3: issues.append("insufficient_open_ray_samples")
	if result.projected_span_fraction<.02: issues.append("less_than_2_percent_frame_height")
	if plan.get("ridge",false) and (result.base_terrain_clear or result.hundred_m_terrain_clear):
		issues.append("ridge_lower_100m_not_hidden")
	if expired() and "search_budget" not in issues: issues.append("search_budget")
	return result

func select_views(seed: Dictionary, seconds: float = 30.0) -> Dictionary:
	deadline_ms = Time.get_ticks_msec()+int(clampf(seconds,5,45)*1000)
	receipts = []; rejected = {}; examined = 0
	var closest: Array = []
	var candidate_audit: Array = []
	var result = {"views":[],"failures":[],"search_receipts":receipts,
		"closest_rejected":closest,"candidate_audit":candidate_audit,"candidate_limit":144,
		"stop_reason":"searching","geometry_selection_complete":false,"probe_version":4}
	var bounds_started = Time.get_ticks_msec()
	var bounds_error = prepare_tree_bounds()
	result.tree_bounds_ms = Time.get_ticks_msec()-bounds_started
	if not bounds_error.is_empty():
		result.failures.append(bounds_error); result.stop_reason = "tree_bounds_input_failed"; return result
	var decoded = Race.decode(seed.selected_fixture.race_code)
	if not decoded.has("race"):
		result.failures.append("seed_race_decode"); result.stop_reason = "seed_decode_failed"; return result
	var lower: Vector3 = decoded.race.finish
	var far_seed: Dictionary = seed.selected_fixture.approaches.finish_2000m
	var far_position = vec(far_seed.position)
	var fixed = {"label":"navigation_2000m_ridge","anchor":lower,"position":far_position,
		"heading":float(far_seed.heading),"kmh":float(far_seed.kmh),"distance_m":2000.0,"ridge":true,
		"roles":["2000m","ridge"],"origin":"finish selection-diag-parent-v2; immutable anchor and pose"}
	var fixed_probe = evaluate(fixed)
	var expected: Dictionary = far_seed.selection_camera_trace[-1]
	var camera_matches: bool = camera.global_position.distance_to(vec(expected.position))<.1 and absf(camera.fov-float(expected.fov))<.001 and camera.global_rotation.distance_to(vec(expected.rotation))<.001
	fixed_probe.seed_camera_matches = camera_matches
	if not camera_matches: fixed_probe.issues.append("seed_camera_pose_changed")
	receipts.append({"kind":"fixed_2000m_ridge","plan":fixed,"probe":fixed_probe})
	result.fixed_anchor = lower; result.fixed_plan = fixed
	if not fixed_probe.issues.is_empty():
		result.failures.append("fixed_2000m_ridge: "+str(fixed_probe.issues))
		result.stop_reason = "fixed_revalidation_failed"; return result
	# This independent positive view survives every subsequent 500 m search failure.
	result.views.append(fixed)
	var failed: Dictionary = seed.selected_fixture.approaches.finish_500m
	var control = {"anchor":lower,"position":vec(failed.position),"heading":float(failed.heading),
		"kmh":float(failed.kmh),"distance_m":500.0,"ridge":false}
	var control_probe = evaluate(control)
	var control_tree_hit = false
	for blocker in control_probe.get("ray_blockers",[]):
		if int(blocker.get("tree_id",-1))>=0: control_tree_hit = true
	result.negative_control_rejected = not control_probe.issues.is_empty() and control_tree_hit and "search_budget" not in control_probe.issues
	receipts.append({"kind":"known_opaque_forest_control","plan":control,"probe":control_probe,
		"pixel_evidence":"finish/500m-foliage-parent-v3; opaque native negative, never a capture candidate"})
	if not result.negative_control_rejected:
		# A false positive is a real failure. Still capture independent positive views.
		result.failures.append("known_opaque_forest_control_not_rejected")
	var uphill = Vector3(far_position.x-lower.x,0,far_position.z-lower.z).normalized()
	var side = Vector3(-uphill.z,0,uphill.x)
	var observer_count = 0
	var found = false
	var navigation_fallback: Dictionary = {}
	# V3's anchors stopped at 2,801 m. Begin instead at the proven open 3,546 m
	# observer, then nearby upper snow. All changes are rider position/heading only.
	# Six observers x 24 real anchors; prefer a shared navigation/finish candidate.
	for offset in [Vector2.ZERO,Vector2(150,0),Vector2(300,0),Vector2(0,120),Vector2(0,-120),Vector2(150,120)]:
		if expired() or found: break
		observer_count += 1
		var support = Navigation.anchor(field,far_position+uphill*offset.x+side*offset.y)
		if not support.error.is_empty():
			receipts.append({"kind":"upper_observer_rejected","offset":offset,"reason":support.error}); continue
		var position: Vector3 = support.position
		var observer_error: String = Race.point_error(position,field)
		if not observer_error.is_empty():
			receipts.append({"kind":"upper_observer_rejected","position":position,"offset":offset,"reason":observer_error}); continue
		for i in 24:
			if expired() or examined>=144: break
			examined += 1
			# Start with the known downhill direction, then alternate +/-15, +/-30...
			var step = 0 if i==0 else (ceili(float(i)/2.0) if i%2==1 else -i/2)
			var heading = float(far_seed.heading)+TAU*float(step)/24.0
			var requested = position+Vector3(sin(heading),0,cos(heading))*500.0
			var anchored = Navigation.anchor(field,requested)
			var audit = {"observer":position,"observer_offset_from_open_seed":offset,
				"requested_anchor":requested,"heading":heading,"issues":[],"open_sample_count":0,"nearby_canopy_count":0}
			candidate_audit.append(audit)
			if not anchored.error.is_empty():
				audit.issues.append("anchor_snow: "+anchored.error)
				for reason in audit.issues: rejected[reason] = rejected.get(reason,0)+1
				continue
			var anchor: Vector3 = anchored.position
			audit.anchor = anchor
			# Prefer an anchor reusable by finish, without tightening navigation rules.
			var finish_error: String = Race.point_error(anchor,field)
			audit.finish_point_error = finish_error
			var plan = {"label":"navigation_500m_1","anchor":anchor,"position":position,
				"heading":heading,"kmh":60.0,"distance_m":500.0,"ridge":false,"roles":["500m"],
				"observer_offset_from_open_seed":offset,"finish_point_error":finish_error,
				"origin":"500 m supported anchor around proven upper observer; default Connected 60 km/h"}
			var current = evaluate(plan)
			audit.issues = current.issues
			audit.open_sample_count = current.get("open_ray_heights_m",[]).size()
			audit.in_frame_sample_count = current.get("in_frame_heights_m",[]).size()
			audit.terrain_clear_sample_count = current.get("terrain_clear_heights_m",[]).size()
			audit.nearby_canopy_count = current.get("nearby_canopy_proxy_ids",[]).size()
			if not current.issues.is_empty():
				for reason in current.issues: rejected[reason] = rejected.get(reason,0)+1
				closest.append({"plan":plan,"probe":current,"score":audit.open_sample_count})
				closest.sort_custom(func(a,b): return a.score>b.score if a.score!=b.score else a.plan.position.y>b.plan.position.y)
				if closest.size()>3: closest.resize(3)
				continue
			plan.selection_probe = current
			if not finish_error.is_empty():
				if navigation_fallback.is_empty(): navigation_fallback = plan
				continue
			result.views.append(plan); found = true; break
	var shared_found = found
	if not found and not navigation_fallback.is_empty():
		result.views.append(navigation_fallback); found = true
	result.shared_finish_fixture = found and result.views[-1].finish_point_error.is_empty()
	result.rejections = rejected
	result.candidates_examined = examined
	result.observers_examined = observer_count
	result.search_budget_exhausted = expired()
	result.geometry_selection_complete = found and result.negative_control_rejected
	result.stop_reason = "first_shared_500m_candidate_ready_for_pixels" if shared_found else ("search_budget" if expired() else "upper_observer_candidates_exhausted")
	if found and not shared_found: result.stop_reason += "_navigation_only_fallback_retained"
	if not found: result.failures.append("no_500m_open_snow_candidate")
	result.scope = "Independent fixed lower 2 km/ridge plus at most one upper 500 m fixture, preferring finish-eligible support; geometry/bounds are not pixel acceptance"
	return result

static func vec(value: Array) -> Vector3:
	return Vector3(float(value[0]),float(value[1]),float(value[2]))

static func json_safe(value: Variant) -> Variant:
	if value is Vector3: return [value.x,value.y,value.z]
	if value is Vector2 or value is Vector2i: return [value.x,value.y]
	if value is Vector4 or value is Color: return [value[0],value[1],value[2],value[3]]
	if value is Basis: return [json_safe(value.x),json_safe(value.y),json_safe(value.z)]
	if value is Dictionary:
		var result: Dictionary = {}
		for key in value: result[key] = json_safe(value[key])
		return result
	if value is Array:
		var result: Array = []
		for item in value: result.append(json_safe(item))
		return result
	return value

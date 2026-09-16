extends SceneTree
## Diagnostic only: preserve existing natural openings without retaining routes.
const Cache = preload("res://scripts/world/mountain_cache_v15.gd")
const Search = preload("res://tests/generation_route_search.gd")
func _initialize() -> void: call_deferred("run")
static func opening(field, p: Vector2, radius: float = 0) -> bool:
	for face in field.adjacent_faces(p):
		var q: Vector2 = face.to_local(p)
		if face.sector_weight(q.x,q.y)<.01: continue
		for offset in [Vector2.ZERO,Vector2(radius,0),Vector2(-radius,0),Vector2(0,radius),Vector2(0,-radius)]:
			var at = q+offset
			if face.woodland_opening(at) or face.snow_gap(at.x,at.y)>.25: return true
			# Drainage protection reaches the shared junction, even where the
			# height cut tapers to avoid sharp seams.
			for channel_id in face.channel_grid.get(Vector2i(floori(at.x/face.REGION_CELL),floori(at.y/face.REGION_CELL)),[]):
				var channel = face.channels[channel_id]
				var t = clampf((at.y-channel.start.y)/(channel.finish.y-channel.start.y),0,1)
				var centre = Vector2(lerpf(channel.start.x,channel.finish.x,t)+channel.bend*sin(t*PI)*sin(t*PI+channel.phase),lerpf(channel.start.y,channel.finish.y,t))
				if at.distance_to(centre)<channel.width*.55+12: return true
	return false
func run() -> void:
	var settings = Cache.Settings.preset(3); settings.tree_spacing = .5
	var field = Cache.generate(849205174,settings); var job = Cache.Job.new()
	field.geology.reserved = {}; var mineral_count = 0
	for placed in field.geology.placements:
		var record: Dictionary = field.geology.catalog.records[placed.asset]
		if not opening(field,Vector2(placed.pose.origin.x,placed.pose.origin.z),Vector2(record.size_m.x,record.size_m.z).length()*.6+2):
			field.geology._reserve(placed,record); mineral_count += 1
	print("DRAINAGE_MINERALS ",mineral_count)
	var trees = Cache.Terrain.Trees.new()
	for id in field.tree_data.size():
		var p: Vector3 = field.tree_data.positions[id]
		if opening(field,Vector2(p.x,p.z),field.tree_data.dimensions[id].x+1): continue
		var d: Vector3 = field.tree_data.dimensions[id]
		trees.append(p,d.x,d.y,d.z,field.tree_data.yaws[id],field.tree_data.candidate_ids[id],field.tree_data.ecology[id]==1)
	trees.build_index(); field.tree_data = trees
	print("DRAINAGE_TREES ",trees.size())
	var results = job.map_tiles(49,func(tile):
		var bytes = PackedByteArray()
		for z in range(tile*32,mini(field.NZ,(tile+1)*32)):
			for x in field.NX:
				var value = field.material_image.get_pixel(x,z).r
				if value>0 and field.final_normals[z*field.NX+x].y>=.60 and opening(field,Vector2(field.X_MIN+x*4,field.Z_MIN+z*4)):
					value *= .15
				bytes.append(roundi(value*255))
		return bytes)
	var bytes = PackedByteArray(); for part in results: bytes.append_array(part)
	field.material_image = Image.create_from_data(field.NX,field.NZ,false,Image.FORMAT_R8,bytes)
	print("OPENINGS_PROTOTYPE trees=",trees.size()," minerals=",mineral_count)
	var rows: Array = []; var success = true
	for route in job.map_tiles(6,func(face): return Search.survey(field,face,.6,.5)):
		var connected = not route.paths[0].is_empty() and not route.paths[1].is_empty()
		var spread = route.paths[0][-1].distance_to(route.paths[1][-1]) if connected else 0.0
		success = success and connected and spread>=500
		rows.append({"face":route.face,"connected":connected,"spread_m":spread,"visited":route.safe_samples,"refinement":route.refinement,"reachable_rows":route.get("reachable_columns",[])})
	var report = {"diagnostic_only":true,"trees":trees.size(),"minerals":mineral_count,"routes":rows,"pass":success}
	preload("res://tests/test_report.gd").write("res://artifacts/generation_v15/openings_probe.json",JSON.stringify(report,"\t"))
	print("OPENINGS_ROUTES ",JSON.stringify(report)); quit(0 if success else 1)

extends RefCounted
const Terrain = preload("res://scripts/world/generators/alpine_massif_v17.gd")
const Face = preload("res://scripts/world/generators/alpine_face_v17.gd")
const Settings = preload("res://scripts/world/generation_settings.gd")
const Job = preload("res://scripts/world/generation_job.gd")
const Archive = preload("res://scripts/world/mountain_archive.gd")
const Sources = preload("res://scripts/world/generation_sources.gd")
const DIRECTORY = Archive.DIRECTORY
const FACE_FIELDS = ["landforms","bowls","shelves","channels","channel_grid","stands","clearings","ecology_grid","forest_passages","debris_pockets","crags","ribs","rib_grid","powder_deposits","geology_angle","ruggedness","forest_cover","wind_angle","treeline_height","snow_forms","snow_grid","bowl_grid","shelf_grid","crag_grid"]

static func recipe_key(seed_number: int, settings: Dictionary = {}) -> String:
	return ("v18|%d|%s" % [seed_number,Settings.identity(settings)]).sha256_text()

static func cache_key(seed_number: int, settings: Dictionary = {}, job = null) -> String:
	var signature = Sources.signature(false,job)
	if signature.is_empty(): return ""
	return (recipe_key(seed_number,settings)+"|"+signature+"|"+Sources.engine_identity()).sha256_text()

static func path_for(seed_number: int, settings: Dictionary = {}) -> String:
	return DIRECTORY.path_join(recipe_key(seed_number,settings)+".physical")

static func generate(seed_number: int, settings: Dictionary = {}, context = null):
	if not preload("res://scripts/diagnostics/test_world_policy.gd").require_full("Mountain generation/restoration"): return null
	var job = context if context else Job.new()
	var canonical = Settings.canonical(settings)
	if canonical.is_empty() or job.is_cancelled(): return null
	var key = cache_key(seed_number,canonical,job); var path = path_for(seed_number,canonical)
	var paths = [path]
	if seed_number==Terrain.DEFAULT_SEED and canonical==Settings.preset() and not OS.has_feature("editor"):
		paths.append(OS.get_executable_path().get_base_dir().path_join("data/default_mountain_v18.physical"))
	for candidate in paths:
		var begin = Time.get_ticks_usec(); job.begin_stage("physical_cache_read")
		var data = Archive.read(candidate,key,job)
		if job.is_cancelled(): return null
		if data.is_empty(): continue
		var field = restore(seed_number,canonical,data,job)
		if field==null: continue
		field.cache_hit = true; field.generation_ms = (Time.get_ticks_usec()-begin)/1000.0
		job.end_stage("physical_cache_read")
		field.generation_stages = job.snapshot().timings_ms
		field.generation_stages.original_bake_ms = data.meta.bake_ms
		field.generation_stages.cache_source = "user" if candidate==path else "bundled"
		if not preload("res://scripts/diagnostics/test_world_policy.gd").automated(): Archive.touch(recipe_key(seed_number,canonical))
		return field
	if preload("res://scripts/diagnostics/test_world_policy.gd").automated():
		push_error("VALIDATION_CACHE_MISS: Prepare this exact mountain explicitly with tests/prepare_validation_mountain.gd under an Exclusive guard. No cold bake was started.")
		return null
	var field = Terrain.new(seed_number,true,canonical,job)
	if not field.valid or job.is_cancelled(): return null
	job.begin_stage("physical_cache_write")
	if not key.is_empty(): Archive.write(path,key,sections(field),job)
	job.end_stage("physical_cache_write")
	if job.is_cancelled(): return null
	Archive.touch(recipe_key(seed_number,canonical))
	Archive.evict(recipe_key(Terrain.DEFAULT_SEED),-1,recipe_key(seed_number,canonical))
	field.generation_stages = job.snapshot().timings_ms
	return field

static func sections(field) -> Array:
	var trees = field.tree_data
	var result: Array = [{"name":"meta","value":{"schema":1,"seed":field.seed_value,"settings":field.generation_settings,
		"height_sha256":field.height_checksum,"obstacle_sha256":field.obstacle_checksum,"bake_ms":field.generation_ms,"stages":field.generation_stages,
		"population":field.population,"snow_statistics":field.tree_snow_statistics,"geology_statistics":field.geology.statistics,
		"tree_cell":trees.cell,"tree_side":trees.side,"tree_max_radius":trees.max_radius,"features":field.features,"powder_deposits":field.powder_deposits}}]
	for pair in [["heights",field.heights],["tree_snow",field.tree_snow_height],["exposure",field.exposure_image.get_data()],["material",field.material_image.get_data()],
		["normals",field.final_normals],["tree_positions",trees.positions],["tree_dimensions",trees.dimensions],["tree_yaws",trees.yaws],["tree_ids",trees.candidate_ids],["tree_ecology",trees.ecology],["tree_heads",trees.heads],["tree_links",trees.links]]:
		Archive.append_packed(result,pair[0],pair[1])
	for face in field.faces:
		var data: Dictionary = {}
		for name in FACE_FIELDS: data[name] = face.get(name)
		result.append({"name":"face/%d" % face.index,"value":data})
	Archive.append_packed(result,"placements",field.geology.placements,128)
	Archive.append_packed(result,"collision_grid",_grid_rows(field.geology.collision.grid),512)
	var entries: Array = []
	for entry in field.geology.collision.entries:
		var record: Dictionary = entry.duplicate(); record.erase("source"); entries.append(record)
	Archive.append_packed(result,"collision",entries,32)
	return result

static func _grid_rows(grid: Dictionary) -> Array:
	var rows: Array = []
	for key in grid: rows.append([key,PackedInt32Array(grid[key])])
	return rows

static func restore(seed_number: int, settings: Dictionary, data: Dictionary, job):
	if not preload("res://scripts/diagnostics/test_world_policy.gd").require_full("Mountain generation/restoration"): return null
	var meta = data.get("meta")
	if not meta is Dictionary or meta.get("schema")!=1 or meta.get("seed")!=seed_number or meta.get("settings")!=settings: return null
	var field = Terrain.new(seed_number,false,settings,job,true)
	for pair in [["heights","heights",PackedFloat32Array(),1537*1537],["tree_snow","tree_snow_height",PackedFloat32Array(),1537*1537],["normals","final_normals",PackedVector3Array(),1537*1537]]:
		var values = Archive.unpack(data,pair[0],pair[2],pair[3])
		if values==null or values.size()!=pair[3]: return null
		field.set(pair[1],values)
	var exposure = Archive.unpack(data,"exposure",PackedByteArray(),1537*1537*4)
	var material = Archive.unpack(data,"material",PackedByteArray(),1537*1537)
	if exposure==null or material==null or exposure.size()!=1537*1537*4 or material.size()!=1537*1537: return null
	field.exposure_image = Image.create_from_data(field.NX,field.NZ,false,Image.FORMAT_RGBA8,exposure)
	field.material_image = Image.create_from_data(field.NX,field.NZ,false,Image.FORMAT_R8,material)
	var trees = field.tree_data
	for pair in [["tree_positions","positions",PackedVector3Array()],["tree_dimensions","dimensions",PackedVector3Array()],["tree_yaws","yaws",PackedFloat32Array()],["tree_ids","candidate_ids",PackedInt64Array()],["tree_ecology","ecology",PackedByteArray()],["tree_heads","heads",PackedInt32Array()],["tree_links","links",PackedInt32Array()]]:
		var values = Archive.unpack(data,pair[0],pair[2],1000000)
		if values==null: return null
		trees.set(pair[1],values)
	if meta.get("tree_cell")!=48.0 or meta.get("tree_side")!=128: return null
	trees.cell = 48.0; trees.side = 128; trees.max_radius = meta.get("tree_max_radius",0.0)
	if not trees.valid(): return null
	for id in trees.size():
		if id%4096==0 and job.is_cancelled(): return null
		if trees.links[id]<-1 or trees.links[id]>=id or not trees.positions[id].is_finite() or not trees.dimensions[id].is_finite(): return null
	for id in trees.heads:
		if id<-1 or id>=trees.size(): return null
	for i in 6:
		var saved = data.get("face/%d" % i)
		if not saved is Dictionary or saved.size()!=FACE_FIELDS.size(): return null
		var face = Face.new(field,i,field.face_phase+TAU*i/6,false)
		for name in FACE_FIELDS:
			if not saved.has(name): return null
			face.set(name,saved[name])
		field.faces.append(face)
	var placements = Archive.unpack(data,"placements",[],100000,128)
	var entries = Archive.unpack(data,"collision",[],100000,32)
	var grid = Archive.unpack(data,"collision_grid",[],65536,512)
	if placements==null or entries==null or grid==null or placements.size()!=entries.size(): return null
	field.geology.placements = placements; field.geology.statistics = meta.geology_statistics
	for entry in entries:
		if not entry is Dictionary or not field.geology.catalog.records.has(entry.get("record")): return null
		entry.source = field.geology.catalog.records[entry.record]
	field.geology.collision.entries = entries
	for row in grid:
		if not row is Array or row.size()!=2 or not row[0] is Vector2i or not row[1] is PackedInt32Array: return null
		for id in row[1]:
			if id<0 or id>=entries.size(): return null
		field.geology.collision.grid[row[0]] = row[1]
	field.geology._rebuild_reservations(); field.geology._freeze()
	field.height_checksum = meta.height_sha256; field.obstacle_checksum = meta.obstacle_sha256
	field.population = meta.population; field.tree_snow_statistics = meta.snow_statistics
	field.features.assign(meta.features); field.powder_deposits.assign(meta.powder_deposits)
	field.valid = true
	return field

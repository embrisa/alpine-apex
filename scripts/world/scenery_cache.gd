extends RefCounted
const Physical = preload("res://scripts/world/mountain_cache_v17.gd")
const Archive = preload("res://scripts/world/mountain_archive.gd")
const Sources = preload("res://scripts/world/generation_sources.gd")
const Terrain = preload("res://scripts/world/terrain_preparation.gd")

# Pure display consumers: neither creates arrays persisted by save(). Keep them
# in GenerationSources' complete export manifest, but not in the bake identity.
const DISPLAY_ONLY = [
	"res://scripts/presentation/foliage_sight.gd",
	"res://assets/graphics/foliage_sight.gdshaderinc"]

static func key(field, quality, job = null) -> String:
	var source = source_signature(job)
	if source.is_empty(): return ""
	return _key(source,Sources.engine_identity(),field.height_checksum,field.obstacle_checksum,quality.level)

static func _key(source: String, engine: String, height: String, obstacles: String, level: int) -> String:
	if source.is_empty(): return ""
	return ("scenery-v2|%s|%s|%s|%s|%d" % [source,engine,height,obstacles,level]).sha256_text()

static func source_signature(job = null) -> String:
	if job and job.is_cancelled(): return ""
	if OS.has_feature("generation_export"):
		# Preserve the existing schema, engine and complete-package validation.
		var validated = Sources.signature(true,job)
		if validated.is_empty(): return ""
		var manifest = JSON.parse_string(FileAccess.get_file_as_string(Sources.MANIFEST))
		return _export_signature(manifest,validated,job)
	var values: Dictionary = {}
	for path in Sources.dependencies(true):
		if job and job.is_cancelled(): return ""
		if path in DISPLAY_ONLY: continue
		if not FileAccess.file_exists(path): return ""
		values[path] = FileAccess.get_sha256(path)
	return _bake_signature(values,job)

static func _export_signature(manifest: Variant, validated: String, job = null) -> String:
	if job and job.is_cancelled(): return ""
	if not manifest is Dictionary or validated.length()!=64: return ""
	var values = manifest.get("scenery")
	if not values is Dictionary: return ""
	# Bind this read to the complete receipt already accepted by Sources.
	if manifest.get("scenery_sha256")!=validated or JSON.stringify(values,"",true,true).sha256_text()!=validated: return ""
	return _bake_signature(values,job)

static func _bake_signature(values: Dictionary, job = null) -> String:
	for path in Sources.PHYSICAL+Sources.SCENERY:
		if path not in DISPLAY_ONLY and not values.has(path): return ""
	var bake: Dictionary = {}
	for path in values:
		if job and job.is_cancelled(): return ""
		if path in DISPLAY_ONLY: continue
		if not values[path] is String or values[path].length()!=64: return ""
		bake[path] = values[path]
	return JSON.stringify(bake,"",true,true).sha256_text()

static func path_for(field) -> String:
	return Archive.DIRECTORY.path_join(Physical.recipe_key(field.seed_value,field.generation_settings)+".scenery")

static func save(prepared, field, quality, job, archive_path: String = "") -> bool:
	var cache_key = key(field,quality,job)
	if cache_key.is_empty(): return false
	var sections: Array = [{"name":"meta","value":{"schema":2,"seed":field.seed_value,"height":field.height_checksum,"obstacles":field.obstacle_checksum,
		"origin":prepared.mountain.ORIGIN,"scenery_height":prepared.mountain.height_checksum,"scenery_environment":prepared.mountain.environment_checksum,
		"assets":prepared.forest.assets,"family_counts":prepared.forest.family_counts,"macro_bounds":prepared.macro_bounds,
		"readability_origin":prepared.readability.origin,"readability_cell":prepared.readability.cell_m}}]
	for pair in [["height",prepared.mountain.height_image.get_data()],["environment",prepared.mountain.environment_image.get_data()],
		["readability",prepared.readability.image.get_data()],["tree_poses",prepared.forest.poses],["tree_assets",prepared.forest.asset_indices],["tree_positions",prepared.forest.positions]]:
		Archive.append_packed(sections,pair[0],pair[1])
	sections.append({"name":"terrain_indices","value":prepared.terrain.indices}); sections.append({"name":"terrain_lods","value":prepared.terrain.lods})
	Archive.append_packed(sections,"terrain",prepared.terrain.chunks,8)
	var regions: Array = []
	for region in prepared.forest.regions:
		for asset in prepared.forest.regions[region]:
			var group: Dictionary = prepared.forest.regions[region][asset]
			regions.append([region,asset,group.prepared.buffer,group.prepared.bounds,group.height_m])
	Archive.append_packed(sections,"forest_regions",regions,64)
	var far: Array = []
	for name in prepared.forest.far_groups:
		var group: Dictionary = prepared.forest.far_groups[name]
		far.append([name,group.asset,group.prepared.buffer,group.prepared.bounds,group.height_m])
	Archive.append_packed(sections,"forest_far",far,8)
	Archive.append_packed(sections,"minerals",prepared.minerals,64)
	var result = Archive.write(path_for(field) if archive_path.is_empty() else archive_path,cache_key,sections,job)
	if result and archive_path.is_empty():
		Archive.touch(Physical.recipe_key(field.seed_value,field.generation_settings))
		Archive.evict(Physical.recipe_key(Physical.Terrain.DEFAULT_SEED),-1,Physical.recipe_key(field.seed_value,field.generation_settings))
	return result

static func load_into(prepared, field, quality, job, archive_path: String = "") -> bool:
	# Decode into an unpublished object: structural failure must not contaminate
	# the subsequent fresh preparation or a previously valid caller result.
	var candidate = prepared.get_script().new()
	if not _decode_into(candidate,field,quality,job,archive_path) or job.is_cancelled(): return false
	for member in ["mountain","terrain","forest","readability","minerals","macro_bounds"]:
		prepared.set(member,candidate.get(member))
	return true

static func _decode_into(prepared, field, quality, job, archive_path: String = "") -> bool:
	var local_path = path_for(field) if archive_path.is_empty() else archive_path
	var bundled_path = OS.get_executable_path().get_base_dir().path_join("data/default_mountain_v18.scenery")
	var bundled = archive_path.is_empty() and field.seed_value==Physical.Terrain.DEFAULT_SEED and field.generation_settings==Physical.Settings.preset() and FileAccess.file_exists(bundled_path)
	if not FileAccess.file_exists(local_path) and not bundled: return false
	var cache_key = key(field,quality,job)
	var data = Archive.read(local_path,cache_key,job)
	if data.is_empty() and bundled and not job.is_cancelled():
		data = Archive.read(bundled_path,cache_key,job)
	if data.is_empty() or job.is_cancelled(): return false
	var meta = data.get("meta")
	if not meta is Dictionary or meta.get("schema")!=2 or meta.get("height")!=field.height_checksum or meta.get("obstacles")!=field.obstacle_checksum: return false
	var height = Archive.unpack(data,"height",PackedByteArray(),2048*2048*4)
	var environment = Archive.unpack(data,"environment",PackedByteArray(),257*257*4)
	var readability = Archive.unpack(data,"readability",PackedByteArray(),1537*1537*2)
	if height==null or environment==null or readability==null or height.size()!=2048*2048*4 or environment.size()!=257*257*4: return false
	prepared.mountain.ORIGIN = meta.origin; prepared.mountain.seed_value = field.seed_value
	prepared.mountain.physics_authority = "alpine-drainage-v18"
	prepared.mountain.height_image = Image.create_from_data(2048,2048,false,Image.FORMAT_RF,height)
	prepared.mountain.environment_image = Image.create_from_data(257,257,false,Image.FORMAT_RGBA8,environment)
	prepared.mountain.height_checksum = meta.scenery_height; prepared.mountain.environment_checksum = meta.scenery_environment
	prepared.readability.image = Image.create_from_data(1537,1537,true,Image.FORMAT_R8,readability)
	prepared.readability.origin = meta.readability_origin; prepared.readability.cell_m = meta.readability_cell
	for pair in [["tree_poses","poses",PackedFloat32Array(),12000000],["tree_assets","asset_indices",PackedInt32Array(),1000000],["tree_positions","positions",PackedVector3Array(),1000000]]:
		var values = Archive.unpack(data,pair[0],pair[2],pair[3])
		if values==null: return false
		prepared.forest.set(pair[1],values)
	if prepared.forest.positions.size()!=field.tree_data.size() or prepared.forest.asset_indices.size()!=field.tree_data.size() or prepared.forest.poses.size()!=field.tree_data.size()*12: return false
	prepared.forest.assets = meta.assets; prepared.forest.family_counts = meta.family_counts
	var terrain = Archive.unpack(data,"terrain",[],576,8)
	var minerals = Archive.unpack(data,"minerals",[],100000,64)
	var regions = Archive.unpack(data,"forest_regions",[],524288,64)
	var far = Archive.unpack(data,"forest_far",[],20000,8)
	if terrain==null or minerals==null or regions==null or far==null or terrain.is_empty() or terrain.size()>576: return false
	var expected_chunks: Dictionary={}
	for z in range(0,1536,64):
		for x in range(0,1536,64):
			var origin=Vector2(field.X_MIN+x*4,field.Z_MIN+z*4)
			var clip=Terrain.footprint_indices(origin)
			if clip.mode!=0: expected_chunks[origin+Vector2.ONE*128]=clip
	if terrain.size()!=expected_chunks.size(): return false
	for chunk in terrain:
		if not chunk is Dictionary or not chunk.get("vertices") is PackedVector3Array or not chunk.get("normals") is PackedVector3Array or chunk.vertices.size()!=4225 or chunk.normals.size()!=4225: return false
		if not expected_chunks.has(chunk.get("center")): return false
		var expected: Dictionary=expected_chunks[chunk.center]; expected_chunks.erase(chunk.center)
		if expected.mode==2:
			if chunk.get("indices")!=expected.indices or chunk.get("lods")!={}: return false
		elif chunk.has("indices") or chunk.has("lods"): return false
	if not data.get("terrain_indices") is PackedInt32Array or not data.get("terrain_lods") is Dictionary: return false
	prepared.terrain.chunks = terrain; prepared.terrain.indices = data.terrain_indices; prepared.terrain.lods = data.terrain_lods
	var near_count = 0; var far_count = 0
	for row in regions:
		if job.is_cancelled(): return false
		if not row is Array or row.size()!=5 or not row[0] is Vector2i or not row[2] is PackedFloat32Array or row[2].size()%12!=0: return false
		if not prepared.forest.regions.has(row[0]): prepared.forest.regions[row[0]] = {}
		prepared.forest.regions[row[0]][row[1]] = _group(row)
		near_count += row[2].size()/12
	for row in far:
		if job.is_cancelled(): return false
		if not row is Array or row.size()!=5 or not row[0] is String or not row[2] is PackedFloat32Array or row[2].size()%12!=0: return false
		prepared.forest.far_groups[row[0]] = _group(row)
		far_count += row[2].size()/12
	if near_count!=field.tree_data.size() or far_count!=field.tree_data.size(): return false
	prepared.minerals = minerals; prepared.macro_bounds = meta.macro_bounds
	return true

static func _group(row: Array) -> Dictionary:
	return {"asset":row[1],"transforms":[],"height_m":row[4],"prepared":{"buffer":row[2],"bounds":row[3],"multimeshes":{}}}

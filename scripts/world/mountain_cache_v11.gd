extends RefCounted
## Two disposable bake slots (default and most recent random mountain). Source
## and engine identity invalidate the cache; recipes and saves never depend on it.
const Terrain = preload("res://scripts/world/generators/alpine_massif_v11.gd")
const DIRECTORY = "user://mountain_bake_cache_v11"
static func generate(seed_value: int):
	var begin = Time.get_ticks_usec()
	var key = "%d|%s" % [seed_value,Engine.get_version_info().string]
	for path in ["res://scripts/world/generators/alpine_massif_v11.gd","res://scripts/world/generators/alpine_face_v10.gd","res://scripts/world/heightfield_surface.gd","res://scripts/world/mountain_geology.gd","res://scripts/world/mineral_catalog.gd","res://scripts/world/mineral_catalog_data.gd","res://scripts/world/mineral_collision.gd","res://assets/graphics/geology_v11/catalog.json","res://assets/graphics/geology_v11/catalog.res"]:
		# Exported builds without source files simply reconstruct the generator.
		if not FileAccess.file_exists(path): return Terrain.new(seed_value)
		key += "|"+FileAccess.get_sha256(path)
	var path = DIRECTORY.path_join("default.bin" if seed_value==Terrain.DEFAULT_SEED else "recent.bin")
	var file = FileAccess.open(path,FileAccess.READ)
	if file and file.get_length()<64*1024*1024:
		var data = file.get_var(false)
		file.close()
		if _valid(data,key):
			var field = Terrain.new(seed_value,false)
			field.heights = data.heights
			field.exposure_image = Image.create_from_data(field.NX,field.NZ,false,Image.FORMAT_RGBA8,data.exposure)
			for ob in data.obstacles: field.add_obstacle(ob)
			field.geology.restore(data.placements,data.geology_statistics)
			field.height_checksum = data.height_sha256
			field.obstacle_checksum = data.obstacle_sha256
			field.cache_hit = true
			field.generation_ms = (Time.get_ticks_usec()-begin)/1000.0
			field.generation_stages = {"cache_load_ms":field.generation_ms,"original_bake_ms":data.bake_ms}
			return field
	var field = Terrain.new(seed_value)
	if DirAccess.make_dir_recursive_absolute(DIRECTORY)==OK:
		var temp = path+".%d.%d.tmp" % [OS.get_process_id(),Time.get_ticks_usec()]
		file = FileAccess.open(temp,FileAccess.WRITE)
		if file:
			var payload = {"key":key,"heights":field.heights,"obstacles":field.obstacles,"exposure":field.exposure_image.get_data(),"height_sha256":field.height_checksum,"obstacle_sha256":field.obstacle_checksum,"bake_ms":field.generation_ms,"placements":field.geology.placements,"geology_statistics":field.geology.statistics}
			payload.payload_sha256 = Terrain._digest(var_to_bytes(payload))
			file.store_var(payload,false)
			file.flush()
			var ok = file.get_error()==OK
			file.close()
			if not ok or DirAccess.rename_absolute(temp,path)!=OK: DirAccess.remove_absolute(temp)
	return field

static func _valid(data: Variant,key: String) -> bool:
	if not data is Dictionary or data.get("key")!=key or data.size()!=10: return false
	if not data.get("heights") is PackedFloat32Array or data.heights.size()!=1537*1537: return false
	if not data.get("exposure") is PackedByteArray or data.exposure.size()!=1537*1537*4: return false
	if not data.get("obstacles") is Array or data.obstacles.size()>100000: return false
	if not data.get("placements") is Array or data.placements.size()>20000 or not data.get("geology_statistics") is Dictionary: return false
	var checksum = data.get("payload_sha256","")
	var payload: Dictionary = data.duplicate()
	payload.erase("payload_sha256")
	return checksum==Terrain._digest(var_to_bytes(payload)) and Terrain._digest(data.heights.to_byte_array())==data.get("height_sha256")

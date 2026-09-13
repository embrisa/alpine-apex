extends RefCounted
## Export-time source identity bridges source .gd and exported compiled scripts.
const MANIFEST = "res://config/generation_dependencies.json"
static var engine_mutex = Mutex.new()
static var executable_digest: String = ""
const PHYSICAL = [
	"res://scripts/world/generation_sources.gd",
	"res://scripts/world/generation_settings.gd","res://scripts/world/generation_job.gd","res://scripts/world/packed_trees.gd",
	"res://scripts/world/heightfield_surface.gd","res://scripts/world/generators/alpine_massif_v15.gd","res://scripts/world/generators/alpine_face_v15.gd",
	"res://scripts/world/generators/tree_snow_v15.gd","res://scripts/world/mountain_geology_v15.gd","res://scripts/world/mineral_catalog.gd",
	"res://scripts/world/mineral_catalog_data.gd","res://scripts/world/mineral_collision.gd","res://scripts/world/mountain_cache_v15.gd","res://scripts/world/mountain_archive.gd",
	"res://assets/graphics/geology_v11/catalog.json","res://assets/graphics/geology_v11/catalog.res"]
const SCENERY = [
	"res://scripts/presentation/terrain_grass.gd","res://scripts/presentation/grass_placement.gd","res://scripts/presentation/grass_motion.gd",
	"res://assets/graphics/terrain_grass.gdshader","res://assets/graphics/grass_motion.gdshaderinc","res://assets/graphics/mineral_grass.gdshader",
	"res://assets/graphics/grass/manifest.json","res://assets/graphics/geology_v11/textures/grass.png",
	"res://scripts/world/mountain_footprint.gd",
	"res://scripts/world/mountain_preparation.gd","res://scripts/world/scenery_cache.gd","res://scripts/world/terrain_preparation.gd",
	"res://scripts/world/mountain_data.gd","res://scripts/world/alpine_world.gd","res://scripts/world/alpine_scenery.gd",
	"res://scripts/presentation/forest_placement.gd","res://scripts/presentation/density_forest.gd","res://scripts/presentation/tree_motion.gd",
	"res://scripts/presentation/mineral_scenery.gd","res://scripts/presentation/asset_snow_contacts.gd","res://scripts/presentation/snow_readability.gd",
	"res://scripts/presentation/alpine_assets.gd","res://scripts/presentation/graphics_quality.gd","res://scripts/presentation/graphics_presets.gd",
	"res://scripts/presentation/foliage_sight.gd","res://assets/graphics/foliage_sight.gdshaderinc",
	"res://assets/graphics/trees/manifest.json","res://assets/graphics/trees/branches.json",
	"res://scripts/art/tree_collection_post_import.gd",
	"res://assets/graphics/pc_forest_tree.gdshader","res://assets/graphics/pc_forest_shadow.gdshader",
	"res://assets/graphics/pc_tree_impostor.gdshader","res://assets/graphics/pc_lod.gdshaderinc"]

static func dependencies(scenery: bool = false) -> Array:
	var paths: Array = PHYSICAL.duplicate()
	if scenery:
		paths.append_array(SCENERY)
		# Include prepared footprints and actual tree mesh assets, not only filenames.
		for directory in ["res://assets/graphics/grass","res://assets/graphics/trees/models","res://assets/graphics/trees/textures","res://assets/graphics/geology_v11/meshes"]:
			for name in DirAccess.get_files_at(directory):
				if name.get_extension() in ["res","glb","import","png"]: paths.append(directory.path_join(name))
	paths.sort()
	return paths

static func signature(scenery: bool = false, job = null) -> String:
	var values: Dictionary = {}
	if not OS.has_feature("generation_export"):
		for path in dependencies(scenery):
			if job and job.is_cancelled(): return ""
			if not FileAccess.file_exists(path): return ""
			values[path] = FileAccess.get_sha256(path)
	else:
		var manifest = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
		if not manifest is Dictionary or manifest.get("schema")!=1 or manifest.get("engine")!=Engine.get_version_info().string or manifest.get("engine_sha256")!=engine_identity(): return ""
		values = manifest.get("scenery" if scenery else "physical",{})
		if not values is Dictionary or values.is_empty(): return ""
		for path in (PHYSICAL+SCENERY if scenery else PHYSICAL):
			if not values.get(path) is String or values[path].length()!=64: return ""
		if JSON.stringify(values,"",true,true).sha256_text()!=manifest.get("scenery_sha256" if scenery else "physical_sha256"): return ""
	return JSON.stringify(values,"",true,true).sha256_text()

static func export_manifest() -> Dictionary:
	var result = {"schema":1,"engine":Engine.get_version_info().string}
	for scenery in [false,true]:
		var values: Dictionary = {}
		for path in dependencies(scenery):
			if not FileAccess.file_exists(path): return {}
			values[path] = FileAccess.get_sha256(path)
		var key = "scenery" if scenery else "physical"
		result[key] = values; result[key+"_sha256"] = JSON.stringify(values,"",true,true).sha256_text()
	return result

static func engine_identity() -> String:
	# An executable is immutable for this process. Version labels can be shared
	# by distinct custom engine builds; fingerprint the actual running binary.
	engine_mutex.lock()
	if executable_digest.is_empty(): executable_digest = FileAccess.get_sha256(OS.get_executable_path())
	var result = executable_digest
	engine_mutex.unlock()
	return result

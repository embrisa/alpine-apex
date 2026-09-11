extends SceneTree
## Explicit art bake. Never called by game startup or quality switching.
const Asset = preload("res://scripts/world/wilderness_asset.gd")
const Recipe = preload("res://scripts/authoring/wilderness_recipe.gd")
const Apron = preload("res://scripts/world/alpine_backdrop.gd")
const Panorama = preload("res://scripts/world/alpine_wilderness.gd")
const Placement = preload("res://scripts/authoring/wilderness_placement.gd")
const MeshBake = preload("res://scripts/authoring/wilderness_mesh.gd")
const Quality = preload("res://scripts/presentation/graphics_quality.gd")
class Assets:
	extends RefCounted
	func terrain_material(_bias: float = 0.0,_scale: float = .075) -> ShaderMaterial: return ShaderMaterial.new()
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var field = preload("res://scripts/world/mountain_definition.gd").generate(849205174,15)
	# Match MountainPreparation and normal startup, including its scenery RNG.
	var mountain = preload("res://scripts/world/mountain_data.gd").new(); mountain.generate(field,field.seed_value)
	var recipe = Recipe.new(); recipe.configure(mountain,field)
	var asset = Asset.new()
	asset.metadata={"seed":recipe.seed_value,"physical_seed":field.seed_value,"height_sha256":field.height_checksum,"obstacle_sha256":field.obstacle_checksum,"scenery_height_sha256":mountain.height_checksum,"scenery_environment_sha256":mountain.environment_checksum,"bounds":field.bounds(),"valley_height":recipe.valley_height,"snowline":recipe.snowline,"ridge_segments":recipe.ridges.size(),"source_sha256":Panorama.source_hashes()}
	asset.metadata.source_sha256={}
	asset.metadata.scenery_seed=mountain.seed_value
	for source_path in ["scripts/authoring/bake_wilderness.gd","scripts/authoring/wilderness_recipe.gd","scripts/authoring/wilderness_mesh.gd","scripts/authoring/wilderness_placement.gd","scripts/world/alpine_backdrop.gd","scripts/world/mountain_data.gd","scripts/world/wilderness_asset.gd","scripts/presentation/graphics_quality.gd"]:
		asset.metadata.source_sha256[source_path]=FileAccess.get_sha256("res://"+source_path)
	asset.metadata.engine=Engine.get_version_info().string
	# One extra ring supplies exact normals at the 8192 m apron edge.
	for z in range(-1,258):
		for x in range(-1,258):
			var p=Vector2(-4096+x*32,-4096+z*32)
			var sample=recipe.sample_at(p)
			asset.apron_heights.append(sample.height)
			asset.apron_reference.append(mountain.sample_height(p))
			asset.apron_normals.append(sample.normal)
			asset.apron_masks.append(sample.mask)
			asset.apron_blends.append(sample.blend)
	var apron=Apron.new(); root.add_child(apron)
	await apron.build(field,Assets.new(),mountain,recipe)
	for level in 3:
		var panorama=Panorama.new(); root.add_child(panorama)
		panorama.source_arrays=apron.triangle_sources.duplicate()
		var owner=Node3D.new(); panorama.add_child(owner)
		for band in 3:
			for sector in 8:
				var arrays=MeshBake.sector(recipe,band,sector,[12,24,24][level],level)
				panorama.source_arrays.append(arrays)
				panorama.triangles+=arrays[Mesh.ARRAY_INDEX].size()/3
		var placement=Placement.new()
		placement.build(panorama.source_arrays,field.bounds(),Vector2.ZERO,recipe.seed_value,recipe.snowline,Quality.preset(level).offmap_prop_density)
		assert(placement.ready)
		asset.levels.append({"terrain":panorama.source_arrays.slice(apron.triangle_sources.size()),"groups":placement.groups,"counts":placement.counts,"fingerprint":placement.fingerprint,"seating_error_m":placement.seating_error_m,"terrain_triangles":panorama.triangles,"apron_count":apron.triangle_sources.size()})
		print("BAKED_PRESET ",level," ",placement.counts)
		panorama.queue_free(); await process_frame
	var path="res://assets/graphics/scenery/alpine_valleys_01.res"
	assert(ResourceSaver.save(asset,path,ResourceSaver.FLAG_COMPRESS)==OK)
	var reopened=load(path)
	assert(reopened.levels.size()==3 and reopened.levels[2].fingerprint==asset.levels[2].fingerprint)
	print("WILDERNESS_ASSET ",path," ",FileAccess.get_sha256(path)," ",FileAccess.open(path,FileAccess.READ).get_length()," bytes")
	apron.queue_free(); await process_frame; quit()

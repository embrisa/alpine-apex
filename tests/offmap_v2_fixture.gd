extends RefCounted
## Explicit test-only v2 baseline. Same v15 world, weather, camera and physics.
const Apron = preload("res://tests/fixtures/offmap_v2/alpine_backdrop.gd")
const Panorama = preload("res://tests/fixtures/offmap_v2/alpine_wilderness.gd")
var apron
var panorama
var source_world
var removed_corners
var corner_triangles = 0
var baseline_mountain

func build(world, checkpoint: Callable = Callable()) -> void:
	# Exercise the actual staged startup path, not a separately seeded test map.
	var reference: Dictionary=world.wilderness.data.asset.metadata
	if world.surface.seed_value==reference.physical_seed:
		assert(world.mountain.seed_value==reference.scenery_seed and world.mountain.height_checksum==reference.scenery_height_sha256,"Default startup must match the authored scenery reference")
		assert(world.wilderness.placement.adapted_instances==0,"Default startup must not move authored prop anchors")
	source_world = world
	assert(world.backdrop.material.get_shader_parameter("contact_material")==world.snow_material.get_shader_parameter("contact_material"),"Joining snow must share the physical terrain's material mask")
	apron = Apron.new(); panorama = Panorama.new()
	world.add_child(apron); world.add_child(panorama)
	# V2 included the empty square corners. Restore them only for this frozen
	# comparison, on the same unchanged v15 support grid and original material.
	removed_corners=Node3D.new(); world.add_child(removed_corners)
	var terrain=preload("res://scripts/world/terrain_preparation.gd")
	var job=preload("res://scripts/world/generation_job.gd").new()
	var shared_indices=terrain.base_indices(64)
	var shared_lods={0.7:terrain.lod_indices(64,4),3.0:terrain.lod_indices(64,8)}
	for z in range(0,1536,64):
		for x in range(0,1536,64):
			var chunk=terrain.chunk_arrays(world.surface,x,z,job,false)
			if chunk.is_empty(): continue
			var arrays=[]; arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX]=chunk.vertices; arrays[Mesh.ARRAY_NORMAL]=chunk.normals; arrays[Mesh.ARRAY_INDEX]=shared_indices
			var mesh=ArrayMesh.new(); mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],shared_lods)
			var node=MeshInstance3D.new(); node.mesh=mesh; node.material_override=world.snow_material
			node.gi_mode=GeometryInstance3D.GI_MODE_STATIC
			removed_corners.add_child(node); corner_triangles+=arrays[Mesh.ARRAY_INDEX].size()/3
	baseline_mountain=preload("res://tests/fixtures/offmap_v2/mountain_data.gd").new()
	baseline_mountain.generate(world.surface,world.mountain.seed_value)
	panorama.prepare(world.surface,baseline_mountain)
	var baseline_assets=preload("res://scripts/presentation/alpine_assets.gd").new(world.cloud_lighting,world.quality)
	baseline_assets.mountain=baseline_mountain
	await apron.build(world.surface,baseline_assets,baseline_mountain,panorama.data,checkpoint)
	var retained_triangles=0
	for chunk in world.terrain_chunks:
		if not chunk.get_meta("trimmed_perimeter",false): retained_triangles+=chunk.mesh.surface_get_array_index_len(0)/3
	assert(retained_triangles+corner_triangles==4718592,"V2 comparison must restore the original complete terrain and its original LODs")
	panorama.apron_material = apron.material
	await panorama.apply_quality(world.quality,checkpoint)
	select(world,false)
	world.get_tree().process_frame.connect(update_weather)

func update_weather() -> void:
	if is_instance_valid(source_world) and source_world.last_weather_state:
		panorama.update_weather(source_world.last_weather_state)

func select(world, baseline: bool) -> void:
	apron.visible = baseline; panorama.visible = baseline
	removed_corners.visible=baseline
	for chunk in world.terrain_chunks:
		if chunk.get_meta("trimmed_perimeter",false): chunk.visible=not baseline
	world.backdrop.visible = not baseline; world.wilderness.visible = not baseline
	update_weather()

func dispose() -> void:
	if is_instance_valid(source_world): source_world.get_tree().process_frame.disconnect(update_weather)
	apron.queue_free(); panorama.queue_free()
	removed_corners.queue_free()

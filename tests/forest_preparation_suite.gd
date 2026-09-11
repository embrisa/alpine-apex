extends SceneTree
## Native MultiMesh readback and real residency boundary checks, outside timing.
const Scenery = preload("res://scripts/world/alpine_scenery.gd")
const Forest = preload("res://scripts/presentation/density_forest.gd")
const Graphics = preload("res://scripts/presentation/graphics_quality.gd")
const Assets = preload("res://scripts/presentation/alpine_assets.gd")
const Clouds = preload("res://scripts/presentation/cloud_lighting.gd")
var failures = []
var checks = 0
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures.append(label); printerr("FAIL ",label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://artifacts/fps_optimization")
	if DisplayServer.get_name()=="headless": printerr("Native MultiMesh readback required"); quit(2); return
	Engine.max_fps = 120
	var host = Scenery.new(); root.add_child(host)
	host.quality = Graphics.preset(2); host.dense_woodlands = true
	host.assets = Assets.new(Clouds.new(),host.quality)
	var manifest = JSON.parse_string(FileAccess.get_file_as_string("res://assets/graphics/trees/manifest.json"))
	var asset: String = manifest.assets[0].id
	var mesh = host.assets.mesh(asset+"_lod0")
	var transforms = []
	for i in 80:
		transforms.append(Transform3D(Basis(Vector3.UP,i*.17).scaled(Vector3(.8,1.3,.9)),Vector3(i*3,0,i%7)))
	var prepared = Scenery.prepare_tree_batch(transforms,23,host.assets.tree_render_bounds(asset))
	for lod in [0,1,5]:
		host._batch(mesh,transforms,lod,23)
		var original = host.batches[-1]
		host._batch(mesh,transforms,lod,23,prepared)
		var packed = host.batches[-1]
		host.configure_batches(host.quality,[original,packed])
		await process_frame
		check(packed.get_instance_shader_parameter("pc_lod_individual")==true,"Ordinary conifer batches select detail per scaled crown")
		check(packed.get_instance_shader_parameter("pc_streamed")!=true,"Ordinary conifers do not use streamed far fallback")
		for i in transforms.size():
			check(packed.multimesh.get_instance_transform(i)==original.multimesh.get_instance_transform(i),"Native packed transform equals individual upload")
		for property in ["custom_aabb","visibility_range_begin","visibility_range_end","cast_shadow","gi_mode"]:
			check(packed.get(property)==original.get(property),"Packed batch preserves "+property)
		original.queue_free(); packed.queue_free()
	host.batches.clear(); await process_frame
	var forest = Forest.new(); host.add_child(forest); forest.set_process(false)
	for x in range(-256,257,16):
		for z in [-32,0,32]: forest.add_tree(asset,Transform3D(Basis.IDENTITY,Vector3(x,0,z)),23)
	await forest.finish(host,Callable())
	for batch in host.batches:
		check(batch.get_instance_shader_parameter("pc_streamed")==true,"Streamed distant batches retain teleport fallback")
	check(forest.prepared_bytes==99*48,"Packed memory is bounded by tree count")
	var counts = []
	for traversal in 3:
		for x in range(-448,449,32):
			forest.update_residency(Vector3(x,0,0)); await process_frame
			for nodes in forest.resident.values():
				for i in range(0,nodes.size(),3):
					check(nodes[i+1].multimesh.buffer==nodes[i+2].multimesh.buffer,"Authored middle and shadow meshes receive identical immutable placements")
		for x in range(448,-449,-32):
			forest.update_residency(Vector3(x,0,0)); await process_frame
		counts.append(host.batches.size())
		check(forest.resident.is_empty(),"Crossing beyond the retention radius retires nearby batches")
		for region in forest.regions.values():
			for group in region.values(): check(group.prepared.multimeshes.is_empty(),"Retirement releases cached GPU placement")
	check(counts[0]==counts[1] and counts[1]==counts[2],"Repeated boundary traversals do not accumulate batches")
	host.queue_free(); await process_frame
	# Replacing the owner gets a fresh preparation/cache lifetime.
	var replacement = Scenery.new(); root.add_child(replacement)
	check(replacement.batches.is_empty(),"Replacement world starts without previous residency")
	replacement.queue_free(); await process_frame
	print("FOREST_PREPARATION ",checks," checks; failures=",failures)
	FileAccess.open("res://artifacts/fps_optimization/forest_preparation_checks.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"\t"))
	quit(0 if failures.is_empty() else 1)

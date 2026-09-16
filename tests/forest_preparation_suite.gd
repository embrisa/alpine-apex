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
	check(forest.prepared_bytes>=99*48 and forest.prepared_bytes<=99*96,"Regional and subdivided transforms remain bounded by tree count")
	var counts = []
	for traversal in 3:
		for x in range(-448,449,32):
			forest.update_residency(Vector3(x,0,0)); await process_frame
			check_slots(host)
			for nodes in forest.resident.values():
				var placements={0:{},1:{},5:{}}
				for node in nodes:
					var lod:int=node.get_meta("art_lod")
					var mm:MultiMesh=node.multimesh
					for index in mm.instance_count:
						var pose:Transform3D=mm.get_instance_transform(index)
						placements[lod][pose]=int(placements[lod].get(pose,0))+1
				check(placements[0]==placements[1] and placements[1]==placements[5],"Subdivided detail and regional shadows retain identical immutable placements")
		for x in range(448,-449,-32):
			forest.update_residency(Vector3(x,0,0)); await process_frame
			check_slots(host)
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
	await partition_checks(manifest)
	print("FOREST_PREPARATION ",checks," checks; failures=",failures)
	FileAccess.open("res://artifacts/fps_optimization/forest_preparation_checks.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"\t"))
	quit(0 if failures.is_empty() else 1)

func check_slots(host) -> void:
	var valid = true
	for i in host.batches.size():
		valid = valid and host.batches[i].get_meta("batch_slot",-1)==i
	check(valid,"Every live batch retains its slot through swap removal and re-entry")

func partition_checks(manifest: Dictionary) -> void:
	var host = Scenery.new(); root.add_child(host)
	host.quality = Graphics.preset(2); host.dense_woodlands = true
	host.assets = Assets.new(Clouds.new(),host.quality)
	var forest = Forest.new(); host.add_child(forest); forest.set_process(false)
	var expected = 0
	for record in manifest.assets:
		for x in [-384.01,-384.0,-.01,0.0,383.99,384.0]:
			var scale_value = 14.0/float(record.height_m)
			var pose = Transform3D(Basis(Vector3.UP,x*.1).scaled(Vector3.ONE*scale_value),Vector3(x,x*.15,x*.6))
			forest.add_tree(record.id,pose,22); expected += 1
	var stored = 0
	for group in forest.far_groups.values(): stored += group.transforms.size()
	check(stored==expected,"Signed distant-cell boundaries store every authored variant exactly once")
	check(Forest.CELL==32.0 and Forest.LOAD_RADIUS==128.0 and Forest.KEEP_RADIUS==192.0,"Detail residency and retention are unchanged")
	check(Forest.FAR_CELL==preload("res://scripts/presentation/forest_placement.gd").FAR_CELL,"Prepared and direct forests share the same distant partition")
	await forest.finish(host,Callable())
	await process_frame
	var uploaded = 0
	for node in host.batches:
		var mm: MultiMesh = node.multimesh
		var asset: String = mm.mesh.get_meta("forest_asset")
		var local_box: AABB = host.assets.tree_render_bounds(asset)
		for i in mm.instance_count:
			var pose: Transform3D = mm.get_instance_transform(i)
			check(node.custom_aabb.grow(.001).encloses(pose*local_box),"Distant bounds retain the complete wind and rotated-card envelope")
			uploaded += 1
	check(uploaded==expected,"Native distant uploads preserve every tree without duplication")
	for preset in [1,7,10]:
		host.apply_quality(Graphics.numbered(preset))
		for node in host.batches:
			var ranges: Vector4 = node.get_instance_shader_parameter("pc_lod_ranges")
			check(ranges.y==host.quality.tree_far_m and ranges.z==5.0,"Quality changes preserve individual distance and fade")
			check(node.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,"Distant regrouping cannot remove an off-camera shadow caster")
			for i in node.multimesh.instance_count:
				var anchor: Vector3 = node.multimesh.get_instance_transform(i).origin
				var center: Vector3 = node.custom_aabb.get_center()
				check(anchor.distance_to(center)+ranges.y+ranges.z<=node.visibility_range_end+.001,"Batch distance cannot cut an individually visible tree early")
	# Remove the first, a middle, and the last member, then re-use swapped slots.
	while not host.batches.is_empty():
		var slot = [0,host.batches.size()/2,host.batches.size()-1][host.batches.size()%3]
		var node: MultiMeshInstance3D = host.batches[slot]
		host.remove_batch(node); node.queue_free(); check_slots(host)
	host.queue_free(); await process_frame

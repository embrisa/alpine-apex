extends SceneTree
## Alternate original individual setup and prepared setup on one native device.
const Scenery = preload("res://scripts/world/alpine_scenery.gd")
const Forest = preload("res://scripts/presentation/density_forest.gd")
const Graphics = preload("res://scripts/presentation/graphics_quality.gd")
const Assets = preload("res://scripts/presentation/alpine_assets.gd")
const Clouds = preload("res://scripts/presentation/cloud_lighting.gd")
const Costs = preload("res://scripts/diagnostics/frame_costs.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	if DisplayServer.get_name()=="headless": printerr("Native renderer required"); quit(2); return
	Engine.max_fps = 0; root.size = Vector2i(640,360)
	var display = preload("res://scripts/presentation/pc_graphics_settings.gd").new()
	display.upscaler = "fsr4"; display.frame_generation = false; display.apply_viewport(root)
	var host = Scenery.new(); root.add_child(host)
	host.quality = Graphics.preset(2); host.dense_woodlands = true
	host.assets = Assets.new(Clouds.new(),host.quality)
	var forest = Forest.new(); host.add_child(forest); forest.host = host; forest.set_process(false)
	var manifest = JSON.parse_string(FileAccess.get_file_as_string("res://assets/graphics/trees/manifest.json"))
	var asset: String = manifest.assets[0].id
	var meshes = [forest._mesh_for(asset,0),forest._mesh_for(asset,1),forest._mesh_for(asset,5)]
	var camera = Camera3D.new(); host.add_child(camera); camera.position = Vector3(0,12,45); camera.look_at(Vector3(0,5,0))
	var transforms = []
	for i in 80:
		transforms.append(Transform3D(Basis(Vector3.UP,i*.17),Vector3((i%10)*4-20,0,-(i/10)*4)))
	var prepared = Scenery.prepare_tree_batch(transforms,23,host.assets.tree_render_bounds(asset))
	var rows = []
	for packed in [false,true,true,false,false,true]:
		var samples = PackedFloat64Array()
		for sample in 240:
			var start = Time.get_ticks_usec()
			for i in 3: host._batch(meshes[i],transforms,[0,1,5][i],23,prepared if packed else {})
			host.configure_batches(host.quality,host.batches)
			if sample>=40: samples.append(Time.get_ticks_usec()-start)
			await process_frame; await RenderingServer.frame_post_draw
			for node in host.batches: node.queue_free()
			host.batches.clear(); prepared.multimeshes.clear()
		var row = Costs.stats(samples); row.prepared = packed; rows.append(row)
		print("FOREST_SUBMISSION ",JSON.stringify(row))
	preload("res://tests/test_report.gd").write("res://artifacts/fps_optimization/forest_submission.json",JSON.stringify({"scope":"CPU microseconds for one 80-tree region's near/mid/shadow creation and configuration, alternating on one native FSR4 device. Native frames separate samples; preparation is outside timing.","rows":rows},"\t"))
	host.queue_free(); await process_frame; quit(0)

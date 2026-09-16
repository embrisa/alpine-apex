extends SceneTree
## GPU check of the production include at matched depths across all screen tiles.
## Synthetic coverage does not replace production tree/temporal rendered review.
var checks = 0
var failures = []
var rows = []
var output = "res://artifacts/orchestration_20260912/forest/mask_%d_%d" % [OS.get_process_id(),Time.get_ticks_usec()]
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr("FAIL ",label)
func snapshot() -> Image:
	for frame in 3: await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()
func coverage(image: Image) -> Array:
	var ratios = []
	for row in 3:
		for col in 3:
			var hidden = 0; var total = 0
			for y in range(row*image.get_height()/3,(row+1)*image.get_height()/3):
				for x in range(col*image.get_width()/3,(col+1)*image.get_width()/3):
					total += 1
					if image.get_pixel(x,y).r<.5: hidden += 1
			ratios.append(float(hidden)/total)
	return ratios
func run() -> void:
	if DisplayServer.get_name()=="headless": quit(2); return
	root.size = Vector2i(480,360)
	root.content_scale_size = Vector2i.ZERO
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	Engine.max_fps = 60
	DirAccess.make_dir_recursive_absolute(output)
	var background = ColorRect.new(); background.color = Color.BLACK; background.size = Vector2(480,360); root.add_child(background)
	var material = ShaderMaterial.new(); material.shader = preload("res://tests/foliage_sight_probe.gdshader")
	var layers = []
	for layer in 4:
		var card = ColorRect.new(); card.size = Vector2(480,360); card.material = material; root.add_child(card); layers.append(card)
	for depth in [5.0,10.0,12.0,14.0,20.0]:
		var previous = []
		material.set_shader_parameter("probe_depth",depth)
		for strength in [0.0,.25,.5,.75,1.0]:
			material.set_shader_parameter("foliage_sight_parameters",Vector4(1,10,14,strength))
			for index in 4: layers[index].visible = index==0
			var single = await snapshot()
			for layer in layers: layer.show()
			var stacked = await snapshot()
			check(single.get_data()==stacked.get_data(),"Stacked foliage preserves the same revealed pixels")
			var measured = coverage(stacked)
			var expected = strength*(1.0-smoothstep(10,14,depth))
			for tile in 9:
				check(absf(measured[tile]-expected)<.015,"Center/edge/corner removal follows strength and depth")
				if not previous.is_empty(): check(measured[tile]>=previous[tile],"Removal increases monotonically in every tile")
			previous = measured
			stacked.save_png(output+"/depth_%02d_strength_%03d.png" % [depth,strength*100])
			rows.append({"depth":depth,"strength":strength*100,"tile_removal":measured})
	preload("res://tests/test_report.gd").write(output+"/report.json",JSON.stringify({"checks":checks,"failures":failures,"rows":rows,"output":output,"scope":"synthetic production shader include","tree_visual_acceptance":false},"\t"))
	print("FOLIAGE_MASK_RESULTS ",JSON.stringify({"checks":checks,"failures":failures,"output":output}))
	quit(0 if failures.is_empty() else 1)

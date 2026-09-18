extends SceneTree
## Explicit catalogue views using production shaders; no mountain, records or FPS claim.
var output = "res://artifacts/meshy_seasons_20260918/catalogue"
var style = 1
var stage: Node3D
var camera: Camera3D

func _initialize(): call_deferred("run")

func run():
	assert(DisplayServer.get_name() != "headless", "Native rendered review required")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = "res://" + arg.get_slice("=", 1)
		if arg.begins_with("--forest-style="):style=["autumn","winter","summer"].find(arg.get_slice("=",1))
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1600, 1000); Engine.max_fps = 30
	stage = Node3D.new(); root.add_child(stage)
	var environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(.36, .49, .65)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(.72, .83, 1)
	environment.ambient_light_energy = .42
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_environment = WorldEnvironment.new(); world_environment.environment = environment; stage.add_child(world_environment)
	var sun = DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-36, -32, 0); sun.light_energy = 1; stage.add_child(sun)
	var lighting = preload("res://scripts/presentation/cloud_lighting.gd").new()
	var quality = preload("res://scripts/presentation/graphics_quality.gd").preset(2)
	var assets = preload("res://scripts/presentation/alpine_assets.gd").new(lighting, quality)
	var scenery = preload("res://scripts/world/alpine_scenery.gd").new(); stage.add_child(scenery)
	scenery.assets = assets; scenery.quality = quality
	scenery.tree_motion = preload("res://scripts/presentation/tree_motion.gd").new(assets, "")
	var appearance = preload("res://scripts/presentation/forest_appearance.gd").new()
	appearance.setup({"assets":assets, "scenery":scenery, "wilderness":null})
	appearance.select(style)
	camera = Camera3D.new(); camera.fov = 45; camera.far = 200; stage.add_child(camera); camera.make_current()
	var tree = MeshInstance3D.new(); stage.add_child(tree)
	var rows = []
	for family in ["spruce_01", "spruce_02", "fir_01", "fir_02", "pine_01", "pine_02", "birch_01", "golden_01", "maple_01", "dead_01", "broken_01"]:
		var id = "forest_" + family
		var near_mesh: Mesh = assets.mesh(id + "_lod0")
		var bounds = near_mesh.get_aabb(); var center = bounds.get_center()
		var distance_m = maxf(bounds.size.y * 1.55, bounds.size.x * 1.8)
		for lod in 3:
			tree.mesh = assets.mesh(id + "_lod%d" % lod)
			camera.position = center + Vector3(distance_m * .23, 0, distance_m)
			camera.look_at(center)
			for frame in 8: await process_frame
			await RenderingServer.frame_post_draw
			var path = output + "/%s_lod%d.webp" % [family, lod]
			assert(root.get_texture().get_image().save_webp(path, true) == OK)
			var material: ShaderMaterial = tree.mesh.surface_get_material(0)
			rows.append({"asset":id, "lod":lod, "material":material.resource_name, "shader":material.shader.resource_path, "capture":path, "camera_m":distance_m, "forced_lod":true})
		print("SEASONAL_CATALOGUE ", family)
	preload("res://tests/test_report.gd").write(output + "/review.json", JSON.stringify({"season":appearance.STYLES[style],"scope":"Forced catalogue LODs at matched framing; no gameplay, transition or performance acceptance","views":rows}, "\t"))
	stage.queue_free(); await process_frame; quit()

extends SceneTree
## Pixel comparison of conservative near-batch culling; captures are not timing.
const Grass=preload("res://scripts/presentation/terrain_grass.gd")
const Habitat=preload("res://tests/terrain_grass_suite.gd").Habitat
func _initialize(): call_deferred("run")
func run():
	if DisplayServer.get_name()=="headless": quit(2); return
	root.size=Vector2i(1280,720); Engine.max_fps=60
	var output="res://artifacts/terrain_grass_performance_20260913/lod_visual"
	DirAccess.make_dir_recursive_absolute(output)
	var field=Habitat.new(); field.forest=1.0; field.rock=1.0; field.depth=0.0
	var profile=preload("res://scripts/presentation/graphics_quality.gd").numbered(7)
	var library=preload("res://scripts/presentation/alpine_assets.gd").new(preload("res://scripts/presentation/cloud_lighting.gd").new(),profile)
	var grass=Grass.new(); root.add_child(grass); grass.build(field,library,profile); grass.set_process(false)
	grass.stream(Vector3.ZERO,625)
	for material in grass.materials: material.set_shader_parameter("grass_stream_time",10.0)
	var env=WorldEnvironment.new(); env.environment=Environment.new(); root.add_child(env)
	env.environment.background_mode=Environment.BG_COLOR; env.environment.background_color=Color(.12,.16,.2)
	env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR; env.environment.ambient_light_energy=.7
	var sun=DirectionalLight3D.new(); root.add_child(sun); sun.rotation_degrees=Vector3(-35,-25,0)
	var camera=Camera3D.new(); root.add_child(camera); camera.current=true; camera.fov=65
	var rows=[]; var failures=0
	for distance_m in [2.0,17.0,18.0,22.0,26.0,28.0,40.0,80.0]:
		camera.position=Vector3(8,1.6,distance_m); camera.look_at(Vector3(8,.2,0))
		var captures=[]
		for candidate in [false,true]:
			for batches in grass.cells.values():
				for batch in batches:
					if batch.material_override==grass.materials[0]: batch.visibility_range_end=26.0+batch.multimesh.custom_aabb.size.length()*.5 if candidate else grass.distance_m+32.0
			for i in 4: await process_frame
			await RenderingServer.frame_post_draw
			var picture=root.get_texture().get_image(); captures.append(picture.get_data())
			picture.save_png(output+"/d%02d_%s.png" % [int(distance_m),"candidate" if candidate else "reference"])
		var equal=captures[0]==captures[1]
		if not equal: failures+=1
		rows.append({"distance_m":distance_m,"byte_identical":equal})
	FileAccess.open(output+"/receipt.json",FileAccess.WRITE).store_string(JSON.stringify({"scope":"native 1280x720 frozen grass, unchanged 18-26 m blend, no FPS claim","rows":rows,"failures":failures}))
	print("GRASS_LOD_VISUAL ",JSON.stringify(rows)); grass.free(); quit(0 if failures==0 else 1)

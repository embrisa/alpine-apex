extends SceneTree
## Unranked, bounded native view of a real seeded cliff and its debris field.
const Terrain=preload("res://scripts/world/generators/alpine_massif_v11.gd")
var world
func _initialize() -> void: call_deferred("run")
func run() -> void:
	if DisplayServer.get_name()=="headless": quit(2); return
	Engine.max_fps=30
	root.size=Vector2i(1920,1080)
	var data: Dictionary=FileAccess.open("res://artifacts/geology_v11/field_849205174.bin",FileAccess.READ).get_var(false)
	var field=Terrain.new(849205174,false)
	field.heights=data.heights
	field.exposure_image=Image.create_from_data(field.NX,field.NZ,false,Image.FORMAT_RGBA8,data.exposure)
	field.geology.restore(data.placements,data.stats)
	field.build_material_map()
	var selected: Dictionary={}
	var asset_filter=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--asset="): asset_filter=arg.trim_prefix("--asset=")
	for placed in field.geology.placements:
		if (asset_filter.is_empty() and field.geology.catalog.records[placed.asset].category=="cliffs") or placed.asset==asset_filter:
			selected=placed; break
	if selected.is_empty():
		printerr("Requested asset is not present in the test seed: ",asset_filter)
		quit(2); return
	var focus: Vector3=selected.pose.origin
	focus.y=field.sample(focus.x,focus.z).height
	var local: Array=[]
	for placed in field.geology.placements:
		if Vector2(placed.pose.origin.x-focus.x,placed.pose.origin.z-focus.z).length()<300: local.append(placed)
	field.geology.placements=local
	world=preload("res://scripts/world/alpine_world.gd").new()
	root.add_child(world)
	world.surface=field
	world.quality=preload("res://scripts/presentation/graphics_quality.gd").preset(2)
	world.assets=preload("res://scripts/presentation/alpine_assets.gd").new(world.cloud_lighting,world.quality)
	world.snow_material=world.assets.terrain_material()
	world.snow_material.set_shader_parameter("contact_material_enabled",true)
	world.snow_material.set_shader_parameter("contact_material",ImageTexture.create_from_image(field.material_image))
	world.snow_material.set_shader_parameter("contact_material_origin",Vector2(field.X_MIN,field.Z_MIN))
	world.snow_material.set_shader_parameter("contact_material_size",Vector2(field.NX,field.NZ))
	world.snow_material.set_shader_parameter("use_feature_exposure",true)
	world.snow_material.set_shader_parameter("feature_exposure",ImageTexture.create_from_image(field.exposure_image))
	world.snow_material.set_shader_parameter("feature_origin",field.MASK_ORIGIN)
	world.snow_material.set_shader_parameter("feature_size",Vector2(field.MASK_SIZE))
	world._environment()
	var st=SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var origin=Vector2(floorf(focus.x/4)*4-320,floorf(focus.z/4)*4-320)
	for z in 160:
		if z%8==0: await process_frame
		for x in 160:
			for offset in [Vector2(0,0),Vector2(1,0),Vector2(0,1),Vector2(1,0),Vector2(1,1),Vector2(0,1)]:
				var p=origin+(Vector2(x,z)+offset)*4
				st.set_normal(field.render_normal(p.x,p.y))
				st.add_vertex(Vector3(p.x,field.sample(p.x,p.y).height,p.y))
	var terrain=MeshInstance3D.new(); terrain.mesh=st.commit(); terrain.material_override=world.snow_material; world.add_child(terrain)
	var minerals=preload("res://scripts/presentation/mineral_scenery.gd").new()
	world.add_child(minerals); await minerals.build(field,world.assets,world.quality,checkpoint)
	world.apply_graphics(world.quality)
	var weather=preload("res://scripts/presentation/weather_controller.gd").new(); root.add_child(weather)
	world.update_weather(weather.state,0,false)
	var camera=Camera3D.new(); camera.far=3000; world.add_child(camera); camera.make_current()
	root.size=Vector2i(1920,1080)
	var directions=[Vector3(140,70,150),Vector3(65,4,100),Vector3(-100,10,80)]
	var captures: Array=[]
	for i in directions.size():
		var offset: Vector3=selected.pose.basis.orthonormalized()*directions[i]
		camera.position=focus+offset
		camera.position.y=maxf(camera.position.y,field.sample(camera.position.x,camera.position.z).height+(4 if i else 40))
		camera.look_at(focus+Vector3.UP*10)
		for frame in 40: await process_frame
		await RenderingServer.frame_post_draw
		var path="res://artifacts/geology_v11/seating_%s_%d.png" % [selected.asset,i]
		var picture=root.get_texture().get_image()
		if picture.get_size()!=Vector2i(1920,1080): quit(2); return
		picture.save_png(path)
		captures.append(path)
	FileAccess.open("res://artifacts/geology_v11/seating.json",FileAccess.WRITE).store_string(JSON.stringify({"asset":selected.asset,"placements":local.size(),"height_sha256":data.height_sha256,"obstacle_sha256":data.obstacle_sha256,"catalog_sha256":field.geology.catalog.fingerprint,"captures":captures,"output_pixels":[1920,1080],"fps_cap":Engine.max_fps,"unranked":true},"\t"))
	print("GEOLOGY_SEATING_CAPTURE ",selected.asset," ",local.size()," nearby placements")
	quit()

func checkpoint(_message: String, _progress: float) -> void:
	await process_frame

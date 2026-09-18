extends "res://art_source/trees/meshy_snow_v1/prepare.gd"
## Prepare one coherent family without changing production assets.
const FAMILY=["spruce","spruce_open","fir","stone_pine"]
const DEST="res://artifacts/meshy_snow_20260918/winter_family"
func run():
	assert(OS.get_environment("ALPINE_VALIDATION_MODE")=="Exclusive")
	DirAccess.make_dir_recursive_absolute(DEST+"/review")
	var common=FileAccess.get_file_as_string("res://assets/graphics/pc_forest_tree_common.gdshaderinc")
	var vertex=common.substr(0,common.find("void fragment()"))
	var fragment=FileAccess.get_file_as_string("res://assets/graphics/pc_winter_fragment.gdshaderinc")
	for lod in 2:
		FileAccess.open(DEST+"/tree_"+str(lod)+".gdshader",FileAccess.WRITE).store_string("shader_type spatial;\nrender_mode cull_disabled;\n"+("#define ALPINE_FOREST_MID\n" if lod==1 else "")+vertex+fragment)
	root.size=Vector2i(2560,1440);Engine.max_fps=30
	stage=Node3D.new();root.add_child(stage)
	var we=WorldEnvironment.new();environment=Environment.new();we.environment=environment
	environment.background_mode=Environment.BG_COLOR;environment.background_color=Color(.40,.56,.72)
	environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.ambient_light_color=Color(.72,.83,1);environment.ambient_light_energy=.42
	environment.tonemap_mode=Environment.TONE_MAPPER_FILMIC;stage.add_child(we)
	var sun=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-36,-32,0);sun.light_energy=1;sun.shadow_enabled=true;stage.add_child(sun)
	floor_node=MeshInstance3D.new();var plane=PlaneMesh.new();plane.size=Vector2(180,180);floor_node.mesh=plane
	var ground=StandardMaterial3D.new();ground.albedo_color=Color(.8,.86,.92);ground.roughness=1;floor_node.material_override=ground;stage.add_child(floor_node)
	camera=Camera3D.new();stage.add_child(camera);camera.make_current();camera.fov=55;camera.far=250
	var albedo:Texture2D
	for species in FAMILY:
		models[species]={"meshes":[]}
		for lod in 2:
			var state=GLTFState.new();var document=GLTFDocument.new()
			assert(document.append_from_file(DEST+"/"+species+"/tree_lod"+str(lod)+".glb",state)==OK)
			var imported=document.generate_scene(state);var parts=gather(imported);assert(parts.size()==1)
			var a:Array=parts[0].arrays
			assert(a[Mesh.ARRAY_COLOR].size()==a[Mesh.ARRAY_VERTEX].size(),"Authored bark/bough roles")
			var tags:PackedVector2Array=a[Mesh.ARRAY_TEX_UV2];var indices:PackedInt32Array=a[Mesh.ARRAY_INDEX]
			for face in range(0,indices.size(),3):
				assert(tags[indices[face]]==tags[indices[face+1]] and tags[indices[face]]==tags[indices[face+2]],"Whole-bough pivots")
			var raw=ArrayMesh.new();raw.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,a)
			var optimizer=SurfaceTool.new();optimizer.create_from(raw,0);optimizer.optimize_indices_for_cache()
			var mesh=optimizer.commit();mesh.set_meta("authored_boughs",true)
			assert(ResourceSaver.save(mesh,DEST+"/"+species+"_"+str(lod)+".res")==OK)
			albedo=parts[0].material.albedo_texture
			var mat=ShaderMaterial.new();mat.shader=load(DEST+"/tree_"+str(lod)+".gdshader")
			mat.set_shader_parameter("mesh_albedo",albedo)
			mat.set_shader_parameter("bark_texture",load("res://assets/graphics/textures/bark_albedo_high.jpg"))
			mat.set_shader_parameter("bark_normal",load("res://assets/graphics/textures/bark_normal_high.jpg"))
			mat.set_shader_parameter("pc_lod_individual",false);mat.set_shader_parameter("contact_active",false)
			mesh.surface_set_material(0,mat);models[species].meshes.append(mesh)
			report.sources.append({"species":species,"lod":lod,"triangles":indices.size()/3,"vertices":a[Mesh.ARRAY_VERTEX].size(),"bounds":str(mesh.get_aabb())})
			imported.free()
	assert(albedo.get_image().save_png(DEST+"/bough_albedo.png")==OK)
	var nodes=[]
	for i in FAMILY.size():
		var node=MeshInstance3D.new();node.mesh=models[FAMILY[i]].meshes[0];node.position.x=(i-1.5)*9;stage.add_child(node);nodes.append(node)
	camera.position=Vector3(0,10,43);camera.look_at(Vector3(0,6,0));await capture("lineup")
	for i in nodes.size():
		var node:MeshInstance3D=nodes[i]
		for other in nodes:other.visible=other==node
		camera.position=node.position+Vector3(10,6,18);camera.look_at(node.position+Vector3(0,6,0))
		for lod in 2:
			node.mesh=models[FAMILY[i]].meshes[lod];await capture(FAMILY[i]+"_"+str(lod))
	for node in nodes:node.free()
	if not "--no-bake" in OS.get_cmdline_user_args():await bake_family()
	FileAccess.open(DEST+"/prepare.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	quit()
func capture(label:String):
	for i in 8:await process_frame
	await RenderingServer.frame_post_draw
	var path=DEST+"/review/"+label+".webp"
	assert(root.get_texture().get_image().save_webp(path,true)==OK)
	report.captures.append(path);print("FAMILY_CAPTURE ",label)
func bake_family():
	floor_node.hide();root.size=Vector2i(512,512);root.transparent_bg=true
	root.scaling_3d_scale=1;root.msaa_3d=Viewport.MSAA_4X
	environment.background_mode=Environment.BG_CLEAR_COLOR;environment.tonemap_mode=Environment.TONE_MAPPER_LINEAR
	RenderingServer.set_default_clear_color(Color(0,0,0,0))
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=13.8
	var shader=Shader.new()
	shader.code="shader_type spatial; render_mode unshaded,cull_disabled; uniform sampler2D mesh_albedo:source_color,repeat_disable; uniform sampler2D bark_texture:source_color,repeat_enable; void fragment(){ALBEDO=(COLOR.a<.4?texture(bark_texture,UV).rgb:texture(mesh_albedo,UV).rgb)*COLOR.rgb;}"
	for species in FAMILY:
		var node=MeshInstance3D.new();node.mesh=models[species].meshes[0];stage.add_child(node)
		var mat=ShaderMaterial.new();mat.shader=shader
		var original:ShaderMaterial=node.mesh.surface_get_material(0)
		for param in ["mesh_albedo","bark_texture"]:mat.set_shader_parameter(param,original.get_shader_parameter(param))
		node.material_override=mat
		var atlas=Image.create(4096,512,false,Image.FORMAT_RGBA8)
		for view in 8:
			var angle=view*TAU/8;camera.position=Vector3(sin(angle)*40,6,cos(angle)*40);camera.look_at(Vector3(0,6,0))
			for i in 4:await process_frame
			await RenderingServer.frame_post_draw
			var frame=root.get_texture().get_image();frame.convert(Image.FORMAT_RGBA8)
			assert(frame.get_pixel(0,0).a<.01)
			atlas.blit_rect(frame,Rect2i(0,0,512,512),Vector2i(view*512,0))
		assert(atlas.save_png(DEST+"/"+species+"_atlas.png")==OK)
		node.free();print("FAMILY_ATLAS ",species)

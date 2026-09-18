extends "res://art_source/trees/meshy_snow_v1/prepare.gd"
## Offline source preparation and native eight-bearing atlas bake, never startup work.
const PREPARED="res://artifacts/meshy_seasons_20260918/prepared"
const PACK="res://artifacts/meshy_seasons_20260918/pack"
const SOURCES=["spruce","fir","pine","birch_summer","birch_bare","maple_summer","maple_bare","dead_snag","broken_tree"]
var appearances={}

func run():
	assert(OS.get_environment("ALPINE_VALIDATION_MODE")=="Exclusive")
	DirAccess.make_dir_recursive_absolute(PACK+"/review")
	root.size=Vector2i(1600,1000);Engine.max_fps=30
	stage=Node3D.new();root.add_child(stage)
	var we=WorldEnvironment.new();environment=Environment.new();we.environment=environment;stage.add_child(we)
	environment.background_mode=Environment.BG_COLOR;environment.background_color=Color(.36,.49,.65)
	environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.ambient_light_color=Color(.72,.83,1);environment.ambient_light_energy=.42
	environment.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	var sun=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-36,-32,0);sun.light_energy=1;stage.add_child(sun)
	camera=Camera3D.new();camera.fov=45;camera.far=200;stage.add_child(camera);camera.make_current()
	var selected=PackedStringArray(SOURCES)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):selected=arg.get_slice("=",1).split(",")
	for species in selected:
		var bough=species in ["spruce","fir","pine"]
		models[species]={"meshes":[],"bough":bough}
		for lod in 2:
			var state=GLTFState.new();var document=GLTFDocument.new()
			assert(document.append_from_file(PREPARED+"/"+species+"/tree_lod%d.glb"%lod,state)==OK)
			var imported=document.generate_scene(state);var parts=gather(imported);assert(parts.size()==1)
			var arrays:Array=parts[0].arrays
			var texture:Texture2D=parts[0].material.albedo_texture
			if lod==0:assert(texture.get_image().save_png(PACK+"/"+species+"_albedo.png")==OK)
			if lod==0 and bough:
				var light_image=Image.load_from_file(PREPARED+"/"+species+"_slices/light_albedo.png")
				assert(light_image!=null);assert(light_image.save_png(PACK+"/"+species+"_light_albedo.png")==OK)
				models[species].light_texture=ImageTexture.create_from_image(light_image)
				var normal_texture:Texture2D=parts[0].material.normal_texture
				if normal_texture:
					assert(normal_texture.get_image().save_png(PACK+"/"+species+"_normal.png")==OK)
					models[species].normal=normal_texture
			if not bough:
				var image=texture.get_image();if image.is_compressed():assert(image.decompress()==OK)
				var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
				var uv:PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
				var colors=PackedColorArray();var tags=PackedVector2Array()
				for i in vertices.size():
					var pixel=image.get_pixel(clampi(int(uv[i].x*image.get_width()),0,image.get_width()-1),clampi(int(uv[i].y*image.get_height()),0,image.get_height()-1))
					var leafy=species.ends_with("summer") and pixel.g>maxf(pixel.r,pixel.b)+.008
					colors.append(Color(1,1,1,.55 if leafy else .1));tags.append(Vector2.ZERO)
				arrays[Mesh.ARRAY_COLOR]=colors;arrays[Mesh.ARRAY_TEX_UV2]=tags
			var mesh=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
			var optimizer=SurfaceTool.new();optimizer.create_from(mesh,0);optimizer.optimize_indices_for_cache();mesh=optimizer.commit()
			mesh.set_meta("authored_boughs",bough)
			assert(ResourceSaver.save(mesh,PACK+"/"+species+"_%d.res"%lod,ResourceSaver.FLAG_COMPRESS)==OK)
			models[species].meshes.append(mesh);models[species].texture=texture
			report.sources.append({"source":species,"lod":lod,"triangles":mesh.surface_get_array_index_len(0)/3,"bounds":str(mesh.get_aabb())})
			imported.free()
		appearances[species]={"source":species,"autumn_color":[1,1,1],"autumn_amount":0,"snow_dusting":0,"source_textured":not bough}
		if bough:
			appearances[species+"_light"]={"source":species,"autumn_color":[1,1,1],"autumn_amount":0,"snow_dusting":0,"source_textured":false,"light_texture":true}
	for pair in [["birch_autumn","birch_summer",[1.0,.65,.09]],["maple_autumn","maple_summer",[1.0,.22,.035]]]:
		if not models.has(pair[1]):continue
		appearances[pair[0]]={"source":pair[1],"autumn_color":pair[2],"autumn_amount":1,"snow_dusting":0,"source_textured":true}
	for config in appearances.values():
		var radius=0.0
		for vertex in models[config.source].meshes[0].surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:radius=maxf(radius,Vector2(vertex.x,vertex.z).length())
		assert(radius<6.85,"Atlas must contain the full crown at every bearing")
		config.card_crop=clampf(radius*2.0/13.8+.03,.2,1.0)
	for appearance in appearances:
		var config:Dictionary=appearances[appearance]
		var node=MeshInstance3D.new();stage.add_child(node)
		for lod in 2:
			node.mesh=models[config.source].meshes[lod];node.material_override=material(config,lod)
			camera.position=Vector3(4.5,6,20);camera.look_at(Vector3(0,6,0))
			for frame in 6:await process_frame
			await RenderingServer.frame_post_draw
			assert(root.get_texture().get_image().save_webp(PACK+"/review/"+appearance+"_%d.webp"%lod,true)==OK)
			if lod==0:
				camera.position=Vector3(1.5,4,6);camera.look_at(Vector3(0,4,0))
				for frame in 6:await process_frame
				await RenderingServer.frame_post_draw
				assert(root.get_texture().get_image().save_webp(PACK+"/review/"+appearance+"_close.webp",true)==OK)
		node.free();print("SEASON_SOURCE_REVIEW ",appearance)
	if not "--no-bake" in OS.get_cmdline_user_args():await bake_atlases()
	FileAccess.open(PACK+"/appearances.json",FileAccess.WRITE).store_string(JSON.stringify(appearances,"\t")+"\n")
	FileAccess.open(PACK+"/prepare.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t")+"\n")
	quit()

func material(config:Dictionary,lod:int)->ShaderMaterial:
	var mat=ShaderMaterial.new();mat.shader=load("res://assets/graphics/pc_season_tree_%d.gdshader"%lod)
	mat.set_shader_parameter("mesh_albedo",models[config.source].light_texture if config.get("light_texture",false) else models[config.source].texture)
	if models[config.source].has("normal"):
		mat.set_shader_parameter("mesh_normal",models[config.source].normal)
		mat.set_shader_parameter("has_mesh_normal",true)
	mat.set_shader_parameter("bark_texture",load("res://assets/graphics/textures/bark_albedo_high.jpg"))
	mat.set_shader_parameter("bark_normal",load("res://assets/graphics/textures/bark_normal_high.jpg"))
	for param in ["autumn_amount","snow_dusting","source_textured"]:mat.set_shader_parameter(param,config[param])
	mat.set_shader_parameter("autumn_color",Color(config.autumn_color[0],config.autumn_color[1],config.autumn_color[2]))
	mat.set_shader_parameter("contact_active",false)
	return mat

func bake_atlases():
	root.size=Vector2i(512,512);root.transparent_bg=true;root.scaling_3d_scale=1;root.msaa_3d=Viewport.MSAA_4X
	environment.background_mode=Environment.BG_CLEAR_COLOR;environment.tonemap_mode=Environment.TONE_MAPPER_LINEAR
	RenderingServer.set_default_clear_color(Color(0,0,0,0))
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=13.8
	var shader=Shader.new()
	shader.code="shader_type spatial; render_mode unshaded,cull_disabled; uniform sampler2D mesh_albedo:source_color,repeat_disable; uniform sampler2D bark_texture:source_color,repeat_enable; uniform bool canopy_only=false; varying vec3 normal_local;\n"+FileAccess.get_file_as_string("res://assets/graphics/pc_season_color.gdshaderinc")+"\nvoid vertex(){normal_local=NORMAL;} void fragment(){vec4 source=texture(mesh_albedo,UV);if(COLOR.a>=.4 && source.a<.35) discard;vec3 color=(COLOR.a<.4 && !source_textured)?texture(bark_texture,UV).rgb:source.rgb; ALBEDO=canopy_only?vec3(step(.4,COLOR.a)):season_color(color,normalize(normal_local))*COLOR.rgb;}"
	var masks={}
	for appearance in appearances:
		var config:Dictionary=appearances[appearance]
		var node=MeshInstance3D.new();node.mesh=models[config.source].meshes[0];stage.add_child(node)
		var mat=material(config,0);mat.shader=shader;node.material_override=mat
		var atlas=Image.create(4096,512,false,Image.FORMAT_RGBA8)
		for view in 8:
			var angle=view*TAU/8;camera.position=Vector3(sin(angle)*40,6,cos(angle)*40);camera.look_at(Vector3(0,6,0))
			for frame in 4:await process_frame
			await RenderingServer.frame_post_draw
			var frame=root.get_texture().get_image();frame.convert(Image.FORMAT_RGBA8)
			assert(frame.get_pixel(0,0).a<.01)
			atlas.blit_rect(frame,Rect2i(0,0,512,512),Vector2i(view*512,0))
		assert(atlas.save_png(PACK+"/"+appearance+"_atlas.png")==OK)
		if not masks.has(config.source):
			mat.set_shader_parameter("canopy_only",true)
			for view in 8:
				var angle=view*TAU/8;camera.position=Vector3(sin(angle)*40,6,cos(angle)*40);camera.look_at(Vector3(0,6,0))
				for frame in 4:await process_frame
				await RenderingServer.frame_post_draw
				var frame=root.get_texture().get_image();frame.convert(Image.FORMAT_RGBA8)
				atlas.blit_rect(frame,Rect2i(0,0,512,512),Vector2i(view*512,0))
			assert(atlas.save_png(PACK+"/"+config.source+"_canopy.png")==OK)
			masks[config.source]=true
		node.free();print("SEASON_ATLAS ",appearance)

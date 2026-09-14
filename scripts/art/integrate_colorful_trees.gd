extends SceneTree
## Repack the preserved portable sources into the production one-surface contract.
const SOURCE = "res://art_source/trees/colorful_v1/"
const DEST = "res://assets/graphics/trees/"
var selected = ""
var receipts: Array = []
var stage: Node3D
var camera: Camera3D
func _initialize() -> void: call_deferred("run")

func read_json(path: String): return JSON.parse_string(FileAccess.get_file_as_string(path))
func write_json(path: String, data) -> void:
	FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(data,"\t",true,true)+"\n")
func save(resource: Resource, path: String) -> void:
	var uid=ResourceLoader.get_resource_uid(path) if FileAccess.file_exists(path) else -1
	assert(ResourceSaver.save(resource,path,ResourceSaver.FLAG_COMPRESS)==OK,path)
	if uid!=-1: assert(ResourceSaver.set_uid(path,uid)==OK)
	receipts.append({"path":path,"sha256":FileAccess.get_sha256(path)})

func import_tree(record: Dictionary, lod: int) -> Node3D:
	var model: Dictionary=record.models[lod]
	var path=SOURCE+"models/"+model.file
	assert(FileAccess.get_sha256(path)==model.sha256,"Prepared model changed: "+path)
	var document=GLTFDocument.new(); var state=GLTFState.new()
	assert(document.append_from_file(path,state)==OK)
	return document.generate_scene(state)

func pack(node: Node3D, material_name: String) -> ArrayMesh:
	var surface=SurfaceTool.new(); surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for child in node.find_children("*","MeshInstance3D",true,false):
		var pose: Transform3D=child.transform
		var parent=child.get_parent()
		while parent is Node3D and parent!=node:
			pose=parent.transform*pose; parent=parent.get_parent()
		for i in child.mesh.get_surface_count():
			var source: Material=child.mesh.surface_get_material(i)
			var role=source.resource_name.trim_prefix("PreparedTree_")
			assert(role in ["Wood","Leaves","Snow"],"Unexpected source material")
			var data: Array=child.mesh.surface_get_arrays(i)
			var colors: PackedColorArray=data[Mesh.ARRAY_COLOR]
			for j in colors.size(): colors[j].a={"Wood":0.0,"Leaves":0.7,"Snow":1.0}[role]
			data[Mesh.ARRAY_COLOR]=colors
			var part=ArrayMesh.new(); part.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,data)
			surface.append_from(part,0,pose)
	surface.index()
	var mat=StandardMaterial3D.new(); mat.resource_name=material_name
	surface.set_material(mat)
	return surface.commit()

func model_record(mesh: ArrayMesh, path: String) -> Dictionary:
	save(mesh,path)
	var size=mesh.get_aabb().size
	return {"path":path.trim_prefix("res://"),"sha256":FileAccess.get_sha256(path),
		"triangles":mesh.get_faces().size()/3,"bytes":FileAccess.get_file_as_bytes(path).size(),
		"dimensions_blender_xyz_m":[size.x,size.z,size.y]}

func shadow_mesh(mesh: ArrayMesh) -> ArrayMesh:
	var importer=ImporterMesh.from_mesh(mesh)
	importer.generate_lods(60.0,60.0,[])
	var data=mesh.surface_get_arrays(0)
	var chosen: PackedInt32Array=data[Mesh.ARRAY_INDEX]
	for i in importer.get_surface_lod_count(0):
		var indices=importer.get_surface_lod_indices(0,i)
		if indices.size()/3>=900 and indices.size()<chosen.size(): chosen=indices
	data[Mesh.ARRAY_INDEX]=chosen
	var result=ArrayMesh.new(); result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,data)
	result.surface_set_material(0,mesh.surface_get_material(0))
	# The selected index set no longer uses most source vertices. Compact their
	# attributes too, preserving the exact shadow triangles while bounding VRAM.
	var compact=SurfaceTool.new(); compact.create_from(result,0); compact.deindex(); compact.index()
	var packed=compact.commit()
	assert(result.get_faces()==packed.get_faces())
	return packed

func branches(mesh: ArrayMesh) -> Array:
	var data=mesh.surface_get_arrays(0); var points: PackedVector3Array=data[Mesh.ARRAY_VERTEX]
	var tags: PackedVector2Array=data[Mesh.ARRAY_TEX_UV2]; var result=[]
	for cluster in 12:
		var members: Array[Vector3]=[]; var center=Vector3.ZERO; var pivot=0.0
		for i in points.size():
			if roundi(tags[i].x*16.0)!=cluster: continue
			members.append(points[i]); center+=points[i]; pivot=tags[i].y*32.0
		if not members.is_empty(): center/=members.size()
		var radius=.1
		for p in members: radius=maxf(radius,p.distance_to(center))
		result.append({"center":[center.x,center.y,center.z],"radius":minf(mesh.get_aabb().size.y*.21,radius),"pivot_y":pivot})
	return result

func texture_levels(source: Image, stem: String, normal: bool=false) -> void:
	for level in 3:
		var image=source.duplicate(); image.clear_mipmaps()
		var divisor=1<<(2-level)
		image.resize(source.get_width()/divisor,source.get_height()/divisor,Image.INTERPOLATE_LANCZOS)
		image.generate_mipmaps(normal)
		assert(image.compress(Image.COMPRESS_BPTC)==OK,"BC7 packing")
		save(ImageTexture.create_from_image(image),DEST+"textures/"+stem+["_low","_balanced",""][level]+".res")

func canopy_atlas(node: Node3D, atlas: Dictionary) -> Image:
	stage.add_child(node)
	for child in node.find_children("*","MeshInstance3D",true,false):
		for i in child.mesh.get_surface_count():
			var role=child.mesh.surface_get_material(i).resource_name
			var mat=StandardMaterial3D.new(); mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.cull_mode=BaseMaterial3D.CULL_DISABLED
			mat.albedo_color=Color.BLACK if role.ends_with("Wood") else Color.WHITE
			child.set_surface_override_material(i,mat)
	camera.size=atlas.span_m
	var result=Image.create(4096,512,false,Image.FORMAT_RGBA8)
	for view in 8:
		var angle=float(view)*TAU/8.0
		camera.position=Vector3(sin(angle)*atlas.span_m*3,atlas.center_height_m,cos(angle)*atlas.span_m*3)
		camera.look_at(Vector3(0,atlas.center_height_m,0))
		for frame in 4: await process_frame
		await RenderingServer.frame_post_draw
		var img=root.get_texture().get_image(); img.convert(Image.FORMAT_RGBA8)
		assert(img.get_pixel(0,0).a<.01,"Transparent canopy atlas")
		result.blit_rect(img,Rect2i(0,0,512,512),Vector2i(view*512,0))
	stage.remove_child(node)
	return result

func run() -> void:
	assert(DisplayServer.get_name()!="headless","Native atlas packing required")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--asset="): selected=arg.trim_prefix("--asset=")
	root.size=Vector2i(512,512); root.transparent_bg=true; root.msaa_3d=Viewport.MSAA_4X
	RenderingServer.set_default_clear_color(Color(0,0,0,0)); Engine.max_fps=60
	stage=Node3D.new(); root.add_child(stage)
	camera=Camera3D.new(); camera.projection=Camera3D.PROJECTION_ORTHOGONAL; stage.add_child(camera)
	var catalog: Dictionary=read_json(SOURCE+"manifest.json")
	var atlases: Array=read_json(SOURCE+"impostors/manifest.json")
	var production={"assets":[],"families":{}}
	var definitions={}
	for channel in ["albedo","normal","roughness"]:
		texture_levels(Image.load_from_file(SOURCE+"textures/leaf_"+channel+".png"),"broadleaf_"+channel,channel=="normal")
	var built=0
	for record in catalog.assets:
		var family="golden" if record.family=="golden_birch" else "maple"
		var variant=int(record.id.right(2)); var id="forest_%s_%02d" % [family,variant]
		if not selected.is_empty() and selected!=id: continue
		var near_node=import_tree(record,0); var mid_node=import_tree(record,2)
		var near=pack(near_node,"FC_Broadleaf"); var mid=pack(mid_node,"FC_Broadleaf")
		var atlas: Dictionary=atlases.filter(func(a): return a.id==record.id)[0]
		assert(atlas.source_model_sha256==record.models[0].sha256)
		var image_path=SOURCE+"impostors/"+atlas.file
		assert(FileAccess.get_sha256(image_path)==atlas.sha256)
		texture_levels(Image.load_from_file(image_path),id+"_atlas")
		texture_levels(await canopy_atlas(near_node,atlas),id+"_canopy")
		var card=QuadMesh.new(); card.size=Vector2.ONE*float(atlas.span_m)
		card.center_offset=Vector3(0,atlas.center_height_m,0)
		var far=ArrayMesh.new(); far.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,card.get_mesh_arrays())
		var far_mat=StandardMaterial3D.new(); far_mat.resource_name="FC_Impostor_"+id.trim_prefix("forest_")
		far.surface_set_material(0,far_mat)
		var models=[]
		for pair in [[near,0],[mid,1],[far,2]]: models.append(model_record(pair[0],DEST+"models/%s_lod%d.res" % [id,pair[1]]))
		var box=near.get_aabb(); var center=box.get_center()
		var entry={"id":id,"family":family,"variant":variant,"height_m":box.size.y,"nominal_height_m":record.nominal_height_m,
			"seed":record.seed,"models":models,"branches":branches(near),"atlas_complete":true,
			"shadow":model_record(shadow_mesh(mid),DEST+"models/"+id+"_shadow.res"),
			"foliage_type":record.leaf_type,"palette_srgb":record.palette_srgb,"crown_center":[center.x,center.y,center.z],
			"crown_radius":box.size.length()*.5,"source_blend":SOURCE.trim_prefix("res://")+"blends/"+record.blend,
			"prepared_source":record,"prepared_manifest_sha256":FileAccess.get_sha256(SOURCE+"manifest.json"),
			"runtime_builder":"scripts/art/integrate_colorful_trees.gd","runtime_builder_sha256":FileAccess.get_sha256("res://scripts/art/integrate_colorful_trees.gd")}
		production.assets=production.assets.filter(func(a): return a.id!=id); production.assets.append(entry)
		definitions[id]={"branches":entry.branches}
		production.families[family]={"label":"Golden birch" if family=="golden" else "Autumn maple","variants":3,"foliage_type":record.leaf_type}
		near_node.free(); mid_node.free(); built+=1
		print("COLORFUL_TREE_PACKED ",id," triangles ",models[0].triangles," / ",models[1].triangles," / 2; shadow ",entry.shadow.triangles)
	assert(built>0,"Unknown colorful asset")
	DirAccess.make_dir_recursive_absolute("res://artifacts/colorful_forest_variety")
	# The wrapper merges this additive update with Python's exact JSON numbers;
	# do not round-trip existing authored metadata through Godot's JSON parser.
	production["branches"]=definitions
	write_json("res://artifacts/colorful_forest_variety/catalog_update.json",production)
	write_json("res://artifacts/colorful_forest_variety/packing.json",receipts)
	print("COLORFUL_PACK_COMPLETE ",built); quit()

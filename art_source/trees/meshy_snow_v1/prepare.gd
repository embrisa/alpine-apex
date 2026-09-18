extends SceneTree
## Isolated native source review and eight-view albedo bake. No runtime writes.
const SOURCE="res://art_source/trees/meshy_snow_v1"
const OUT="res://artifacts/meshy_snow_20260918"
const SPECIES=["spruce","fir","stone_pine","winter_birch_v2"]
var camera:Camera3D
var stage:Node3D
var floor_node:MeshInstance3D
var environment:Environment
var models={}
var report={"sources":[],"captures":[],"scope":"Native isolated source review; not gameplay or FPS acceptance"}
var mode="review"
var smooth_normals=false
var high_detail=false
var candidate=false
func _initialize():call_deferred("run")
func gather(node:Node,parent:=Transform3D.IDENTITY)->Array:
	var result=[]
	var pose=parent*node.transform if node is Node3D else parent
	if node is MeshInstance3D:
		for s in node.mesh.get_surface_count():
			var a=node.mesh.surface_get_arrays(s).duplicate(true)
			var v:PackedVector3Array=a[Mesh.ARRAY_VERTEX]
			var n:PackedVector3Array=a[Mesh.ARRAY_NORMAL]
			var t:PackedFloat32Array=a[Mesh.ARRAY_TANGENT]
			for i in v.size():
				v[i]=pose*v[i];n[i]=(pose.basis.inverse().transposed()*n[i]).normalized()
				if not t.is_empty():
					var tangent=(pose.basis*Vector3(t[i*4],t[i*4+1],t[i*4+2])).normalized()
					t[i*4]=tangent.x;t[i*4+1]=tangent.y;t[i*4+2]=tangent.z
			a[Mesh.ARRAY_VERTEX]=v;a[Mesh.ARRAY_NORMAL]=n;a[Mesh.ARRAY_TANGENT]=t
			result.append({"arrays":a,"material":node.get_active_material(s)})
	for child in node.get_children():result.append_array(gather(child,pose))
	return result
func load_source(species:String,lod:int)->ArrayMesh:
	var filename=("tree_high.glb" if lod==0 else "tree.glb") if high_detail and species!="winter_birch" else ("tree.glb" if lod==0 else "tree_mid.glb")
	if candidate:filename=("tree.glb" if species=="winter_birch_v2" else "tree_detail.glb") if lod==0 else "tree_local_mid.glb"
	var path=SOURCE+"/"+species+"/"+filename
	var state=GLTFState.new();var document=GLTFDocument.new()
	assert(document.append_from_file(path,state)==OK,path)
	var root_node=document.generate_scene(state);var parts=gather(root_node)
	assert(parts.size()==1,"Expected one opaque surface")
	var mat:StandardMaterial3D=parts[0].material
	assert(mat.transparency==BaseMaterial3D.TRANSPARENCY_DISABLED)
	var a:Array=parts[0].arrays
	var vertices:PackedVector3Array=a[Mesh.ARRAY_VERTEX]
	var box=AABB(vertices[0],Vector3.ZERO)
	for vertex in vertices:box=box.expand(vertex)
	var root_center=Vector2.ZERO;var root_count=0
	for vertex in vertices:
		if vertex.y<=box.position.y+box.size.y*.015:
			root_center+=Vector2(vertex.x,vertex.z);root_count+=1
	root_center/=maxi(1,root_count)
	# Both LODs use the detailed source frame, so remesh bounds cannot pump size.
	var reference:Dictionary=models[species].frame if lod==1 else {"bottom":box.position.y,"center":root_center,"height":box.size.y}
	var scale_m=12.0/reference.height
	for i in vertices.size():vertices[i]=(vertices[i]-Vector3(reference.center.x,reference.bottom,reference.center.y))*scale_m
	a[Mesh.ARRAY_VERTEX]=vertices
	if smooth_normals:
		var normals:PackedVector3Array=a[Mesh.ARRAY_NORMAL]
		var groups={}
		for i in vertices.size():
			if not groups.has(vertices[i]):groups[vertices[i]]=[]
			groups[vertices[i]].append(i)
		var original=normals.duplicate()
		for indices in groups.values():
			for i in indices:
				var sum=Vector3.ZERO
				for j in indices:
					if original[i].dot(original[j])>.35:sum+=original[j]
				normals[i]=sum.normalized()
		a[Mesh.ARRAY_NORMAL]=normals
	var mesh=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,a)
	var optimizer=SurfaceTool.new();optimizer.create_from(mesh,0)
	if smooth_normals:optimizer.generate_tangents()
	optimizer.optimize_indices_for_cache();mesh=optimizer.commit()
	mesh.surface_set_material(0,mat)
	if lod==0:models[species]={"frame":reference,"meshes":[]}
	models[species].meshes.append(mesh)
	report.sources.append({"species":species,"lod":lod,"source":path,"vertices":mesh.surface_get_array_len(0),"triangles":mesh.surface_get_array_index_len(0)/3,"bounds":str(mesh.get_aabb()),"surfaces":1,"opaque":true})
	root_node.free();return mesh
func run():
	assert(OS.get_environment("ALPINE_VALIDATION_MODE")=="Exclusive")
	for arg in OS.get_cmdline_user_args():
		if arg=="--bake":mode="bake"
		if arg=="--smooth":smooth_normals=true
		if arg=="--high":high_detail=true
		if arg=="--candidate":candidate=true
	DirAccess.make_dir_recursive_absolute(OUT+"/source_review")
	DirAccess.make_dir_recursive_absolute(OUT+"/prepared")
	var common=FileAccess.get_file_as_string("res://assets/graphics/pc_forest_tree_common.gdshaderinc")
	var vertex=common.substr(0,common.find("void fragment()"))
	var fragment=FileAccess.get_file_as_string(SOURCE+"/fragment.gdshaderinc")
	for lod in 2:
		var shader="shader_type spatial;\nrender_mode cull_disabled;\n"+("#define ALPINE_FOREST_MID\n" if lod==1 else "")+vertex+fragment
		FileAccess.open(OUT+"/prepared/pc_forest_tree_snow_"+str(lod)+".gdshader",FileAccess.WRITE).store_string(shader)
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
	for species in SPECIES:
		load_source(species,0)
		if candidate or FileAccess.file_exists(SOURCE+"/"+species+"/tree_mid.glb"):load_source(species,1)
		for lod in models[species].meshes.size():
			assert(ResourceSaver.save(models[species].meshes[lod],OUT+"/prepared/"+species+"_"+str(lod)+".res")==OK)
	await review()
	if mode=="bake":await bake()
	FileAccess.open(OUT+"/"+mode+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("MESHY_SOURCE_DONE ",JSON.stringify(report));quit()
func review():
	var nodes=[]
	for i in SPECIES.size():
		var node=MeshInstance3D.new();node.mesh=models[SPECIES[i]].meshes[0];node.position.x=(i-1.5)*9;stage.add_child(node);nodes.append(node)
	camera.position=Vector3(0,10,40);camera.look_at(Vector3(0,6,0))
	await capture("lineup_detail")
	for i in nodes.size():
		var node:MeshInstance3D=nodes[i]
		for other in nodes:other.visible=other==node
		camera.position=node.position+Vector3(13,7,20);camera.look_at(node.position+Vector3(0,6,0))
		for lod in models[SPECIES[i]].meshes.size():
			node.mesh=models[SPECIES[i]].meshes[lod];await capture(SPECIES[i]+"_lod"+str(lod))
	for node in nodes:node.free()
func capture(name:String):
	for i in 12:await process_frame
	await RenderingServer.frame_post_draw
	var path=OUT+"/source_review/"+name+("_candidate" if candidate else "")+("_high" if high_detail else "")+("_smooth" if smooth_normals else "")+".webp"
	assert(root.get_texture().get_image().save_webp(path,true)==OK)
	report.captures.append(path);print("MESHY_CAPTURE ",path)
func bake():
	floor_node.visible=false;root.size=Vector2i(512,512);root.transparent_bg=true
	root.scaling_3d_scale=1;root.msaa_3d=Viewport.MSAA_4X
	environment.background_mode=Environment.BG_CLEAR_COLOR
	RenderingServer.set_default_clear_color(Color(0,0,0,0))
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=13.8
	for species in SPECIES:
		var node=MeshInstance3D.new();node.mesh=models[species].meshes[0];stage.add_child(node)
		var mat:StandardMaterial3D=node.mesh.surface_get_material(0).duplicate();mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;node.material_override=mat
		var atlas=Image.create(4096,512,false,Image.FORMAT_RGBA8)
		for view in 8:
			var angle=view*TAU/8;camera.position=Vector3(sin(angle)*40,6,cos(angle)*40);camera.look_at(Vector3(0,6,0))
			for i in 4:await process_frame
			await RenderingServer.frame_post_draw
			var frame=root.get_texture().get_image();frame.convert(Image.FORMAT_RGBA8)
			assert(frame.get_pixel(0,0).a<.01,"Transparent atlas")
			atlas.blit_rect(frame,Rect2i(0,0,512,512),Vector2i(view*512,0))
		assert(atlas.save_png(OUT+"/prepared/"+species+"_atlas.png")==OK)
		node.free();print("MESHY_ATLAS ",species)

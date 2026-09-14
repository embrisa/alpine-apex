extends SceneTree
## Immutable centimetre sources become shared, non-overlapping half-metre tiles.
const SOURCE="res://art_source/rocks/pebbles_v1/"
const DEST="res://assets/graphics/gravel/"
const SOURCE_SHA="3499916ddf9989cb33070643e06922d90dbba57718ecd621acf40d85bc1ff906"
var receipts=[]
var meshes={}
var catalog: Dictionary
func _initialize() -> void: call_deferred("run")
func save(resource: Resource,path: String) -> void:
	var uid=ResourceLoader.get_resource_uid(path) if FileAccess.file_exists(path) else -1
	assert(ResourceSaver.save(resource,path,ResourceSaver.FLAG_COMPRESS)==OK,path)
	if uid!=-1: assert(ResourceSaver.set_uid(path,uid)==OK)
	receipts.append({"path":path,"sha256":FileAccess.get_sha256(path),"bytes":FileAccess.get_file_as_bytes(path).size()})
func run() -> void:
	assert(FileAccess.get_sha256(SOURCE+"manifest.json")==SOURCE_SHA,"Use the final 1–10 cm source pack")
	catalog=JSON.parse_string(FileAccess.get_file_as_string(SOURCE+"manifest.json"))
	DirAccess.make_dir_recursive_absolute(DEST)
	for record in catalog.assets:
		for lod in [0,2]:
			var model: Dictionary=record.models[lod]
			var path=SOURCE+"models/"+model.file
			assert(FileAccess.get_sha256(path)==model.sha256)
			var document=GLTFDocument.new(); var state=GLTFState.new()
			assert(document.append_from_file(path,state)==OK)
			var scene=document.generate_scene(state)
			var nodes=scene.find_children("*","MeshInstance3D",true,false)
			assert(nodes.size()==1 and nodes[0].mesh.get_surface_count()==1)
			assert(scene.find_children("*","CollisionObject3D",true,false).is_empty())
			meshes[record.id+str(lod)]=nodes[0].mesh
			scene.free()
	for channel in catalog.material.textures:
		var record: Dictionary=catalog.material.textures[channel]
		var path=SOURCE+record.path
		assert(FileAccess.get_sha256(path)==record.sha256)
		var image=Image.load_from_file(path); image.generate_mipmaps(channel=="normal")
		assert(image.compress(Image.COMPRESS_BPTC)==OK)
		save(ImageTexture.create_from_image(image),DEST+channel+".res")
	var tiles=[]
	for mode in ["dense","sparse"]:
		for variant in 4:
			var stones=arrange(mode,variant)
			var outputs=[]
			for lod in [0,2]:
				var mesh=tile(stones,lod)
				var path=DEST+"%s_%d_lod%d.res" % [mode,variant,lod]
				save(mesh,path); outputs.append({"path":path,"triangles":mesh.get_faces().size()/3})
			var limits={"min_width":1.0,"max_width":0.0,"max_exposed":0.0,"minimum_gap":1.0}
			for i in stones.size():
				var s: Dictionary=stones[i]
				limits.min_width=minf(limits.min_width,s.width); limits.max_width=maxf(limits.max_width,s.width)
				limits.max_exposed=maxf(limits.max_exposed,s.height-s.burial)
				for j in i:
					limits.minimum_gap=minf(limits.minimum_gap,Vector2(s.x,s.z).distance_to(Vector2(stones[j].x,stones[j].z))-s.radius-stones[j].radius)
			assert(limits.min_width>=.00999 and limits.max_width<=.10001 and limits.max_exposed<=.010001 and limits.minimum_gap>=0)
			tiles.append({"id":"%s_%d" % [mode,variant],"mode":mode,"variant":variant,"count":stones.size(),"stones_per_m2":stones.size()*4,"limits":limits,"models":outputs,"stones":stones})
	var output={"schema":1,"source_manifest_sha256":SOURCE_SHA,"builder_sha256":FileAccess.get_sha256("res://scripts/art/integrate_rock_gravel.gd"),"tile_width_m":.5,"collision":false,"tiles":tiles,"files":receipts}
	FileAccess.open(DEST+"manifest.json",FileAccess.WRITE).store_string(JSON.stringify(output,"\t",true,true)+"\n")
	print("GRAVEL_PACK_COMPLETE tiles=8 resources=19"); quit()
func arrange(mode: String,variant: int) -> Array:
	var rng=RandomNumberGenerator.new(); rng.seed=914000+variant+int(mode=="sparse")*100
	var stones=[]
	# Large stones are placed first so filling cannot quietly omit rare accents.
	var counts={"shale_chip":1,"pebble":7,"gravel":52,"grit":215} if mode=="dense" else {"shale_chip":int(variant==0),"pebble":int(variant==1),"gravel":1,"grit":int(variant>=2)}
	for family in counts:
		for index in counts[family]:
			var id="%s_%02d" % [family,rng.randi_range(1,3)]
			var mesh: Mesh=meshes[id+"0"]; var box=mesh.get_aabb()
			var radius=0.0
			for p in mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]: radius=maxf(radius,Vector2(p.x,p.z).length())
			var stone={"id":id,"x":0.0,"z":0.0,"yaw":rng.randf()*TAU,"radius":radius,"width":maxf(box.size.x,box.size.z),"height":box.size.y,"burial":maxf(box.size.y*.3,box.size.y-.01)}
			var found=false
			for attempt in 3000:
				stone.x=rng.randf_range(radius+.001,.5-radius-.001); stone.z=rng.randf_range(radius+.001,.5-radius-.001)
				found=true
				for old in stones:
					if Vector2(old.x,old.z).distance_squared_to(Vector2(stone.x,stone.z))<pow(old.radius+radius+.0004,2): found=false; break
				if found: break
			assert(found,"Dense packing must retain its count and exact asset mix")
			stones.append(stone)
	return stones
func tile(stones: Array,lod: int) -> ArrayMesh:
	var surface=SurfaceTool.new(); surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for s in stones:
		var mesh: Mesh=meshes[s.id+str(lod)]
		var arrays=mesh.surface_get_arrays(0)
		var uv2=PackedVector2Array(); uv2.resize(arrays[Mesh.ARRAY_VERTEX].size()); uv2.fill(Vector2(s.x,s.z)); arrays[Mesh.ARRAY_TEX_UV2]=uv2
		var part=ArrayMesh.new(); part.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		surface.append_from(part,0,Transform3D(Basis(Vector3.UP,s.yaw),Vector3(s.x,-s.burial,s.z)))
	surface.index()
	return surface.commit()

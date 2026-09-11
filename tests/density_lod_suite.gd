extends SceneTree
## Authored foliage budgets and mip coverage, using imported production resources.
const Assets=preload("res://scripts/presentation/alpine_assets.gd")
const Quality=preload("res://scripts/presentation/graphics_quality.gd")
const Clouds=preload("res://scripts/presentation/cloud_lighting.gd")
const Forest=preload("res://scripts/presentation/density_forest.gd")
var checks=0
var failures=[]
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label); printerr("FAIL ",label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var library=Assets.new(Clouds.new(),Quality.preset(2))
	var manifest=JSON.parse_string(FileAccess.get_file_as_string("res://assets/graphics/trees/manifest.json"))
	check(manifest.version==3 and manifest.assets.size()==24,"Current collection retains 24 variants")
	for row in manifest.assets:
		var living=row.family in ["spruce","fir","pine"]
		for lod in 3:
			var mesh=library.mesh(row.id+"_lod%d" % lod)
			var triangles=mesh.get_faces().size()/3
			check(FileAccess.get_sha256("res://"+row.models[lod].path)==row.models[lod].sha256,"Asset hash "+row.id)
			check(mesh.get_surface_count()==1,"One visible surface "+row.id)
			if living:
				check(triangles<=[30000,6000,2][lod],"Authored LOD budget "+row.id)
				if lod<2:
					var arrays=mesh.surface_get_arrays(0); var tagged=0
					var center=Vector3(row.crown_center[0],row.crown_center[1],row.crown_center[2])
					var enclosed=true
					for i in arrays[Mesh.ARRAY_COLOR].size():
						var color: Color=arrays[Mesh.ARRAY_COLOR][i]
						if color.a>.65 and color.a<.8:
							tagged+=1
							enclosed=enclosed and arrays[Mesh.ARRAY_VERTEX][i].distance_to(center)<=float(row.crown_radius)+.15
					check(tagged>0,"Textured foliage vertex mask "+row.id)
					check(enclosed,"Crown contains near and middle foliage "+row.id)
					check(absf(mesh.get_aabb().end.y-float(row.normalization_bounds.max[1]))<.005,"Preserved top normalization "+row.id)
					var swept=true; var box=library.tree_render_bounds(row.id)
					# Triangle inequality bounds all Euler rotations, including the
					# .32-radian contact stop plus maximum two-axis 7 m/s wind.
					var sweep_angle=sqrt(3.0)*.32+sqrt(2.0)*7.0*.005*1.35
					for i in arrays[Mesh.ARRAY_VERTEX].size():
						var p: Vector3=arrays[Mesh.ARRAY_VERTEX][i]
						var pivot=Vector3(0,arrays[Mesh.ARRAY_TEX_UV2][i].y*32.0,0)
						var displacement=2*sin(sweep_angle*.5)*p.distance_to(pivot)
						swept=swept and box.has_point(p+Vector3.ONE*displacement) and box.has_point(p-Vector3.ONE*displacement)
					check(swept,"Conservative bound covers every contact/wind rotation "+row.id)
		if living:
			check(row.foliage_revision==3 and row.crown_radius>0,"Crown metadata "+row.id)
			var shadow=library.tree_shadow(row.id)
			check(shadow.get_faces().size()/3<=1500,"Dedicated shadow budget "+row.id)
			check(FileAccess.get_sha256("res://"+row.shadow.path)==row.shadow.sha256,"Shadow integrity "+row.id)
			var bounds=library.tree_render_bounds(row.id)
			var contained=true
			for p in shadow.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]: contained=contained and bounds.has_point(p)
			check(contained,"Motion/culling bounds contain shadow "+row.id)
	for level in 3:
		library.apply_quality(Quality.preset(level))
		var mat: ShaderMaterial=library.mesh("forest_spruce_01_lod0").surface_get_material(0)
		var texture: Texture2D=mat.get_shader_parameter("foliage_texture")
		var img=texture.get_image(); img.decompress()
		check(img.get_width()==[512,1024,2048][level] and img.has_mipmaps(),"Quality selects precomputed coverage mips")
		if level==2:
			var reference=Image.load_from_file("res://assets/graphics/trees/textures/foliage_color.png")
			var error=0.0; var samples=0
			for y in range(0,2048,16):
				for x in range(0,2048,16):
					var a=reference.get_pixel(x,y); var b=img.get_pixel(x,y)
					if a.a>.6 and b.a>.6:
						error+=absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b); samples+=3
			check(samples>100 and error/maxi(samples,1)<.025,"Runtime atlas retains source sRGB color without double encoding")
		var original=coverage(img,0)
		for mip in mini(6,img.get_mipmap_count()):
			var area=coverage(img,mip)
			check(absf(area-original)<.07,"Mipmap keeps needle area at level %d mip %d" % [level,mip])
	check(Forest.LOAD_RADIUS>64+32 and Forest.KEEP_RADIUS>Forest.LOAD_RADIUS,"Detail preload and retention stay bounded")
	DirAccess.make_dir_recursive_absolute("res://artifacts/foliage_v3")
	FileAccess.open("res://artifacts/foliage_v3/asset_checks.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"\t"))
	print("DENSITY_LOD_SUITE ",checks," checks; failures=",failures); quit(0 if failures.is_empty() else 1)
func coverage(img: Image, mip: int) -> float:
	var size=img.get_width()>>mip
	var image=Image.create_from_data(size,size,false,Image.FORMAT_RGBA8,img.get_data().slice(img.get_mipmap_offset(mip),img.get_mipmap_offset(mip)+size*size*4))
	var hit=0; var count=0; var stride=maxi(1,size/256)
	for y in range(0,size,stride):
		for x in range(0,size,stride):
			hit+=int(image.get_pixel(x,y).a>=.5); count+=1
	return float(hit)/count

extends SceneTree
const Readability = preload("res://scripts/presentation/snow_readability.gd")
const Surface = preload("res://scripts/world/heightfield_surface.gd")
var checks = 0
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	print("PASS: " if ok else "FAIL: ",label)
	if not ok: failures.append(label)

func fixture(slope: Vector2, hollow: float = 0.0):
	var field = Surface.new()
	field.NX = 65; field.NZ = 65; field.X_MIN = -128; field.Z_MIN = -128
	field.heights.resize(field.NX*field.NZ)
	for z in field.NZ:
		for x in field.NX:
			var p = Vector2(x-32,z-32)*4.0
			field.heights[z*field.NX+x] = 4000.0+p.dot(slope)-hollow*exp(-p.length_squared()/128.0)
	return field

func run() -> void:
	var harness = load("res://tests/snow_readability_playtest.gd")
	check(harness!=null and harness.can_instantiate(),"Native comparison harness parses before loading a rendered mountain")
	var retune_harness = load("res://tests/snow_readability_retune_playtest.gd")
	check(retune_harness!=null and retune_harness.can_instantiate(),"Stronger snow comparison harness parses")
	for slope in [Vector2.ZERO,Vector2(.5,-.75),Vector2(-1.25,.25),Vector2(.123,-.879)]:
		var field = fixture(slope)
		var map = Readability.build_image(field.heights,field.NX,field.NZ)
		var maximum = 0
		for value in map.get_data(): maximum = maxi(maximum,value)
		check(maximum==0,"Flat and tilted planes remain neutral, including boundaries and mipmaps: "+str(slope))
	var bowl = fixture(Vector2(.5,-.75),1.0)
	var original = bowl.heights.to_byte_array()
	var shading = Readability.new()
	shading.prepare(bowl)
	check(original==bowl.heights.to_byte_array() and bowl.material_image==null,"Preparation leaves terrain heights and contact materials untouched")
	var centre = shading.image.get_pixel(32,32).r
	check(centre>.9,"A real shallow hollow receives bounded shape shading")
	check(shading.image.get_pixel(1,1).r==0,"Shading stays near the feature instead of tinting the whole slope")
	var mound = fixture(Vector2(.5,-.75),-1.0)
	var mound_image = Readability.build_image(mound.heights,mound.NX,mound.NZ)
	check(mound_image.get_pixel(32,32).r==0,"Convex crowns never become dark pits or bright outlines")
	var rotated = fixture(Vector2(-.75,.5),1.0)
	var rotated_image = Readability.build_image(rotated.heights,rotated.NX,rotated.NZ)
	var rotated_equal = true
	for z in bowl.NZ:
		for x in bowl.NX:
			rotated_equal = rotated_equal and shading.image.get_pixel(x,z)==rotated_image.get_pixel(z,x)
	check(rotated_equal,"Concavity follows terrain shape independently of slope orientation")
	check(shading.image.has_mipmaps() and shading.image.get_format()==Image.FORMAT_R8,"Single-channel shape map includes filtered distance levels")
	var repeats = Readability.build_image(bowl.heights,bowl.NX,bowl.NZ)
	check(repeats.get_data()==shading.image.get_data(),"Identical final heights produce identical presentation data")
	var parallel = Readability.build_image(bowl.heights,bowl.NX,bowl.NZ,bowl.CELL,4)
	check(parallel.get_data()==repeats.get_data(),"Row-job boundaries preserve identical hollow pixels and mipmaps")
	var materials: Array[ShaderMaterial] = []
	for path in ["alpine_surface","powder_surface","ski_track"]:
		var material = ShaderMaterial.new()
		material.shader = load("res://assets/graphics/"+path+".gdshader")
		shading.bind(material)
		materials.append(material)
	var shared = true
	for material in materials:
		shared = shared and material.get_shader_parameter("snow_hollows")==shading.texture
		shared = shared and material.get_shader_parameter("snow_hollows_origin")==Vector2(-128,-128)
	check(shared and shading.builds==1,"Terrain, powder and tracks share one upload and identical world mapping")
	check(shading.report().texture_bytes<65*65*1.34,"Texture and mip memory stays within the single-channel budget")
	if "--mountain" in OS.get_cmdline_user_args():
		var field = preload("res://scripts/world/mountain_definition.gd").generate(849205174,15)
		var identity = [field.height_checksum,field.obstacle_checksum,hash(field.heights),hash(field.tree_data.positions)]
		var full_map = Readability.new()
		full_map.prepare(field)
		check(identity==[field.height_checksum,field.obstacle_checksum,hash(field.heights),hash(field.tree_data.positions)],"Default v15 shading preserves terrain and obstacle identities")
		check(full_map.image.get_size()==Vector2i(field.NX,field.NZ),"Default mountain maps every support-grid vertex")
		var serial = Readability.build_image(field.heights,field.NX,field.NZ,field.CELL,1)
		check(serial.get_data()==full_map.image.get_data(),"Full v15 single-worker and parallel maps are byte-identical")
		print("SNOW_READABILITY_MOUNTAIN ",JSON.stringify(full_map.report()))
	DirAccess.make_dir_recursive_absolute("res://artifacts/snow_readability")
	FileAccess.open("res://artifacts/snow_readability/automated.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"\t"))
	quit(0 if failures.is_empty() else 1)

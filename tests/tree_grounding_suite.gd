extends SceneTree
const Contacts = preload("res://scripts/presentation/asset_snow_contacts.gd")
const Surface = preload("res://scripts/world/heightfield_surface.gd")
const Quality = preload("res://scripts/presentation/graphics_quality.gd")
var checks = 0
var failures: Array = []
class SnowField:
	extends "res://scripts/world/heightfield_surface.gd"
	func snow_depth_at(_x: float, _z: float) -> float: return .3

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr("FAIL: ",label)

func _initialize() -> void:
	var library = preload("res://scripts/presentation/alpine_assets.gd").new(preload("res://scripts/presentation/cloud_lighting.gd").new(),Quality.preset(2))
	var contacts = Contacts.new()
	var field = Surface.new(); field.X_MIN = -16; field.Z_MIN = -16; field.NX = 9; field.NZ = 9
	field.heights.resize(81)
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/graphics/trees/manifest.json"))
	var maximum_burial = 0.0
	for degrees in [0,20,40]:
		for z in 9:
			for x in 9: field.heights[z*9+x] = tan(deg_to_rad(degrees))*(field.X_MIN+x*4.0)+.12*(field.Z_MIN+z*4.0)
		var original_heights = field.heights.duplicate()
		for record in manifest.assets:
			var footprint = contacts.root_footprint(record.id,library)
			check(footprint.size()>=6,record.id+" has a real root footprint")
			for size in [.65,1.65]:
				var scale_value = size*10.5/float(record.height_m)
				var point = Vector3(1.2,field.sample(1.2,2.3).height,2.3)
				var original = Transform3D(Basis(Vector3.UP,1.3).scaled(Vector3.ONE*scale_value),point)
				var seated = Contacts.seat_tree(field,original,footprint)
				var buried = true
				for local in footprint:
					var p = seated*local
					buried = buried and p.y<=float(field.sample(p.x,p.z).height)-Contacts.ROOT_CLEARANCE_M+.0001
				check(buried,"Entire near/mid root edge buried: %s, %d degrees, %.2f scale" % [record.id,degrees,size])
				check(seated.basis==original.basis and seated.origin.x==point.x and seated.origin.z==point.z,"Tree stays upright at its obstacle x/z")
				maximum_burial = maxf(maximum_burial,point.y-seated.origin.y)
		var anchor = Vector3(1.2,field.sample(1.2,2.3).height,2.3)
		var arrays = Contacts.contact_arrays(field,anchor,Vector2(1.2,1.0),.4,.22,1.7)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var rim_buried = true
		for i in range(vertices.size()-Contacts.ANGLES,vertices.size()):
			var p = vertices[i]; rim_buried = rim_buried and p.y<float(field.sample(p.x,p.z).height)-.03
		check(rim_buried,"Snow edge sinks into slope at %d degrees" % degrees)
		var good_normals = true
		for n in normals: good_normals = good_normals and n.is_finite() and n.y>0 and absf(n.length()-1)<.0001
		check(good_normals,"Finite upward smooth snow normals")
		check(arrays[Mesh.ARRAY_INDEX].size()/3==264,"Bounded 264 triangles per contact")
		check(field.heights==original_heights and field.obstacles.is_empty(),"Presentation preserves terrain and physical obstacles")
		contacts.add_contact(field,anchor,Vector2(.3,.3),0,.32)
	check(maximum_burial<1.2,"Slope burial stays below 1.2 m for all production trees/scales")
	var count_before = contacts.contact_count
	contacts.add_contact(field,Vector3.ZERO,Vector2.ONE,0,0)
	check(contacts.contact_count==count_before,"Bare ground gets no snow mound")
	var mat = StandardMaterial3D.new()
	contacts.finish(mat,Quality.preset(2))
	check(contacts.contact_count==3 and contacts.patches.size()==1,"Snow contacts share a spatial draw batch")
	for level in 3:
		contacts.apply_quality(Quality.preset(level))
		check(contacts.patches[0].visibility_range_end==[65.0,90.0,115.0][level],"Quality controls contact snow distance")
	contacts.free()
	# Exercise actual scenery assembly, including branch anchors and all LODs.
	var snow_field = SnowField.new()
	snow_field.X_MIN = -16; snow_field.Z_MIN = -16; snow_field.NX = 9; snow_field.NZ = 9
	snow_field.heights = field.heights.duplicate()
	for tree in [true,false]:
		var x = 2.0 if tree else 7.0
		snow_field.add_obstacle({"tree":tree,"position":Vector3(x,snow_field.sample(x,3).height,3),"yaw":.8,"scale":1.2,"radius":.48 if tree else 1.6,"height":12.6 if tree else 2.4})
	var obstacles_before = snow_field.obstacles.duplicate(true)
	var heights_before = snow_field.heights.duplicate()
	var scenery = preload("res://scripts/world/alpine_scenery.gd").new()
	var terrain_material = library.terrain_material()
	scenery.build(snow_field,library,Quality.preset(2),terrain_material)
	check(snow_field.obstacles==obstacles_before and snow_field.heights==heights_before,"Scenery build preserves the full physical surface and obstacle records")
	check(scenery.contact_snow.contact_count==2,"Mountain build adds snow at both tree and rock contacts")
	var anchor: Transform3D = scenery.tree_motion.trees[0].transform
	check(anchor.origin.y<obstacles_before[0].position.y,"Mountain build applies slope seating before branch registration")
	var aligned = true; var lods = 0
	for batch in scenery.batches:
		if batch.get_meta("forest_tree",false):
			# Dummy renderer returns identity for MultiMesh readback. Its CPU
			# culling bounds can be checked here; GPU transforms are checked when
			# this same suite runs with the native renderer.
			if DisplayServer.get_name()=="headless":
				var expected_bounds: AABB=anchor*library.tree_render_bounds(batch.multimesh.mesh.get_meta("forest_asset"))
				aligned = aligned and batch.custom_aabb.is_equal_approx(expected_bounds)
			else: aligned = aligned and batch.multimesh.get_instance_transform(0).is_equal_approx(anchor)
			lods += 1
	check(aligned and lods==4,"Near/mid/far/shadow bounds follow branch anchor" if DisplayServer.get_name()=="headless" else "Native near/mid/far/shadow transforms match branch anchor")
	var snow_material: ShaderMaterial = scenery.contact_snow.patches[0].mesh.surface_get_material(0)
	terrain_material.set_shader_parameter("powder_patch_enabled",true)
	check(not snow_material.get_shader_parameter("powder_patch_enabled"),"Local track replacement does not discard raised contact snow")
	check(snow_material.get_shader_parameter("snow_albedo")==terrain_material.get_shader_parameter("snow_albedo"),"Contact snow shares the terrain texture")
	scenery.free()
	var result = {"checks":checks,"failures":failures,"maximum_burial_m":maximum_burial,"native_transform_readback":DisplayServer.get_name()!="headless"}
	DirAccess.make_dir_recursive_absolute("res://artifacts/trees_v2/grounding")
	FileAccess.open("res://artifacts/trees_v2/grounding/"+("contracts.json" if DisplayServer.get_name()=="headless" else "contracts_native.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("TREE_GROUNDING_RESULTS ",JSON.stringify(result)); quit(0 if failures.is_empty() else 1)

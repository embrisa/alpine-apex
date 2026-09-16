extends SceneTree
const Placement=preload("res://scripts/presentation/grass_placement.gd")
const Grass=preload("res://scripts/presentation/terrain_grass.gd")
const Motion=preload("res://scripts/presentation/grass_motion.gd")
const Quality=preload("res://scripts/presentation/graphics_quality.gd")
var checks=0
var failures: Array=[]
class Habitat extends "res://scripts/world/heightfield_surface.gd":
	const MASK_ORIGIN=Vector2(-128,-128)
	var exposure_image: Image
	var job=preload("res://scripts/world/generation_job.gd").new()
	var forest=0.0
	var depth=.22
	var powder=0.0
	var rock=.5
	func _init() -> void:
		NX=65; NZ=65; X_MIN=-128; Z_MIN=-128
		heights.resize(NX*NZ)
	func stand_density(_x: float,_z: float) -> float: return forest
	func snow_depth_at(_x: float,_z: float) -> float: return depth
	func powder_region(_x: float,_z: float) -> float: return powder
	func rock_fraction_at(_x: float,_z: float) -> float: return rock
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label)
	print("PASS: " if ok else "FAIL: ",label)
func run() -> void:
	var field=Habitat.new()
	var physical=field.heights.to_byte_array()
	var before_rng=field.noise.seed
	var p=Placement.new(field)
	var sparse: Array=[]
	for z in range(-3,3):
		for x in range(-3,3): sparse.append_array(p.cell(Vector2i(x,z)))
	check(not sparse.is_empty(),"Transition habitat contains grass")
	check(p.cell(Vector2i(1,1))==p.cell(Vector2i(1,1)),"Cell request order does not reshuffle grass")
	field.forest=1
	var dense: Array=[]
	for z in range(-3,3):
		for x in range(-3,3): dense.append_array(p.cell(Vector2i(x,z)))
	check(dense.size()>sparse.size()*2,"Forests contain denser irregular patches")
	check(dense.size()<36*Placement.CANDIDATES/2,"Patch omissions preserve substantial bare ground")
	field.rock=1
	var green=p.cell(Vector2i(1,1))
	check(not green.is_empty() and green[0].asset.ends_with("green") and green[0].burial==0,"Bare rock is green and ignores raw mantle depth")
	field.rock=0
	var snowy=p.cell(Vector2i(1,1))
	check(not snowy.is_empty() and snowy[0].asset.ends_with("snow") and snowy[0].burial>0,"Snow cover coats and buries tall blades")
	field.depth=.6
	check(p.cell(Vector2i(1,1)).is_empty(),"Deep snow suppresses grass")
	field.depth=.22; field.powder=1
	check(p.cell(Vector2i(1,1)).is_empty(),"Deep powder regions remain clear")
	field.powder=0; field.rock=.5
	field.exposure_image=Image.create(field.NX,field.NZ,false,Image.FORMAT_RGBA8)
	field.exposure_image.fill(Color(0,1,0,1))
	check(p.cell(Vector2i(1,1)).is_empty(),"Glacier exposure remains clear even in otherwise suitable habitat")
	field.exposure_image=null
	for i in field.heights.size(): field.heights[i]=float(i%field.NX)*8.0
	check(p.cell(Vector2i(1,1)).is_empty(),"Steep 4 m terrain triangles do not grow grass")
	field.heights.fill(0)
	var finite=true; var seated=true
	for item in dense:
		finite=finite and item.pose.origin.is_finite() and item.pose.basis.is_finite()
		seated=seated and is_equal_approx(item.pose.origin.y+item.burial+.012,item.support)
	check(finite and seated,"Finite transforms seat roots using exact support and burial")
	check(field.heights.to_byte_array()==physical and field.noise.seed==before_rng and field.obstacles.is_empty(),"Grass leaves physical terrain, obstacles and generator RNG unchanged")
	var motion=Motion.new()
	motion.update(Vector3(-8,0,0),Vector3.RIGHT*48,.016,true)
	motion.update(Vector3(8,0,0),Vector3.RIGHT*48,.016,true)
	check(motion.influence_at(Vector3(0,0,.2))>.7,"Fast swept travel bends grass between endpoints")
	check(motion.influence_at(Vector3(0,-3,.2))==0,"Airborne skier does not flatten distant ground below")
	var held=motion.ends.duplicate()
	motion.update(Vector3(8,0,0),Vector3.ZERO,1,false)
	check(held==motion.ends,"Pause holds recovery")
	for i in 15: motion.update(Vector3(8,0,0),Vector3.ZERO,.1,true)
	check(motion.influence_at(Vector3(0,0,.2))==0,"Grass recovers after passage")
	motion.update(Vector3(9,0,0),Vector3.RIGHT,.016,true)
	motion.update(Vector3(100,0,0),Vector3.RIGHT,.016,true)
	check(motion.influence_at(Vector3(8.5,0,.2))==0,"Teleport clears the old path")
	motion.reset()
	check(not motion.initialized and motion.ends==PackedVector4Array([Vector4.ZERO,Vector4.ZERO,Vector4.ZERO,Vector4.ZERO,Vector4.ZERO,Vector4.ZERO,Vector4.ZERO,Vector4.ZERO,Vector4.ZERO,Vector4.ZERO,Vector4.ZERO,Vector4.ZERO,Vector4.ZERO,Vector4.ZERO,Vector4.ZERO,Vector4.ZERO]),"Retry reset clears every influence slot")
	var assets=preload("res://scripts/presentation/alpine_assets.gd").new(preload("res://scripts/presentation/cloud_lighting.gd").new(),Quality.preset(2))
	var grass=Grass.new(); root.add_child(grass); grass.set_process(false)
	grass.build(field,assets,Quality.numbered(7,{"scrub_distance_m":35.0}))
	check_packing(grass,dense)
	grass.stream(Vector3.ZERO,Grass.MAX_CELLS)
	check(grass.population()>0 and grass.cells.size()<=Grass.MAX_CELLS,"Bounded spatial batches contain grass")
	var wind_time=assets.wind_time
	grass._process(.5)
	check(grass.stream_time>=.5 and assets.wind_time==wind_time and grass.materials[0].get_shader_parameter("grass_stream_time")==grass.stream_time,"Residency fades in while wind stays paused")
	var full=grass.population()
	var poses={}
	var bounds_ok=true
	for batches in grass.cells.values():
		for batch in batches:
			for i in batch.multimesh.instance_count:
				var pose=batch.multimesh.get_instance_transform(i)
				poses[str(pose.origin)]=true
				bounds_ok=bounds_ok and batch.multimesh.custom_aabb.encloses((pose*batch.multimesh.mesh.get_aabb()).grow(.60))
	if DisplayServer.get_name()!="headless": check(bounds_ok,"Native batch bounds include wind and bend")
	grass.apply_quality(Quality.numbered(7,{"scrub_distance_m":35.0,"scrub_density":.5}))
	grass.stream(Vector3.ZERO,Grass.MAX_CELLS)
	var subset=true
	for batches in grass.cells.values():
		for batch in batches:
			for i in batch.multimesh.instance_count: subset=subset and poses.has(str(batch.multimesh.get_instance_transform(i).origin))
	check(grass.population()<full,"Lower density reduces resident population")
	if DisplayServer.get_name()!="headless": check(subset,"Native density changes retain a stable subset")
	grass.apply_quality(Quality.numbered(7,{"scrub_distance_m":35.0}))
	grass.stream(Vector3.ZERO,3,true)
	check(grass.work.size()<=3 and not grass.work.is_empty(),"Async cell preparation has at most three isolated jobs")
	var deadline=Time.get_ticks_msec()+5000
	while (not grass.pending.is_empty() or not grass.work.is_empty()) and Time.get_ticks_msec()<deadline:
		await create_timer(.01).timeout
		grass.stream(Vector3.ZERO,3,true)
	check(grass.pending.is_empty() and grass.work.is_empty() and grass.population()==full,"Async preparation reaches the exact synchronous population")
	var conservative=true; var matching=true
	for batches in grass.cells.values():
		for batch in batches:
			var envelope: AABB=batch.multimesh.custom_aabb
			if batch.material_override==grass.materials[0]: conservative=conservative and batch.visibility_range_end>=26.0+envelope.size.length()*.5-.001
			for i in batch.multimesh.instance_count: matching=matching and poses.has(str(batch.multimesh.get_instance_transform(i).origin))
	check(conservative,"Near LOD culling encloses every root through the complete blend range")
	if DisplayServer.get_name()!="headless": check(matching,"Native async transforms equal synchronous vegetation")
	grass.stream(Vector3(160,0,0),3,true)
	grass.apply_quality(Quality.numbered(1,{"scrub_density":0.0}))
	grass.stream(Vector3.ZERO,Grass.MAX_CELLS)
	check(grass.population()==0 and grass.cells.is_empty() and grass.pending.is_empty() and grass.work.is_empty(),"Density zero releases residency and has a real off path")
	grass.apply_quality(Quality.numbered(7,{"scrub_distance_m":35.0}))
	grass.stream(Vector3.ZERO,1)
	field.job.cancel(); grass._process(.016)
	check(grass.cells.is_empty() and grass.pending.is_empty(),"Cancelled generation clears submitted and pending grass cells")
	grass.free()
	check(assets.wind_receivers.is_empty() and assets.lighting.materials.is_empty(),"Teardown unregisters grass materials")
	check_assets()
	DirAccess.make_dir_recursive_absolute("res://artifacts/terrain_grass_20260913")
	var result={"checks":checks,"failures":failures,"sparse":sparse.size(),"forest":dense.size()}
	var suffix="headless" if DisplayServer.get_name()=="headless" else "native"
	preload("res://tests/test_report.gd").write("res://artifacts/terrain_grass_20260913/suite_"+suffix+".json",JSON.stringify(result,"\t"))
	print("TERRAIN_GRASS_RESULTS ",JSON.stringify(result)); quit(0 if failures.is_empty() else 1)
func check_packing(grass, items: Array) -> void:
	# Compare the packed worker result against the former per-instance server path.
	# Native readback catches transform row order and custom-data layout errors.
	for density in [0.0,.5,1.0]:
		var prepared=Placement.pack(items,density,grass.mesh_bounds)
		var groups={}
		for item in items:
			if item.rank>=density: continue
			if not groups.has(item.asset): groups[item.asset]=[]
			groups[item.asset].append(item)
		var matching=prepared.size()==groups.size()
		for group in prepared:
			var members: Array=groups[group.asset]
			for lod in 2:
				var mesh: Mesh=grass.mesh_cache[group.asset+"_lod"+str(lod+1)]
				var reference=MultiMesh.new()
				reference.transform_format=MultiMesh.TRANSFORM_3D; reference.use_custom_data=true
				reference.mesh=mesh; reference.instance_count=members.size()
				var box=AABB()
				for i in members.size():
					var item: Dictionary=members[i]
					reference.set_instance_transform(i,item.pose)
					reference.set_instance_custom_data(i,Color(item.phase,item.height,item.coverage,1))
					var bounds: AABB=item.pose*mesh.get_aabb()
					box=bounds if i==0 else box.merge(bounds)
				matching=matching and group.bounds[lod]==box.grow(.65)
				if DisplayServer.get_name()!="headless": matching=matching and reference.buffer==group.buffer
		check(matching,"Packed transforms/custom data and both LOD bounds match reference at density "+str(density))
func check_assets() -> void:
	var catalog: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(Grass.MANIFEST))
	var dependencies: Array=preload("res://scripts/world/generation_sources.gd").dependencies(true)
	check(catalog.vegetation_only and catalog.assets.size()==18,"Runtime catalog contains only the selected grass exports")
	check(Grass.MANIFEST in dependencies and "res://assets/graphics/grass_motion.gdshaderinc" in dependencies and "res://assets/graphics/mineral_grass.gdshader" in dependencies,"Generation/export receipts include the grass manifest and shared shaders")
	for record in catalog.assets:
		var mesh: Mesh=load(record.path)
		var arrays=mesh.surface_get_arrays(0)
		if "--verify-asset-hashes" in OS.get_cmdline_user_args():
			check(FileAccess.get_sha256(record.path)==record.sha256 and FileAccess.get_sha256(record.source)==record.source_sha256,"Runtime and source provenance: "+record.id)
		check(record.path in dependencies,"Export/source receipt includes runtime mesh: "+record.id)
		check(mesh.get_surface_count()==1 and mesh.surface_get_material(0)==null and ResourceLoader.get_dependencies(record.path).is_empty(),"Independent vegetation mesh has no mineral/material/collision dependencies: "+record.id)
		check(arrays[Mesh.ARRAY_COLOR]!=null and arrays[Mesh.ARRAY_TEX_UV]!=null and arrays[Mesh.ARRAY_TEX_UV2]!=null and mesh.get_aabb().position.y>=-.00001,"Blade color, bend coordinates and rooted base survive conversion: "+record.id)

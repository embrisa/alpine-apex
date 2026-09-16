extends SceneTree
const Placement=preload("res://scripts/presentation/gravel_placement.gd")
const Gravel=preload("res://scripts/presentation/rock_gravel.gd")
const Quality=preload("res://scripts/presentation/graphics_quality.gd")
var checks=0
var failures=[]
class BorderGrass extends RefCounted:
	var root=Vector3(8,0,3.5)
	func cell(_key: Vector2i) -> Array: return [{"pose":Transform3D(Basis.IDENTITY,root)}]
class Habitat extends "res://scripts/world/heightfield_surface.gd":
	var rock=1.0
	var steep=false
	func _init() -> void:
		NX=33; NZ=33; X_MIN=-64; Z_MIN=-64; heights.resize(NX*NZ)
	func rock_fraction_at(_x: float,_z: float) -> float: return rock
	func environment_weight(_x: float,_z: float) -> float: return 0.0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label)
	print("PASS: " if ok else "FAIL: ",label)
func run() -> void:
	var source=JSON.parse_string(FileAccess.get_file_as_string(Gravel.ROOT+"manifest.json"))
	check(source.source_manifest_sha256==FileAccess.get_sha256("res://art_source/rocks/pebbles_v1/manifest.json"),"Final cosmetic source identity")
	for file in source.files: check(FileAccess.get_sha256(file.path)==file.sha256,"Packed bytes "+file.path)
	for tile in source.tiles:
		check(tile.count==(275 if tile.mode=="dense" else 2),"Dense and sparse populations "+tile.id)
		var clear=true; var limits=true; var inside=true
		for i in tile.stones.size():
			var s: Dictionary=tile.stones[i]
			limits=limits and s.width>=.00999 and s.width<=.10001 and s.height-s.burial<=.010001
			inside=inside and s.x-s.radius>=0 and s.z-s.radius>=0 and s.x+s.radius<=.5 and s.z+s.radius<=.5
			for j in i:
				var b: Dictionary=tile.stones[j]
				clear=clear and Vector2(s.x,s.z).distance_to(Vector2(b.x,b.z))>=s.radius+b.radius
		check(clear and inside,"No overlap, stacking or tile-boundary intersections "+tile.id)
		check(limits,"Widths 1–10 cm and exposure <=1 cm "+tile.id)
		for row in tile.models:
			var mesh: Mesh=load(row.path)
			check(mesh.get_surface_count()==1 and mesh.surface_get_material(0)==null,"One material-free mesh "+row.path)
			var a=mesh.surface_get_arrays(0)
			check(a[Mesh.ARRAY_TANGENT].size()==a[Mesh.ARRAY_VERTEX].size()*4 and a[Mesh.ARRAY_TEX_UV2].size()==a[Mesh.ARRAY_VERTEX].size(),"Retained tangents and root seating coordinates "+row.path)
	var field=Habitat.new(); var original=field.heights.to_byte_array(); var rng_seed=field.noise.seed
	var p=Placement.new(field); var all=[]
	for z in range(-2,2):
		for x in range(-2,2): all.append_array(p.cell(Vector2i(x,z)))
	check(all.any(func(i):return i.asset.begins_with("dense")) and all.any(func(i):return i.asset.begins_with("sparse")),"Rock contains dense patches and sparse accents")
	check(p.cell(Vector2i.ZERO)==p.cell(Vector2i.ZERO),"Deterministic cell regeneration")
	field.rock=0
	check(p.cell(Vector2i.ZERO).is_empty(),"Snow excludes all gravel")
	field.rock=.55
	check(p.cell(Vector2i.ZERO).is_empty(),"Mixed snow/rock transition excludes gravel")
	field.rock=1
	for i in field.heights.size(): field.heights[i]=float(i%field.NX)*4
	check(p.cell(Vector2i.ZERO).is_empty(),"Implausible steep terrain excludes gravel")
	field.heights.fill(0)
	var border=Placement.new(field); border.grass_source=BorderGrass.new()
	border.cell(Vector2i.ZERO); var left=border.mask.duplicate()
	border.cell(Vector2i(1,0)); var right=border.mask
	var agrees=true
	for y in 18:
		agrees=agrees and left.get_pixel(17,y)==right.get_pixel(1,y) and left.get_pixel(16,y)==right.get_pixel(0,y)
	check(agrees and left.get_pixel(16,7).r==0,"Neighbor masks agree across the publication boundary and exclude grass")
	border.grass_source.root=Vector3(9.65,0,3.75)
	border.cell(Vector2i.ZERO); left=border.mask.duplicate()
	border.cell(Vector2i(1,0)); right=border.mask
	check(left.get_pixel(17,8)==right.get_pixel(1,8) and left.get_pixel(17,8).r<1,"Halo includes grass roots beyond the core cell exclusion margin")
	var actual=preload("res://scripts/diagnostics/test_map.gd").create("perf-gravel")
	var actual_before=var_to_bytes([actual.heights,actual.obstacles,actual.geology.placements,actual.geology.collision.entries])
	var physical_rocks=preload("res://scripts/diagnostics/test_map.gd").create("perf-rocks")
	check(actual.heights==physical_rocks.heights and actual.geology.placements==physical_rocks.geology.placements,"Gravel map retains exact rock-map terrain and mineral collision placements")
	var actual_placement=Placement.new(actual); var actual_items=actual_placement.cell(Vector2i(0,8))
	check(not actual_items.is_empty(),"Actual exposed-rock fixture has gravel")
	actual.build_material_map()
	check(actual.material_image.get_pixel(32,16).r==actual.rock_fraction_at(0,0) and actual.material_image.get_pixel(30,16).r==0,"Actual material texture matches rock and snow support")
	check(actual_placement.mask.get_format()==Image.FORMAT_R8 and actual_placement.mask.get_size()==Vector2i(18,18),"Filtered grass exclusions use a bounded 0.5 m mask")
	var assets=preload("res://scripts/presentation/alpine_assets.gd").new(preload("res://scripts/presentation/cloud_lighting.gd").new(),Quality.preset(2))
	var gravel=Gravel.new(); root.add_child(gravel); gravel.set_process(false)
	var texture=ImageTexture.create_from_image(Image.create_from_data(field.NX,field.NZ,false,Image.FORMAT_RF,field.heights.to_byte_array()))
	gravel.build(field,assets,Quality.preset(2),texture)
	gravel.stream(Vector3.ZERO,Gravel.MAX_CELLS)
	var before=gravel.population()
	check(before.dense>0 and before.sparse>0 and before.cells<=Gravel.MAX_CELLS,"Resident batch bounds and both modes")
	check(gravel.find_children("*","CollisionObject3D",true,false).is_empty(),"No collision nodes or proxies")
	gravel.set_mode("off")
	check(gravel.cells.is_empty() and gravel.work.is_empty(),"Off mode retires batches and workers")
	gravel.set_mode("all"); gravel.stream(Vector3.ZERO,2,true)
	check(gravel.work.size()<=2,"At most two private low-priority cell jobs")
	gravel.clear_cells()
	check(gravel.work.is_empty(),"Quality/reset boundary joins all jobs")
	gravel.stream(Vector3.ZERO,Gravel.MAX_CELLS)
	check(gravel.population()==before,"Residency rebuild preserves exact population")
	gravel.set_mode("dense"); gravel.stream(Vector3.ZERO,Gravel.MAX_CELLS)
	check(gravel.population().dense==before.dense and gravel.population().sparse==0,"Dense diagnostic mode isolates only accents")
	gravel.set_mode("sparse"); gravel.stream(Vector3.ZERO,Gravel.MAX_CELLS)
	check(gravel.population().sparse==before.sparse and gravel.population().dense==0,"Sparse diagnostic mode isolates only beds")
	gravel.free()
	check(field.heights.to_byte_array()==original and field.noise.seed==rng_seed and actual_before==var_to_bytes([actual.heights,actual.obstacles,actual.geology.placements,actual.geology.collision.entries]),"Terrain, RNG and collision data remain byte-identical")
	var output="res://artifacts/rock_gravel/suite.json"
	preload("res://tests/test_report.gd").write(output,JSON.stringify({"checks":checks,"failures":failures,"population":before},"\t"))
	print("GRAVEL_SUITE ",checks," checks; ",failures.size()," failures"); quit(0 if failures.is_empty() else 1)

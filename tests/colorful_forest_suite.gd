extends SceneTree
const Placement=preload("res://scripts/presentation/forest_placement.gd")
const Job=preload("res://scripts/world/generation_job.gd")
const Assets=preload("res://scripts/presentation/alpine_assets.gd")
const Quality=preload("res://scripts/presentation/graphics_quality.gd")
var failures=[]
var checks=0
class Field extends "res://scripts/world/heightfield_surface.gd":
	func height_at(x: float,z: float) -> float: return sample(x,z).height
	var tree_data=preload("res://scripts/world/packed_trees.gd").new()
	func _init() -> void:
		X_MIN=-256; Z_MIN=-256; NX=129; NZ=129; heights.resize(NX*NZ)
		for z in NZ:
			for x in NX: heights[z*NX+x]=-(Z_MIN+z*4.0)*.18
		for z in range(-240,241,16):
			for x in range(-240,241,16):
				var id=tree_data.size()
				tree_data.append(Vector3(x,height_at(x,z),z),.31,10.5,1.0,id*.13,id,id%3==0)
		tree_data.build_index()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label); printerr("FAIL ",label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var library=Assets.new(preload("res://scripts/presentation/cloud_lighting.gd").new(),Quality.numbered(7))
	var metadata=Placement.metadata(library)
	check(metadata.size()==30,"All catalog assets enter packed metadata")
	var rows=[]
	for seed_value in [849205174,638201943]:
		var field=Field.new(); field.seed_value=seed_value
		var physical=var_to_bytes([field.heights,field.tree_data.positions,field.tree_data.dimensions,field.tree_data.yaws,field.tree_data.candidate_ids,field.tree_data.ecology])
		var a=Placement.new(); var job=Job.new(); job.worker_count=3; a.build(field,metadata,job)
		var b=Placement.new(); job=Job.new(); job.worker_count=1; b.build(field,metadata,job)
		check(a.assets==b.assets and a.asset_indices==b.asset_indices and a.poses==b.poses,"Assignment and seating independent of worker count")
		check(var_to_bytes([field.heights,field.tree_data.positions,field.tree_data.dimensions,field.tree_data.yaws,field.tree_data.candidate_ids,field.tree_data.ecology])==physical,"Physical trees and 4 m terrain stay byte-identical")
		check(a.asset_indices.size()==field.tree_data.size(),"Exactly one visual per physical candidate")
		check(a.family_counts.get("golden",0)>0 and a.family_counts.get("maple",0)>0,"Both warm families participate on each seed")
		var selected_assets={}; var mixed_stands=0
		for index in a.asset_indices: selected_assets[a.assets[index]]=true
		for family in ["golden","maple"]:
			for variant in range(1,4): check(selected_assets.has("forest_%s_%02d" % [family,variant]),"All prepared silhouettes occur on each seed")
		for region in a.regions.values():
			var families={}
			for asset in region:
				var family=asset.get_slice("_",1)
				families[family]=int(families.get(family,0))+1
			if families.values().any(func(count): return count>1): mixed_stands+=1
		check(mixed_stands>0,"Neighboring members of a stand vary in silhouette")
		var evergreen=a.family_counts.get("spruce",0)+a.family_counts.get("fir",0)+a.family_counts.get("pine",0)
		check(evergreen>field.tree_data.size()*.5,"Evergreen backbone retained")
		var seated=true; var near_count=0; var far_count=0
		for i in field.tree_data.size():
			var pose=a.pose_at(i); var p: Vector3=field.tree_data.positions[i]
			seated=seated and pose.origin.x==p.x and pose.origin.z==p.z and pose.origin.y<=p.y
		for region in a.regions.values():
			for group in region.values(): near_count+=group.prepared.buffer.size()/12
		for group in a.far_groups.values(): far_count+=group.prepared.buffer.size()/12
		check(seated and near_count==field.tree_data.size() and far_count==near_count,"Seated near and far partitions retain all candidates")
		var restored=bytes_to_var(var_to_bytes([a.assets,a.asset_indices,a.poses,a.positions,a.family_counts]))
		check(restored==[a.assets,a.asset_indices,a.poses,a.positions,a.family_counts],"Packed cache values roundtrip without reshuffling")
		rows.append({"seed":seed_value,"trees":field.tree_data.size(),"families":a.family_counts})
	var camera=Camera3D.new(); root.add_child(camera)
	for family in ["golden","maple"]:
		for variant in range(1,4):
			var id="forest_%s_%02d" % [family,variant]
			var near: ShaderMaterial=library.mesh(id+"_lod0").surface_get_material(0)
			var far: ShaderMaterial=library.mesh(id+"_lod2").surface_get_material(0)
			check(near in library.wind_receivers and near in library.sight_receivers and far in library.sight_receivers,"New material receives wind and canopy sight state")
			check(near==library.mesh(id+"_lod1").surface_get_material(0),"Detail levels share the broadleaf material")
			check(far.get_shader_parameter("authored_canopy")==true,"Far visibility uses an authored canopy mask")
			var shadow=library.tree_shadow(id)
			check(shadow.get_faces().size()/3<2000,"Bounded dedicated broadleaf shadow proxy")
			for level in 3:
				library.apply_quality(Quality.preset(level))
				for strength in [0.0,50.0,100.0]:
					library.update_foliage_sight(camera,Vector3.ZERO,.1,true,60,strength)
					check(far.get_shader_parameter("foliage_sight_parameters")==near.get_shader_parameter("foliage_sight_parameters"),"Quality and strength propagate to geometry and cards")
				for parameter in ["foliage_texture","foliage_normal_ao","leaf_roughness"]:
					var texture: Texture2D=near.get_shader_parameter(parameter)
					check(texture!=null and texture.get_width()==[256,512,1024][level] and texture.get_image().has_mipmaps(),"Leaf surface maps retain every quality tier")
				for parameter in ["albedo_texture","canopy_texture"]:
					var texture: Texture2D=far.get_shader_parameter(parameter)
					check(texture!=null and texture.get_width()==[1024,2048,4096][level] and texture.get_image().has_mipmaps(),"Eight-view atlas and canopy mips exist")
	var motion=preload("res://scripts/presentation/tree_motion.gd").new(library,"res://assets/graphics/trees/branches.json")
	motion.anchors.fill(Vector4(1,2,3,1)); motion._upload()
	check(library.named_materials.FC_Broadleaf.get_shader_parameter("contact_anchors")==motion.anchors,"Cosmetic branch contact reaches broadleaf receiver")
	check(preload("res://scripts/world/generation_sources.gd").dependencies(true).has("res://assets/graphics/trees/models/forest_maple_01_lod0.res"),"New resources participate in scenery identity")
	check(not preload("res://scripts/world/generation_sources.gd").dependencies(false).has("res://assets/graphics/trees/models/forest_maple_01_lod0.res"),"New artwork stays outside physical identity")
	var result={"checks":checks,"failures":failures,"seed_samples":rows}
	DirAccess.make_dir_recursive_absolute("res://artifacts/colorful_forest_variety")
	FileAccess.open("res://artifacts/colorful_forest_variety/suite.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("COLORFUL_FOREST_RESULTS ",JSON.stringify(result)); camera.free(); quit(0 if failures.is_empty() else 1)

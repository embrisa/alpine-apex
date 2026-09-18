extends "res://art_source/trees/meshy_snow_v1/bough_library.gd"
## Complete reversible candidate; original placement, contacts and shadows.
const FAMILY_PREP="res://artifacts/meshy_snow_20260918/winter_family"
func setup(world):
	assets=world.assets;scenery=world.scenery;forest=scenery.density_forest
	var tier:String=["low","balanced","high"][assets.quality.texture_tier]
	for species in ["spruce","spruce_open","fir","stone_pine"]:
		var lods=[]
		for lod in 2:
			var mesh:Mesh=load(FAMILY_PREP+"/"+species+"_"+str(lod)+".res")
			var mat=ShaderMaterial.new();mat.shader=load(FAMILY_PREP+"/tree_"+str(lod)+".gdshader")
			mat.resource_name="FC_Winter_"+species+"_"+str(lod);mat.render_priority=-20 if lod==0 else -10
			mat.set_shader_parameter("mesh_albedo",load(FAMILY_PREP+"/bough_albedo_"+tier+".res"))
			mat.set_shader_parameter("bark_texture",assets.texture("bark","albedo"))
			mat.set_shader_parameter("bark_normal",assets.texture("bark","normal"))
			register(mat,true)
			lods.append({"mesh":mesh,"mat":mat})
		var far=ShaderMaterial.new();far.shader=load("res://assets/graphics/pc_tree_impostor.gdshader");far.render_priority=-5
		far.resource_name="FC_Impostor_Winter_"+species
		far.set_shader_parameter("albedo_texture",load(FAMILY_PREP+"/"+species+"_atlas_"+tier+".res"))
		far.set_shader_parameter("card_crop",.64);far.set_shader_parameter("pc_detail_residency",forest.residency_texture)
		register(far,false);source[species]={"lods":lods,"far":far}
	for id in assets.tree_ids():
		var record:Dictionary=assets.tree_record(id)
		if not SPECIES.has(record.family) or record.family=="birch":continue
		var species:String=SPECIES[record.family]
		var bare=record.family in ["golden","maple"]
		if bare:species="forest_birch_%02d"%clampi(int(id.get_slice("_",2))+1,1,4)
		if species=="spruce" and int(id.get_slice("_",2))%2==0:species="spruce_open"
		var box=assets.mesh(id+"_lod0").get_aabb()
		var srcbox:AABB=assets.mesh(species+"_lod0").get_aabb() if bare else source[species].lods[0].mesh.get_aabb()
		var scale_m=Vector3(box.size.x/srcbox.size.x,box.size.y/(srcbox.size.y if bare else 12.0),box.size.z/srcbox.size.z)
		for lod in 3:
			var key=id+"_lod"+str(lod);original[key]=assets.mesh(key)
			var mesh:Mesh=bare_tree(species,lod,scale_m,box.position.y-srcbox.position.y*scale_m.y) if bare else (detail(id,record,species,lod,scale_m,box.position.y) if lod<2 else card(species,scale_m,box.position.y))
			mesh.set_meta("forest_asset",id);replacement[key]=mesh
			inventory.append({"asset":id,"species":species,"lod":lod,"original_triangles":original[key].surface_get_array_index_len(0)/3,"candidate_triangles":mesh.surface_get_array_index_len(0)/3,"original_vertices":original[key].surface_get_array_len(0),"candidate_vertices":mesh.surface_get_array_len(0)})
	scenery.tree_motion._upload()
func bare_tree(species:String,lod:int,scale_m:Vector3,bottom:float)->Mesh:
	var template:Mesh=assets.mesh(species+"_lod"+str(lod));var a:Array=template.surface_get_arrays(0).duplicate(true)
	var v:PackedVector3Array=a[Mesh.ARRAY_VERTEX];var n:PackedVector3Array=a[Mesh.ARRAY_NORMAL]
	var t:PackedFloat32Array=a[Mesh.ARRAY_TANGENT] if a[Mesh.ARRAY_TANGENT]!=null else PackedFloat32Array()
	var tags:PackedVector2Array=a[Mesh.ARRAY_TEX_UV2] if a[Mesh.ARRAY_TEX_UV2]!=null else PackedVector2Array()
	for i in v.size():
		if lod==2:v[i]=Vector3(v[i].x*maxf(scale_m.x,scale_m.z),v[i].y*scale_m.y+bottom,v[i].z)
		else:
			v[i]=v[i]*scale_m+Vector3(0,bottom,0);n[i]=(n[i]/scale_m).normalized()
			if not t.is_empty():
				var tangent=(Vector3(t[i*4],t[i*4+1],t[i*4+2])*scale_m).normalized()
				t[i*4]=tangent.x;t[i*4+1]=tangent.y;t[i*4+2]=tangent.z
			if not tags.is_empty():tags[i].y=tags[i].y*scale_m.y+bottom/32.0
	a[Mesh.ARRAY_VERTEX]=v;a[Mesh.ARRAY_NORMAL]=n;a[Mesh.ARRAY_TANGENT]=t;a[Mesh.ARRAY_TEX_UV2]=tags
	var mesh=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,a);mesh.surface_set_material(0,template.surface_get_material(0));return mesh
func register(mat:ShaderMaterial,detail_material:bool):
	assets.named_materials[mat.resource_name]=mat
	assets.sight_receivers.append(mat);mat.set_shader_parameter("foliage_sight_parameters",assets.foliage_sight.parameters)
	assets.lighting.register(mat)
	if detail_material:
		assets.wind_receivers.append(mat);scenery.tree_motion.material_ids.append(mat.resource_name)
		if assets.last_wind_direction.is_finite():
			mat.set_shader_parameter("wind_time",assets.last_wind_time)
			mat.set_shader_parameter("wind_direction",assets.last_wind_direction)
			mat.set_shader_parameter("wind_strength",assets.last_wind_strength)
func validate_batches()->int:
	var checked=0
	for node in scenery.batches:
		if not is_instance_valid(node) or not node.has_meta("art_lod"):continue
		var lod=int(node.get_meta("art_lod"));var id=str(node.multimesh.mesh.get_meta("forest_asset",""))
		if lod>2 or not replacement.has(id+"_lod"+str(lod)):continue
		assert(node.get_meta("pc_tree",false) and node.get_meta("forest_tree",false),"Seasonal forest classification")
		assert(node.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,"Original separate shadows only")
		var ranges:Vector4=node.get_instance_shader_parameter("pc_lod_ranges")
		if assets.quality.level==2 and assets.quality.tree_near_m==95 and assets.quality.tree_mid_m==280:
			assert(is_equal_approx(ranges.x,[0.0,12.0,64.0][lod]))
			if lod<2:assert(is_equal_approx(ranges.y,[12.0,64.0][lod]))
		checked+=1
	return checked

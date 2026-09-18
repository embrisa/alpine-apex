extends RefCounted
## Presentation-only catalogue substitution; physical trees and proxies stay original.
const ROOT="res://assets/graphics/trees/winter"
var assets
var scenery
var forest
var wilderness
var original={}
var replacement={}
var active=false

func setup(world)->void:
	assets=world.assets;scenery=world.scenery
	forest=scenery.density_forest if scenery else null
	wilderness=world.wilderness

func _prepare()->void:
	if not replacement.is_empty():return
	var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"/manifest.json"))
	for key in manifest.models:
		var record:Dictionary=manifest.models[key]
		original[key]=assets.mesh(key)
		var mesh:Mesh=load(record.path).duplicate()
		var id:String=record.material
		if id.begins_with("FC_Impostor_birch_"):assets.mesh("forest_"+id.trim_prefix("FC_Impostor_")+"_lod2")
		elif id in ["FC_Tree","FC_Tree_Mid"]:assets.mesh("forest_birch_02_lod0" if id=="FC_Tree" else "forest_birch_02_lod1")
		if not assets.named_materials.has(id):
			assert("Winter_" in id,"Original bare-birch material must be loaded")
			var mat=ShaderMaterial.new();mat.resource_name=id
			var far=id.begins_with("FC_Impostor_Winter_")
			var species=id.trim_prefix("FC_Impostor_Winter_") if far else id.trim_prefix("FC_Winter_").left(-2)
			var lod=2 if far else int(id.right(1))
			mat.shader=load("res://assets/graphics/pc_tree_impostor.gdshader" if far else "res://assets/graphics/pc_winter_tree_%d.gdshader"%lod)
			mat.render_priority=[-20,-10,-5][lod]
			mat.set_meta("winter_texture",species+"_atlas" if far else "bough_albedo")
			if far:
				mat.set_shader_parameter("card_crop",.64)
				if forest:mat.set_shader_parameter("pc_detail_residency",forest.residency_texture)
			else:
				assets.wind_receivers.append(mat)
				if scenery.tree_motion:scenery.tree_motion.material_ids.append(id)
				if assets.last_wind_direction.is_finite():
					mat.set_shader_parameter("wind_time",assets.last_wind_time)
					mat.set_shader_parameter("wind_direction",assets.last_wind_direction)
					mat.set_shader_parameter("wind_strength",assets.last_wind_strength)
			assets.sight_receivers.append(mat)
			mat.set_shader_parameter("foliage_sight_parameters",assets.foliage_sight.parameters)
			assets.lighting.register(mat);assets.named_materials[id]=mat
			assets.set_winter_textures(mat)
		mesh.surface_set_material(0,assets.named_materials[id])
		replacement[key]=mesh
	if scenery.tree_motion:scenery.tree_motion._upload()

func select(winter:bool)->void:
	if winter==active:return
	if winter:_prepare()
	var selected=replacement if winter else original
	var shadow_resources={}
	for node in scenery.batches:
		if is_instance_valid(node) and int(node.get_meta("art_lod",-1))==5:shadow_resources[node.multimesh.get_rid()]=true
	for key in selected:
		assets.meshes[key]=selected[key]
		if forest:forest.prepared_meshes[key.replace("_lod",":")]=selected[key]
	for node in scenery.batches:
		if not is_instance_valid(node) or not node.has_meta("art_lod"):continue
		var lod=int(node.get_meta("art_lod"));var id=str(node.multimesh.mesh.get_meta("forest_asset",""))
		var key=id+"_lod"+str(lod)
		if not selected.has(key):continue
		# Some original bare-tree shadows share a visible MultiMesh.
		if shadow_resources.has(node.multimesh.get_rid()):node.multimesh=node.multimesh.duplicate()
		node.multimesh.mesh=selected[key]
	if forest:
		for region in forest.regions.values():
			for id in region:
				var group:Dictionary=region[id];var prepared=[group.prepared]
				for child in group.detail_groups:prepared.append(child.prepared)
				for p in prepared:
					var updated={}
					for mm in p.multimeshes.values():updated[mm.mesh]=mm
					p.multimeshes=updated
	if wilderness:wilderness.set_forest_appearance(replacement,winter)
	active=winter

extends RefCounted
## Presentation-only catalogue substitution; physical trees and proxies stay original.
const ROOT="res://assets/graphics/trees/seasons"
const STYLES=["autumn","winter","summer"]
var assets
var scenery
var forest
var wilderness
var replacement={}
var active=-1
var catalogues={}
var manifest={}

func setup(world)->void:
	assets=world.assets;scenery=world.scenery
	forest=scenery.density_forest if scenery else null
	wilderness=world.wilderness

func _prepare(style:int)->void:
	if catalogues.has(style):return
	if manifest.is_empty():manifest=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"/manifest.json"))
	# Preserve fallback bare-tree proxies before visible LOD1 slots are replaced.
	for id in assets.tree_ids():assets.tree_shadow(id)
	var catalogue={}
	for key in manifest.styles[STYLES[style]]:
		var record:Dictionary=manifest.styles[STYLES[style]][key]
		var mesh:Mesh=load(record.path).duplicate()
		var id:String=record.material
		if not assets.named_materials.has(id):_material(id,manifest.materials[id])
		mesh.surface_set_material(0,assets.named_materials[id])
		catalogue[key]=mesh
	catalogues[style]=catalogue

func _activate_receivers()->void:
	# Cached inactive seasons must not add per-frame wind/contact publication.
	assets.wind_receivers.assign(assets.wind_receivers.filter(func(mat):return not mat.has_meta("forest_texture")))
	assets.sight_receivers.assign(assets.sight_receivers.filter(func(mat):return not mat.has_meta("forest_texture")))
	if scenery.tree_motion:
		scenery.tree_motion.material_ids.assign(scenery.tree_motion.material_ids.filter(func(id):return not assets.named_materials.has(id) or not assets.named_materials[id].has_meta("forest_texture")))
	var selected={}
	for mesh in replacement.values():selected[mesh.surface_get_material(0)]=true
	for mat in selected:
		assets.sight_receivers.append(mat)
		mat.set_shader_parameter("foliage_sight_parameters",assets.foliage_sight.parameters)
		if int(mat.get_meta("forest_appearance").lod)==2:continue
		assets.wind_receivers.append(mat)
		if assets.last_wind_direction.is_finite():
			mat.set_shader_parameter("wind_time",assets.last_wind_time)
			mat.set_shader_parameter("wind_direction",assets.last_wind_direction)
			mat.set_shader_parameter("wind_strength",assets.last_wind_strength)
		if scenery.tree_motion:scenery.tree_motion.material_ids.append(mat.resource_name)
	if scenery.tree_motion:
		scenery.tree_motion.uploaded_materials.clear()
		scenery.tree_motion._upload()

func _material(id:String,config:Dictionary)->void:
	var mat=ShaderMaterial.new();mat.resource_name=id
	var lod=int(config.lod);var far=lod==2
	mat.shader=load("res://assets/graphics/pc_tree_impostor.gdshader" if far else "res://assets/graphics/pc_%s_tree_%d.gdshader"%["winter" if config.heavy else "season",lod])
	mat.render_priority=[-20,-10,-5][lod]
	mat.set_meta("forest_texture",config.texture_root+config.texture)
	mat.set_meta("forest_texture_parameter","albedo_texture" if far else "mesh_albedo")
	mat.set_meta("forest_appearance",config)
	if far:
		mat.set_shader_parameter("card_crop",config.card_crop)
		if config.has("canopy"):
			mat.set_meta("forest_canopy_texture",config.texture_root+config.canopy)
			mat.set_shader_parameter("authored_canopy",true)
		if forest:mat.set_shader_parameter("pc_detail_residency",forest.residency_texture)
	else:
		if not config.heavy:
			if config.has("normal"):
				mat.set_meta("forest_normal_texture",config.texture_root+config.normal)
				mat.set_shader_parameter("has_mesh_normal",true)
			for parameter in ["source_textured","autumn_amount","snow_dusting","continuous_crown"]:mat.set_shader_parameter(parameter,config[parameter])
			mat.set_shader_parameter("autumn_color",Color(config.autumn_color[0],config.autumn_color[1],config.autumn_color[2]))
			var centers=PackedVector3Array()
			for branch in config.branches:centers.append(Vector3(branch.center[0],branch.center[1],branch.center[2]))
			assert(centers.size()==12);mat.set_shader_parameter("branch_centers",centers)
		assets.wind_receivers.append(mat)
		if scenery.tree_motion:scenery.tree_motion.material_ids.append(id)
		if assets.last_wind_direction.is_finite():
			mat.set_shader_parameter("wind_time",assets.last_wind_time)
			mat.set_shader_parameter("wind_direction",assets.last_wind_direction)
			mat.set_shader_parameter("wind_strength",assets.last_wind_strength)
	assets.sight_receivers.append(mat)
	mat.set_shader_parameter("foliage_sight_parameters",assets.foliage_sight.parameters)
	assets.lighting.register(mat);assets.named_materials[id]=mat
	assets.set_forest_textures(mat)

func select(style:int)->void:
	assert(style>=0 and style<STYLES.size())
	if style==active:return
	_prepare(style)
	replacement=catalogues[style]
	_activate_receivers()
	var selected=replacement
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
	if wilderness:wilderness.set_forest_appearance(replacement,style)
	active=style

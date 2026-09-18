extends SceneTree
var checks=0
func check(value:bool):
	checks+=1;assert(value)
func _initialize():call_deferred("run")
func run():
	var quality=preload("res://scripts/presentation/graphics_quality.gd").preset(2)
	var assets=preload("res://scripts/presentation/alpine_assets.gd").new(preload("res://scripts/presentation/cloud_lighting.gd").new(),quality)
	var scenery=preload("res://scripts/world/alpine_scenery.gd").new();root.add_child(scenery)
	scenery.assets=assets;scenery.quality=quality;scenery.dense_woodlands=true
	scenery.tree_motion=preload("res://scripts/presentation/tree_motion.gd").new(assets,"")
	for lod in [0,1,2,5]:scenery._batch(assets.mesh("forest_spruce_01_lod%d"%lod) if lod<3 else assets.tree_shadow("forest_spruce_01"),[Transform3D.IDENTITY],lod,12.0)
	scenery.configure_batches(quality,scenery.batches)
	var shadow=scenery.batches[3].multimesh.mesh
	var bare_shadow=assets.tree_shadow("forest_birch_01")
	var style=preload("res://scripts/presentation/forest_appearance.gd").new()
	style.setup({"assets":assets,"scenery":scenery,"wilderness":null})
	var prefs=preload("res://scripts/presentation/weather_preferences.gd").new()
	check(prefs.values.forest_style==1)
	var props=preload("res://scripts/world/wilderness_props.gd").new();root.add_child(props)
	var background=MultiMeshInstance3D.new();props.add_child(background)
	background.set_meta("forest_key","forest_spruce_01_lod2");background.set_meta("kind","tree")
	var original_card:Mesh=assets.mesh("forest_spruce_01_lod2").duplicate();var background_material=ShaderMaterial.new()
	background_material.shader=preload("res://assets/graphics/offmap_tree.gdshader")
	original_card.surface_set_material(0,background_material)
	var multi=MultiMesh.new();multi.transform_format=MultiMesh.TRANSFORM_3D;multi.use_custom_data=true;multi.mesh=original_card
	multi.instance_count=1;multi.set_instance_transform(0,Transform3D.IDENTITY);multi.custom_aabb=original_card.get_aabb().grow(4)
	background.multimesh=multi;props.apply_quality(quality)
	var selected={}
	var winter_receivers=[]
	for season in [1,0,2,1]:
		style.select(season)
		check(style.active==season and style.replacement.size()==90)
		check(scenery.batches[3].multimesh.mesh==shadow)
		check(assets.tree_shadow("forest_birch_01")==bare_shadow)
		if season==1:
			if winter_receivers.is_empty():winter_receivers=assets.wind_receivers.duplicate()
			else:check(assets.wind_receivers==winter_receivers)
		for i in 3:
			check(scenery.batches[i].multimesh.mesh==assets.mesh("forest_spruce_01_lod%d"%i))
			check(scenery.batches[i].cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
		for key in style.replacement:
			var mesh:Mesh=style.replacement[key]
			check(mesh.get_surface_count()==1 and mesh.surface_get_material(0)!=null)
			check(mesh.get_meta("forest_asset")==key.get_slice("_lod",0))
			check(mesh.get_aabb().size.is_finite())
			check(mesh.surface_get_material(0).has_meta("forest_texture"))
		var material:ShaderMaterial=assets.mesh("forest_birch_01_lod1").surface_get_material(0)
		check(material.get_shader_parameter("source_textured"))
		check(material.get_shader_parameter("continuous_crown"))
		check(material.get_shader_parameter("contact_active")==false)
		assets.apply_quality(preload("res://scripts/presentation/graphics_quality.gd").preset(0))
		check(material.get_shader_parameter("mesh_albedo").resource_path.ends_with("_low.res"))
		assets.apply_quality(quality)
		check(material.get_shader_parameter("mesh_albedo").resource_path.ends_with("_high.res"))
		props.apply_forest_appearance(style.replacement,season)
		var card_material=multi.mesh.surface_get_material(0)
		var mountain_material=assets.mesh("forest_spruce_01_lod2").surface_get_material(0)
		check(card_material.get_shader_parameter("albedo_texture").resource_path==str(mountain_material.get_meta("forest_texture"))+"_low.res")
		check(card_material.get_shader_parameter("card_crop")==mountain_material.get_shader_parameter("card_crop"))
		if selected.has(season):check(selected[season]==multi.mesh)
		selected[season]=multi.mesh
		prefs.set_value("forest_style",season);check(prefs.values.forest_style==season)
		prefs.set_value("forest_style",99);check(prefs.values.forest_style==season)
	check(assets.wind_receivers.count(assets.mesh("forest_birch_01_lod1").surface_get_material(0))==1)
	props.free();scenery.free()
	print("FOREST_APPEARANCE ",JSON.stringify({"checks":checks,"failures":[]}));quit()

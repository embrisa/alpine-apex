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
	var old=[]
	for node in scenery.batches:old.append(node.multimesh.mesh)
	var style=preload("res://scripts/presentation/forest_appearance.gd").new()
	style.setup({"assets":assets,"scenery":scenery,"wilderness":null});style.select(true)
	check(style.active and style.replacement.size()==54)
	for i in 3:
		check(scenery.batches[i].multimesh.mesh!=old[i])
		check(scenery.batches[i].cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	check(scenery.batches[3].multimesh.mesh==old[3])
	var winter:ShaderMaterial=assets.mesh("forest_spruce_01_lod1").surface_get_material(0)
	check(winter.get_shader_parameter("contact_active")==false)
	check(winter.get_shader_parameter("mesh_albedo").resource_path.ends_with("_high.res"))
	assets.apply_quality(preload("res://scripts/presentation/graphics_quality.gd").preset(0))
	check(winter.get_shader_parameter("mesh_albedo").resource_path.ends_with("_low.res"))
	check(assets.mesh("forest_spruce_01_lod2").surface_get_material(0).get_shader_parameter("albedo_texture").resource_path.ends_with("_low.res"))
	for key in style.replacement:
		var mesh:Mesh=style.replacement[key]
		check(mesh.get_surface_count()==1 and mesh.surface_get_material(0)!=null)
		check(mesh.get_meta("forest_asset")==key.get_slice("_lod",0))
		check(mesh.get_aabb().size.is_finite())
	style.select(false)
	for i in 4:check(scenery.batches[i].multimesh.mesh==old[i])
	style.select(true);style.select(false)
	check(assets.wind_receivers.count(winter)==1)
	var prefs=preload("res://scripts/presentation/weather_preferences.gd").new()
	prefs.set_value("forest_style",0);check(prefs.values.forest_style==0)
	prefs.set_value("forest_style",99);check(prefs.values.forest_style==0)
	var props=preload("res://scripts/world/wilderness_props.gd").new();root.add_child(props)
	var background=MultiMeshInstance3D.new();props.add_child(background)
	background.set_meta("forest_key","forest_spruce_01_lod2");background.set_meta("kind","tree")
	var original_card:Mesh=old[2].duplicate();var background_material=ShaderMaterial.new()
	background_material.shader=preload("res://assets/graphics/offmap_tree.gdshader")
	original_card.surface_set_material(0,background_material)
	var multi=MultiMesh.new();multi.transform_format=MultiMesh.TRANSFORM_3D;multi.use_custom_data=true;multi.mesh=original_card
	multi.instance_count=1;multi.set_instance_transform(0,Transform3D.IDENTITY);multi.custom_aabb=original_card.get_aabb().grow(4)
	background.multimesh=multi;var original_bound=multi.custom_aabb
	props.apply_quality(quality);props.apply_forest_appearance(style.replacement,true)
	check(multi.mesh!=original_card and multi.mesh.surface_get_material(0).get_shader_parameter("albedo_texture").resource_path.contains("winter/textures"))
	var low=preload("res://scripts/presentation/graphics_quality.gd").preset(0)
	props.apply_quality(low);props.apply_forest_appearance(style.replacement,false)
	check(multi.mesh==original_card and multi.custom_aabb==original_bound)
	check(background_material.get_shader_parameter("range_end")==low.offmap_tree_distance_m)
	props.free()
	print("FOREST_APPEARANCE checks=",checks," failures=0")
	scenery.free();quit()

extends SceneTree
## Catalogue trees keep forest LOD/shadow policy with independently named shaders.
func _initialize():call_deferred("run")
func run():
	var quality=preload("res://scripts/presentation/graphics_quality.gd").preset(2)
	var library=preload("res://scripts/presentation/alpine_assets.gd").new(preload("res://scripts/presentation/cloud_lighting.gd").new(),quality)
	var scenery=preload("res://scripts/world/alpine_scenery.gd").new();root.add_child(scenery)
	scenery.assets=library;scenery.quality=quality;scenery.dense_woodlands=true
	var shader=Shader.new();shader.code="shader_type spatial;\n#include \"res://assets/graphics/pc_lod.gdshaderinc\"\nvoid fragment(){ALBEDO=vec3(1.0);}"
	var material=ShaderMaterial.new();material.shader=shader;material.resource_name="IndependentWinterMaterial"
	var mesh=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,BoxMesh.new().get_mesh_arrays())
	mesh.surface_set_material(0,material);mesh.set_meta("forest_asset","forest_spruce_01")
	for lod in [0,1,2,5]:scenery._batch(mesh,[Transform3D.IDENTITY],lod,12.0)
	scenery.configure_batches(quality,scenery.batches)
	var checks=0
	for index in 4:
		var node=scenery.batches[index];var lod=[0,1,2,5][index]
		assert(node.get_meta("pc_tree") and node.get_meta("forest_tree"));checks+=1
		var ranges:Vector4=node.get_instance_shader_parameter("pc_lod_ranges")
		assert(is_equal_approx(ranges.x,[0.0,12.0,64.0,0.0][index]));checks+=1
		assert(is_equal_approx(ranges.y,[12.0,64.0,quality.tree_far_m,32.0][index]));checks+=1
		assert(node.cast_shadow==(GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY if lod==5 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF));checks+=1
		if lod==5:assert(node.material_override==scenery.forest_shadow_material);checks+=1
	print("FOREST_MATERIAL_IDENTITY checks=",checks," failures=0")
	scenery.free();quit()

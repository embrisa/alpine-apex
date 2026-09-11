extends SceneTree
## Explicit exported-resource smoke check; no world, race or preferences writes.
const Assets=preload("res://scripts/presentation/alpine_assets.gd")
const Quality=preload("res://scripts/presentation/graphics_quality.gd")
const Clouds=preload("res://scripts/presentation/cloud_lighting.gd")
const Sources=preload("res://scripts/world/generation_sources.gd")
func _initialize() -> void:
	var failures=[]; var count=0
	var library=Assets.new(Clouds.new(),Quality.preset(2))
	var manifest=JSON.parse_string(FileAccess.get_file_as_string("res://assets/graphics/trees/manifest.json"))
	if not OS.has_feature("generation_export"): failures.append("Requires actual exported executable")
	if Sources.signature(true).is_empty(): failures.append("Export dependency identity rejected")
	if manifest.version!=3 or manifest.assets.size()!=24: failures.append("Wrong collection")
	for row in manifest.assets:
		for lod in 3:
			var mesh=library.mesh(row.id+"_lod%d" % lod)
			if mesh.get_surface_count()!=1 or mesh.get_faces().size()/3!=int(row.models[lod].triangles): failures.append(row.id+" visible mesh")
			count+=1
		if row.family in ["spruce","fir","pine"]:
			if library.tree_shadow(row.id).get_faces().size()/3!=int(row.shadow.triangles): failures.append(row.id+" shadow")
			count+=1
	for level in 3:
		library.apply_quality(Quality.preset(level))
		var mat=library.mesh("forest_spruce_01_lod0").surface_get_material(0)
		for parameter in ["foliage_texture","foliage_normal_ao"]:
			var texture: Texture2D=mat.get_shader_parameter(parameter)
			if texture==null or texture.get_width()!=[512,1024,2048][level]: failures.append("Missing quality texture")
	var result={"exported":OS.has_feature("generation_export"),"meshes":count,"failures":failures,"engine_sha256":Sources.engine_identity()}
	FileAccess.open("user://foliage_export_check.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("FOLIAGE_EXPORT_CHECK ",JSON.stringify(result)); quit(0 if failures.is_empty() else 1)

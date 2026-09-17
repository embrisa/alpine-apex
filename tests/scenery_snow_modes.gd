extends RefCounted
## Material-only comparison on identical current geometry; never alters assets.
var original: Array = []
var frozen: Array = []
var manifest: Dictionary = {}
var materials: Array = []
var enabled: Array = []
var mode = "cheap"

func setup(game, path: String) -> void:
	manifest = JSON.parse_string(FileAccess.get_file_as_string(path+"/manifest.json"))
	materials = [game.world.wilderness.material,game.world.backdrop.material]
	for name in ["alpine_wilderness","alpine_apron"]:
		var source = FileAccess.get_file_as_string(path+"/"+name+".txt")
		assert(not source.is_empty(),"Missing frozen material source")
		var shader = Shader.new(); shader.code = source; frozen.append(shader)
	for material in materials:
		original.append(material.shader)
		enabled.append(material.get_shader_parameter("offmap_snow_detail"))

func select(value: String) -> void:
	assert(value in ["baseline","cheap","enhanced"])
	mode = value
	for i in materials.size():
		materials[i].shader = frozen[i] if mode=="baseline" else original[i]
		if mode!="baseline": materials[i].set_shader_parameter("offmap_snow_detail",mode=="enhanced")

func report() -> Dictionary:
	var bound = []
	for i in materials.size():
		bound.append({"expected_shader_bound":materials[i].shader==(frozen[i] if mode=="baseline" else original[i]),
			"deposits":materials[i].get_shader_parameter("offmap_snow_detail") if mode!="baseline" else false})
	return {"snow_mode":mode,"material_bindings":bound,"baseline_commit":manifest.commit}

func restore() -> void:
	for i in materials.size():
		materials[i].shader = original[i]
		materials[i].set_shader_parameter("offmap_snow_detail",enabled[i])

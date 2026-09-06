extends RefCounted
## Independent live controls over separate exported material surfaces.
const DEFAULTS = {
 "Clothing":{"tint":Color.WHITE,"roughness":.78,"metallic":0.0},
 "Helmet":{"tint":Color.WHITE,"roughness":.38,"metallic":.08},
 "Lens":{"tint":Color.WHITE,"roughness":.12,"metallic":.80}}
var values: Dictionary = DEFAULTS.duplicate(true)
var materials: Dictionary = {}
const FILE = "user://skier_appearance.cfg"

func bind(assets) -> void:
	for id in DEFAULTS:
		materials[id] = assets.named_materials.get("SkierV7"+id)
		apply(id)

func apply(id: String) -> void:
	var mat: ShaderMaterial = materials.get(id)
	if not mat: return
	mat.set_shader_parameter("base_color",values[id].tint)
	mat.set_shader_parameter("surface_roughness",values[id].roughness)
	mat.set_shader_parameter("surface_metallic",values[id].metallic)
	mat.set_shader_parameter("has_roughness",false)
	mat.set_shader_parameter("has_metallic",false)

func change(id: String, property: String, value, persist: bool = true) -> void:
	if not DEFAULTS.has(id) or not DEFAULTS[id].has(property): return
	values[id][property] = value if property=="tint" else clampf(float(value),.04 if property=="roughness" else 0.0,1.0)
	apply(id)
	if persist: save_preferences()

func load_preferences() -> void:
	var file = ConfigFile.new()
	if file.load(FILE)!=OK: return
	for id in DEFAULTS:
		for property in DEFAULTS[id]:
			var value = file.get_value(id,property,DEFAULTS[id][property])
			if typeof(value)==typeof(DEFAULTS[id][property]): change(id,property,value,false)

func save_preferences() -> void:
	var file = ConfigFile.new()
	for id in values:
		for property in values[id]: file.set_value(id,property,values[id][property])
	file.save(FILE)

func reset(persist: bool = true) -> void:
	values = DEFAULTS.duplicate(true)
	for id in DEFAULTS: apply(id)
	if persist: save_preferences()

extends Node3D
## Static culled ridges and packed background props. No physics or GI contribution.
const Data = preload("res://scripts/world/wilderness_data.gd")
const Placement = preload("res://scripts/world/wilderness_instances.gd")
const Props = preload("res://scripts/world/wilderness_props.gd")
const Fog = preload("res://scripts/world/wilderness_atmosphere.gd")
const FAR_M = 32000.0
const TRIANGLE_LIMITS = [20000,40000,80000]
var data = Data.new()
var material = ShaderMaterial.new()
var triangles: int = 0
var build_ms: float = 0.0
var level: int = -1
var enabled: bool = true
var apron_material: ShaderMaterial
var apron_triangles: int = 0
var apron_build_ms: float = 0.0
var apron_sources: Array = []
var terrain_root: Node3D
var props
var placement
var worker = Callable()
var job
var last_weather
var weather_values: Array = []
var build_revision = 0
var requested_level = -1
var source_arrays: Array = []

func prepare(field, mountain) -> void:
	name = "AlpineWilderness"
	level = -1
	requested_level = -1
	job = field.job if "job" in field else null
	data.configure(mountain,field)
	material.shader = preload("res://assets/graphics/alpine_wilderness.gdshader")
	enabled = "--wilderness=off" not in OS.get_cmdline_user_args()
	material.set_shader_parameter("offmap_rock",load("res://assets/graphics/textures/rock_albedo_low.jpg"))
	material.set_shader_parameter("offmap_snow",load("res://assets/graphics/textures/snow_albedo_low.jpg"))
	Fog.configure(material,data)
	visible = enabled

func build(field, mountain, profile, checkpoint: Callable = Callable()) -> void:
	prepare(field,mountain)
	await apply_quality(profile,checkpoint)

func apply_quality(profile, checkpoint: Callable = Callable()) -> void:
	if not enabled:
		data.clear_cache()
		return
	if requested_level==profile.level: return
	requested_level = profile.level
	build_revision += 1
	var revision = build_revision
	var begin = Time.get_ticks_usec()
	var staging = Node3D.new()
	staging.name = "RidgeBatches"
	staging.visible = false
	add_child(staging)
	triangles = 0
	source_arrays = apron_sources.duplicate()
	var preset: Dictionary = data.asset.levels[profile.level]
	var detail: float = [0.0,0.12,0.18][profile.level]
	material.set_shader_parameter("offmap_detail",detail)
	if apron_material:
		apron_material.set_shader_parameter("offmap_detail",detail)
		apron_material.set_shader_parameter("offmap_snow",load("res://assets/graphics/textures/snow_albedo_low.jpg"))
		Fog.configure(apron_material,data)
	for arrays in preset.terrain:
		_upload_ridge(arrays,staging)
		if checkpoint.is_valid(): await checkpoint.call("Loading authored alpine ridges…",100.0*staging.get_child_count()/24.0)
		if _cancelled(revision): _abort(staging,revision); return
	var candidate = Placement.new()
	var prepare_props = candidate.build.bind(preset,apron_sources,job)
	if worker.is_valid() and checkpoint.is_valid(): await worker.call(prepare_props)
	else: prepare_props.call()
	if _cancelled(revision) or not candidate.ready:
		_abort(staging,revision); return
	var candidate_props = Props.new()
	staging.add_child(candidate_props)
	await candidate_props.build(candidate,data,profile,checkpoint,job)
	if _cancelled(revision): _abort(staging,revision); return
	if terrain_root:
		remove_child(terrain_root); terrain_root.queue_free()
	terrain_root = staging; props = candidate_props; placement = candidate
	level = profile.level
	staging.visible = true
	source_arrays.clear()
	data.clear_cache()
	weather_values.clear()
	if last_weather: update_weather(last_weather)
	build_ms = (Time.get_ticks_usec()-begin)/1000.0

func _cancelled(revision: int) -> bool:
	return revision!=build_revision or (job and job.is_cancelled())

func _abort(staging: Node3D, revision: int) -> void:
	remove_child(staging); staging.queue_free()
	if revision==build_revision:
		requested_level=level
		triangles=0
		for ridge in ridge_nodes(): triangles+=ridge.mesh.surface_get_array_index_len(0)/3
		source_arrays.clear(); data.clear_cache()

func _exit_tree() -> void:
	build_revision+=1

func ridge_nodes() -> Array:
	return terrain_root.get_children().filter(func(node): return node is MeshInstance3D) if terrain_root else []

func _upload_ridge(arrays: Array, parent: Node3D) -> void:
	var mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var node = MeshInstance3D.new()
	node.name = "Ridge_%d" % parent.get_child_count()
	node.mesh = mesh; node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	parent.add_child(node)
	triangles += arrays[Mesh.ARRAY_INDEX].size()/3

func update_weather(state) -> void:
	last_weather = state
	var values = [state.enabled,state.cloud_coverage,state.fog_color,state.fog_density,state.sun_color,state.sun_energy,state.sun_direction]
	if values==weather_values: return
	weather_values = values
	Fog.apply(material,state)
	if apron_material: Fog.apply(apron_material,state)
	if props:
		for receiver in props.materials: Fog.apply(receiver,state)

func report() -> Dictionary:
	return {"version":Data.VERSION,"seed":data.seed_value,"enabled":visible,"triangles":triangles,
		"batches":ridge_nodes().size(),"build_ms":build_ms,"radius_m":Data.OUTER_RADIUS_M,"quality":level,"apron_triangles":apron_triangles,"apron_build_ms":apron_build_ms,
		"props": {"counts":placement.counts,"fingerprint":placement.fingerprint,"prepare_ms":placement.build_ms,"adapted_instances":placement.adapted_instances,"seating_error_m":placement.seating_error_m,"triangles":props.triangles,"batches":props.get_child_count(),"upload_ms":props.upload_ms,"bounds_valid":props.bounds_valid} if placement else {},
		"asset_id":data.asset.asset_id,"asset_sha256":FileAccess.get_sha256(Data.DEFAULT_ASSET),"asset_read_ms":data.asset_read_ms,"ridge_segments":data.asset.metadata.ridge_segments,"source_sha256":source_hashes()}

static func source_hashes() -> Dictionary:
	var result = {}
	for path in ["scripts/world/wilderness_data.gd","scripts/world/alpine_wilderness.gd","scripts/world/alpine_backdrop.gd","scripts/world/wilderness_instances.gd","scripts/world/wilderness_asset.gd","scripts/world/wilderness_props.gd","scripts/world/wilderness_atmosphere.gd","scripts/presentation/graphics_quality.gd","assets/graphics/offmap_fog.gdshaderinc","assets/graphics/offmap_tree.gdshader","assets/graphics/offmap_prop.gdshader","assets/graphics/alpine_wilderness.gdshader","assets/graphics/alpine_apron.gdshader","assets/graphics/offmap_surface.gdshaderinc","assets/graphics/alpine_surface_fragment.gdshaderinc","assets/cloud_light.gdshaderinc","assets/graphics/trees/manifest.json","assets/graphics/manifest.json"]:
		result[path] = FileAccess.get_sha256("res://"+path)
	for path in ["scripts/world/mountain_data.gd","assets/graphics/textures/rock_albedo_low.jpg","assets/graphics/textures/snow_albedo_low.jpg"]:
		result[path] = FileAccess.get_sha256("res://"+path)
	for id in Placement.TREE_IDS:
		for suffix in ["_shadow","_lod2"]:
			var path = "assets/graphics/trees/models/%s%s.glb" % [id,suffix]
			result[path] = FileAccess.get_sha256("res://"+path)
		var path = "assets/graphics/trees/textures/%s_atlas_low.png" % id
		result[path] = FileAccess.get_sha256("res://"+path)
	for id in Placement.ROCK_IDS:
		var path = "assets/graphics/models/%s.glb" % id
		result[path] = FileAccess.get_sha256("res://"+path)
	return result

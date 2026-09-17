extends Resource
## Presentation budgets only. Never consumed by the simulation or course seed.
@export_enum("Low","Balanced","High") var level: int = 1
@export var texture_suffix: String = ""
@export var surface_texture_suffix: String = ""
@export var tree_near_m: float = 70.0
@export var tree_mid_m: float = 220.0
@export var tree_far_m: float = 1000.0
@export var scrub_distance_m: float = 85.0
@export var scrub_density: float = 1.0
@export var shadow_distance_m: float = 170.0
@export var normal_strength: float = 0.36
@export var contact_shading: bool = true
@export var indirect_lighting: bool = false
@export var terrain_gi: bool = false
@export var volumetric_shafts: bool = false
@export var highlight_glow: bool = true
@export var highlight_glow_intensity: float = .2772
@export var snow_particles: Vector3i = Vector3i(192,128,48)
@export var snow_track_capacity: int = 1600
@export var snow_track_relief: bool = true
@export var snow_sparkle: float = 6.0
@export var snow_crystal_density: float = 1.35
@export var snow_sheen: float = .1008
@export var snow_local_deformation: bool = false
@export var offmap_snow_detail: bool = false
@export var offmap_shadow_quality: int = 0
@export var offmap_prop_density: float = .6
@export var offmap_tree_distance_m: float = 4500.0

const Presets = preload("res://scripts/presentation/graphics_presets.gd")
@export var preset_id: int = 4
@export var texture_tier: int = 1
@export var backdrop_tier: int = 1
@export var mesh_lod_bias: float = .6
@export var shadow_quality: int = 1
@export var contact_intensity: float = .20
@export var indirect_intensity: float = 1.0
@export var shaft_strength: float = 1.0
@export var fog_strength: float = 1.0
@export var spray_budget: int = 192
@export var grain_budget: int = 128
@export var mist_budget: int = 48
@export var weather_quality: int = 2
@export var weather_budget: float = 1.0

static func preset(asset_tier: int) -> Resource:
	# Named Low/Balanced/High anchors for resource and fixture consumers.
	return numbered([1,4,7][clampi(asset_tier,0,2)])

static func numbered(id: int, overrides: Dictionary = {}) -> Resource:
	var q = load("res://scripts/presentation/graphics_quality.gd").new()
	q.preset_id = clampi(id,1,10)
	q.level = 0 if id<4 else (1 if id<7 else 2)
	var values = Presets.values(q.preset_id)
	values.merge(Presets.sanitize(overrides),true)
	# Ordered LOD transitions avoid invisible gaps after arbitrary edits.
	values.tree_mid_m = maxf(values.tree_mid_m,values.tree_near_m+20.0)
	values.tree_far_m = maxf(values.tree_far_m,values.tree_mid_m+50.0)
	for key in values: q.set(key,values[key])
	q.texture_suffix = "_low" if q.texture_tier==0 else ""
	q.surface_texture_suffix = ["_low","","_high"][q.texture_tier]
	q.snow_particles = Vector3i(q.spray_budget,q.grain_budget,q.mist_budget)
	return q

func snapshot() -> Dictionary:
	var result = {}
	for key in Presets.CONTROLS: result[key] = get(key)
	return result

func label() -> String:
	return ["low","balanced","high"][level]

func apply_snow_material(material: ShaderMaterial, sparkle_scale: float = 1.0) -> void:
	material.set_shader_parameter("snow_sparkle_strength",snow_sparkle*sparkle_scale)
	material.set_shader_parameter("snow_crystal_density",snow_crystal_density)
	material.set_shader_parameter("snow_sheen_strength",snow_sheen)

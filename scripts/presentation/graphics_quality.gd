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
@export var highlight_glow_intensity: float = .252
@export var snow_particles: Vector3i = Vector3i(192,128,48)
@export var snow_track_capacity: int = 1600
@export var snow_track_relief: bool = true
@export var snow_sparkle: float = 6.0
@export var snow_crystal_density: float = 1.35
@export var snow_sheen: float = .084
@export var snow_local_deformation: bool = false
@export var offmap_prop_density: float = .6
@export var offmap_tree_distance_m: float = 4500.0

static func preset(id: int) -> Resource:
	var q = load("res://scripts/presentation/graphics_quality.gd").new()
	q.level = clampi(id,0,2)
	q.offmap_prop_density = [.3,.6,1.0][q.level]
	q.offmap_tree_distance_m = [3000.0,4500.0,6000.0][q.level]
	if q.level == 0:
		q.snow_particles = Vector3i(96,64,0)
		q.snow_track_capacity = 800
		q.snow_track_relief = false
		q.snow_sparkle = 0.0
		q.snow_crystal_density = 0.0
		q.snow_sheen = .06
		q.highlight_glow = false
		q.highlight_glow_intensity = 0.0
		q.contact_shading = false
		q.texture_suffix = "_low"
		q.surface_texture_suffix = "_low"
		q.tree_near_m = 40.0
		q.tree_mid_m = 135.0
		q.tree_far_m = 700.0
		q.scrub_distance_m = 45.0
		q.scrub_density = 0.45
		q.shadow_distance_m = 100.0
		q.normal_strength = 0.23
	elif q.level == 2:
		q.snow_local_deformation = true
		q.snow_particles = Vector3i(384,256,128)
		q.snow_track_capacity = 4096
		q.snow_sparkle = 9.0
		q.snow_crystal_density = 1.75
		q.snow_sheen = .132
		q.highlight_glow_intensity = .35
		q.volumetric_shafts = true
		q.indirect_lighting = true
		q.surface_texture_suffix = "_high"
		q.tree_near_m = 95.0
		q.tree_mid_m = 280.0
		q.tree_far_m = 1300.0
		q.scrub_distance_m = 130.0
		q.shadow_distance_m = 220.0
		q.normal_strength = 0.42
	return q

func label() -> String:
	return ["low","balanced","high"][level]

func apply_snow_material(material: ShaderMaterial, sparkle_scale: float = 1.0) -> void:
	material.set_shader_parameter("snow_sparkle_strength",snow_sparkle*sparkle_scale)
	material.set_shader_parameter("snow_crystal_density",snow_crystal_density)
	material.set_shader_parameter("snow_sheen_strength",snow_sheen)

extends Resource
## Presentation budgets only. Never consumed by the simulation or course seed.
@export_enum("Low","Balanced","High") var level: int = 1
@export var texture_suffix: String = ""
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

static func preset(id: int) -> Resource:
	var q = load("res://scripts/presentation/graphics_quality.gd").new()
	q.level = clampi(id,0,2)
	if q.level == 0:
		q.contact_shading = false
		q.texture_suffix = "_low"
		q.tree_near_m = 40.0
		q.tree_mid_m = 135.0
		q.tree_far_m = 700.0
		q.scrub_distance_m = 45.0
		q.scrub_density = 0.45
		q.shadow_distance_m = 100.0
		q.normal_strength = 0.23
	elif q.level == 2:
		q.indirect_lighting = true
		q.terrain_gi = true
		q.tree_near_m = 110.0
		q.tree_mid_m = 330.0
		q.tree_far_m = 1250.0
		q.scrub_distance_m = 130.0
		q.shadow_distance_m = 220.0
	return q

func label() -> String:
	return ["low","balanced","high"][level]

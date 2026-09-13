extends RefCounted
## A per-session view of immutable terrain. Filter before the earliest-hit merge.
var field
var source
var policy

func _init(terrain = null, production_surface = null, rules = null) -> void:
	field = terrain; source = production_surface if production_surface!=null else terrain; policy = rules

func sample(x: float, z: float) -> Dictionary: return source.sample(x,z)
func contact_normal(x: float, z: float) -> Vector3: return source.contact_normal(x,z)
func snow_depth_at(x: float, z: float) -> float: return source.snow_depth_at(x,z)
func rock_fraction_at(x: float, z: float) -> float: return source.rock_fraction_at(x,z)

func category_hit(from: Vector3, to: Vector3, trees: bool, rocks: bool) -> Dictionary:
	if "tree_data" in field:
		if not field.ski_bounds().has_point(Vector2(to.x,to.z)): return {"reason":field.boundary_message,"boundary":true}
		var tree: Dictionary = field._sweep_trees(from,to) if trees else {}
		var mineral: Dictionary = field.geology.collision.sweep(from,to) if rocks else {}
		return mineral if not mineral.is_empty() and mineral.fraction<float(tree.get("fraction",INF)) else tree
	return field.sweep_filtered_obstacle_contact(from,to,trees,rocks)

func sweep_obstacle_contact(from: Vector3, to: Vector3) -> Dictionary:
	var hit = category_hit(from,to,policy.values.trees,policy.values.rocks)
	if source!=field: return source.sweep_obstacle_contact(from,to,hit)
	return hit

func sweep_obstacle(from: Vector3, to: Vector3) -> String:
	return sweep_obstacle_contact(from,to).get("reason","")

func overlaps(point: Vector3, category: String) -> bool:
	var hit = category_hit(point,point,category=="trees",category=="rocks")
	return not hit.is_empty() and not hit.get("boundary",false)

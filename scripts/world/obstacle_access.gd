extends RefCounted
## Indexed access for packed mountains and the deliberately small laboratory.
static func count(field) -> int:
	return field.tree_data.size() if "tree_data" in field else field.obstacles.size()

static func record(field, id: int) -> Dictionary:
	return field.tree_data.record(id) if "tree_data" in field else field.obstacles[id]

static func position(field, id: int) -> Vector3:
	return field.tree_data.positions[id] if "tree_data" in field else field.obstacles[id].position

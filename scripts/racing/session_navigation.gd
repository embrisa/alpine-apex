extends RefCounted
## Memory-only landmarks. SceneTree metadata outlives scene rebuilds, not the app.
const META_KEY = "session_navigation_points"
const MAX_POINTS = 32
const Zone = preload("res://scripts/world/mountain_zone.gd")
signal changed
var mountain_identity: String = ""
var shown: bool = true
var _next_id: int = 1
var _points: Array[Dictionary] = []

static func acquire(tree: SceneTree, identity: String):
	var state = tree.get_meta(META_KEY) if tree.has_meta(META_KEY) else null
	if state == null:
		state = load("res://scripts/racing/session_navigation.gd").new()
		tree.set_meta(META_KEY,state)
	state.bind_mountain(identity)
	return state

func bind_mountain(identity: String) -> void:
	assert(not identity.is_empty(),"Navigation requires a full physical mountain identity")
	if identity == mountain_identity: return
	mountain_identity = identity
	_points.clear()
	_next_id = 1
	shown = true
	changed.emit()

func points() -> Array[Dictionary]:
	return _points.duplicate(true)

func count() -> int:
	return _points.size()

func point(id: int) -> Dictionary:
	for entry in _points:
		if entry.id == id: return entry.duplicate()
	return {}

static func anchor(surface, proposed: Vector3) -> Dictionary:
	if not proposed.is_finite() or not surface.ski_bounds().has_point(Vector2(proposed.x,proposed.z)):
		return {"error":"Choose supported terrain inside the skiable mountain."}
	if not Zone.new(surface).contains(proposed):
		return {"error":"Choose terrain inside the summit-return boundary."}
	var sample = surface.sample(proposed.x,proposed.z)
	var height = float(sample.height)
	if not is_finite(height): return {"error":"This terrain has no valid support."}
	var seated = Vector3(proposed.x,height,proposed.z)
	# A point needs support; it does not need a race gate footprint, slope or margin.
	if surface.has_method("sweep_obstacle") and not surface.sweep_obstacle(seated,seated).is_empty():
		return {"error":"Place the point on open terrain, away from a tree or rock."}
	return {"position":seated,"error":""}

func add_point(surface, proposed: Vector3) -> Dictionary:
	if count() >= MAX_POINTS: return {"error":"All 32 navigation points are in use. Remove a point to add another."}
	var result = anchor(surface,proposed)
	if not result.error.is_empty(): return result
	var id = _next_id
	_next_id += 1
	_points.append({"id":id,"position":result.position})
	changed.emit()
	return {"id":id,"error":""}

func move_point(id: int, surface, proposed: Vector3) -> Dictionary:
	var result = anchor(surface,proposed)
	if not result.error.is_empty(): return result
	for i in _points.size():
		if _points[i].id == id:
			_points[i].position = result.position
			changed.emit()
			return {"id":id,"error":""}
	return {"error":"Select an existing point to move."}

func remove_point(id: int) -> bool:
	for i in _points.size():
		if _points[i].id == id:
			_points.remove_at(i)
			changed.emit()
			return true
	return false

func clear_points() -> void:
	if _points.is_empty(): return
	_points.clear() # IDs are not reused within this mountain session.
	changed.emit()

func set_shown(value: bool) -> void:
	if shown == value: return
	shown = value
	changed.emit()

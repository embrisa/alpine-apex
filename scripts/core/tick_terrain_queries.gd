extends RefCounted
## Exact queries shared only during one synchronous solver step. Production V15
## terrain is immutable within that step; mutable/unknown adapters bypass this.
const Massif = preload("res://scripts/world/generators/alpine_massif_v15.gd")
const Props = preload("res://scripts/world/prop_collision_surface.gd")
var source
var samples: Dictionary = {}
var normals: Dictionary = {}
var depths: Dictionary = {}
var materials: Dictionary = {}

func begin(surface):
	clear()
	var terrain = surface.terrain if surface.get_script()==Props else surface
	if terrain==null or terrain.get_script()!=Massif: return surface
	source=surface
	return self

func clear() -> void:
	source=null
	samples.clear(); normals.clear(); depths.clear(); materials.clear()

func sample(x: float,z: float) -> Dictionary:
	# Nested scalar keys preserve full GDScript float precision. Vector2 keys
	# would round different query coordinates into the same float32 value.
	if not samples.has(x): samples[x]={}
	var row:Dictionary=samples[x]
	if not row.has(z): row[z]=source.sample(x,z)
	return row[z]

func contact_normal(x: float,z: float) -> Vector3:
	if not normals.has(x): normals[x]={}
	var row:Dictionary=normals[x]
	if not row.has(z): row[z]=source.contact_normal(x,z)
	return row[z]

func snow_depth_at(x: float,z: float) -> float:
	if not depths.has(x): depths[x]={}
	var row:Dictionary=depths[x]
	if not row.has(z): row[z]=source.snow_depth_at(x,z)
	return row[z]

func rock_fraction_at(x: float,z: float) -> float:
	if not materials.has(x): materials[x]={}
	var row:Dictionary=materials[x]
	if not row.has(z): row[z]=source.rock_fraction_at(x,z)
	return row[z]

func sweep_obstacle(from: Vector3,to: Vector3) -> String:
	return source.sweep_obstacle(from,to)

func sweep_obstacle_contact(from: Vector3,to: Vector3) -> Dictionary:
	return source.sweep_obstacle_contact(from,to)

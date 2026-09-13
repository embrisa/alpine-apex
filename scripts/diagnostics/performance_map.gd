extends "res://scripts/diagnostics/test_map.gd"
## Authored local rendering workloads, with production forest and mineral components.
var performance_fixture = true
var geology = ExplicitGeology.new()
var exposure_image: Image
var MASK_ORIGIN: Vector2
var MASK_SIZE: Vector2i

class ExplicitGeology extends RefCounted:
	var catalog
	var collision = preload("res://scripts/world/mineral_collision.gd").new()
	var placements: Array = []

func _init(id: String, options: Dictionary = {}) -> void:
	super(id,options)
	MASK_ORIGIN=Vector2(X_MIN,Z_MIN); MASK_SIZE=Vector2i(NX,NZ)
	exposure_image=Image.create(NX,NZ,false,Image.FORMAT_RGBA8)
	exposure_image.fill(Color(0,0,0,0))
	for spec in fixture_spec.objects:
		if spec.get("kind","")!="mineral": continue
		if geology.catalog==null: geology.catalog=preload("res://scripts/world/mineral_catalog.gd").new()
		assert(geology.catalog.records.has(spec.asset),"Missing explicit performance-map mineral: "+spec.asset)
		var row: Dictionary=geology.catalog.records[spec.asset]
		var yaw=deg_to_rad(spec.yaw)
		var basis=Basis(Vector3.UP,yaw).scaled(Vector3.ONE*spec.scale)
		if row.category in ["small","medium"]:
			var up=Vector3.UP.slerp(sample(spec.x,spec.z).normal,.92).normalized()
			var forward=Vector3(sin(yaw),0,cos(yaw)).slide(up).normalized()
			var right=up.cross(forward).normalized()
			basis=Basis(right,up,right.cross(up)).scaled(Vector3.ONE*spec.scale)
		var pose=Transform3D(basis,Vector3(spec.x,0,spec.z))
		# Production burial rule: every foundation point stays below the snow.
		# Small stones follow the support normal; macro forms remain upright.
		var support=INF
		for local_point in row.seating:
			var p: Vector3=pose*local_point
			support=minf(support,sample(p.x,p.z).height-p.y-.10)
		var burial=.52 if row.category=="huge_boulders" else .22
		pose.origin.y=minf(support,sample(spec.x,spec.z).height-row.size_m.y*spec.scale*burial)
		var placed={"id":geology.placements.size(),"asset":spec.asset,"pose":pose,"solid":true,"snow":.55,"moss":.0,"grass":false}
		geology.placements.append(placed)
		geology.collision.add(placed,row)

func _height(p: Vector2) -> float:
	var h=-p.y*.28
	# Common baseline: no terrain changes when components are added/removed.
	h+=2.0*exp(-pow((p.y-196.0)/22.0,2))
	h-=1.5*exp(-pow((p.y-286.0)/25.0,2))
	h+=maxf(0.0,absf(p.x)-14.0)*.055
	# An outboard ripple strip supports terrain/shadow/contact inspection.
	h+=smoothstep(45.0,65.0,absf(p.x))*.30*cos(p.y*TAU/24.0)
	return h

func sweep_obstacle_contact(from: Vector3,to: Vector3) -> Dictionary:
	var contact=super.sweep_obstacle_contact(from,to)
	if contact.get("boundary",false) or geology==null: return contact
	var mineral: Dictionary=geology.collision.sweep(from,to)
	return mineral if not mineral.is_empty() and (contact.is_empty() or mineral.fraction<contact.fraction) else contact

func ray_geology(from: Vector3,to: Vector3,radius: float = 0.0) -> Dictionary:
	return geology.collision.sweep(from,to,Vector3.ONE*radius,Vector3.ZERO)

func fixture_descriptor() -> Dictionary:
	var result=super.fixture_descriptor()
	result.kind="performance"
	result.trees=obstacles.size()
	result.rocks=0 if geology==null else geology.placements.size()
	result.objects=result.trees+result.rocks
	result.design=fixture_spec.design
	return result

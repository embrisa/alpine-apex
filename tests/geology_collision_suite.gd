extends SceneTree
const Collision=preload("res://scripts/world/mineral_collision.gd")
var failures: Array=[]
var checks=0
class FlatRockField:
	extends RefCounted
	var collision
	func sample(_x: float,_z: float) -> Dictionary: return {"height":-20.0}
	func ray_geology(a: Vector3,b: Vector3,radius: float=0.0) -> Dictionary:
		return collision.sweep(a,b,Vector3.ONE*radius,Vector3.ZERO)
class SolverRockField:
	extends "res://scripts/world/heightfield_surface.gd"
	var rocks
	func _init() -> void:
		heights.resize(NX*NZ); heights.fill(0.0)
	func sweep_obstacle_contact(a: Vector3,b: Vector3) -> Dictionary: return rocks.sweep(a,b)
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures.append(label); printerr("FAIL ",label)

func cube_record() -> Dictionary:
	var points=PackedVector3Array()
	for x in [-1,1]:
		for y in [-1,1]:
			for z in [-1,1]: points.append(Vector3(x,y,z))
	return {"id":"cube","aabb":AABB(-Vector3.ONE,Vector3.ONE*2),"hull_points":[points],
		"hull_axes":[{"normals":[[1,0,0],[0,1,0],[0,0,1]],"edges":[[1,0,0],[0,1,0],[0,0,1]]}]}

func run() -> void:
	var collision=Collision.new()
	collision.add({"id":1,"pose":Transform3D(Basis.IDENTITY,Vector3(0,1,0)),"solid":true},cube_record())
	var hit=collision.sweep(Vector3(-10,0,0),Vector3(10,0,0))
	check(not hit.is_empty() and absf(hit.position.x+1.35)<.0001 and hit.normal.dot(Vector3.LEFT)>.999,"Earliest direct contact includes rider width")
	check(collision.sweep(Vector3(-10,2.2,0),Vector3(10,2.2,0)).is_empty(),"Airborne passage above a boulder remains clear")
	check(not collision.sweep(Vector3(-10,1.8,0),Vector3(10,1.8,0)).is_empty(),"Airborne rider can strike the exposed top")
	check(not collision.sweep(Vector3(0,0,0),Vector3(0,0,0)).is_empty(),"Stationary occupancy detects an embedded rider")
	check(collision.sweep(Vector3(.95,0,0),Vector3(2,0,0)).is_empty(),"An overlapping rider can move outward")
	var rotated=Collision.new()
	rotated.add({"id":2,"pose":Transform3D(Basis(Vector3.UP,PI/4),Vector3(0,1,0)),"solid":true},cube_record())
	check(rotated.sweep(Vector3(1.6,0,1.6),Vector3(1.7,0,1.7)).is_empty(),"Rotated rock does not fill the corners of its bounds")
	var glance=rotated.sweep(Vector3(-4,0,.4),Vector3(4,0,.4))
	check(not glance.is_empty() and absf(glance.normal.z)>.5,"Glancing impact follows a rotated rock face")
	var split=Collision.new()
	for x in [-3,3]: split.add({"id":x,"pose":Transform3D(Basis.IDENTITY,Vector3(x,1,0)),"solid":true},cube_record())
	check(split.sweep(Vector3(0,0,-5),Vector3(0,0,5)).is_empty(),"Open passage between solid pieces stays open")
	split.add({"id":9,"pose":Transform3D(Basis.IDENTITY.scaled(Vector3(4,.3,2)),Vector3(0,3,0)),"solid":true},cube_record())
	check(split.sweep(Vector3(0,0,-5),Vector3(0,0,5)).is_empty(),"Rider passes beneath a supported overhang")
	check(not split.sweep(Vector3(0,2,-5),Vector3(0,2,5)).is_empty(),"Airborne rider strikes the same overhang")
	var field=FlatRockField.new(); field.collision=collision
	var camera=preload("res://scripts/presentation/chase_camera.gd").new()
	root.add_child(camera); camera.position=Vector3(10,1.1,0)
	camera._clear_terrain(field,Vector3(-10,0,0),false)
	check(camera.position.x< -1.65 and field.ray_geology(Vector3(-10,1.1,0),camera.position,.65).is_empty(),"Camera boom retracts outside the mineral with near-plane clearance")
	camera.queue_free()
	var solver_field=SolverRockField.new(); solver_field.rocks=collision
	for altitude in [0.0,1.5]:
		var sim=preload("res://scripts/core/ski_simulation.gd").new(preload("res://config/ski_default.tres").duplicate(true))
		sim.reset(Vector3(-3,altitude,0),PI/2)
		sim.prime_contacts(solver_field); sim.velocity=Vector3(90,0,0)
		for tick in 12:
			sim.step(1.0/120,RiderInput.new(),solver_field)
			if sim.crashed: break
		check(sim.impacts.last_reason=="ROCK IMPACT" and sim.impacts.reserve<1 and sim.position.x< -1.34 and absf(sim.velocity.x)<.01,"120 Hz solver stops a %s mineral strike and spends impact reserve" % ("grounded" if altitude==0 else "airborne"))
	var thin=Collision.new()
	thin.add({"id":3,"pose":Transform3D(Basis.IDENTITY.scaled(Vector3(.05,2,2)),Vector3(2500,100,2500)),"solid":true},cube_record())
	check(not thin.sweep(Vector3(2450,100,2500),Vector3(2550,100,2500)).is_empty(),"Continuous sweep catches a thin far-from-origin wall")
	check(collision.sweep(Vector3(0,5,0),Vector3(0,-5,0),Vector3.ZERO,Vector3.ZERO).normal.dot(Vector3.UP)>.999,"Survey rays hit the top rather than hidden ground")
	var composite=cube_record()
	var template=composite.hull_points[0]
	var template_axes=composite.hull_axes[0]
	composite.hull_points=[]; composite.hull_axes=[]
	for x in 8:
		for z in 8:
			var points=PackedVector3Array()
			for point in template: points.append(point+Vector3(x*4,0,z*4))
			composite.hull_points.append(points); composite.hull_axes.append(template_axes)
	var hierarchy=Collision.new()
	hierarchy.add({"id":4,"pose":Transform3D.IDENTITY,"solid":true},composite)
	var hierarchy_matches=true
	for z in range(-3,33):
		var a=Vector3(-5,0,z); var b=Vector3(35,0,z+.3)
		var accelerated=hierarchy.sweep(a,b)
		var earliest=INF
		for piece in hierarchy.entries[0].hulls.size():
			var spans=hierarchy._spans(hierarchy.entries[0],piece)
			var exhaustive=Collision.sweep_hull(a+Vector3(0,.8,0),b+Vector3(0,.8,0),Vector3(.35,.8,.35),spans)
			if not exhaustive.is_empty(): earliest=minf(earliest,exhaustive.fraction)
		hierarchy_matches=hierarchy_matches and (accelerated.is_empty() if is_inf(earliest) else (not accelerated.is_empty() and absf(accelerated.fraction-earliest)<.00001))
	check(hierarchy_matches,"Piece hierarchy matches exhaustive sweeps through a 64-piece formation")
	DirAccess.make_dir_recursive_absolute("res://artifacts/geology_v11")
	preload("res://tests/test_report.gd").write("res://artifacts/geology_v11/collision_tests.json",JSON.stringify({"checks":checks,"failures":failures},"\t"))
	print("GEOLOGY_COLLISION ",checks," checks, ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)

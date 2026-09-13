extends SceneTree
const Maps=preload("res://scripts/diagnostics/test_map.gd")
const Simulation=preload("res://scripts/core/ski_simulation.gd")
var failures: Array[String]=[]
var checks=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	print("PASS: " if ok else "FAIL: ",label)
	if not ok: failures.append(label)
func run() -> void:
	var baseline=Maps.create("perf-slopes")
	var combined=Maps.create("perf-mixed")
	for id in ["perf-slopes","perf-rocks","perf-vegetation","perf-mixed"]:
		var field=Maps.create(id); var repeated=Maps.create(id)
		var trees=384 if id in ["perf-vegetation","perf-mixed"] else 0
		var rocks=48 if id in ["perf-rocks","perf-mixed"] else 0
		var description=field.fixture_descriptor()
		check(field.heights==baseline.heights and field.heights==repeated.heights,id+": common deterministic terrain")
		check(field.obstacles==repeated.obstacles and field.fixture_identity==repeated.fixture_identity,id+": deterministic vegetation and identity")
		check(description.trees==trees and description.rocks==rocks and description.objects==trees+rocks,id+": exact component population")
		check(field.CELL==4 and field.NX==65 and field.NZ==129 and field.heights.size()==8385,id+": bounded production grid")
		var triangles=true
		for z in range(0,field.NZ-1,9):
			for x in range(0,field.NX-1,7):
				for p in [field.vertex(x,z)*.2+field.vertex(x+1,z)*.3+field.vertex(x,z+1)*.5,field.vertex(x+1,z)*.2+field.vertex(x+1,z+1)*.3+field.vertex(x,z+1)*.5]:
					triangles=triangles and absf(p.y-field.sample(p.x,p.z).height)<.0001
		check(triangles,id+": both rendered/contact triangles agree")
		check(Maps.valid_reference(Maps.to_reference(field,field.seed_value)),id+": isolated fixture reference validates")
		if trees: check(field.obstacles==combined.obstacles,id+": exact shared vegetation placements")
		check((field.geology.catalog!=null)==(rocks>0),id+": empty collision component loads no mineral assets")
		if rocks:
			check(field.geology.placements==repeated.geology.placements and field.geology.placements==combined.geology.placements,id+": exact shared mineral placements")
			var clear_trunks=true
			for entry in field.geology.collision.entries:
				for tree in combined.obstacles:
					clear_trunks=clear_trunks and entry.aabb.grow(tree.radius).intersects_segment(tree.position,tree.position+Vector3.UP*tree.height)==null
			check(clear_trunks,id+": mineral bounds do not intersect tree trunks")
			check(field.geology.collision.entries.size()==48,id+": real frozen mineral hulls installed")
			var buried=true
			for placed in field.geology.placements:
				for local_point in field.geology.catalog.records[placed.asset].seating:
					var point: Vector3=placed.pose*local_point
					buried=buried and point.y<=field.sample(point.x,point.z).height-.05
			check(buried,id+": every mineral foundation point is buried below snow")
			var corridor=true
			for entry in field.geology.collision.entries:
				corridor=corridor and (entry.aabb.end.x< -12 or entry.aabb.position.x>12)
			check(corridor,id+": real rock bounds leave the lane clear")
			var entry=field.geology.collision.entries[0]
			var center: Vector3=entry.aabb.get_center()
			check(not field.sweep_obstacle_contact(center-Vector3(10,.5,0),center+Vector3(10,-.5,0)).is_empty(),id+": production mineral collision sweep reaches the rider")
		var sim=Simulation.new(); sim.tuning=load("res://config/ski_default.tres").duplicate(true)
		var p=Vector3(0,field.sample(0,64).height,64)
		sim.reset(p,0); sim.prime_contacts(field)
		sim.velocity=Vector3.DOWN.slide(field.sample(p.x,p.z).normal).normalized()*60.0/3.6
		var input=RiderInput.new(); input.tuck=.35; input.brake=.08
		for tick in 1200: sim.step(1.0/120.0,input,field)
		check(not sim.crashed and sim.position.z<field.finish_z and sim.ticks==1200,id+": complete maximum 10-second ordinary-input window")
		check(field.sweep_obstacle_contact(Vector3.ZERO,Vector3(500,0,0)).get("boundary",false),id+": early boundary remains an explicit failure")
	print("PERFORMANCE_MAP_RESULTS ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)

extends SceneTree
const Surface=preload("res://scripts/world/heightfield_surface.gd")
const Crash=preload("res://scripts/world/crash_collision.gd")
const Definition=preload("res://scripts/world/mountain_definition.gd")
class StubWorld extends Node:
	var surface
	var terrain_chunks: Array=[]
var failures: Array=[]
var checks=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures.append(label); printerr("FAIL ",label)
func run() -> void:
	var field=Surface.new()
	var rng=RandomNumberGenerator.new()
	rng.seed=134892
	for i in 800:
		var p=Vector3(rng.randf_range(-2000,2000),0,rng.randf_range(-2000,2000))
		field.add_obstacle({"position":p,"radius":rng.randf_range(.3,3),"height":12.0,"tree":true})
	for p in [Vector3.ZERO,Vector3(48,0,-48),Vector3(-.1,0,.1),Vector3(1999,0,1999)]:
		for radius in [0.0,12.0,175.0,240.0,400.0]:
			var expected: Array=[]
			for i in field.obstacles.size():
				var q: Vector3=field.obstacles[i].position
				if Vector2(p.x-q.x,p.z-q.z).length_squared()<=radius*radius: expected.append(i)
			check(field.nearby_obstacle_indices(p,radius)==expected,"Grid query agrees with brute-force distance across cell boundaries")
	var world=StubWorld.new()
	world.surface=field
	root.add_child(world)
	var crash=Crash.new()
	crash.world=world
	world.add_child(crash)
	crash.prepare(Vector3.ZERO)
	var expected=field.nearby_obstacle_indices(Vector3.ZERO,174.999)
	var actual=crash.obstacles.keys(); actual.sort()
	check(actual==expected,"Crash preparation activates the same nearby trunks")
	for id in actual:
		var node=crash.obstacles[id]
		var shape=node.get_child(0).shape
		check(is_equal_approx(shape.radius,field.obstacles[id].radius) and is_equal_approx(shape.height,field.obstacles[id].height),"Ragdoll trunk envelopes match the source")
		check(node.get_meta("audio_material")==2,"Tree material metadata survives spatial preparation")
	crash.prepare(Vector3(10000,0,10000))
	check(crash.obstacles.is_empty(),"Teleport retires every old trunk body")
	check(Definition.CURRENT_VERSION==18 and Definition.parse_seed("42").version==18,"Bare seeds use current v18")
	check(Definition.CurrentTerrain.GENERATOR_VERSION==18 and not Definition.CurrentTerrain.GENERATOR_ID.is_empty(),"Versioned fields expose scenery dispatch metadata")
	check(not Definition.parse_seed("42 / v12").get("error","").is_empty(),"Obsolete shared recipes are rejected")
	check(not Definition.parse_seed("42 / v%d" % (Definition.CURRENT_VERSION+1)).get("error","").is_empty(),"Unsupported future recipes are rejected")
	world.queue_free()
	await process_frame
	print("DENSITY_SPATIAL ",checks," checks ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)

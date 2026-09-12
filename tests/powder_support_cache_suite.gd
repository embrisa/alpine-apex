extends SceneTree
## Exact immutable support-grid reuse. No renderer, simulation or preferences.
const Powder = preload("res://scripts/presentation/powder_surface.gd")
var checks = 0
var failures: Array[String] = []

class Surface extends RefCounted:
	var queries = 0
	var offset = 0.0
	func render_normal(x: float, z: float) -> Vector3:
		queries += 1
		return Vector3(sin(x*.17+offset),2.0,cos(z*.23-offset)).normalized()
	func snow_depth_at(x: float, z: float) -> float:
		return .15+.12*sin(x*.31+z*.29+offset)

class World extends RefCounted:
	var surface

func _initialize() -> void: call_deferred("run")

func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)
	print("PASS: " if value else "FAIL: ",label)

func run() -> void:
	var world = World.new(); world.surface = Surface.new()
	var cached = Powder.new(); cached.world = world
	var positions = [Vector2.ZERO,Vector2(4,0),Vector2(8,4),Vector2(4,0),Vector2(4,0),Vector2(100,100),Vector2(101,100)]
	var expected_queries = [81,9,17,17,0,81,81]
	for i in positions.size():
		var before: int = world.surface.queries
		var actual = cached._support_bytes(positions[i])
		var queried: int = world.surface.queries-before
		var fresh = Powder.new(); fresh.world = world
		var reference = fresh._support_bytes(positions[i]); fresh.free()
		check(actual==reference,"Every normal/depth byte equals uncached terrain at move %d"%i)
		check(queried==expected_queries[i],"Bounded newly exposed queries at move %d: %d"%[i,queried])
		check(cached.support_cache.size()*4==Powder.SUPPORT_BYTES,"Cache retains exactly one 1296-byte support grid at move %d"%i)
	var previous = cached._support_bytes(Vector2.ZERO)
	world.surface = Surface.new(); world.surface.offset = .7
	var replaced = cached._support_bytes(Vector2.ZERO)
	check(world.surface.queries==81 and previous!=replaced,"World replacement rebuilds every support knot")
	world.surface.offset = .9
	cached.reset()
	var before_reset: int = world.surface.queries
	var reset_bytes = cached._support_bytes(Vector2.ZERO)
	check(world.surface.queries-before_reset==81 and reset_bytes!=replaced,"Lifecycle reset invalidates retained support bytes")
	var expected = Powder.new(); expected.world = world
	check(reset_bytes==expected._support_bytes(Vector2.ZERO),"Reset output remains byte-exact to a fresh grid")
	expected.free(); cached.free()
	print("POWDER_SUPPORT_CACHE_CHECKS ",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)

extends SceneTree
const Queries=preload("res://scripts/core/tick_terrain_queries.gd")
const Massif=preload("res://scripts/world/generators/alpine_massif_v17.gd")
const Props=preload("res://scripts/world/prop_collision_surface.gd")
var checks=0
var failures=[]
class Mutable extends RefCounted:
	var height=3.0
	func sample(_x:float,_z:float) -> Dictionary: return {"height":height,"normal":Vector3.UP}
func check(ok:bool,label:String) -> void:
	checks+=1
	if not ok: failures.append(label);printerr("FAIL ",label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var field=Massif.new(849205174,false)
	field.NX=9;field.NZ=9;field.X_MIN=-16;field.Z_MIN=-16
	field.heights.resize(81)
	for i in 81: field.heights[i]=float(i%9)*.2-float(i/9)*.35
	field.build_material_map()
	var cache=Queries.new()
	check(cache.begin(field)==cache,"Production V15 queries opt into a single step")
	var rng=RandomNumberGenerator.new();rng.seed=981561
	for i in 300:
		var x=rng.randf_range(-20,20);var z=rng.randf_range(-20,20)
		for repeat in 2:
			check(cache.sample(x,z)==field.sample(x,z),"Raw triangle sample remains exact")
			check(cache.contact_normal(x,z)==field.contact_normal(x,z),"Distributed normal remains exact")
			check(cache.snow_depth_at(x,z)==field.snow_depth_at(x,z),"Analytic snow depth remains exact")
			check(cache.rock_fraction_at(x,z)==field.rock_fraction_at(x,z),"Material interpolation remains exact")
	# Both pairs collapse to one Vector2 coordinate, but are distinct doubles.
	cache.clear();cache.begin(field)
	var x1=8.0;var x2=8.0+0.00000001
	var z1=7.0;var z2=7.0+0.00000001
	cache.sample(x1,z1);cache.sample(x2,z1);cache.sample(x1,z2)
	check(cache.samples.size()==2 and cache.samples[x1].size()==2,"Scalar keys retain sub-float32 coordinate differences")
	var previous=cache.sample(1,1).height
	cache.clear()
	check(cache.source==null and cache.samples.is_empty() and cache.depths.is_empty(),"Completed step releases all terrain/cache references")
	for i in 81: field.heights[i]+=2.0
	cache.begin(field)
	check(cache.sample(1,1).height!=previous and cache.sample(1,1)==field.sample(1,1),"Next step sees terrain mutation")
	var previous_depth=cache.snow_depth_at(1,1)
	field.noise.seed+=1;cache.begin(field)
	check(cache.snow_depth_at(1,1)==field.snow_depth_at(1,1),"Next step sees analytic snow mutation")
	var mutable=Mutable.new()
	check(cache.begin(mutable)==mutable and cache.source==null,"Unknown mutable adapter bypasses caching")
	mutable.height=11.0
	check(mutable.sample(0,0).height==11.0,"Mutable queries remain live")
	var props=Props.new(field)
	check(cache.begin(props)==cache,"Production collision adapter shares pure terrain queries")
	check(cache.sample(1,1)==props.sample(1,1),"Collision adapter retains terrain authority")
	check(not cache.has_method("bounds") and not cache.has_method("ski_bounds"),"Cache does not manufacture prediction bounds; solver passes the original adapter")
	var mutable_props=Props.new(mutable)
	check(cache.begin(mutable_props)==mutable_props,"Collision adapter over mutable terrain bypasses caching")
	print("TICK_TERRAIN_QUERY_RESULTS ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)

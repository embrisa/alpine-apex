extends SceneTree
## Runtime quality changes must remove penumbra again when lowering filtering.
const World=preload("res://scripts/world/alpine_world.gd")
const Quality=preload("res://scripts/presentation/graphics_quality.gd")
var checks=0
var failures=[]
func _initialize():call_deferred("run")
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);printerr("FAIL ",label)
func run():
	var world=World.new();root.add_child(world);world._environment()
	world.assets=preload("res://scripts/presentation/alpine_assets.gd").new(world.cloud_lighting,world.quality)
	for id in [4,7,10,1,7,4]:
		var q=Quality.numbered(id);var snapshot=q.snapshot();world.apply_graphics(q)
		for lamp in [world.sun,world.moon]:
			check(is_equal_approx(lamp.light_angular_distance,.53 if id>=7 else 0.0),"Preset transition applies or clears penumbra on both lights")
			check(lamp.directional_shadow_max_distance==q.shadow_distance_m,"Shadow reach retains the selected quality")
			check(lamp.directional_shadow_mode==DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS and is_equal_approx(lamp.shadow_bias,.035),"Existing cascades and contact bias are retained")
		check(q.snapshot()==snapshot,"Applying light quality never raises a filter or population budget")
	for id in [1,10]:
		world.apply_graphics(Quality.numbered(id,{"shadow_quality":0 if id==10 else 3}))
		check(is_equal_approx(world.sun.light_angular_distance,.53 if id==1 else 0),"Custom filtering overrides own penumbra, not the preset number")
	check(load("res://tests/shadow_softness_review.gd").can_instantiate(),"Native review producer parses")
	print("SHADOW_SOFTNESS_RESULTS ",JSON.stringify({"checks":checks,"failures":failures}))
	world.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)

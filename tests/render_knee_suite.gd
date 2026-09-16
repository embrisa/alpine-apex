extends SceneTree
## Compare the native search with the portable reference across both cuffs.
const Anatomy = preload("res://scripts/presentation/skier_anatomy.gd")
var checks = 0
var failures: Array[String] = []
func _initialize() -> void:
 if Anatomy.native_fit_kernel==null:
  print("RENDER_KNEE_RESULTS ",JSON.stringify({"native_available":false,"skipped":"Portable reference remains active"})); quit(); return
 var rng = RandomNumberGenerator.new(); rng.seed = 293018
 var largest = 0.0
 var zero_weight = 0
 var short_pole = 0
 for prefix in ["Right","Left"]:
  var side: Dictionary = Anatomy.rest_sides[prefix]
  for i in 2000:
   var boot = Basis.from_euler(Vector3(rng.randf_range(-.8,.8),rng.randf_range(-3.0,3.0),rng.randf_range(-.8,.8)))
   var ankle = Vector3(rng.randf_range(-2,2),rng.randf_range(-1,1),rng.randf_range(-2,2))
   var hip = ankle+boot*Vector3(rng.randf_range(-.2,.2),rng.randf_range(.25,.92),rng.randf_range(-.45,.1))
   var pole = Vector3.ZERO if i%11==0 else Vector3(rng.randf_range(-.6,.6),rng.randf_range(-.3,.3),rng.randf_range(-.6,.6))
   var source = hip.lerp(ankle,.5)+pole
   var weight = [0.0,.5,1.0][i%3]
   var a = Anatomy.reference_render_knee(prefix,hip,ankle,source,boot,side.thigh,side.shin,weight)
   var b = Anatomy.native_fit_kernel.fit_render_knee(prefix,hip,ankle,source,boot,side.thigh,side.shin,weight)
   var delta: float = a.distance_to(b)
   largest = maxf(largest,delta); checks += 1
   if weight==0.0: zero_weight += 1
   if pole==Vector3.ZERO: short_pole += 1
   if (not b.is_finite() or delta>.00001) and failures.size()<16: failures.append(prefix+" sample "+str(i)+" error "+str(delta))
 print("RENDER_KNEE_RESULTS ",JSON.stringify({"native_available":true,"checks":checks,"failures":failures,"max_knee_delta_m":largest,"zero_weight_cases":zero_weight,"axis_pole_cases":short_pole}))
 quit(0 if failures.is_empty() else 1)

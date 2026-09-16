extends SceneTree
## Pair the packaged native fitting kernels against the portable GDScript
## references on random inputs. Skips (not fails) where no library is packaged.
const Body = preload("res://scripts/core/rider_body.gd")
const Anatomy = preload("res://scripts/presentation/skier_anatomy.gd")
var checks = 0
var failures: Array[String] = []
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok and failures.size()<24: failures.append(label)
func _initialize() -> void:
	var report = {"platform":OS.get_name(),"architecture":Engine.get_architecture_name(),"extension":preload("res://scripts/core/skier_kernel.gd").extension_path()}
	if Body.native_fit_kernel==null or Anatomy.native_fit_kernel==null:
		report.native_available = false; report.skipped = "Portable reference remains active"
		print("SKIER_FIT_NATIVE_RESULTS ",JSON.stringify(report)); quit(); return
	var rng = RandomNumberGenerator.new(); rng.seed = 7181930
	var largest_hips = 0.0; var largest_pelvis = 0.0; var largest_limit = 0.0; var exact_hips = 0
	for i in 3000:
		var pelvis = Basis.from_euler(Vector3(rng.randf_range(-.6,.6),rng.randf_range(-3.0,3.0),rng.randf_range(-.9,.9)))
		var hips = Vector3(rng.randf_range(-.3,.3),rng.randf_range(.55,1.0),rng.randf_range(-.3,.3))
		var ankles: Array[Vector3] = []
		var boots: Array[Basis] = []
		for side in [-1.0,1.0]:
			ankles.append(Vector3(side*rng.randf_range(.08,.30),rng.randf_range(.0,.25),rng.randf_range(-.25,.25)))
			boots.append(Basis.from_euler(Vector3(rng.randf_range(-.5,.5),rng.randf_range(-.4,.4),rng.randf_range(-.6,.6))))
		var reference: Vector3 = Body.reference_fit_hips(hips,pelvis,ankles,boots)
		var native: Vector3 = Body.native_fit_kernel.fit(hips,pelvis,ankles,boots)
		var delta = reference.distance_to(native)
		largest_hips = maxf(largest_hips,delta)
		if delta==0.0: exact_hips += 1
		check(native.is_finite() and delta<.00001,"hip fit sample %d error %f" % [i,delta])
		var reference_pelvis: Vector3 = Anatomy.reference_fit_pelvis(hips,pelvis,ankles,boots)
		var native_pelvis: Vector3 = Anatomy.fit_pelvis(hips,pelvis,ankles,boots)
		var pelvis_delta = reference_pelvis.distance_to(native_pelvis)
		largest_pelvis = maxf(largest_pelvis,pelvis_delta)
		# Iterative pelvis fitting exits on tolerances, so float32/double intermediate
		# differences can change one late iteration: allow 2 mm on random extreme poses.
		check(native_pelvis.is_finite() and pelvis_delta<.002,"pelvis fit sample %d error %f" % [i,pelvis_delta])
	for id in ["Hips","Spine02","Spine01","Spine","neck","Head","LeftUpLeg","LeftLeg","RightArm","RightForeArm","LeftHand","RightFoot"]:
		for i in 400:
			var rotation = Basis.from_euler(Vector3(rng.randf_range(-2.5,2.5),rng.randf_range(-2.5,2.5),rng.randf_range(-2.5,2.5)))
			var pole = [0.0,.5,1.0][i%3]; var forearm = [0.0,1.0][i%2]
			var a: Basis = Anatomy.reference_local_limit(id,rotation,pole,forearm)
			var b: Basis = Anatomy.local_limit(id,rotation,pole,forearm)
			var limit_delta = maxf(maxf(a.x.distance_to(b.x),a.y.distance_to(b.y)),a.z.distance_to(b.z))
			largest_limit = maxf(largest_limit,limit_delta)
			check(limit_delta<.0001,id+" limit sample %d error %f" % [i,limit_delta])
	report.merge({"native_available":true,"checks":checks,"failures":failures,"max_hip_fit_delta_m":largest_hips,"exact_hip_fits":exact_hips,"max_pelvis_fit_delta_m":largest_pelvis,"max_limit_basis_delta":largest_limit})
	print("SKIER_FIT_NATIVE_RESULTS ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)

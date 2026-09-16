extends SceneTree
const Sim = preload("res://scripts/core/ski_simulation.gd")
const MotionInput = preload("res://scripts/core/rider_input.gd")
const Anatomy = preload("res://scripts/presentation/skier_anatomy.gd")
func _initialize(): call_deferred("run")
func run():
	var skier = preload("res://scripts/presentation/skier_visual.gd").new()
	root.add_child(skier); await process_frame
	var sim = Sim.new()
	var surface = preload("res://tests/physics_suite.gd").TestPlane.new(.30)
	sim.reset(Vector3.ZERO); sim.prime_contacts(surface); sim.velocity = sim.support_basis().z*30.0
	skier.reset_animation(sim)
	var intent = MotionInput.new(); intent.tuck = 1.0
	var rows = []
	for tick in 480:
		sim.step(1.0/120,intent,surface); skier.step_animation(1.0/120,sim,intent,surface)
		skier.pose(sim,1.0)
		if tick%60!=59: continue
		var f = skier.animation.full_motion
		var raw = f.sample_clip("NAV_FAST_FWD_SPEED",f.clock,true)
		var source = {}; var angles = {}; var limits = {}; var globals = {}
		for i in f.library.names.size():
			var id = f.library.names[i]; var parent: int = f.library.parents[i]
			var v = Anatomy.vector(raw.q[i])
			angles[id] = [rad_to_deg(v.x),rad_to_deg(v.y),rad_to_deg(v.z)]
			var rotation = Basis(raw.q[i])
			globals[id] = globals[f.library.names[parent]]*rotation if parent>=0 else rotation
			source[id] = source[f.library.names[parent]]+globals[f.library.names[parent]]*(f.library.rest[i].origin-f.library.rest[parent].origin) if parent>=0 else raw.root
			v = Anatomy.vector(Anatomy.local_limit(id,rotation).get_rotation_quaternion())
			limits[id] = [rad_to_deg(v.x),rad_to_deg(v.y),rad_to_deg(v.z)]
		var row = {"seconds":(tick+1)/120.0,"weights":f.weights,"state":skier.animation.current,"angles":angles,"limited":limits,"source":{},"final":{},"rotations":{}}
		for id in source: row.source[id] = var_to_str(source[id])
		for id in skier.rendered_joints: row.final[id] = var_to_str(skier.rendered_joints[id])
		for id in skier.rendered_rotations: row.rotations[id] = var_to_str(skier.rendered_rotations[id].get_rotation_quaternion())
		rows.append(row)
	DirAccess.make_dir_recursive_absolute("res://artifacts/deep_tuck")
	preload("res://tests/test_report.gd").write("res://artifacts/deep_tuck/probe.json",JSON.stringify(rows,"\t"))
	skier.queue_free(); await process_frame; quit()

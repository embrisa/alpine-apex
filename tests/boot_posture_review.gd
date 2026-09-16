extends SceneTree
## Render final production poses close enough to inspect cuffs and pole clearance.
const Sim = preload("res://scripts/core/ski_simulation.gd")
var folder = "res://artifacts/boot_posture_correction/"
func _initialize(): call_deferred("run")
func run():
	var before = "--baseline" in OS.get_cmdline_user_args()
	var scene = Node3D.new(); root.add_child(scene)
	var large = "--4k" in OS.get_cmdline_user_args()
	root.size = Vector2i(3840,2160) if large else Vector2i(1440,900)
	var env = WorldEnvironment.new(); env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(.18,.22,.28)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(.85,.9,1); env.environment.ambient_light_energy = .8
	scene.add_child(env)
	var sun = DirectionalLight3D.new(); scene.add_child(sun); sun.rotation_degrees = Vector3(-40,-30,0); sun.light_energy = 1.4
	var camera = Camera3D.new(); scene.add_child(camera); camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	var visual = load(folder+"baseline/skier_visual.gd" if before else "res://scripts/presentation/skier_visual.gd").new()
	visual.preview_only = true; scene.add_child(visual); await process_frame
	if before: visual.animation.full_motion = load(folder+"baseline/skier_full_motion.gd").new()
	var output = folder+("before" if before else "after")+("_4k/" if large else "/"); DirAccess.make_dir_recursive_absolute(output)
	var rows = {}
	for scenario in ["glide","tuck","carve","hop"]:
		var sim = Sim.new(); var surface = preload("res://tests/physics_suite.gd").TestPlane.new(0)
		sim.reset(Vector3.ZERO); sim.prime_contacts(surface); sim.velocity = Vector3.BACK*25
		visual.reset_animation(sim)
		var intent = RiderInput.new(); intent.tuck = 1 if scenario=="tuck" else 0; intent.steer = .2 if scenario=="carve" else 0
		for tick in (110 if scenario=="hop" else 240):
			intent.jump_held = scenario=="hop" and tick<90; intent.jump = scenario=="hop" and tick==90
			sim.step(1.0/120,intent,surface); visual.step_animation(1.0/120,sim,intent,surface)
		visual.pose(sim); visual.global_transform = Transform3D.IDENTITY
		# Equipment world transforms were solved before the root is reset.
		var j = visual.rendered_joints; var r = visual.rendered_rotations
		rows[scenario] = {"joints":{},"poles":[],"cuff_flex":[]}
		for id in j: rows[scenario].joints[id] = [j[id].x,j[id].y,j[id].z]
		for i in 2:
			var prefix = "Right" if i==0 else "Left"
			var axis: Vector3 = r[prefix+"Foot"].transposed()*(j[prefix+"Leg"]-j[prefix+"Foot"]).normalized()
			rows[scenario].cuff_flex.append(rad_to_deg(atan2(axis.z,axis.y)))
			var grip: Vector3 = visual.poles[i].position; var tip: Vector3 = grip-visual.poles[i].basis.y*1.18
			rows[scenario].poles.append({"grip":[grip.x,grip.y,grip.z],"tip":[tip.x,tip.y,tip.z]})
		for view in ["side","front","rear","oblique","cuff"]:
			var center: Vector3 = j.Hips.lerp((j.LeftFoot+j.RightFoot)*.5,.35)
			camera.size = 2.25
			var direction: Vector3 = {"side":Vector3(3,0,0),"front":Vector3(0,.2,3),"rear":Vector3(0,.2,-3),"oblique":Vector3(3,1.2,3),"cuff":Vector3(3,.3,1.3)}[view]
			if view=="cuff": center = j.RightFoot+Vector3(0,.18,0); camera.size = .95
			camera.position = center+direction; camera.look_at(center)
			for f in 5: await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(output+scenario+"_"+view+".png")
	preload("res://tests/test_report.gd").write(output+"poses.json",JSON.stringify(rows,"\t"))
	scene.queue_free(); await process_frame; quit()

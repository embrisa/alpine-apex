extends SceneTree
## Production skier and solver on an explicit unranked visual fixture.
const Sim = preload("res://scripts/core/ski_simulation.gd")
const TestPlane = preload("res://tests/physics_suite.gd").TestPlane
const DT = 1.0 / 120.0
var skier
var camera: Camera3D
var world: Node3D
var output = "res://artifacts/hands_v1/native"
var captures: Array[String] = []
var failures: Array[String] = []

func _initialize(): call_deferred("run")

func run():
	if DisplayServer.get_name() == "headless": quit(2); return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--hand-label="): output += "_"+arg.trim_prefix("--hand-label=").validate_filename()
	output = ProjectSettings.globalize_path(output)
	assert(DirAccess.make_dir_recursive_absolute(output)==OK)
	print("HAND_OUTPUT ",output)
	root.size = Vector2i(1280,960)
	Engine.max_fps = 60
	world = Node3D.new(); root.add_child(world)
	var env = WorldEnvironment.new(); env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(.16,.19,.23)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(.78,.86,1.0)
	env.environment.ambient_light_energy = .65
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.add_child(env)
	for spec in [[Vector3(-42,-28,0),1.5],[Vector3(-30,145,0),.8]]:
		var light = DirectionalLight3D.new(); light.rotation_degrees = spec[0]
		light.light_energy = spec[1]; world.add_child(light)
	var floor_body = StaticBody3D.new(); var collision = CollisionShape3D.new()
	floor_body.collision_layer = 8; floor_body.collision_mask = 16
	collision.shape = WorldBoundaryShape3D.new(); floor_body.add_child(collision); world.add_child(floor_body)
	skier = preload("res://scripts/presentation/skier_visual.gd").new()
	world.add_child(skier); await process_frame
	if "--hands-baseline" in OS.get_cmdline_user_args():
		preload("res://tests/helpers/skier_hand_comparison.gd").apply(skier,true)
	camera = Camera3D.new(); world.add_child(camera); camera.near = .01; camera.far = 300
	camera.current = true
	for name in ["glide","tuck","turn_left","turn_right","jump","safety","mute","landing"]:
		var surface = TestPlane.new(0.0)
		var sim = Sim.new()
		var air = name in ["jump","safety","mute","landing"]
		sim.reset(Vector3(0,1.0 if name=="landing" else (12.0 if air else 0.0),0)); sim.prime_contacts(surface)
		sim.velocity = Vector3(0,-1 if name=="landing" else 0,18)
		if air: sim._begin_flight(sim.support_basis())
		sim.reset_pose_history(); skier.reset_animation(sim)
		skier.animation.full_motion.grab_style = "mute" if name=="mute" else "safety"
		var intent = RiderInput.new()
		intent.tuck = 1.0 if name=="tuck" else 0.0
		intent.steer = -.7 if name=="turn_left" else (.7 if name=="turn_right" else 0.0)
		intent.grab = name in ["safety","mute"]
		for tick in (190 if name=="landing" else (125 if air else 300)):
			sim.step(DT,intent,surface); skier.step_animation(DT,sim,intent,surface)
			if sim.crashed: failures.append(name+" unexpectedly crashed"); break
		skier.pose(sim)
		await inspect_pose(name)
		if name=="landing":
			sim.crash("HAND_VISUAL_FIXTURE"); skier.ragdoll.start(sim)
			for tick in 24: await physics_frame
			skier.ragdoll.set_frozen(true)
			for frame in 2: await process_frame
			skier.ragdoll.update_equipment()
			camera.projection = Camera3D.PROJECTION_PERSPECTIVE; camera.fov = 45
			var focus: Vector3 = skier.ragdoll.focus()
			camera.position = focus+Vector3(2,1.4,2.8); camera.look_at(focus)
			await capture("crash_body")
			for side in ["Left","Right"]:
				var frame: Transform3D = skier.ragdoll.bone_world(side+"Hand")
				camera.projection = Camera3D.PROJECTION_ORTHOGONAL; camera.size = .35
				camera.position = frame.origin+Vector3(.35,.25,.4); camera.look_at(frame.origin)
				await capture("crash_"+side)
	preload("res://tests/test_report.gd").write(output+"/report.json",JSON.stringify({
		"captures":captures,"failures":failures,"bones":skier.skeleton.get_bone_count(),
		"unranked_fixture":true,"physics":Sim.MODEL_VERSION,
		"model_sha256":FileAccess.get_sha256("res://art_source/meshy/hands_v1/baseline/skier_v7.glb" if "--hands-baseline" in OS.get_cmdline_user_args() else "res://assets/graphics/models/skier_v7.glb"),
		"performance_acceptance":false},"\t"))
	print("HANDS_VISUAL_COMPLETE ",captures.size()," captures failures=",failures)
	world.queue_free(); await process_frame
	quit(0 if failures.is_empty() else 1)

func inspect_pose(name: String):
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE; camera.fov = 45
	var center: Vector3 = skier.to_global(Vector3(0,.8,0))
	camera.global_position = center+skier.global_basis*Vector3(1.5,.5,2.7)
	camera.look_at(center); await capture(name+"_body")
	for side in ["Left","Right"]:
		var sign_value = 1.0 if side=="Left" else -1.0
		var wrist: Vector3 = skier.rendered_joints[side+"Hand"]
		var rotation: Basis = skier.rendered_rotations[side+"Hand"]
		var focus: Vector3 = skier.to_global(wrist+rotation*Vector3(sign_value*.048,.005,.008))
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL; camera.size = .27
		for spec in [["back",Vector3(sign_value*.18,.20,.32)],["palm",Vector3(sign_value*.18,-.12,-.30)]]:
			camera.global_position = focus+skier.global_basis*rotation*spec[1]
			camera.look_at(focus,skier.global_basis*rotation*Vector3.UP)
			await capture(name+"_"+side+"_"+spec[0])

func capture(id: String):
	for frame in 4: await process_frame
	await RenderingServer.frame_post_draw
	var path = output+"/"+id+".png"
	assert(root.get_texture().get_image().save_png(path)==OK)
	assert(FileAccess.file_exists(path))
	captures.append(id)

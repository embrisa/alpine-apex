extends SceneTree
var failures: Array[String] = []
var checks: int = 0
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)
	print("PASS: " if value else "FAIL: ",label)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game = load("res://main.tscn").instantiate()
	game.automated = true
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.set_process(false)
	game.start_speed_lab(120)
	check(game.skier.skeleton.get_bone_count()==24,"Verified character rig is loaded")
	var original = [game.sim.position,game.sim.velocity,game.sim.heading,game.sim.balance,game.session.elapsed,game.session.eligible,game.session.course_id,hash(game.field.heights),hash(game.field.obstacles)]
	var material_count: int = game.world.cloud_lighting.materials.size()
	for level in [0,2,1,0,2,1]:
		game.set_graphics_quality(level)
		game.hud.graphics_quality.item_selected.emit(level)
		game.world.update_weather(game.weather.state,.1,false)
	var after = [game.sim.position,game.sim.velocity,game.sim.heading,game.sim.balance,game.session.elapsed,game.session.eligible,game.session.course_id,hash(game.field.heights),hash(game.field.obstacles)]
	check(original==after,"Graphics switching preserves simulation, course geometry, obstacles and records")
	check(game.world.cloud_lighting.materials.size()==material_count,"Repeated quality changes do not accumulate material registrations")
	check(game.world.scenery.obstacle_count==game.field.obstacles.size(),"Scenery consumes every existing obstacle without generating collisions")
	var families = game.world.scenery.family_counts
	var family_total = 0
	var complete_families = true
	for family in game.world.scenery.TREE_FAMILIES+game.world.scenery.ROCK_FAMILIES:
		complete_families = complete_families and families.get(family,0)>0
		family_total += families.get(family,0)
	check(complete_families and family_total==game.field.obstacles.size(),"Every tree and rock family appears, with exactly one visual per obstacle")
	var envelopes_valid = true
	var far_cards_valid = true
	for family in game.world.scenery.TREE_FAMILIES:
		if family=="spruce": continue
		for variant in [1,2,3,4]:
			for lod in [0,1]:
				var mesh: Mesh = game.world.assets.mesh("%s_%d_lod%d" % [family,variant,lod])
				var bounds = mesh.get_aabb()
				envelopes_valid = envelopes_valid and absf(bounds.end.y-10.5)<.05 and bounds.position.y>=-.3
			var card: Mesh = game.world.assets.mesh("%s_%d_lod2" % [family,variant])
			far_cards_valid = far_cards_valid and card.get_faces().size()==6
	check(envelopes_valid,"New standing tree LODs retain the shared collision-height envelope")
	check(far_cards_valid,"All new distant tree variants use bounded two-triangle silhouettes")
	check(game.graphics.level==1 and game.weather.quality==2,"Graphics and weather quality remain independent")
	check(game.world.sun.directional_shadow_max_distance==170.0,"Balanced applies its bounded shadow budget")
	var wind_before: float = game.world.assets.wind_time
	game.world.update_weather(game.weather.state,10.0,false)
	check(game.world.assets.wind_time==wind_before,"Paused foliage has no presentation-time drift")
	var finite_poses = true
	var constant_limbs = true
	for tuck in [0.0,.5,1.0]:
		for edge in [-.65,0.0,.65]:
			game.sim.effective_tuck = tuck
			game.sim.edge_angle = edge
			game.sim.landing_force = 3.0
			game.sim.body._pose(game.sim,1.0/120.0)
			game.sim.body.previous_joints = game.sim.body.joints.duplicate()
			game.sim.body.previous_rotations = game.sim.body.rotations.duplicate()
			game.skier.pose(game.sim)
			var skeleton: Skeleton3D = game.skier.skeleton
			for i in range(skeleton.get_bone_count()):
				var transform_value = skeleton.get_bone_global_pose(i)
				finite_poses = finite_poses and transform_value.origin.is_finite() and transform_value.basis.is_finite() and absf(transform_value.basis.determinant()-1.0)<.01
			for side in ["Left","Right"]:
				for pair in [["UpLeg","Leg"],["Leg","Foot"],["Arm","ForeArm"],["ForeArm","Hand"]]:
					var a = skeleton.find_bone(side+pair[0])
					var b = skeleton.find_bone(side+pair[1])
					var expected = skeleton.get_bone_global_rest(a).origin.distance_to(skeleton.get_bone_global_rest(b).origin)
					var actual = skeleton.get_bone_global_pose(a).origin.distance_to(skeleton.get_bone_global_pose(b).origin)
					constant_limbs = constant_limbs and absf(expected-actual)<.002
	check(finite_poses,"Tuck, carving and compression keep every joint finite and unscaled")
	check(constant_limbs,"Limb targets preserve anatomical segment lengths through skiing poses")
	game.camera.close_view = true
	game._process(.016)
	check(not game.skier.body_pivot.visible and game.skier.skis[0].visible,"First person hides the body and retains real ski equipment")
	game.camera.close_view = false
	game.restart()
	check(game.graphics.level==1 and not game.session.eligible,"Restart retains graphics quality and stays unranked in tests")
	check(game.effects.track_cursor==0,"Restart clears the bounded track ring")
	_snow_effect_checks(game)
	var result = {"checks":checks,"failures":failures}
	FileAccess.open("res://artifacts/graphics_results.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("GRAPHICS_RESULTS ",JSON.stringify(result))
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

func _snow_effect_checks(game) -> void:
	var stamps = game.effects.snow_tracks
	var field = game.field
	var sim = game.sim
	sim.reset(Vector3(0,field.sample(0,500).height,500))
	sim.surface_normal = field.contact_normal(0,500)
	sim.ski_forward = Vector3.DOWN.slide(sim.surface_normal).normalized()
	sim.snow_penetration = 0.04
	stamps.reset()
	stamps.update_contact(sim,field,sim.position,true)
	var endpoint = sim.position+sim.ski_forward*3.0
	stamps.update_contact(sim,field,endpoint,true)
	check(stamps.written==8,"A three-metre render step produces four continuous paired ski segments")
	var conforming = true
	for i in range(stamps.written):
		var transform_value: Transform3D = stamps.tracks.get_instance_transform(i)
		var heights: Color = stamps.tracks.get_instance_custom_data(i)
		var offsets = [heights.r,heights.g,heights.b,heights.a]
		var corner = 0
		for end in [-0.5,0.5]:
			for side in [-0.5,0.5]:
				var p: Vector3 = transform_value*Vector3(side,0,end)
				conforming = conforming and absf(p.y+offsets[corner]-field.sample(p.x,p.z).height)<0.001
				corner += 1
	# The dummy renderer returns empty MultiMesh readback; check GPU instance
	# corner data in the native suite, alongside the rendered snow playtest.
	if DisplayServer.get_name()!="headless":
		check(conforming,"Every imprint corner follows the actual contact heightfield")
	var count: int = stamps.written
	stamps.update_contact(sim,field,endpoint,true)
	check(stamps.written==count,"Stationary rendering cannot stamp extra snow")
	sim.grounded = false
	stamps.update_contact(sim,field,endpoint+Vector3(0,3,5),true)
	sim.grounded = true
	stamps.update_contact(sim,field,endpoint+Vector3(0,0,7),true)
	check(stamps.written==count,"An airborne gap and landing never bridge a floating track")
	stamps.update_contact(sim,field,endpoint+Vector3(0,0,50),true)
	check(stamps.written==count,"Teleporting breaks track history without a stretched imprint")
	stamps.update_contact(sim,field,endpoint,false)
	check(stamps.written==count and not stamps.last_position.is_finite(),"Inactive play freezes impressions and breaks contact history")
	stamps.reset()
	for step in range(410):
		var p = Vector3(0,0,500.0+step)
		p.y = field.sample(p.x,p.z).height
		stamps.update_contact(sim,field,p,true)
	check(stamps.written==800 and stamps.tracks.instance_count==800,"Long tracks wrap within the fixed 800-instance allocation")
	var particles = 0
	for spray in game.effects.sprays: particles += spray.amount
	check(particles==380,"Powder and ice grains share the existing 380-particle budget")
	game.effects.update_effects(sim,field,sim.position,.016,false)
	var frozen = true
	for spray in game.effects.sprays: frozen = frozen and spray.speed_scale==0.0 and not spray.emitting
	check(frozen,"Pause freezes both particle layers and stops snow emission")
	stamps.reset()
	check(stamps.written==0 and stamps.tracks.visible_instance_count==0,"Restart hides all prior imprints, including a wrapped ring")

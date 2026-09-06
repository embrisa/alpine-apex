extends SceneTree
var failures: Array[String] = []
var checks = 0
func _initialize(): call_deferred("run")
func check(value, label):
 checks += 1
 if not value: failures.append(label)
 print("PASS: " if value else "FAIL: ",label)
func run():
 var floor_body = StaticBody3D.new()
 floor_body.collision_layer = 8
 floor_body.collision_mask = 16
 var collision = CollisionShape3D.new()
 var box = BoxShape3D.new()
 box.size = Vector3(500,1,500)
 collision.shape = box
 floor_body.add_child(collision)
 root.add_child(floor_body)
 floor_body.position.y = -.5
 var skier = preload("res://scripts/presentation/skier_visual.gd").new()
 root.add_child(skier)
 var sim = preload("res://scripts/core/ski_simulation.gd").new()
 var plane = preload("res://tests/physics_suite.gd").TestPlane.new(0)
 await process_frame
 sim.reset(Vector3(0,2,0))
 sim.prime_contacts(plane)
 sim.grounded = false
 var crash_kmh = 200.0 if "--crash-200" in OS.get_cmdline_user_args() else 150.0
 sim.velocity = Vector3(0,-4,crash_kmh/3.6)
 sim.body.roll_velocity = .7
 sim.body.pitch_velocity = -.35
 skier.pose(sim)
 var initial_joint = skier.skeleton.get_bone_global_pose(skier.bone_ids.Hips)
 sim.crash("TEST")
 skier.ragdoll.start(sim)
 check(skier.ragdoll.bodies.size()==15 and skier.ragdoll.simulator.is_simulating_physics(),"Crash activates fifteen physical segments")
 var mass = 0.0
 for id in skier.ragdoll.bodies: mass += skier.ragdoll.bodies[id].mass
 check(absf(mass-80.0)<.001,"Crash bodies preserve the simulated 80 kg rider mass")
 var momentum = Vector3.ZERO
 for id in skier.ragdoll.bodies:
  momentum += skier.ragdoll.bodies[id].linear_velocity*skier.ragdoll.bodies[id].mass
 check((momentum/mass).distance_to(sim.velocity)<.001,"Banking crash preserves total skier momentum at %d km/h"%crash_kmh)
 check(skier.ragdoll.bodies.LeftFoot.joint_type==PhysicalBone3D.JOINT_TYPE_HINGE and skier.ragdoll.bodies.RightFoot.joint_type==PhysicalBone3D.JOINT_TYPE_HINGE,"Both rigid boot cuffs retain a flexion hinge during a crash")
 var first = skier.ragdoll.focus()
 var min_height = INF
 var max_stretch = 0.0
 var stretches = {}
 var finite = true
 var max_cuff_side = 0.0
 var min_cuff_flex = INF
 var max_cuff_flex = -INF
 var max_binding_gap = 0.0
 var cuff_excursions = 0
 for tick in range(360):
  await physics_frame
  skier.ragdoll.update_equipment()
  for i in range(2):
   var prefix = "Right" if i==0 else "Left"
   var foot = skier.ragdoll.bone_world(prefix+"Foot")
   var boot = foot.basis*skier.rest[skier.bone_ids[prefix+"Foot"]].basis.inverse()
   var shin = (skier.ragdoll.bone_world(prefix+"Leg").origin-foot.origin).normalized()
   max_cuff_side = maxf(max_cuff_side,absf(rad_to_deg(atan2(shin.dot(boot.x),shin.dot(boot.y)))))
   var flex = rad_to_deg(atan2(shin.dot(boot.z),shin.dot(boot.y)))
   min_cuff_flex = minf(min_cuff_flex,flex)
   max_cuff_flex = maxf(max_cuff_flex,flex)
   if flex>40.0 or flex < -8.0: cuff_excursions += 1
   var expected_binding = foot*skier.ragdoll.equipment_offsets[i*2]
   max_binding_gap = maxf(max_binding_gap,expected_binding.origin.distance_to(skier.skis[i].global_position))
  for id in skier.ragdoll.bodies:
   var body = skier.ragdoll.bodies[id]
   min_height = minf(min_height,body.global_position.y)
   finite = finite and body.global_transform.is_finite() and body.linear_velocity.length()<150.0
   var index = skier.bone_ids[id]
   var parent = skier.skeleton.get_bone_parent(index)
   while parent>=0 and not skier.ragdoll.bodies.has(skier.skeleton.get_bone_name(parent)):
    parent = skier.skeleton.get_bone_parent(parent)
   if parent>=0:
    var parent_id = skier.skeleton.get_bone_name(parent)
    var expected = skier._origin(id).distance_to(skier._origin(parent_id))
    var actual = skier.ragdoll.bone_world(id).origin.distance_to(skier.ragdoll.bone_world(parent_id).origin)
    max_stretch = maxf(max_stretch,absf(actual-expected))
    stretches[id] = maxf(stretches.get(id,0.0),absf(actual-expected))

 check(skier.ragdoll.focus().z>first.z+10.0,"Ragdoll travels under Jolt instead of freezing at the crash point")
 check(finite and min_height>-.20,"High-speed crash remains finite and cannot tunnel through snow")
 check(max_stretch<.12,"Joint constraints retain a connected skeleton during impact")
 check(max_binding_gap<.0005,"Skis remain rigidly attached to the physical boots throughout a crash")
 # Jolt can exceed a limit briefly during a high-speed impact. Bound both
 # peak error and its duration, rather than asserting an exact rigid limit.
 check(max_cuff_side<25.0 and min_cuff_flex>-12.0 and max_cuff_flex<65.0 and cuff_excursions<15,"Crash cuff hinges prevent sustained side folding and hyperflexion")
 var paused = skier.ragdoll.focus()
 skier.ragdoll.set_frozen(true)
 for i in range(12): await physics_frame
 check(skier.ragdoll.focus().distance_to(paused)<.001,"Focus pause freezes the physical body")
 skier.ragdoll.stop()
 sim.reset(Vector3.ZERO)
 sim.prime_contacts(plane)
 skier.pose(sim)
 check(not skier.ragdoll.simulator.is_simulating_physics() and not skier.ragdoll.running,"Restart stops crash simulation and restores procedural control")
 check(not skier.ragdoll.bodies.RightFoot.has_node("SkiCollision"),"Restart removes temporary equipment collision")
 print("RAGDOLL_RESULTS ",JSON.stringify({"checks":checks,"failures":failures,"min_height":min_height,"max_joint_stretch_m":max_stretch,"stretches":stretches,"crash_kmh":crash_kmh,"cuff_side_deg":max_cuff_side,"cuff_flex_deg":[min_cuff_flex,max_cuff_flex],"cuff_excursions":cuff_excursions,"binding_gap_m":max_binding_gap}))
 skier.queue_free()
 floor_body.queue_free()
 await process_frame
 quit(0 if failures.is_empty() else 1)

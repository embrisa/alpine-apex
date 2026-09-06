extends SceneTree
## Hard steering must preserve a plausible cuff/shin relationship, not just bone lengths.
const Sim = preload("res://scripts/core/ski_simulation.gd")
const TestPlane = preload("res://tests/physics_suite.gd").TestPlane
const CrossSlope = preload("res://tests/physics_suite.gd").CrossSlope
var skier
var checks = 0
var failures: Array[String] = []
var metrics = {"ankle_roll_deg":0.0,"ankle_flex_min_deg":INF,"ankle_flex_max_deg":-INF,"skin_twist_deg":0.0,"boot_gap_m":0.0,"edge_step_deg":0.0}
func _initialize(): call_deferred("run")
func check(value,label):
 checks += 1
 if not value: failures.append(label)
 print("PASS: " if value else "FAIL: ",label)
func inspect(sim,alpha):
 skier.pose(sim,alpha)
 skier.skeleton.force_update_all_bone_transforms()
 for i in range(2):
  var prefix = "Right" if i==0 else "Left"
  var knee = skier.skeleton.get_bone_global_pose(skier.bone_ids[prefix+"Leg"])
  var foot = skier.skeleton.get_bone_global_pose(skier.bone_ids[prefix+"Foot"])
  var shin = (knee.origin-foot.origin).normalized()
  var boot = skier.global_basis.transposed()*skier.skis[i].global_basis
  var local = boot.transposed()*shin
  metrics.ankle_roll_deg = maxf(metrics.ankle_roll_deg,absf(rad_to_deg(atan2(local.x,local.y))))
  metrics.ankle_flex_min_deg = minf(metrics.ankle_flex_min_deg,rad_to_deg(atan2(local.z,local.y)))
  metrics.ankle_flex_max_deg = maxf(metrics.ankle_flex_max_deg,rad_to_deg(atan2(local.z,local.y)))
  var deformation = knee.basis*skier.rest[skier.bone_ids[prefix+"Leg"]].basis.inverse()
  var side_axis = (deformation*Vector3.RIGHT).slide(shin).normalized()
  metrics.skin_twist_deg = maxf(metrics.skin_twist_deg,rad_to_deg(side_axis.angle_to(boot.x.slide(shin).normalized())))
  var expected = skier.skis[i].global_transform*Vector3(0,.095+skier._origin(prefix+"Foot").y,-.15)
  metrics.boot_gap_m = maxf(metrics.boot_gap_m,expected.distance_to(skier.skeleton.to_global(foot.origin)))
func run():
 skier = preload("res://scripts/presentation/skier_visual.gd").new()
 root.add_child(skier)
 await process_frame
 # A cuff angle limit alone still allows a bow-legged crouch. Inspect the
 # rendered knees through the ordinary stance range in each boot's frame.
 for tuck in [0.0,.5,1.0]:
  var stance_sim = Sim.new()
  var stance_surface = TestPlane.new(.46)
  stance_sim.reset(Vector3.ZERO)
  stance_sim.prime_contacts(stance_surface)
  stance_sim.velocity = Vector3.BACK.slide(stance_sim.surface_normal).normalized()*30/3.6
  var stance_intent = RiderInput.new()
  stance_intent.tuck = tuck
  for tick in range(120): stance_sim.step(1.0/120,stance_intent,stance_surface)
  inspect(stance_sim,1.0)
  var tracking = 0.0
  for i in range(2):
   var prefix = "Right" if i==0 else "Left"
   var knee = skier.skeleton.get_bone_global_pose(skier.bone_ids[prefix+"Leg"]).origin
   var ankle = skier.skeleton.get_bone_global_pose(skier.bone_ids[prefix+"Foot"]).origin
   var boot = skier.global_basis.transposed()*skier.skis[i].global_basis
   tracking = maxf(tracking,absf((boot.transposed()*(knee-ankle)).x))
  check(tracking<.01,"Tuck %s keeps both knees within 1 cm of the boot centerlines"%tuck)
 for speed in [0,30,90,150,200]:
  for turn in [-1.0,1.0]:
   var sim = Sim.new()
   var surface = TestPlane.new(.46)
   sim.reset(Vector3.ZERO)
   sim.prime_contacts(surface)
   sim.velocity = Vector3.BACK.slide(sim.surface_normal).normalized()*speed/3.6
   var intent = RiderInput.new()
   var early_edge = 0.0
   var banked_edge = 0.0
   var hips_follow = false
   for tick in range(240):
    intent.steer = turn if tick<120 else -turn
    intent.tuck = 1.0 if tick>150 else 0.0
    var edges = [sim.skis[0].edge_angle,sim.skis[1].edge_angle]
    sim.step(1.0/120,intent,surface)
    if sim.crashed: break
    for i in range(2): metrics.edge_step_deg = maxf(metrics.edge_step_deg,absf(rad_to_deg(sim.skis[i].edge_angle-edges[i])))
    if tick==10: early_edge = absf(sim.skis[0].edge_angle)
    if tick==100:
     banked_edge = absf(sim.skis[0].edge_angle)
     hips_follow = sim.body.joints.Hips.x*turn<-.012
    for alpha in [0.0,.5,1.0]: inspect(sim,alpha)
   check(hips_follow and banked_edge>early_edge,"At %s km/h, turn %s builds edge with hip/torso lean"%[speed,turn])
   check(sim.ticks>=120,"At %s km/h, turn %s completes the sustained hard-turn fixture"%[speed,turn])
 var sim = Sim.new()
 var surface = CrossSlope.new()
 sim.reset(Vector3.ZERO)
 sim.prime_contacts(surface)
 sim.velocity = Vector3.BACK.slide(sim.surface_normal).normalized()*90/3.6
 var intent = RiderInput.new()
 for tick in range(120):
  intent.steer = .6*sin(tick*.04)
  intent.tuck = .5
  sim.step(1.0/120,intent,surface)
  if sim.crashed: break
  for alpha in [0.0,.5,1.0]: inspect(sim,alpha)
 check(not sim.crashed,"Cross-slope turns retain physical balance")
 # Real terrain also exercises the extreme lean immediately before crash
 # handoff. Keeping lengths alone was insufficient at this point.
 for turn in [-1.0,1.0]:
  var mountain = preload("res://scripts/world/test_slope.gd").new()
  sim = Sim.new()
  sim.reset(Vector3(0,mountain.sample(0,500).height,500))
  sim.prime_contacts(mountain)
  sim.velocity = Vector3.BACK.slide(sim.surface_normal).normalized()*30/3.6
  intent = RiderInput.new()
  for tick in range(240):
   intent.steer = turn if tick<120 else -turn
   sim.step(1.0/120,intent,mountain)
   for alpha in [0.0,.5,1.0]: inspect(sim,alpha)
   if sim.crashed: break
  check(sim.ticks>=150,"Mountain reversal %s tests cuff limits through deep lean and crash handoff"%turn)
 check(metrics.ankle_roll_deg<12.0,"Hard turns/reversals keep sideways cuff-to-shin bend below 12 degrees")
 check(metrics.ankle_flex_min_deg>-5.0 and metrics.ankle_flex_max_deg<40.0,"Knees flex forwards above the cuffs without ankle hyperextension")
 check(metrics.skin_twist_deg<.05,"Shin skin follows the boot hinge axis instead of twisting at the cuff")
 check(metrics.boot_gap_m<.0005,"Anatomical turning retains the previous sub-millimetre boot attachment")
 check(metrics.edge_step_deg<3.0,"Rapid left/right reversal cannot snap an edge between physics ticks")
 # Transporting support coordinates must not instantaneously rotate the body in world space.
 sim.reset(Vector3.ZERO)
 sim.prime_contacts(TestPlane.new(0))
 sim.body.roll = .2
 sim.body.pitch = -.1
 var up = (Basis(Vector3.BACK,sim.body.roll)*Basis(Vector3.RIGHT,sim.body.pitch)).y
 sim.surface_normal = Vector3(.2,1,.3).normalized()
 sim.body.step(.0000001,sim,RiderInput.new(),Vector3.ZERO)
 var world_up = sim.support_basis()*(Basis(Vector3.BACK,sim.body.roll)*Basis(Vector3.RIGHT,sim.body.pitch)).y
 check(up.distance_to(world_up)<.00001,"A changed support frame preserves world lean without injecting a false tip")
 print("TURN_ANATOMY_RESULTS ",JSON.stringify({"checks":checks,"failures":failures,"metrics":metrics}))
 skier.queue_free()
 await process_frame
 quit(0 if failures.is_empty() else 1)

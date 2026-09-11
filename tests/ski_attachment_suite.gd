extends SceneTree
## Attachment and interpolation contracts, including the rendered skeleton pose.
const Sim = preload("res://scripts/core/ski_simulation.gd")
const Intent = preload("res://scripts/core/rider_input.gd")
const TestPlane = preload("res://tests/physics_suite.gd").TestPlane
const CrossSlope = preload("res://tests/physics_suite.gd").CrossSlope
const SplitSurface = preload("res://tests/skier_motion_suite.gd").SplitSurface
const Terrain = preload("res://scripts/world/test_slope.gd")
const DT = 1.0/120.0
var skier
var checks = 0
var failures: Array[String] = []
var metrics = {"ankle_gap_m":0.0,"leg_length_error_m":0.0,"hip_gap_m":0.0,"rotation_error_rad":0.0,"rendered_gap_m":0.0}
var measuring = false
func _initialize(): call_deferred("run")
func check(value,label):
 checks += 1
 if not value: failures.append(label)
 print("PASS: " if value else "FAIL: ",label)
func foot_gap():
 var gap = 0.0
 for i in range(2):
  var id = "RightFoot" if i==0 else "LeftFoot"
  var foot = skier.skeleton.global_transform*skier.skeleton.get_bone_global_pose(skier.bone_ids[id])
  var ankle = skier.skis[i].get_child(1).global_transform*Vector3(0,skier._origin(id).y,0)
  gap = maxf(gap,foot.origin.distance_to(ankle))
 return gap
func rendered():
 if measuring: metrics.rendered_gap_m = maxf(metrics.rendered_gap_m,foot_gap())
func inspect_pose(sim,alpha):
 skier.pose(sim,alpha)
 skier.skeleton.force_update_all_bone_transforms()
 metrics.ankle_gap_m = maxf(metrics.ankle_gap_m,foot_gap())
 for prefix in ["Right","Left"]:
  for pair in [["UpLeg","Leg"],["Leg","Foot"]]:
   var a = skier.skeleton.get_bone_global_pose(skier.bone_ids[prefix+pair[0]]).origin
   var b = skier.skeleton.get_bone_global_pose(skier.bone_ids[prefix+pair[1]]).origin
   var expected = skier._origin(prefix+pair[0]).distance_to(skier._origin(prefix+pair[1]))
   metrics.leg_length_error_m = maxf(metrics.leg_length_error_m,absf(a.distance_to(b)-expected))
  var hips = skier.skeleton.get_bone_global_pose(skier.bone_ids.Hips)*skier.rest[skier.bone_ids.Hips].affine_inverse()
  var hip = skier.skeleton.get_bone_global_pose(skier.bone_ids[prefix+"UpLeg"]).origin
  metrics.hip_gap_m = maxf(metrics.hip_gap_m,hip.distance_to(hips*skier._origin(prefix+"UpLeg")))
  var foot = skier.skeleton.global_basis*skier.skeleton.get_bone_global_pose(skier.bone_ids[prefix+"Foot"]).basis*skier.rest[skier.bone_ids[prefix+"Foot"]].basis.inverse()
  var ski = skier.skis[0 if prefix=="Right" else 1].global_basis
  metrics.rotation_error_rad = maxf(metrics.rotation_error_rad,foot.y.angle_to(ski.y))
func run():
 skier = preload("res://scripts/presentation/skier_visual.gd").new()
 root.add_child(skier)
 await process_frame
 skier.skeleton.skeleton_updated.connect(rendered)
 var intent = Intent.new()
 intent.tuck = 1.0
 var last_sim
 for surface in [TestPlane.new(0),TestPlane.new(.46),CrossSlope.new(),Terrain.new()]:
  var sim = Sim.new()
  var z = 500.0 if surface is Terrain else 0.0
  sim.reset(Vector3(0,surface.sample(0,z).height,z))
  sim.prime_contacts(surface)
  check(sim.body.previous_pose_frame==sim.body.pose_frame,"Spawn starts with one complete pose frame")
  sim.velocity = Vector3.BACK.slide(sim.surface_normal).normalized()*200/3.6
  var state_unchanged = true
  for tick in range(240):
   intent.steer = sin(tick*.012)*.04
   sim.step(DT,intent,surface)
   var state = [sim.position,sim.velocity,sim.body.joints.duplicate(),sim.body.rotations.duplicate(),sim.body.com,sim.body.roll,sim.body.hand_velocities.duplicate()]
   for alpha in [0.0,.17,.5,.83,1.0]: inspect_pose(sim,alpha)
   state_unchanged = state_unchanged and state==[sim.position,sim.velocity,sim.body.joints,sim.body.rotations,sim.body.com,sim.body.roll,sim.body.hand_velocities]
  check(not sim.crashed,"High-speed attachment route finishes without a crash")
  check(state_unchanged,"Interpolated leg closure cannot change simulation state")
  last_sim = sim
 # An uneven platform exercises different ski heights, followed by an actual hop.
 var split = SplitSurface.new()
 split.gap = .16
 var uneven = Sim.new()
 uneven.reset(Vector3.ZERO)
 uneven.prime_contacts(split)
 uneven.velocity = Vector3.BACK*12
 intent = Intent.new()
 for tick in range(60):
  intent.jump = tick==20
  uneven.step(DT,intent,split)
  for alpha in [0.0,.5,1.0]: inspect_pose(uneven,alpha)
 check(uneven.total_airtime>0,"Unequal supports and hop exercise airborne attachment")
 # A stopped run must ignore the cycling global interpolation clock entirely.
 measuring = true
 skier.pose(last_sim)
 var stopped = [skier.global_transform,skier.skis[0].global_transform,skier.skis[1].global_transform,skier.desired.duplicate()]
 var frozen = true
 for frame in range(24):
  skier.pose(last_sim)
  await process_frame
  frozen = frozen and stopped==[skier.global_transform,skier.skis[0].global_transform,skier.skis[1].global_transform,skier.desired]
 check(frozen,"Paused high-speed skis and skeleton stay completely frozen")
 for alpha in [0.0,.25,.75,1.0]:
  inspect_pose(last_sim,alpha)
  await process_frame
 var root_frame = last_sim.body.previous_pose_frame.interpolate_with(last_sim.body.pose_frame,.25)
 skier.pose(last_sim,.25)
 check(skier.global_position.distance_to(root_frame.origin)<.0001 and skier.global_basis.is_equal_approx(root_frame.basis),"Root translation and support rotation share the joints' timestamp")
 last_sim.reset(Vector3(40,0,-200))
 last_sim.prime_contacts(TestPlane.new(0))
 for alpha in [0.0,.5,1.0]: inspect_pose(last_sim,alpha)
 check(skier.global_position.distance_to(last_sim.position)<.0001,"Restart discards the old high-speed interpolation history")
 check(metrics.ankle_gap_m<.0005 and metrics.rendered_gap_m<.0005,"Both actual foot bones stay within 0.5 mm of the rigid boots")
 check(metrics.leg_length_error_m<.0005,"Closing the rendered legs preserves thigh and shin lengths")
 check(metrics.hip_gap_m<.0005,"Both thighs remain attached to the same pelvis")
 check(metrics.rotation_error_rad<.001,"Foot skin and rigid boots share orientation through edging")
 print("SKI_ATTACHMENT_RESULTS ",JSON.stringify({"checks":checks,"failures":failures,"metrics":metrics}))
 skier.queue_free()
 await process_frame
 quit(0 if failures.is_empty() else 1)

extends SceneTree
## Authoritative articulation/contact invariants, separate from visual feel.
const Sim = preload("res://scripts/core/ski_simulation.gd")
const Intent = preload("res://scripts/core/rider_input.gd")
const TestPlane = preload("res://tests/physics_suite.gd").TestPlane
var failures: Array[String] = []
var checks = 0
var skier
class SplitSurface extends RefCounted:
 var gap = .5
 func sample(x,z): return {"height":0.0 if x<0 else -gap,"normal":Vector3.UP}
 func sweep_obstacle(_a,_b): return ""
 func snow_depth_at(x,_z): return .12 if x<0 else .01
func _initialize(): call_deferred("run")
func check(value,label):
 checks += 1
 if not value: failures.append(label)
 print("PASS: " if value else "FAIL: ",label)
func run():
 skier = preload("res://scripts/presentation/skier_visual.gd").new()
 root.add_child(skier)
 await process_frame
 var plane = TestPlane.new(0)
 var sim = Sim.new()
 var intent = Intent.new()
 sim.reset(Vector3.ZERO)
 # This checks tuck articulation, which now requires speed above pole pushing.
 sim.velocity = Vector3(0,0,20)
 sim.prime_contacts(plane)
 check(sim.contact_count==2 and absf(sim.skis[0].load_n-sim.skis[1].load_n)<1,"Flat stance shares support across both skis")
 var initial: Vector3 = sim.body.joints.LeftHand-sim.body.joints.LeftArm
 intent.tuck = 1
 sim.step(1.0/120.0,intent,plane)
 var first: Vector3 = sim.body.joints.LeftHand-sim.body.joints.LeftArm
 for i in range(240): sim.step(1.0/120.0,intent,plane)
 var settled: Vector3 = sim.body.joints.LeftHand-sim.body.joints.LeftArm
 check(first.distance_to(initial)<.025 and settled.distance_to(initial)>.12,"120 Hz hands ease into the tuck without a rigid snap")
 var back: Vector3 = sim.body.joints.Spine-sim.body.joints.Hips
 var lumbar: float = sim.body.rotations.Hips.get_rotation_quaternion().angle_to(sim.body.rotations.Spine.get_rotation_quaternion())
 check(back.angle_to(Vector3.UP)<.56 and lumbar<.16,"Deep tuck preserves the straight back and small lumbar bend")
 var poses = sim.body.joints.duplicate()
 var state = [sim.position,sim.velocity,sim.ticks,sim.body.roll,sim.body.hand_velocities.duplicate()]
 for i in range(100): skier.pose(sim)
 check(poses==sim.body.joints and state==[sim.position,sim.velocity,sim.ticks,sim.body.roll,sim.body.hand_velocities],"Rendering cannot advance body balance, hands or ski physics")
 var invariant = true
 for fps in [30,60,144,240]:
  var other = Sim.new()
  other.reset(Vector3.ZERO)
  other.velocity = Vector3(0,0,20)
  other.prime_contacts(plane)
  for i in range(241):
   other.step(1.0/120.0,intent,plane)
   if i%maxi(1,120/fps)==0: skier.pose(other)
  invariant = invariant and other.body.joints==sim.body.joints and other.body.roll==sim.body.roll
 check(invariant,"Body and hand motion are identical across render schedules")
 var split = SplitSurface.new()
 sim.reset(Vector3.ZERO)
 sim.velocity = Vector3(0,0,12)
 sim.prime_contacts(split)
 sim.step(1.0/120.0,Intent.new(),split)
 check(sim.contact_count==1 and sim.skis[0].grounded and not sim.skis[1].grounded,"One ski can retain support while the other hangs beyond leg reach")
 check(sim.skis[0].load_n>600 and sim.skis[1].load_n==0 and sim.skis[1].grip_n==0,"Unsupported ski contributes no load or grip; supported ski carries the rider")
 check(sim.skis[1].penetration==0 and sim.skis[1].snow_drag==0,"Unsupported foot cannot generate snow drag or penetration")
 split.gap = .16
 sim.reset(Vector3.ZERO)
 sim.velocity = Vector3(0,0,12)
 sim.prime_contacts(split)
 sim.step(1.0/120.0,Intent.new(),split)
 check(sim.contact_count==2 and absf(sim.skis[0].position.y-sim.skis[1].position.y)>.15,"Reachable unequal heights produce two independent contact positions")
 check(sim.skis[0].penetration>sim.skis[1].penetration*2,"Each ski uses the snow depth at its own contact")
 var ankles = sim.body.joints.RightFoot.y-sim.body.joints.LeftFoot.y
 check(ankles>.13,"Foot IK follows the unequal supports")
 var lengths = true
 var hips_connected = true
 for i in range(120):
  intent.steer = sin(i*.035)*.6
  intent.tuck = .5+.5*sin(i*.05)
  sim.step(1.0/120.0,intent,split)
  for side in ["Right","Left"]:
   for pair in [["UpLeg","Leg"],["Leg","Foot"],["Arm","ForeArm"],["ForeArm","Hand"]]:
    var expected: float = sim.Body.REST[side+pair[0]].distance_to(sim.Body.REST[side+pair[1]])
    var actual: float = sim.body.joints[side+pair[0]].distance_to(sim.body.joints[side+pair[1]])
    lengths = lengths and absf(expected-actual)<.002
   var hip: Vector3 = sim.body.joints.Hips+sim.body.rotations.Hips*(sim.Body.REST[side+"UpLeg"]-sim.Body.REST.Hips)
   hips_connected = hips_connected and hip.distance_to(sim.body.joints[side+"UpLeg"])<.001
 check(lengths and hips_connected,"Articulation preserves segment lengths and one connected pelvis")
 var total = 0.0
 var computed = Vector3.ZERO
 for segment in sim.Body.SEGMENTS:
  total += segment[2]
  computed += (sim.body.joints[segment[0]]+sim.body.joints[segment[1]])*.5*segment[2]
 check(absf(total-1)<.00001 and computed.distance_to(sim.body.com)<.00001,"All fifteen body segments contribute to the physical centre of mass")
 check(sim.body.cop.x>=-.276 and sim.body.cop.x<=.276 and absf(sim.body.cop.y)<=.721,"Corrective pressure stays inside the supporting ski footprint")
 sim.reset(Vector3(0,20,0))
 sim.prime_contacts(plane)
 sim.grounded = false
 sim.body.roll_velocity = .3
 sim.body.pitch_velocity = .1
 var momentum: Vector2 = sim.body.inertia*Vector2(.3,.1)
 sim.tuning.landing_assist_enabled = false
 intent = Intent.new()
 intent.tuck = 1
 for i in range(60): sim.step(1.0/120.0,intent,plane)
 check(sim.body.angular_momentum.distance_to(momentum)<.001 and sim.contact_count==0,"Unassisted airborne tuck within anatomical limits conserves momentum without ground torque")
 sim.reset(Vector3.ZERO)
 sim.prime_contacts(plane)
 sim.body.roll = 1.4
 sim.step(1.0/120.0,Intent.new(),plane)
 check(not sim.crashed and sim.impacts.reserve==1.0,"Body tipping alone cannot cause a fall or spend impact reserve")
 var mats = skier.appearance.materials
 check(mats.Clothing!=null and mats.Helmet!=null and mats.Lens!=null and mats.Clothing!=mats.Helmet and mats.Helmet!=mats.Lens,"Clothing, helmet and lens have separate live material instances")
 var cloth_before = mats.Clothing.get_shader_parameter("surface_roughness")
 var helmet_before = mats.Helmet.get_shader_parameter("base_color")
 skier.appearance.change("Lens","roughness",.06,false)
 skier.appearance.change("Lens","tint",Color(.2,.5,1),false)
 check(mats.Lens.get_shader_parameter("surface_roughness")==.06 and cloth_before==mats.Clothing.get_shader_parameter("surface_roughness") and helmet_before==mats.Helmet.get_shader_parameter("base_color"),"Lens controls leave helmet and clothing unchanged")
 sim.reset(Vector3.ZERO)
 sim.prime_contacts(plane)
 skier.pose(sim)
 var grips = true
 for i in range(2):
  var prefix = "right" if i==0 else "left"
  grips = grips and skier.poles[i].global_position.distance_to(skier.pose_probe(prefix+"_hand"))<.001
 check(grips,"Pole handle origins remain locked to the glove grip frames")
 print("SKIER_MOTION_RESULTS ",JSON.stringify({"checks":checks,"failures":failures}))
 skier.queue_free()
 await process_frame
 quit(0 if failures.is_empty() else 1)

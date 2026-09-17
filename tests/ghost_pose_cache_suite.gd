extends SceneTree
## Production-rig equivalence through forward, reverse and replaced sample pairs.
const Pose=preload("res://scripts/presentation/ghost_pose.gd")
const Visual=preload("res://scripts/presentation/skier_visual.gd")
const Sim=preload("res://scripts/core/ski_simulation.gd")
const Surface=preload("res://tests/physics_suite.gd").TestPlane
const Response=preload("res://scripts/presentation/snow_response.gd")
const Writer=preload("res://scripts/presentation/skier_pose_writer.gd")
const BONES=Pose.BONES
const CONTACT_START=Pose.CONTACT_START
const CONTACT_WIDTH=Pose.CONTACT_WIDTH
var checks=0
var failures=[]
func _initialize()->void: run.call_deferred()
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok: failures.append(label);printerr("FAIL: ",label)
func run()->void:
 var source=Visual.new();source.preview_only=true;root.add_child(source)
 var candidate=Visual.new();candidate.preview_only=true;root.add_child(candidate)
 var reference=Visual.new();reference.preview_only=true;root.add_child(reference)
 var field=Surface.new(.3)
 var sim=Sim.new();sim.reset(Vector3.ZERO);sim.prime_contacts(field)
 sim.velocity=Vector3(0,0,18).slide(sim.surface_normal);sim.reset_pose_history();source.reset_animation(sim)
 var frames=[]
 for sample in 24:
  var intent=RiderInput.new();intent.steer=.5*sin(sample*.3);intent.tuck=float(sample%2)
  for tick in 6: sim.step(1.0/120.0,intent,field);source.step_animation(1.0/120.0,sim,intent,field)
  source.pose(sim,1.0);frames.append(Pose.capture(source,sim,field))
 var candidate_responses=[Response.new(),Response.new()]
 var reference_responses=[Response.new(),Response.new()]
 var sequence=range(23)+[23,4,5,1,0,12,11,20,21]
 for index in sequence:
  var a:PackedFloat32Array=frames[index]
  var b:PackedFloat32Array=frames[mini(index+1,23)]
  for weight in [0.0,.13,.5,.87,1.0]:
   Pose.apply(candidate,a,b,weight,candidate_responses)
   reference_apply(reference,a,b,weight,reference_responses)
   check(candidate.global_transform.is_equal_approx(reference.global_transform),"Root follows current interpolation")
   for i in candidate.desired.size():
    check(candidate.desired[i].is_equal_approx(reference.desired[i]),"Bone %d follows current interpolation" % i)
   for side in 2:
    check(candidate.skis[side].global_transform.is_equal_approx(reference.skis[side].global_transform),"Ski attachment preserved")
    check(candidate.poles[side].global_transform.is_equal_approx(reference.poles[side].global_transform),"Pole attachment preserved")
    var c=candidate_responses[side];var r=reference_responses[side]
    check(c.supported==r.supported and c.snow_contact==r.snow_contact and c.track_contact==r.track_contact and c.contact_position==r.contact_position and c.contact_forward==r.contact_forward and c.track_depth_m==r.track_depth_m,"Contact and rendered track fronts preserved")
   check(candidate.get_meta(&"ghost_pose_frames").size()==2,"Decoded cache retains only the current frame pair")
 var changed:PackedFloat32Array=frames[0].duplicate();changed[0]+=80.0
 Pose.apply(candidate,changed,changed,0.0,candidate_responses)
 reference_apply(reference,changed,changed,0.0,reference_responses)
 check(candidate.global_transform==reference.global_transform,"Replacement content cannot reuse stale root")
 Pose.apply(candidate,frames[0],frames[0],0.0,candidate_responses)
 reference_apply(reference,frames[0],frames[0],0.0,reference_responses)
 check(candidate.global_transform.is_equal_approx(reference.global_transform),"Retry restores the initial frame")
 source.queue_free();candidate.queue_free();reference.queue_free();await process_frame
 print("GHOST_POSE_CACHE_RESULTS ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)

# Retained exclusively as the differential reference for this cache.
static func reference_apply(visual, a: PackedFloat32Array, b: PackedFloat32Array, weight: float, responses: Array) -> void:
 visual.global_transform = Pose.transform_at(a,0).interpolate_with(Pose.transform_at(b,0),weight)
 visual.targets.clear()
 # Interpolate local rotations/positions hierarchically; a global blend would
 # shrink long limbs. The production writer remains the sole skeleton writer.
 for name_value in BONES:
  var index: int = visual.bone_ids[name_value]
  var slot = BONES.find(name_value)+1
  var local = Pose.transform_at(a,slot).interpolate_with(Pose.transform_at(b,slot),weight)
  var parent: int = visual.skeleton.get_bone_parent(index)
  visual.targets[index] = visual.targets[parent]*local if parent>=0 else local
 Writer.apply(visual.skeleton,visual.rest,visual.desired,visual.targets)
 for i in 2:
  var prefix = "Right" if i==0 else "Left"
  var foot_id: int = visual.bone_ids[prefix+"Foot"]
  var hand_id: int = visual.bone_ids[prefix+"Hand"]
  var foot_a = Pose.bone_global(a,visual,foot_id)
  var foot_b = Pose.bone_global(b,visual,foot_id)
  var hand_a = Pose.bone_global(a,visual,hand_id)
  var hand_b = Pose.bone_global(b,visual,hand_id)
  var ski_socket = (foot_a.affine_inverse()*Pose.transform_at(a,25+i)).interpolate_with(foot_b.affine_inverse()*Pose.transform_at(b,25+i),weight)
  var pole_socket = (hand_a.affine_inverse()*Pose.transform_at(a,27+i)).interpolate_with(hand_b.affine_inverse()*Pose.transform_at(b,27+i),weight)
  visual.skis[i].global_transform = visual.global_transform*visual.desired[foot_id]*ski_socket
  visual.poles[i].global_transform = visual.global_transform*visual.desired[hand_id]*pole_socket
  var start = CONTACT_START+i*CONTACT_WIDTH
  var response = responses[i]
  # Discrete support is left-continuous. Conservative interval gating avoids
  # projecting an airborne ski onto snow during takeoff/landing interpolation.
  response.supported = a[start]>.5 and (weight==0 or b[start]>.5)
  response.snow_contact = a[start+1]>.5 and (weight==0 or b[start+1]>.5)
  for pair in [["width_m",2],["contact_width_m",3],["depth_m",4],["slip",5],["crystal_density",6]]:
   response.set(pair[0],lerpf(a[start+pair[1]],b[start+pair[1]],weight))
  response.throw_world = Vector3(a[start+7],a[start+8],a[start+9]).lerp(Vector3(b[start+7],b[start+8],b[start+9]),weight)
  response.contact_position = visual.skis[i].global_position
  response.contact_forward = visual.skis[i].global_basis.z.normalized()
  response.track_contact = response.snow_contact
  response.track_depth_m = response.depth_m


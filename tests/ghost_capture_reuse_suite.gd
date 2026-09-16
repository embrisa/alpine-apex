extends SceneTree
## Compact production-rig checks for reusing a displayed ghost pose.
const Visual=preload("res://scripts/presentation/skier_visual.gd")
const Sim=preload("res://scripts/core/ski_simulation.gd")
const InputType=preload("res://scripts/core/rider_input.gd")
const Pose=preload("res://scripts/presentation/ghost_pose.gd")
const Surface=preload("res://tests/physics_suite.gd").TestPlane
const Response=preload("res://scripts/presentation/snow_response.gd")
var checks=0
var failures=[]
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures.append(label);printerr("FAIL: ",label)
func _initialize()->void:run.call_deferred()
func run()->void:
 var visual=Visual.new();visual.preview_only=true;root.add_child(visual)
 var mirror=Visual.new();mirror.preview_only=true;root.add_child(mirror)
 var field=Surface.new(.3);var sim=Sim.new();sim.reset(Vector3.ZERO);sim.prime_contacts(field)
 sim.velocity=Vector3(0,0,18).slide(sim.surface_normal);sim.reset_pose_history();visual.reset_animation(sim)
 check(visual.pose_tick==-1,"Reset invalidates cached rig")
 Pose.capture_completed(visual,sim,field)
 check(visual.pose_tick==sim.ticks,"First capture solves the current pose")
 var responses=[Response.new(),Response.new()]
 for sample in 30:
  var input=InputType.new();input.steer=.5*sin(sample*.3);input.tuck=float(sample%2)
  sim.step(1.0/120.0,input,field);visual.step_animation(1.0/120.0,sim,input,field);visual.pose(sim,.5)
  var tick=visual.pose_tick
  for advance in 2:sim.step(1.0/120.0,input,field);visual.step_animation(1.0/120.0,sim,input,field)
  var before=Pose.capture(visual,sim,field)
  var data=Pose.capture_completed(visual,sim,field)
  check(visual.pose_tick==tick and Pose.capture(visual,sim,field)==before,"Reuse never mutates the displayed rider")
  check(Pose.validate(data) and data.slice(7,Pose.CONTACT_START)==before.slice(7,Pose.CONTACT_START),"Recent local rig is preserved")
  check(Pose.transform_at(data,0).origin==sim.facing_pose.frame.origin,"Ghost root uses the current physical sample")
  Pose.apply(mirror,data,data,0.0,responses)
  for i in 2:
   var prefix="Right" if i==0 else "Left";var foot=mirror.bone_ids[prefix+"Foot"];var hand=mirror.bone_ids[prefix+"Hand"]
   var ankle=mirror.global_transform*mirror.desired[foot].origin
   var boot=mirror.skis[i].get_child(1).global_transform*Vector3(0,mirror.rest[foot].origin.y,0)
   var hand_pose=mirror.skeleton.get_bone_global_pose(hand)
   var rotation=hand_pose.basis*mirror.rest[hand].basis.inverse()
   var grip=mirror.skeleton.global_transform*(hand_pose.origin+rotation*Vector3(-.070 if i==0 else .070,0,.018))
   check(ankle.distance_to(boot)<.0001,"Reused ghost boots stay attached")
   check(grip.distance_to(mirror.poles[i].global_position)<.0001,"Reused ghost grips stay attached")
 for mode in ["stale","ground_change","switch_change","fraction","boundary","future"]:
  visual.pose(sim,.5)
  if mode=="stale":visual.pose_tick=sim.ticks-4
  if mode=="ground_change":visual.pose_grounded=not sim.grounded
  if mode=="switch_change":visual.pose_backward=not sim.facing_backward
  if mode=="future":visual.pose_tick=sim.ticks+2
  var fraction=.37 if mode=="fraction" else 1.0
  var data=Pose.capture_completed(visual,sim,field,fraction,mode!="boundary")
  check(visual.pose_tick==sim.ticks and visual.pose_fraction==fraction,"Fresh fallback "+mode)
  check(data==Pose.capture(visual,sim,field),"Fresh completed capture "+mode)
 visual.queue_free();mirror.queue_free();await process_frame
 print("GHOST_CAPTURE_REUSE_RESULTS ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)

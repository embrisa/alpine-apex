extends SceneTree
## Measure the final connected body in a gravity/heading frame. Comparing LEFT
## and RIGHT clip labels, or photographing relative to terrain up, misses this.
const Sim = preload("res://scripts/core/ski_simulation.gd")
const Visual = preload("res://scripts/presentation/skier_visual.gd")
const Replay = preload("res://scripts/racing/run_replay.gd")
const Slope = preload("res://tests/carve_entry_capture.gd").EntrySlope
const DT = 1.0/120.0
var failures: Array[String]=[]
var checks=0
func _initialize():call_deferred("run")
func check(ok: bool,description: String):
	checks+=1
	if not ok:failures.append(description)
	print("PASS: " if ok else "FAIL: ",description)
func silhouette(visual,sim) -> Vector2:
	var j=visual.rendered_joints
	var feet=(j.LeftFoot+j.RightFoot)*.5
	var heading=Basis(Vector3.UP,sim.heading)
	var body=heading.transposed()*visual.global_basis*(j.Spine-feet)
	var torso=heading.transposed()*visual.global_basis*visual.rendered_rotations.Spine.y
	# Using the full axis length remains well-defined in a deep forward tuck.
	return Vector2(asin(clampf(-body.normalized().x,-1,1)),asin(clampf(-torso.normalized().x,-1,1)))
func run():
	var output="res://artifacts/carve_entry/regression.json"
	var baseline=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
		if arg.begins_with("--baseline-motion="):baseline=arg.trim_prefix("--baseline-motion=")
	var visual=Visual.new();visual.preview_only=true;root.add_child(visual);await process_frame
	if not baseline.is_empty():visual.animation.full_motion=load(baseline).new()
	var results=[]
	for warmup in [.5,2.0]:
		for tuck in [0.0,1.0]:
			for ramp in [false,true]:
				for direction in [-1.0,1.0]:
					var sim=Sim.new();var control=Sim.new();var surface=Slope.new()
					for s in [sim,control]:s.reset(Vector3.ZERO);s.prime_contacts(surface);s.velocity=s.support_basis().z*25
					visual.reset_animation(sim)
					var input=RiderInput.new();input.tuck=tuck
					for tick in int(warmup/DT):
						sim.step(DT,input,surface);control.step(DT,input,surface);visual.step_animation(DT,sim,input,surface)
					visual.pose(sim);var initial=silhouette(visual,sim)
					var wrong=Vector2.ZERO;var same=true;var peak_step=0.0;var last=visual.rendered_joints.duplicate();var trace=[]
					for tick in 180:
						input.steer=direction*(minf((tick+1)/60.0,1.0)*.55 if ramp else 1.0) if tick<120 else 0.0
						sim.step(DT,input,surface);control.step(DT,input,surface);visual.step_animation(DT,sim,input,surface);visual.pose(sim)
						same=same and Replay.snapshot(sim.ticks*DT,sim)==Replay.snapshot(control.ticks*DT,control) and sim.body.com==control.body.com
						for bone in last:peak_step=maxf(peak_step,visual.rendered_joints[bone].distance_to(last[bone]))
						last=visual.rendered_joints.duplicate()
						var lean=silhouette(visual,sim)
						if tick<90:
							wrong.x=maxf(wrong.x,-direction*(lean.x-initial.x));wrong.y=maxf(wrong.y,-direction*(lean.y-initial.y))
						trace.append({"tick":sim.ticks,"steer":input.steer,"body_lateral_rad":lean.x,"torso_lateral_rad":lean.y})
					var name="phase=%.1f tuck=%.0f ramp=%s dir=%+.0f"%[warmup,tuck,ramp,direction]
					check(wrong.x<deg_to_rad(1.0),name+": no opposite whole-body entry beyond 1 degree of initial sway")
					check(wrong.y<deg_to_rad(1.0),name+": no opposite torso entry beyond 1 degree of initial sway")
					check(same and not sim.crashed,name+": physical/replay state unchanged")
					check(peak_step<.08,name+": connected pose continuous through entry and release")
					results.append({"name":name,"opposite_body_degrees":rad_to_deg(wrong.x),"opposite_torso_degrees":rad_to_deg(wrong.y),"peak_joint_step_m":peak_step,"trace":trace})
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"cases":results,"model":Sim.MODEL_VERSION},"\t"))
	print("CARVE_ENTRY ",checks," checks, ",failures.size()," failures")
	visual.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)

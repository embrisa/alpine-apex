extends SceneTree
## Steering selects the clip side; completed ski response owns bank and strength.
const Sim = preload("res://scripts/core/ski_simulation.gd")
const Visual = preload("res://scripts/presentation/skier_visual.gd")
const Replay = preload("res://scripts/racing/run_replay.gd")
const DirectionSlope = preload("res://tests/carve_direction_capture.gd").DirectionSlope
const DT = 1.0/120.0
var checks = 0
var failures: Array[String] = []

func _initialize(): call_deferred("run")

func check(ok: bool, message: String):
	checks += 1
	if not ok: failures.append(message)
	print("PASS: " if ok else "FAIL: ",message)

func steering(name: String, tick: int) -> float:
	# Build a real opposite edge before the cross-slope steering switch.
	# Do not depend on the old counterbank bug to manufacture this coverage.
	if tick<120 and name=="cross_right": return -.55
	if tick<120 and name=="cross_mirror_left": return .55
	if tick<60: return 0.0
	if name=="taps": return (.8 if int((tick-60)/12)%2==0 else -.8) if tick<300 else 0.0
	if name=="reversal":
		if tick<180: return .55
		if tick<240: return -.7 if int((tick-180)/16)%2==0 else .7
		return -.55 if tick<360 else 0.0
	return (-.55 if name.ends_with("left") else .55) if tick<420 else 0.0

func run():
	var output = "res://artifacts/carve_response/response.json"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
	var visual = Visual.new(); visual.preview_only=true; root.add_child(visual); await process_frame
	var cases = {}
	for name in ["left","right","cross_left","cross_right","cross_mirror_left","cross_mirror_right","reversal","taps"]:
		var sim = Sim.new(); var control = Sim.new(); var surface = DirectionSlope.new()
		if name.begins_with("cross"): surface.cross_gradient = -.22 if name.begins_with("cross_mirror") else .22
		for s in [sim,control]:
			s.reset(Vector3.ZERO); s.prime_contacts(surface); s.velocity=s.support_basis().z*25
		visual.reset_animation(sim)
		var wrong = 0; var wrong_release = 0; var early = 0; var banked = 0; var opposing_input = 0
		var physical_equal = true; var peak_step = 0.0; var last = {}; var trace = []
		for tick in 540:
			var intent = RiderInput.new(); intent.steer=steering(name,tick)
			sim.step(DT,intent,surface); control.step(DT,intent,surface)
			visual.step_animation(DT,sim,intent,surface); visual.pose(sim)
			physical_equal = physical_equal and Replay.snapshot(tick*DT,sim)==Replay.snapshot(tick*DT,control) and sim.body.com==control.body.com
			var load = 0.0; var edge = 0.0
			for ski in sim.skis:
				if ski.grounded:
					load+=maxf(0.0,ski.load_n); edge-=ski.edge_angle*maxf(0.0,ski.load_n)
			edge/=maxf(1.0,load)
			var left = 0.0; var right = 0.0; var total = 0.0
			for clip in visual.animation.full_motion.weights:
				var w: float = visual.animation.full_motion.weights[clip].weight
				total+=w
				if clip in ["NAV_MED_LEFT","NAV_SLOW_LEFT","NAV_FAST_LEFT_SPEED"]: left+=w
				if clip in ["NAV_MED_RIGHT","NAV_SLOW_RIGHT","NAV_FAST_RIGHT_SPEED"]: right+=w
			var balance = (right-left)/maxf(.00001,total)
			if sim.grounded:
				if intent.steer!=0.0 and balance*signf(intent.steer)<-.000001: wrong+=1
				if intent.steer==0.0 and balance*signf(edge)<-.000001: wrong_release+=1
			if sim.grounded and absf(edge)>.08:
				banked+=1
				if edge*intent.steer<0.0: opposing_input+=1
			if sim.grounded and absf(edge)<.035 and absf(balance)>.20: early+=1
			var j = visual.rendered_joints
			for bone in last: peak_step=maxf(peak_step,j[bone].distance_to(last[bone]))
			last=j.duplicate()
			var r = visual.rendered_rotations
			trace.append({"tick":tick+1,"input":intent.steer,"edge_rad":edge,"bank_rad":sim.body.roll,"clip_balance":balance,
				"chest_bank_rad":atan2(-r.Spine.y.x,r.Spine.y.y),"hands_m":j.LeftHand.distance_to(j.RightHand),
				"left_reach_m":j.LeftArm.distance_to(j.LeftHand),"right_reach_m":j.RightArm.distance_to(j.RightHand)})
		cases[name]={"wrong_clip_samples":wrong,"wrong_release_samples":wrong_release,"early_commit_samples":early,"banked_samples":banked,"opposing_input_samples":opposing_input,"peak_joint_step_m":peak_step,"trace":trace}
		check(physical_equal and not sim.crashed,name+": animation preserves the physical run")
		check(banked>60,name+": fixture contains loaded physical edging")
		check(wrong==0,name+": active steering never selects the opposite turn clip")
		check(wrong_release==0,name+": released steering follows the remaining loaded edge")
		check(early==0,name+": near-flat skis do not play a committed turn from input alone")
		check(peak_step<.08,name+": final connected joints remain continuous")
		if name in ["cross_right","cross_mirror_left","reversal","taps"]: check(opposing_input>12,name+": fixture exercises input opposing the existing edge")
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"cases":cases,"model":Sim.MODEL_VERSION},"\t"))
	print("CARVE_RESPONSE ",checks," checks, ",failures.size()," failures")
	visual.queue_free(); await process_frame; quit(0 if failures.is_empty() else 1)

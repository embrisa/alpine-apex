extends "res://tests/controller_input_playtest.gd"
## Chronological reproduction of IDEA-20260911-185650 using the production router.
var trace: Array = []
var sources: Dictionary = {}
var motion_script = ""
var motion_selected = false

func run() -> void:
	output = "res://artifacts/tuck_consistency/visual"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
		if argument.begins_with("--motion-script="): motion_script = argument.trim_prefix("--motion-script=")
	if DirAccess.dir_exists_absolute(output):
		push_error("Choose a new tuck capture output; previous evidence is preserved.")
		quit(2); return
	DirAccess.make_dir_recursive_absolute(output)
	for folder in ["scripts/core","scripts/presentation"]:
		DirAccess.make_dir_recursive_absolute(output+"/sources/"+folder)
		for file in DirAccess.get_files_at("res://"+folder):
			if file.get_extension()!="gd": continue
			var path = folder+"/"+file
			sources[path] = FileAccess.get_sha256("res://"+path)
			DirAccess.copy_absolute("res://"+path,output+"/sources/"+path)
	for path in ["tests/tuck_presentation_playtest.gd","tests/controller_input_playtest.gd","tests/controller_input_suite.gd",
		"assets/animation/steep_ski_motion.res","assets/graphics/models/skier_v7.glb","project.godot"]:
		sources[path] = FileAccess.get_sha256("res://"+path)
		if path.get_extension()=="gd":
			DirAccess.make_dir_recursive_absolute((output+"/sources/"+path).get_base_dir())
			DirAccess.copy_absolute("res://"+path,output+"/sources/"+path)
	await super.run()
	var stable = true
	for path in sources: stable = stable and sources[path]==FileAccess.get_sha256("res://"+path)
	preload("res://tests/test_report.gd").write(output+"/sources.json",JSON.stringify({"sources":sources,"stable":stable,"motion_script":motion_script},"\t"))
	if not stable:
		print("FAIL: Production source changed during tuck capture")
		quit(1)

func ride(label: String, x: float, y: float, frames: int, r2: float = 0.0) -> void:
	if not motion_selected:
		if not motion_script.is_empty():
			game.skier.animation.full_motion = load(motion_script).new()
			game.skier.reset_animation(game.sim)
		game.resume(); game.hud.hide()
		motion_selected = true
	for frame in frames:
		# Sample the production router synchronously, then use automation's
		# existing focus exemption while awaiting draw. Another app taking focus
		# must not silently pause this synthetic-input fixture at tick zero.
		game.automated = false
		caption.text = label
		Pad.axis(JOY_AXIS_LEFT_X,x); Pad.axis(JOY_AXIS_LEFT_Y,y)
		Pad.axis(JOY_AXIS_TRIGGER_LEFT,0.0); Pad.axis(JOY_AXIS_TRIGGER_RIGHT,r2)
		for tick in 2: game._physics_process(DT)
		game._process(1.0/60.0)
		game.skier.pose(game.sim,1.0) # One completed timestamp for paired evidence.
		var center: Vector3 = game.sim.position+Vector3.UP*.85
		var basis: Basis = game.sim.support_basis()
		observer.global_position = center+basis.x*4.5+basis.z*2.0+Vector3.UP*.65
		observer.look_at(center); observer.make_current()
		game.automated = true
		await process_frame
		assert(game.sim.ticks==(trace.size()+1)*2,"Tuck capture lost its fixed tick sequence")
		var full = game.skier.animation.full_motion
		trace.append({"frame":trace.size(),"label":label,"tick":game.sim.ticks,
			"tuck":game.sim.effective_tuck,"state":pack(game.skier.animation.current),
			"speed":game.sim.motion.speed_mps,"grounded":game.sim.grounded,
			"landing_age":full.landing_age,"downhill":full.downhill_amount,
			"action":pack(full.action_amount),"clips":full.weights.duplicate(true),
			"diagnostics":full.diagnostics.duplicate(),
			"joints":pack(game.skier.rendered_joints),
			"requested":pack(full.requested_joints),
			"rotations":pack(game.skier.rendered_rotations),
			"clearance_margin":game.skier.animation.clearance_margin(game.skier.rendered_joints,game.skier.global_transform),
			"root":pack(game.skier.global_transform),
			"camera":pack(observer.global_transform),
			"physical_position":pack(game.sim.position),
			"velocity":pack(game.sim.velocity),
			"input":pack({"tuck":game.intent.tuck,"steer":game.intent.steer,"brake":game.intent.brake}),
			"skis":[pack(game.skier.skis[0].global_transform),pack(game.skier.skis[1].global_transform)]})
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_jpg(output+"/frame_%04d.jpg"%(trace.size()-1),.92)

func capture(name: String) -> void:
	if motion_script.is_empty() and name in ["01_forward_tuck","03_tuck_resumes"]:
		var joints = game.skier.rendered_joints
		var rotations = game.skier.rendered_rotations
		var up: Vector3 = (rotations.LeftFoot.y+rotations.RightFoot.y).normalized()
		var forward: Vector3 = (rotations.LeftFoot.z+rotations.RightFoot.z).slide(up).normalized()
		var hip: float = (joints.Hips-(joints.LeftFoot+joints.RightFoot)*.5).dot(up)
		var pitch = rad_to_deg(atan2(rotations.Spine.y.dot(forward),rotations.Spine.y.dot(up)))
		if hip>=.60 or pitch<=55.0: failures.append(name+": full solver tuck lost its visible compression")
	await super.capture(name)
	preload("res://tests/test_report.gd").write(output+"/trace.json",JSON.stringify(trace,"\t"))

func pack(value):
	if value is Vector3: return [value.x,value.y,value.z]
	if value is Basis: return [pack(value.x),pack(value.y),pack(value.z)]
	if value is Transform3D: return {"origin":pack(value.origin),"basis":pack(value.basis)}
	if value is Dictionary:
		var result = {}; for key in value: result[key]=pack(value[key])
		return result
	if value is Array:
		var result = []; for item in value: result.append(pack(item))
		return result
	return value

extends SceneTree
const Sim = preload("res://scripts/core/ski_simulation.gd")
const Visual = preload("res://scripts/presentation/skier_visual.gd")
const PlaneSurface = preload("res://tests/skid_response_suite.gd").PlaneSurface
const DT = 1.0/120.0
var failures: Array[String] = []
var checks = 0
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var visual = Visual.new(); visual.preview_only = true; root.add_child(visual); await process_frame
	var rows: Array = []
	for command in [0.0, -.2, .2, 1.0]:
		for tuck in [0.0,1.0]:
			var sim = Sim.new(); var surface = PlaneSurface.new()
			sim.reset(Vector3.ZERO); sim.prime_contacts(surface); sim.velocity = sim.support_basis().z*25
			visual.reset_animation(sim)
			var intent = RiderInput.new(); intent.steer = command; intent.tuck = tuck
			for tick in 240:
				sim.step(DT,intent,surface); visual.step_animation(DT,sim,intent,surface); visual.pose(sim)
				if tick%30==29:
					var feet: Vector3 = (visual.rendered_joints.LeftFoot+visual.rendered_joints.RightFoot)*.5
					var native: Vector3 = visual.animation.full_motion.root_position
					var physical: Vector3 = sim.facing_pose.joints.Hips-feet
					var fitted: Vector3 = visual.rendered_joints.Hips-feet
					# Same segment fractions give a comparable visual mass centroid.
					# This measurement never enters the physical model.
					var visible_com = Vector3.ZERO
					for segment in sim.Body.SEGMENTS:
						visible_com += (visual.rendered_joints[segment[0]]+visual.rendered_joints[segment[1]])*.5*segment[2]
					visible_com -= feet
					rows.append({"steer":command,"tuck":tuck,"s":(tick+1)*DT,"source":[native.x,native.y,native.z],"physical":[physical.x,physical.y,physical.z],"fitted":[fitted.x,fitted.y,fitted.z],"com":[sim.body.com.x,sim.body.com.y,sim.body.com.z],"visible_com":[visible_com.x,visible_com.y,visible_com.z]})
	var suffix = "before" if "--before" in OS.get_cmdline_user_args() else "after"
	preload("res://tests/test_report.gd").write("res://artifacts/steering_response_v22/pelvis_"+suffix+".json",JSON.stringify(rows))
	print("PELVIS_SAMPLES ",rows.size())
	if suffix!="before":
		var neutral = sample(rows,0.0,0.0); var tuck = sample(rows,0.0,1.0)
		check(neutral.fitted[2]<-.05,"Neutral pelvis sits behind the bindings")
		check(tuck.fitted[1]<neutral.fitted[1]-.12,"Tuck lowers the final pelvis at least 12 cm instead of only folding the chest")
		check(tuck.fitted[2]<neutral.fitted[2]-.10,"Tuck moves the final pelvis at least 10 cm farther back")
		check(tuck.fitted[1]<tuck.physical[1]+.03,"Final tuck pelvis follows physical crouch within 3 cm vertically")
		check(tuck.visible_com[1]<neutral.visible_com[1]-.15 and tuck.visible_com[2]<neutral.visible_com[2],"Visible body mass moves down and back in tuck")
		for direction in [-.2,.2]:
			var carve = sample(rows,direction,0.0); var carve_tuck = sample(rows,direction,1.0)
			check(carve.fitted[1]<neutral.fitted[1]-.05 and carve.fitted[2]<neutral.fitted[2]-.015,"Carving sinks the pelvis down and back in direction "+str(direction))
			check(carve_tuck.fitted[1]<tuck.fitted[1]-.06,"Tuck retains supported lowering while carving "+str(direction))
	print("PELVIS_BALANCE ",checks," checks, ",failures.size()," failures")
	visual.queue_free(); await process_frame; quit(0 if failures.is_empty() else 1)

func sample(rows: Array, steer: float, tuck: float) -> Dictionary:
	for row in rows:
		if row.steer==steer and row.tuck==tuck and row.s==2.0: return row
	assert(false,"Missing pelvis fixture")
	return {}

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)
	print("PASS: " if ok else "FAIL: ",message)

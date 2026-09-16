extends SceneTree
## The retained script tracker is the independent oracle for the native batch.
const Full = preload("res://scripts/presentation/skier_full_motion.gd")
var failures: Array[String] = []
var checks = 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)

func _initialize() -> void:
	var reference = Full.new()
	var candidate = Full.new()
	reference.native_tracking_enabled = false
	if Full.native_tracker==null:
		print("SKIER_TRACKING_RESULTS ",JSON.stringify({"native_available":false,"skipped":"Platform uses the retained script tracker"}))
		quit(); return
	var maximum_rotation = 0.0
	var maximum_velocity = 0.0
	var updates = 0
	for name in Full.library.clips:
		for action in [Vector3.ZERO,Vector3(1,0,0),Vector3(0,1,0),Vector3(0,0,1),Vector3(.15,.35,.50)]:
			reference.current = reference.sample_clip("NAV_MED_FWD",.13).q
			candidate.current = reference.current.duplicate()
			reference.velocities.clear()
			for i in reference.current.size(): reference.velocities.append(Vector3.ZERO)
			candidate.velocities = reference.velocities.duplicate()
			var saved_previous = candidate.current.duplicate()
			var previous_value = saved_previous.duplicate()
			var rotation_error = 0.0
			var velocity_error = 0.0
			for tick in 120:
				var requested = reference.sample_clip(name,tick/120.0,true).q
				var saved_request = requested.duplicate()
				var carry = tick/119.0
				var before = reference.track_pose(requested,action,carry,carry,1.0/120.0)
				var after = candidate.track_pose(requested,action,carry,carry,1.0/120.0)
				check(requested==saved_request,"Input remains immutable")
				check(after.x<=160.001 and after.y<=12.0001 and before.x<=160.001 and before.y<=12.0001,"Tracker retains speed and acceleration limits")
				for i in reference.current.size():
					var a: Quaternion = reference.current[i]
					var b: Quaternion = candidate.current[i]
					rotation_error = maxf(rotation_error,minf((a-b).length(),(a+b).length()))
					velocity_error = maxf(velocity_error,reference.velocities[i].distance_to(candidate.velocities[i]))
					check(b.is_finite() and candidate.velocities[i].is_finite(),"Finite tracked state")
				updates += 1
			check(saved_previous==previous_value,"Tracker does not mutate saved interpolation history")
			check(rotation_error<.0001 and velocity_error<.005,name+" cumulative tracker error "+str(Vector2(rotation_error,velocity_error)))
			maximum_rotation = maxf(maximum_rotation,rotation_error)
			maximum_velocity = maxf(maximum_velocity,velocity_error)
	print("SKIER_TRACKING_RESULTS ",JSON.stringify({"native_available":true,"checks":checks,"failures":failures,"updates":updates,"max_quaternion_component_distance":maximum_rotation,"max_velocity_delta_rad_s":maximum_velocity}))
	quit(0 if failures.is_empty() else 1)

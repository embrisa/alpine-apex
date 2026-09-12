extends SceneTree
## Independent raw-asset oracle for the immutable sampling preparation.
const Full = preload("res://scripts/presentation/skier_full_motion.gd")
var checks = 0
var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)
	print("PASS: " if ok else "FAIL: ",message)

func _initialize() -> void:
	var motion = Full.new()
	var sample_count = 0
	var prepared_frames = 0
	for name in Full.library.clips:
		var clip: Dictionary = Full.library.clips[name]
		prepared_frames += clip.frames
		var equal = true
		for time in [-1.0,0.0,.5/60.0,1.0/60.0,.137,.73,clip.duration-.25,clip.duration-.001,clip.duration,clip.duration+.01,clip.duration*3.17]:
			for looping in [false,true]:
				var expected = reference_clip(clip,time,looping)
				var sampled = motion.sample_clip(name,time,looping)
				equal = equal and sampled==expected
				sample_count += 1
		check(equal,name+": decoded samples exactly match raw asset interpolation and seams")
		check(Full.prepared_clips[name].is_read_only() and Full.prepared_clips[name].rotations.is_read_only(),name+": shared preparation is read-only")
	var first = motion.sample_clip("NAV_MED_LEFT",.73)
	var original = first.duplicate(true)
	first.q[0] = Quaternion.IDENTITY; first.root = Vector3.INF
	check(Full.new().sample_clip("NAV_MED_LEFT",.73)==original,"Returned pose edits cannot contaminate another rider's source samples")
	check(motion.mirror_pose(motion.mirror_pose(original))==original,"Mirroring retains both signs and does not mutate shared source data")
	for id in Full.grip_chains:
		var chain: PackedInt32Array = Full.grip_chains[id]
		var continuous = Full.library.parents[chain[0]]==-1
		for i in range(1,chain.size()): continuous = continuous and Full.library.parents[chain[i]]==chain[i-1]
		check(continuous and Full.library.names[chain[-1]]==id.replace("Hand","ForeArm"),id+": grip evaluates the complete root-to-forearm ancestor chain")
	print("ANIMATION_CPU_RESULTS ",JSON.stringify({"checks":checks,"failures":failures,"raw_samples":sample_count,"prepared_frames":prepared_frames,"prepared_joint_samples":prepared_frames*Full.library.names.size(),"serialized_preparation_bytes":var_to_bytes(Full.prepared_clips).size()}))
	quit(0 if failures.is_empty() else 1)

func reference_clip(clip: Dictionary, time: float, looping: bool) -> Dictionary:
	var seam = minf(.25,clip.duration*.2)
	var t: float = clampf(time,0.0,clip.duration)
	if looping: t = seam+fposmod(time,maxf(.01,clip.duration-seam))
	var pose = raw(clip,t)
	if looping and t>clip.duration-seam:
		var other = raw(clip,t-(clip.duration-seam))
		var alpha = smoothstep(clip.duration-seam,clip.duration,t)
		for i in pose.q.size(): pose.q[i] = pose.q[i].slerp(other.q[i],alpha)
		pose.root = pose.root.lerp(other.root,alpha)
	return pose

func raw(clip: Dictionary, time: float) -> Dictionary:
	var cursor = clampf(time*60.0,0.0,clip.frames-1.0)
	var a = int(cursor); var b = mini(a+1,clip.frames-1); var f = cursor-a
	var count: int = Full.library.names.size()
	var values: PackedFloat32Array = clip.values
	var qs: Array[Quaternion] = []
	for i in count:
		var ai = (a*count+i)*7+3; var bi = (b*count+i)*7+3
		qs.append(Quaternion(values[ai],values[ai+1],values[ai+2],values[ai+3]).normalized().slerp(Quaternion(values[bi],values[bi+1],values[bi+2],values[bi+3]).normalized(),f))
	var ai = a*count*7; var bi = b*count*7
	return {"q":qs,"root":Vector3(values[ai],values[ai+1],values[ai+2]).lerp(Vector3(values[bi],values[bi+1],values[bi+2]),f)}

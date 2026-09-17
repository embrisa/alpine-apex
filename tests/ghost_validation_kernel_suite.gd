extends SceneTree
## Differential codec validation: production native helper versus script rules.
const Replay = preload("res://scripts/racing/run_replay.gd")
const Fixture = preload("res://tests/ghost_replay_fixture.gd")
var checks = 0
var failures: Array = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures.append(label); push_error(label)
func run() -> void:
	if Replay.native_validation==null:
		check(false,"This parity suite requires the newly built native validation kernel")
		quit(1); return
	var kernel=Replay.native_validation
	var identity=Replay.key("native-replay-validation-fixture")
	var recording=Fixture.replay(1.0,identity)
	var snapshots=recording.samples.duplicate()
	var poses=recording.presentation.duplicate()
	check(kernel.validate(snapshots,poses,recording.inputs,recording.tick_kinds),"Valid synthetic recording")
	var values=[NAN,INF,-INF,-10001.0,10001.0,-8.001,-8.0,8.0,8.001,-3.0001,-3.0,3.0,3.0001,-1.0001,-1.0,-.01,0.0,.009999,.01,.010001,.15,.5,.999999,1.0,1.00001,1.1,4.0,4.0001,PI,PI+.01,PI+.011]
	for type in 2:
		var base: PackedFloat32Array = recording.samples[0] if type==0 else recording.presentation[0]
		for index in base.size():
			for value in values:
				var changed=base.duplicate();changed[index]=value
				if type==0: snapshots[0]=changed
				else: poses[0]=changed
				var expected=Replay.valid_snapshot(changed) if type==0 else Replay.Pose.validate(changed)
				check(kernel.validate(snapshots,poses,recording.inputs,recording.tick_kinds)==expected,"Field parity type=%d index=%d value=%s" % [type,index,value])
			if type==0: snapshots[0]=base
			else: poses[0]=base
	# Quaternion and vector boundaries involve several components together.
	var rng=RandomNumberGenerator.new();rng.seed=31709
	for trial in 600:
		var changed: PackedFloat32Array=recording.presentation[0].duplicate()
		var slot=rng.randi_range(1,28)*7
		var axis=Vector3(rng.randf_range(-1,1),rng.randf_range(-1,1),rng.randf_range(-1,1)).normalized()
		var q=Quaternion(axis,rng.randf_range(-PI,PI))*sqrt(1.0+rng.randf_range(-.01001,.01001))
		changed[slot]=rng.randf_range(-8.01,8.01)
		changed[slot+3]=q.x;changed[slot+4]=q.y;changed[slot+5]=q.z;changed[slot+6]=q.w
		poses[0]=changed
		check(kernel.validate(snapshots,poses,recording.inputs,recording.tick_kinds)==Replay.Pose.validate(changed),"Combined pose boundary %d" % trial)
	poses[0]=recording.presentation[0]
	for field in Replay.INPUT_WIDTH:
		for value in values:
			var input=recording.inputs.duplicate();input[field]=value
			var actual: float=input[field]
			var expected=is_finite(actual) and actual<=1.0 and actual>=(-1.0 if field in [0,4,5,7] else 0.0) and (field not in [3,6,8] or actual in [0.0,1.0])
			check(kernel.validate(snapshots,poses,input,recording.tick_kinds)==expected,"Input parity field=%d value=%s" % [field,value])
	for value in [0,1,2,255]:
		var kinds=recording.tick_kinds.duplicate();kinds[0]=value
		check(kernel.validate(snapshots,poses,recording.inputs,kinds)==(value in [0,1]),"Tick kind %d" % value)
	check(not kernel.validate([],[],recording.inputs,recording.tick_kinds),"Reject empty frames")
	check(not kernel.validate([1,2],poses,recording.inputs,recording.tick_kinds),"Reject wrong frame type")
	check(not kernel.validate(snapshots,[PackedFloat32Array(),poses[1]],recording.inputs,recording.tick_kinds),"Reject wrong pose width")
	check(not kernel.validate(snapshots,poses,PackedFloat32Array(),recording.tick_kinds),"Reject input dimension mismatch")
	var bytes=recording.to_bytes()
	Replay.native_validation_enabled=false
	var reference=Replay.from_bytes(bytes,identity,1.0)
	Replay.native_validation_enabled=true
	var native=Replay.from_bytes(bytes,identity,1.0)
	check(native!=null and reference!=null and native.samples==reference.samples and native.presentation==reference.presentation and native.inputs==reference.inputs and native.sample_times==reference.sample_times and native.pose_times==reference.pose_times,"Whole decode preserves payload arrays and exact clocks")
	# Numeric shape cannot authorize a crash mask that contradicts its intervals.
	recording.tick_kinds[0]=1
	check(Replay.from_bytes(recording.to_bytes(),identity,1.0)==null,"Native validation retains semantic crash cross-check")
	print("GHOST_VALIDATION_KERNEL_RESULTS ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)

extends SceneTree
const Replay = preload("res://scripts/racing/run_replay.gd")
const Pose = preload("res://scripts/presentation/ghost_pose.gd")
const Simulation = preload("res://scripts/core/ski_simulation.gd")
const Recovery = preload("res://scripts/core/crash_recovery.gd")
const CoreFixtures = preload("res://tests/crash_recovery_suite.gd")
const DT = 1.0/120.0
var checks = 0
var failures: Array[String] = []
var clock_round_trips: Array = []

func _initialize() -> void: call_deferred("run")

func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)
	print("PASS: " if value else "FAIL: ",label)

func _pose(sim) -> PackedFloat32Array:
	# Codec fixture, not a claim of a production rendered pose. Native lifecycle
	# harness captures the real skeleton/equipment and tests saved playback.
	var data = PackedFloat32Array()
	for i in Pose.TRANSFORMS:
		Pose.append_transform(data,Transform3D(Basis.IDENTITY,sim.position if i==0 else Vector3.ZERO))
	for i in 2: data.append_array(PackedFloat32Array([1,1,.15,.15,.02,0,1,0,0,0]))
	data.append(2.1)
	return data

func _record(crashes: int, inactive_ticks: int = 12):
	var field = CoreFixtures.Fixture.new()
	var sim = Simulation.new(preload("res://config/ski_default.tres").duplicate(true))
	sim.reset(field.spawn_point()); sim.prime_contacts(field)
	var replay = Replay.new()
	replay.begin(sim,Replay.key("crash-codec-fixture-recovery1"))
	replay.capture_presentation(0.0,_pose(sim))
	var time = 0.0
	var intent = RiderInput.new()
	for cycle in range(crashes+1):
		for i in 4:
			sim.step(DT,intent,field)
			time += DT
			replay.record(DT,time,sim,intent)
			if replay.wants_presentation_sample(): replay.capture_presentation(time,_pose(sim))
		if cycle==crashes: break
		sim.crash("FIXTURE")
		replay.begin_crash(time,sim)
		replay.capture_presentation(time,_pose(sim))
		for i in inactive_ticks:
			time += DT
			replay.record_crash(DT,time)
		var destination: Vector3 = field.spawn_point()+Vector3(-2.0*(cycle+1),0,0)
		Recovery.restore_at_rest(sim,{"position":destination,"heading":0.0},field)
		replay.record_recovery(time,sim)
		replay.capture_presentation(time,_pose(sim))
	sim.step(DT,intent,field)
	time += DT*.375
	replay.record(DT,time,sim,intent,.375)
	replay.capture_presentation(time,_pose(sim))
	return replay

func _decode(replay):
	return Replay.decode(replay.to_data(),replay.compatibility,replay.duration)

func _clock_evidence(replay, decoded) -> Dictionary:
	var intervals: Array = []
	for i in replay.crash_intervals.size():
		for endpoint in 2:
			var source: float = replay.crash_intervals[i][endpoint]
			var restored: float = decoded.crash_intervals[i][endpoint]
			intervals.append({"event":i,"endpoint":endpoint,
				"source_decimal":JSON.stringify(source,"",true,true),
				"decoded_decimal":JSON.stringify(restored,"",true,true),
				"source_f64":PackedFloat64Array([source]).to_byte_array().hex_encode(),
				"decoded_f64":PackedFloat64Array([restored]).to_byte_array().hex_encode(),
				"equal":source==restored})
	var stream = StreamPeerBuffer.new()
	stream.data_array = replay.to_bytes()
	stream.seek(24) # Six uint32 dimensions/magic/version precede exact duration.
	var stored_duration: float = stream.get_double()
	return {"crashes":replay.crash_intervals.size(),"intervals":intervals,
		"duration_decimal":JSON.stringify(replay.duration,"",true,true),
		"stored_duration_decimal":JSON.stringify(stored_duration,"",true,true),
		"stored_duration_exact":stored_duration==replay.duration,
		"sample_times_exact":decoded.sample_times==replay.sample_times,
		"pose_times_exact":decoded.pose_times==replay.pose_times}

func _missing_boundary_payload(encoded: Dictionary, replay) -> Dictionary:
	# Start with a valid payload so this actually tests decoding. Mutating the
	# in-memory pose times first now correctly causes the writer to return {}.
	var stream = StreamPeerBuffer.new()
	stream.data_array = Marshalls.base64_to_raw(encoded.payload)
	stream.seek(8)
	var header_bytes: int = stream.get_u32()
	var pose_times_offset = 32+header_bytes+replay.samples.size()*(8+Replay.WIDTH*4)
	stream.seek(pose_times_offset+8) # Alter the first crash-boundary pose time.
	stream.put_double(replay.pose_times[1]+DT*.5)
	encoded.payload = Marshalls.raw_to_base64(stream.data_array)
	return encoded

func run() -> void:
	for crashes in [0,1,3]:
		var replay = _record(crashes)
		var decoded = _decode(replay)
		check(decoded!=null,"Loadable full-duration replay with %d recovery events" % crashes)
		if decoded==null: continue
		check(decoded.tick_kinds.count(1)==crashes*12 and decoded.ticks==ceili(decoded.duration/DT-.000001),"Inactive ticks count exactly toward duration")
		var evidence = _clock_evidence(replay,decoded)
		clock_round_trips.append(evidence)
		check(decoded.crash_intervals==replay.crash_intervals,"Recovery interval endpoints round trip exactly, without tolerance")
		check(decoded.duration==replay.duration and evidence.stored_duration_exact and evidence.sample_times_exact and evidence.pose_times_exact and decoded.sample_times[-1]==replay.duration and decoded.pose_times[-1]==replay.duration,"Binary timeline and exact fractional finish round trip without tolerance")
		for interval in decoded.crash_intervals:
			check(decoded.in_crash(interval[0]) and decoded.presentation_at((interval[0]+interval[1])*.5).is_empty(),"Ghost is hidden throughout crash interval")
			var pose = decoded.presentation_at(interval[1])
			check(not pose.is_empty() and pose.weight==0.0 and decoded.segment_at(interval[1])>0,"Ghost returns exactly at recovery pose with new track segment")
			check(decoded.discontinuity_between(interval[0]-.001,interval[1]),"Interpolation never bridges the recovery jump")
	var instant = _record(2,0)
	check(_decode(instant)!=null and instant.tick_kinds.count(1)==0,"Same-timestamp recovery remains an explicit zero-duration discontinuity")
	for kind in ["fractional","mask","input","overlap","missing_boundary","open","wrong_identity","old_version"]:
		var broken = _record(2)
		match kind:
			"fractional": broken.crash_intervals[0][0] += DT*.25
			"mask": broken.tick_kinds[0] = 1
			"input": broken.inputs[4*Replay.INPUT_WIDTH] = .5
			"overlap": broken.crash_intervals[1][0] = broken.crash_intervals[0][0]
			"missing_boundary":
				pass # Corrupt a serialized valid payload below, after writer checks.
			"open": broken.crash_intervals[0][1] = -1.0
		var encoded = broken.to_data()
		if kind=="missing_boundary": encoded = _missing_boundary_payload(encoded,broken)
		var identity = broken.compatibility.duplicate()
		if kind=="wrong_identity": identity.course += "-old"
		if kind=="old_version": encoded.version = 5
		check(Replay.decode(encoded,identity,broken.duration)==null,"Malformed recovery replay rejected: "+kind)
	var missing_boundary = _record(1)
	missing_boundary.pose_times[1] += DT*.5
	check(missing_boundary.to_bytes().is_empty() and missing_boundary.to_data().is_empty(),"Unserializable boundary mismatch returns no envelope without encoding empty bytes")
	var overflow = _record(0)
	overflow.complete = false
	_overflow(overflow)
	check(overflow.overflow and overflow.inputs.is_empty() and overflow.samples.is_empty(),"Existing ten-minute overflow frees buffers independently of crash timing")
	check(overflow.to_data().is_empty(),"Overflow capture returns no envelope without encoding empty bytes")
	var report = {"checks":checks,"failures":failures,"clock_round_trips":clock_round_trips}
	preload("res://tests/test_report.gd").write("res://artifacts/orchestration_20260912/crash/replay-results.json",JSON.stringify(report,"\t"))
	print("CRASH_REPLAY_RESULTS ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)

func _overflow(replay) -> void:
	var field = CoreFixtures.Fixture.new()
	var sim = Simulation.new(); sim.reset(field.spawn_point()); sim.prime_contacts(field)
	replay.begin_crash(replay.duration,sim)
	replay.record_crash(DT,Replay.MAX_SECONDS+DT)

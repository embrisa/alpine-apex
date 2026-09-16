extends RefCounted
## Snapshot playback, never a second simulation. SI units; inputs retained at 120 Hz.
const VERSION = 7
const Clock = preload("res://scripts/racing/record_clock.gd")
const Pose = preload("res://scripts/presentation/ghost_pose.gd")
const MAX_BYTES = 32*1024*1024
const MAX_EVENTS = 256
const INPUT_WIDTH = 9 # steer, tuck, brake, release, pitch, yaw, grab, tilt, jump_held
const DT = 1.0/120.0
const SAMPLE_EVERY = 4
const MAX_SECONDS = 600.0
const JOINTS = ["Hips","Spine","Head","RightUpLeg","RightLeg","RightFoot","RightArm","RightForeArm","RightHand","LeftUpLeg","LeftLeg","LeftFoot","LeftArm","LeftForeArm","LeftHand"]
const SKI_START = 56
const FRAME_START = SKI_START+18
const FACING_YAW = FRAME_START+12
const POLE_START = FACING_YAW+1
const WIDTH = POLE_START+3 # completed pole phase/intensity/power
const MAX_SAMPLES = 18002
var samples: Array = []
var sample_times = PackedFloat64Array()
var presentation: Array = []
var pose_times = PackedFloat64Array()
var tick_kinds = PackedByteArray() # 0 skiing, 1 inactive crash
var crash_intervals: Array = []
var crash_open = false
var inputs = PackedFloat32Array()
var compatibility: Dictionary = {}
var duration: float = 0.0
var ticks: int = 0
var previous = PackedFloat32Array()
var complete: bool = false
var overflow: bool = false

static func key(course_id: String) -> Dictionary:
	return {"course":course_id,"engine":Engine.get_version_info().string,
		"physics":preload("res://scripts/core/ski_simulation.gd").MODEL_VERSION,
		"tuning":FileAccess.get_sha256("res://config/ski_default.tres"),"tick_hz":120}

func begin(sim, identity: Dictionary) -> void:
	compatibility = identity.duplicate(true)
	samples = [snapshot(0.0,sim)]
	sample_times = PackedFloat64Array([0.0])
	presentation.clear(); pose_times.clear(); tick_kinds.clear(); crash_intervals.clear()
	crash_open = false
	previous = samples[0]
	inputs = PackedFloat32Array()
	ticks = 0
	duration = 0.0
	complete = false
	overflow = false

static func snapshot(time: float, sim: SkiSimulation) -> PackedFloat32Array:
	var facing = sim.facing_pose
	var ready: bool = facing.initialized and facing.positions.size()==2
	var turn = Basis(Vector3.UP,PI) if sim.facing_backward else Basis.IDENTITY
	var frames: Array[Basis] = [facing.frame.basis if ready else sim.support_basis()*turn]
	var result = [time,sim.position.x,sim.position.y,sim.position.z,sim.heading,sim.edge_angle,
		sim.effective_tuck,sim.surface_normal.x,sim.surface_normal.y,sim.surface_normal.z,1.0 if sim.grounded else 0.0]
	for id in JOINTS:
		var point: Vector3 = facing.joints.get(id,sim.Body.REST[id]) if ready else sim.Body.REST[id]
		result.append_array([point.x,point.y,point.z])
	for i in range(2):
		var ski = sim.skis[1-i if sim.facing_backward else i]
		var point: Vector3 = (facing.positions[i] if ready else ski.position)-sim.position
		var orientation: Basis = facing.orientations[i] if ready else ski.orientation*turn
		frames.append(orientation)
		var up: Vector3 = orientation.y
		result.append_array([point.x,point.y,point.z,up.x,up.y,up.z,sim.facing_heading,ski.edge_angle,1.0 if ski.grounded else 0.0])
	for frame in frames:
		var q: Quaternion = frame.get_rotation_quaternion().normalized()
		result.append_array([q.x,q.y,q.z,q.w])
	result.append(sim.facing_heading)
	result.append_array([sim.pole_push_phase,sim.pole_push_intensity,sim.pole_push_power])
	return PackedFloat32Array(result)

func record(dt: float, end_time: float, sim, intent, last_fraction: float = -1.0) -> void:
	if overflow or complete: return
	if absf(dt-DT)>0.0000001 or end_time>MAX_SECONDS or ticks>=72000:
		overflow = true
		_release_capture()
		return
	inputs.append_array(PackedFloat32Array([intent.steer,intent.tuck,intent.brake,1.0 if intent.jump else 0.0,intent.air_pitch,intent.air_yaw,1.0 if intent.grab else 0.0,intent.air_tilt,1.0 if intent.jump_held else 0.0]))
	ticks += 1
	tick_kinds.append(0)
	var current = snapshot(end_time,sim)
	if last_fraction>=0.0:
		var completed = current.duplicate()
		for i in range(1,WIDTH):
			if i not in [SKI_START+6,SKI_START+15]: current[i] = lerpf(float(previous[i]),float(current[i]),last_fraction)
		current[4] = lerp_angle(float(previous[4]),sim.heading,last_fraction)
		current[FACING_YAW] = lerp_angle(previous[FACING_YAW],sim.facing_heading,last_fraction)
		current[POLE_START] = fposmod(lerp_angle(previous[POLE_START]*TAU,completed[POLE_START]*TAU,last_fraction)/TAU,1.0)
		for start in [FRAME_START,FRAME_START+4,FRAME_START+8]:
			var q = read_quaternion(previous,start).slerp(read_quaternion(completed,start),last_fraction).normalized()
			var components = [q.x,q.y,q.z,q.w]
			for axis in range(4): current[start+axis] = components[axis]
		current[10] = current[10] if last_fraction>=0.5 else previous[10]
		for start in [SKI_START,SKI_START+9]:
			current[start+6] = lerp_angle(previous[start+6],current[start+6],last_fraction)
			current[start+8] = 1.0 if current[start+8]>=.5 else 0.0
			var normal = Vector3(current[start+3],current[start+4],current[start+5]).normalized()
			for axis in range(3): current[start+3+axis] = normal[axis]
		complete = true
	if ticks%SAMPLE_EVERY==0 or complete:
		if end_time>sample_times[-1]:
			samples.append(current)
			sample_times.append(end_time)
	previous = current
	duration = end_time

func pose_at(time: float) -> Dictionary:
	if samples.is_empty(): return {}
	var low = 0
	var high = samples.size()-1
	while low<high:
		var middle = (low+high+1)/2
		if sample_times[middle]<=time: low = middle
		else: high = middle-1
	var a = samples[low]
	var next = mini(low+1,samples.size()-1)
	var b = samples[next]
	var weight = clampf((time-sample_times[low])/maxf(sample_times[next]-sample_times[low],0.000001),0,1)
	if discontinuity_between(sample_times[low],sample_times[next]): weight = 0.0
	var normal = Vector3(a[7],a[8],a[9]).lerp(Vector3(b[7],b[8],b[9]),weight).normalized()
	var result = {"position":Vector3(a[1],a[2],a[3]).lerp(Vector3(b[1],b[2],b[3]),weight),
		"heading":lerp_angle(float(a[4]),float(b[4]),weight),"edge":lerpf(a[5],b[5],weight),
		"tuck":lerpf(a[6],b[6],weight),"normal":normal,"grounded":a[10]>0.5 and (weight==0 or b[10]>0.5),"active":not in_crash(time)}
	result.facing_heading = lerp_angle(a[FACING_YAW],b[FACING_YAW],weight)
	result.basis = Basis(read_quaternion(a,FRAME_START).slerp(read_quaternion(b,FRAME_START),weight).normalized())
	result.joints = {}
	for i in range(JOINTS.size()):
		var j = 11+i*3
		result.joints[JOINTS[i]] = Vector3(a[j],a[j+1],a[j+2]).lerp(Vector3(b[j],b[j+1],b[j+2]),weight)
	result.skis = []
	for start in [SKI_START,SKI_START+9]:
		result.skis.append({"offset":Vector3(a[start],a[start+1],a[start+2]).lerp(Vector3(b[start],b[start+1],b[start+2]),weight),
			"normal":Vector3(a[start+3],a[start+4],a[start+5]).lerp(Vector3(b[start+3],b[start+4],b[start+5]),weight).normalized(),
			"heading":lerp_angle(a[start+6],b[start+6],weight),"edge":lerpf(a[start+7],b[start+7],weight),"grounded":a[start+8]>.5 and (weight==0 or b[start+8]>.5)})
		var q_start = FRAME_START+result.skis.size()*4
		result.skis[-1].basis = Basis(read_quaternion(a,q_start).slerp(read_quaternion(b,q_start),weight).normalized())
	result.pole_push_phase = fposmod(lerp_angle(a[POLE_START]*TAU,b[POLE_START]*TAU,weight)/TAU,1.0)
	result.pole_push_intensity = lerpf(a[POLE_START+1],b[POLE_START+1],weight)
	result.pole_push_power = lerpf(a[POLE_START+2],b[POLE_START+2],weight)
	return result

static func read_quaternion(frame, start: int) -> Quaternion:
	return Quaternion(frame[start],frame[start+1],frame[start+2],frame[start+3])

func wants_presentation_sample() -> bool:
	return not overflow and not crash_open and not sample_times.is_empty() and (pose_times.is_empty() or sample_times[-1]>pose_times[-1])

func capture_presentation(time: float, data: PackedFloat32Array) -> void:
	if overflow or not Pose.validate(data): return
	if not pose_times.is_empty() and time<pose_times[-1]: return
	if not pose_times.is_empty() and time==pose_times[-1]:
		presentation[-1] = data
		return
	if presentation.size()>=MAX_SAMPLES+MAX_EVENTS*2:
		overflow = true
		_release_capture()
		return
	pose_times.append(time)
	presentation.append(data)

func has_presentation() -> bool:
	return complete and not overflow and not crash_open and pose_times==sample_times and pose_times.size()>=2 and pose_times[0]==0.0 and pose_times[-1]==duration

func presentation_at(time: float) -> Dictionary:
	if presentation.is_empty() or in_crash(time): return {}
	var low = 0
	var high = pose_times.size()-1
	while low<high:
		var middle = (low+high+1)/2
		if pose_times[middle]<=time: low = middle
		else: high = middle-1
	var next = mini(low+1,pose_times.size()-1)
	var weight = clampf((time-pose_times[low])/maxf(pose_times[next]-pose_times[low],.000001),0,1)
	if discontinuity_between(pose_times[low],pose_times[next]): weight = 0.0
	return {"a":presentation[low],"b":presentation[next],"weight":weight,"segment":segment_at(time)}

func begin_crash(time: float, sim) -> void:
	if overflow or complete or crash_open: return
	if crash_intervals.size()>=MAX_EVENTS:
		overflow = true; _release_capture(); return
	crash_intervals.append([time,-1.0])
	crash_open = true
	_append_snapshot(time,sim)

func record_crash(dt: float, time: float) -> void:
	if overflow or complete or not crash_open: return
	if absf(dt-DT)>.0000001 or time>MAX_SECONDS or ticks>=72000:
		overflow = true; _release_capture(); return
	inputs.resize(inputs.size()+INPUT_WIDTH)
	for i in INPUT_WIDTH: inputs[inputs.size()-1-i] = 0.0
	tick_kinds.append(1)
	ticks += 1
	duration = time

func record_recovery(time: float, sim) -> void:
	if overflow or complete or not crash_open: return
	crash_intervals[-1][1] = time
	crash_open = false
	_append_snapshot(time,sim)

func _append_snapshot(time: float, sim) -> void:
	previous = snapshot(time,sim)
	if sample_times[-1]==time: samples[-1] = previous
	else:
		samples.append(previous)
		sample_times.append(time)

func in_crash(time: float) -> bool:
	for interval in crash_intervals:
		if time>=interval[0] and (interval[1]<0 or time<interval[1]): return true
	return false

func segment_at(time: float) -> int:
	var segment = 0
	for interval in crash_intervals:
		if interval[1]>=0 and time>=interval[1]: segment += 1
	return segment

func discontinuity_between(a: float, b: float) -> bool:
	for interval in crash_intervals:
		if interval[0]>a and interval[0]<=b or interval[1]>a and interval[1]<=b: return true
	return false

func _release_capture() -> void:
	samples.clear(); sample_times.clear(); presentation.clear(); pose_times.clear()
	inputs.clear(); tick_kinds.clear(); crash_intervals.clear()

func to_data() -> Dictionary:
	var payload = to_bytes()
	if payload.is_empty(): return {}
	return {"version":VERSION,"compatibility":compatibility,"duration":Clock.encode(duration),"payload":Marshalls.raw_to_base64(payload)}

func to_bytes() -> PackedByteArray:
	if not has_presentation(): return PackedByteArray()
	if not is_finite(duration) or duration<=0.0 or duration>MAX_SECONDS or crash_intervals.size()>MAX_EVENTS: return PackedByteArray()
	var stored_intervals: Array = []
	for interval in crash_intervals:
		if not interval is Array or interval.size()!=2 or not number(interval[0]) or not number(interval[1]): return PackedByteArray()
		stored_intervals.append(Clock.encode_array(interval))
	var header = JSON.stringify({"compatibility":compatibility,"crashes":stored_intervals},"",true,true).to_utf8_buffer()
	if header.size()>16384: return PackedByteArray()
	var stream = StreamPeerBuffer.new()
	stream.put_u32(0x37525041); stream.put_u32(VERSION); stream.put_u32(header.size())
	stream.put_u32(samples.size()); stream.put_u32(presentation.size()); stream.put_u32(ticks)
	stream.put_double(duration); stream.put_data(header)
	stream.put_data(sample_times.to_byte_array())
	for row in samples: stream.put_data(PackedFloat32Array(row).to_byte_array())
	stream.put_data(pose_times.to_byte_array())
	for row in presentation: stream.put_data(row.to_byte_array())
	stream.put_data(inputs.to_byte_array()); stream.put_data(tick_kinds)
	return stream.data_array if stream.data_array.size()<=MAX_BYTES else PackedByteArray()

static func decode(data: Variant, expected: Dictionary, best: float):
	if not data is Dictionary or data.get("version")!=VERSION or not compatible(data.get("compatibility"),expected): return null
	var seconds = Clock.decode(data.get("duration"))
	if seconds==null or seconds!=best: return null
	var encoded = data.get("payload")
	if not encoded is String or encoded.length()>ceili(MAX_BYTES/3.0)*4: return null
	return from_bytes(Marshalls.base64_to_raw(encoded),expected,best)

static func from_bytes(bytes: PackedByteArray, expected: Dictionary, best: float):
	if bytes.size()<32 or bytes.size()>MAX_BYTES or not is_finite(best) or best<=0 or best>MAX_SECONDS: return null
	var stream = StreamPeerBuffer.new()
	stream.data_array = bytes
	if stream.get_u32()!=0x37525041 or stream.get_u32()!=VERSION: return null
	var header_size = stream.get_u32()
	var count = stream.get_u32(); var pose_count = stream.get_u32(); var tick_count = stream.get_u32()
	var seconds = stream.get_double()
	if not is_finite(seconds) or seconds!=best or header_size>16384: return null
	if count<2 or count>MAX_SAMPLES+MAX_EVENTS*2 or pose_count<2 or pose_count>MAX_SAMPLES+MAX_EVENTS*2: return null
	if tick_count!=ceili(seconds/DT-.000001) or tick_count>72000: return null
	var required = 32+header_size+count*(8+WIDTH*4)+pose_count*(8+Pose.WIDTH*4)+tick_count*(INPUT_WIDTH*4+1)
	# Validate all dimensions/aggregate size before allocating frame collections.
	if required!=bytes.size(): return null
	var header = JSON.parse_string(stream.get_data(header_size)[1].get_string_from_utf8())
	if not header is Dictionary or not compatible(header.get("compatibility"),expected): return null
	var stored_intervals = header.get("crashes")
	if not stored_intervals is Array or stored_intervals.size()>MAX_EVENTS: return null
	var intervals: Array = []
	var end = -1.0
	for stored in stored_intervals:
		var interval = Clock.decode_array(stored,2)
		if interval==null: return null
		if interval[0]<0 or interval[0]<end or interval[1]<interval[0] or interval[1]>seconds: return null
		end = interval[1]
		intervals.append(interval)
	var replay = load("res://scripts/racing/run_replay.gd").new()
	replay.sample_times = stream.get_data(count*8)[1].to_float64_array()
	if not valid_times(replay.sample_times,seconds): return null
	for i in count:
		var frame: PackedFloat32Array = stream.get_data(WIDTH*4)[1].to_float32_array()
		if not valid_snapshot(frame): return null
		replay.samples.append(frame)
	replay.pose_times = stream.get_data(pose_count*8)[1].to_float64_array()
	if not valid_times(replay.pose_times,seconds): return null
	for i in pose_count:
		var frame: PackedFloat32Array = stream.get_data(Pose.WIDTH*4)[1].to_float32_array()
		if not Pose.validate(frame): return null
		replay.presentation.append(frame)
	replay.inputs = stream.get_data(tick_count*INPUT_WIDTH*4)[1].to_float32_array()
	replay.tick_kinds = stream.get_data(tick_count)[1]
	for i in replay.inputs.size():
		var value: float = replay.inputs[i]
		var field = i%INPUT_WIDTH
		if not is_finite(value) or value>1 or value<(-1.0 if field in [0,4,5,7] else 0.0) or (field in [3,6,8] and value not in [0.0,1.0]): return null
	for kind in replay.tick_kinds:
		if kind not in [0,1]: return null
	# The fixed binary header owns duration; metadata is only an exact identity check.
	replay.compatibility = expected.duplicate(true); replay.duration = seconds
	replay.ticks = tick_count; replay.complete = true; replay.crash_intervals = intervals
	if not preload("res://scripts/racing/crash_replay_validation.gd").valid(replay,intervals,seconds): return null
	if replay.pose_times!=replay.sample_times: return null
	return replay

static func valid_times(times: PackedFloat64Array, best: float) -> bool:
	if times.is_empty() or times[0]!=0.0 or times[-1]!=best: return false
	var previous_time = -1.0
	for time in times:
		if not is_finite(time) or time<=previous_time or time>best: return false
		previous_time = time
	return true

static func valid_snapshot(frame: PackedFloat32Array) -> bool:
	if frame.size()!=WIDTH: return false
	for value in frame:
		if not is_finite(value) or absf(value)>10000: return false
	if absf(frame[5])>PI or frame[6]<0 or frame[6]>1 or frame[10] not in [0.0,1.0]: return false
	if absf(Vector3(frame[7],frame[8],frame[9]).length()-1.0)>.15: return false
	for start in [FRAME_START,FRAME_START+4,FRAME_START+8]:
		if absf(read_quaternion(frame,start).length_squared()-1.0)>.01: return false
	for j in range(11,SKI_START):
		if absf(frame[j])>3.0: return false
	for start in [SKI_START,SKI_START+9]:
		if Vector3(frame[start],frame[start+1],frame[start+2]).length()>3.0: return false
		if absf(Vector3(frame[start+3],frame[start+4],frame[start+5]).length()-1.0)>.15: return false
		if absf(frame[start+6])>PI+.01 or absf(frame[start+7])>PI or frame[start+8] not in [0.0,1.0]: return false
	for j in range(POLE_START,WIDTH):
		if frame[j]<0 or frame[j]>1: return false
	return absf(frame[FACING_YAW])<=PI+.01

func input_at(tick: int) -> RiderInput:
	var intent = RiderInput.new()
	if tick<0 or tick*INPUT_WIDTH+INPUT_WIDTH>inputs.size(): return intent
	var offset = tick*INPUT_WIDTH
	intent.steer = inputs[offset]; intent.tuck = inputs[offset+1]; intent.brake = inputs[offset+2]
	intent.jump = inputs[offset+3]>.5; intent.air_pitch = inputs[offset+4]; intent.air_yaw = inputs[offset+5]; intent.grab = inputs[offset+6]>.5
	intent.air_tilt = inputs[offset+7]
	intent.jump_held = inputs[offset+8]>.5
	return intent

static func number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))

static func compatible(candidate: Variant, expected: Dictionary) -> bool:
	# JSON reads numbers as floats; dictionary equality distinguishes their type.
	if not candidate is Dictionary or candidate.size()!=expected.size(): return false
	for field in ["course","engine","tuning"]:
		if candidate.get(field)!=expected[field]: return false
	for field in ["physics","tick_hz"]:
		if not number(candidate.get(field)) or float(candidate[field])!=float(expected[field]): return false
	return true

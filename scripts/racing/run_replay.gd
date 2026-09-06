extends RefCounted
## Snapshot playback, never a second simulation. SI units; inputs retained at 120 Hz.
const VERSION = 2
const DT = 1.0/120.0
const SAMPLE_EVERY = 4
const MAX_SECONDS = 600.0
const JOINTS = ["Hips","Spine","Head","RightUpLeg","RightLeg","RightFoot","RightArm","RightForeArm","RightHand","LeftUpLeg","LeftLeg","LeftFoot","LeftArm","LeftForeArm","LeftHand"]
const SKI_START = 56
const WIDTH = SKI_START+18 # each ski: root-relative xyz, normal xyz, yaw, edge, contact
const MAX_SAMPLES = 18002
var samples: Array = []
var inputs = PackedFloat32Array()
var compatibility: Dictionary = {}
var duration: float = 0.0
var ticks: int = 0
var previous: Array = []
var complete: bool = false
var overflow: bool = false

static func key(course_id: String) -> Dictionary:
	return {"course":course_id,"engine":Engine.get_version_info().string,
		"physics":preload("res://scripts/core/ski_simulation.gd").MODEL_VERSION,
		"tuning":FileAccess.get_sha256("res://config/ski_default.tres"),"tick_hz":120}

func begin(sim, identity: Dictionary) -> void:
	compatibility = identity.duplicate(true)
	samples = [snapshot(0.0,sim)]
	previous = samples[0]
	inputs = PackedFloat32Array()
	ticks = 0
	duration = 0.0
	complete = false
	overflow = false

static func snapshot(time: float, sim) -> Array:
	var result = [time,sim.position.x,sim.position.y,sim.position.z,sim.heading,sim.edge_angle,
		sim.effective_tuck,sim.surface_normal.x,sim.surface_normal.y,sim.surface_normal.z,1.0 if sim.grounded else 0.0]
	for id in JOINTS:
		var point: Vector3 = sim.body.joints.get(id,sim.Body.REST[id])
		result.append_array([point.x,point.y,point.z])
	for ski in sim.skis:
		var point: Vector3 = ski.position-sim.position
		result.append_array([point.x,point.y,point.z,ski.normal.x,ski.normal.y,ski.normal.z,ski.heading,ski.edge_angle,1.0 if ski.grounded else 0.0])
	return result

func record(dt: float, end_time: float, sim, intent, last_fraction: float = -1.0) -> void:
	if overflow or complete: return
	if absf(dt-DT)>0.0000001 or end_time>MAX_SECONDS or ticks>=72000:
		overflow = true
		samples.clear()
		inputs.clear()
		return
	inputs.append_array(PackedFloat32Array([intent.steer,intent.tuck,intent.brake,1.0 if intent.jump else 0.0]))
	ticks += 1
	var current = snapshot(end_time,sim)
	if last_fraction>=0.0:
		for i in range(1,WIDTH):
			if i not in [SKI_START+6,SKI_START+15]: current[i] = lerpf(float(previous[i]),float(current[i]),last_fraction)
		current[4] = lerp_angle(float(previous[4]),sim.heading,last_fraction)
		current[10] = current[10] if last_fraction>=0.5 else previous[10]
		for start in [SKI_START,SKI_START+9]:
			current[start+6] = lerp_angle(previous[start+6],current[start+6],last_fraction)
			current[start+8] = 1.0 if current[start+8]>=.5 else 0.0
			var normal = Vector3(current[start+3],current[start+4],current[start+5]).normalized()
			for axis in range(3): current[start+3+axis] = normal[axis]
		complete = true
	if ticks%SAMPLE_EVERY==0 or complete:
		if current[0]>samples[-1][0]: samples.append(current)
	previous = current
	duration = end_time

func pose_at(time: float) -> Dictionary:
	if samples.is_empty(): return {}
	var low = 0
	var high = samples.size()-1
	while low<high:
		var middle = (low+high+1)/2
		if samples[middle][0]<=time: low = middle
		else: high = middle-1
	var a: Array = samples[low]
	var b: Array = samples[mini(low+1,samples.size()-1)]
	var weight = clampf((time-float(a[0]))/maxf(float(b[0])-float(a[0]),0.000001),0,1)
	var normal = Vector3(a[7],a[8],a[9]).lerp(Vector3(b[7],b[8],b[9]),weight).normalized()
	var result = {"position":Vector3(a[1],a[2],a[3]).lerp(Vector3(b[1],b[2],b[3]),weight),
		"heading":lerp_angle(float(a[4]),float(b[4]),weight),"edge":lerpf(a[5],b[5],weight),
		"tuck":lerpf(a[6],b[6],weight),"normal":normal,"grounded":a[10]>0.5 if weight<0.5 else b[10]>0.5}
	result.joints = {}
	for i in range(JOINTS.size()):
		var j = 11+i*3
		result.joints[JOINTS[i]] = Vector3(a[j],a[j+1],a[j+2]).lerp(Vector3(b[j],b[j+1],b[j+2]),weight)
	result.skis = []
	for start in [SKI_START,SKI_START+9]:
		result.skis.append({"offset":Vector3(a[start],a[start+1],a[start+2]).lerp(Vector3(b[start],b[start+1],b[start+2]),weight),
			"normal":Vector3(a[start+3],a[start+4],a[start+5]).lerp(Vector3(b[start+3],b[start+4],b[start+5]),weight).normalized(),
			"heading":lerp_angle(a[start+6],b[start+6],weight),"edge":lerpf(a[start+7],b[start+7],weight)})
	return result

func to_data() -> Dictionary:
	return {"version":VERSION,"compatibility":compatibility,"duration":duration,
		"sample_every":SAMPLE_EVERY,"samples":samples,"inputs_f32":Marshalls.raw_to_base64(inputs.to_byte_array())}

static func decode(data: Variant, expected: Dictionary, best: float):
	if not data is Dictionary or data.get("version")!=VERSION or not compatible(data.get("compatibility"),expected) or data.get("sample_every")!=SAMPLE_EVERY:
		return null
	if not number(data.get("duration")) or not is_equal_approx(float(data.duration),best) or best<=0 or best>MAX_SECONDS:
		return null
	var frames = data.get("samples")
	var encoded = data.get("inputs_f32")
	if not frames is Array or frames.size()<2 or frames.size()>MAX_SAMPLES or not encoded is String or encoded.length()>1536000:
		return null
	var previous_time = -1.0
	for frame in frames:
		if not frame is Array or frame.size()!=WIDTH: return null
		for value in frame:
			if not number(value) or absf(float(value))>10000: return null
		if frame[0]<=previous_time or frame[0]>best+0.000001 or absf(frame[5])>PI or frame[6]<0 or frame[6]>1 or frame[10] not in [0.0,1.0]: return null
		if Vector3(frame[7],frame[8],frame[9]).length()<0.5 or Vector3(frame[7],frame[8],frame[9]).length()>1.1: return null
		for j in range(11,SKI_START):
			if absf(frame[j])>3.0: return null
		for start in [SKI_START,SKI_START+9]:
			if Vector3(frame[start],frame[start+1],frame[start+2]).length()>3.0: return null
			if absf(Vector3(frame[start+3],frame[start+4],frame[start+5]).length()-1.0)>.15: return null
			if absf(frame[start+6])>PI+.01 or absf(frame[start+7])>PI or frame[start+8] not in [0.0,1.0]: return null
		previous_time = frame[0]
	if frames[0][0]!=0.0 or absf(float(frames[-1][0])-best)>0.000001: return null
	var bytes = Marshalls.base64_to_raw(encoded)
	if bytes.size()%16!=0: return null
	var frames_input = bytes.to_float32_array()
	var expected_ticks = ceili(best/DT-0.000001)
	if frames_input.size()!=expected_ticks*4: return null
	for i in frames_input.size():
		var v = frames_input[i]
		if not is_finite(v) or v>1.0 or v<(-1.0 if i%4==0 else 0.0) or (i%4==3 and v not in [0.0,1.0]): return null
	var replay = load("res://scripts/racing/run_replay.gd").new()
	replay.compatibility = expected.duplicate(true)
	replay.samples = frames
	replay.inputs = frames_input
	replay.duration = best
	replay.ticks = expected_ticks
	replay.complete = true
	return replay

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

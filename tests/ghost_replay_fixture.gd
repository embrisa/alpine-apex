extends RefCounted
## Synthetic codec/storage fixtures, explicitly not rendered animation evidence.
const Replay = preload("res://scripts/racing/run_replay.gd")
const Pose = preload("res://scripts/presentation/ghost_pose.gd")
const Sim = preload("res://scripts/core/ski_simulation.gd")

static func pose(position_value: Vector3, supported: bool = true) -> PackedFloat32Array:
	var data = PackedFloat32Array()
	for i in Pose.TRANSFORMS:
		Pose.append_transform(data,Transform3D(Basis.IDENTITY,position_value if i==0 else Vector3.ZERO))
	for i in 2: data.append_array(PackedFloat32Array([float(supported),float(supported),.3,.3,.02,0,1,0,0,0]))
	data.append(2.1)
	return data

static func replay(seconds: float, identity: Dictionary, dense: bool = false, offset: float = 0.0):
	var sim = Sim.new()
	sim.reset(Vector3(offset,0,0))
	var result = Replay.new()
	result.begin(sim,identity)
	result.capture_presentation(0.0,pose(sim.position))
	var count = ceili(seconds*30) if dense else 1
	for i in range(1,count+1):
		var time = minf(seconds,i/30.0) if dense else seconds
		sim.position = Vector3(offset+sin(time)*.1,0,time*2)
		var frame: PackedFloat32Array = result.samples[0].duplicate()
		frame[0] = time
		for axis in 3: frame[1+axis] = sim.position[axis]
		result.samples.append(frame); result.sample_times.append(time)
		result.capture_presentation(time,pose(sim.position))
	result.duration = seconds; result.complete = true
	result.ticks = ceili(seconds/Replay.DT-.000001)
	result.inputs.resize(result.ticks*Replay.INPUT_WIDTH); result.inputs.fill(0)
	result.tick_kinds.resize(result.ticks); result.tick_kinds.fill(0)
	return result

static func attach_sample_poses(recording) -> void:
	# Input/physics codec regressions need a complete current envelope. These
	# neutral poses use each real snapshot root; they are not animation evidence.
	for i in recording.samples.size():
		var frame = recording.samples[i]
		recording.capture_presentation(recording.sample_times[i],pose(Vector3(frame[1],frame[2],frame[3]),frame[10]>.5))

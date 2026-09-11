extends RefCounted
## Observes completed player ticks. Never writes state back to the simulation.
const Trace = preload("res://tests/performance_trace.gd")
const Inputs = preload("res://tests/performance_input.gd")
const MAX_TICKS = 72000
var data: Dictionary = {}
var recording = false
var failure = ""
func begin(field, sim, presentation: Dictionary) -> void:
	failure = ""
	var face = 0
	for i in field.faces.size():
		if absf(angle_difference(sim.heading,field.faces[i].heading))<absf(angle_difference(sim.heading,field.faces[face].heading)): face = i
	data = {"origin":"player","identity":Trace.identity(field),"input_fields":Inputs.FIELDS,"seed":field.seed_value,
		"face":face,"heading":sim.heading,"command_ticks":1,"commands":[],"checkpoints":[],"camera_samples":[],
		"initial_state":Inputs.state(sim),"presentation":presentation.duplicate(true)}
	recording = sim.ticks==0 and sim.position==field.launch_point(sim.heading)
	if not recording: failure = "Start recording with a fresh summit drop."
func observe(sim, intent, camera_sample: Array = [false,0.0,0.0,1.0]) -> void:
	if not recording: return
	if sim.ticks!=data.commands.size()+1: invalidate("The run restarted or skipped recorded ticks."); return
	data.commands.append(Inputs.encode(intent))
	data.camera_samples.append(camera_sample.duplicate())
	if sim.ticks%120==0: data.checkpoints.append(Inputs.state(sim))
	if sim.ticks>=MAX_TICKS: invalidate("The recording exceeded ten minutes. Retry a shorter descent.")
func invalidate(reason: String) -> void:
	if failure.is_empty(): failure = reason
	recording = false
func finish(sim, finished: bool, reason: String = "manual") -> bool:
	if data.is_empty(): return false
	if data.commands.size()!=sim.ticks: invalidate("The recording is missing inputs.")
	data.result = {"face":data.face,"side":0,"ticks":sim.ticks,"seconds":sim.ticks/120.0,
		"finished":finished,"crash":sim.crash_reason,"position":[sim.position.x,sim.position.y,sim.position.z]}
	data.final_state = Inputs.state(sim)
	data.termination = reason
	data.scope = "complete_descent" if finished and not sim.crashed else "scenario"
	data.recording_error = failure
	recording = false
	if failure.is_empty(): failure = Trace.preflight_error(data,field_version(),false)
	data.recording_error = failure
	return failure.is_empty()
func field_version() -> int:
	return int(data.identity.generator)

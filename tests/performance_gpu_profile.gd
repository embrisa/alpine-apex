extends "res://tests/performance_descent.gd"
## Native resolved timestamps; profiling is separate from acceptance timing.
const MAX_PROFILE_FRAMES = 10000
var gpu_markers: Array = []
var gpu_mutex = Mutex.new()
var last_gpu_frame = -1
var profile_trial = 0
var dropped_frames = 0
var frames_with_passes = 0

func run() -> void:
	if DisplayServer.get_name()=="headless":
		printerr("GPU pass profiling requires a native renderer")
		quit(2); return
	await super.run()

func prepare_comparison_trial(index: int) -> void:
	profile_trial = index+1

func measure() -> void:
	super.measure()
	if recording:
		RenderingServer.call_on_render_thread(read_markers.bind(profile_trial,game.sim.ticks))

func read_markers(trial: int, requested_tick: int) -> void:
	var rd = RenderingServer.get_rendering_device()
	var frame = rd.get_captured_timestamps_frame()
	if frame==last_gpu_frame: return
	last_gpu_frame = frame
	var markers = []
	var has_passes = false
	for i in rd.get_captured_timestamps_count():
		var name = rd.get_captured_timestamp_name(i)
		if name=="Render Opaque Pass": has_passes = true
		markers.append([name,rd.get_captured_timestamp_gpu_time(i),rd.get_captured_timestamp_cpu_time(i)])
	gpu_mutex.lock()
	if has_passes: frames_with_passes += 1
	if gpu_markers.size()<MAX_PROFILE_FRAMES:
		gpu_markers.append({"trial":trial,"gpu_frame":frame,"read_requested_tick":requested_tick,"markers":markers})
	else:
		dropped_frames += 1
	gpu_mutex.unlock()

func comparison_metadata() -> Dictionary:
	return {"gpu_pass_profiling":true}

func dispose_comparison() -> void:
	# Reading completed queries does not stall the GPU. The final pending read
	# may be omitted; trim boundary frames when aggregating each trial.
	gpu_mutex.lock()
	if frames_with_passes==0: failures.append("No native GPU passes captured; supply the engine --gpu-profile flag")
	if dropped_frames>0: failures.append("GPU profile exceeded its 10000-frame bound; select a shorter diagnostic")
	preload("res://tests/test_report.gd").write(output+"/gpu_passes.json",JSON.stringify({
		"scope":"Diagnostic native timestamps; GPU frames lag the requesting simulation tick. Exclude trial boundaries. No screenshot or device synchronization.",
		"fields":["name","gpu_ns","cpu_us"],"frames_with_passes":frames_with_passes,"dropped_frames":dropped_frames,"frames":gpu_markers}))
	gpu_mutex.unlock()
	var path = output+"/production.json"
	var report = JSON.parse_string(FileAccess.get_file_as_string(path))
	report.gpu_pass_profiling = true
	report.gpu_passes_file = "gpu_passes.json"
	report.failures = failures
	preload("res://tests/test_report.gd").write(path,JSON.stringify(report,"\t"))

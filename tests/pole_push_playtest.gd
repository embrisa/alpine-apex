extends "res://tests/pole_push_capture.gd"
## Same synchronized solver chronology with production chase in the first view.
var chase
var frame_fovs: Array[float] = []

func setup_render():
	super.setup_render()
	chase = preload("res://scripts/presentation/chase_camera.gd").new()
	views[0].add_child(chase); cameras[0].queue_free(); cameras[0] = chase; chase.current = true
	report.notes.append("First panel is the production chase camera; anatomical front/side remain beside it.")

func reset_sim(name: String, fixture: Dictionary):
	if chase: chase.reset()
	return super.reset_sim(name,fixture)

func position_cameras(sim, name: String):
	super.position_cameras(sim,name)
	chase.update_camera(sim,field,sim.position,1.0/60.0)
	frame_fovs.append(chase.fov)

func capture_sequence(name: String, fixture: Dictionary):
	assert(not probe,"Use native rendering for the chase review")
	frame_fovs.clear()
	await super.capture_sequence(name,fixture)
	# The shared capture labels its three studio cameras orthographic. Preserve
	# exact transforms and correct the production camera's projection metadata.
	var path = output+"/"+name+".json"
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert(data.frames.size()==frame_fovs.size(),"Every actual camera sample needs its own FOV")
	for i in data.frames.size():
		var row: Dictionary = data.frames[i]
		row.cameras[0].projection = "perspective"
		row.cameras[0].fov = frame_fovs[i]
	FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(data,"\t"))

func source_hashes() -> Dictionary:
	var result = super.source_hashes()
	result["res://tests/pole_push_playtest.gd"] = FileAccess.get_sha256("res://tests/pole_push_playtest.gd")
	return result

extends SceneTree
const Project = preload("res://scripts/workshop/motion_project.gd")
var failures: Array = []
var checks = 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, description: String) -> void:
	checks += 1
	if not value: failures.append(description); printerr("FAIL: ",description)
func run() -> void:
	var path = "res://artifacts/animation_workshop/native-review.zip"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--package="): path = argument.trim_prefix("--package=")
	var zip = ZIPReader.new()
	check(zip.open(path)==OK,"Native review ZIP reopens")
	if not failures.is_empty(): quit(1); return
	var document = JSON.parse_string(zip.read_file("project.apexmotion").get_string_from_utf8())
	check(Project.validate(document).is_empty(),"Embedded project validates")
	if not failures.is_empty(): zip.close(); quit(1); return
	var project = Project.new(); project.data = document
	var max_error = 0.0; var frames_tested = 0; var images_tested = 0
	for item in document.variants:
		var motion = JSON.parse_string(zip.read_file("motion/"+item.id+".json").get_string_from_utf8())
		check(motion.frames.size()==roundi(item.duration*60)+1,"Baked frame count matches duration")
		for frame in motion.frames:
			frames_tested += 1
			check(absf(frame.time-frame.frame/60.0)<.00001,"Baked frame timestamp is exact")
			for layer in ["original","edited"]:
				var pose = project.evaluate(item.id,frame.time,layer=="edited")
				max_error = maxf(max_error,Project.v3(frame[layer].root).distance_to(pose.root))
				for i in pose.q.size():
					var delta = (Project.q4(frame[layer].q[i]).inverse()*pose.q[i]).normalized()
					max_error = maxf(max_error,2*atan2(Vector3(delta.x,delta.y,delta.z).length(),absf(delta.w)))
	check(max_error<.0001,"All original and edited poses reproduce from the packaged project")
	var notes = JSON.parse_string(zip.read_file("comments.json").get_string_from_utf8())
	for note in notes:
		var captured: Dictionary = {}
		for original in document.comments:
			if original.id==note.id: captured = original
		check(not captured.is_empty(),"Every structured comment belongs to the embedded project")
		var previous = -1
		for i in note.evidence.frames.size():
			var frame: Dictionary = note.evidence.frames[i]
			check(frame.frame>previous and absf(frame.time-frame.frame/60.0)<.00001,"Comment frames are chronological with exact timestamps")
			previous = frame.frame
			check(frame.time==captured.evidence.frames[i].time and frame.source_time==captured.evidence.frames[i].source_time,"Comment timestamps match preserved evidence")
			check(zip.file_exists(frame.image),"Comment PNG reference resolves")
			var png = zip.read_file(frame.image)
			check(png==Marshalls.base64_to_raw(captured.evidence.frames[i].image_png),"Export preserves the exact annotated PNG")
			var image = Image.new()
			check(image.load_png_from_buffer(png)==OK and image.get_size()==Vector2i(1280,756),"Comparison PNG decodes at its expected dimensions")
			images_tested += 1
		if note.evidence.has("inspection_image"):
			check(zip.file_exists(note.evidence.inspection_image),"Inspection camera image exists")
		var sheet_path: String = "frames/"+note.id+"_sequence.png"
		check(zip.file_exists(sheet_path),"Chronological contact sheet exists")
		if path.begins_with("user://"):
			var output = FileAccess.open("res://artifacts/animation_workshop/head-study-sequence.png",FileAccess.WRITE)
			output.store_buffer(zip.read_file(sheet_path)); output.close()
	zip.close(); project.dispose()
	var result = {"checks":checks,"frames":frames_tested,"images":images_tested,"max_pose_error":max_error,"failures":failures,"package":path,"sha256":FileAccess.get_sha256(path)}
	Project.atomic_json("res://artifacts/animation_workshop/package-check.json",result)
	print("WORKSHOP_PACKAGE ",JSON.stringify(result))
	if "--show-folder" in OS.get_cmdline_user_args():
		print("SHOW_EXPORT_FOLDER ",OS.shell_show_in_file_manager(ProjectSettings.globalize_path(path)))
		await create_timer(3).timeout
	quit(0 if failures.is_empty() else 1)

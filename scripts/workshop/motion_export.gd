extends RefCounted
const Project = preload("res://scripts/workshop/motion_project.gd")
const Capture = preload("res://scripts/workshop/motion_capture.gd")
var error = ""
var progress: Callable
var cancelled = false

func message(value: String) -> void:
	if progress.is_valid(): progress.call(value)

func capture_evidence(stage, start: float, end: float, bones: Array) -> Dictionary:
	var saved_time: float = stage.time; var saved_camera: Dictionary = stage.camera_data()
	var evidence = {"revision":stage.project.revision,"camera":saved_camera,"context":stage.project.data.preview.duplicate(true),"bones":bones.duplicate(),"frames":[]}
	# Freeze the fitting implementation alongside the source animation identity.
	# Subsequent game updates cannot relabel the context of existing evidence.
	evidence.fitting_identity = {"physics_model":preload("res://scripts/core/ski_simulation.gd").MODEL_VERSION,"sources":{}}
	for path in ["scripts/core/rider_body.gd","scripts/presentation/skier_full_motion.gd","scripts/presentation/skier_visual.gd","scripts/presentation/skier_anatomy.gd","scripts/workshop/pose_evaluator.gd"]:
		evidence.fitting_identity.sources[path] = FileAccess.get_sha256("res://"+path)
	await stage.get_tree().process_frame
	await RenderingServer.frame_post_draw
	evidence.inspection_time = saved_time
	evidence.inspection_png = Marshalls.raw_to_base64(stage.capture().save_png_to_buffer())
	var times: Array = []
	var duration: float = stage.project.variant(stage.variant_id).duration
	for at in [start-.15,start,(start+end)*.5,end,end+.15]:
		var frame = roundi(clampf(at,0,duration)*60)
		if not times.has(frame): times.append(frame)
	stage.comparison = "Side by side"; stage.distance = maxf(7,stage.distance); stage.update_camera()
	evidence.capture_camera = stage.camera_data()
	evidence.capture_dimensions = [1280,756]
	for frame in times:
		stage.time = frame/60.0; stage.refresh()
		await stage.get_tree().process_frame
		await RenderingServer.frame_post_draw
		var source_image = stage.capture()
		var scale = minf(1280.0/source_image.get_width(),720.0/source_image.get_height())
		var scaled_size = Vector2i(Vector2(source_image.get_size())*scale)
		source_image.resize(scaled_size.x,scaled_size.y,Image.INTERPOLATE_LANCZOS); source_image.convert(Image.FORMAT_RGBA8)
		var offset = (Vector2i(1280,720)-scaled_size)/2
		var image = Image.create(1280,720,false,Image.FORMAT_RGBA8); image.fill(Color("182c3b"))
		image.blit_rect(source_image,Rect2i(Vector2i.ZERO,scaled_size),offset)
		var markers: Array = []
		for index in 3:
			for bone in bones:
				if stage.poses[index].joints.has(bone):
					var p: Vector2 = stage.project_point(stage.bone_point(bone,index))/stage.size
					p = (Vector2(offset)+p*Vector2(scaled_size))/Vector2(1280,720)
					markers.append({"bone":bone,"point":[p.x,p.y]})
		var marked = await mark_image(stage,image,"Original  /  Your edit  /  Constrained · frame %d · %.3f s"%[frame,stage.time],markers)
		var original = stage.project.evaluate(stage.variant_id,stage.time,false)
		var edited = stage.project.evaluate(stage.variant_id,stage.time)
		evidence.frames.append({"frame":frame,"time":stage.time,"source_time":stage.project.source_time(stage.project.variant(stage.variant_id),stage.time),
			"original":pack_pose(original),"edited":pack_pose(edited),"changes":stage.diagnostics.changes.duplicate(true),"fitting":stage.diagnostics.fitting.duplicate(true),
			"image_png":Marshalls.raw_to_base64(marked.save_png_to_buffer())})
	stage.time = saved_time; stage.restore_camera(saved_camera); stage.refresh()
	return evidence

static func pack_pose(pose: Dictionary) -> Dictionary:
	var rotations: Array = []
	for q in pose.q: rotations.append(Project.quat(q))
	return {"root":Project.vec(pose.root),"q":rotations}

static func mark_image(stage, image: Image, heading: String, markers: Array) -> Image:
	var viewport = SubViewport.new(); viewport.size = Vector2i(1280,756); viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	stage.add_child(viewport)
	var canvas = Capture.new(); canvas.size = Vector2(viewport.size); canvas.texture = ImageTexture.create_from_image(image)
	canvas.heading = heading; canvas.markers = markers; viewport.add_child(canvas)
	await stage.get_tree().process_frame
	await RenderingServer.frame_post_draw
	var result = viewport.get_texture().get_image()
	viewport.queue_free()
	return result

func reviewed_variants(project) -> Array:
	var result: Array = []
	for item in project.data.variants:
		if not item.regions.is_empty() or item.reviewed or project.data.comments.any(func(note): return note.variant==item.id): result.append(item)
	return result

func preview(project) -> String:
	var text = "The ZIP contains your project, original/edited 60 Hz motion, comments and frozen visual evidence.\n\n"
	for item in reviewed_variants(project):
		var notes = project.data.comments.filter(func(note): return note.variant==item.id)
		var images = 0
		for note in notes: images += note.evidence.frames.size()
		text += "%s · %d comments · %d comparisons\n"%[item.name,notes.size(),images]
	return text

func export_zip(project, destination: String, stage = null) -> Error:
	error = ""; cancelled = false
	var items = reviewed_variants(project)
	if items.is_empty(): error = "Add a comment, edit a clip, or mark a variant reviewed first."; return ERR_INVALID_DATA
	var absolute = ProjectSettings.globalize_path(destination)
	var result = DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	if result!=OK: error = "Cannot create export folder."; return result
	var zip = ZIPPacker.new()
	result = zip.open(absolute+".partial")
	if result!=OK: error = "Cannot open export destination."; return result
	var document = project.data.duplicate(true)
	document.variants = items.duplicate(true)
	var used: Array = items.map(func(item): return item.id)
	document.comments = document.comments.filter(func(note): return note.variant in used)
	var sources = {}
	for item in items: sources[item.source] = document.sources[item.source]
	document.sources = sources
	# Even an edited variant with no written comments receives a visual sequence.
	# Generated references belong to this export, not the user's working document.
	if stage!=null:
		var saved_variant: String = stage.variant_id; var saved_time: float = stage.time
		for item in items:
			if document.comments.any(func(note): return note.variant==item.id): continue
			message("Capturing "+item.name)
			stage.variant_id = item.id; stage.time = 0.0; stage.refresh()
			var note = {"id":Project.uid(),"variant":item.id,"start":0.0,"end":item.duration,"bones":[],"priority":"Normal","status":"Reference","text":"Automatically captured overview of this reviewed or edited variant.","generated":true}
			note.evidence = await capture_evidence(stage,0,item.duration,[])
			document.comments.append(note)
		stage.variant_id = saved_variant; stage.time = saved_time; stage.refresh()
	result = put(zip,"project.apexmotion",JSON.stringify(document).to_utf8_buffer())
	var report = "# Alpine Apex animation review\n\nAll changes are authoring proposals. Gameplay integration requires a separate change.\n\n"
	report += "The constrained images use controlled fixtures, not recorded gameplay. Bone rotations use YXZ correction channels and exported local quaternions [x,y,z,w]. Positions use metres; times use seconds at 60 FPS.\n\n"
	var notes_export: Array = []
	for item in items:
		if cancelled: result = ERR_SKIP; break
		message("Baking "+item.name)
		var motion = {"variant":item.id,"name":item.name,"source":item.source,"fps":60,"rig":document.rig,"identity":document.identity,"conventions":document.conventions,"frames":[]}
		for frame in range(roundi(item.duration*60)+1):
			var at = minf(frame/60.0,item.duration)
			motion.frames.append({"frame":frame,"time":at,"source_time":project.source_time(item,at),"original":pack_pose(project.evaluate(item.id,at,false)),"edited":pack_pose(project.evaluate(item.id,at))})
		result = put(zip,"motion/"+item.id+".json",JSON.stringify(motion).to_utf8_buffer()) if result==OK else result
		report += "## "+item.name.replace("\n"," ")+"\n\nSource: `"+item.source+"`. [Exact motion](motion/"+item.id+".json).\n\n"
		var notes = document.comments.filter(func(note): return note.variant==item.id)
		notes.sort_custom(func(a,b): return a.start<b.start)
		for note in notes:
			var exported = note.duplicate(true)
			report += "### Frames %d–%d · %s · %s\n\n%s\n\nBones: %s. Evidence revision: %d.\n\n"%[roundi(note.start*60),roundi(note.end*60),note.priority,note.status,note.text,", ".join(note.bones),note.evidence.revision]
			if note.evidence.has("inspection_png"):
				var inspection_path = "frames/"+note.id+"_inspection.png"
				result = put(zip,inspection_path,Marshalls.base64_to_raw(note.evidence.inspection_png)) if result==OK else result
				exported.evidence.erase("inspection_png"); exported.evidence.inspection_image = inspection_path
				report += "[Original inspection camera]("+inspection_path+")\n\n"
			var sheet: Image
			for i in note.evidence.frames.size():
				var frame: Dictionary = note.evidence.frames[i]
				var image_path = "frames/"+note.id+"_%03d.png"%i
				var bytes = Marshalls.base64_to_raw(frame.image_png)
				result = put(zip,image_path,bytes) if result==OK else result
				exported.evidence.frames[i].erase("image_png"); exported.evidence.frames[i].image = image_path
				var picture = Image.new()
				if picture.load_png_from_buffer(bytes)==OK:
					picture.resize(640,378)
					if sheet==null: sheet = Image.create(640,378*note.evidence.frames.size(),false,Image.FORMAT_RGBA8)
					picture.convert(Image.FORMAT_RGBA8); sheet.blit_rect(picture,Rect2i(0,0,640,378),Vector2i(0,i*378))
				else: result = ERR_INVALID_DATA
			if sheet!=null:
				var sheet_path = "frames/"+note.id+"_sequence.png"
				result = put(zip,sheet_path,sheet.save_png_to_buffer()) if result==OK else result
				report += "![Chronological pose comparison]("+sheet_path+")\n\n"
			notes_export.append(exported)
		if stage!=null: await stage.get_tree().process_frame
	result = put(zip,"comments.json",JSON.stringify(notes_export,"\t").to_utf8_buffer()) if result==OK else result
	result = put(zip,"REVIEW.md",report.to_utf8_buffer()) if result==OK else result
	var close_result = zip.close()
	if result==OK: result = close_result
	if result==OK:
		# Validate the container before replacing an earlier export.
		var reader = ZIPReader.new(); result = reader.open(absolute+".partial")
		if result==OK and not reader.file_exists("project.apexmotion"): result = ERR_FILE_CORRUPT
		reader.close()
	if result==OK:
		if FileAccess.file_exists(absolute):
			if FileAccess.file_exists(absolute+".bak"): DirAccess.remove_absolute(absolute+".bak")
			result = DirAccess.rename_absolute(absolute,absolute+".bak")
		if result==OK: result = DirAccess.rename_absolute(absolute+".partial",absolute)
	if result!=OK: error = "Export did not complete (error %d). Saved projects are intact."%result
	return result

static func put(zip: ZIPPacker, name_value: String, bytes: PackedByteArray) -> Error:
	var result = zip.start_file(name_value)
	if result!=OK: return result
	result = zip.write_file(bytes)
	var end = zip.close_file()
	return result if result!=OK else end

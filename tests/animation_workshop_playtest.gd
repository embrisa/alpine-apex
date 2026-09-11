extends SceneTree
const Workshop = preload("res://scripts/workshop/motion_workshop.gd")
var editor
var failures: Array = []
func _initialize() -> void: call_deferred("run")
func run() -> void:
	Engine.max_fps = 120
	root.size = Vector2i(1440,900)
	root.title = "Alpine Apex · Animation Workshop QA"
	editor = Workshop.new(); editor.persistence_enabled = false; root.add_child(editor)
	for i in 15: await process_frame
	print("WORKSHOP_UI_READY")
	if "--interactive" in OS.get_cmdline_user_args():
		editor.closed.connect(func(): quit()); return
	editor.seek(.508)
	if absf(editor.time-.5)>.00001: failures.append("Seeking does not snap to native frames")
	editor.time = .507; editor.playing = true; editor.toggle_playback()
	if editor.playing or absf(editor.time-.5)>.00001: failures.append("Pause does not stop on an exact frame")
	editor.range_start = .2; editor.range_end = .4; editor.time = .39; editor.playing = true; editor.looping = true
	editor._process(.02)
	if absf(editor.time-.21)>.00001: failures.append("Loop boundary does not preserve elapsed remainder")
	editor.time = .39; editor.looping = false; editor._process(.02)
	if editor.playing or absf(editor.time-.4)>.00001: failures.append("Non-looping playback does not stop at the range end")
	editor.looping = true; editor.range_start = 0; editor.range_end = editor.project.variant(editor.variant_id).duration
	editor.seek(0)
	if DisplayServer.get_name()!="headless":
		await capture("editor_1440")
		editor.stage.comparison = "Side by side"; editor.stage.distance = 7; editor.stage.update_camera(); editor.refresh()
		for view_name in ["Front","Side","Back"]:
			editor.stage.set_view(view_name)
			var p0 = editor.stage.project_point(editor.stage.bone_point("Hips",0))
			var p1 = editor.stage.project_point(editor.stage.bone_point("Hips",1))
			var p2 = editor.stage.project_point(editor.stage.bone_point("Hips",2))
			if p1.x-p0.x<50 or p2.x-p1.x<50: failures.append(view_name+" comparison characters overlap")
			editor.refresh(); await capture("comparison_"+view_name.to_lower())
		editor.stage.set_view("Front"); editor.refresh()
		await capture("comparison_1440")
		editor.new_note(); editor.note_text.text = "Keep the head upright and bring the right hand closer to the torso."
		editor.selected = ["Head","RightHand"]
		await editor.save_note(true)
		var exported = await editor.exporter.export_zip(editor.project,"res://artifacts/animation_workshop/native-review.zip",editor.stage)
		if exported!=OK: failures.append(editor.exporter.error)
		root.size = Vector2i(3840,2160)
		for i in 12: await process_frame
		editor.stage._resize_view()
		await capture("comparison_4k")
	print("WORKSHOP_UI_RESULT ",JSON.stringify({"failures":failures}))
	editor.queue_free(); await process_frame
	quit(0 if failures.is_empty() else 1)
func capture(name_value: String) -> void:
	for i in 5: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/animation_workshop/"+name_value+".png")

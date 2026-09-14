extends SceneTree
const Sequence = preload("res://scripts/ui/startup_sequence.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.mode = Window.MODE_WINDOWED; root.size = Vector2i(1920,1080); Engine.max_fps = 60
	var output = "res://artifacts/startup_20260914/photos"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = "res://"+arg.get_slice("=",1)
	DirAccess.make_dir_recursive_absolute(output)
	var entries = Sequence.Photos.catalog()
	if "--snow-motion" in OS.get_cmdline_user_args():
		await capture_snow(entries[5],output+"/snow"); quit(); return
	for i in entries.size():
		var opening = Sequence.new()
		opening.photo_texture = load(Sequence.Photos.DIRECTORY+entries[i].file)
		opening.photo_focus = Vector2(entries[i].focus[0],entries[i].focus[1])
		opening.preferences = {"muted":true,"reduced_motion":true}
		root.add_child(opening); opening.set_process(false)
		opening.state.elapsed = 1.1; opening._paint()
		await process_frame; await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output+"/photo_%d.png"%i)
		opening.queue_free(); await process_frame
	print("STARTUP_PHOTO_GALLERY ",entries.size()," supplied photographs")
	quit()

func capture_snow(entry: Dictionary, output: String) -> void:
	root.size = Vector2i(1280,720)
	DirAccess.make_dir_recursive_absolute(output)
	var opening = Sequence.new()
	opening.photo_texture = load(Sequence.Photos.DIRECTORY+entry.file)
	opening.preferences = {"muted":true}
	root.add_child(opening); opening.set_process(false)
	for frame in 60:
		opening.state.elapsed = float(frame)/30.0
		opening._paint()
		await process_frame; await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output+"/frame_%03d.png"%frame)
	opening.queue_free(); await process_frame
	print("STARTUP_SNOW_MOTION 60 rendered frames at explicit 30 Hz presentation time; capture is not a performance measurement")

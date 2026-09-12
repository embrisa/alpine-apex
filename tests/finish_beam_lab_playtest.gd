extends SceneTree
## Direct AlpineWorld laboratory caller smoke, separate from Standard race views.
const Beams = preload("res://scripts/presentation/race_beams.gd")
var output = "res://artifacts/taller_finish_beam_lab"
var game
var failures: Array[String] = []
var captures: Array = []

func _initialize() -> void: call_deferred("run")

func check(ok: bool, label: String) -> void:
	print("PASS: " if ok else "FAIL: ",label)
	if not ok: failures.append(label)

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	if not output.begins_with("res://"): output = "res://"+output
	var resolved = ProjectSettings.globalize_path(output).simplify_path()
	var artifacts = ProjectSettings.globalize_path("res://artifacts/").simplify_path().trim_suffix("/")+"/"
	if not resolved.begins_with(artifacts) or DirAccess.dir_exists_absolute(output):
		printerr("Choose a fresh output directory inside artifacts: ",output)
		quit(2); return
	DirAccess.make_dir_recursive_absolute(output)
	set_meta("test_lab_fixture",true)
	game = load("res://main.tscn").instantiate(); game.automated = true
	game.benchmark_no_captures = true
	root.add_child(game); current_scene = game
	while not game.initialized: await process_frame
	game.set_process(false); game.set_physics_process(false)
	game.active = false; game.session.eligible = false
	game.session.record_directory = output+"/records"
	game.session.benchmark_path = output+"/benchmark.json"
	game.sim.tuning.vibration_intensity = 0.0
	game.effects.reset_haptics(); game.effects.muted = true; game.voice.set_muted(true)
	var start = game.world.get_node_or_null("StartBeam")
	var finish_beam = game.world.get_node_or_null("FinishBeam")
	check(start is Beams and finish_beam is Beams,"Laboratory world creates the reusable beam component")
	if start!=null and finish_beam!=null:
		check(start.applied_style.height_m==800.0 and finish_beam.applied_style.height_m==2000.0,"Laboratory world preserves start and selects taller finish")
		check(start in game.world.benchmark_markers and finish_beam in game.world.benchmark_markers,"Laboratory marker owner tracks both beams")
		game.world.set_benchmark_markers(false)
		check(not start.visible and not finish_beam.visible,"Laboratory marker visibility hides both beams")
		game.world.set_benchmark_markers(true)
		if DisplayServer.get_name()!="headless":
			game.display_settings.display_mode = "windowed"
			game.display_settings.apply_display(root,Vector2i(1920,1080))
			game.hud.root.hide(); game.vectors.hide(); game.skier.hide()
			game.weather.set_preset("clear"); game.weather.set_time_of_day("day")
			game.world.update_weather(game.weather.state,0.0,false)
			var camera = Camera3D.new(); camera.far = game.camera.far
			game.add_child(camera); camera.current = true
			var center = Vector3(0,game.field.sample(0,1450).height,1450)
			for item in [{"label":"lab_finish_close","offset":Vector3(12,8,-27),"aim":4.0},
					{"label":"lab_finish_height","offset":Vector3(0,1100,-2600),"aim":1000.0}]:
				camera.global_position = center+item.offset
				camera.look_at(center+Vector3.UP*item.aim)
				for frame in 30:
					call_group("race_beam_vfx","update_effect",1.0/60.0,true,false)
					await process_frame
				await RenderingServer.frame_post_draw
				var image = root.get_texture().get_image()
				check(image.save_png(output+"/"+item.label+".png")==OK,"Saved "+item.label)
				check(image.get_size()==Vector2i(1920,1080),"Laboratory capture is 1080p")
				captures.append({"label":item.label,"camera":[camera.position.x,camera.position.y,camera.position.z],"fov":camera.fov,"far":camera.far})
	var report = {"failures":failures,"captures":captures,"native":DisplayServer.get_name()!="headless",
		"scope":"laboratory component, marker visibility and supplemental fixed views; not ordinary skiing acceptance"}
	FileAccess.open(output+"/report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("FINISH_BEAM_LAB_RESULT ",JSON.stringify(report))
	game.effects.stop_audio(); game.queue_free(); await process_frame
	quit(0 if failures.is_empty() else 1)

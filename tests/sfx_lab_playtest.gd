extends SceneTree
## Small rendered audio fixture. Explicitly not a full-mountain performance test.
const OUTPUT="res://artifacts/sfx/capture"
var game
var requested=Vector2i(1920,1080)
var frames: Array[Dictionary]=[]
var started=0.0
var last_capture=0.0
var busy=false
func _initialize() -> void: run.call_deferred()
func run() -> void:
	if DisplayServer.get_name()=="headless": quit(2);return
	if "--quiet-audio" in OS.get_cmdline_user_args(): AudioServer.set_bus_volume_db(0,-80)
	set_meta("test_lab_fixture",true)
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	game=load("res://main.tscn").instantiate()
	game.automated=true
	root.add_child(game);current_scene=game
	while not game.initialized or (game.loading and game.loading.busy): await process_frame
	game.set_physics_process(false)
	game.voice.enabled=false
	game.start_run(false)
	game.session.eligible=false
	game.effects.muted=false
	game.sim.velocity=game.sim.support_basis().z*25
	if "--audio-capture-4k" in OS.get_cmdline_user_args(): requested=Vector2i(3840,2160)
	game.display_settings.apply_display(root,requested)
	for i in 30: await process_frame
	await RenderingServer.frame_post_draw
	var pixels=root.get_texture().get_image().get_size()
	if pixels!=requested: printerr("Wrong fixture output dimensions: ",pixels);quit(2);return
	var record=AudioEffectRecord.new();record.format=AudioStreamWAV.FORMAT_16_BITS
	var index=AudioServer.get_bus_effect_count(0);AudioServer.add_bus_effect(0,record)
	started=Time.get_ticks_usec()/1000000.0
	record.set_recording_active(true)
	print("SFX_CAPTURE_RIDING ",pixels)
	process_frame.connect(capture_frame)
	for tick in 480:
		var input=RiderInput.new()
		input.steer=.25 if tick>=100 and tick<200 else -.2 if tick>=200 and tick<300 else 0.0
		input.brake=.5 if tick>=300 and tick<400 else 0.0
		input.jump=tick==420
		game.intent=input
		await physics_frame
		game.sim.step(1.0/120,input,game.world.ski_surface)
		game.skier.step_animation(1.0/120,game.sim,input,game.field)
		game.observe_audio_tick(1.0/120)
		if game.sim.crashed: break
	if not game.sim.crashed: game.sim.crash("AUDIO CRASH FIXTURE")
	game.skier.ragdoll.start(game.sim)
	game.active=false
	print("SFX_CAPTURE_CRASH")
	game.hud.show_menu("crashed","Audio crash fixture · unranked")
	await create_timer(2.5).timeout
	process_frame.disconnect(capture_frame)
	while busy: await process_frame
	record.set_recording_active(false)
	var wav=record.get_recording()
	wav.save_to_wav(OUTPUT+"/skiing_crash.wav")
	AudioServer.remove_bus_effect(0,index)
	FileAccess.open(OUTPUT+"/frames.json",FileAccess.WRITE).store_string(JSON.stringify(frames))
	var report={"scope":"laboratory_rendered_audio_fixture","native_sfx":game.effects.sfx.diagnostics(),"native_wind":game.effects.wind.diagnostics(),"audio_rate":wav.mix_rate,"audio_frames":wav.data.size()/4,"capture_frames":frames.size(),"unranked":true,"capture_overhead_included":true,"crash_fixture":true,"actual_pixels":[pixels.x,pixels.y],"display":game.display_settings.report(root,pixels)}
	FileAccess.open(OUTPUT+"/report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("SFX_LAB_CAPTURE ",JSON.stringify(report))
	game.effects.stop_audio()
	game.skier.ragdoll.stop()
	game.hud.open_settings()
	for i in range(game.hud.settings_tabs.get_tab_count()):
		if game.hud.settings_tabs.get_tab_title(i)=="Audio": game.hud.settings_tabs.current_tab=i
	for i in 10: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUTPUT+"/audio_settings.png")
	await create_timer(.2).timeout
	game.queue_free();await process_frame
	quit(0)
func capture_frame() -> void:
	var now=Time.get_ticks_usec()/1000000.0
	if busy or now-last_capture<.2: return
	last_capture=now;busy=true
	await RenderingServer.frame_post_draw
	var name="frame_%04d.jpg" % frames.size()
	root.get_texture().get_image().save_jpg(OUTPUT+"/"+name,.88)
	frames.append({"time":now-started,"file":name})
	busy=false

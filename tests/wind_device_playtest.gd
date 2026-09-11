extends SceneTree
## Real audio callback lifecycle without loading the mountain. No personal stores.
const Wind = preload("res://scripts/presentation/procedural_wind.gd")
var failures: Array[String] = []
var checks = 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, caption: String) -> void:
	checks += 1
	print("PASS: " if ok else "FAIL: ",caption)
	if not ok: failures.append(caption)
func run() -> void:
	if DisplayServer.get_name()=="headless": quit(2); return
	var original = AudioStreamPlayer.new()
	root.add_child(original)
	var controller = Wind.new()
	root.add_child(controller)
	controller.setup(original)
	if not controller.available: quit(2); return
	controller.airflow = Vector3(0,0,-25)
	controller.audible = true
	controller.advance(.2)
	await create_timer(.3).timeout
	var native_frames = controller.diagnostics().frames
	check(native_frames>0,"Real device requests native audio samples")
	controller.mode = 1
	controller.advance(.2)
	await create_timer(.15).timeout
	var paused_frames = controller.diagnostics().frames
	await create_timer(.15).timeout
	check(controller.diagnostics().frames==paused_frames,"Original comparison suspends native DSP work")
	controller.mode = 0
	controller.advance(.2)
	await create_timer(.2).timeout
	check(controller.diagnostics().frames>paused_frames,"Procedural comparison resumes native playback")
	var retained_player = controller.player
	controller.stop_audio()
	check(retained_player.get_parent()==root and retained_player.playing,"Scene retirement preserves the player for its fade")
	controller.queue_free()
	await process_frame
	check(is_instance_valid(retained_player),"Playback survives controller destruction briefly")
	await create_timer(.25).timeout
	check(not is_instance_valid(retained_player),"Retired player releases without a scene leak")
	original.queue_free()
	await process_frame
	FileAccess.open("res://artifacts/wind/device_suite.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"mix_rate":AudioServer.get_mix_rate(),"driver":AudioServer.get_output_device()},"\t"))
	print("WIND_DEVICE_RESULT checks=",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)

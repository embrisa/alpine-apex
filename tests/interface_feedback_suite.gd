extends SceneTree
## Standalone service/content tests. No main scene, mountain generation or personal stores.
const Feedback = preload("res://scripts/ui/interface_feedback.gd")
const Loading = preload("res://scripts/ui/loading_overlay.gd")
const Content = preload("res://scripts/ui/loading_content.gd")
const Router = preload("res://scripts/core/input_router.gd")
const Job = preload("res://scripts/world/generation_job.gd")
const OUTPUT = "res://artifacts/interface_feedback"
var failures: Array[String] = []
var checks: int = 0
var audio_report: Array = []

func _initialize() -> void: call_deferred("run")

func check(value: bool, caption: String) -> void:
	checks += 1
	print("PASS: " if value else "FAIL: ",caption)
	if not value: failures.append(caption)

func run() -> void:
	var _router = Router.new()
	check(DirAccess.make_dir_recursive_absolute(OUTPUT)==OK,"Artifact directory is available")
	var feedback = Feedback.new()
	feedback.enabled = true
	check(not feedback.play(),"Feedback before ready is harmless")
	root.add_child(feedback)
	check(not feedback.persist,"Standalone invocation cannot write personal preferences")
	check(feedback.players.size()==3,"Exactly three players are allocated")
	check(feedback.cues.ready==feedback.cues.success and feedback.cues.focus==feedback.cues.hover and feedback.cues.activate==feedback.cues.press,"Aliases share prebuilt streams")
	inspect_cues(feedback)
	check(not feedback._play_at("missing",1000),"Unknown cue IDs fail silently")
	check(feedback._play_at("focus",2000) and feedback._play_at("activate",2000),"Activation replaces focus even in the same frame")
	check(feedback.players[0].stream==null and feedback.players[2].stream==feedback.cues.press,"Activation releases the obsolete navigation voice")
	check(not feedback._play_at("hover",2050) and not feedback._play_at("adjust",2050),"Soft repeats cannot mask a new screen action")
	check(feedback._play_at("back",2070) and feedback.players[2].stream==feedback.cues.back,"Back replaces activation without queuing")
	check(feedback._play_at("ready",2300) and feedback.players[2].stream==feedback.cues.success,"Existing ready ID dispatches success")
	var accepted = 0
	for i in 1000:
		if feedback._play_at(Feedback.CUE_IDS[i%Feedback.CUE_IDS.size()],10000+i): accepted += 1
	check(accepted>0 and accepted<=35 and feedback.players.size()==3,"One thousand mixed requests per second remain globally bounded")
	var repeats = 0
	for i in 1000:
		if feedback._play_at("adjust",20000+i): repeats += 1
	check(repeats>0 and repeats<=15,"Held adjustment is limited to at most fifteen cues per second")
	check(feedback._play_at("press",22000),"Action admitted before live-volume check")
	var previous_db: float = feedback.players[2].volume_db
	feedback.volume *= 0.5
	check(absf(feedback.players[2].volume_db-previous_db+6.0206)<0.01,"UI volume updates an existing voice immediately")
	feedback.loading_ambience = false
	check(feedback._play_at("press",23000),"Disabling loading ambience does not disable UI cues")
	feedback.muted = true
	check(silent(feedback) and not feedback._play_at("error",24000),"Mute releases every stream and rejects new feedback")
	feedback.muted = false
	feedback.volume = 0.0
	check(silent(feedback) and not feedback._play_at("press",25000),"Zero volume is silent")
	feedback.volume = 0.55
	check(feedback._play_at("press",26000),"Feedback resumes after unmuting and restoring volume")
	feedback.enabled = false
	check(silent(feedback) and not feedback._play_at("back",27000),"Disabling feedback cancels active audio")
	var prefs = feedback.snapshot()
	var restored = Feedback.new()
	restored.restore(prefs)
	check(restored.snapshot()==prefs,"Independent UI and ambience preferences round trip")
	restored.free()
	await inspect_motion(feedback)
	await inspect_loading(feedback)
	inspect_bindings()
	feedback.queue_free()
	await process_frame
	var report = {"checks":checks,"failures":failures,"cues":audio_report,
		"listening_established":false,"rendered_acceptance_established":false,
		"note":"WAVs contain exact synthesized source PCM before UI volume and per-cue gain. Headless dispatch is silent."}
	var file = preload("res://tests/test_report.gd").open_write(OUTPUT+"/report.json")
	if file: file.store_string(JSON.stringify(report,"\t")); file.close()
	else: check(false,"Report can be written")
	print("INTERFACE_FEEDBACK_SUITE ",checks," checks, ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)

func silent(feedback) -> bool:
	for player in feedback.players:
		if player.playing or player.stream!=null: return false
	return true

func inspect_cues(feedback) -> void:
	var unique: Array[PackedByteArray] = []
	var bytes = 0
	for id in Feedback.CUE_IDS:
		var stream: AudioStreamWAV = feedback.cues[id]
		var data: PackedByteArray = stream.data
		var samples = data.size()/2
		var peak = 0
		var max_step = 0
		var previous = 0
		var sum = 0.0
		var energy = 0.0
		for i in samples:
			var sample = data.decode_s16(i*2)
			peak = maxi(peak,absi(sample))
			max_step = maxi(max_step,absi(sample-previous))
			previous = sample
			sum += sample
			energy += float(sample)*sample
		check(stream.format==AudioStreamWAV.FORMAT_16_BITS and stream.mix_rate==22050 and not stream.stereo and stream.loop_mode==AudioStreamWAV.LOOP_DISABLED,"%s is bounded mono PCM without loops" % id)
		check(stream.get_length()>=0.035 and stream.get_length()<=0.26 and peak>1000 and peak<30000,"%s is short, non-silent and has peak headroom" % id)
		check(data.decode_s16(0)==0 and data.decode_s16(data.size()-2)==0 and max_step<6000 and absf(sum/samples)<100.0,"%s has smooth endpoints and no large discontinuity or DC offset" % id)
		check(data not in unique and data==feedback._tone(id).data,"%s is distinct and deterministic" % id)
		check(stream.save_to_wav(OUTPUT+"/"+id+".wav")==OK,"%s source WAV is captured" % id)
		unique.append(data)
		bytes += data.size()
		audio_report.append({"id":id,"seconds":stream.get_length(),"peak":peak,"rms":sqrt(energy/samples),"dc":sum/samples,"max_sample_step":max_step,"gain_db":Feedback.GAINS_DB[id]})
	check(bytes<65536,"All six synthesized source streams use less than 64 KiB PCM")

func inspect_motion(feedback) -> void:
	var panel = Control.new()
	panel.size = Vector2(400,240)
	root.add_child(panel)
	var button = Button.new()
	button.text = "Live action"
	panel.add_child(button)
	button.grab_focus()
	feedback.reveal(panel)
	var obsolete: Tween = panel.get_meta("ui_tween")
	check(button.has_focus() and not button.disabled and panel.mouse_filter==Control.MOUSE_FILTER_STOP,"Reveal leaves controls and focus interactive")
	feedback.reveal(panel)
	check(not obsolete.is_valid() and feedback.active_reveals.size()==1,"Rapid reveal kills its predecessor")
	var running: Tween = panel.get_meta("ui_tween")
	feedback.reduced_motion = true
	check(not running.is_valid() and panel.modulate.a==1.0 and feedback.active_reveals.is_empty(),"Enabling reduced motion immediately cancels and settles the active fade")
	feedback.reveal(panel)
	check(panel.modulate.a==1.0 and not panel.has_meta("ui_tween"),"Reduced-motion reveals have no tween")
	feedback.reduced_motion = false
	feedback.reveal(panel)
	panel.hide()
	check(panel.modulate.a==1.0 and feedback.active_reveals.is_empty(),"Closing a panel cancels its obsolete fade immediately")
	panel.show()
	var replacement = Control.new()
	root.add_child(replacement)
	feedback.reveal(panel)
	feedback.reveal(replacement)
	check(panel.modulate.a==1.0 and not panel.has_meta("ui_tween"),"A new panel settles the previous transition")
	replacement.free()
	check(feedback.active_reveals.is_empty(),"Freeing a transitioning control leaves no retained transition")
	panel.queue_free()
	await process_frame

func inspect_loading(feedback) -> void:
	var loading = Loading.new()
	root.add_child(loading)
	loading.audio_enabled = false
	loading.configure_feedback(feedback)
	set_meta("interface_device","keyboard")
	loading.begin("Loading mountain","Preparing terrain")
	loading.set_process(false)
	loading.tip_start = 0
	loading.tip.text = Content.tip(0,"keyboard")
	var started: int = loading.started
	loading.stage("Reading scenery",42.0)
	check(loading.bar.value==42.0 and not loading.pulse.visible,"Known stage progress stays factual")
	loading._update_wait_feedback(7.99,0.0)
	check(loading.tip.text==Content.tip(0,"keyboard"),"A short wait does not rotate the tip")
	set_meta("interface_device","playstation")
	loading._update_wait_feedback(7.99,0.0)
	check("R2" in loading.tip.text and loading.tip.modulate.a==1.0 and not loading.outgoing_tip.visible and loading.started==started,"Device handoff immediately updates the binding without restarting loading")
	loading._update_wait_feedback(8.0,0.1)
	check(loading.outgoing_tip.visible and loading.tip.modulate.a<1.0,"Long waits crossfade tips")
	feedback.reduced_motion = true
	check(loading.tip.modulate.a==1.0 and not loading.outgoing_tip.visible and not loading.snow.visible and not loading.artwork.material.get_shader_parameter("animate_loading"),"Live reduced motion immediately settles loading text and atmosphere")
	loading.stage("Preparing scenery")
	check(loading.pulse.visible and loading.bar.value==0.0,"Unknown stage work has no fabricated percentage")
	var job = Job.new()
	loading.attach_job(job)
	loading.cancel_job()
	loading._process(0.0)
	check(job.is_cancelled() and loading.busy and loading.cancel_button.disabled and "Cancelling" in loading.detail.text,"Cancellation remains cooperative until the owner finishes")
	loading.finish()
	check(not loading.busy and not loading.overlay.visible and not loading.is_processing() and loading.artwork.texture==null,"Finish is synchronous with no minimum delay")
	loading.cancelled_startup()
	loading.set_process(false)
	check(loading.retry_button.visible and loading.quit_button.visible and loading.retry_button.has_focus(),"Cancelled startup retains retry, quit and readable focus")
	loading.finish()
	loading.begin("Loading mountain","Opening terrain")
	loading.set_process(false)
	var failed = Job.new()
	failed.complete("Fixture failure: terrain unavailable")
	loading.attach_job(failed)
	loading._process(0.0)
	check(loading.detail.text==failed.snapshot().error and not loading.pulse.visible,"Actual job failures are visible without a false progress pulse")
	loading.finish()
	check(failed.snapshot().error=="Fixture failure: terrain unavailable","Finish cannot erase a recorded failure")
	loading.finish()
	loading.queue_free()
	remove_meta("interface_device")
	await process_frame

func inspect_bindings() -> void:
	var router = Router.new()
	check(has_key("jump",KEY_SPACE) and has_axis("jump",JOY_AXIS_TRIGGER_RIGHT),"Hop copy matches production keyboard and trigger bindings")
	check(has_key("brake",KEY_S) and has_axis("brake",JOY_AXIS_TRIGGER_LEFT),"Brake copy matches production bindings")
	check(has_key("tuck",KEY_W) and has_axis("tuck",JOY_AXIS_LEFT_Y),"Tuck copy matches production bindings")
	check(has_key("flip_forward",KEY_I) and has_key("flip_backward",KEY_K),"Flip copy matches production keyboard bindings")
	check(has_key("camera_mode",KEY_C) and has_button("camera_mode",JOY_BUTTON_RIGHT_SHOULDER),"Camera copy matches production keyboard and shoulder bindings")
	for device in ["keyboard","playstation","xbox","gamepad","unknown"]:
		for i in Content.COUNT:
			check(not Content.tip(i,device).is_empty() and Content.tip(i,device).length()<=120,"Tip %d has bounded readable copy for %s" % [i,device])
	check("RT" in Content.tip(0,"xbox") and "right trigger" in Content.tip(0,"gamepad") and Content.tip(0,"unknown")==Content.tip(0,"keyboard"),"Xbox, generic and unknown-device fallbacks are explicit")
	router.cancel_air_input()

func has_key(action: String, code: Key) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey and event.physical_keycode==code: return true
	return false

func has_axis(action: String, axis: JoyAxis) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadMotion and event.axis==axis: return true
	return false

func has_button(action: String, button: JoyButton) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadButton and event.button_index==button: return true
	return false

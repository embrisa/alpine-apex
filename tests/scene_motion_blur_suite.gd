extends SceneTree
const Blur = preload("res://scripts/presentation/scene_motion_blur.gd")
const Settings = preload("res://scripts/presentation/camera_settings.gd")
var checks = 0
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, caption: String) -> void:
	checks += 1
	if not ok: failures.append(caption); printerr("FAIL: ",caption)

func run() -> void:
	var settings = Settings.new()
	for view in Settings.VIEWS:
		for preset in Settings.BUILT_INS:
			var profile = Settings.defaults(view,preset)
			check(not profile.motion_blur_enabled,"Every built-in keeps scene blur Off")
			check(profile.motion_blur_strength==(0.0 if preset=="Stable" else 50.0),"Explicit retained strength overrides Race's broad loop")
			check(profile.blur_strength==({"Connected":50.0,"Race":100.0,"Stable":0.0}[preset]),"Peripheral defaults remain independent")
	settings.update_profile("chase",{"motion_blur_enabled":true,"motion_blur_strength":73.0})
	settings.save_preset("chase","Blur test")
	settings.set_value("chase","motion_blur_enabled",false)
	check(settings.profile("chase").motion_blur_strength==73.0,"Off retains strength")
	check(settings.profile("first_person").motion_blur_strength==50.0 and not settings.profile("first_person").motion_blur_enabled,"Views save independently")
	var path = "user://motion_blur_test_%d.cfg" % Time.get_ticks_usec()
	check(settings.save_preferences(path)==OK,"Isolated preferences save")
	var restored = Settings.new(); restored.load_preferences(path)
	check(restored.snapshot()==settings.snapshot(),"Toggle, retained strength and named preset round trip")
	restored.apply_preset("chase","Blur test")
	check(restored.profile("chase").motion_blur_enabled and restored.profile("chase").motion_blur_strength==73.0,"Named preset restores both controls")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	for value in [NAN,INF,-INF,"bad",true,{},[]]:
		restored.set_value("chase","motion_blur_strength",value)
	check(restored.profile("chase").motion_blur_strength==73.0,"Malformed/nonfinite strength retains valid state")
	for value in [1,0,NAN,"on"]: restored.set_value("chase","motion_blur_enabled",value)
	check(restored.profile("chase").motion_blur_enabled,"Toggle requires an actual bool")
	restored.reset_view("chase")
	check(not restored.profile("chase").motion_blur_enabled and restored.presets.chase.has("Blur test"),"Reset disables blur and retains named presets")
	var p = {"motion_blur_enabled":true,"motion_blur_strength":50.0}
	check(Blur.requested_strength(p,true,true,false)==0.5,"Medium strength reaches presentation")
	for args in [[false,true,false],[true,false,false],[true,true,true]]:
		check(Blur.requested_strength(p,args[0],args[1],args[2])==0.0,"Inactive, V and reduced motion bypass")
	for value in [0.0,NAN,INF,"bad"]:
		check(Blur.requested_strength({"motion_blur_enabled":true,"motion_blur_strength":value},true,true,false)==0.0,"Zero and invalid values bypass")
	for hz in [30.0,60.0,90.0,120.0,240.0]:
		check(is_equal_approx((1.0/hz)*Blur.exposure_scale(1.0,1.0/hz),1.0/120.0),"Exposure length is independent of rendered cadence")
	for dt in [0.0,-1.0,NAN,INF,0.11]: check(Blur.exposure_scale(1.0,dt)==0.0,"Invalid cadence and stalls suppress blur")
	var effect = Blur.new()
	check(not effect.enabled and not effect.needs_motion_vectors and not effect.access_resolved_color and not effect.access_resolved_depth,"Default Off requests no blur-only GPU work")
	effect.update_state(p,true,true,false,1.0/60.0,[])
	if DisplayServer.get_name()=="headless":
		check(not effect.enabled and not effect.status().unavailable.is_empty(),"Unsupported backend is honestly unavailable")
	# Exercise scheduling independently of a GPU, then use real main ownership.
	effect._report.unavailable = ""
	effect.update_state(p,true,true,false,1.0/60.0,["chase"])
	check(effect.enabled and effect.needs_motion_vectors,"Enabled scheduler requests velocity")
	var epoch: int = effect._state.epoch
	effect.update_state(p,true,true,false,1.0/60.0,["first_person"])
	check(effect._state.epoch>epoch,"View/configuration changes invalidate rendered history")
	effect.suspend()
	check(not effect.enabled and not effect.needs_motion_vectors and not effect.access_resolved_color and not effect.access_resolved_depth,"Suspend removes every blur-only request")
	set_meta("test_map_fixture","smooth-slope")
	var game = load("res://main.tscn").instantiate()
	game.automated = true
	root.add_child(game)
	while not game.initialized or game.loading.busy: await process_frame
	game.set_process(false); game.set_physics_process(false)
	game.effects.muted = true; game.hud.feedback.muted = true
	game.hud.feedback.reduced_motion = false
	game.scene_motion_blur._report.unavailable = ""
	game.camera_settings.update_profile("chase",p)
	game.camera.close_view = false
	game.start_run(false)
	game.session.eligible = false
	game.summit_ready = false
	game.active = true
	game.application_focused = true
	game.presentation_camera = game.camera
	game._update_screen_effects(1.0/60.0)
	check(game.scene_motion_blur.enabled,"Main enables selected riding profile")
	check(game.camera.compositor.compositor_effects==[game.scene_motion_blur] and game.camera_preview.compositor==null and game.menu_camera.compositor==null,"Only riding camera owns the blur")
	var unchanged = [game.sim.position,game.sim.velocity,game.session.elapsed,game.session.eligible]
	for gate in ["reduced","optional","focus","loading","crash","transition","preview","menu","inactive"]:
		match gate:
			"reduced": game.hud.feedback.reduced_motion = true
			"optional": game.camera.effects_enabled = false
			"focus": game.application_focused = false
			"loading": game.loading.busy = true
			"crash": game.sim.crashed = true
			"transition": game.transitioning = true
			"preview": game.hud.camera_options.preview_active = true
			"menu": game.hud.menu.show()
			"inactive": game.active = false
		game._update_screen_effects(1.0/60.0)
		check(not game.scene_motion_blur.enabled and not game.scene_motion_blur.needs_motion_vectors,gate+" suppresses blur immediately")
		game.hud.feedback.reduced_motion = false; game.camera.effects_enabled = true
		game.application_focused = true; game.loading.busy = false; game.sim.crashed = false
		game.transitioning = false; game.hud.camera_options.preview_active = false
		game.hud.menu.hide(); game.active = true; game.presentation_camera = game.camera
	game.camera.close_view = true
	game._update_screen_effects(1.0/60.0)
	check(not game.scene_motion_blur.enabled,"First person uses its independently Off profile")
	check(unchanged==[game.sim.position,game.sim.velocity,game.session.elapsed,game.session.eligible],"Effect lifecycle does not advance simulation/session/eligibility")
	var ui = game.hud.camera_options
	check(ui.controls.motion_blur_enabled is CheckButton and ui.controls.motion_blur_strength is HSlider,"Both typed controls exist")
	check(ui.controls.motion_blur_enabled.focus_mode==Control.FOCUS_ALL and ui.controls.motion_blur_strength.focus_mode==Control.FOCUS_ALL,"Controller focus reaches both controls")
	game.automated = false
	ui.controls.motion_blur_enabled.toggled.emit(true)
	ui.controls.motion_blur_strength.value_changed.emit(39.0)
	check(game.camera_settings.profile(ui.view).motion_blur_enabled and game.camera_settings.profile(ui.view).motion_blur_strength==39.0,"UI signals update the working profile live")
	game.scene_motion_blur.suspend()
	game.effects.stop_audio(); game.queue_free(); await process_frame
	DirAccess.make_dir_recursive_absolute("res://artifacts/scene_motion_blur")
	var report = {"checks":checks,"failures":failures,"rendered":false}
	FileAccess.open("res://artifacts/scene_motion_blur/settings_lifecycle.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("SCENE_MOTION_BLUR_RESULTS ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)

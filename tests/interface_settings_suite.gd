extends SceneTree
const Settings = preload("res://scripts/presentation/pc_graphics_settings.gd")
const Presets = preload("res://scripts/presentation/graphics_presets.gd")
const Profile = preload("res://scripts/presentation/graphics_quality.gd")
var failures: Array[String] = []
var checks = 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	print("PASS: " if ok else "FAIL: ",label)
	if not ok: failures.append(label)
func run() -> void:
	var settings = Settings.new()
	settings.display.restore({"display_mode":"windowed","fps_limit":90,"resolution":Vector2i(1280,720)})
	settings.frame_generation = true
	var output = settings.display.snapshot()
	var configurations = []
	for id in range(1,11):
		settings.select_preset(id)
		var profile = settings.profile()
		check(profile.snapshot() not in configurations,"Preset %d has distinct effective budgets" % id)
		configurations.append(profile.snapshot())
		check(profile.level in [0,1,2] and profile.texture_tier in [0,1,2] and profile.snow_particles.x<=640 and profile.snow_track_capacity<=Presets.MAX_TRACK_HISTORY,"Preset %d bounds asset indices and GPU budgets" % id)
		check(settings.display.snapshot()==output and settings.frame_generation,"Preset %d preserves output and explicit frame generation" % id)
	for tier in 3: check(Profile.preset(tier).snapshot()==Profile.numbered([1,4,7][tier]).snapshot(),"Named asset anchor %d uses the numbered table" % tier)
	settings.select_preset(7)
	settings.set_graphics_value("spray_budget",512)
	settings.set_graphics_value("terrain_gi",true)
	check(settings.custom and settings.profile().snow_particles.x==512 and settings.profile().terrain_gi,"Same-preset overrides produce effective Custom settings")
	settings.set_graphics_value("tree_near_m",160.0)
	settings.set_graphics_value("tree_mid_m",80.0)
	check(settings.profile().tree_mid_m>settings.profile().tree_near_m,"Arbitrary overrides cannot invert LOD transitions")
	settings.reset_group("Snow & particles")
	check(settings.profile().snow_particles.x==384 and settings.terrain_gi,"Group reset preserves other graphics groups")
	settings.set_graphics_value("snow_track_capacity",999999)
	settings.set_graphics_value("snow_sparkle",NAN)
	check(settings.profile().snow_track_capacity==Presets.MAX_TRACK_HISTORY and settings.profile().snow_sparkle==9.0,"Malformed graphics values are bounded or rejected")
	var path = "user://overhaul_settings_test.cfg"
	check(settings.save_preferences(path)==OK,"Versioned stores save atomically to isolated paths")
	var restored = Settings.new()
	restored.load_preferences(path)
	check(restored.snapshot()==settings.snapshot(),"Graphics overrides and separate output store survive a fresh instance")
	check(not Settings.Store.read_values(path,2).has("display_mode") and not Settings.Store.read_values(path+".display",1).has("quality"),"Physical files preserve settings domain ownership")
	settings.display.begin_preview({"resolution":Vector2i(1920,1080)},100)
	check(not settings.display.expired(15099) and settings.display.expired(15100),"Disruptive output changes have a 15-second recovery deadline")
	settings.display.revert()
	check(settings.display.snapshot()==output,"Revert restores all prior output values")
	settings.display.begin_preview({"fps_limit":144},200)
	settings.display.keep()
	check(settings.fps_limit==144 and not settings.display.expired(50000),"Keep accepts the display transaction once")
	for key in Presets.CONTROLS:
		var row: Array = Presets.CONTROLS[key]
		settings.set_graphics_value(key,row[3])
		check(settings.profile().get(key)==row[3],"Advanced property %s reaches the effective profile" % key)
	check_display_transactions()
	check_output_plans()
	print("INTERFACE_SETTINGS_RESULTS ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)

func check_display_transactions() -> void:
	var Display = Settings.Output
	var output = Display.new()
	output.restore({"display_mode":"windowed","monitor":-1,"resolution":Vector2i(1280,720),"vsync":1,"fps_limit":90})
	var preferences = output.snapshot()
	# Detached Window stores real Window properties without touching an OS screen.
	# In particular current_screen can represent a second monitor in headless CI.
	var window = Window.new()
	window.current_screen = 2
	window.position = Vector2i(-1840,137)
	window.size = Vector2i(1280,720)
	window.borderless = false
	var actual = Display.capture_window(window)
	var previous_cap = Engine.max_fps
	output.begin_preview({"display_mode":"fullscreen","monitor":0,"resolution":Vector2i(1920,1080),"fps_limit":144,"vsync":0},100,window)
	window.current_screen = 0
	window.position = Vector2i.ZERO
	window.size = Vector2i(3840,2160)
	window.borderless = true
	window.mode = Window.MODE_FULLSCREEN
	var path = "user://overhaul_display_transaction_test.cfg"
	check(output.save_preferences(path)==OK and Settings.Store.read_values(path,1)==preferences,"Saving during preview persists the complete original preference set only")
	var reloaded = Display.new()
	reloaded.load_preferences(path)
	check(reloaded.snapshot()==preferences and reloaded.pending.is_empty(),"A fresh instance cannot inherit an unconfirmed display transaction")
	output.begin_preview({"resolution":Vector2i(2560,1440),"fps_limit":165},300,window)
	check(output.display_mode==preferences.display_mode and output.pending==preferences,"Replacement preview starts from the original complete preference snapshot")
	check(not output.expired(15299) and output.expired(15300),"Replacement preview renews its recovery deadline")
	output.revert()
	check(output.snapshot()==preferences and output.pending.is_empty(),"Timeout/Revert atomically restores mode, resolution, automatic monitor, synchronization and frame cap")
	check(output.save_preferences(path)==OK and Settings.Store.read_values(path,1)==preferences,"Queued actual-window rollback never enters persistence")
	output.apply(window,Vector2i(640,480),true)
	check(Display.capture_window(window)==actual and Engine.max_fps==90,"Revert restores the original automatic screen and exact geometry ahead of explicit output overrides")
	window.position += Vector2i(20,30)
	var moved = Display.capture_window(window)
	output.revert()
	output.apply(window)
	check(Display.capture_window(window)==moved,"Rollback is consumed once; repeated Revert/apply cannot replay stale geometry")
	output.begin_preview({"fps_limit":144},500,window)
	window.position += Vector2i(10,10)
	output.keep()
	var kept = Display.capture_window(window)
	output.revert()
	output.apply(window)
	check(output.fps_limit==144 and Display.capture_window(window)==kept and not output.expired(99999),"Keep clears the transaction and prevents a later Revert from undoing it")
	check(output.save_preferences(path)==OK and Settings.Store.read_values(path,1)==output.snapshot(),"Keep persists the accepted settings without transient window geometry")
	# A new preview can arrive before the parent's queued rollback apply.
	for mode in [Window.MODE_WINDOWED,Window.MODE_FULLSCREEN]:
		window.mode = mode
		window.borderless = true
		var baseline = Display.capture_window(window)
		output.begin_preview({"fps_limit":60},600,window)
		window.current_screen = 1
		window.position = Vector2i(4000,80)
		output.revert()
		output.begin_preview({"fps_limit":240},700,window)
		output.revert()
		output.apply(window)
		var recovered = Display.capture_window(window)
		# A detached Window has no OS to supply fullscreen geometry. Native tests
		# verify those pixels; here fullscreen recovery owns screen/mode/borderless.
		var restored_geometry = recovered==baseline if mode==Window.MODE_WINDOWED else recovered.screen==baseline.screen and recovered.mode==baseline.mode and recovered.borderless==baseline.borderless
		check(restored_geometry,"Unapplied rollback survives a replacement transaction for actual window mode %d" % mode)
	Engine.max_fps = previous_cap
	window.free()

func check_output_plans() -> void:
	var output = Settings.Output.new()
	var native_pixels = Vector2i(3840,2160)
	var origin = Vector2i(-3840,0)
	output.resolution = Vector2i(1280,720)
	var fullscreen = output.window_plan(native_pixels,origin)
	check(fullscreen.size==native_pixels and fullscreen.position==origin and fullscreen.mode==Window.MODE_FULLSCREEN,"Fullscreen ignores the saved window resolution and uses native display pixels")
	check(output.choices(null)==[Vector2i.ZERO],"Fullscreen resolution choices are native only")
	var exact = output.window_plan(native_pixels,origin,Vector2i.ZERO,true)
	check(exact.size==native_pixels and exact.position==origin and exact.mode==Window.MODE_WINDOWED and exact.borderless,"Native DX12 FG output remains exactly sized borderless windowed")
	output.display_mode = "windowed"
	output.resolution = native_pixels
	var windowed = output.window_plan(native_pixels,origin)
	check(windowed.size==native_pixels and windowed.position==origin and windowed.mode==Window.MODE_WINDOWED and windowed.borderless,"Native-sized Windowed remains windowed with exact client pixels")
	for mode in ["windowed","fullscreen"]:
		output.display_mode = mode
		for fixture in [Vector2i(1280,720),Vector2i(1440,900),Vector2i(1920,1080),Vector2i(3440,1440),native_pixels]:
			for exact_output in [false,true]:
				var plan = output.window_plan(native_pixels,origin,fixture,exact_output)
				var expected_mode = Window.MODE_FULLSCREEN if mode=="fullscreen" and fixture==native_pixels and not exact_output else Window.MODE_WINDOWED
				check(plan.size==fixture and plan.position==origin+(native_pixels-fixture)/2 and plan.mode==expected_mode and plan.borderless,"Explicit %s fixture %s exact=%s retains output dimensions and mode" % [mode,fixture,exact_output])
	output.display_mode = "windowed"
	output.resolution = Vector2i(1280,720)
	var small = output.window_plan(native_pixels,origin)
	check(small.size==output.resolution and small.mode==Window.MODE_WINDOWED and not small.borderless,"Ordinary Windowed resolution remains a decorated centered client area")

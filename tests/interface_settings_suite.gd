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
		check(profile.level in [0,1,2] and profile.texture_tier in [0,1,2] and profile.snow_particles.x<=640 and profile.snow_track_capacity<=6144,"Preset %d bounds asset indices and GPU budgets" % id)
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
	check(settings.profile().snow_track_capacity==6144 and settings.profile().snow_sparkle==9.0,"Malformed graphics values are bounded or rejected")
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
	print("INTERFACE_SETTINGS_RESULTS ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)

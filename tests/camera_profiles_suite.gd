extends SceneTree
const Settings = preload("res://scripts/presentation/camera_settings.gd")
var checks = 0
var failures: Array[String] = []
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message); printerr("FAIL: ",message)
func _initialize() -> void:
	var settings = Settings.new()
	for view in Settings.VIEWS:
		check(settings.selected[view]=="Connected","Connected is the default")
		for name in Settings.BUILT_INS:
			check(settings.apply_preset(view,name),"Built-in applies")
			var previous = -1.0
			for speed in range(0,301):
				var blend = Settings.speed_factor(speed,settings.profile(view))
				check(blend>=previous and blend<=1,"Curve is monotonic and bounded")
				previous = blend
			check(settings.framing(view,0).x==(55 if name=="Connected" else 60),"Rest lens matches preset")
			check(settings.framing(view,200).x==({"Connected":75,"Race":80,"Stable":60}[name]),"Fast lens matches preset")
	settings.reset()
	check(absf(Settings.speed_factor(120,settings.profile("chase"))-.4416131537)<.00001,"120 km/h retains meaningful framing headroom")
	check(absf(Settings.speed_factor(160,settings.profile("chase"))-.6997517273)<.00001,"160 km/h is only 70 percent")
	var first_before: Dictionary = settings.profile("first_person").duplicate()
	var shared_before = settings.shared.duplicate()
	settings.update_profile("chase",{"rest_fov":65,"rest_tilt":-51})
	check(settings.selected.chase=="Custom" and settings.profile("first_person")==first_before,"Edits only affect the selected view")
	check(settings.save_preset("chase","My camera"),"Save a named preset")
	check(not settings.save_preset("chase","My camera"),"Save does not overwrite")
	var saved = settings.presets.chase["My camera"].duplicate()
	settings.update_profile("chase",{"rest_fov":69})
	check(settings.presets.chase["My camera"]==saved and settings.selected.chase=="Custom","Working edits leave saved preset immutable")
	check(settings.save_preset("chase","My camera",true),"Explicit replace succeeds")
	check(settings.rename_preset("chase","My camera","Snow view"),"Rename succeeds")
	check(settings.selected.chase=="Snow view","Rename follows selected preset")
	settings.apply_preset("chase","Race")
	check(settings.shared==shared_before,"Preset never changes shared preferences")
	check(settings.apply_preset("chase","Snow view") and settings.profile("chase").rest_fov==69,"Named preset can be restored")
	settings.reset_view("chase")
	check(settings.presets.chase.has("Snow view") and settings.profile("chase")==Settings.defaults("chase"),"Reset view retains saved presets")
	settings.reset()
	check(settings.presets.chase.has("Snow view"),"Reset all retains saved presets")
	for name in ["","  ","Connected","Race","Stable","Custom","bad\nname","a".repeat(41)]:
		check(not settings.save_preset("chase",name),"Reject reserved or malformed preset name")
	for view in Settings.VIEWS:
		for key in Settings.DEFAULTS:
			var bounds: Vector3 = Settings.RANGES[key]
			settings.set_value(view,key,-9999)
			check(settings.value(view,key)>=bounds.x,"Lower bounds are enforced: "+key)
			settings.set_value(view,key,9999)
			check(settings.value(view,key)<=bounds.y,"Upper bounds are enforced: "+key)
		settings.reset_view(view)
		var before = settings.profile(view).duplicate()
		for key in before:
			for invalid in [NAN,INF,-INF,"wrong",true,{},[]]: settings.set_value(view,key,invalid)
		check(before==settings.profile(view),"Invalid values cannot damage live profile")
		settings.update_profile(view,{"speed_start":250,"speed_full":100})
		check(settings.profile(view).speed_full==251,"Start and full speed cannot cross")
		settings.update_profile(view,{"rest_fov":80,"fast_fov":50})
		check(settings.framing(view,300).x==50,"Descending lens endpoints are supported")
	settings.reset()
	settings.set_value("shared","invert_y",true)
	settings.set_value("shared","auto_recenter",false)
	settings.set_value("shared","mouse_sensitivity",.27)
	var snapshot = settings.snapshot()
	var restored = Settings.new()
	restored.restore(snapshot)
	check(restored.snapshot()==snapshot,"Both profiles, shared controls and named presets round-trip")
	var previous_fields = settings.snapshot()
	for view in Settings.VIEWS:
		previous_fields.profiles[view].erase("slope_follow")
		previous_fields.profiles[view].erase("slope_smoothing")
	restored.restore(previous_fields)
	check(restored.snapshot()==settings.snapshot(),"Added slope controls receive defaults without discarding existing v2 working profiles or named presets")
	snapshot.profiles.chase.rest_fov = 120
	check(settings.profile("chase").rest_fov==55,"Snapshots are independent copies")
	var path = "user://camera_profiles_test_%d.cfg" % Time.get_ticks_usec()
	check(settings.save_preferences(path)==OK,"Save isolated preferences")
	restored = Settings.new()
	restored.load_preferences(path)
	check(restored.snapshot()==settings.snapshot(),"ConfigFile preserves typed values and named presets")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	for malformed in [{"version":1},{"version":2,"profiles":[],"selected":true,"presets":false,"shared":"bad"},{"version":2,"profiles":{"chase":{"rest_fov":INF}}}]:
		restored = Settings.new()
		restored.restore(malformed)
		check(restored.profile("chase")==Settings.defaults("chase"),"Malformed or obsolete config leaves safe defaults")
	check(settings.delete_preset("chase","Snow view"),"Delete removes saved preset")
	check(not settings.delete_preset("chase","Connected"),"Built-ins cannot be deleted")
	print("CAMERA_PROFILES_RESULTS ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)

extends SceneTree
const Sight = preload("res://scripts/presentation/foliage_sight.gd")
const Assets = preload("res://scripts/presentation/alpine_assets.gd")
const Clouds = preload("res://scripts/presentation/cloud_lighting.gd")
const Quality = preload("res://scripts/presentation/graphics_quality.gd")
const Preferences = preload("res://scripts/presentation/camera_settings.gd")
var checks = 0
var failures = []
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr("FAIL ",label)
func _initialize() -> void: call_deferred("run")
func settle(sight, camera: Camera3D, riding: bool, reach: float, strength: float) -> void:
	for frame in 100: sight.update(camera,Vector3.ZERO,1.0/60,riding,reach,strength)
func run() -> void:
	var camera = Camera3D.new(); root.add_child(camera); camera.current = true
	var sight = Sight.new()
	for reach in [1.0,60.0,100.0]:
		for pose in [Vector3(0,1.7,0),Vector3(0,7,-8),Vector3(0,20,-20)]:
			camera.position = pose; camera.look_at(Vector3(0,.5,12))
			settle(sight,camera,true,reach,100)
			var expected_depth = clampf(pose.length()+lerpf(8,18,reach/100),8,28)
			check(is_equal_approx(sight.parameters.z,expected_depth),"Reach retains the existing distance mapping")
			var limits = Vector2(sight.parameters.y,sight.parameters.z)
			for strength in [0.0,25.0,50.0,75.0,100.0]:
				settle(sight,camera,true,reach,strength)
				check(sight.parameters.x==1.0,"Activation settles without perpetual flicker")
				check(sight.parameters.w==strength/100.0,"Strength sets independent normalized removal")
				check(Vector2(sight.parameters.y,sight.parameters.z)==limits,"Strength leaves depth unchanged")
	camera.position = Vector3(0,1.7,0)
	settle(sight,camera,true,100,50)
	var far_depth = sight.parameters.z
	sight.update(camera,Vector3.ZERO,1.0/60,true,10,50)
	check(sight.parameters.z<far_depth and sight.parameters.w==.5,"Reach changes distance without changing strength")
	sight.update(camera,Vector3.ZERO,1.0/60,true,0,50)
	check(sight.parameters.x==0.0 and sight.parameters.w==.5,"Zero reach disables removal immediately and retains strength")
	settle(sight,camera,true,60,50)
	sight.update(camera,Vector3.ZERO,1.0/60,true,60,0)
	check(sight.parameters.x*sight.parameters.w==0.0,"Zero strength restores foliage immediately")
	settle(sight,camera,true,60,50)
	sight.update(camera,Vector3.ZERO,1.0/60,false,60,50)
	check(sight.parameters.x<1.0 and sight.parameters.x>0.0,"Menus restore foliage gradually")
	settle(sight,camera,false,60,50)
	check(sight.parameters.x==0.0 and sight.parameters.w==.5,"Menus finish opaque and retain selected strength")
	settle(sight,camera,true,60,50)
	check(sight.parameters.x==1.0 and sight.parameters.w==.5,"Riding resumes the selected strength")
	sight.update(camera,Vector3(100,0,100),0.0,true,60,50)
	check(sight.parameters.x==0.0 and sight.parameters.w==.5,"Teleport resets activation without resetting strength")
	settle(sight,null,true,60,50)
	check(sight.parameters.x==0.0,"Missing camera disables the aid")
	for invalid in [INF,-INF,NAN]:
		sight.update(camera,Vector3.ZERO,invalid,true,invalid,invalid)
		check(sight.parameters.is_finite(),"Nonfinite API input cannot poison shader state")
	sight.update(camera,Vector3.ZERO,.1,true,-4,125)
	check(sight.parameters.x==0.0 and sight.parameters.w==1.0,"API clamps reach and strength")
	sight.update(camera,Vector3.ZERO,.1,true,101,-5)
	check(sight.parameters.w==0.0,"API clamps strength off")
	var library = Assets.new(Clouds.new(),Quality.preset(2))
	library.update_foliage_sight(camera,Vector3.ZERO,.1,true,60,25)
	var far = library.mesh("forest_spruce_01_lod2").surface_get_material(0)
	check(far.get_shader_parameter("foliage_sight_parameters")==library.foliage_sight.parameters,"Late fallback material inherits current strength")
	var near = library.mesh("forest_spruce_01_lod0").surface_get_material(0)
	var middle = library.mesh("forest_spruce_01_lod1").surface_get_material(0)
	check(near!=middle,"Middle shading has a separate material")
	check(near.shader.resource_path.ends_with("pc_forest_tree.gdshader") and middle.shader.resource_path.ends_with("pc_forest_tree_mid.gdshader"),"Only middle detail selects mesh-normal shading")
	var broadleaf = library.mesh("forest_golden_01_lod1").surface_get_material(0)
	check(broadleaf!=middle and broadleaf.get_shader_parameter("broadleaf")==true,"Broadleaf middle retains its leaf material role")
	for receiver in [middle,broadleaf]:
		check(receiver in library.wind_receivers and receiver in library.sight_receivers,"Middle material participates in wind and sight updates")
	var motion=preload("res://scripts/presentation/tree_motion.gd").new(library,"")
	motion.reset()
	for receiver in [near,middle,broadleaf]:
		check(receiver.get_shader_parameter("contact_active")==false,"Resting branches skip contact lookups")
	motion.anchors[0]=Vector4(1,2,3,1); motion.angles[0]=Vector4(.1,0,0,0); motion._upload()
	for receiver in [near,middle,broadleaf]:
		check(receiver.get_shader_parameter("contact_active")==true and receiver.get_shader_parameter("contact_angles")==motion.angles,"Branch response reaches both detail materials")
	for strength in [0.0,25.0,50.0,75.0,100.0]:
		library.update_foliage_sight(camera,Vector3.ZERO,.1,true,60,strength)
		for receiver in [near,middle,broadleaf,far]:
			check(receiver.get_shader_parameter("foliage_sight_parameters")==library.foliage_sight.parameters,"Resident/fallback materials receive each strength")
		for level in 3:
			library.apply_quality(Quality.preset(level))
			for receiver in [near,middle,broadleaf,far]:
				check(receiver.get_shader_parameter("foliage_sight_parameters")==library.foliage_sight.parameters,"Quality switch retains current strength")
			check(middle.get_shader_parameter("foliage_texture")==near.get_shader_parameter("foliage_texture"),"Middle quality uses the matching foliage texture")
			check(broadleaf.get_shader_parameter("broadleaf")==true,"Quality switch retains the broadleaf role")
	var bare = library.mesh("forest_birch_01_lod2").surface_get_material(0)
	check(not bare in library.sight_receivers,"Bare distant crowns remain excluded")
	var preferences = Preferences.new()
	check(preferences.shared.forest_visibility==60 and preferences.shared.forest_visibility_strength==100,"Shared defaults retain reach and use maximum transparency")
	check(Preferences.RANGES.forest_visibility_strength==Vector3(0,100,1),"Strength uses one-percent increments")
	for key in ["forest_visibility","forest_visibility_strength"]:
		preferences.set_value("shared",key,-5); check(preferences.shared[key]==0,"Preference clamps off: "+key)
		for invalid in [INF,-INF,NAN,"25",null]:
			preferences.set_value("shared",key,invalid)
			check(preferences.shared[key]==0,"Invalid preference retains valid value: "+key)
		preferences.set_value("shared",key,101); check(preferences.shared[key]==100,"Preference clamps maximum: "+key)
		preferences.set_value("shared",key,25.4); check(preferences.shared[key]==25,"Preference snaps to one percent: "+key)
	preferences.set_value("shared","forest_visibility",42)
	preferences.set_value("shared","forest_visibility_strength",75)
	var path = "user://foliage_strength_%d_%d.cfg" % [OS.get_process_id(),Time.get_ticks_usec()]
	check(preferences.save_preferences(path)==OK,"Isolated preferences save")
	var restored = Preferences.new(); restored.load_preferences(path)
	check(restored.shared.forest_visibility==42 and restored.shared.forest_visibility_strength==75,"Reach and strength roundtrip independently")
	for view in Preferences.VIEWS:
		restored.apply_preset(view,"Stable"); restored.reset_view(view)
		check(restored.shared==preferences.shared,"View presets/reset leave shared strength untouched")
	var old_data = preferences.snapshot()
	old_data.shared.erase("forest_visibility_strength"); old_data.shared.forest_visibility_size = 20
	restored.restore(old_data)
	check(restored.shared.forest_visibility==42 and restored.shared.forest_visibility_strength==100,"Old opening size is ignored; strength uses its default")
	check(not restored.set_value("shared","forest_visibility_size",100),"Removed preference is rejected")
	check(restored.save_preferences(path)==OK,"Current output replaces old size data")
	var saved = ConfigFile.new(); saved.load(path)
	check(not saved.get_value("camera","data").shared.has("forest_visibility_size"),"Saved output has no old size field")
	restored.reset()
	check(restored.shared.forest_visibility==60 and restored.shared.forest_visibility_strength==100,"Reset-all restores both defaults")
	DirAccess.remove_absolute(path)
	print("FOLIAGE_SIGHT_RESULTS ",JSON.stringify({"checks":checks,"failures":failures,"gpu_removal_unverified":true}))
	camera.free(); quit(0 if failures.is_empty() else 1)

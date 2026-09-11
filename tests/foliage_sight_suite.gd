extends SceneTree
const Sight=preload("res://scripts/presentation/foliage_sight.gd")
const Assets=preload("res://scripts/presentation/alpine_assets.gd")
const Clouds=preload("res://scripts/presentation/cloud_lighting.gd")
const Quality=preload("res://scripts/presentation/graphics_quality.gd")
const Preferences=preload("res://scripts/presentation/camera_settings.gd")
var checks=0
var failures=[]
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label); printerr("FAIL ",label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var camera=Camera3D.new(); root.add_child(camera); camera.current=true
	var sight=Sight.new()
	for strength in [1.0,60.0,100.0]:
		for pose in [Vector3(0,1.7,0),Vector3(0,7,-8),Vector3(0,20,-20)]:
			camera.position=pose; camera.look_at(Vector3(0,.5,12))
			for frame in 100: sight.update(camera,Vector3.ZERO,Vector3(0,0,25),1.0/60,true,strength)
			check(sight.parameters.x==1.0,"Aid settles without perpetual flicker")
			check(sight.window.x-sight.window.z>=.009 and sight.window.x+sight.window.z<=.991 and sight.window.y-sight.window.w>=.009 and sight.window.y+sight.window.w<=.991,"Narrow screen border stays untouched at all strengths and camera poses")
			if strength>=60:
				# Area of the fully clear fourth-power superellipse, before depth fading.
				var clear_area=4.0*sight.window.z*sight.window.w*.86*.86*.92703734
				check(clear_area>.5,"Default size fully clears a majority of nearby screen coverage")
			check(sight.parameters.z<=28.0 and sight.parameters.y<sight.parameters.z,"Visibility aid has bounded forward depth")
	camera.position=Vector3(0,1.7,0)
	sight.update(camera,Vector3.ZERO,Vector3(0,0,25),1.0/60,true,100)
	var prior_depth=sight.parameters.z
	for coverage in [20.0,50.0,88.0,100.0]:
		sight.update(camera,Vector3.ZERO,Vector3(0,0,25),1.0/60,true,100,coverage)
		check(is_equal_approx(sight.window.z*200,coverage) and sight.parameters.z==prior_depth,"Size changes screen coverage without changing reach")
	var prior_size=Vector2(sight.window.z,sight.window.w)
	sight.update(camera,Vector3.ZERO,Vector3(0,0,25),1.0/60,true,10,100)
	check(Vector2(sight.window.z,sight.window.w)==prior_size and sight.parameters.z<prior_depth,"Reach changes independently of opening size")
	var enabled=sight.parameters.x
	sight.update(camera,Vector3.ZERO,Vector3.ZERO,1.0/60,false,60)
	check(sight.parameters.x<enabled and sight.parameters.x>0.0,"Leaving skiing restores foliage gradually")
	for frame in 100: sight.update(camera,Vector3.ZERO,Vector3.ZERO,1.0/60,false,60)
	check(sight.parameters.x==0.0,"Menus finish with full foliage")
	for frame in 100: sight.update(camera,Vector3.ZERO,Vector3.ZERO,1.0/60,true,0)
	check(sight.parameters.x==0.0,"Zero strength disables the aid")
	for frame in 100: sight.update(camera,Vector3.ZERO,Vector3.ZERO,1.0/60,true,60)
	sight.update(camera,Vector3(100,0,100),Vector3.ZERO,0.0,true,60)
	check(sight.parameters.x==0.0,"Teleport discards the old opening")
	var library=Assets.new(Clouds.new(),Quality.preset(2))
	library.update_foliage_sight(camera,Vector3.ZERO,Vector3(0,0,20),.1,true)
	var far=library.mesh("forest_spruce_01_lod2").surface_get_material(0)
	check(far.get_shader_parameter("foliage_sight_parameters")==library.foliage_sight.parameters,"Late streamed material receives the current aid state")
	var near=library.mesh("forest_spruce_01_lod0").surface_get_material(0)
	var middle=library.mesh("forest_spruce_01_lod1").surface_get_material(0)
	check(near==middle,"Near and middle share the visibility material")
	library.update_foliage_sight(camera,Vector3.ZERO,Vector3(0,0,20),.1,true,60,40)
	for receiver in [near,far]:
		var updated: Vector4=receiver.get_shader_parameter("foliage_sight_window")
		check(is_equal_approx(updated.z,.2),"Size updates reach both resident and fallback materials")
	for level in 3:
		library.apply_quality(Quality.preset(level))
		check(near.get_shader_parameter("foliage_sight_parameters")==library.foliage_sight.parameters,"Quality switching preserves aid state")
	var bare=library.mesh("forest_birch_01_lod2").surface_get_material(0)
	check(not bare in library.sight_receivers,"Bare distant crowns are excluded")
	var preferences=Preferences.new()
	preferences.restore({"forest_visibility":-5}); check(preferences.forest_visibility==0,"Aid preference clamps off")
	preferences.restore({"forest_visibility":INF}); check(preferences.forest_visibility==60,"Nonfinite aid preference restores default")
	preferences.restore({"forest_visibility":101}); check(preferences.forest_visibility==100,"Aid preference clamps maximum")
	preferences.restore({"forest_visibility_size":-5}); check(preferences.forest_visibility_size==20,"Size clamps to small opening")
	preferences.restore({"forest_visibility_size":INF}); check(preferences.forest_visibility_size==88,"Invalid size restores enlarged default")
	preferences.restore({"forest_visibility_size":101}); check(preferences.forest_visibility_size==100,"Maximum size enables full-screen mode")
	preferences.restore({"forest_visibility_size":50})
	var path="user://foliage_sight_test.cfg"
	check(preferences.save_preferences(path)==OK,"Aid preference saves independently of replay state")
	var restored=Preferences.new(); restored.load_preferences(path)
	check(restored.forest_visibility==100,"Aid preference roundtrips")
	check(restored.forest_visibility_size==50,"Size persists separately from reach")
	DirAccess.remove_absolute(path)
	print("FOLIAGE_SIGHT_RESULTS ",JSON.stringify({"checks":checks,"failures":failures}))
	camera.free(); quit(0 if failures.is_empty() else 1)

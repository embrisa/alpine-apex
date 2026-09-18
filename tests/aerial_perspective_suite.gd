extends SceneTree
const World=preload("res://scripts/world/alpine_world.gd")
const Weather=preload("res://scripts/presentation/weather_controller.gd")
const Quality=preload("res://scripts/presentation/graphics_quality.gd")
const Fog=preload("res://scripts/presentation/alpine_atmosphere.gd")
var checks=0
var failures=[]
func _initialize():call_deferred("run")
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);printerr("FAIL ",label)
func run():
	var world=World.new();root.add_child(world);world._environment()
	world.assets=preload("res://scripts/presentation/alpine_assets.gd").new(world.cloud_lighting,world.quality)
	var far=preload("res://scripts/world/alpine_wilderness.gd").new();world.add_child(far);world.wilderness=far
	far.material.shader=preload("res://assets/graphics/alpine_wilderness.gdshader")
	far.apron_material=ShaderMaterial.new();far.apron_material.shader=preload("res://assets/graphics/alpine_apron.gdshader")
	# Already-resident material-only fixture. Geometry and placement aren't changed.
	far.requested_level=2;far.level=2
	var weather=Weather.new();root.add_child(weather)
	for preset in ["clear","cloudy","snowfall","snowstorm"]:
		for band in ["day","dawn","dusk","night"]:
			weather.set_preset(preset);weather.set_time_of_day(band)
			var s=weather.state;var source_density=s.fog_density;var source_color=s.fog_color
			for strength in [.5,1.5,1.0]:
				world.apply_graphics(Quality.numbered(7,{"fog_strength":strength}));world.update_weather(s,0,false)
				var env=world.environment;var expected:Color=env.fog_light_color.srgb_to_linear()*env.fog_light_energy
				for material in [far.material,far.apron_material]:
					check(is_equal_approx(env.fog_density,material.get_shader_parameter("offmap_depth_density")),"Both sides of handover use identical optical density after live override")
					var actual:Vector3=material.get_shader_parameter("offmap_fog_color")
					check(actual.distance_to(Vector3(expected.r,expected.g,expected.b))<.00001,"Both sides of handover use identical linear colour")
				check(env.fog_height_density==0 and env.fog_aerial_perspective==0,"No competing height layer or sky-texture fog path")
			check(s.fog_density==source_density and s.fog_color==source_color,"Appearance never mutates weather authority")
			if band=="night":check(is_equal_approx(Fog.depth_fog(s).density,s.fog_density),"Night keeps its original density")
	weather.set_preset("clear");weather.set_time_of_day("day");world.update_weather(weather.state,0,false)
	var original=far.material.get_shader_parameter("offmap_fog_color")
	weather.state.sky_top=Color.RED;world.update_weather(weather.state,0,false)
	check(far.material.get_shader_parameter("offmap_fog_color")!=original,"Sky-only changes invalidate background colour cache")
	var sky_changed=far.material.get_shader_parameter("offmap_fog_color")
	weather.state.cloud_offset+=Vector2(80,25);world.update_weather(weather.state,0,false)
	check(far.material.get_shader_parameter("offmap_fog_color")==sky_changed,"Cloud translation does not recolour atmosphere")
	weather.state.enabled=false
	check(is_equal_approx(Fog.depth_fog(weather.state).density,weather.state.fog_density),"Weather Off removes the added depth ramp")
	check(load("res://tests/aerial_perspective_review.gd").can_instantiate(),"Review producer parses without loading a mountain")
	print("AERIAL_PERSPECTIVE_RESULTS ",JSON.stringify({"checks":checks,"failures":failures}))
	world.queue_free();weather.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)

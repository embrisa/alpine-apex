extends SceneTree
## Weather-driven tone and ambient invariants on the compact environment owner.
const World=preload("res://scripts/world/alpine_world.gd")
const Weather=preload("res://scripts/presentation/weather_controller.gd")
const Atmosphere=preload("res://scripts/presentation/alpine_atmosphere.gd")
var checks=0
var failures=[]
func _initialize():call_deferred("run")
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);printerr("FAIL ",label)
func run():
	var world=World.new();root.add_child(world);world._environment()
	world.assets=preload("res://scripts/presentation/alpine_assets.gd").new(world.cloud_lighting,world.quality)
	var weather=Weather.new();root.add_child(weather)
	var camera=Camera3D.new();root.add_child(camera);camera.make_current()
	for preset in ["clear","cloudy","snowfall","snowstorm"]:
		for band in ["dawn","day","dusk","night"]:
			weather.set_preset(preset);weather.set_time_of_day(band);world.update_weather(weather.state,0,false)
			var values=Atmosphere.snow_ambient(weather.state)
			check(values[0].is_finite() and values[1].is_finite() and values[0].x>=0 and values[1].x>=0,"Finite nonnegative ambient: "+preset+band)
			check(values[0].w>0 and values[0].w<.5,"Ambient retains most of the existing environment: "+preset+band)
			check(world.environment.tonemap_exposure>=.79 and world.environment.tonemap_exposure<=1.0,"Tone never increases exposure above the night reference: "+preset+band)
			check(is_equal_approx(world.environment.ambient_light_sky_contribution,.42),"Other receivers retain their existing ambient blend")
			if band=="night":check(world.environment.tonemap_exposure==1 and world.environment.tonemap_white==1,"Night tone is unchanged: "+preset)
			var old_sun=world.sun.light_energy
			var top=world.render_state.values[world.environment][&"snow_ambient_top"]
			weather.state.cloud_offset+=Vector2(80,20);camera.position+=Vector3(5,2,9)
			world.update_weather(weather.state,0,false)
			check(world.render_state.values[world.environment][&"snow_ambient_top"]==top and world.sun.light_energy==old_sun,"Camera/cloud translation cannot recolour snow or change direct light")
	weather.set_preset("clear");weather.set_time_of_day("day")
	var state=weather.state
	state.sky_top=Color(.2,.3,.8);state.sky_horizon=Color(.9,.3,.2);state.cloud_coverage=0
	var clear=Atmosphere.snow_ambient(state)
	check(clear[0].z>clear[0].x and clear[1].x>clear[1].z,"Distinct zenith and horizon chroma reach the two hemispheres")
	state.cloud_coverage=1;state.cloud_color=Color(.5,.5,.5)
	var overcast=Atmosphere.snow_ambient(state)
	check(absf(overcast[0].z-overcast[0].x)<absf(clear[0].z-clear[0].x),"Neutral clouds soften sky chroma")
	state.ambient_energy=0
	var dark=Atmosphere.snow_ambient(state)
	check(Vector3(dark[0].x,dark[0].y,dark[0].z).is_zero_approx() and Vector3(dark[1].x,dark[1].y,dark[1].z).is_zero_approx(),"Zero ambient cannot add fill light")
	var harness=load("res://tests/snow_appearance_review.gd")
	check(harness!=null and harness.can_instantiate(),"Full-mountain review parses without loading its fixture")
	var result={"checks":checks,"failures":failures}
	preload("res://tests/test_report.gd").write("res://artifacts/snow_appearance_20260918/unit.json",JSON.stringify(result,"\t"))
	print("SNOW_APPEARANCE_RESULTS ",JSON.stringify(result))
	world.queue_free();weather.queue_free();camera.queue_free();await process_frame
	quit(0 if failures.is_empty() else 1)

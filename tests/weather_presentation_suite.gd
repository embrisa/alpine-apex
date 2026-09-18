extends SceneTree
## Presentation contracts: cloud motion, retained precipitation pools and budgets.
const Weather=preload("res://scripts/presentation/weather_controller.gd")
const Effects=preload("res://scripts/presentation/weather_effects.gd")
var checks=0
var failures=[]
func _initialize():call_deferred("run")
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);printerr("WEATHER_PRESENTATION_FAIL ",label)
func run():
	var field=preload("res://scripts/diagnostics/test_map.gd").create("smooth-slope")
	var weather=Weather.new();root.add_child(weather)
	var fx=Effects.new();root.add_child(fx)
	var camera=Camera3D.new();root.add_child(camera);camera.position=Vector3(0,4,32)
	var pool=fx.volumes.map(func(p):return p.get_instance_id())
	for preset in ["cloudy","snowfall","rain","snowstorm","thunderstorm"]:
		weather.set_preset(preset);weather.cloud_x=0;weather.cloud_z=0
		weather.update_weather(30,true)
		var distance=weather.cloud_offset.length()
		check(distance>1 and distance<(60 if preset.ends_with("storm") else 25),"Clouds evolve gently over thirty seconds: "+preset)
		check(weather.state.wind_velocity.is_equal_approx(weather.PRESETS[preset].wind_velocity*(.8+weather.state.gust*.4)),"Cloud mapping preserves precipitation/foliage wind: "+preset)
		check(weather.state.cloud_offset==weather.cloud_offset,"Sky and lighting share displacement: "+preset)
	weather.set_preset("snowfall")
	fx.update_weather(weather.state,camera,Vector3(0,0,32),field,1.0/30,true,false,1,2)
	var ordinary=float(fx.volumes[0].draw_pass_1.material.get_shader_parameter("density"))
	var extents:Vector3=fx.volumes[0].process_material.get_shader_parameter("half_extents")
	check(extents.x*extents.y*extents.z*8<4000,"Snow particles concentrate in a resolvable nearby volume")
	var resets=fx.reset_count
	weather.set_preset("snowstorm")
	fx.update_weather(weather.state,camera,Vector3(0,0,32),field,1.0/30,true,false,1,2)
	var storm=float(fx.volumes[0].draw_pass_1.material.get_shader_parameter("density"))
	check(storm>ordinary*2 and storm<=1 and ordinary>0,"Storm selects substantially more flakes without exceeding the pool")
	check(fx.reset_count==resets and fx.volumes.map(func(p):return p.get_instance_id())==pool,"Intensity transitions retain the same particle state and allocations")
	for quality in [0,1,2]:
		for budget in [.25,.5,1.0]:
			fx.set_budget_scale(budget)
			fx.update_weather(weather.state,camera,Vector3(0,0,32),field,1.0/30,true,false,0,quality)
			check(fx.particle_budget()<=(1700 if quality==2 else 850 if quality==1 else 0),"Quality/budget cap %s/%s"%[quality,budget])
			check(fx.volumes[0].visible==(quality>0),"Effects Off removes snowfall, Low/High retain it")
			check(fx.volumes[0].draw_pass_1.material.get_shader_parameter("stretch")==0.0,"Reduced speed accents do not stretch flakes")
	fx.update_weather(weather.state,camera,Vector3(0,0,32),field,1.0/30,false,false,0,2)
	check(fx.volumes[0].speed_scale==0 and fx.volumes[0].visible,"Pause freezes retained precipitation")
	resets=fx.reset_count;camera.position.x+=20
	fx.update_weather(weather.state,camera,Vector3(0,0,32),field,1.0/30,true,false,0,2)
	check(fx.reset_count==resets+1 and fx.camera_velocity==Vector3.ZERO,"Teleport clears the previous camera velocity")
	resets=fx.reset_count
	fx.update_weather(weather.state,camera,Vector3(0,0,32),field,1.0/30,true,false,0,2,true)
	check(fx.reset_count==resets+1,"Riding-view transition resets the local volume")
	preload("res://tests/test_report.gd").write("res://artifacts/weather_presentation_20260918/unit.json",JSON.stringify({"checks":checks,"failures":failures},"\t"))
	print("WEATHER_PRESENTATION_RESULTS ",JSON.stringify({"checks":checks,"failures":failures}))
	fx.queue_free();weather.queue_free();camera.queue_free();await process_frame
	quit(0 if failures.is_empty() else 1)

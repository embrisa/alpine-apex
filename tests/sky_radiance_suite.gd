extends SceneTree
## Native radiance readbacks are correctness evidence, never timing samples.
const World=preload("res://scripts/world/alpine_world.gd")
const Weather=preload("res://scripts/presentation/weather_controller.gd")
var checks=0
var failures=[]
var world
var weather
var camera: Camera3D
var output="res://artifacts/sky_radiance_suite/results.json"
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label); printerr("FAIL ",label)
func settle() -> void:
	world.update_weather(weather.state,0,false)
	for frame in 8: await process_frame
func panorama() -> PackedByteArray:
	var image=RenderingServer.sky_bake_panorama(world.weather_sky.get_rid(),1.0,true,Vector2i(64,32))
	check(image!=null and not image.is_empty(),"Radiance image is available")
	return image.get_data() if image else PackedByteArray()
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
	if DisplayServer.get_name()=="headless": printerr("Native radiance checks require a renderer"); quit(2); return
	root.size=Vector2i(640,360); Engine.max_fps=60
	world=World.new(); root.add_child(world); world._environment()
	world.assets=preload("res://scripts/presentation/alpine_assets.gd").new(world.cloud_lighting,world.quality)
	weather=Weather.new(); root.add_child(weather); weather.set_preset("cloudy"); weather.set_time_of_day("day")
	camera=Camera3D.new(); root.add_child(camera); camera.current=true; camera.position=Vector3(0,1100,0)
	camera.look_at(Vector3(0,1500,-3000))
	await settle()
	var original=panorama()
	check(is_equal_approx(world.weather_material.get_shader_parameter("radiance_cloud_coverage"),weather.state.cloud_coverage),"Initial coverage reaches radiance independently of global displacement")
	for point in [Vector3(40,1150,80),Vector3(-100,900,-300)]:
		camera.position=point; await settle()
		check(panorama()==original,"Camera motion preserves ambient/reflection content")
		check(world.render_state.values[world.weather_material][&"cloud_camera_position"]==point,"Current camera position published")
	weather.state.cloud_offset+=Vector2(600,800); await settle()
	check(panorama()==original,"Cloud displacement preserves the same ambient approximation")
	weather.state.cloud_coverage=.15; await settle()
	var low_cover=panorama()
	check(low_cover!=original,"Coverage-only change updates native radiance with a stationary camera")
	check(is_equal_approx(world.weather_material.get_shader_parameter("radiance_cloud_coverage"),.15),"Coverage-only value is explicit")
	weather.state.sky_top=Color(.1,.12,.3); weather.state.cloud_color=Color(.35,.25,.3); await settle()
	check(panorama()!=low_cover,"Sky/cloud color updates still rebuild native radiance")
	weather.state.enabled=false; await settle()
	check(world.environment.sky==world.original_sky,"Weather-off selects original sky")
	weather.state.enabled=true; await settle()
	check(world.environment.sky==world.weather_sky,"Weather-on restores weather sky")
	preload("res://tests/test_report.gd").write(output,JSON.stringify({"checks":checks,"failures":failures,"scope":"Native radiance content on camera/displacement/coverage/color/weather transitions; no FPS claim"},"\t"))
	print("SKY_RADIANCE_CHECKS ",checks," failures=",failures)
	world.queue_free(); weather.queue_free(); camera.queue_free(); await process_frame
	quit(0 if failures.is_empty() else 1)

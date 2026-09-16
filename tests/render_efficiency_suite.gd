extends SceneTree
const Cache = preload("res://scripts/presentation/render_state_cache.gd")
const Clouds = preload("res://scripts/presentation/cloud_lighting.gd")
const Weather = preload("res://scripts/presentation/weather_controller.gd")
const Atmosphere = preload("res://scripts/presentation/alpine_atmosphere.gd")
const Graphics = preload("res://scripts/presentation/graphics_quality.gd")
const Tracks = preload("res://scripts/presentation/snow_tracks.gd")
const Scenery = preload("res://scripts/world/alpine_scenery.gd")
var checks = 0
var failures = []
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures.append(message); printerr("FAIL ",message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var cache = Cache.new()
	var node = Node3D.new(); root.add_child(node)
	cache.assign(node,&"position",Vector3(1,2,3))
	cache.assign(node,&"position",Vector3(1,2,3))
	check(cache.submitted==1 and cache.skipped==1,"Unchanged transform does not submit twice")
	cache.assign(node,&"position",Vector3(1,2,3.001))
	check(node.position.z==Vector3(1,2,3.001).z,"Small changes are not thresholded away")
	node.position = Vector3.ZERO; cache.clear(); cache.assign(node,&"position",Vector3(1,2,3.001))
	check(node.position!=Vector3.ZERO,"Preset invalidation resubmits state")
	node.queue_free()
	var weather = Weather.new()
	var clouds = Clouds.new()
	clouds.update(weather.state,Vector2(12,34),weather.state.sun_direction)
	var late = ShaderMaterial.new(); late.shader = Clouds.SURFACE_SHADER
	clouds.register(late)
	# Cloud inputs are global shader parameters (not readable back headless);
	# a late receiver needs no copy and the publisher state stays authoritative.
	check(late in clouds.materials and clouds.parameters.x==12.0 and clouds.parameters.y==34.0,"Late material joins the registry under the current cloud position")
	check(clouds.last_sun_direction==weather.state.sun_direction,"Publisher retains the current sun direction")
	clouds.update(weather.state,Vector2(12,34),weather.state.sun_direction)
	clouds.update(weather.state,Vector2(13,34),weather.state.sun_direction)
	check(clouds.parameters.x==13.0,"Moving clouds retain every update")
	await check_atmosphere(weather)
	await check_tracks(clouds)
	check_transforms()
	await check_world(weather)
	print("RENDER_EFFICIENCY ",checks," checks; ",failures.size()," failures")
	DirAccess.make_dir_recursive_absolute("res://artifacts/fps_optimization")
	preload("res://tests/test_report.gd").write("res://artifacts/fps_optimization/efficiency_checks.json",JSON.stringify({"checks":checks,"failures":failures},"\t"))
	cache.clear(); cache = null
	clouds.materials.clear(); clouds = null; late = null
	weather.free(); weather = null
	await process_frame
	quit(0 if failures.is_empty() else 1)
func check_atmosphere(weather) -> void:
	var environments = [Environment.new(),Environment.new()]
	var suns = [DirectionalLight3D.new(),DirectionalLight3D.new()]
	var moons = [DirectionalLight3D.new(),DirectionalLight3D.new()]
	var skies = [ShaderMaterial.new(),ShaderMaterial.new()]
	for i in 2:
		root.add_child(suns[i]); root.add_child(moons[i])
		skies[i].shader = load("res://assets/weather_sky.gdshader")
		Atmosphere.configure(environments[i])
	var cache = Cache.new()
	for quality in [2,0,1,2]:
		var profile = Graphics.preset(quality)
		for i in 2: Atmosphere.apply_quality(environments[i],profile)
		cache.clear()
		for preset in ["clear","snowfall"]:
			weather.set_preset(preset)
			for time in ["day","dusk","night"]:
				weather.set_time_of_day(time)
				Atmosphere.apply(environments[0],suns[0],moons[0],skies[0],weather.state,profile)
				for repeat in 2: Atmosphere.apply(environments[1],suns[1],moons[1],skies[1],weather.state,profile,cache)
				for property in ["tonemap_exposure","tonemap_white","fog_light_energy","fog_sun_scatter","glow_enabled","glow_intensity","volumetric_fog_enabled"]:
					check(environments[0].get(property)==environments[1].get(property),"Cached atmosphere equals original: "+property)
				check(suns[0].light_volumetric_fog_energy==suns[1].light_volumetric_fog_energy,"Identical shaft illumination")
	cache.clear()
	for i in 2: suns[i].queue_free(); moons[i].queue_free()
	environments.clear(); skies.clear(); suns.clear(); moons.clear()
	await process_frame
func check_tracks(clouds) -> void:
	var tracks = Tracks.new(); tracks.lighting = clouds; root.add_child(tracks)
	tracks.apply_quality(Graphics.preset(2))
	var mirror = PackedByteArray(); mirror.resize(4098*32)
	apply_uploads(mirror,tracks.take_gpu_updates())
	check(mirror.slice(0,tracks.capacity*32)==tracks.gpu_stamps.to_byte_array(),"Initial buffer synchronization")
	# Multiple wraps and delayed consumption exercise both split spans and the
	# bounded full synchronization, independent of any native readback.
	for i in tracks.capacity*2+17:
		var index = i%tracks.capacity
		tracks.transforms[index] = Transform3D(Basis.IDENTITY,Vector3(i*.37,0,i*.61))
		tracks.corner_history[index] = Color(0,0,0,0)
		tracks.appearance_history[index] = Color(.03,.7,.2,1)
		tracks._upload(index)
		if i%97==0:
			apply_uploads(mirror,tracks.take_gpu_updates())
			check(mirror.slice(0,tracks.capacity*32)==tracks.gpu_stamps.to_byte_array(),"Partial uploads reproduce complete history across ring wrap")
	var pending = tracks.take_gpu_updates()
	var immutable = pending.duplicate(true)
	tracks.reset()
	check(pending==immutable,"Queued bytes survive reset until render thread consumes them")
	apply_uploads(mirror,tracks.take_gpu_updates())
	check(mirror.slice(0,tracks.capacity*32)==tracks.gpu_stamps.to_byte_array(),"Reset erases stale GPU strokes")
	for level in [0,2,1,2]:
		tracks.apply_quality(Graphics.preset(level))
		apply_uploads(mirror,tracks.take_gpu_updates())
		check(mirror.slice(0,tracks.capacity*32)==tracks.gpu_stamps.to_byte_array(),"Quality capacity change fully synchronizes")
	check(tracks.take_gpu_updates().is_empty(),"Unchanged history needs no upload")
	tracks.queue_free(); await process_frame
func apply_uploads(mirror: PackedByteArray, uploads: Array) -> void:
	for update in uploads:
		for i in update.bytes.size(): mirror[update.offset+i] = update.bytes[i]
func check_transforms() -> void:
	var transforms = []
	for i in 51:
		transforms.append(Transform3D(Basis(Vector3.UP,i*.193).scaled(Vector3(.7+i*.03,1.3,.9)),Vector3(i*17-470,3000-i*43,-i*11)))
	var prepared = Scenery.prepare_tree_batch(transforms,23.0)
	var bounds = AABB(transforms[0].origin,Vector3.ZERO)
	for i in transforms.size():
		var data: PackedFloat32Array = prepared.buffer.slice(i*12,(i+1)*12)
		var decoded = Transform3D(Basis(Vector3(data[0],data[4],data[8]),Vector3(data[1],data[5],data[9]),Vector3(data[2],data[6],data[10])),Vector3(data[3],data[7],data[11]))
		check(decoded==transforms[i],"Packed placement preserves rotation, scale and origin")
		bounds = bounds.expand(transforms[i].origin)
	bounds.position-=Vector3(10,.5,10); bounds.size+=Vector3(20,23,20)
	check(bounds==prepared.bounds,"Near, mid and shadow bounds match original exactly")

func check_world(weather) -> void:
	var world = preload("res://scripts/world/alpine_world.gd").new(); root.add_child(world)
	world.assets = preload("res://scripts/presentation/alpine_assets.gd").new(world.cloud_lighting,Graphics.preset(2))
	world._environment()
	weather.set_preset("clear"); weather.set_time_of_day("day")
	world.update_weather(weather.state,.25,true)
	var receiver = ShaderMaterial.new(); receiver.shader = preload("res://assets/graphics/foliage.gdshader")
	world.assets._remember_material("Needles",receiver)
	check(receiver.get_shader_parameter("wind_time")==.25,"Late wind receiver initializes immediately")
	var changed = {"enabled":false,"sun_color":Color.RED,"sun_energy":.4,"sun_direction":Vector3(.2,.7,.4).normalized(),"moon_color":Color.BLUE,"moon_energy":.3,"ambient_color":Color.GREEN,"ambient_energy":.5,"fog_color":Color.GRAY,"fog_density":.001,"sky_top":Color.RED,"sky_horizon":Color.BLUE,"cloud_color":Color.GRAY,"cloud_coverage":.8}
	for key in changed:
		weather.set_preset("clear"); weather.set_time_of_day("day")
		world.update_weather(weather.state,0,false)
		weather.state.set(key,changed[key]); world.update_weather(weather.state,0,false)
		var actual = world_snapshot(world)
		world.weather_values.clear(); world.render_state.clear()
		world.update_weather(weather.state,0,false)
		check(actual==world_snapshot(world),"Stable lighting key observes changes to "+key)
	world.apply_graphics(Graphics.preset(0))
	check(world.weather_values.is_empty(),"Quality switching invalidates stable lighting key")
	var late_receiver = ShaderMaterial.new(); late_receiver.shader = preload("res://assets/graphics/foliage.gdshader")
	world.assets._remember_material("PC_Conifer",late_receiver)
	check(late_receiver.get_shader_parameter("wind_time")==world.assets.last_wind_time and late_receiver.get_shader_parameter("wind_direction")==world.assets.last_wind_direction,"Material registered during quality invalidation immediately receives the last wind state")
	world.update_weather(weather.state,0,false)
	check(not world.environment.glow_enabled,"Quality switching resubmits current lighting")
	world.queue_free(); await process_frame

func world_snapshot(world) -> Array:
	var result = []
	for key in ["sky","ambient_light_color","ambient_light_energy","fog_light_color","fog_density","fog_sky_affect","tonemap_exposure","tonemap_white","glow_enabled","glow_intensity","volumetric_fog_enabled"]: result.append(world.environment.get(key))
	for light in [world.sun,world.moon]:
		for key in ["light_color","light_energy","basis","visible","light_volumetric_fog_energy"]: result.append(light.get(key))
	for key in ["sky_top","sky_horizon","cloud_color","sun_color","sun_glow_strength","moon_glow_strength","sun_disc_energy","sun_halo_energy"]: result.append(world.weather_material.get_shader_parameter(key))
	return result

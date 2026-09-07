extends SceneTree
const Quality = preload("res://scripts/presentation/graphics_quality.gd")
const Atmosphere = preload("res://scripts/presentation/alpine_atmosphere.gd")
var checks = 0
var failures: Array[String] = []
var game

func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	print("PASS: " if ok else "FAIL: ",label)
	if not ok: failures.append(label)
func apply() -> void:
	game.world.update_weather(game.weather.state,0.0,false)
func identity() -> Array:
	return [game.session.eligible,game.session.course_id,game.physics_modified,game.sim.position,game.sim.velocity,game.session.elapsed,hash(game.field.heights),hash(game.field.obstacles)]

func run() -> void:
	game = load("res://main.tscn").instantiate()
	game.automated = true
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	game.start_run(true)
	game.session.eligible = true # Identity fixture only; never save a run.
	var original = identity()
	var env: Environment = game.world.environment
	game.weather.set_preset("clear")
	game.weather.set_time_of_day("day")
	game.set_graphics_quality(2)
	apply()
	var expected = Vector3(0,sin(deg_to_rad(24.0)),cos(deg_to_rad(24.0))).rotated(Vector3.UP,deg_to_rad(-58.0))
	check(game.weather.state.sun_direction.is_equal_approx(expected) and game.weather.daylight.hour==12.0,"Golden lighting preserves the exact noon direction and 12:00 default")
	check(game.weather.daylight.CYCLE_SECONDS==1200.0 and Engine.physics_ticks_per_second==120,"Day cycle and independent 120 Hz simulation retain their timing")
	check(env.volumetric_fog_enabled and game.world.sun.shadow_enabled and game.world.sun.light_volumetric_fog_energy>0.0,"Clear High enables shadowed sun shafts")
	check(env.volumetric_fog_length<=160 and env.volumetric_fog_length<=game.world.sun.directional_shadow_max_distance and env.volumetric_fog_density<=0.0001,"Shaft range stays inside nearby tree and terrain shadows at minimal density")
	check(env.volumetric_fog_gi_inject==0 and env.volumetric_fog_ambient_inject==0 and not env.sdfgi_enabled,"Shafts add no GI requirement and preserve optional SDFGI off")
	check(env.glow_enabled and env.glow_bloom==0.0 and env.glow_hdr_threshold>1.0 and not root.use_hdr_2d,"HDR highlights glow without full-screen bloom or HDR HUD processing")
	check(env.tonemap_mode==Environment.TONE_MAPPER_FILMIC and env.tonemap_white>1 and game.weather.state.sun_color.r>game.weather.state.sun_color.b,"Warm direct lighting uses filmic highlight headroom")
	var noon_energy: float = game.world.sun.light_volumetric_fog_energy
	var same_light = [game.world.sun.light_energy,game.world.sun.light_color,env.tonemap_exposure,env.tonemap_white]
	for level in [0,1,2,1,0,2]:
		game.set_graphics_quality(level)
		check(env.volumetric_fog_enabled==(level==2) and env.glow_enabled==(level>0),"Live quality %d applies shaft and glow switches immediately" % level)
		check(same_light==[game.world.sun.light_energy,game.world.sun.light_color,env.tonemap_exposure,env.tonemap_white],"Quality %d retains the shared golden lighting" % level)
	game.weather.set_preset("cloudy")
	apply()
	check(game.world.sun.light_volumetric_fog_energy<noon_energy*.1 and game.world.sun.light_energy>0.65,"Cloudy keeps warm illuminated breaks with subdued rays")
	for preset in ["clear","cloudy","snowfall","rain"]:
		game.weather.set_preset(preset)
		game.weather.set_time_of_day("night")
		apply()
		check(not env.volumetric_fog_enabled and not env.glow_enabled and game.world.sun.light_volumetric_fog_energy==0 and game.world.moon.light_volumetric_fog_energy==0 and not game.world.sun.visible,"Night suppresses daytime effects in "+preset)
	game.weather.set_time_of_day("day")
	game.weather.set_preset("clear")
	game.weather.set_quality(0)
	apply()
	check(not env.volumetric_fog_enabled and not env.glow_enabled and game.world.sun.light_color.r>game.world.sun.light_color.b,"Weather FX off disables effects but keeps warm direct light")
	game.weather.set_quality(2)
	game.weather.set_automatic(true)
	game.weather.update_weather(180.0,true)
	var previous = noon_energy
	var continuous = true
	for step in 200:
		game.weather.update_weather(.1,true)
		apply()
		var current: float = game.world.sun.light_volumetric_fog_energy
		continuous = continuous and current<=previous+.001 and absf(current-previous)<3.0
		previous = current
	check(continuous,"Automatic Clear to Cloudy transition fades shaft energy continuously")
	var frozen = [game.weather.visual_time,game.weather.phase_seconds,game.world.cloud_offset,game.world.assets.wind_time,env.tonemap_exposure,game.world.sun.light_volumetric_fog_energy]
	game.weather.update_weather(30.0,false)
	game.world.update_weather(game.weather.state,30.0,false)
	check(frozen==[game.weather.visual_time,game.weather.phase_seconds,game.world.cloud_offset,game.world.assets.wind_time,env.tonemap_exposure,game.world.sun.light_volumetric_fog_energy],"Pause freezes weather, wind, cloud phase and presentation values")
	check(identity()==original,"All atmosphere and quality transitions preserve ranked eligibility, physics, elapsed time and terrain identity")
	var restart_state = [game.weather.selected_preset,game.weather.phase_seconds,game.weather.visual_time]
	game.restart()
	apply()
	check(game.graphics.level==2 and game.weather.automatic and restart_state==[game.weather.selected_preset,game.weather.phase_seconds,game.weather.visual_time] and env.volumetric_fog_enabled,"Restart retains selected quality and weather progression")
	check(game.weather_effects.lighting==game.world.cloud_lighting,"Precipitation and spindrift share actual sun and cloud lighting")
	DirAccess.make_dir_recursive_absolute("res://artifacts/golden_sunlight")
	FileAccess.open("res://artifacts/golden_sunlight/automated.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"\t"))
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

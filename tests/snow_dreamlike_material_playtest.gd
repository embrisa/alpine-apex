extends "res://tests/snow_playtest.gd"
## Rendered layer/shadow controls over the existing real-snow laboratory.
var layer_checks: Dictionary = {}

func _initialize() -> void:
	set_meta("test_lab_fixture",true)
	output = "res://artifacts/snow_dreamlike/materials"
	super._initialize()

func run() -> void:
	await super.run()
	var report = JSON.parse_string(FileAccess.get_file_as_string(output+"/playtest_legacy.json"))
	var sun: Dictionary = layer_checks.get("sun_crystals",{})
	var shade: Dictionary = layer_checks.get("crystals_cast_shadow",{})
	var night: Dictionary = layer_checks.get("night",{})
	var ok = not sun.is_empty() and not shade.is_empty() and not night.is_empty()
	if ok:
		ok = sun.sheen_center>0 and sun.crystal_center>0 and shade.sheen_center<sun.sheen_center*.2 and shade.crystal_center<sun.crystal_center*.2
		ok = ok and night.sheen_pixels==0 and night.crystal_pixels==0 and report.night_crystal_pixels==0 and not report.crashed and not report.eligible
	FileAccess.open(output+"/acceptance.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":ok,"layers":layer_checks,"native_aa":true,"all_particles_frozen":true},"\t"))
	print("SNOW_LAYER_ACCEPTANCE ",ok)
	quit(0 if ok else 1)

func snow_materials() -> Array:
	var result: Array = game.world.assets.surface_materials.duplicate()
	result.append(game.world.scenery.powder_caps.material)
	result.append(game.effects.snow_tracks.material)
	return result

func settle() -> void:
	for i in 20: await process_frame
	await RenderingServer.frame_post_draw

func capture(id: String) -> void:
	# Exact lighting controls use native AA and freeze every particle family.
	# Production FSR2 motion is validated by the separate v13 harness.
	game.display_settings.upscaler = "native"
	game.display_settings.apply_viewport(root)
	for particle in game.effects.sprays+game.weather_effects.volumes+game.weather_effects.drifts:
		particle.speed_scale = 0.0
	await super.capture(id)
	if id not in ["sun_crystals","crystals_cast_shadow","night"]: return
	var materials = snow_materials()
	var saved: Array = []
	for material in materials:
		saved.append([material.get_shader_parameter("snow_sparkle_strength"),material.get_shader_parameter("snow_sheen_strength")])
	var env: Environment = game.world.environment
	var glow = env.glow_enabled
	env.glow_enabled = false
	for material in materials: material.set_shader_parameter("snow_sparkle_strength",0.0)
	await settle()
	var sheen = root.get_texture().get_image()
	sheen.save_png(output+"/"+id+"_sheen_only.png")
	for material in materials: material.set_shader_parameter("snow_sheen_strength",0.0)
	await settle()
	var neither = root.get_texture().get_image()
	neither.save_png(output+"/"+id+"_neither.png")
	for i in materials.size(): materials[i].set_shader_parameter("snow_sparkle_strength",saved[i][0])
	await settle()
	var crystals = root.get_texture().get_image()
	crystals.save_png(output+"/"+id+"_crystals_only.png")
	layer_checks[id] = {"sheen_pixels":changed_pixels(sheen,neither),"sheen_center":changed_pixels(sheen,neither,true),"crystal_pixels":changed_pixels(crystals,neither),"crystal_center":changed_pixels(crystals,neither,true)}
	for i in materials.size(): materials[i].set_shader_parameter("snow_sheen_strength",saved[i][1])
	await settle()
	root.get_texture().get_image().save_png(output+"/"+id+"_glow_off.png")
	env.glow_enabled = glow
	await settle()
	FileAccess.open(output+"/layers.json",FileAccess.WRITE).store_string(JSON.stringify(layer_checks,"\t"))
	print("DREAMLIKE_LAYERS ",id," ",layer_checks[id])

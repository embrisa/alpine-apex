extends RefCounted
## Build only explicitly requested test terrain using the production world components.
static func build(world,field,checkpoint: Callable = Callable()) -> void:
	var started = Time.get_ticks_usec()
	world.surface = field
	world.cloud_lighting.height_m = maxf(2400.0,field.sample(0,0).height+1200.0)
	world.mountain = preload("res://scripts/world/mountain_data.gd").new()
	world.mountain.seed_value = world.mountain_seed if world.mountain_seed>=0 else field.seed_value
	world.mountain.physics_authority = field.fixture_identity
	# No distant terrain is drawn. A uniform snow environment is sufficient for
	# these authored snow patches; support/material detail still uses the real grid.
	world.mountain.height_image = Image.create(2,2,false,Image.FORMAT_RF)
	world.mountain.height_image.fill(Color(0,0,0))
	world.mountain.environment_image = Image.create(2,2,false,Image.FORMAT_RGBA8)
	world.mountain.environment_image.fill(Color(1,0,0,.5))
	world.mountain.height_checksum = field.heights.to_byte_array().hex_encode().sha256_text()
	world.mountain.environment_checksum = world.mountain.environment_image.get_data().hex_encode().sha256_text()
	field.build_material_map()
	world.snow_readability.prepare(field)
	world.assets = preload("res://scripts/presentation/alpine_assets.gd").new(world.cloud_lighting,world.quality)
	world.assets.mountain = world.mountain
	world.snow_material = world.assets.terrain_material()
	world.snow_readability.bind(world.snow_material)
	world.snow_material.set_shader_parameter("contact_material_enabled",true)
	world.snow_material.set_shader_parameter("contact_material",ImageTexture.create_from_image(field.material_image))
	world.snow_material.set_shader_parameter("contact_material_origin",Vector2(field.X_MIN,field.Z_MIN))
	world.snow_material.set_shader_parameter("contact_material_size",Vector2(field.NX,field.NZ))
	world._environment()
	if checkpoint.is_valid(): await checkpoint.call("Building targeted test terrain…",-1.0)
	await world._terrain(checkpoint)
	await world._vegetation(checkpoint)
	world.flavor = preload("res://scripts/world/mountain_flavor.gd").new()
	world.add_child(world.flavor)
	world.flavor.surface = preload("res://scripts/world/prop_collision_surface.gd").new(field)
	world.flavor.lighting = world.assets.lighting
	world.flavor.profile = world.quality
	world.ski_surface = world.flavor.surface
	world.generation_ms = (Time.get_ticks_usec()-started)/1000.0
	world.build_timings = {"targeted_world_ms":world.generation_ms}
	print("TEST_MAP_READY ",JSON.stringify(field.fixture_descriptor()))

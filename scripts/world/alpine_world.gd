extends Node3D
var render_state = preload("res://scripts/presentation/render_state_cache.gd").new()
var weather_values: Array = []
## Bounded static mountain: shared terrain grid, culled chunks and spatially
## grouped MultiMeshes. No per-tree Nodes, physics bodies, or per-frame allocation.
var surface
var mountain
var mountain_seed: int = -1
var assets
var scenery
var minerals
var grass
var flavor
var ski_surface
var wilderness
var backdrop
var quality = preload("res://scripts/presentation/graphics_quality.gd").preset(1)
var snow_material: ShaderMaterial
var snow_readability = preload("res://scripts/presentation/snow_readability.gd").new()
var generation_ms: float = 0.0
var preparation
var build_timings: Dictionary = {}
var build_job
## Startup alone may submit optional scenery after the menu owns input.
var defer_startup_cosmetics: bool = false
var startup_cosmetics_pending: bool = false
var startup_vistas_pending: bool = false
var startup_cosmetics_running: bool = false
var startup_cosmetics_ms: float = 0.0
var terrain_triangles: int = 0
const terrain_renderer: String = "legacy"
var terrain_chunks: Array[MeshInstance3D] = []
var benchmark_markers: Array[Node3D] = []
var environment: Environment
var sun: DirectionalLight3D
var moon: DirectionalLight3D
var original_sky: Sky
var weather_sky: Sky
var weather_material: ShaderMaterial
var cloud_offset = Vector2.ZERO
const CloudLighting = preload("res://scripts/presentation/cloud_lighting.gd")
var cloud_lighting = CloudLighting.new()
const Atmosphere = preload("res://scripts/presentation/alpine_atmosphere.gd")
var last_weather_state

func build(field, checkpoint: Callable = Callable(), data_worker: Callable = Callable()) -> void:
	if field.has_method("fixture_descriptor"):
		await preload("res://scripts/diagnostics/test_world.gd").build(self,field,checkpoint)
		return
	if not preload("res://scripts/diagnostics/test_world_policy.gd").require_full("Production mountain or scenery-rich laboratory scene construction"): return
	var start = Time.get_ticks_usec()
	surface = field
	# The full summit is 4300 m high. The old laboratory's fixed 2400 m layer
	# collapsed the sky projection above it and disabled mountain cloud shadows.
	cloud_lighting.height_m = maxf(2400.0,field.sample(0,0).height+1200.0)
	build_job = field.job if "job" in field else null
	if build_job:
		preload("res://scripts/world/generation_estimates.gd").configure_scenery(build_job,field)
		preparation = preload("res://scripts/world/mountain_preparation.gd").new()
		assets = preload("res://scripts/presentation/alpine_assets.gd").new(cloud_lighting,quality)
		var cached: bool
		if data_worker.is_valid(): cached = await data_worker.call(preparation.load_cached.bind(field,quality,build_job))
		else: cached = preparation.load_cached(field,quality,build_job)
		if _cancelled(): return
		if not cached:
			preload("res://scripts/world/generation_estimates.gd").configure_scenery(build_job,field,false)
			build_job.begin_stage("tree_assets",assets.tree_ids().size())
			var asset_start = Time.get_ticks_usec()
			var metadata: Dictionary = await preload("res://scripts/presentation/forest_placement.gd").metadata_async(assets,checkpoint,build_job)
			build_timings.tree_assets_ms = (Time.get_ticks_usec()-asset_start)/1000.0
			build_job.end_stage("tree_assets")
			if _cancelled(): return
			if data_worker.is_valid(): await data_worker.call(preparation.build.bind(field,metadata,quality,build_job))
			else: preparation.build(field,metadata,quality,build_job)
		if _cancelled() or not preparation.ready: return
		mountain = preparation.mountain; snow_readability = preparation.readability
	else:
		mountain = preload("res://scripts/world/mountain_data.gd").new()
		var generate_data = mountain.generate.bind(field,field.seed_value+4187 if mountain_seed<0 else mountain_seed)
		if data_worker.is_valid():
			await checkpoint.call("Preparing mountain scenery data…",-1.0)
			await data_worker.call(generate_data)
		else: generate_data.call()
		if checkpoint.is_valid(): await checkpoint.call("Preparing snow and rock contact materials…",-1.0)
		if data_worker.is_valid(): await data_worker.call(field.build_material_map)
		else: field.build_material_map()
		if checkpoint.is_valid(): await checkpoint.call("Preparing snow detail…",-1.0)
		if data_worker.is_valid(): await data_worker.call(snow_readability.prepare.bind(field))
		else: snow_readability.prepare(field)
		assets = preload("res://scripts/presentation/alpine_assets.gd").new(cloud_lighting,quality)
	_configure_submission_stages()
	_begin_submission("material_uploads")
	var upload_start = Time.get_ticks_usec()
	if checkpoint.is_valid(): await checkpoint.call("Loading materials and mountain lighting…",-1.0)
	assets.mountain = mountain
	snow_material = assets.terrain_material()
	snow_readability.bind(snow_material)
	snow_material.set_shader_parameter("contact_material_enabled",true)
	snow_material.set_shader_parameter("contact_material",ImageTexture.create_from_image(field.material_image))
	snow_material.set_shader_parameter("contact_material_origin",Vector2(field.X_MIN,field.Z_MIN))
	snow_material.set_shader_parameter("contact_material_size",Vector2(field.NX,field.NZ))
	if field.has_method("exposure_at"):
		# A localized 4 m feature mask preserves narrow snow ramps between cliffs.
		snow_material.set_shader_parameter("use_feature_exposure",true)
		snow_material.set_shader_parameter("feature_exposure",ImageTexture.create_from_image(field.exposure_image))
		snow_material.set_shader_parameter("feature_origin",field.MASK_ORIGIN)
		snow_material.set_shader_parameter("feature_size",Vector2(field.MASK_SIZE))
	_environment()
	build_timings.material_uploads_ms = (Time.get_ticks_usec()-upload_start)/1000.0
	_end_submission("material_uploads")
	var step_start = Time.get_ticks_usec()
	_begin_submission("terrain_meshes_uploads",preparation.terrain.chunks.size() if preparation else 0)
	if checkpoint.is_valid(): await _terrain(checkpoint)
	else: _terrain()
	build_timings.terrain_meshes_uploads_ms = (Time.get_ticks_usec()-step_start)/1000.0
	_end_submission("terrain_meshes_uploads")
	if _cancelled(): return
	if defer_startup_cosmetics:
		startup_cosmetics_pending = true; startup_vistas_pending = true
	else:
		step_start = Time.get_ticks_usec()
		_begin_submission("distant_scenery")
		if checkpoint.is_valid(): await checkpoint.call("Preparing distant scenery…",-1.0)
		await _vistas(checkpoint,data_worker)
		build_timings.distant_scenery_ms = (Time.get_ticks_usec()-step_start)/1000.0
		_end_submission("distant_scenery")
	if _cancelled(): return
	step_start = Time.get_ticks_usec()
	_begin_submission("forest_uploads")
	if checkpoint.is_valid(): await checkpoint.call("Placing trees, rocks and scenery…",-1.0)
	await _vegetation(checkpoint)
	build_timings.forest_uploads_ms = (Time.get_ticks_usec()-step_start)/1000.0
	_end_submission("forest_uploads")
	if _cancelled(): return
	step_start = Time.get_ticks_usec()
	_begin_submission("mineral_uploads",preparation.minerals.size() if preparation else 0)
	if "geology" in field:
		minerals=preload("res://scripts/presentation/mineral_scenery.gd").new()
		add_child(minerals)
		await minerals.build(field,assets,quality,checkpoint,preparation)
	build_timings.mineral_uploads_ms = (Time.get_ticks_usec()-step_start)/1000.0
	_end_submission("mineral_uploads")
	if _cancelled(): return
	_build_grass()
	step_start = Time.get_ticks_usec()
	_begin_submission("flavor")
	if checkpoint.is_valid(): await checkpoint.call("Preparing structures…",-1.0)
	flavor=preload("res://scripts/world/mountain_flavor.gd").new()
	add_child(flavor); flavor.build(field,assets,quality,snow_material)
	ski_surface=flavor.surface
	if field.GENERATOR_ID == "laboratory": _course_markers()
	build_timings.flavor_ms = (Time.get_ticks_usec()-step_start)/1000.0
	_end_submission("flavor")
	generation_ms = (Time.get_ticks_usec() - start) / 1000.0
	if build_job:
		var submission_ms = 0.0
		for value in build_timings.values(): submission_ms += value
		build_job.mutex.lock(); build_job.costs.scene_submission = submission_ms; build_job.counters.scene_submission = terrain_chunks.size()+scenery.batches.size(); build_job.mutex.unlock()

func _environment() -> void:
	var world = WorldEnvironment.new()
	var env = Environment.new()
	environment = env
	var sky = Sky.new()
	var material = ProceduralSkyMaterial.new()
	material.sky_top_color = Color("456b91")
	material.sky_horizon_color = Color("d7cfc5")
	material.ground_bottom_color = Color("637f98")
	material.ground_horizon_color = Color("b4d0e2")
	material.sky_curve = 0.22
	material.sun_angle_max = 5.0
	sky.sky_material = material
	original_sky = sky
	weather_material = ShaderMaterial.new()
	weather_material.shader = preload("res://assets/weather_sky.gdshader")
	weather_sky = Sky.new()
	weather_sky.sky_material = weather_material
	weather_sky.process_mode = Sky.PROCESS_MODE_REALTIME
	# Realtime radiance is fixed at 256 by the Forward+ renderer.
	weather_sky.radiance_size = Sky.RADIANCE_SIZE_256
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	# Retain the readable weather fill, with a restrained directional sky component.
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.42
	# Small contact-scale occlusion; never multiply direct sun or material AO.
	env.ssao_radius = 0.65
	env.ssao_intensity = 1.2
	env.ssao_power = 1.2
	env.ssao_detail = 0.35
	env.ssao_sharpness = 0.92
	env.ssao_light_affect = 0.20
	# The Forward+ renderer gates direct SSAO influence through this blend.
	# With zero here, ssao_light_affect has no visible direct-light effect.
	env.ssao_ao_channel_affect = 1.0
	# Local indirect detail only; keep rejection to limit light leaking.
	env.ssil_radius = 2.0
	env.ssil_intensity = 0.55
	env.ssil_sharpness = 0.9
	env.ssil_normal_rejection = 1.0
	# Four cascades bound camera-following GI work at racing speed.
	env.sdfgi_cascades = 4
	env.sdfgi_min_cell_size = 1.0
	env.sdfgi_y_scale = Environment.SDFGI_Y_SCALE_100_PERCENT
	env.sdfgi_use_occlusion = true
	env.sdfgi_read_sky_light = true
	env.sdfgi_energy = 0.8
	env.sdfgi_bounce_feedback = 0.2
	env.ambient_light_color = Color("abc5e1")
	env.ambient_light_energy = 0.32
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	Atmosphere.configure(env)
	env.fog_enabled = true
	env.fog_light_color = Color("aab8cb")
	env.fog_light_energy = 0.75
	env.fog_density = 0.00012
	world.environment = env
	add_child(world)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-24.0, -58.0, 0.0)
	sun.light_color = Color("ffe1bb")
	sun.light_energy = 1.25
	sun.light_bake_mode = Light3D.BAKE_DYNAMIC
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 220.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.shadow_bias = 0.035
	add_child(sun)
	moon = DirectionalLight3D.new()
	moon.name = "Moonlight"
	moon.light_energy = 0.0
	moon.visible = false
	moon.light_bake_mode = Light3D.BAKE_DYNAMIC
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 220.0
	moon.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	moon.shadow_bias = sun.shadow_bias
	add_child(moon)
	cloud_lighting.register(weather_material)

func update_weather(state, dt: float, animate: bool) -> void:
	last_weather_state = state
	if wilderness: wilderness.update_weather(state)
	assets.update_wind(state,dt,animate)
	# Stable preset lighting is independent of animated wind/cloud displacement.
	# One value comparison skips the per-property cache and its derived maths;
	# transitions still submit only individual values that actually changed.
	var next_weather = [state.enabled,state.sun_color,state.sun_energy,state.sun_direction,
		state.moon_color,state.moon_energy,state.ambient_color,state.ambient_energy,
		state.fog_color,state.fog_density,state.sky_top,state.sky_horizon,state.cloud_color,state.cloud_coverage]
	if next_weather!=weather_values:
		weather_values = next_weather
		render_state.assign(environment,&"sky",weather_sky if state.enabled else original_sky)
		render_state.assign(sun,&"light_color",state.sun_color)
		render_state.assign(sun,&"light_energy",state.sun_energy)
		render_state.assign(sun,&"basis",Basis.looking_at(-state.sun_direction,Vector3.UP))
		render_state.assign(sun,&"visible",state.sun_energy>0.001)
		render_state.assign(moon,&"basis",Basis.looking_at(state.sun_direction,Vector3.UP))
		render_state.assign(moon,&"light_color",state.moon_color)
		render_state.assign(moon,&"light_energy",state.moon_energy)
		render_state.assign(moon,&"visible",state.moon_energy>0.001)
		render_state.assign(environment,&"ambient_light_color",state.ambient_color)
		render_state.assign(environment,&"ambient_light_energy",state.ambient_energy)
		render_state.assign(environment,&"fog_light_color",state.fog_color)
		render_state.assign(environment,&"fog_density",state.fog_density*quality.fog_strength)
		render_state.assign(environment,&"fog_sky_affect",0.07 if state.enabled else 0.25)
		Atmosphere.apply(environment,sun,moon,weather_material,state,quality,render_state)
		if not state.enabled:
			var clear_material: ProceduralSkyMaterial = original_sky.sky_material
			render_state.assign(clear_material,&"sky_top_color",state.sky_top)
			render_state.assign(clear_material,&"sky_horizon_color",state.sky_horizon)
			render_state.assign(clear_material,&"ground_horizon_color",state.fog_color)
			render_state.assign(clear_material,&"ground_bottom_color",state.sky_top)
		else:
			for key in ["sky_top","sky_horizon","cloud_color","sun_color"]:
				render_state.shader(weather_material,key,state.get(key))
			render_state.shader(weather_material,"sun_glow_strength",smoothstep(0.0,0.16,state.sun_direction.y))
			render_state.shader(weather_material,"moon_glow_strength",smoothstep(0.01,0.20,-state.sun_direction.y))
	# Controller snapshots own displacement; world only submits completed state.
	cloud_offset = state.cloud_offset
	render_state.shader(weather_material,"high_wisps",quality.level==2)
	render_state.shader(weather_material,"lightning_flash",state.lightning_flash if state.enabled else 0.0)
	cloud_lighting.update(state,cloud_offset,state.sun_direction)
	var camera = get_viewport().get_camera_3d()
	if camera:
		render_state.shader(weather_material,"cloud_camera_position",camera.global_position)


func _terrain(checkpoint: Callable = Callable()) -> void:
	if preparation:
		await _prepared_terrain(checkpoint)
		return
	var chunk = 64 if surface.is_summit_mountain() else 32
	var lods = {0.7:_terrain_lod_indices(chunk,4),3.0:_terrain_lod_indices(chunk,8)} if surface.is_summit_mountain() else {}
	for cz in range(0, surface.NZ - 1, chunk):
		for cx in range(0, surface.NX - 1, chunk):
			var clipped = preload("res://scripts/world/terrain_preparation.gd").footprint_indices(Vector2(surface.X_MIN+cx*4,surface.Z_MIN+cz*4)) if preload("res://scripts/world/mountain_footprint.gd").enabled(surface) else {"mode":1}
			if clipped.mode==0: continue
			var nx = mini(chunk, surface.NX - 1 - cx)
			var nz = mini(chunk, surface.NZ - 1 - cz)
			var vertices = PackedVector3Array()
			var normals = PackedVector3Array()
			var indices = PackedInt32Array()
			for z in range(nz + 1):
				for x in range(nx + 1):
					var p = surface.vertex(cx + x, cz + z)
					vertices.append(p)
					if surface.GENERATOR_ID=="alpine-drainage":
						normals.append(surface.render_normal(p.x,p.z))
					else:
						var dx = surface.sample(p.x+2,p.z).height-surface.sample(p.x-2,p.z).height
						var dz = surface.sample(p.x,p.z+2).height-surface.sample(p.x,p.z-2).height
						normals.append(Vector3(-dx,4,dz*-1).normalized())
			for z in range(nz):
				for x in range(nx):
					var a = z * (nx + 1) + x
					var b = a + 1
					var c = a + nx + 1
					var d = c + 1
					indices.append_array(PackedInt32Array([a,b,c,b,d,c]))
			var arrays = []
			if clipped.mode==2: indices=clipped.indices
			arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX] = vertices
			arrays[Mesh.ARRAY_NORMAL] = normals
			arrays[Mesh.ARRAY_INDEX] = indices
			var mesh = ArrayMesh.new()
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{} if clipped.mode==2 else lods)
			var instance = MeshInstance3D.new()
			instance.mesh = mesh
			instance.gi_mode = GeometryInstance3D.GI_MODE_STATIC
			instance.material_override = snow_material
			instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			instance.set_meta("terrain_center",Vector2(surface.vertex(cx,cz).x+nx*surface.CELL*.5,surface.vertex(cx,cz).z+nz*surface.CELL*.5))
			instance.set_meta("trimmed_perimeter",clipped.mode==2)
			terrain_chunks.append(instance)
			add_child(instance)
			terrain_triangles += indices.size() / 3
			if checkpoint.is_valid() and terrain_chunks.size()%8 == 0:
				var total = ceili(float(surface.NX-1)/chunk)*ceili(float(surface.NZ-1)/chunk)
				await checkpoint.call("Building terrain · %d / %d sections" % [terrain_chunks.size(),total],100.0*terrain_chunks.size()/total)

func _vistas(checkpoint: Callable = Callable(), data_worker: Callable = Callable()) -> void:
	backdrop = preload("res://scripts/world/alpine_backdrop.gd").new()
	add_child(backdrop)
	var slice_budget = 2000 if startup_cosmetics_running else 0
	if surface.is_summit_mountain():
		# Keep the candidate private until its initial upload completes. A menu
		# quality change must not start a second build on its shared sampler.
		var candidate = preload("res://scripts/world/alpine_wilderness.gd").new()
		add_child(candidate)
		candidate.prepare(surface,mountain)
		await backdrop.build(surface,assets,mountain,candidate.data,checkpoint,slice_budget)
		# The joining collar must use the same snow/stone decision as the
		# retained support mesh. A separate procedural mask exposes its cut edge.
		for parameter in ["contact_material_enabled","contact_material","contact_material_origin","contact_material_size"]:
			backdrop.material.set_shader_parameter(parameter,snow_material.get_shader_parameter(parameter))
		snow_readability.bind(backdrop.material)
		candidate.apron_material = backdrop.material
		candidate.apron_sources = backdrop.triangle_sources
		candidate.worker = data_worker
		candidate.apron_triangles = backdrop.triangles
		candidate.apron_build_ms = backdrop.build_ms
		while not _cancelled():
			await candidate.apply_quality(quality,checkpoint)
			if candidate.requested_level==quality.backdrop_tier or not candidate.enabled: break
		wilderness = candidate
		if startup_cosmetics_running: wilderness.worker = Callable()
	else:
		await backdrop.build(surface,assets,mountain,null,checkpoint,slice_budget)

func _vegetation(checkpoint: Callable = Callable()) -> void:
	scenery = preload("res://scripts/world/alpine_scenery.gd").new()
	add_child(scenery)
	await scenery.build(surface,assets,quality,snow_material,checkpoint,preparation.forest if preparation else null)
	apply_graphics(quality)

func apply_graphics(profile) -> void:
	weather_values.clear()
	render_state.clear()
	quality = profile
	if not assets:
		return
	environment.ssao_enabled = profile.contact_shading
	environment.ssao_light_affect = profile.contact_intensity
	environment.ssil_intensity = profile.indirect_intensity
	RenderingServer.directional_soft_shadow_filter_set_quality(profile.shadow_quality)
	environment.ssil_enabled = profile.indirect_lighting
	environment.sdfgi_enabled = profile.terrain_gi
	Atmosphere.apply_quality(environment,profile)
	if last_weather_state:
		Atmosphere.apply(environment,sun,moon,weather_material,last_weather_state,profile)
	assets.apply_quality(profile)
	if wilderness: wilderness.apply_quality(profile)
	if flavor: flavor.apply_quality(profile)
	if minerals: minerals.apply_quality(profile)
	if grass: grass.apply_quality(profile)
	if scenery:
		scenery.apply_quality(profile)
	if sun:
		sun.directional_shadow_max_distance = profile.shadow_distance_m
		moon.directional_shadow_max_distance = profile.shadow_distance_m

func material(color: Color, emission: bool = false) -> ShaderMaterial:
	return cloud_lighting.material(color,0.7,false,emission)

func box(pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mesh = BoxMesh.new()
	mesh.size = size
	var node = MeshInstance3D.new()
	node.mesh = mesh
	node.position = pos
	node.material_override = material(color)
	add_child(node)
	return node

func _course_markers() -> void:
	var existing = get_children()
	_gate(5.0, 6.0, false)
	_gate(1450.0, 36.0, true)
	for z in range(125, 1450, 125):
		for side in [-1, 1]:
			var x = side * 37.0
			var h = surface.sample(x, z).height
			box(Vector3(x, h + 1.25, z), Vector3(0.10, 2.5, 0.10), Color("253f4d"))
			box(Vector3(x, h + 2.3, z), Vector3(0.38, 0.45, 0.09), Color("c6eb68"))
		if z % 250 == 0:
			var label = Label3D.new()
			label.text = "%d m" % (1450 - z)
			label.font_size = 52
			label.pixel_size = 0.022
			label.position = Vector3(41, surface.sample(41, z).height + 4.0, z)
			label.rotation.y = PI
			label.modulate = Color("203e4c")
			add_child(label)
	for child in get_children():
		if child not in existing and child is Node3D:
			benchmark_markers.append(child)

func set_benchmark_markers(enabled: bool) -> void:
	for marker in benchmark_markers:
		marker.visible = enabled

func _gate(z: float, width: float, finish: bool) -> void:
	var center_h = surface.sample(0, z).height
	var height_value = 8.0 if finish else 6.0
	for side in [-1, 1]:
		var x = side * width
		var h = surface.sample(x, z).height
		box(Vector3(x, h + height_value / 2, z), Vector3(0.42, height_value, 0.42), Color("163441"))
		box(Vector3(x, h + 1.0, z), Vector3(0.6, 2.0, 0.6), Color("c4ea5e"))
	box(Vector3(0, center_h + height_value, z), Vector3(width * 2 + 0.5, 1.3, 0.42), Color("163441"))
	var beams = preload("res://scripts/presentation/race_beams.gd").new()
	beams.name = "FinishBeam" if finish else "StartBeam"
	add_child(beams)
	beams.build(to_global(Vector3(0,center_h,z)),finish,surface)

static func _terrain_lod_indices(chunk: int, step: int) -> PackedInt32Array:
	# Only index buffers change with view distance. Every boundary vertex is
	# retained, so neighbouring LOD levels share exactly the same 4 m edge.
	# The base mesh remains exact for ski sampling and crash trimesh creation.
	var indices = PackedInt32Array()
	var stride = chunk+1
	for z in range(0,chunk,step):
		for x in range(0,chunk,step):
			var corners = [Vector2i(x,z),Vector2i(x+step,z),Vector2i(x+step,z+step),Vector2i(x,z+step)]
			var edge = x==0 or z==0 or x+step==chunk or z+step==chunk
			if not edge:
				var a = z*stride+x
				indices.append_array(PackedInt32Array([a,a+step,a+step*stride,a+step,a+step*(stride+1),a+step*stride]))
				continue
			var perimeter: Array[int] = []
			for side in 4:
				var a: Vector2i = corners[side]
				var b: Vector2i = corners[(side+1)%4]
				var boundary = (a.x==b.x and (a.x==0 or a.x==chunk)) or (a.y==b.y and (a.y==0 or a.y==chunk))
				var divisions = step if boundary else 1
				for i in divisions:
					var p = Vector2i(Vector2(a).lerp(Vector2(b),float(i)/divisions))
					perimeter.append(p.y*stride+p.x)
			var center = (z+step/2)*stride+x+step/2
			for i in perimeter.size(): indices.append_array(PackedInt32Array([center,perimeter[i],perimeter[(i+1)%perimeter.size()]]))
	return indices

func _cancelled() -> bool:
	return build_job!=null and build_job.is_cancelled()

func _prepared_terrain(checkpoint: Callable) -> void:
	var data = preparation.terrain
	for chunk in data.chunks:
		if _cancelled(): return
		var arrays: Array = []; arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = chunk.vertices; arrays[Mesh.ARRAY_NORMAL] = chunk.normals; arrays[Mesh.ARRAY_INDEX] = chunk.get("indices",data.indices)
		var mesh = ArrayMesh.new(); mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],chunk.get("lods",data.lods))
		var instance = MeshInstance3D.new(); instance.mesh = mesh
		instance.gi_mode = GeometryInstance3D.GI_MODE_STATIC; instance.material_override = snow_material
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		instance.set_meta("terrain_center",chunk.center)
		instance.set_meta("trimmed_perimeter",chunk.has("indices"))
		terrain_chunks.append(instance); add_child(instance); terrain_triangles += arrays[Mesh.ARRAY_INDEX].size()/3
		if build_job: build_job.advance()
		if checkpoint.is_valid() and terrain_chunks.size()%4==0:
			await checkpoint.call("Building terrain · %d / %d sections" % [terrain_chunks.size(),data.chunks.size()],100.0*terrain_chunks.size()/data.chunks.size())
	# GPU meshes now own their buffers; the reusable copy is on disk.
	data.chunks.clear()

func _configure_submission_stages() -> void:
	if not build_job: return
	# Broad stage weights are refined by measured work as each upload completes.
	var weights = {"material_uploads":.02,"terrain_meshes_uploads":.30,"distant_scenery":.05,"forest_uploads":.20,"mineral_uploads":.40,"flavor":.03}
	if defer_startup_cosmetics: weights.erase("distant_scenery")
	build_job.mutex.lock()
	var predicted_ms = float(build_job.expected_stages.get("scene_submission",50000.0))
	build_job.expected_stages.erase("scene_submission")
	for key in weights: build_job.expected_stages[key] = predicted_ms*weights[key]
	build_job.mutex.unlock()

func _begin_submission(name: String, work: int = 0) -> void:
	if build_job: build_job.begin_stage(name,work)

func _end_submission(name: String) -> void:
	if build_job: build_job.end_stage(name)

func _build_grass() -> void:
	if defer_startup_cosmetics and not startup_cosmetics_running:
		startup_cosmetics_pending = true
		return
	grass=preload("res://scripts/presentation/terrain_grass.gd").new()
	add_child(grass)
	grass.build(surface,assets,quality)
	grass.bind_minerals(minerals)

func finish_startup_cosmetics(checkpoint: Callable = Callable(), data_worker: Callable = Callable()) -> void:
	if not startup_cosmetics_pending or startup_cosmetics_running: return
	startup_cosmetics_pending = false
	if _cancelled(): return
	startup_cosmetics_running = true
	var started = Time.get_ticks_usec()
	_build_grass()
	if checkpoint.is_valid(): await checkpoint.call()
	if startup_vistas_pending and not _cancelled(): await _vistas(checkpoint,data_worker)
	startup_vistas_pending = false
	startup_cosmetics_ms = (Time.get_ticks_usec()-started)/1000.0
	startup_cosmetics_running = false
	# This duration includes cooperative waits and is separate from menu-ready
	# loading estimates. The completed GenerationJob is never re-opened.
	print("STARTUP_COSMETICS_COMPLETE ",startup_cosmetics_ms," ms elapsed")

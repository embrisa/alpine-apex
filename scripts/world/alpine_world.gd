extends Node3D
## Bounded static mountain: shared terrain grid, culled chunks and spatially
## grouped MultiMeshes. No per-tree Nodes, physics bodies, or per-frame allocation.
var surface
var mountain
var mountain_seed: int = -1
var assets
var scenery
var quality = preload("res://scripts/presentation/graphics_quality.gd").preset(1)
var snow_material: ShaderMaterial
var generation_ms: float = 0.0
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

func build(field) -> void:
	var start = Time.get_ticks_usec()
	surface = field
	mountain = preload("res://scripts/world/mountain_data.gd").new()
	mountain.generate(field,field.seed_value+4187 if mountain_seed<0 else mountain_seed)
	assets = preload("res://scripts/presentation/alpine_assets.gd").new(cloud_lighting,quality)
	assets.mountain = mountain
	snow_material = assets.terrain_material()
	if field.has_method("exposure_at"):
		# A localized 4 m feature mask preserves narrow snow ramps between cliffs.
		snow_material.set_shader_parameter("use_feature_exposure",true)
		snow_material.set_shader_parameter("feature_exposure",ImageTexture.create_from_image(field.exposure_image))
		snow_material.set_shader_parameter("feature_origin",field.MASK_ORIGIN)
		snow_material.set_shader_parameter("feature_size",Vector2(field.MASK_SIZE))
	_environment()
	_terrain()
	_vistas()
	_vegetation()
	if field.GENERATOR_ID == "laboratory": _course_markers()
	generation_ms = (Time.get_ticks_usec() - start) / 1000.0

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
	env.ambient_light_sky_contribution = 0.25
	# Small contact-scale occlusion; never multiply direct sun or material AO.
	env.ssao_radius = 0.65
	env.ssao_intensity = 1.2
	env.ssao_power = 1.2
	env.ssao_detail = 0.35
	env.ssao_sharpness = 0.92
	env.ssao_light_affect = 0.0
	env.ssao_ao_channel_affect = 0.0
	# Local indirect detail only; keep rejection to limit light leaking.
	env.ssil_radius = 2.0
	env.ssil_intensity = 0.7
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
	assets.update_wind(state,dt,animate)
	environment.sky = weather_sky if state.enabled else original_sky
	sun.light_color = state.sun_color
	sun.light_energy = state.sun_energy
	sun.basis = Basis.looking_at(-state.sun_direction,Vector3.UP)
	sun.visible = state.sun_energy>0.001
	moon.basis = Basis.looking_at(state.sun_direction,Vector3.UP)
	moon.light_color = state.moon_color
	moon.light_energy = state.moon_energy
	moon.visible = state.moon_energy>0.001
	environment.ambient_light_color = state.ambient_color
	environment.ambient_light_energy = state.ambient_energy
	environment.fog_light_color = state.fog_color
	environment.fog_density = state.fog_density
	environment.fog_sky_affect = 0.25 if state.enabled else 1.0
	# Integrate displacement instead of multiplying time by changing wind:
	# a gust or transition must not teleport the clouds.
	if animate and state.enabled:
		cloud_offset += Vector2(state.wind_velocity.x,state.wind_velocity.z)*dt
	cloud_lighting.update(state,cloud_offset,state.sun_direction)
	var camera = get_viewport().get_camera_3d()
	if camera:
		weather_material.set_shader_parameter("cloud_camera_position",camera.global_position)
	if not state.enabled:
		var clear_material: ProceduralSkyMaterial = original_sky.sky_material
		clear_material.sky_top_color = state.sky_top
		clear_material.sky_horizon_color = state.sky_horizon
		clear_material.ground_horizon_color = state.fog_color
		clear_material.ground_bottom_color = state.sky_top
		return
	for key in ["sky_top","sky_horizon","cloud_color","sun_color"]:
		weather_material.set_shader_parameter(key,state.get(key))
	weather_material.set_shader_parameter("sun_glow_strength",smoothstep(0.0,0.16,state.sun_direction.y))
	weather_material.set_shader_parameter("moon_glow_strength",smoothstep(0.01,0.20,-state.sun_direction.y))

func _terrain() -> void:
	var chunk = 64 if surface.is_summit_mountain() else 32
	var lods = {0.7:_terrain_lod_indices(chunk,4),3.0:_terrain_lod_indices(chunk,8)} if surface.is_summit_mountain() else {}
	for cz in range(0, surface.NZ - 1, chunk):
		for cx in range(0, surface.NX - 1, chunk):
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
			arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX] = vertices
			arrays[Mesh.ARRAY_NORMAL] = normals
			arrays[Mesh.ARRAY_INDEX] = indices
			var mesh = ArrayMesh.new()
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],lods)
			var instance = MeshInstance3D.new()
			instance.mesh = mesh
			instance.gi_mode = GeometryInstance3D.GI_MODE_STATIC
			instance.material_override = snow_material
			instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			instance.set_meta("terrain_center",Vector2(surface.vertex(cx,cz).x+nx*surface.CELL*.5,surface.vertex(cx,cz).z+nz*surface.CELL*.5))
			terrain_chunks.append(instance)
			add_child(instance)
			terrain_triangles += indices.size() / 3

func _vistas() -> void:
	var backdrop = preload("res://scripts/world/alpine_backdrop.gd").new()
	add_child(backdrop)
	backdrop.build(surface,assets,mountain)

func _vegetation() -> void:
	scenery = preload("res://scripts/world/alpine_scenery.gd").new()
	add_child(scenery)
	scenery.build(surface,assets,quality)
	apply_graphics(quality)

func apply_graphics(profile) -> void:
	quality = profile
	if not assets:
		return
	environment.ssao_enabled = profile.contact_shading
	environment.ssil_enabled = profile.indirect_lighting
	environment.sdfgi_enabled = profile.terrain_gi
	assets.apply_quality(profile)
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
	_gate(5.0, 6.0, "APEX  /  DROP IN", false)
	_gate(1450.0, 36.0, "FINISH", true)
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

func _gate(z: float, width: float, title: String, finish: bool) -> void:
	var center_h = surface.sample(0, z).height
	var height_value = 8.0 if finish else 6.0
	for side in [-1, 1]:
		var x = side * width
		var h = surface.sample(x, z).height
		box(Vector3(x, h + height_value / 2, z), Vector3(0.42, height_value, 0.42), Color("163441"))
		box(Vector3(x, h + 1.0, z), Vector3(0.6, 2.0, 0.6), Color("c4ea5e"))
	box(Vector3(0, center_h + height_value, z), Vector3(width * 2 + 0.5, 1.3, 0.42), Color("163441"))
	var label = Label3D.new()
	label.text = title
	label.font_size = 96
	label.pixel_size = 0.011 if not finish else 0.035
	label.position = Vector3(0, center_h + height_value, z - 0.24)
	label.rotation.y = PI
	label.modulate = Color("eaf1ef")
	label.outline_size = 0
	add_child(label)

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

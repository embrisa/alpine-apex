extends RefCounted
## Golden noon presentation. Consumes blended weather; never advances time,
## changes the light direction or touches the solver.
const SHAFT_LENGTH_M = 120.0 # Inside the 160 m tree / 220 m terrain shadows.
const SHAFT_DENSITY = 0.0001
const SHAFT_ENERGY = 16.0

static func configure(environment: Environment) -> void:
	environment.volumetric_fog_density = SHAFT_DENSITY
	environment.volumetric_fog_albedo = Color.WHITE
	environment.volumetric_fog_emission = Color.BLACK
	environment.volumetric_fog_gi_inject = 0.0
	environment.volumetric_fog_ambient_inject = 0.0
	environment.volumetric_fog_anisotropy = 0.65
	environment.volumetric_fog_detail_spread = 2.0
	environment.volumetric_fog_sky_affect = 0.65
	# Short history reduces trails when skiing rapidly past an occluder.
	environment.volumetric_fog_temporal_reprojection_enabled = true
	environment.volumetric_fog_temporal_reprojection_amount = 0.6
	environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	environment.glow_bloom = 0.0
	environment.glow_hdr_threshold = 1.4
	environment.glow_hdr_scale = 1.8
	environment.glow_hdr_luminance_cap = 16.0
	environment.glow_strength = 0.85
	for level in 7:
		environment.set_glow_level(level,[0.0,0.25,0.65,0.45,0.12,0.0,0.0][level])

static func apply_quality(environment: Environment, quality) -> void:
	environment.volumetric_fog_length = minf(SHAFT_LENGTH_M,quality.shadow_distance_m)
	# One active game world; renderer budgets belong to the graphics preset.
	if quality.volumetric_shafts:
		RenderingServer.environment_set_volumetric_fog_volume_size(128,64)
		RenderingServer.environment_set_volumetric_fog_filter_active(true)
	environment.volumetric_fog_enabled = false
	environment.glow_enabled = quality.highlight_glow

static func apply(environment: Environment, sun: DirectionalLight3D, moon: DirectionalLight3D, sky: ShaderMaterial, state, quality, cache = null) -> void:
	var day = smoothstep(0.0,0.16,state.sun_direction.y)
	var clear = 1.0-smoothstep(0.20,0.98,state.cloud_coverage)
	var golden = day*clear
	# Roll off highlights to preserve scanned snow and track lips.
	if cache: cache.assign(environment,&"tonemap_exposure",lerpf(1.0,1.15,golden))
	else: environment.tonemap_exposure = lerpf(1.0,1.15,golden)
	if cache: cache.assign(environment,&"tonemap_white",lerpf(1.0,2.8,golden))
	else: environment.tonemap_white = lerpf(1.0,2.8,golden)
	if cache: cache.assign(environment,&"fog_light_energy",lerpf(0.75,0.85,golden))
	else: environment.fog_light_energy = lerpf(0.75,0.85,golden)
	if cache: cache.assign(environment,&"fog_sun_scatter",0.08*golden)
	else: environment.fog_sun_scatter = 0.08*golden
	if cache: cache.assign(environment,&"glow_enabled",quality.highlight_glow and state.enabled and day>0.001)
	else: environment.glow_enabled = quality.highlight_glow and state.enabled and day>0.001
	if cache: cache.assign(environment,&"glow_intensity",quality.highlight_glow_intensity*day*lerpf(0.15,1.0,clear))
	else: environment.glow_intensity = quality.highlight_glow_intensity*day*lerpf(0.15,1.0,clear)
	var shaft_weight = day*clear*clear if state.enabled else 0.0
	if cache: cache.assign(environment,&"volumetric_fog_enabled",quality.volumetric_shafts and shaft_weight>0.001)
	else: environment.volumetric_fog_enabled = quality.volumetric_shafts and shaft_weight>0.001
	if cache: cache.assign(sun,&"light_volumetric_fog_energy",SHAFT_ENERGY*quality.shaft_strength*shaft_weight if environment.volumetric_fog_enabled else 0.0)
	else: sun.light_volumetric_fog_energy = SHAFT_ENERGY*quality.shaft_strength*shaft_weight if environment.volumetric_fog_enabled else 0.0
	if cache: cache.assign(moon,&"light_volumetric_fog_energy",0.0)
	else: moon.light_volumetric_fog_energy = 0.0
	if cache: cache.shader(sky,"sun_disc_energy",14.0*clampf(state.sun_energy/1.9,0.0,1.5))
	else: sky.set_shader_parameter("sun_disc_energy",14.0*clampf(state.sun_energy/1.9,0.0,1.5))
	if cache: cache.shader(sky,"sun_halo_energy",day*lerpf(0.15,1.0,clear))
	else: sky.set_shader_parameter("sun_halo_energy",day*lerpf(0.15,1.0,clear))

extends Node3D
var frame_costs
## Fixed-size effects. Presentation randomness never enters the simulation.
const Response = preload("res://scripts/presentation/snow_response.gd")
var responses: Array = [Response.new(),Response.new()]
var emission_origins: Array[Vector3] = [Vector3.ZERO,Vector3.ZERO]
var quality_level = -1
var sprays: Array = []
var snow_tracks
var powder_surface
var rock_sparks
var tracks: MultiMesh:
	get: return snow_tracks.tracks if snow_tracks else null
var track_cursor: int:
	get: return snow_tracks.cursor if snow_tracks else 0
var audio_wind: AudioStreamPlayer
var wind = preload("res://scripts/presentation/procedural_wind.gd").new()
var sfx = preload("res://scripts/presentation/procedural_sfx.gd").new()
var audio_ski: AudioStreamPlayer
var muted: bool = false
var haptics = preload("res://scripts/presentation/rider_haptics.gd").new()
var haptic_hardware_enabled = DisplayServer.get_name()!="headless"
var haptic_output = Vector3.ZERO
var haptic_applied_id = -1
var haptic_applied_motors = Vector2.ZERO
var audio_edge: AudioStreamPlayer
var audio_rain: AudioStreamPlayer
var lighting = preload("res://scripts/presentation/cloud_lighting.gd").new()

func _exit_tree() -> void:
	stop_audio()
	reset_haptics()

func reset_haptics() -> void:
	haptics.reset()
	haptic_output = Vector3.ZERO
	haptic_applied_id = -1
	haptic_applied_motors = Vector2.ZERO
	if haptic_hardware_enabled:
		for pad in Input.get_connected_joypads(): Input.stop_joy_vibration(pad)

func update_haptics(dt: float, active: bool, crash_visible: bool, intensity: float) -> void:
	haptic_output = haptics.advance(dt,active,crash_visible,intensity)
	var motors = Vector2(haptic_output.x,haptic_output.y)
	if motors==haptic_applied_motors and (motors==Vector2.ZERO or haptic_applied_id==haptics.pulse_id): return
	haptic_applied_motors = motors
	haptic_applied_id = haptics.pulse_id
	if not haptic_hardware_enabled: return
	for pad in Input.get_connected_joypads():
		if motors==Vector2.ZERO: Input.stop_joy_vibration(pad)
		else: Input.start_joy_vibration(pad,motors.x,motors.y,haptic_output.z)

func stop_audio() -> void:
	wind.stop_audio()
	sfx.stop_audio()
	for player in [audio_wind,audio_ski,audio_edge,audio_rain]:
		if is_instance_valid(player):
			player.stop()
			player.stream = null

func _ready() -> void:
	for kind in [0,1,2]:
		for side in [-1,1]:
			var spray = GPUParticles3D.new()
			spray.amount = 1
			spray.lifetime = [.95,.60,1.9][kind]
			spray.fixed_fps = 60
			spray.local_coords = false
			spray.emitting = false
			# Includes the world-space racing trail through the mist lifetime.
			spray.visibility_aabb = AABB(Vector3(-180,-90,-180),Vector3(360,180,360))
			var process = ShaderMaterial.new()
			process.shader = preload("res://assets/graphics/snow_particles.gdshader")
			process.set_shader_parameter("kind",kind)
			spray.process_material = process
			var quad = QuadMesh.new()
			quad.size = Vector2.ONE
			var material = ShaderMaterial.new()
			material.shader = preload("res://assets/graphics/snow_spray.gdshader")
			material.set_shader_parameter("kind",kind)
			lighting.register(material)
			quad.material = material
			spray.draw_pass_1 = quad
			spray.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(spray)
			sprays.append(spray)
	snow_tracks = preload("res://scripts/presentation/snow_tracks.gd").new()
	snow_tracks.lighting = lighting
	add_child(snow_tracks)
	rock_sparks = preload("res://scripts/presentation/rock_sparks.gd").new()
	add_child(rock_sparks)
	audio_wind = _audio("res://assets/wind.wav")
	add_child(wind)
	wind.setup(audio_wind)
	add_child(sfx)
	audio_ski = _audio("res://assets/ski.wav")
	# Separate scrape layer stays quiet on a clean line and bites under edge load.
	audio_edge = _audio("res://assets/ski.wav")
	audio_rain = _audio("res://assets/rain.wav")

func _audio(path: String) -> AudioStreamPlayer:
	var player = AudioStreamPlayer.new()
	# Headless tests have no audio device; avoid starting looping playbacks on
	# the dummy audio driver (which cannot drain them during scene teardown).
	if DisplayServer.get_name() == "headless":
		add_child(player)
		return player
	var stream = load(path) as AudioStreamWAV
	if stream:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = stream.data.size() / 2
	player.stream = stream
	player.volume_db = -60.0
	add_child(player)
	player.play()
	return player

func reset() -> void:
	sfx.reset()
	reset_haptics()
	if rock_sparks: rock_sparks.reset()
	if snow_tracks: snow_tracks.reset()
	if powder_surface: powder_surface.reset()
	for spray in sprays:
		spray.restart()
		spray.emitting = false

func update_effects(sim, field, position_value: Vector3, dt: float, active: bool, weather = null, ragdoll = null, listener: Camera3D = null, crash_visible: bool = false, speaking: bool = false, ski_visuals: Array = []) -> void:
	var speed: float = sim.velocity.length()
	var ratio = clampf(sim.speed_kmh() / 200.0, 0.0, 1.0)
	var slip = absf(sin(sim.slip_angle))
	for i in range(2):
		var ski = sim.skis[i]
		responses[i].sample(sim,ski,field)
		responses[i].contact_position += position_value-sim.position
		if ski_visuals.size()==2 and not sim.crashed:
			# Read the already rendered equipment timestamp, including turn and
			# switch interpolation. Never infer a ski pose from the body root.
			var visual = ski_visuals[1-i if sim.facing_backward else i]
			responses[i].contact_position = visual.global_position
			responses[i].contact_forward = visual.global_basis.z.normalized()
		responses[i].resolve_track_contact(sim,ski,field)
		var tail: Vector3 = responses[i].contact_position+responses[i].contact_forward*lerpf(.05,.32,responses[i].turn_work)
		# Tail terrain can be higher than the boot on a mound. Births must clear
		# that surface and High's loose crowns or depth testing hides the spray.
		tail.y = field.sample(tail.x,tail.z).height
		emission_origins[i] = tail+ski.normal*.12
	rock_sparks.update_contact(sim,position_value,active,responses)
	for i in range(sprays.size()):
		var spray: GPUParticles3D = sprays[i]
		var kind: int = i / 2
		var ski = sim.skis[i%2]
		var response = responses[i%2]
		var intensity: float = [response.powder,response.grains,response.mist][kind]
		spray.position = emission_origins[i%2]
		var forward: Vector3 = response.contact_forward
		spray.basis = Basis(ski.normal.cross(forward).normalized(),ski.normal,forward)
		spray.emitting = active and response.supported and intensity>.002 and spray.visible
		spray.speed_scale = 1.0 if active else 0.0
		var process: ShaderMaterial = spray.process_material
		process.set_shader_parameter("emission_ratio",intensity if spray.emitting else 0.0)
		process.set_shader_parameter("contact_energy",response.disturbance)
		process.set_shader_parameter("ejection_m_s",response.ejection_m_s)
		process.set_shader_parameter("throw_side",response.throw_side)
		process.set_shader_parameter("skier_velocity",sim.velocity)
		process.set_shader_parameter("wind_velocity",weather.wind_velocity.limit_length(35.0) if weather!=null and weather.enabled else Vector3.ZERO)
	var snow_started = frame_costs.begin() if frame_costs else 0
	snow_tracks.update_contact(sim,field,position_value,active,responses)
	if powder_surface: powder_surface.update_surface(sim,position_value,responses)
	if frame_costs: frame_costs.end(&"snow_tracks_powder",snow_started)
	var audible = active and not muted and not sim.crashed
	var wind_db = lerpf(-48.0,-7.0,pow(ratio,0.72)) if audible else -65.0
	if audible:
		var gust: float = weather.gust if weather != null else 0.0
		var weather_wind: float = weather.wind_velocity.length() if weather != null else 0.0
		if weather != null and weather.enabled:
			wind_db = minf(-5.5, wind_db + smoothstep(90.0,200.0,sim.speed_kmh()) * 1.5 + gust * 1.2)
			wind_db = maxf(wind_db, -43.0 + minf(weather_wind,15.0))
	var ski_db = lerpf(-39.0,-22.0,smoothstep(0.0,90.0,sim.speed_kmh())) + minf(sim.landing_force,6.0) if audible and sim.grounded else -65.0
	ski_db = lerpf(ski_db,-65.0,sim.rock_contact)
	var edge_db = -42.0 + sim.edge_load * 11.0 + slip * 12.0 + minf(sim.landing_force,8.0) if audible and sim.grounded and speed>2.0 else -65.0
	if audible and sim.grounded and speed>2.0:
		edge_db = maxf(edge_db,lerpf(-65.0,-27.0,sim.rock_contact))
	wind.sample(sim,weather,audible,wind_db)
	sfx.advance(sim,field,ragdoll,listener,wind,weather,dt,audible,crash_visible,muted,speaking)
	wind.advance(dt)
	audio_wind.pitch_scale = 0.7 + ratio * 0.7
	var rain: float = weather.rain if weather != null and weather.enabled else 0.0
	var rain_db: float = lerpf(-42.0,-17.0,sqrt(rain)) if audible and rain>0.001 else -65.0
	audio_rain.volume_db = lerpf(audio_rain.volume_db,rain_db,1.0-exp(-dt*5.0))
	var legacy_gain = sqrt(1.0-sfx.blend)*sfx.snow
	ski_db = ski_db+linear_to_db(legacy_gain) if legacy_gain>.00001 else -80.0
	edge_db = edge_db+linear_to_db(legacy_gain) if legacy_gain>.00001 else -80.0
	audio_ski.volume_db = lerpf(audio_ski.volume_db,ski_db,1.0-exp(-dt*8.0))
	audio_ski.pitch_scale = 0.85 + ratio * 0.9 + slip * 0.2
	audio_edge.volume_db = lerpf(audio_edge.volume_db,edge_db,1.0-exp(-dt*12.0))
	audio_edge.pitch_scale = 1.5 + sim.edge_load * 0.45 + slip * 0.6
	update_haptics(dt,active,crash_visible,sim.tuning.vibration_intensity)

func apply_quality(profile) -> void:
	quality_level = profile.level
	rock_sparks.apply_quality(profile.level)
	for i in range(sprays.size()):
		var count: int = profile.snow_particles[i/2]
		sprays[i].amount = maxi(1,count)
		sprays[i].visible = count>0
		sprays[i].emitting = false
		sprays[i].draw_pass_1.material.set_shader_parameter("soft_intersection",quality_level>0)
	snow_tracks.apply_quality(profile)
	if powder_surface: powder_surface.apply_quality(profile)

func bind_powder_surface(world, profile) -> void:
	world.snow_readability.bind(snow_tracks.material)
	powder_surface = preload("res://scripts/presentation/powder_surface.gd").new()
	add_child(powder_surface)
	powder_surface.bind(snow_tracks,world,profile)

func snow_budget() -> Dictionary:
	var count = 0
	for spray in sprays:
		if spray.visible: count += spray.amount
	return {"gpu_particles":count,"track_capacity":snow_tracks.capacity,"track_instances":snow_tracks.written,
		"live_track_capacity":2,"live_track_instances":snow_tracks.live_active.count(true),
		"rock_spark_particles":rock_sparks.emitters[0].amount*2 if rock_sparks else 0,
		"paired_history_m":snow_tracks.capacity*snow_tracks.SPACING_M*.5,"surface_texture_bytes":snow_tracks.surface_texture_bytes,
		"local_deformation":powder_surface.budget() if powder_surface else {"enabled":false}}

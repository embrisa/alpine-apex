extends Node3D
## Fixed-size effects. Presentation randomness never enters the simulation.
var sprays: Array = []
var snow_tracks
var tracks: MultiMesh:
	get: return snow_tracks.tracks if snow_tracks else null
var track_cursor: int:
	get: return snow_tracks.cursor if snow_tracks else 0
var audio_wind: AudioStreamPlayer
var audio_ski: AudioStreamPlayer
var muted: bool = false
var haptic_clock: float = 0.0
var audio_edge: AudioStreamPlayer
var audio_rain: AudioStreamPlayer
var lighting = preload("res://scripts/presentation/cloud_lighting.gd").new()

func _exit_tree() -> void:
	stop_audio()
	for pad in Input.get_connected_joypads():
		Input.stop_joy_vibration(pad)

func stop_audio() -> void:
	for player in [audio_wind,audio_ski,audio_edge,audio_rain]:
		if is_instance_valid(player):
			player.stop()
			player.stream = null

func _ready() -> void:
	for kind in [0,1]:
		for side in [-1,1]:
			var spray = GPUParticles3D.new()
			spray.amount = 110 if kind==0 else 80
			spray.lifetime = 0.85 if kind==0 else 0.50
			spray.local_coords = false
			spray.emitting = false
			spray.visibility_aabb = AABB(Vector3(-20,-16,-20),Vector3(40,32,40))
			var process = ParticleProcessMaterial.new()
			process.direction = Vector3(side*0.6,0.7,0.2)
			process.spread = 28.0 if kind==0 else 38.0
			process.initial_velocity_min = 0.8
			process.initial_velocity_max = 3.5
			process.gravity = Vector3(0,-3.2 if kind==0 else -9.81,0)
			process.damping_min = 0.6 if kind==0 else 0.0
			process.damping_max = 1.4 if kind==0 else 0.2
			process.scale_min = 0.08 if kind==0 else 0.012
			process.scale_max = 0.24 if kind==0 else 0.035
			process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
			process.emission_box_extents = Vector3(0.035,0.01,0.45)
			var gradient = Gradient.new()
			gradient.set_color(0,Color(1,1,1,0.75))
			gradient.add_point(0.25,Color(1,1,1,0.65))
			gradient.set_color(gradient.get_point_count()-1,Color(1,1,1,0))
			var ramp = GradientTexture1D.new()
			ramp.gradient = gradient
			process.color_ramp = ramp
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
	audio_wind = _audio("res://assets/wind.wav")
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
	if snow_tracks: snow_tracks.reset()
	for spray in sprays:
		spray.restart()
	for pad in Input.get_connected_joypads():
		Input.stop_joy_vibration(pad)

func update_effects(sim, field, position_value: Vector3, dt: float, active: bool, weather = null) -> void:
	var speed: float = sim.velocity.length()
	var ratio = clampf(sim.speed_kmh() / 200.0, 0.0, 1.0)
	var racing = smoothstep(60.0, 150.0, sim.speed_kmh())
	var slip = absf(sin(sim.slip_angle))
	var forward: Vector3 = sim.ski_forward
	var right: Vector3 = sim.surface_normal.cross(forward).normalized()
	var basis_value = Basis(right,sim.surface_normal,forward)
	for i in range(sprays.size()):
		var spray = sprays[i]
		var kind = i / 2
		var side = -1.0 if i%2==0 else 1.0
		var ski = sim.skis[i%2]
		spray.position = position_value + right*side*0.22 - forward*0.35 + sim.surface_normal*0.045
		spray.basis = basis_value
		if sim.contacts_initialized:
			spray.position = ski.position+(position_value-sim.position)-ski.forward*.35+ski.normal*.045
			spray.basis = Basis(ski.normal.cross(ski.forward).normalized(),ski.normal,ski.forward)
		spray.emitting = active and sim.grounded and speed>1.5 and not sim.crashed and (not sim.contacts_initialized or (ski.grounded and ski.load_n>1.0))
		spray.speed_scale = 1.0 if active else 0.0
		var powder: float = clampf((ski.penetration if sim.contacts_initialized else sim.snow_penetration)/0.07,0.0,1.0)
		var plough: float = clampf((ski.snow_drag*2.0 if sim.contacts_initialized else sim.snow_drag)/2.0,0.0,1.0)
		spray.amount_ratio = clampf(0.10+racing*0.18+powder*0.20+plough*0.20+slip*0.60+sim.edge_load*0.24+sim.landing_force*0.10,0.0,1.0)
		var process: ParticleProcessMaterial = spray.process_material
		# The loaded edge and measured sideways slip throw more snow outward.
		process.direction = Vector3(side*0.55-signf(sim.slip_angle)*slip*0.9,0.65,0.18).normalized()
		process.initial_velocity_max = 1.8+speed*0.045+slip*5.0+minf(sim.landing_force,8.0)*0.4
		process.scale_max = (0.20+powder*0.14+plough*0.20+slip*0.26) if kind==0 else (0.032+powder*0.016+slip*0.025)
	snow_tracks.update_contact(sim,field,position_value,active)
	var audible = active and not muted and not sim.crashed
	var wind_db = lerpf(-48.0,-7.0,pow(ratio,0.72)) if audible else -65.0
	if audible:
		var gust: float = weather.gust if weather != null else 0.0
		var weather_wind: float = weather.wind_velocity.length() if weather != null else 0.0
		if weather != null and weather.enabled:
			wind_db = minf(-5.5, wind_db + smoothstep(90.0,200.0,sim.speed_kmh()) * 1.5 + gust * 1.2)
			wind_db = maxf(wind_db, -43.0 + minf(weather_wind,15.0))
	var ski_db = lerpf(-39.0,-22.0,smoothstep(0.0,90.0,sim.speed_kmh())) + minf(sim.landing_force,6.0) if audible and sim.grounded else -65.0
	var edge_db = -42.0 + sim.edge_load * 11.0 + slip * 12.0 + minf(sim.landing_force,8.0) if audible and sim.grounded and speed>2.0 else -65.0
	audio_wind.volume_db = lerpf(audio_wind.volume_db,wind_db,1.0-exp(-dt*5.0))
	audio_wind.pitch_scale = 0.7 + ratio * 0.7
	var rain: float = weather.rain if weather != null and weather.enabled else 0.0
	var rain_db: float = lerpf(-42.0,-17.0,sqrt(rain)) if audible and rain>0.001 else -65.0
	audio_rain.volume_db = lerpf(audio_rain.volume_db,rain_db,1.0-exp(-dt*5.0))
	audio_ski.volume_db = lerpf(audio_ski.volume_db,ski_db,1.0-exp(-dt*8.0))
	audio_ski.pitch_scale = 0.85 + ratio * 0.9 + slip * 0.2
	audio_edge.volume_db = lerpf(audio_edge.volume_db,edge_db,1.0-exp(-dt*12.0))
	audio_edge.pitch_scale = 1.5 + sim.edge_load * 0.45 + slip * 0.6
	haptic_clock += dt
	if haptic_clock > 0.1:
		haptic_clock = 0.0
		for pad in Input.get_connected_joypads():
			if active:
				var strength: float = sim.tuning.vibration_intensity
				Input.start_joy_vibration(pad, minf(1.0,ratio*ratio*0.30+(sim.edge_load*0.28+slip*0.35)*float(sim.grounded))*strength, minf(1.0,sim.landing_force*0.10+sim.balance_pressure*0.12+float(sim.crashed))*strength,0.11)
			else:
				Input.stop_joy_vibration(pad)

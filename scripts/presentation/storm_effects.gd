extends Node3D
## Bounded distant effects. Absolute active-time schedule; no timers or delayed backlog.
const CLIPS = [preload("res://assets/audio/weather/thunder_01.wav"),preload("res://assets/audio/weather/thunder_02.wav"),preload("res://assets/audio/weather/thunder_03.wav")]
const SLOT_SECONDS = 18.0
const VOICES = 3
var bolts: Array[MeshInstance3D] = []
var players: Array[AudioStreamPlayer3D] = []
var materials: Array[StandardMaterial3D] = []
var last_clock = -1.0
var reset_clock = 0.0
var last_thunder = -1
var cursor = 0
var event_slot = -999
var events: Array = []
var active_before = false
var reset_serial = 0
var played_count = 0
var illumination = 0.0
var layer_height = 5400.0
var event_seed = -1

func _ready() -> void:
	# Branch geometry and audio players are created once, outside riding updates.
	for variant in 6:
		var rng = RandomNumberGenerator.new(); rng.seed = 1931+variant*17
		var mesh = ImmediateMesh.new()
		mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
		var a = Vector3.ZERO
		for segment in 9:
			var b = a+Vector3(rng.randf_range(-38,38),-70,rng.randf_range(-24,24))
			_strip(mesh,a,b,2.8)
			if segment in [2,4,6]:
				var branch = b+Vector3(rng.randf_range(-110,110),-100,40)
				_strip(mesh,b,branch,1.4)
				_strip(mesh,branch,branch+Vector3(50,-110,-20),0.7)
			a = b
		mesh.surface_end()
		var material = StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		# Distant emissive discharge must survive the storm's dense atmospheric fog.
		material.disable_fog = true
		material.albedo_color = Color(0.75,0.83,1.0,0.0)
		material.emission_enabled = true; material.emission = Color(0.58,0.7,1.0)
		material.emission_energy_multiplier = 1.2
		var bolt = MeshInstance3D.new(); bolt.mesh = mesh; bolt.material_override = material
		bolt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		bolt.gi_mode = GeometryInstance3D.GI_MODE_DISABLED; bolt.hide()
		add_child(bolt); bolts.append(bolt); materials.append(material)
	for i in VOICES:
		var player = AudioStreamPlayer3D.new()
		player.unit_size = 1800.0; player.max_distance = 12000.0; player.max_db = -9.0
		player.stream = CLIPS[i]; add_child(player); players.append(player)

func _strip(mesh: ImmediateMesh, a: Vector3, b: Vector3, width: float) -> void:
	# Crossed ribbons remain visible from any camera without camera-dependent geometry.
	for axis in [Vector3.RIGHT,Vector3.BACK]:
		var w: Vector3 = axis*width
		for vertex in [a-w,a+w,b+w,a-w,b+w,b-w]: mesh.surface_add_vertex(vertex)

static func event(seed_value: int, slot: int) -> Dictionary:
	var rng = RandomNumberGenerator.new(); rng.seed = seed_value+slot*7919
	var at = slot*SLOT_SECONDS+rng.randf_range(3.0,11.0)
	var angle = rng.randf()*TAU; var radius = rng.randf_range(2800.0,4400.0)
	return {"id":slot,"at":at,"thunder_at":at+rng.randf_range(2.8,6.0),"angle":angle,"radius":radius,"variant":rng.randi_range(0,5),"clip":rng.randi_range(0,2)}

func clear_transients(clock: float = -1.0) -> void:
	reset_clock = maxf(0.0,clock if clock>=0 else last_clock)
	last_clock = -1.0; last_thunder = -1; active_before = false; illumination = 0.0
	event_slot = -999; events.clear(); reset_serial += 1
	for bolt in bolts: bolt.hide()
	for player in players: player.stop()

func update_storm(state, active: bool, lightning: int, reduced_motion: bool, muted: bool, volume: float) -> void:
	state.lightning_flash = 0.0; illumination = 0.0
	var clock: float = state.active_seconds
	if not active or not state.enabled or state.thunder<0.35:
		if active_before or last_clock>=0: clear_transients(clock)
		return
	if not active_before or event_seed!=state.variation_seed or clock<last_clock:
		clear_transients(clock)
		event_seed = state.variation_seed; active_before = true; last_clock = clock
	var setting = mini(lightning,1) if reduced_motion else lightning
	var slot = floori(clock/SLOT_SECONDS)
	if slot!=event_slot:
		event_slot = slot
		events = [event(event_seed,slot-1),event(event_seed,slot)]
	for bolt in bolts: bolt.hide()
	if muted or volume<=0.0:
		for player in players: player.stop()
	for strike in events:
		if strike.at<=reset_clock: continue
		var age: float = clock-strike.at
		var position_value = Vector3(sin(strike.angle)*strike.radius,layer_height,cos(strike.angle)*strike.radius)
		if age>=0.0 and age<0.45 and setting>0:
			var envelope = sin(PI*clampf(age/0.45,0,1)) if setting==1 else exp(-age*15.0)
			var bolt: MeshInstance3D = bolts[strike.variant]
			bolt.position = position_value; bolt.visible = true
			materials[strike.variant].albedo_color = Color(0.75,0.83,1.0,envelope*(0.28 if setting==1 else 0.85)*state.thunder)
			if setting==2: illumination = maxf(illumination,envelope*0.32*state.thunder)
		if strike.thunder_at>last_clock and strike.thunder_at<=clock and clock-strike.thunder_at<0.25 and strike.id!=last_thunder:
			last_thunder = strike.id
			if not muted and volume>0.0 and DisplayServer.get_name()!="headless":
				var player = players[cursor]; cursor = (cursor+1)%VOICES
				player.stop(); player.position = position_value+Vector3.DOWN*300.0
				player.stream = CLIPS[strike.clip]; player.volume_db = linear_to_db(clampf(volume,0.0,1.0))-9.0
				player.play(); played_count += 1
	state.lightning_flash = illumination
	last_clock = clock

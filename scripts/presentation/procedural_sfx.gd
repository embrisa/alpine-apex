extends Node
## Presentation-only controller: bounded native synthesis, lifecycle and mix.
const Events = preload("res://scripts/presentation/riding_audio_events.gd")
const Contacts = preload("res://scripts/presentation/crash_audio_contacts.gd")
const EquipmentContacts = preload("res://scripts/presentation/equipment_audio_contacts.gd")
const Condition = preload("res://scripts/presentation/snow_condition.gd")
const Wind = preload("res://scripts/presentation/procedural_wind.gd")
const SETTINGS_PATH = "user://riding_audio_v1.cfg"
enum Mode { PROCEDURAL, ORIGINAL }
var mode = Mode.PROCEDURAL
var snow = 1.0
var impacts = 1.0
var equipment = 1.0
var near_miss = 1.0
var adaptive = true
var persist = false
var available = false
var playback_enabled = false
var stream = null
var player: AudioStreamPlayer
var observer = Events.new()
var contacts = Contacts.new()
var equipment_contacts = EquipmentContacts.new()
var equipment_source: WeakRef
var equipment_clock = 0.0
var equipment_until = 0.0
var pending_equipment: Dictionary = {}
var equipment_events_submitted = 0
var equipment_mode = ""
var blend = 0.0
var audible = false
var stopping = false
var state = "silent"
var duck_db = 0.0
var contact_duck = 0.0
var impact_duck_remaining = 0.0
var last_impact_material = -1
var crash_elapsed = 0.0
var last_tick = -1
var submitted_events = 0
var tick_max_us = 0

func _ready() -> void:
	playback_enabled = DisplayServer.get_name()!="headless"
	if "--sfx-disable-native" not in OS.get_cmdline_user_args() and "--wind-disable-native" not in OS.get_cmdline_user_args():
		if not ClassDB.class_exists("AlpineSfxStream") and OS.has_feature("windows") and FileAccess.file_exists(Wind.LIBRARY):
			GDExtensionManager.load_extension(Wind.EXTENSION)
		available = ClassDB.class_exists("AlpineSfxStream")
	player = AudioStreamPlayer.new()
	player.name = "ProceduralSkiing"
	add_child(player)
	if available:
		stream = ClassDB.instantiate("AlpineSfxStream")
		player.stream = stream
		if playback_enabled: player.play()
	blend = 1.0 if available and mode==Mode.PROCEDURAL else 0.0
	_ensure_limiter()

func snapshot() -> Dictionary:
	return {"mode":mode,"snow":snow,"impacts":impacts,"equipment":equipment,"near_miss":near_miss,"adaptive":adaptive}

func bind_equipment_source(visual: Node3D) -> void:
	equipment_source = weakref(visual) if is_instance_valid(visual) else null
	equipment_contacts.reset()
	pending_equipment.clear()
	equipment_mode = ""

func restore(values: Dictionary) -> void:
	mode = int(values.get("mode",0)) if values.get("mode",0) in [0,1] else 0
	for key in ["snow","impacts","equipment","near_miss"]:
		var value = values.get(key,1.0)
		set(key,clampf(float(value),0,1) if typeof(value) in [TYPE_FLOAT,TYPE_INT] and is_finite(float(value)) else 1.0)
	adaptive = values.get("adaptive",true)==true

func load_preferences() -> void:
	if not persist: return
	var cfg = ConfigFile.new()
	if cfg.load(SETTINGS_PATH)!=OK: return
	var values = {}
	for key in snapshot(): values[key]=cfg.get_value("audio",key,snapshot()[key])
	restore(values)

func save_preferences() -> void:
	if not persist: return
	var cfg = ConfigFile.new()
	var values = snapshot()
	for key in values: cfg.set_value("audio",key,values[key])
	cfg.save(SETTINGS_PATH)

func change_setting(key: String, value) -> void:
	var values = snapshot()
	if not values.has(key): return
	values[key]=value
	if key=="mode": silence()
	restore(values)
	save_preferences()

func label() -> String:
	if mode==Mode.PROCEDURAL and not available: return "Original · procedural riding sound unavailable"
	return "Procedural" if mode==Mode.PROCEDURAL else "Original"

func observe_tick(sim, field, dt: float, near_passes: Array = []) -> void:
	var started = Time.get_ticks_usec()
	state = "riding"
	audible = true
	_publish_mix()
	contact_duck = 0.0
	for i in range(2):
		var ski = sim.skis[i]
		var supported: bool = ski.grounded and not sim.crashed and ski.load_n>1.0
		var tangent: Vector3 = ski.velocity.slide(ski.normal)
		var forward_speed: float = tangent.dot(ski.forward)
		var lateral_speed: float = tangent.dot(ski.normal.cross(ski.forward).normalized())
		var condition: int = Condition.at(field,ski.position,ski.snow_depth)
		if stream: stream.set_ski_controls(i,forward_speed,lateral_speed,ski.edge_angle,ski.load_n,ski.snow_depth,ski.penetration,condition,ski.material_kind,supported)
		if supported:
			var work: float = (1.0-exp(-absf(lateral_speed)/7.0))*clampf(ski.load_n/maxf(sim.tuning.rider_mass*9.81*.5,1),0,1)
			contact_duck = maxf(contact_duck,3.0*smoothstep(.2,.8,work)*snow)
	for event in observer.sample(sim,dt,near_passes): _submit(event)
	tick_max_us = maxi(tick_max_us,Time.get_ticks_usec()-started)

func advance(sim, field, ragdoll, camera: Camera3D, wind, weather, dt: float, riding: bool, crash_visible: bool, muted: bool, speaking: bool) -> void:
	var crash_audible: bool = crash_visible and ragdoll.running and not ragdoll.frozen
	var wanted = (riding or crash_audible) and not muted and not stopping
	equipment_clock += maxf(0,dt)
	if not wanted:
		silence()
	elif crash_audible:
		if state!="crash":
			contacts.reset()
			crash_elapsed = 0.0
		state = "crash"
		audible = true
		crash_elapsed += dt
		contact_duck = 0.0
		if stream:
			for i in range(2): stream.set_ski_controls(i,0,0,0,0,0,0,2,0,false)
		for event in contacts.sample(ragdoll,field,camera,dt):
			if crash_elapsed<.14 and impact_duck_remaining>0 and event.material==last_impact_material: continue
			_submit(event)
		if stream:
			var slide = contacts.slide
			stream.set_slide_controls(slide.speed,slide.intensity,slide.pan,slide.material,slide.condition)
		wind.sample_crash(ragdoll,weather,true)
	else:
		state = "riding"
		audible = true
		if stream: stream.set_slide_controls(0,0,0,0,2)
	var target = 1.0 if available and mode==Mode.PROCEDURAL else 0.0
	blend = move_toward(blend,target,maxf(0.0,dt)/.2)
	_publish_mix()
	_observe_equipment(camera,dt,wanted)
	if playback_enabled and is_instance_valid(player): player.stream_paused=blend<=0.0
	impact_duck_remaining = maxf(0.0,impact_duck_remaining-dt)
	var duck_target = 0.0
	if adaptive and wanted:
		duck_target = maxf(contact_duck if mode==Mode.PROCEDURAL and available else 0.0,5.0 if speaking or (impact_duck_remaining>0 and mode==Mode.PROCEDURAL and available) else 0.0)
	duck_db = lerpf(duck_db,duck_target,1.0-exp(-maxf(0.0,dt)/(.03 if duck_target>duck_db else .35)))
	wind.mix_gain = db_to_linear(-duck_db)

func _publish_mix() -> void:
	if stream: stream.set_mix(Vector4(snow,impacts,equipment,near_miss)*sqrt(blend),audible and blend>0.0)

func _submit(event: Dictionary) -> void:
	if mode!=Mode.PROCEDURAL or not available or not audible: return
	var gain: float = impacts if event.kind<=Events.Kind.IMPACT else equipment if event.kind==Events.Kind.EQUIPMENT else near_miss
	if gain<=0: return
	if event.kind==Events.Kind.EQUIPMENT:
		_queue_equipment(event)
		return
	if stream and stream.push_event(event.kind,event.material,event.speed,event.pan,event.detail):
		submitted_events += 1
		if event.kind<=Events.Kind.IMPACT:
			impact_duck_remaining = .18
			last_impact_material = event.material

func _queue_equipment(event: Dictionary) -> void:
	if pending_equipment.is_empty():
		equipment_until = equipment_clock+.025
		pending_equipment = event.duplicate()
		return
	# An actual piece-to-piece touch takes precedence over load-change rattling.
	var specific = int(event.get("profile",0))!=Events.EquipmentProfile.BINDING_RATTLE
	var pending_specific = int(pending_equipment.get("profile",0))!=Events.EquipmentProfile.BINDING_RATTLE
	if (specific and not pending_specific) or (specific==pending_specific and event.speed>pending_equipment.speed):
		pending_equipment = event.duplicate()

func _observe_equipment(camera: Camera3D, dt: float, wanted: bool) -> void:
	var visual = equipment_source.get_ref() if equipment_source!=null else null
	if not wanted or mode!=Mode.PROCEDURAL or not available or equipment<=0:
		equipment_contacts.reset()
		pending_equipment.clear()
		equipment_mode = ""
		return
	if is_instance_valid(visual):
		var presentation_mode: String = state+str(visual.animation_enabled)+str(visual.animation.full_motion.enabled)+str(visual.animation.full_motion.grab_style)
		if presentation_mode!=equipment_mode:
			equipment_contacts.reset()
			pending_equipment.clear()
			equipment_mode = presentation_mode
		var anchor: Vector3 = (visual.skis[0].global_position+visual.skis[1].global_position)*.5
		var listener = camera.global_transform if camera!=null else visual.global_transform
		var serial: int = equipment_contacts.reset_serial
		var events = equipment_contacts.sample(EquipmentContacts.snapshot(visual),anchor,dt,presentation_mode,listener)
		if serial!=equipment_contacts.reset_serial: pending_equipment.clear()
		for event in events: _submit(event)
	if not pending_equipment.is_empty() and equipment_clock>=equipment_until:
		var e = pending_equipment
		var accepted = false
		if stream:
			# The legacy bridge remains valid while a staged DLL awaits installation.
			if stream.has_method("push_equipment_event"):
				accepted = stream.push_equipment_event(int(e.get("profile",0)),e.speed,e.pan,e.detail)
			else: accepted = stream.push_event(e.kind,e.material,e.speed,e.pan,e.detail)
		if accepted:
			submitted_events += 1
			equipment_events_submitted += 1
		pending_equipment.clear()

func silence() -> void:
	if audible:
		if stream: stream.reset()
		observer.reset()
		contacts.reset()
	equipment_contacts.reset()
	pending_equipment.clear()
	equipment_mode = ""
	audible = false
	state = "silent"
	contact_duck = 0.0
	impact_duck_remaining = 0.0

func reset() -> void:
	silence()
	observer.reset()
	contacts.reset()
	if stream: stream.reset()
	duck_db = 0.0
	last_impact_material = -1

func stop_audio() -> void:
	if stopping: return
	stopping=true
	silence()
	if playback_enabled and is_instance_valid(player) and is_inside_tree():
		var retiring = player
		retiring.reparent(get_tree().root)
		var timer = get_tree().create_timer(.15)
		timer.timeout.connect(retiring.stop)
		timer.timeout.connect(retiring.queue_free)
		player=null
	elif is_instance_valid(player): player.stop(); player.stream=null

func _exit_tree() -> void:
	if stream: stream.reset()
	if is_instance_valid(player): player.stop(); player.stream=null

func diagnostics() -> Dictionary:
	var d: Dictionary = stream.diagnostics() if stream else {"blocks":0,"p99_512_ms":0.0}
	d["observer_max_us"] = tick_max_us
	d["contact_max_us"] = contacts.max_update_us
	d["contact_reports"] = contacts.reports_read
	d["capture_max_bone_us"] = contacts.capture_max_bone_us
	d["capture_sum_max_us"] = contacts.capture_sum_max_us
	d["submitted_events"] = submitted_events
	d["equipment_events"] = equipment_events_submitted
	d["equipment_contact_events"] = equipment_contacts.event_count
	d["equipment_observer_max_us"] = equipment_contacts.max_update_us
	d["equipment_sweep_exhausted"] = equipment_contacts.sweep_exhausted
	d["state"] = state
	return d

func _ensure_limiter() -> void:
	for i in range(AudioServer.get_bus_effect_count(0)):
		if AudioServer.get_bus_effect(0,i).resource_name=="Alpine audio safety": return
	var limiter = AudioEffectHardLimiter.new()
	limiter.resource_name="Alpine audio safety"
	limiter.ceiling_db=-1.0
	limiter.pre_gain_db=0.0
	AudioServer.add_bus_effect(0,limiter)

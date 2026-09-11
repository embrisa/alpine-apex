extends SceneTree
const Sfx = preload("res://scripts/presentation/procedural_sfx.gd")
const Events = preload("res://scripts/presentation/riding_audio_events.gd")
const Contacts = preload("res://scripts/presentation/crash_audio_contacts.gd")
const Simulation = preload("res://scripts/core/ski_simulation.gd")
const Voice = preload("res://scripts/presentation/skier_voice.gd")
const Survey = preload("res://scripts/presentation/voice_environment.gd")
const Fixture = preload("res://tests/skier_voice_upgrade_suite.gd").Fixture
const Wind = preload("res://scripts/presentation/procedural_wind.gd")
var checks=0
var failures: Array[String]=[]
class QuietBone:
	extends RefCounted
	var contact_tick=-1
	var contact_count=0
	var linear_velocity=Vector3(0,0,40)
class CrashFixture:
	extends RefCounted
	var running=true
	var frozen=false
	var bodies={"Hips":QuietBone.new()}
	func bone_world(_id: String) -> Transform3D: return Transform3D.IDENTITY
class EquipmentPose:
	extends Node3D
	var poles: Array[Node3D] = []
	var skis: Array[Node3D] = []
	var animation_enabled = true
	var animation = {"full_motion":{"enabled":true,"grab_style":0}}
	func _init() -> void:
		for i in 2:
			var pole = Node3D.new(); add_child(pole); poles.append(pole)
			var ski_node = Node3D.new(); add_child(ski_node); skis.append(ski_node)
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label)
	print("PASS: " if ok else "FAIL: ",label)
func energy(frames: PackedVector2Array) -> float:
	var sum=0.0
	for f in frames: sum+=f.length_squared()*.5
	return sum/maxi(1,frames.size())
func digest(value):
	if value is Object:
		var state={}
		for property in value.get_property_list():
			if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE: state[property.name]=digest(value.get(property.name))
		return state
	if value is Array: return value.map(digest)
	if value is Dictionary:
		var state={}
		for key in value: state[key]=digest(value[key])
		return state
	return value
func run() -> void:
	var control=Sfx.new()
	root.add_child(control)
	check(not control.persist and control.mode==0 and control.adaptive,"Scripted audio uses isolated procedural defaults")
	control.restore({"mode":300,"snow":NAN,"impacts":-1,"equipment":"bad","near_miss":3})
	check(control.mode==0 and control.snow==1 and control.impacts==0 and control.equipment==1 and control.near_miss==1,"Preferences reject invalid values and clamp gains")
	control.restore({"mode":0,"snow":1,"impacts":1,"equipment":1,"near_miss":1})
	var sim=Simulation.new()
	var field=Fixture.new()
	field.slope=.35
	sim.reset(Vector3.ZERO)
	sim.prime_contacts(field)
	sim.velocity=Vector3(0,0,20)
	var observer=Events.new()
	observer.sample(sim,1.0/120)
	sim.skis[0].landing_speed=6
	sim.skis[1].landing_speed=4
	sim.landing_force=6
	var found: Array=[]
	for i in 30:
		found.append_array(observer.sample(sim,1.0/120))
		sim.skis[0].landing_speed=0;sim.skis[1].landing_speed=0
		sim.landing_force=maxf(0,sim.landing_force-.1)
	check(found.filter(func(e):return e.kind==Events.Kind.LANDING).size()==1,"Paired landing and decaying force produce one impact")
	observer.reset()
	var passes=[{"position":Vector3(1,0,0),"gap_m":.2,"reason":"TREE"},{"position":Vector3(-1,0,0),"gap_m":.8,"reason":"ROCK"}]
	found=observer.sample(sim,.1,passes)
	check(found.size()==1 and found[0].kind==Events.Kind.NEAR_MISS and found[0].material==Events.AudioMaterial.WOOD and found[0].pan>0,"Closest near miss supplies material and side")
	check(observer.sample(sim,.1,passes).is_empty(),"Near-miss SFX cooldown suppresses a rapid second pass")
	sim.position+=Vector3(0,0,1000)
	check(observer.sample(sim,.1,passes).is_empty(),"Teleport does not sound like a near miss")
	var contacts=Contacts.new()
	var reports: Array[Dictionary]=[{"body":1,"collider":100,"speed":5.0,"slide_speed":10.0,"weight":1.0,"pan":.2,"material":0,"condition":0},{"body":2,"collider":100,"speed":8.0,"slide_speed":4.0,"weight":.3,"pan":.2,"material":0,"condition":0}]
	found=[]
	for i in 30: found.append_array(contacts.observe_reports(reports,1.0/120))
	check(found.size()==1 and found[0].speed==8,"Simultaneous limbs group into the strongest collider impact")
	check(contacts.slide.intensity>0 and contacts.slide.speed==10,"Sustained contact drives body sliding")
	for i in 15: contacts.observe_reports([],1.0/120)
	check(contacts.slide.intensity==0,"Leaving contact immediately clears sliding target")
	found=[]
	for i in 12: found.append_array(contacts.observe_reports(reports,1.0/120))
	check(found.size()==1,"Separated contact rearms a genuine tumble impact")
	var third=reports[0].duplicate();third.body=3;third.speed=9
	reports.append(third)
	found=[]
	for i in 12: found.append_array(contacts.observe_reports(reports,1.0/120))
	check(found.size()==1,"A new limb can impact while another remains on the ground")
	contacts.reset()
	check(contacts.observe_reports([],.1).is_empty(),"Reset discards pending crash clusters")
	var observed=Simulation.new();var silent=Simulation.new()
	observed.reset(Vector3.ZERO);silent.reset(Vector3.ZERO)
	var Replay=preload("res://scripts/racing/run_replay.gd")
	var with_audio=Replay.new();var without_audio=Replay.new()
	with_audio.begin(observed,{"course":"audio_fixture"});without_audio.begin(silent,{"course":"audio_fixture"})
	var input=preload("res://scripts/core/rider_input.gd").new()
	var same=true
	var pose_unchanged=true
	var equipment_pose=EquipmentPose.new();root.add_child(equipment_pose)
	control.bind_equipment_source(equipment_pose)
	for i in 240:
		input.steer=.3 if i>90 else 0.0
		observed.step(1.0/120,input,field);silent.step(1.0/120,input,field)
		control.observe_tick(observed,field,1.0/120)
		# Final presentation transforms move independently of the solver and replay.
		equipment_pose.position=observed.position
		for side in 2: equipment_pose.skis[side].position=Vector3(-.35+side*.7,0,0)
		equipment_pose.poles[0].transform=Transform3D(Basis(Quaternion(Vector3.DOWN,Vector3.RIGHT)),Vector3(-.59,1,0))
		equipment_pose.poles[1].transform=Transform3D(Basis(Quaternion(Vector3.DOWN,Vector3.BACK)),Vector3(0,1.3-.6*sin(PI*i/239.0),-.59))
		var before_pose=Sfx.EquipmentContacts.snapshot(equipment_pose)
		control.equipment_clock+=1.0/120
		control._observe_equipment(null,1.0/120,true)
		pose_unchanged=pose_unchanged and before_pose==Sfx.EquipmentContacts.snapshot(equipment_pose)
		same=same and digest(observed)==digest(silent)
		with_audio.record(1.0/120,(i+1)/120.0,observed,input)
		without_audio.record(1.0/120,(i+1)/120.0,silent,input)
	check(same,"Every completed solver field remains identical with audio observation")
	check(digest(with_audio)==digest(without_audio),"Recorded replay samples, inputs and compatibility remain identical")
	check(pose_unchanged,"Equipment observation leaves every final pole, ski and binding proxy unchanged")
	check(control.equipment_contacts.event_count>0 if control.available else control.equipment_contacts.event_count==0,"Replay comparison exercises equipment contacts when native audio is enabled")
	control.bind_equipment_source(null);equipment_pose.queue_free()
	var voice=Voice.new();root.add_child(voice);voice.enabled=false
	var survey=Survey.new();voice.environment=survey
	var near_field=Fixture.new();near_field.add(Vector3(1.2,0,0))
	var near_sim=Simulation.new();near_sim.reset(Vector3(0,0,-3));near_sim.velocity=Vector3(0,0,30)
	survey.sample(near_sim,near_field,.1)
	near_sim.position=Vector3(0,0,3)
	var candidates=survey.sample(near_sim,near_field,.1)
	var updates=survey.update_count
	voice.observe_tick(near_sim,.1,near_field,-1,candidates)
	check(survey.update_count==updates and survey.near_passes.size()==1,"Voice disabled still shares one survey with near-miss metadata")
	check(Events.new().sample(near_sim,.1,survey.near_passes).size()==1,"Swish works independently of disabled speech")
	near_sim._obstacle_contact={"closing_speed_mps":4.0,"reason":"TREE","normal":Vector3.BACK}
	survey.reset();survey.sample(near_sim,near_field,.1)
	near_sim.position=Vector3(0,0,-3);survey.sample(near_sim,near_field,.1)
	near_sim.position=Vector3(0,0,3);survey.sample(near_sim,near_field,.1)
	check(survey.near_passes.is_empty(),"Actual obstacle contact suppresses a near-miss swish")
	voice.queue_free()
	var original=AudioStreamPlayer.new();root.add_child(original)
	var wind=Wind.new();root.add_child(wind);wind.setup(original)
	control.contact_duck=3;control.duck_db=0
	control.advance(sim,field,null,null,wind,null,.5,true,false,false,true)
	check(control.duck_db<=5.0 and control.duck_db>4.9,"Adaptive requests combine by maximum, bounded to five dB")
	control.contact_duck=0
	control.advance(sim,field,null,null,wind,null,1.0,true,false,false,false)
	check(control.duck_db<.4,"Wind recovers smoothly after speech/contact cues")
	control.adaptive=false
	control.advance(sim,field,null,null,wind,null,1.0,true,false,false,true)
	check(control.duck_db<.03,"Disabling adaptive mix restores fixed wind balance")
	control.advance(sim,field,null,null,wind,null,.1,true,false,true,false)
	check(not control.audible and control.state=="silent","Global mute gates SFX even while riding")
	var crash=CrashFixture.new()
	control.advance(sim,field,crash,null,wind,null,.1,false,true,false,false)
	check(control.audible and control.state=="crash" and is_equal_approx(wind.airflow.length(),40),"Visible crash retains audio and wind follows actual ragdoll velocity")
	crash.frozen=true
	control.advance(sim,field,crash,null,wind,null,.1,false,true,false,false)
	check(not control.audible,"Frozen ragdoll silences crash audio")
	crash.frozen=false
	control.advance(sim,field,crash,null,wind,null,.1,false,false,false,false)
	check(not control.audible,"Hidden crash view does not leave audible sliding or impacts")
	wind.stop_audio();wind.queue_free();original.queue_free()
	control.silence()
	check(not control.audible and control.observer.pending_landing.is_empty(),"Silence cancels lifecycle events")
	var fallback="--sfx-disable-native" in OS.get_cmdline_user_args()
	check(control.available!=fallback,"Native availability matches explicit fallback switch")
	if control.available:
		var stream=control.stream
		var playback: AudioStreamPlayback=stream.instantiate_playback()
		var second: AudioStreamPlayback=stream.instantiate_playback()
		playback.start();second.start()
		check(playback.is_playing() and not second.is_playing(),"One resource has exactly one active playback consumer")
		stream.set_mix(Vector4.ONE,true)
		stream.set_ski_controls(0,25,7,.5,450,.1,.05,0,0,true)
		var pcm=playback.mix_audio(1.0,48000)
		var peak=0.0;var finite=true
		for f in pcm:
			finite=finite and f.is_finite();peak=maxf(peak,maxf(absf(f.x),absf(f.y)))
		check(pcm.size()==48000 and energy(pcm)>.000001 and finite and peak<=.501188,"Native integration produces bounded audible stereo")
		for i in 64: stream.push_event(1,1,20,0,0)
		check(not stream.push_event(1,1,20,0,0) and stream.diagnostics().queue_dropped>0,"Native API reports event queue overflow")
		stream.reset();playback.mix_audio(1.0,48000)
		stream.set_mix(Vector4.ONE,true)
		playback.mix_audio(1.0,48000)
		check(energy(playback.mix_audio(1.0,512))<1e-10 and stream.diagnostics().events_started==0,"Reset invalidates queued events across re-enable")
		check(stream.has_method("push_equipment_event"),"Native bridge exposes explicit equipment profiles")
		var accepted_profiles = true
		for profile in 4: accepted_profiles = stream.push_equipment_event(profile,8,.2,.6) and accepted_profiles
		check(accepted_profiles and energy(playback.mix_audio(1.0,24000))>1e-7,"All four equipment profiles pass through the native queue to PCM")
		check(not stream.push_equipment_event(-1,8,0,1) and not stream.push_equipment_event(4,8,0,1),"Native bridge rejects unknown equipment profile IDs")
		stream.push_equipment_event(2,8,0,1)
		var events_before_reset: int = stream.diagnostics().events_started
		stream.reset();stream.set_mix(Vector4.ONE,true);playback.mix_audio(1.0,48000)
		check(stream.diagnostics().events_started==events_before_reset and energy(playback.mix_audio(1.0,512))<1e-10,"Reset discards queued modal strikes without stale ringing")
		playback.stop();second.start()
		check(second.is_playing(),"Stopped playback releases the resource claim")
		second.stop()
	else: check(control.label().contains("unavailable"),"Fallback label explains missing native support")
	var limiter_count=0
	for i in range(AudioServer.get_bus_effect_count(0)):
		var fx=AudioServer.get_bus_effect(0,i)
		if fx.resource_name=="Alpine audio safety": limiter_count+=1;check(fx.ceiling_db==-1,"Master ceiling reserves one dB of headroom")
	check(limiter_count==1,"Master safety limiter is installed once")
	control.stop_audio();control.queue_free()
	await process_frame
	DirAccess.make_dir_recursive_absolute("res://artifacts/sfx")
	var report={"checks":checks,"failures":failures,"fallback":fallback}
	FileAccess.open("res://artifacts/sfx/"+("fallback" if fallback else "native")+"_suite.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("SFX_AUDIO_RESULT ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)

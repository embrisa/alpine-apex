extends SceneTree
const Voice = preload("res://scripts/presentation/skier_voice.gd")
const Simulation = preload("res://scripts/core/ski_simulation.gd")
const Session = preload("res://scripts/core/run_session.gd")
var failures: Array[String] = []
var checks: int = 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	print("PASS: " if ok else "FAIL: ",label)
	if not ok: failures.append(label)
func run() -> void:
	var sim = Simulation.new()
	var events = Voice.Events.new()
	var found: Array[String] = []
	sim.velocity = Vector3(0,0,25)
	for hop in 20:
		sim.grounded = false
		for tick in 12:
			var cue = events.sample(sim,1.0/120.0)
			if not cue.is_empty(): found.append(cue)
		sim.grounded = true
		events.sample(sim,1.0/120.0)
	check(found.is_empty(),"Repeated 100 ms terrain hops never announce big air or landings")
	events.reset()
	sim.grounded = false
	for tick in 240:
		var cue = events.sample(sim,1.0/120.0)
		if not cue.is_empty(): found.append(cue)
	check(found.is_empty(),"Two seconds of ordinary downhill airtime stays quiet")
	for tick in 180:
		var cue = events.sample(sim,1.0/120.0)
		if not cue.is_empty(): found.append(cue)
	check(found == ["big_air"],"One sustained flight announces big air exactly once")
	events.mark_spoken()
	sim.grounded = true
	for tick in 60:
		var cue = events.sample(sim,1.0/120.0)
		if not cue.is_empty(): found.append(cue)
	check(found == ["big_air"],"Clean landing adds no second reaction or finish celebration")
	events.reset()
	sim.grounded = false
	for tick in 220: events.sample(sim,1.0/120.0)
	sim.grounded = true
	sim.impacts.reserve = 0.95
	check(events.sample(sim,1.0/120.0).is_empty(),"Small landing reserve loss is counted once, not doubled")
	sim.impacts.reserve = 0.65
	var rough = events.sample(sim,1.0/120.0)
	for tick in 30:
		var cue = events.sample(sim,1.0/120.0)
		if not cue.is_empty(): rough = cue
	check(rough=="landing_bad","Follow-through damage classifies the landing once after its window")
	sim.crashed = true
	check(events.sample(sim,1.0/120.0).is_empty() and not events.breathing,"Crash cancels pending landing and breathing")
	sim.crashed = false
	sim.impacts.reserve = 0.22
	events.sample(sim,0.01)
	check(events.breathing,"Critical reserve starts breathing")
	sim.impacts.reserve = 0.30
	events.sample(sim,0.01)
	check(events.breathing,"Recovery hysteresis avoids threshold chatter")
	sim.impacts.reserve = 0.43
	events.sample(sim,0.01)
	check(not events.breathing,"Recovered reserve releases breathing")
	var session = Session.new()
	session.finished = true
	session.new_best = true
	check(Voice.Events.finish_event(session)=="personal_best","Eligible saved per-course PB produces a PB cue")
	session.eligible = false
	check(Voice.Events.finish_event(session).is_empty(),"Unranked laboratory result cannot celebrate a record")
	session.eligible = true
	session.save_error = "fixture: save failed"
	check(Voice.Events.finish_event(session).is_empty(),"Failed save cannot announce a saved record")
	session.save_error = ""
	session.new_best = false
	check(Voice.Events.finish_event(session)=="finish","Slower saved finishes use only the ordinary finish celebration")
	session.finished = false
	check(Voice.Events.finish_event(session).is_empty(),"Riding never selects a finish celebration")
	var voice = Voice.new()
	root.add_child(voice)
	voice.set_process(false)
	voice.playback_enabled = false
	check(not voice.persist,"Automated voice tests do not write player preferences")
	check(voice.request("big_air"),"Initial big-air reaction is accepted")
	check(not voice.request("big_air"),"Duplicate event is suppressed")
	check(not voice.request("landing_bad") and not voice.request("impact"),"A jump cannot chain into landing and impact voice lines")
	voice.reset()
	check(not voice.request("big_air"),"Restart cannot bypass the shared riding cooldown")
	voice._process(59.0)
	check(not voice.request("impact"),"Different riding categories share a full minute of quiet")
	voice._process(1.1)
	check(voice.request("impact"),"A major riding event can speak after the quiet interval")
	check(voice.request("crash"),"Crash still responds immediately during the riding cooldown")
	check(not voice.request("big_air"),"Riding speech cannot interrupt a crash")
	voice.set_muted(true)
	check(not voice.request("personal_best") and voice.current_event.is_empty(),"Global mute stops and rejects even record cues")
	voice.set_muted(false)
	check(voice.current_event.is_empty(),"Unmute never replays a stale cue")
	voice.reset()
	voice.request("personal_best")
	voice.set_gameplay_active(false)
	check(voice.current_event.is_empty(),"Pause/focus/menu gate stops voice immediately")
	var chosen: Array[String] = []
	voice.cue_started.connect(func(id,_event): chosen.append(id))
	for i in 12: voice.preview("personal_best")
	var distinct = true
	for i in range(1,chosen.size()): distinct = distinct and chosen[i] != chosen[i-1]
	check(distinct and chosen.size()==12,"Variant selection avoids consecutive repeats")
	voice.preview("breathing")
	voice._process(10.0)
	check(not voice.breath_wanted and not voice.breath_preview,"Breathing audition ends after one take")
	voice.breath_wanted = true
	voice._process(0.5)
	check(voice.breath_gain>0.0,"Breathing fades into the mix")
	voice.breath_wanted = false
	voice._process(0.5)
	check(voice.breath_gain==0.0,"Recovered breathing fades completely to silence")
	voice.restore({"volume":NAN,"enabled":true})
	check(voice.volume==0.75,"Corrupt volume restores a finite default")
	voice.restore({"volume":0.4,"enabled":false,"breathing_enabled":false})
	check(voice.snapshot()=={"volume":0.4,"enabled":false,"breathing_enabled":false},"Voice preferences round-trip independently")
	voice.restore({})
	var before = [sim.position,sim.velocity,sim.ticks,sim.impacts.reserve,sim.tuning.jump_impulse]
	voice.observe_tick(sim,1.0/120.0)
	check(before==[sim.position,sim.velocity,sim.ticks,sim.impacts.reserve,sim.tuning.jump_impulse],"Voice observation does not mutate skiing state or tuning")
	var ids = {}
	var finish_captions: Array[String] = []
	for clip in Voice.Library.CLIPS:
		check(not ids.has(clip.id) and clip.stream.get_length()>0.2 and not clip.stream.loop,"Imported nonlooping clip: "+clip.id)
		ids[clip.id] = true
		if clip.event=="finish": finish_captions.append(clip.caption)
	check(Voice.Library.VOICE_NAME=="Alpine Apex Male 1" and finish_captions.size()>=4,"The new character has a varied ordinary finish pool")
	check(not Voice.PRIORITY.has("land_clean") and not Voice.PRIORITY.has("air_small"),"Ordinary clean landings and hops remain preview only")
	var busy_voice = Voice.new()
	root.add_child(busy_voice)
	busy_voice.set_process(false)
	busy_voice.playback_enabled = false
	var busy_cues: Array = []
	busy_voice.cue_started.connect(func(_id,event): busy_cues.append({"event":event,"time":busy_voice.clock_seconds}))
	sim.impacts.reserve = 1.0
	# Three minutes of repeated 3.5 s flights with large landing impacts: more
	# severe and frequent than the user's normal downhill airtime complaint.
	for tick in 21600:
		var phase = tick%540
		sim.grounded = phase>=420
		sim.impacts.reserve = 0.6 if phase>=420 and phase<425 else 1.0
		busy_voice._process(1.0/120.0)
		busy_voice.observe_tick(sim,1.0/120.0)
	check(busy_cues.size()>0 and busy_cues.size()<=3,"Three minutes of repeated jumps and heavy landings produces at most three riding lines")
	var separated = true
	for i in range(1,busy_cues.size()): separated = separated and busy_cues[i].time-busy_cues[i-1].time>=60.0
	check(separated,"Busy-slope reactions remain at least 60 seconds apart")
	check(busy_cues.all(func(c): return c.event in Voice.RIDING_EVENTS),"Busy downhill skiing never plays a finish or PB line")
	busy_voice.queue_free()
	voice.queue_free()
	await process_frame
	DirAccess.make_dir_recursive_absolute("res://artifacts/voice")
	var result = {"checks":checks,"failures":failures}
	FileAccess.open("res://artifacts/voice/suite.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("SKIER_VOICE_RESULT ",JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)

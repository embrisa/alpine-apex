extends SceneTree
const Voice = preload("res://scripts/presentation/skier_voice.gd")
const Survey = preload("res://scripts/presentation/voice_environment.gd")
const Simulation = preload("res://scripts/core/ski_simulation.gd")
const Session = preload("res://scripts/core/run_session.gd")
var failures: Array[String] = []
var checks = 0

class Fixture:
	extends RefCounted
	var obstacles: Array = []
	var obstacle_grid: Dictionary = {}
	var slope: float = 0.0
	var drop: bool = false
	func ski_bounds() -> Rect2: return Rect2(-100,-100,200,200)
	func sample(_x: float,z: float) -> Dictionary:
		return {"height":-z*slope-(9.0 if drop and z>=8 else 0.0),"normal":Vector3(0,1,slope).normalized()}
	func sweep_obstacle(_a: Vector3,_b: Vector3) -> String: return ""
	func nearby_obstacle_indices(position: Vector3, radius: float) -> Array:
		var result = []
		for z in range(floori((position.z-radius)/48),floori((position.z+radius)/48)+1):
			for x in range(floori((position.x-radius)/48),floori((position.x+radius)/48)+1):
				for id in obstacle_grid.get(Vector2i(x,z),[]):
					if not result.has(id): result.append(id)
		return result
	func add(p: Vector3,r: float = 0.5,h: float = 10.0) -> void:
		var id = obstacles.size()
		obstacles.append({"position":p,"radius":r,"height":h,"tree":true})
		for z in range(floori((p.z-r)/48),floori((p.z+r)/48)+1):
			for x in range(floori((p.x-r)/48),floori((p.x+r)/48)+1):
				var cell = Vector2i(x,z)
				if not obstacle_grid.has(cell): obstacle_grid[cell] = []
				obstacle_grid[cell].append(id)

func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
	print("PASS: " if ok else "FAIL: ",label)

func feed(events,sim,seconds: float) -> Array[String]:
	var found: Array[String] = []
	for tick in roundi(seconds*120):
		found.append_array(events.sample_candidates(sim,1.0/120.0))
	return found

func survey_feed(observer,sim,field,seconds: float) -> Array[String]:
	var found: Array[String] = []
	for tick in roundi(seconds*120):
		found.append_array(observer.sample(sim,field,1.0/120.0))
	return found

func state_value(value):
	if value is Object:
		var result = {}
		for property in value.get_property_list():
			if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
				result[property.name] = state_value(value.get(property.name))
		return result
	if value is Array:
		return value.map(state_value)
	if value is Dictionary:
		var result = {}
		for key in value: result[key] = state_value(value[key])
		return result
	return value

func verify_model_independence(voice) -> void:
	var observed = Simulation.new()
	var silent = Simulation.new()
	var plane = Fixture.new()
	plane.slope = 0.46
	observed.reset(Vector3.ZERO,0.0)
	silent.reset(Vector3.ZERO,0.0)
	voice.reset()
	voice.enabled = true
	voice.allow_gameplay = true
	var identical = true
	for tick in 1200:
		var intent = preload("res://scripts/core/rider_input.gd").new()
		intent.steer = 0.2*sin(float(tick)*0.012)
		observed.step(1.0/120.0,intent,plane)
		silent.step(1.0/120.0,intent,plane)
		voice.enabled = tick<600 # Exercise enabled and disabled playback over the same path.
		voice._process(1.0/120.0)
		voice.observe_tick(observed,1.0/120.0,plane)
		if state_value(observed)!=state_value(silent):
			identical = false
			break
	check(identical,"Voice enabled/disabled preserves every script-owned model-%d state field over 1200 completed ticks" % Simulation.MODEL_VERSION)
	voice.enabled = true

func run() -> void:
	var sim = Simulation.new()
	sim.velocity = Vector3(0,0,25)
	sim.grounded = false
	var events = Voice.Events.new()
	feed(events,sim,3.1)
	sim.grounded = true
	check(feed(events,sim,0.3)==["land_big"],"Unvoiced major flight may celebrate one clean landing")
	events.reset()
	sim.grounded = false
	sim.landing_assist.valid = true
	sim.landing_assist.time_to_contact = 5.0
	check(feed(events,sim,3.1)==["air_huge"],"Existing valid prediction selects huge air")
	events.mark_spoken()
	sim.grounded = true
	sim.impacts.reserve = 0.6
	check(feed(events,sim,0.4).is_empty(),"A voiced flight suppresses its rough landing too")
	events.reset(1.0)
	sim.impacts.reserve = 0.8
	check(events.sample(sim,1.0/120.0)=="impact_small","Moderate compression uses the nonverbal pool")
	sim.impacts.reserve = 0.4
	check(events.sample(sim,1.0/120.0)=="impact","Large reserve loss uses hard impact")
	events.reset(0.22)
	sim.impacts.reserve = 0.22
	check(feed(events,sim,6.1)==["injured"],"Six continuous seconds at low reserve yield one candidate")
	check(feed(events,sim,10.0).is_empty(),"Low-reserve episode cannot repeat")
	sim.impacts.reserve = 0.43
	feed(events,sim,0.1)
	sim.impacts.reserve = 0.22
	check("injured" in feed(events,sim,6.1),"Recovery rearms the low-reserve episode")
	events.reset(1.0)
	sim.impacts.reserve = 1.0
	sim.velocity = Vector3(0,0,65)
	check(feed(events,sim,8.2)==["speed_extreme"],"Extreme speed takes precedence without a second high-speed cue")
	check(feed(events,sim,12.0).is_empty(),"Sustained speed has no repeated candidates")
	sim.velocity = Vector3(0,0,30)
	feed(events,sim,10.1)
	sim.velocity = Vector3(0,0,51)
	check(feed(events,sim,8.1)==["speed_high"],"Ten slow seconds rearm speed reactions")
	var session = Session.new()
	session.finished = true
	session.previous_best = 100.0
	session.elapsed = 102.0
	check(Voice.Events.finish_event(session)=="finish_good","A finish within three percent is good")
	session.elapsed = 110.0
	check(Voice.Events.finish_event(session)=="finish_bad","Ten percent slower selects a bad finish")
	session.elapsed = 105.0
	check(Voice.Events.finish_event(session)=="finish","Intermediate result remains ordinary")
	session.new_best = true
	check(Voice.Events.finish_event(session)=="personal_best","Saved PB wins finish classification")
	session.save_error = "fixture"
	check(Voice.Events.finish_event(session).is_empty(),"Failed save cannot announce a result")
	var voice = Voice.new()
	root.add_child(voice)
	voice.set_process(false)
	voice.playback_enabled = false
	voice.rng.seed = 91
	check(voice.request("impact_hard"),"New category maps to the compatible impact event")
	check(voice.current_event=="impact","Existing event IDs remain compatible")
	voice.silence()
	voice._process(61.0)
	check(voice.offer(["misc","speed_high","nearmiss","impact"]),"Competing candidates can select a reaction")
	check(voice.current_event=="impact","Hard impact wins simultaneous hazards")
	voice.begin_crash()
	voice._process(3.0)
	voice.observe_crash(1.6,0.0,true)
	check(voice.current_event=="crash_after" and not voice.crash_pending,"Settled crash speaks once after onset")
	voice.reset()
	voice.begin_crash()
	voice.observe_crash(2.0,0.0,false)
	check(not voice.crash_pending and voice.current_event.is_empty(),"Leaving crash view cancels the follow-up")
	voice.begin_crash()
	voice.observe_crash(10.1,20.0,true)
	check(not voice.crash_pending,"Long tumble expires its post-crash opportunity")
	voice.race_progress = -1.0
	for i in 50:
		check(voice._choose("injured").get("caption","")!="Almost there.","Free skiing never says Almost there")
	var original = voice.clip_bank
	var stream = Voice.Library.CLIPS[0].stream
	voice.clip_bank = [{"id":"only","event":"impact","stream":stream,"weight":1.0}]
	voice.rebuild_pools()
	check(voice._choose("impact").id=="only" and voice._choose("impact").id=="only","Single accepted variant remains selectable")
	check(voice._choose("missing").is_empty(),"Empty pool safely yields silence")
	voice.clip_bank = [
		{"id":"rare","event":"impact","stream":stream,"weight":0.2},
		{"id":"usual","event":"impact","stream":stream,"weight":1.0},
		{"id":"almost","event":"injured","stream":stream,"weight":1.0,"min_race_progress":0.85}]
	voice.rebuild_pools()
	var rare_count = 0
	for i in 1000:
		voice.last_variant.clear()
		if voice._choose("impact").id=="rare": rare_count += 1
	check(rare_count>100 and rare_count<230,"Reduced selection weight produces fewer rare phrases")
	voice.race_progress = 0.849
	check(voice._choose("injured").is_empty(),"Almost there is ineligible before 85 percent race progress")
	voice.race_progress = 0.85
	check(voice._choose("injured").id=="almost","Almost there becomes eligible at 85 percent race progress")
	voice.clip_bank = original
	voice.rebuild_pools()
	var field = Fixture.new()
	var observer = Survey.new()
	sim.velocity = Vector3(0,0,40)
	sim.surface_normal = Vector3.UP
	sim.position = Vector3(0,0,-4)
	field.add(Vector3(1.6,0,0))
	observer.sample(sim,field,0.1)
	sim.position.z = 4
	check("nearmiss" in observer.sample(sim,field,0.1),"Swept close pass triggers after passing the obstacle")
	sim.position.z = -4
	observer.sample(sim,field,0.1)
	sim.position.z = 4
	check(not "nearmiss" in observer.sample(sim,field,0.1),"Nearby obstacle is deduplicated")
	observer.reset()
	sim.position = Vector3(0,20,-4)
	observer.sample(sim,field,0.1)
	sim.position.z = 4
	check(not "nearmiss" in observer.sample(sim,field,0.1),"Flying above a tree is not a near miss")
	observer.reset()
	field = Fixture.new()
	field.add(Vector3(0.3,0,0))
	sim.position = Vector3(0,0,-4)
	observer.sample(sim,field,0.1)
	sim.position.z = 4
	check(not "nearmiss" in observer.sample(sim,field,0.1),"Intersecting a collision envelope is not a clean miss")
	observer.reset()
	field = Fixture.new()
	field.drop = true
	sim.position = Vector3.ZERO
	check("terrain_cliff" in survey_feed(observer,sim,field,0.4),"Additional drop below the tangent produces a cliff cue")
	observer.reset()
	field.drop = false
	field.slope = 1.2
	sim.surface_normal = Vector3(0,1,1.2).normalized()
	var terrain_cues = survey_feed(observer,sim,field,1.2)
	check("terrain_steep" in terrain_cues and not "terrain_cliff" in terrain_cues,"Continuous steep slope is not mistaken for a cliff")
	check(survey_feed(observer,sim,field,5.0).is_empty(),"Persistent terrain does not repeat")
	observer.reset()
	field = Fixture.new()
	field.add(Vector3(-2,0,10))
	field.add(Vector3(2,0,10))
	sim.surface_normal = Vector3.UP
	check("terrain_tight" in survey_feed(observer,sim,field,0.4),"Obstacles on both sides establish a tight corridor")
	field.obstacles.clear()
	field.obstacle_grid.clear()
	check("terrain_open" in survey_feed(observer,sim,field,3.1),"Leaving a tight corridor for three clear seconds produces open terrain")
	observer.reset()
	sim.position.z = 90
	field.drop = true
	check(survey_feed(observer,sim,field,2.0).is_empty(),"Out-of-bounds samples suppress uncertain terrain cues")
	observer.reset()
	sim.position = Vector3.ZERO
	field = Fixture.new()
	for i in 200: field.add(Vector3(2,0,8+float(i)*.01))
	check(survey_feed(observer,sim,field,0.4).is_empty() and observer.limited,"Dense query overflow suppresses uncertain classifications")
	check(observer.obstacle_checks<=128 and observer.height_samples<=24,"Survey obeys hard obstacle and sample limits")
	observer.reset()
	sim.position.z = -4
	observer.sample(sim,field,.1)
	sim.position.z = 90
	check(observer.sample(sim,field,.1).is_empty(),"Teleport does not create a swept near miss")
	var before = [sim.position,sim.velocity,sim.ticks,sim.impacts.reserve,field.obstacles.size()]
	survey_feed(observer,sim,field,.2)
	check(before==[sim.position,sim.velocity,sim.ticks,sim.impacts.reserve,field.obstacles.size()],"Survey never mutates simulation or mountain data")
	verify_model_independence(voice)
	voice.queue_free()
	await process_frame
	DirAccess.make_dir_recursive_absolute("res://artifacts/voice/male_1_v1")
	preload("res://tests/test_report.gd").write("res://artifacts/voice/male_1_v1/upgrade_suite.json",JSON.stringify({"checks":checks,"failures":failures},"\t"))
	print("VOICE_UPGRADE_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)

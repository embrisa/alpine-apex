extends SceneTree
const Weather = preload("res://scripts/presentation/weather_controller.gd")
const Prefs = preload("res://scripts/presentation/weather_preferences.gd")
const Rules = preload("res://scripts/presentation/weather_rules.gd")
const Race = preload("res://scripts/racing/race_definition.gd")
const Storm = preload("res://scripts/presentation/storm_effects.gd")
var checks = 0
var failures = []
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)
	print("PASS: " if value else "FAIL: ",label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var prefs = Prefs.new()
	check(prefs.values.automatic and prefs.values.time_cycle and prefs.values.random_weather and prefs.values.random_time and prefs.values.rare_storms and prefs.values.quality==2 and prefs.values.lightning==2,"Fresh profile enables cycles, launch choices, rare storms and High/Full")
	var path = "res://artifacts/weather_upgrade/preferences.cfg"
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	for key in prefs.DEFAULTS:
		prefs.set_value(key,not prefs.values[key] if prefs.values[key] is bool else 1 if prefs.values[key] is int else "snowstorm" if key=="manual_weather" else "dusk")
	prefs.free_seconds = 615; prefs.cooldown = 585; prefs.last_weather = "snowfall"; prefs.last_band = "night"
	check(prefs.save_preferences(path)==OK,"Preference store saves atomically to isolated path")
	var restored = Prefs.new(); restored.load_preferences(path)
	check(restored.snapshot()==prefs.snapshot(),"Every choice, launch history and cumulative cooldown round trips")
	FileAccess.open(path,FileAccess.WRITE).store_string("broken")
	restored.load_preferences(path)
	check(restored.values==Prefs.DEFAULTS and restored.cooldown==1200,"Corrupt store restores defaults and initial delay")
	restored.restore({"choices":{"quality":99,"manual_weather":false,"automatic":"yes"},"free_seconds":NAN,"cooldown":-1})
	check(restored.values==Prefs.DEFAULTS and restored.free_seconds==0 and restored.cooldown==1200,"Malformed types/counters rejected")
	var rng = RandomNumberGenerator.new(); rng.seed = 1234
	var counts = [0,0,0,0]
	for i in 20000: counts[Rules.ORDINARY.find(Prefs.weighted_weather(rng))] += 1
	check(abs(counts[0]-6000)<240 and abs(counts[1]-6000)<240 and abs(counts[2]-6000)<240 and abs(counts[3]-2000)<150,"Ordinary base draw has 30/30/30/10 weights before anti-repeat conditioning")
	for rw in [false,true]:
		for rt in [false,true]:
			prefs = Prefs.new(); prefs.values.random_weather = rw; prefs.values.random_time = rt
			prefs.values.manual_weather = "rain"; prefs.values.manual_time = "night"
			var valid = true; var hours = {}
			for i in 1500:
				var old_pair = [prefs.last_weather,prefs.last_band]
				var result = prefs.launch(rng,PackedStringArray(),true)
				valid = valid and (result.preset in Rules.ORDINARY) and result.hour>=0 and result.hour<24
				if rw or rt: valid = valid and [result.preset,Rules.time_band(result.hour)]!=old_pair
				if not rw: valid = valid and result.preset=="rain"
				if not rt: valid = valid and result.hour==0.0
				hours[floori(result.hour)] = true
			check(valid and (hours.size()==24 if rt else hours.size()==1),"Launch anti-repeat respects enabled components rw=%s rt=%s" % [rw,rt])
	prefs = Prefs.new(); var untouched = prefs.snapshot()
	var scripted = prefs.launch(rng,PackedStringArray(),false)
	check(scripted.preset=="clear" and scripted.hour==12 and not scripted.automatic and not scripted.time_cycle and prefs.snapshot()==untouched,"Scripted launch is fixed and does not read/change personal history")
	var override = prefs.launch(rng,PackedStringArray(["--weather=thunderstorm","--time-of-day=dusk","--weather-quality=low"]),true)
	check(override.preset=="thunderstorm" and override.hour==17.5 and not override.automatic and not override.time_cycle and override.quality==1 and prefs.values==Prefs.DEFAULTS,"Explicit fixed overrides hold cycles without changing manual preferences")
	override = prefs.launch(rng,PackedStringArray(["--weather=rain","--weather-auto","--time-of-day=night","--time-cycle"]),false)
	check(override.automatic and override.time_cycle,"Explicit automatic overrides win independently of argument order")
	prefs.storm_at_exit = true; prefs.cooldown = 42
	prefs.launch(rng,PackedStringArray(),true)
	check(prefs.cooldown==1200,"Replacing an exited storm starts a full active cooldown")
	var w = Weather.new(); root.add_child(w)
	seed(937)
	var expected_random = randi()
	seed(937)
	w.seed_stream(417); w.set_automatic(true); w.update_weather(2400,true)
	check(randi()==expected_random,"Weather fronts use no gameplay/global RNG draws")
	w = _replace_weather(w)
	w.set_time_cycle(true); w.update_weather(3600,true)
	check(is_equal_approx(w.daylight.hour,12.0) and w.free_seconds==3600,"Day wraps after exactly 3600 active seconds")
	var held = w.snapshot(); w.update_weather(100,false)
	check(w.snapshot()==held,"Inactive lifecycle freezes all progression")
	w.update_weather(100,false,true)
	check(w.free_seconds==held.free_seconds and w.daylight.hour==held.hour and w.phase_seconds==held.phase_seconds and w.cloud_offset!=held.cloud_offset,"Menu ambience changes only visual time/displacement")
	w.set_automatic(true); w.set_preset("rain")
	w.update_weather(w.duration+0.01,true)
	check(w.target_preset=="cloudy" and w.duration>=45 and w.duration<=75,"Rain transitions through Cloudy with bounded duration")
	w.set_automatic(false); held = w.snapshot(); w.update_weather(60,true)
	check(w.phase_seconds==held.phase_seconds and w.selected_preset==held.selected_preset and w.target_preset==held.target_preset,"Disabling automatic freezes the in-progress front")
	w.set_preset("snowstorm"); w.update_weather(800,true)
	check(w.selected_preset=="snowstorm" and w.phase=="hold","Explicit storm is held indefinitely with automatic off")
	# Find a deterministic 5% draw, and verify boundary vs the identical eligible state.
	var decision_seed = -1
	for i in 1000:
		rng.seed = i
		if rng.randf()<0.05: decision_seed = i; break
	w.set_preset("snowfall"); w.set_automatic(true); w.free_seconds = 1200; w.cooldown = 0; w.rng.seed = decision_seed
	w._next_phase(true)
	check(w.target_preset=="snowstorm" and w.automatic_storm,"Eligible 5% snowy decision schedules Snowstorm")
	w.update_weather(w.duration,true)
	check(w.phase=="peak" and w.duration>=90 and w.duration<=150,"Automatic peak lasts 90-150 seconds")
	var phase_states = [w.snapshot()]
	w.update_weather(w.duration,true); phase_states.append(w.snapshot())
	check(w.phase=="recovery" and w.target_preset=="snowfall","Storm recovers to its ordinary precipitation branch")
	w.update_weather(w.duration,true); phase_states.append(w.snapshot())
	check(w.cooldown==1200 and not w.automatic_storm and w.phase=="hold","Cooldown begins only after recovery ends")
	for case in [[1199.0,0.0,true,true],[1200.0,0.1,true,true],[1200.0,0.0,false,true],[1200.0,0.0,true,false]]:
		w.set_preset("snowfall"); w.free_seconds = case[0]; w.cooldown = case[1]; w.rare_storms = case[2]; w.rng.seed = decision_seed
		w._next_phase(case[3])
		check(not w.automatic_storm,"Storm gate blocks before delay/cooldown, with Rare off or outside free ski: %s" % [case])
	var copy = Weather.new(); root.add_child(copy)
	for saved in phase_states:
		w.restore(saved); copy.restore(saved)
		w.update_weather(700,true)
		for i in 7000: copy.update_weather(0.1,true)
		check(w.selected_preset==copy.selected_preset and w.phase==copy.phase and w.rng.state==copy.rng.state and absf(w.phase_seconds-copy.phase_seconds)<0.00001 and w.cloud_offset.distance_to(copy.cloud_offset)<0.05,"Snapshot and future large/small-step progression agree from "+saved.phase)
	var race = Race.new(); race.title = "Weather fixture"; race.start = Vector3(0,20,25); race.finish = Vector3(0,0,100)
	race.mountain = Race.mountain_reference(preload("res://scripts/world/test_slope.gd").new(),849205174)
	var code = race.share_text(); var decoded = Race.decode(code)
	check(decoded.has("race") and decoded.race.share_text()==code and race.weather_preset=="clear" and race.time_band=="day","Schema 5 canonical share round trip and defaults")
	var identities = {}
	for preset in Rules.PRESETS:
		for band in Rules.TIMES:
			race.weather_preset = preset; race.time_band = band
			identities[race.record_identity()] = true
	check(identities.size()==24,"All weather/time pairs have separate record identity")
	for change in [{"schema":4},{"conditions":{"weather":"rain","time":"day","rules":2}},{"conditions":{"weather":true,"time":"day","rules":1}},{"conditions":{"weather":"rain","time":"noon","rules":1}}]:
		var data = race.to_data(); data.merge(change,true)
		check(Race.decode(JSON.stringify(data)).has("error") and not Race.decode(JSON.stringify(data)).has("race"),"Reject old/unknown/malformed authored rules: %s" % [change])
	w.begin_race("thunderstorm","dusk",race.identity()); copy.begin_race("thunderstorm","dusk",race.identity())
	var suspended_free = w.free_seconds
	w.sample_race(90.0)
	for i in 2700: copy.sample_race(float(i+1)/30.0)
	check(w.state.wind_velocity.is_equal_approx(copy.state.wind_velocity) and w.cloud_offset==copy.cloud_offset and w.active_seconds==90 and w.daylight.hour==17.5 and w.free_seconds==suspended_free,"Race conditions and analytic motion match different render schedules without spending free time")
	var schedule = Storm.event(w.variation_seed,3)
	w.begin_race("thunderstorm","dusk",race.identity())
	check(schedule==Storm.event(w.variation_seed,3) and w.cloud_offset==Vector2.ZERO and w.active_seconds==0,"Retry resets authored hour, clouds and event schedule at elapsed zero")
	var storm = Storm.new(); root.add_child(storm)
	var event = Storm.event(w.variation_seed,0)
	w.sample_race(event.at-0.1); storm.update_storm(w.state,true,2,false,false,1)
	w.sample_race(event.at+0.05); storm.update_storm(w.state,true,2,false,false,1)
	check(w.state.lightning_flash>0 and storm.bolts.any(func(b): return b.visible),"Full lightning produces bounded pooled bolts/cloud illumination")
	storm.update_storm(w.state,true,0,false,false,1)
	check(w.state.lightning_flash==0 and not storm.bolts.any(func(b): return b.visible),"Lightning Off clears both bolt and cloud flash immediately")
	storm.update_storm(w.state,true,2,true,false,1)
	check(w.state.lightning_flash==0,"Reduced motion suppresses abrupt cloud illumination")
	storm.clear_transients(w.active_seconds); w.sample_race(event.thunder_at+.01)
	storm.update_storm(w.state,true,2,false,false,1)
	check(storm.last_thunder==-1 and storm.players.size()==3 and storm.bolts.size()==6,"Pause/handoff drops delayed thunder and retains fixed pools")
	var report = {"checks":checks,"failures":failures}
	FileAccess.open("res://artifacts/weather_upgrade/unit.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("WEATHER_RESULTS ",JSON.stringify(report))
	storm.queue_free(); w.queue_free(); copy.queue_free(); await process_frame
	quit(0 if failures.is_empty() else 1)

func _replace_weather(previous):
	previous.queue_free()
	var next = Weather.new(); root.add_child(next)
	return next

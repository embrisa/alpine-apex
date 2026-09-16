extends SceneTree
## Real diagnostic menu/audio controllers with small UI and terrain fixtures.
const Cases = preload("res://scripts/diagnostics/test_cases.gd")
const Simulation = preload("res://scripts/core/ski_simulation.gd")
const Field = preload("res://tests/skier_voice_upgrade_suite.gd").Fixture
var checks = 0
var failures: Array[String] = []

class AudioEffects extends "res://scripts/presentation/speed_effects.gd":
	func _ready() -> void:
		# Exercise the production audio lifecycle without mountain/particle setup.
		for id in ["audio_wind","audio_ski","audio_edge","audio_rain"]:
			var legacy = AudioStreamPlayer.new()
			var clip = AudioStreamWAV.new()
			clip.format = AudioStreamWAV.FORMAT_16_BITS
			clip.data = PackedByteArray([0,0,64,0,0,0,192,255])
			legacy.stream = clip; add_child(legacy); set(id,legacy)
		add_child(wind); wind.setup(audio_wind); add_child(sfx)

class PanelStub extends "res://scripts/ui/test_case_panel.gd":
	func library(_entries: Array) -> void: mode = "library"
	func controls(_setup: bool) -> void: mode = "test controls"

class HudStub extends RefCounted:
	var menu_mode = "paused"
	func hide_menu() -> void: pass
	func show_menu(value: String) -> void: menu_mode = value

class GameStub extends RefCounted:
	var active = true
	var hud = HudStub.new()
	var sim = Simulation.new()
	var effects
	func resume() -> void:
		active = true # Production resume does not recreate/reset the audio players.

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	print("PASS: " if ok else "FAIL: ",label)
	if not ok: failures.append(label)
func energy(pcm: PackedVector2Array) -> float:
	var sum = 0.0
	for frame in pcm: sum += frame.length_squared()*.5
	return sum/maxi(1,pcm.size())
func drive(game, field) -> void:
	game.effects.wind.sample(game.sim,null,game.active and not game.effects.muted,-12.0)
	if not game.effects.muted: game.effects.sfx.observe_tick(game.sim,field,1.0/120)
	game.effects.sfx.advance(game.sim,field,null,null,game.effects.wind,null,.1,game.active,false,game.effects.muted,false)
	game.effects.wind.advance(.1)
func run() -> void:
	var output = "res://artifacts/diagnostic_audio/"+str(Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(output)
	var game = GameStub.new()
	game.effects = AudioEffects.new(); root.add_child(game.effects)
	var field = Field.new()
	game.sim.reset(Vector3.ZERO); game.sim.prime_contacts(field)
	game.sim.velocity = Vector3(0,0,25)
	for ski in game.sim.skis:
		ski.velocity = game.sim.velocity; ski.load_n = 400.0; ski.grounded = true
	game.sim.grounded = true
	var cases = Cases.new(); root.add_child(cases)
	cases.game = game; cases.directory = output+"/library"
	cases.ui = PanelStub.new(); cases.ui.panel = PanelContainer.new(); root.add_child(cases.ui.panel)
	var legacy_streams: Array = []
	for id in ["audio_wind","audio_ski","audio_edge","audio_rain"]: legacy_streams.append(game.effects.get(id).stream)
	var wind_player = game.effects.wind.player
	var sfx_player = game.effects.sfx.player
	var wind_playback: AudioStreamPlayback
	var sfx_playback: AudioStreamPlayback
	check(game.effects.wind.available and game.effects.sfx.available,"Native wind and riding streams are available for PCM verification")
	if game.effects.wind.available: wind_playback = game.effects.wind.stream.instantiate_playback(); wind_playback.start()
	if game.effects.sfx.available: sfx_playback = game.effects.sfx.stream.instantiate_playback(); sfx_playback.start()
	drive(game,field)
	if wind_playback: check(energy(wind_playback.mix_audio(1.0,24000))>1e-7,"Wind produces audio before diagnostic menus")
	if sfx_playback: check(energy(sfx_playback.mix_audio(1.0,24000))>1e-7,"Ski contact produces audio before diagnostic menus")
	for route in ["library","controls","controls"]:
		game.effects.sfx.pending_equipment = {"speed":8.0}
		if route=="library": cases.open_library()
		else: cases.recording_mode = true; cases.open_controls()
		check(not game.active and not game.effects.wind.audible and not game.effects.sfx.audible,route+" temporarily silences riding audio")
		check(not game.effects.wind.stopping and not game.effects.sfx.stopping,route+" does not retire the audio controllers")
		check(game.effects.wind.player==wind_player and game.effects.sfx.player==sfx_player,route+" retains both native playback players")
		check(game.effects.sfx.pending_equipment.is_empty(),route+" discards obsolete equipment events")
		var preserved = true
		var quiet = true
		for index in 4:
			var player = game.effects.get(["audio_wind","audio_ski","audio_edge","audio_rain"][index])
			preserved = preserved and player.stream==legacy_streams[index]
			quiet = quiet and player.volume_db<=-79.0
		check(preserved,route+" preserves wind, ski, edge and rain playback resources")
		check(quiet,route+" silences all original audio loops without releasing them")
		if wind_playback: check(energy(wind_playback.mix_audio(1.0,48000).slice(24000))<1e-10,route+" fades native wind to silence")
		if sfx_playback: check(energy(sfx_playback.mix_audio(1.0,48000).slice(24000))<1e-10,route+" fades native riding audio to silence")
		cases.back()
		if not game.active: game.resume()
		drive(game,field)
		check(game.effects.wind.audible and game.effects.sfx.audible,route+" resumes both controllers without recreating the scene")
		if wind_playback: check(energy(wind_playback.mix_audio(1.0,24000))>1e-7,route+" resumes audible native wind PCM")
		if sfx_playback: check(energy(sfx_playback.mix_audio(1.0,24000))>1e-7,route+" resumes audible native ski PCM")
	game.effects.muted = true; drive(game,field)
	check(not game.effects.wind.audible and not game.effects.sfx.audible,"Global mute still gates both sources after menu recovery")
	game.effects.muted = false; drive(game,field)
	check(game.effects.wind.audible and game.effects.sfx.audible,"Unmute remains resumable after diagnostic menus")
	game.effects.stop_audio()
	check(game.effects.wind.stopping and game.effects.sfx.stopping,"Final scene teardown still retires both audio controllers")
	if wind_playback: wind_playback.stop()
	if sfx_playback: sfx_playback.stop()
	cases.ui.panel.queue_free(); cases.game = null; cases.queue_free(); game.effects.queue_free()
	await process_frame
	var report = {"checks":checks,"failures":failures,"scope":"Diagnostic menu lifecycle and native PCM; no physical-device listening acceptance"}
	preload("res://tests/test_report.gd").write(output+"/result.json",JSON.stringify(report,"\t"))
	print("DIAGNOSTIC_AUDIO_RESULT ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)

extends RefCounted
signal changed(values: Dictionary)
signal preview_requested(event: String)
signal stop_requested
var enabled: CheckButton
var breathing: CheckButton
var volume: HSlider
var selection: OptionButton
var level: Label
const Voice = preload("res://scripts/presentation/skier_voice.gd")
var events: Array[String] = []

func build(col: VBoxContainer, hud) -> void:
	col.add_theme_constant_override("separation",8)
	hud._note(col,"Alpine Apex Male 1 · Riding reactions share a minute of quiet.")
	enabled = CheckButton.new()
	enabled.name = "SkierReactions"
	enabled.text = "Skier reactions"
	enabled.button_pressed = true
	enabled.toggled.connect(func(_value): _changed())
	col.add_child(enabled)
	breathing = CheckButton.new()
	breathing.name = "SkierBreathing"
	breathing.text = "Heavy breathing at low impact reserve"
	breathing.button_pressed = true
	breathing.toggled.connect(func(_value): _changed())
	col.add_child(breathing)
	level = hud._label("Voice volume · 75%",16,hud.WHITE)
	col.add_child(level)
	volume = HSlider.new()
	volume.name = "SkierVoiceVolume"
	volume.min_value = 0.0
	volume.max_value = 1.0
	volume.step = 0.05
	volume.value = 0.75
	volume.custom_minimum_size.y = 36
	volume.value_changed.connect(func(_value): _changed())
	col.add_child(volume)
	col.add_child(hud._label("Audition a reaction",16,hud.WHITE))
	selection = OptionButton.new()
	selection.name = "SkierVoiceAudition"
	for entry in Voice.AUDITIONS:
		events.append(entry[0])
		selection.add_item(entry[1])
	col.add_child(selection)
	var row = HBoxContainer.new()
	col.add_child(row)
	var play = hud._button("PLAY REACTION")
	play.name = "PlaySkierReaction"
	play.pressed.connect(func(): preview_requested.emit(events[selection.selected]))
	row.add_child(play)
	var stop = hud._button("STOP")
	stop.name = "StopSkierReaction"
	stop.pressed.connect(func(): stop_requested.emit())
	row.add_child(stop)
	hud._note(col,"Each press plays one short reaction from Alpine Apex Male 1. M / Mute all game audio also mutes voice. Shared records and race wins are preview only. Contains strong language.")

func _changed() -> void:
	level.text = "Voice volume · %d%%" % roundi(volume.value*100)
	changed.emit({"enabled":enabled.button_pressed,"breathing_enabled":breathing.button_pressed,"volume":volume.value})

func sync(voice) -> void:
	enabled.set_pressed_no_signal(voice.enabled)
	breathing.set_pressed_no_signal(voice.breathing_enabled)
	volume.set_value_no_signal(voice.volume)
	level.text = "Voice volume · %d%%" % roundi(voice.volume*100)

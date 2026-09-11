extends RefCounted
var controls: Dictionary = {}
var status: Label
var controller

func build(col: VBoxContainer, hud) -> void:
	col.add_child(hud._label("Riding sound",16,hud.WHITE))
	var mode = OptionButton.new()
	mode.name="RidingSound"
	mode.add_item("Procedural",0)
	mode.add_item("Original",1)
	mode.item_selected.connect(func(value): _change("mode",value))
	col.add_child(mode)
	controls.mode=mode
	status=hud._label("",14,hud.MUTED)
	status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	col.add_child(status)
	for entry in [["snow","Snow and surface contact"],["impacts","Landings and crash impacts"],["equipment","Equipment detail"],["near_miss","Near-miss swishes"]]:
		col.add_child(hud._label(entry[1],16,hud.WHITE))
		var slider=HSlider.new()
		slider.name="Audio_"+entry[0]
		slider.min_value=0; slider.max_value=1; slider.step=.05; slider.value=1
		slider.custom_minimum_size.y=36
		slider.value_changed.connect(func(value): _change(entry[0],value))
		col.add_child(slider)
		controls[entry[0]]=slider
	var adaptive=CheckButton.new()
	adaptive.name="AdaptiveAudioMix"
	adaptive.text="Ease wind during impacts and speech"
	adaptive.button_pressed=true
	adaptive.toggled.connect(func(value): _change("adaptive",value))
	col.add_child(adaptive)
	controls.adaptive=adaptive
	hud._note(col,"Surface sounds follow each ski. Crash sounds continue while the skier tumbles. F7 compares wind only.")

func bind(value) -> void:
	controller=value
	sync()

func sync() -> void:
	if controller==null: return
	var values: Dictionary=controller.snapshot()
	controls.mode.select(values.mode)
	for key in ["snow","impacts","equipment","near_miss"]: controls[key].set_value_no_signal(values[key])
	controls.adaptive.set_pressed_no_signal(values.adaptive)
	status.text=controller.label()

func _change(key: String, value) -> void:
	if controller==null: return
	controller.change_setting(key,value)
	sync()

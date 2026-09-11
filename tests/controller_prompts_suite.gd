extends SceneTree
## Real UI with simulated device discovery; no mountain, saves or hardware input.
const Prompts = preload("res://scripts/ui/controller_prompts.gd")
const Navigation = preload("res://scripts/ui/menu_navigation.gd")
const Content = preload("res://scripts/ui/loading_content.gd")
const OUTPUT = "res://artifacts/controller_prompts"

class Devices extends Navigation:
	var attached: Array[int] = [2,5]
	var descriptions = {
		2:{"mapped_name":"Wireless Controller","vendor_id":"1356","product_id":"2508"},
		5:{"mapped_name":"Xbox Series X Controller","vendor_id":1118},
		7:{"mapped_name":"DualSense Wireless Controller","vendor_id":1356},
		8:{"mapped_name":"USB Gamepad"},
	}
	func _connected_devices() -> Array[int]: return attached.duplicate()
	func _device_info(id: int) -> Dictionary: return descriptions.get(id,{})

var checks = 0
var failures: Array[String] = []
var hud
var nav
var signals = 0

func _initialize() -> void: call_deferred("run")
func check(ok: bool, caption: String) -> void:
	checks += 1
	print("PASS: " if ok else "FAIL: ",caption)
	if not ok: failures.append(caption)

func use_pad(id: int) -> void:
	var event = InputEventJoypadButton.new()
	event.device = id
	event.button_index = JOY_BUTTON_X
	event.pressed = true
	nav.route(event)

func run() -> void:
	var _router = preload("res://scripts/core/input_router.gd").new()
	for entry in [["DualShock 4","playstation"],["DualSense Wireless Controller","playstation"],["PS3 Controller","playstation"],["Xbox 360 Controller","xbox"],["XInput Gamepad","xbox"],["Generic Dual Action Gamepad","gamepad"],["Wireless Controller","gamepad"]]:
		check(Prompts.device_family(entry[0]) == entry[1],"Name classification: " + entry[0])
	check(Prompts.device_family("Wireless Controller",{"vendor_id":"1356"}) == "playstation","Sony hardware ID disambiguates Wireless Controller")
	check(Prompts.device_family("Controller",{"raw_name":"DualSense Wireless Controller"}) == "playstation","Raw OS name identifies PlayStation")
	check(Prompts.device_family("Controller",{"xinput_index":"0"}) == "xbox","XInput metadata identifies Xbox layout")
	check(Prompts.binding("grab","playstation") == "□" and Prompts.binding("restart","playstation") == "△","PlayStation face buttons match the actual grab/retry actions")
	check(Prompts.binding("grab","xbox") == "X" and Prompts.binding("restart","xbox") == "Y","Xbox face buttons match the actual grab/retry actions")
	for family in ["playstation","xbox","gamepad","keyboard"]:
		check("Unbound" not in str(Prompts.guide(family)),"Complete binding inventory for " + family)
		check("RT" not in Prompts.summit(family) and "R2" not in Prompts.summit(family),"Summit never advertises the jump trigger as drop-in: " + family)
	# Verify copy is derived from live mappings, not a second binding table.
	var original = InputMap.action_get_events("jump")
	InputMap.action_erase_events("jump")
	var alternate = InputEventJoypadButton.new()
	alternate.button_index = JOY_BUTTON_B
	InputMap.action_add_event("jump",alternate)
	check("Release B" in Content.tip(0,"xbox") and "Hold ○" in Prompts.guide("playstation")["Skiing"],"Loading and Controls follow an altered action binding")
	InputMap.action_erase_events("jump")
	for event in original: InputMap.action_add_event("jump",event)
	if has_meta("interface_device"): remove_meta("interface_device")
	if has_meta("interface_controller"): remove_meta("interface_controller")
	nav = Devices.new()
	root.add_child(nav)
	check(nav.device == 2 and nav.family == "playstation","Already-connected controller is detected before UI setup")
	check(get_meta("interface_device") == "playstation" and "R2" in Content.tip(0,get_meta("interface_device")),"First loading tip uses the detected controller")
	root.size = Vector2i(1920,1080)
	hud = load("res://scripts/ui/hud.gd").new()
	root.add_child(hud)
	nav.device_changed.connect(func():
		signals += 1
		hud.set_input_family(nav.family,nav.device_label())
	)
	hud.set_input_family(nav.family,nav.device_label())
	hud.open_settings()
	hud.settings_tabs.current_tab = 3
	var notes: Dictionary = hud.settings_pages.control_notes
	check("R2" in notes.Skiing.text and "□" in notes["Air control"].text and "R3" in notes.Camera.text,"PlayStation prompts reach all Controls sections")
	use_pad(5)
	check(nav.device == 5 and nav.family == "xbox" and "RT" in notes.Skiing.text and "RB" in notes.Camera.text and "R2" not in notes.Skiing.text,"Using a second pad replaces all PlayStation prompts with Xbox")
	check("A  Select" in hud.footer_controls.text and "View" in notes["Shortcuts & tools"].text,"Xbox menu and telemetry labels agree")
	var count = signals
	use_pad(5)
	check(signals == count,"Repeated input from one controller does not rebuild UI")
	var key = InputEventKey.new()
	key.physical_keycode = KEY_W
	key.pressed = true
	nav.route(key)
	check(nav.family == "keyboard" and nav.device == -1 and "Space" in notes.Skiing.text and "Middle mouse" in notes.Camera.text,"Keyboard use updates the guide even with both pads connected")
	var motion = InputEventJoypadMotion.new()
	motion.device = 2
	for value in [.12,-.12,0.0]:
		motion.axis = JOY_AXIS_LEFT_X
		motion.axis_value = value
		nav.route(motion)
	motion.axis = JOY_AXIS_TRIGGER_RIGHT
	motion.axis_value = -1.0
	nav.route(motion)
	check(nav.family == "keyboard","Stick drift and trigger release do not steal keyboard prompts")
	motion.axis = JOY_AXIS_RIGHT_X
	motion.axis_value = -.4
	nav.route(motion)
	check(nav.family == "playstation","Meaningful camera stick input activates the correct pad")
	var mouse = InputEventMouseMotion.new()
	mouse.relative = Vector2(1,0)
	nav.route(mouse)
	check(nav.family == "playstation","Tiny mouse movement does not replace controller prompts")
	mouse.relative = Vector2(8,0)
	nav.route(mouse)
	check(nav.family == "keyboard","Deliberate mouse movement restores keyboard prompts")
	nav.attached.append(7)
	nav._connection_changed(7,true)
	check(nav.device == 7 and nav.family == "playstation","Hotplug selects a pad while keyboard is active")
	count = signals
	use_pad(2)
	check(signals == count + 1 and nav.device_label() == "Wireless Controller","Same-family handoff refreshes the actual controller name")
	nav.attached.erase(7)
	nav._connection_changed(7,false)
	check(nav.device == 2,"Disconnecting an inactive controller preserves the active one")
	nav.attached.erase(2)
	nav._connection_changed(2,false)
	check(nav.device == 5 and nav.family == "xbox","Disconnecting the active pad selects the remaining pad")
	nav.attached.clear()
	nav._connection_changed(5,false)
	check(nav.family == "keyboard","Disconnecting the last pad restores keyboard")
	# Exercise real API boundary with an unconnected synthetic event as runtime uses.
	var real_navigation = Navigation.new()
	root.add_child(real_navigation)
	var absent = InputEventJoypadButton.new()
	absent.device = 99
	absent.pressed = true
	real_navigation.route(absent)
	check(real_navigation.family == "gamepad","Unconnected synthetic events safely use generic prompts")
	real_navigation.queue_free()
	await process_frame
	nav.attached.assign([2,5,7,8])
	for family_id in [5,2,7,8,-1]:
		if family_id < 0: nav.route(key)
		else: use_pad(family_id)
		await capture_guide(str(family_id),notes)
	if DisplayServer.get_name() != "headless":
		root.size = Vector2i(1280,720)
		for family_id in [5,2]:
			use_pad(family_id)
			await capture_guide(str(family_id) + "_720p",notes)
		nav.route(key)
	# A scene reload retains the user's current keyboard choice, not the first pad.
	var reloaded = Devices.new()
	root.add_child(reloaded)
	check(reloaded.family == "keyboard","Scene reload retains the last-used keyboard")
	reloaded.queue_free()
	use_pad(5)
	reloaded = Devices.new()
	root.add_child(reloaded)
	check(reloaded.device == 5 and reloaded.family == "xbox","Scene reload retains the active controller")
	reloaded.queue_free()
	print("CONTROLLER_PROMPTS_RESULTS ",JSON.stringify({"checks":checks,"failures":failures,"native":DisplayServer.get_name() != "headless"}))
	hud.queue_free()
	nav.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

func capture_guide(id: String, notes: Dictionary) -> void:
	if DisplayServer.get_name() == "headless": return
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	for title in ["Skiing","Air control","Camera"]:
		var body: Control = notes[title].get_parent()
		var toggle: Button = body.get_parent().get_child(0)
		toggle.button_pressed = true
	var page = hud.settings_tabs.get_current_tab_control() as ScrollContainer
	page.scroll_vertical = 0
	for i in 8: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUTPUT + "/guide_" + id + ".png")
	for title in ["Shortcuts & tools","Comfort"]:
		var body: Control = notes[title].get_parent()
		var toggle: Button = body.get_parent().get_child(0)
		toggle.button_pressed = true
	for i in 4: await process_frame
	page.ensure_control_visible(notes.Comfort)
	for i in 4: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUTPUT + "/shortcuts_" + id + ".png")
	for title in ["Shortcuts & tools","Comfort"]:
		var body: Control = notes[title].get_parent()
		var toggle: Button = body.get_parent().get_child(0)
		toggle.button_pressed = false

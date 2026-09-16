extends RefCounted
## Retained menu pages share a small card; crash actions use the same intent owners.
var hud
var shell: VBoxContainer
var header: VBoxContainer
var home: VBoxContainer
var tools: VBoxContainer
var actions: BoxContainer
var bottom: VBoxContainer
var explore_button: Button
var tools_button: Button
var back_button: Button
var quit_button: Button
var crash_paused = false

func build(owner) -> void:
	hud = owner
	hud.menu = hud._panel()
	hud.menu.name = "DescentMenu"
	hud.shell_layout.frame(hud.menu)
	shell = VBoxContainer.new()
	shell.add_theme_constant_override("separation",12)
	hud.menu.add_child(shell)
	header = VBoxContainer.new()
	header.add_theme_constant_override("separation",6)
	shell.add_child(header)
	hud.menu_location = hud._label("MOUNTAIN",12,hud.LIME,true)
	hud.menu_location.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	header.add_child(hud.menu_location)
	hud.menu_title = hud._label("Ready to ski",30,hud.WHITE)
	header.add_child(hud.menu_title)
	hud.menu_description = hud._label("",15,hud.MUTED)
	hud.menu_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	header.add_child(hud.menu_description)
	back_button = hud._button("Back")
	back_button.pressed.connect(back_home)
	shell.add_child(back_button)
	hud.menu_tabs = TabContainer.new()
	hud.menu_tabs.tabs_visible = false
	hud.menu_tabs.all_tabs_in_front = false
	hud.menu_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hud.menu_tabs.add_theme_stylebox_override("panel",StyleBoxEmpty.new())
	shell.add_child(hud.menu_tabs)
	home = page("Ride")
	actions = BoxContainer.new()
	actions.vertical = true
	actions.add_theme_constant_override("separation",8)
	home.add_child(actions)
	hud.primary = hud._button("Drop in",true)
	hud.primary.pressed.connect(hud._primary_pressed)
	actions.add_child(hud.primary)
	hud.crash_restart = hud._button("Try again")
	hud.crash_restart.bind_action("restart")
	hud.crash_restart.pressed.connect(func(): hud.restart_requested.emit())
	actions.add_child(hud.crash_restart)
	hud.navigation_button = hud._button("Map / Navigation")
	hud.navigation_button.pressed.connect(func(): hud.navigation_requested.emit())
	home.add_child(hud.navigation_button)
	explore_button = hud._button("Explore")
	explore_button.pressed.connect(func(): hud.menu_tabs.current_tab = 1)
	home.add_child(explore_button)
	tools_button = hud._button("Tools")
	tools_button.pressed.connect(func(): hud.menu_tabs.current_tab = 2)
	home.add_child(tools_button)
	var explore = page("Explore")
	var mountains = hud._button("Mountains")
	mountains.pressed.connect(func(): hud.mountains_requested.emit())
	explore.add_child(mountains)
	hud.secondary = hud._button("Create & share races")
	hud.secondary.bind_action("race_library")
	hud.secondary.pressed.connect(func(): hud.races_requested.emit())
	explore.add_child(hud.secondary)
	hud.records_button = hud._button("Records & ghosts")
	hud.records_button.bind_action("run_records")
	hud.records_button.pressed.connect(func(): hud.competition_requested.emit())
	explore.add_child(hud.records_button)
	tools = page("Tools")
	var workbench = hud._button("Physics Workbench")
	workbench.bind_action("tuning")
	workbench.pressed.connect(func(): hud.workbench_requested.emit())
	tools.add_child(workbench)
	hud._note(tools,"Physics tuning and speed tests are unranked.")
	var identity_pending = hud.BuildIdentity.worker!=null and not hud.BuildIdentity.poll_background()
	hud.build_version_label = hud._label("Development build" if identity_pending else hud.BuildIdentity.short_label(),12,hud.MUTED)
	hud.build_version_label.name = "BuildVersion"
	hud.build_version_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tools.add_child(hud.build_version_label)
	hud.menu_specs = hud._label("",12,hud.MUTED,true)
	hud.menu_specs.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tools.add_child(hud.menu_specs)
	hud.copy_build_button = hud._button("Copy build details")
	hud.copy_build_button.name = "CopyBuildDetails"
	hud.copy_build_button.disabled = identity_pending
	hud.copy_build_button.pressed.connect(func(): DisplayServer.clipboard_set(hud.BuildIdentity.details()))
	tools.add_child(hud.copy_build_button)
	if identity_pending: hud._finish_build_identity.call_deferred()
	bottom = VBoxContainer.new()
	bottom.add_theme_constant_override("separation",8)
	shell.add_child(bottom)
	hud.weather_button = hud._button("Settings")
	hud.weather_button.pressed.connect(hud.open_settings)
	bottom.add_child(hud.weather_button)
	bottom.add_child(HSeparator.new())
	quit_button = hud._button("Quit Game")
	quit_button.pressed.connect(func(): hud.quit_requested.emit())
	bottom.add_child(quit_button)
	# Clock/reason are retained readouts for diagnostics and the explicit pause card.
	hud.crash_clock = hud._label("",13,hud.MUTED,true)
	header.add_child(hud.crash_clock)
	hud.crash_availability = hud._label("",13,hud.MUTED)
	hud.crash_availability.hide()
	header.add_child(hud.crash_availability)
	hud.menu_tabs.tab_changed.connect(func(_index): refresh(); focus_page())
	hud.root.resized.connect(func(): layout.call_deferred())

func page(caption: String) -> VBoxContainer:
	var scroll = ScrollContainer.new()
	scroll.name = caption
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	hud.menu_tabs.add_child(scroll)
	var column = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation",8)
	scroll.add_child(column)
	return column

func is_crash_actions() -> bool:
	return hud.menu_mode=="crashed" and not crash_paused

func back_home() -> void:
	var previous: int = hud.menu_tabs.current_tab
	hud.menu_tabs.current_tab = 0
	(tools_button if previous==2 else explore_button).grab_focus()

func focus_page() -> void:
	if not is_instance_valid(hud) or not hud.is_inside_tree(): return
	if is_crash_actions(): return
	var candidates = preload("res://scripts/ui/navigation_tabs.gd").focusable(hud.menu_tabs.get_current_tab_control())
	if not candidates.is_empty(): candidates[0].grab_focus()

var crash_style: StyleBox
var card_style: StyleBox

func refresh() -> void:
	var crash = is_crash_actions()
	var recovering: bool = hud.menu_mode=="crashed"
	var index: int = hud.menu_tabs.current_tab
	header.visible = not crash
	bottom.visible = not crash
	back_button.visible = index!=0 and not crash
	hud.menu_location.text = hud.mountain_name if not hud.mountain_name.is_empty() else "ALPINE APEX"
	hud.menu_description.visible = hud.menu_mode=="finished" and index==0
	hud.menu_title.text = ["Ready to ski" if hud.menu_mode=="title" else "Race complete" if hud.menu_mode=="finished" else "Paused","Explore","Tools"][index]
	hud.navigation_button.visible = hud.menu_mode in ["title","paused"]
	explore_button.visible = not recovering
	tools_button.visible = not crash
	hud.crash_clock.visible = recovering and crash_paused
	hud.crash_availability.hide()
	actions.vertical = not crash
	actions.alignment = BoxContainer.ALIGNMENT_CENTER if crash else BoxContainer.ALIGNMENT_BEGIN
	actions.add_theme_constant_override("separation",28 if crash else 8)
	hud.primary.custom_minimum_size.x = 0
	hud.primary.set_text_action(crash)
	hud.crash_restart.set_text_action(crash)
	hud.primary.menu_back = not crash and hud.menu_mode in ["paused","crashed"]
	hud.primary.bind_action("begin_run" if crash else "")
	hud.primary.text = "Stand Up" if crash else "Return to crash" if recovering else "Drop in" if hud.menu_mode=="title" else "Try again" if hud.menu_mode=="finished" else "Resume"
	hud.crash_restart.visible = hud.menu_mode in ["paused","crashed"]
	hud.primary.size_flags_horizontal = Control.SIZE_SHRINK_CENTER if crash else Control.SIZE_EXPAND_FILL
	hud.crash_restart.size_flags_horizontal = Control.SIZE_SHRINK_CENTER if crash else Control.SIZE_EXPAND_FILL
	if crash_style==null: crash_style = StyleBoxEmpty.new()
	if card_style==null: card_style = hud._style(hud.AlpineTheme.PANEL,hud.AlpineTheme.EDGE,20)
	hud.menu.add_theme_stylebox_override("panel",crash_style if crash else card_style)
	hud.menu.set_meta("screen_profile","crash_actions" if crash else "compact_card")
	if crash:
		var focused = hud.root.get_viewport().gui_get_focus_owner()
		if focused and hud.menu.is_ancestor_of(focused): focused.release_focus()
	layout.call_deferred()
	hud._sync_menu_backdrop()

func layout() -> void:
	if not is_instance_valid(hud) or not hud.is_inside_tree() or not hud.menu.is_inside_tree(): return
	if not is_instance_valid(hud.menu_tabs) or hud.menu_tabs.get_tab_count()==0: return
	var column = hud.menu_tabs.get_current_tab_control().get_child(0)
	var desired: float = column.get_combined_minimum_size().y
	if not is_crash_actions():
		desired += header.get_combined_minimum_size().y+bottom.get_combined_minimum_size().y+76.0
		if back_button.visible: desired += back_button.get_combined_minimum_size().y+12.0
	hud.menu.set_meta("content_height",desired)
	hud.shell_layout._layout(hud.menu)

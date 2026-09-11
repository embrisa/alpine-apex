extends SceneTree
## Small retained-screen regression fixture: no world generation or saved runs.
const HUD = preload("res://scripts/ui/hud.gd")
const MountainLibrary = preload("res://scripts/ui/mountain_library.gd")
const Session = preload("res://scripts/core/run_session.gd")
const OUTPUTS = [Vector2i(1280,720),Vector2i(1440,900),Vector2i(1920,1080),Vector2i(3840,2160),Vector2i(3440,1440)]
var checks = 0
var failures: Array[String] = []

class Fixture extends Node3D:
	var hud
	var current_mountain = null

class SurveyFixture extends "res://scripts/racing/race_workshop.gd":
	# Remove terrain work so the test isolates UI ownership of camera translation.
	func _update_survey() -> void: pass
	func pick_snow(_screen: Vector2) -> Variant: return null

func _initialize() -> void: run.call_deferred()

func check(value: bool, caption: String) -> void:
	checks += 1
	print("PASS: " if value else "FAIL: ",caption)
	if not value: failures.append(caption)

func settle() -> void:
	for i in 5: await process_frame

func outside_scroll(control: Control) -> bool:
	var ancestor = control.get_parent()
	while ancestor:
		if ancestor is ScrollContainer: return false
		ancestor = ancestor.get_parent()
	return true

func run() -> void:
	var _input_router = preload("res://scripts/core/input_router.gd").new()
	var fixture = Fixture.new()
	root.add_child(fixture)
	var hud = HUD.new()
	hud.feedback.persist = false
	hud.feedback.muted = true
	hud.feedback.reduced_motion = true
	fixture.hud = hud
	fixture.add_child(hud)
	hud.hide_menu()
	var mountains = MountainLibrary.new()
	fixture.add_child(mountains)
	mountains.build(fixture)
	var races = SurveyFixture.new()
	fixture.add_child(races)
	races.game = fixture
	races._build_ui()
	races.cursor = MeshInstance3D.new()
	races.add_child(races.cursor)
	var records = hud.competition
	var session = Session.new()
	session.personal_best = 60.0
	session.history = []
	for i in 20:
		session.history.append({"date":1750000000+i,"time":60.0+i,"peak_kmh":100+i})
	records.refresh(session,true)
	check("BEST" in records.history.text and "Top speed" in records.history.text,"Record history retains best markers and peak speeds")
	check(records.ghost_toggle.disabled,"Unavailable ghost is explained and disabled")
	for scale_value in [1.0,1.4]:
		hud.shell_layout.ui_scale = scale_value
		for output in OUTPUTS:
			root.size = output
			hud.shell_layout.resize()
			await settle()
			var bounds = Rect2(Vector2.ZERO,Vector2(root.content_scale_size))
			mountains.panel.show()
			for page_index in 3:
				mountains.tabs.current_tab = page_index
				await settle()
				check(bounds.encloses(mountains.panel.get_global_rect()),"Mountain bounds at %s scale %.1f category %d" % [output,scale_value,page_index])
				check(mountains.preview_column.get_parent()==mountains.page_columns[page_index],"Category keeps the selected mountain preview")
				var columns = mountains.page_columns[page_index]
				check(columns.vertical==(columns.size.x<columns.stack_below),"Related mountain content stacks at the available width")
				check(mountains.preview.size.x>300,"Mountain preview has usable width")
			for action in mountains.all_buttons:
				if action.get_parent().name=="MountainActions":
					check(outside_scroll(action) and bounds.encloses(action.get_global_rect()),"Mountain primary actions stay outside page scrolling")
			mountains.panel.hide()
			races.panel.show()
			hud.shell_layout.frame(races.panel)
			await settle()
			check(bounds.encloses(races.panel.get_global_rect()),"Race library fits %s scale %.1f" % [output,scale_value])
			check(outside_scroll(races.race_button),"Race selected remains outside scrolling")
			races.library.hide()
			races.library_actions.hide()
			races.editor.show()
			races.editor_scroll.show()
			races.save_button.show()
			hud.shell_layout.frame(races.panel,true)
			await settle()
			check(bounds.encloses(races.panel.get_global_rect()) and races.panel.size.x<bounds.size.x*.45,"Race drawer leaves central terrain open")
			check(outside_scroll(races.save_button) and bounds.encloses(races.save_button.get_global_rect()),"Save race stays visible outside the editor scroll")
			races.panel.hide()
			races.editor.hide()
			races.editor_scroll.hide()
			races.save_button.hide()
			races.library.show()
			races.library_actions.show()
			records.panel.show()
			for index in 3:
				records.tabs.current_tab = index
				await settle()
				check(bounds.encloses(records.panel.get_global_rect()),"Records fit %s scale %.1f category %d" % [output,scale_value,index])
			records.panel.hide()
	races.panel.show()
	races.editor_scroll.show()
	races.editor.show()
	races.mode = "create"
	races.survey_keyboard_enabled = true
	races.start_button.grab_focus()
	var before = races.focus_point
	Input.action_press("steer_right")
	Input.action_press("tuck")
	races.update_survey(1.0)
	check(races.focus_point==before and not races.survey_keyboard_enabled,"Menu button focus prevents rider axes from translating survey camera")
	root.gui_release_focus()
	races.survey_keyboard_enabled = true
	races.update_survey(1.0)
	check(races.focus_point==before,"Rider axes cannot pan the survey even after focus is released")
	Input.action_release("steer_right")
	Input.action_release("tuck")
	races.survey_keyboard_enabled = false
	check(not races.keyboard_survey_allowed(),"Keyboard survey requires explicit terrain activation")
	var wheel = InputEventMouseButton.new()
	wheel.pressed = true
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.position = races.panel.get_global_rect().get_center()
	var height_before = races.survey_height
	races.handle_input(wheel)
	check(races.survey_height==height_before,"Scrolling inside drawer cannot zoom the terrain")
	mountains.busy = true
	mountains._refresh_actions()
	check(mountains.tabs.buttons.all(func(button): return button.disabled),"Generation busy state disables edge categories")
	mountains.busy = false
	mountains._refresh_actions()
	check(mountains.tabs.buttons.all(func(button): return not button.disabled),"Generation completion restores category actions")
	fixture.queue_free()
	await process_frame
	print("Retained interface: %d checks, %d failures" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)

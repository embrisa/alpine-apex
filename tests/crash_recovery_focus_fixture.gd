extends RefCounted
## Only this native test instance owns application focus. The OS window stays
## untouched. Inherited _notification methods run automatically in Godot, so a
## subclass cannot suppress Main's handler. Clone the live scene script before
## entering the tree; rename only that entry point and keep its body unchanged.
const ENTRY = "func _notification(what: int) -> void:"
const RENAMED = "func _crash_fixture_production_notification(what: int) -> void:"
const DISPATCH = """
var crash_fixture_focus_events: Array = []
var crash_fixture_external_source = "external_os"

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_APPLICATION_FOCUS_IN]:
		_crash_fixture_log_focus(what,crash_fixture_external_source,false,application_focused)
		return
	_crash_fixture_production_notification(what)

func crash_fixture_apply_focus(focused: bool, stage: String) -> void:
	var what = NOTIFICATION_APPLICATION_FOCUS_IN if focused else NOTIFICATION_APPLICATION_FOCUS_OUT
	var before: bool = application_focused
	_crash_fixture_production_notification(what)
	_crash_fixture_log_focus(what,stage,true,before)

func crash_fixture_probe_external(what: int) -> void:
	crash_fixture_external_source = "injected_external_probe"
	notification(what)
	crash_fixture_external_source = "external_os"

func _crash_fixture_log_focus(what: int, source: String, routed: bool, before: bool) -> void:
	var row = {"notification":what,"source":source,"routed_to_production":routed,
		"before_controlled_focus":before,"controlled_focus":application_focused,
		"actual_window_focus":get_window().has_focus() if is_inside_tree() else false,
		"process_frame":Engine.get_process_frames(),"physics_frame":Engine.get_physics_frames(),
		"ticks_usec":Time.get_ticks_usec(),"active":active,"automated":automated,
		"elapsed":session.elapsed if session!=null else 0.0,
		"recovery_paused":session.recovery_paused if session!=null else false}
	crash_fixture_focus_events.append(row)
	print("CRASH_FIXTURE_FOCUS ",JSON.stringify(row,"",true,true))
"""

static func install(game: Node) -> Dictionary:
	if game.is_inside_tree(): return {"error":"Focus fixture must be installed before Main enters the tree."}
	var live: Script = game.get_script()
	if live==null or live.resource_path!="res://scripts/main.gd":
		return {"error":"Expected the actual main.tscn script."}
	var source: String = live.source_code
	if source.count(ENTRY)!=1 or "_crash_fixture_" in source:
		return {"error":"Main notification declaration changed; review the precise test seam."}
	var controlled = GDScript.new()
	controlled.source_code = source.replace(ENTRY,RENAMED)+"\n"+DISPATCH
	var error = controlled.reload()
	if error!=OK: return {"error":"Controlled Main compilation failed: %d" % error}
	game.set_script(controlled)
	return {"source_sha256":source.sha256_text(),"controlled_sha256":controlled.source_code.sha256_text(),
		"mode":"live Main notification dispatch only; native window focus observed"}

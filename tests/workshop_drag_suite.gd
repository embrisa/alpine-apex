extends SceneTree
const Workshop = preload("res://scripts/workshop/motion_workshop.gd")
var editor
var checks = 0
var failures: Array = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr(label)
func mouse(button: bool, pressed: bool, at: Vector2, relative := Vector2.ZERO) -> void:
	var event = InputEventMouseButton.new() if button else InputEventMouseMotion.new()
	event.position = at; event.global_position = at
	if button: event.button_index = MOUSE_BUTTON_LEFT; event.pressed = pressed
	else: event.button_mask = MOUSE_BUTTON_MASK_LEFT; event.relative = relative
	Input.parse_input_event(event)
	await process_frame
func point(bone: String) -> Vector2:
	return editor.stage.global_position+editor.stage.project_point(editor.stage.bone_point(bone))
func gesture(bone: String, delta: Vector2) -> void:
	var at = point(bone)
	await mouse(true,true,at)
	await mouse(false,false,at+delta,delta)
	await mouse(true,false,at+delta)
func run() -> void:
	root.size = Vector2i(1440,900)
	editor = Workshop.new(); editor.persistence_enabled = false; root.add_child(editor)
	for i in 15: await process_frame
	var project = editor.project; var stage = editor.stage
	editor.selected = ["Head"]; editor.sync_selection()
	var before = project.evaluate(editor.variant_id,editor.time)
	var initial_regions: int = project.variant(editor.variant_id).regions.size()
	await gesture("Hips",Vector2.ZERO)
	check(editor.selected==["Hips"],"Click selects a previously unselected pelvis")
	check(project.variant(editor.variant_id).regions.size()==initial_regions,"Selection alone inserts no correction")
	editor.selected = ["Head"]; editor.sync_selection()
	await gesture("Hips",Vector2(12,0))
	var after = project.evaluate(editor.variant_id,editor.time)
	check(after.root.distance_to(before.root)>.01,"First gesture moves an unselected pelvis in default Auto mode")
	check(project.variant(editor.variant_id).regions.size()==initial_regions+1,"One drag creates exactly one correction")
	var first = project.fk(before); var second = project.fk(after)
	for foot in ["LeftFoot","RightFoot"]:
		check(first.joints[foot].distance_to(second.joints[foot])<.002,"Grounded pelvis holds "+foot+" position")
		check(first.rotations[foot].get_rotation_quaternion().angle_to(second.rotations[foot].get_rotation_quaternion())<.001,"Grounded pelvis holds "+foot+" orientation")
	editor.undo()
	check(project.evaluate(editor.variant_id,editor.time).root.distance_to(before.root)<.000001,"Single undo restores entire pelvis gesture")
	editor.redo()
	check(project.evaluate(editor.variant_id,editor.time).root.distance_to(after.root)<.000001,"Single redo restores entire pelvis gesture")
	editor.undo()
	await gesture("Head",Vector2(22,8))
	var head: int = project.data.rig.names.find("Head")
	check(project.evaluate(editor.variant_id,editor.time).q[head].angle_to(before.q[head])>.05,"Direct dragging a previously unselected head rotates it")
	editor.undo()
	await gesture("head_end",Vector2(22,8))
	check(editor.selected==["Head"] and project.evaluate(editor.variant_id,editor.time).q[head].angle_to(before.q[head])>.05,"Helmet tip drags the visible head instead of an inert terminal marker")
	editor.undo()
	await gesture("RightHand",Vector2(15,8))
	check(project.fk(project.evaluate(editor.variant_id,editor.time)).joints.RightHand.distance_to(first.joints.RightHand)>.01,"Direct dragging a previously unselected hand runs IK")
	editor.undo()
	var at = point("Hips")
	await mouse(true,true,at); await mouse(false,false,at+Vector2(20,0),Vector2(20,0))
	var escape = InputEventKey.new(); escape.keycode = KEY_ESCAPE; escape.pressed = true
	Input.parse_input_event(escape); await process_frame
	await mouse(true,false,at+Vector2(20,0))
	check(is_instance_valid(editor) and stage.drag_mode.is_empty(),"Escape cancels the drag without closing workshop")
	check(project.evaluate(editor.variant_id,editor.time).root.distance_to(before.root)<.000001,"Cancelled gesture leaves no pose correction")
	stage.comparison = "Constrained result"; editor.refresh()
	await gesture("Hips",Vector2(15,0))
	check(project.evaluate(editor.variant_id,editor.time).root.distance_to(before.root)<.000001,"Read-only comparison cannot mutate the pose")
	print("WORKSHOP_DRAG ",JSON.stringify({"checks":checks,"failures":failures}))
	editor.queue_free(); await process_frame; quit(0 if failures.is_empty() else 1)

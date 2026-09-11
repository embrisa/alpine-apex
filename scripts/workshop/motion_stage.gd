extends Control
signal bone_selected(bone: String, extend: bool)
signal pose_drag_started
signal pose_dragged(pose: Dictionary, bones: Array)
signal pose_drag_finished
signal pose_drag_cancelled
signal edit_message(text: String)
const Visual = preload("res://scripts/presentation/skier_visual.gd")
const Evaluator = preload("res://scripts/workshop/pose_evaluator.gd")
var project
var variant_id = ""
var time = 0.0
var view = SubViewport.new()
var scene = Node3D.new()
var camera = Camera3D.new()
var characters: Array = []
var evaluator = Evaluator.new()
var poses: Array = []
var diagnostics: Dictionary = {}
var selected: Array = ["Hips"]
var comparison = "Your edit"
var skeleton_visible = true
var ghosts_visible = false
var world_axes = false
var tool = "Auto"
var hold_feet = true
var hovered_bone = ""
var drag_started = false
var drag_bone = ""
var drag_pins: Dictionary = {}
var pins: Dictionary = {}
var yaw = 0.45
var pitch = -.12
var distance = 3.7
var focus = Vector3(0,.95,0)
var orthographic = false
var drag_mode = ""
var drag_axis = Vector3.ZERO
var drag_origin = Vector3.ZERO
var drag_point = Vector3.ZERO
var drag_start_mouse = Vector2.ZERO
var drag_pose: Dictionary = {}
var drag_before: Dictionary = {}
var drag_bones: Array = []
var orbit_button = 0
var display_pose: Dictionary = {}
var frame_cost_us = 0
var fitting_frame = Transform3D.IDENTITY

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	custom_minimum_size = Vector2(280,260)
	view.own_world_3d = true; view.transparent_bg = false
	view.msaa_3d = Viewport.MSAA_4X
	view.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(view); view.add_child(scene)
	var environment = WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("182c3b")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("d6eafa")
	environment.environment.ambient_light_energy = .8
	scene.add_child(environment)
	var light = DirectionalLight3D.new(); light.rotation_degrees = Vector3(-45,-30,0); light.light_energy = 1.5
	scene.add_child(light)
	var fill = DirectionalLight3D.new(); fill.rotation_degrees = Vector3(-15,145,0); fill.light_energy = .7
	scene.add_child(fill)
	var ground = MeshInstance3D.new(); ground.name = "Ground"
	var mesh = PlaneMesh.new(); mesh.size = Vector2(30,30); ground.mesh = mesh
	var material = StandardMaterial3D.new(); material.albedo_color = Color("334b5c"); material.roughness = .9
	ground.material_override = material; scene.add_child(ground)
	for index in 3:
		var character = Visual.new(); character.preview_only = true
		scene.add_child(character); characters.append(character)
	scene.add_child(camera); camera.current = true; camera.near = .03; camera.fov = 42
	resized.connect(_resize_view)
	set_process(false)
	_resize_view(); update_camera()

func _resize_view() -> void:
	var scale = get_global_transform_with_canvas().get_scale()
	view.size = Vector2i(maxi(32,int(size.x*scale.x)),maxi(32,int(size.y*scale.y)))
	view.render_target_update_mode = SubViewport.UPDATE_ONCE
	queue_redraw()

func update_camera() -> void:
	var direction = Vector3(sin(yaw)*cos(pitch),-sin(pitch),cos(yaw)*cos(pitch))
	camera.position = focus+direction*distance
	camera.look_at(focus,Vector3.UP)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL if orthographic else Camera3D.PROJECTION_PERSPECTIVE
	camera.size = distance*.7
	_layout_characters()
	view.render_target_update_mode = SubViewport.UPDATE_ONCE
	queue_redraw()

func camera_data() -> Dictionary:
	return {"yaw":yaw,"pitch":pitch,"distance":distance,"focus":project.vec(focus),"orthographic":orthographic,"comparison":comparison}

func restore_camera(value: Dictionary) -> void:
	yaw = value.get("yaw",.45); pitch = value.get("pitch",-.12); distance = value.get("distance",3.7)
	focus = project.v3(value.get("focus",[0,.95,0])); orthographic = value.get("orthographic",false)
	comparison = value.get("comparison","Your edit"); update_camera()

func set_view(name_value: String) -> void:
	yaw = {"Front":0.0,"Side":PI*.5,"Back":PI}.get(name_value,.45); pitch = -.08
	update_camera()

func refresh(pose_override: Dictionary = {}) -> void:
	if project==null or variant_id.is_empty() or characters.is_empty(): return
	var start = Time.get_ticks_usec()
	var original = project.evaluate(variant_id,time,false)
	var edited = project.evaluate(variant_id,time) if pose_override.is_empty() else pose_override
	display_pose = edited
	poses = [Evaluator.authored(project,original),Evaluator.authored(project,edited)]
	for i in 2: characters[i].present_authored(poses[i].joints,poses[i].rotations)
	var constrained = evaluator.evaluate(project,edited,project.data.preview,characters[2])
	diagnostics = constrained
	poses.append(constrained)
	fitting_frame = characters[2].transform
	var support = Basis(Vector3.RIGHT,deg_to_rad(project.data.preview.slope))
	scene.get_node("Ground").basis = support
	for i in 3:
		characters[i].visible = comparison in ["Side by side","Overlay"] or i==["Original","Your edit","Constrained result"].find(comparison)
		_set_tint(characters[i],i if comparison=="Overlay" and i!=1 else -1)
	_layout_characters()
	frame_cost_us = Time.get_ticks_usec()-start
	view.render_target_update_mode = SubViewport.UPDATE_ONCE
	queue_redraw()

func _layout_characters() -> void:
	for i in characters.size():
		var offset = camera.basis.x*(i-1)*1.9 if comparison=="Side by side" else Vector3.ZERO
		if project!=null: offset.y = -offset.z*tan(deg_to_rad(project.data.preview.slope))
		characters[i].transform = fitting_frame
		characters[i].position += offset

func _set_tint(node: Node, index: int) -> void:
	if node is GeometryInstance3D:
		if index<0: node.material_override = null
		elif not node.material_override is StandardMaterial3D:
			var material = StandardMaterial3D.new(); material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			material.albedo_color = Color(.2,.85,1,.22) if index==0 else Color(1,.4,.6,.22)
			node.material_override = material
	for child in node.get_children(): _set_tint(child,index)

func project_point(point: Vector3) -> Vector2:
	return camera.unproject_position(point)*size/Vector2(view.size)

func unproject(mouse: Vector2, point: Vector3) -> Vector3:
	var pixel = mouse*Vector2(view.size)/size
	var origin = camera.project_ray_origin(pixel); var direction = camera.project_ray_normal(pixel)
	var plane = Plane(camera.global_basis.z,point)
	var hit = plane.intersects_ray(origin,direction)
	return point if hit==null else hit

func bone_point(bone: String, index: int = 1) -> Vector3:
	return characters[index].global_transform*poses[index].joints.get(bone,Vector3.ZERO)

func _draw() -> void:
	if not is_instance_valid(camera) or not camera.is_inside_tree(): return
	draw_texture_rect(view.get_texture(),Rect2(Vector2.ZERO,size),false)
	if poses.is_empty(): return
	var colors = [Color("72cce4"),Color("ddf8ae"),Color("ff9fac")]
	for i in 3:
		if not characters[i].visible: continue
		if skeleton_visible:
			_draw_skeleton(poses[i],characters[i].global_transform,colors[i],i==1)
		if comparison=="Side by side":
			var p = project_point(characters[i].position+Vector3(0,1.95,0))
			draw_string(ThemeDB.fallback_font,p-Vector2(55,0),["ORIGINAL","YOUR EDIT","CONSTRAINED"][i],HORIZONTAL_ALIGNMENT_LEFT,-1,14,colors[i])
	if ghosts_visible:
		for offset in [-3.0,3.0]:
			var pose = project.evaluate(variant_id,clampf(time+offset/60,0,project.variant(variant_id).duration))
			_draw_skeleton(Evaluator.authored(project,pose),characters[1].global_transform,Color(.7,.85,1,.24),false)
	if not selected.is_empty() and characters[1].visible:
		var bone: String = selected[-1]
		var center = bone_point(bone)
		for axis in 3:
			var axis_vector = Vector3.ZERO; axis_vector[axis] = 1
			var frame: Basis = Basis.IDENTITY if world_axes else characters[1].global_basis*poses[1].rotations[bone]
			axis_vector = frame*axis_vector
			var color = [Color("ff766f"),Color("a8ec85"),Color("83bcff")][axis]
			if rotation_tool(bone):
				var points = ring(center,axis_vector)
				draw_polyline(points,color,2,true)
			else:
				draw_line(project_point(center),project_point(center+axis_vector*.22),color,3,true)
		if pins.has(bone): draw_circle(project_point(center),11,Color("dffb9d"),false,2)
	if not hovered_bone.is_empty() and characters[1].visible:
		draw_circle(project_point(bone_point(hovered_bone)),9,Color("ffdc89"),false,2)
	var help = "Drag a joint to pose · RMB orbit · MMB pan · Wheel zoom"
	if not characters[1].visible: help = "Read-only comparison · Choose Your edit to pose"
	elif not hovered_bone.is_empty(): help = hovered_bone+" · "+("Drag to rotate" if rotation_tool(hovered_bone) else "Drag to move / IK")+" · Esc cancels"
	draw_string(ThemeDB.fallback_font,Vector2(14,size.y-16),help,HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("a8c1d3"))

func _draw_skeleton(pose: Dictionary, frame: Transform3D, color: Color, editable: bool) -> void:
	for i in project.data.rig.names.size():
		var bone: String = project.data.rig.names[i]
		if not pose.joints.has(bone): continue
		var p = project_point(frame*pose.joints[bone]); var parent = int(project.data.rig.parents[i])
		var tint = color
		if not editable and pose.has("changes") and pose.changes.has(bone) and (pose.changes[bone].position_m>.02 or pose.changes[bone].rotation_rad>.1): tint = Color("ff805c")
		if parent>=0 and pose.joints.has(project.data.rig.names[parent]): draw_line(project_point(frame*pose.joints[project.data.rig.names[parent]]),p,tint,1.5,true)
		draw_circle(p,5 if editable and bone in selected else 2.5,Color.WHITE if editable and bone in selected else tint)
		if editable and bone in selected: draw_string(ThemeDB.fallback_font,p+Vector2(8,-8),bone,HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color.WHITE)

func ring(center: Vector3, axis: Vector3) -> PackedVector2Array:
	var tangent = axis.cross(Vector3.UP if absf(axis.y)<.9 else Vector3.RIGHT).normalized()*.18
	var points = PackedVector2Array()
	for i in 49: points.append(project_point(center+tangent.rotated(axis,TAU*i/48)))
	return points

func _gui_input(event: InputEvent) -> void:
	if project==null or poses.is_empty(): return
	if event is InputEventMouseButton:
		if event.button_index in [MOUSE_BUTTON_RIGHT,MOUSE_BUTTON_MIDDLE]:
			orbit_button = event.button_index if event.pressed else 0; accept_event(); return
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN] and event.pressed:
			distance = clampf(distance*(.9 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1.1),.4,14); update_camera(); accept_event(); return
		if event.button_index==MOUSE_BUTTON_LEFT:
			if not event.pressed:
				if not drag_mode.is_empty():
					drag_mode = ""
					if drag_started: pose_drag_finished.emit()
					drag_started = false
				accept_event(); return
			_begin_drag(event.position,event.shift_pressed); accept_event()
	elif event is InputEventMouseMotion:
		if orbit_button==MOUSE_BUTTON_RIGHT:
			yaw -= event.relative.x*.007; pitch = clampf(pitch-event.relative.y*.006,-1.4,1.4); update_camera()
		elif orbit_button==MOUSE_BUTTON_MIDDLE:
			focus += (-camera.basis.x*event.relative.x+camera.basis.y*event.relative.y)*distance*.0015; update_camera()
		elif not drag_mode.is_empty():
			if drag_started or event.position.distance_to(drag_start_mouse)>=4:
				drag_started = true; _drag(event.position)
		else:
			hovered_bone = pick_bone(event.position) if characters[1].visible else ""
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if not hovered_bone.is_empty() else Control.CURSOR_ARROW
			queue_redraw()
		accept_event()

func movable_bone(bone: String) -> bool:
	return bone=="Hips" or bone.ends_with("Hand") or bone.ends_with("Foot") or bone.ends_with("ForeArm") or bone in ["LeftLeg","RightLeg"]

func rotation_tool(bone: String) -> bool:
	return tool=="Rotate" or (tool=="Auto" and not movable_bone(bone))

func pick_bone(mouse: Vector2) -> String:
	var best = 16.0; var picked = ""
	for bone in poses[1].joints:
		var point = bone_point(bone)
		if camera.is_position_behind(point): continue
		var d = project_point(point).distance_to(mouse)
		if d<best: best = d; picked = bone
	# Terminal markers have no visible joint of their own. In the viewport
	# their tip is a handle for the parent (e.g. helmet tip -> Head), while
	# explicit hierarchy selection still exposes the unchanged source rig.
	if picked.to_lower().ends_with("_end"):
		var index: int = project.data.rig.names.find(picked)
		var parent: int = project.data.rig.parents[index]
		if parent>=0: return project.data.rig.names[parent]
	return picked

func endpoint_pins(pose: Dictionary) -> Dictionary:
	var result = pins.duplicate()
	if hold_feet and project.data.preview.context=="grounded":
		var world = project.fk(pose)
		for bone in ["LeftFoot","RightFoot"]:
			if not result.has(bone): result[bone] = world.joints[bone]
	return result

func fit_pins(pose: Dictionary, targets: Dictionary, before: Dictionary) -> Array:
	var changed: Array = []
	var original = project.fk(before)
	for endpoint in targets:
		changed.append_array(project.ik(pose,endpoint,targets[endpoint]))
		# IK changes the parent frame. Keep a pinned boot/glove's orientation too.
		var index: int = project.data.rig.names.find(endpoint)
		var parent: String = project.data.rig.names[int(project.data.rig.parents[index])]
		var posed = project.fk(pose)
		pose.q[index] = (posed.rotations[parent].inverse()*original.rotations[endpoint]).get_rotation_quaternion().normalized()
		changed.append(endpoint)
	return changed

func cancel_drag() -> bool:
	if drag_mode.is_empty(): return false
	drag_mode = ""; drag_started = false; drag_pose = {}
	pose_drag_cancelled.emit(); refresh(); return true

func _begin_drag(mouse: Vector2, extend: bool) -> void:
	if not characters[1].visible:
		edit_message.emit("This comparison is read-only. Choose Your edit to drag bones."); return
	var picked = pick_bone(mouse)
	if not picked.is_empty():
		bone_selected.emit(picked,extend)
		if extend: return
	var bone: String = selected[-1] if not selected.is_empty() else "Hips"
	var center = bone_point(bone)
	var best = 9.0; var axis_hit = -1
	for axis in 3:
		var direction = Vector3.ZERO; direction[axis] = 1
		var frame: Basis = Basis.IDENTITY if world_axes else characters[1].global_basis*poses[1].rotations[bone]
		direction = frame*direction
		var points = ring(center,direction) if rotation_tool(bone) else PackedVector2Array([project_point(center),project_point(center+direction*.22)])
		for i in range(1,points.size()):
			var d = mouse.distance_to(Geometry2D.get_closest_point_to_segment(mouse,points[i-1],points[i]))
			if d<best: best = d; axis_hit = axis; drag_axis = direction
	if not picked.is_empty():
		drag_mode = "free_rotate" if rotation_tool(bone) else "move"
	elif axis_hit>=0:
		drag_mode = "rotate" if rotation_tool(bone) else "axis"
	else:
		return
	if not rotation_tool(bone) and not movable_bone(bone):
		drag_mode = ""; edit_message.emit(bone+" rotates. Choose Auto or Rotate, then drag it."); return
	pose_drag_started.emit()
	center = bone_point(bone)
	drag_start_mouse = mouse; drag_origin = center; drag_point = unproject(mouse,center)
	drag_before = display_pose.duplicate(true); drag_pose = drag_before.duplicate(true); drag_bones = []
	drag_bone = bone; drag_started = false; drag_pins = endpoint_pins(drag_before)
	if drag_mode=="free_rotate": drag_axis = camera.global_basis.y

func _drag(mouse: Vector2) -> void:
	drag_pose = drag_before.duplicate(true)
	var bone = drag_bone; var index: int = project.data.rig.names.find(bone)
	var world = project.fk(drag_before)
	if drag_mode in ["rotate","free_rotate"]:
		var a = drag_start_mouse-project_point(drag_origin); var b = mouse-project_point(drag_origin)
		var angle = a.angle_to(b)
		var sign_value = 1.0 if drag_axis.dot(camera.global_basis.z)>0 else -1.0
		var parent: int = project.data.rig.parents[index]
		var parent_frame: Basis = world.rotations[project.data.rig.names[parent]] if parent>=0 else Basis.IDENTITY
		var model_axis: Vector3 = characters[1].global_basis.inverse()*drag_axis
		var delta_rotation = Basis(model_axis,angle*sign_value)
		if drag_mode=="free_rotate":
			var pixels = mouse-drag_start_mouse
			var model_camera: Basis = characters[1].global_basis.inverse()*camera.global_basis
			delta_rotation = Basis(model_camera.y,pixels.x*.008)*Basis(model_camera.x,pixels.y*.008)
		var rotation: Basis = delta_rotation*world.rotations[bone]
		drag_pose.q[index] = (parent_frame.inverse()*rotation).get_rotation_quaternion().normalized(); drag_bones = [bone]
	else:
		var delta = unproject(mouse,drag_origin)-drag_point
		if drag_mode=="axis": delta = drag_axis*delta.dot(drag_axis)
		delta = characters[1].global_basis.inverse()*delta
		if bone=="Hips":
			drag_pose.root += delta; drag_bones = [bone]
			drag_bones.append_array(fit_pins(drag_pose,drag_pins,drag_before))
		elif bone.ends_with("Hand") or bone.ends_with("Foot"):
			drag_bones = project.ik(drag_pose,bone,world.joints[bone]+delta)
		else:
			var endpoint = bone.replace("ForeArm","Hand") if bone.ends_with("ForeArm") else bone.trim_suffix("Leg")+"Foot"
			if world.joints.has(endpoint): drag_bones = project.ik(drag_pose,endpoint,world.joints[endpoint],world.joints[bone]+delta)
	pose_dragged.emit(drag_pose,drag_bones)

func pin_selected() -> void:
	var world = project.fk(display_pose)
	for bone in selected:
		if bone.ends_with("Hand") or bone.ends_with("Foot"):
			if pins.has(bone): pins.erase(bone)
			else: pins[bone] = world.joints[bone]
	queue_redraw()

func capture() -> Image:
	return view.get_texture().get_image()

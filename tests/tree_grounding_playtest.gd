extends SceneTree
## Native, unranked visual lab. Uses production meshes, terrain materials,
## instancing, root seating and contact-snow batching; no player save writes.
const Contacts = preload("res://scripts/presentation/asset_snow_contacts.gd")
const Quality = preload("res://scripts/presentation/graphics_quality.gd")
var stage: Node3D
var camera: Camera3D
var assets
var field
var contacts
var caps
var props: Array = []
var label: Label
var output = "res://artifacts/trees_v2/grounding"
var profile = Quality.preset(2)
var samples: Array[float] = []
var gpu: Array[float] = []
var cpu: Array[float] = []

func _initialize() -> void: call_deferred("run")

func run() -> void:
	if DisplayServer.get_name()=="headless": printerr("Native renderer required"); quit(2); return
	root.size = Vector2i(1920,1080); root.title = "Alpine Apex | Tree grounding"
	root.msaa_3d = Viewport.MSAA_4X; Engine.max_fps = 120
	DirAccess.make_dir_recursive_absolute(output)
	assets = preload("res://scripts/presentation/alpine_assets.gd").new(preload("res://scripts/presentation/cloud_lighting.gd").new(),profile)
	stage = Node3D.new(); root.add_child(stage)
	var env = WorldEnvironment.new(); env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR; env.environment.background_color = Color(.26,.37,.49)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(.68,.78,.88); env.environment.ambient_light_energy = .35
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC; env.environment.ssao_enabled = true
	stage.add_child(env)
	var sun = DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-38,-55,0)
	sun.light_energy = .85; sun.light_color = Color(1,.94,.86); sun.shadow_enabled = true; stage.add_child(sun)
	camera = Camera3D.new(); camera.fov = 48; camera.far = 150; stage.add_child(camera)
	var canvas = CanvasLayer.new(); stage.add_child(canvas)
	label = Label.new(); label.position = Vector2(30,22); label.add_theme_font_size_override("font_size",27)
	label.add_theme_color_override("font_shadow_color",Color.BLACK); label.add_theme_constant_override("shadow_offset_x",2); label.add_theme_constant_override("shadow_offset_y",2)
	canvas.add_child(label)
	field = preload("res://scripts/world/heightfield_surface.gd").new()
	field.X_MIN = -32; field.Z_MIN = -32; field.NX = 17; field.NZ = 17; field.heights.resize(289)
	caps = preload("res://scripts/presentation/powder_caps.gd").new(assets.lighting)
	for slope in [0,35]:
		var display = Node3D.new(); stage.add_child(display)
		for z in 17:
			for x in 17:
				var wx: float = field.X_MIN+x*4.0; var wz: float = field.Z_MIN+z*4.0
				field.heights[z*17+x] = -tan(deg_to_rad(slope))*wz + (.008*wx*wx+.006*wz*wz if slope==35 else 0.0)
		var arrays = []; arrays.resize(Mesh.ARRAY_MAX)
		var vertices = PackedVector3Array(); var normals = PackedVector3Array(); var indices = PackedInt32Array()
		for z in 17:
			for x in 17:
				vertices.append(field.vertex(x,z)); normals.append(field.contact_normal(field.X_MIN+x*4.0,field.Z_MIN+z*4.0))
		for z in 16:
			for x in 16:
				var i = z*17+x; indices.append_array(PackedInt32Array([i,i+1,i+17,i+1,i+18,i+17]))
		arrays[Mesh.ARRAY_VERTEX] = vertices; arrays[Mesh.ARRAY_NORMAL] = normals; arrays[Mesh.ARRAY_INDEX] = indices
		var ground = MeshInstance3D.new(); ground.mesh = ArrayMesh.new(); ground.mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		ground.material_override = assets.terrain_material(-.35); display.add_child(ground)
		contacts = Contacts.new(); display.add_child(contacts); props = []
		for spec in [["forest_dead_03",-4.0],["forest_birch_02",0.0],["pc_rock_boulder_1",4.0]]:
			var id: String = spec[0]; var tree = id.begins_with("forest_")
			var mesh: Mesh = assets.mesh(id+"_lod0" if tree else id)
			var scale_value: float = 10.5/float(assets.tree_record(id).height_m) if tree else 1.0
			var original = Transform3D(Basis(Vector3.UP,.7).scaled(Vector3.ONE*scale_value),Vector3(spec[1],field.sample(spec[1],0).height,0))
			var adjusted = original
			if tree:
				var foot = contacts.root_footprint(id,assets)
				adjusted = Contacts.seat_tree(field,original,foot)
				contacts.add_contact(field,original.origin,Vector2.ONE*Contacts.root_radius(foot,scale_value),.7,.4)
			else:
				original.origin.y -= caps.BURIAL; adjusted = original
				var box = mesh.get_aabb()
				contacts.add_contact(field,adjusted*box.get_center(),Vector2(box.size.x,box.size.z)*.46,.7,.4)
			var node = MultiMeshInstance3D.new(); node.multimesh = MultiMesh.new(); node.multimesh.transform_format = MultiMesh.TRANSFORM_3D
			node.multimesh.mesh = mesh; node.multimesh.instance_count = 1; node.multimesh.set_instance_transform(0,original)
			display.add_child(node); props.append({"node":node,"before":original,"after":adjusted})
			if not tree:
				var cap = MeshInstance3D.new(); cap.mesh = caps.mesh_for(id,mesh); cap.transform = original; display.add_child(cap)
		contacts.finish(ground.material_override,profile)
		for enabled in [false,true]:
			contacts.visible = enabled
			for prop in props: prop.node.multimesh.set_instance_transform(0,prop.after if enabled else prop.before)
			label.text = "ALPINE APEX  /  %d° snow slope  /  %s" % [slope,"Buried roots + contact snow" if enabled else "Original placement"]
			camera.position = Vector3(7,4.1,12); camera.look_at(Vector3(0,.85,0))
			await capture("slope_%02d_%s" % [slope,"after" if enabled else "before"])
			if slope==35:
				camera.position = Vector3(1.5,.8,4); camera.look_at(Vector3(0,.22,0))
				await capture("root_detail_%s" % ("after" if enabled else "before"))
				camera.position = Vector3(6,1.5,5); camera.look_at(Vector3(4,.25,0))
				await capture("rock_detail_%s" % ("after" if enabled else "before"))
		if slope==35:
			RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
			for frame in 30: await process_frame
			var last_frame = Time.get_ticks_usec()
			for frame in 240:
				await process_frame
				var now = Time.get_ticks_usec()
				samples.append((now-last_frame)/1000.0); last_frame = now
				gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
				cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()))
		display.free()
	var report = {"pixels":str(root.size),"device":RenderingServer.get_video_adapter_name(),"frame_ms":stats(samples),"gpu_ms":stats(gpu),"cpu_render_ms":stats(cpu),"video_memory_bytes":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED),"unranked_lab":true}
	FileAccess.open(output+"/native.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("TREE_GROUNDING_NATIVE ",JSON.stringify(report)); quit()

func capture(id: String) -> void:
	for frame in 30: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output+"/"+id+".png")
	print("TREE_GROUNDING_CAPTURE ",id)

func stats(values: Array[float]) -> Dictionary:
	values.sort(); var total = 0.0
	for value in values: total += value
	return {"mean":total/values.size(),"p95":values[floori((values.size()-1)*.95)],"p99":values[floori((values.size()-1)*.99)]}

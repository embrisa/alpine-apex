extends SceneTree
## Rephotograph frozen final bone/equipment transforms. No pose fitting or sim.
const Visual = preload("res://scripts/presentation/skier_visual.gd")
const Writer = preload("res://scripts/presentation/skier_pose_writer.gd")
const FullMotion = preload("res://scripts/presentation/skier_full_motion.gd")
var folder = ""
var details = false
var world_up = false
var scene: Node3D
var skier
var cameras: Array[Camera3D] = []
var sizes = Vector2i(2400,1000)
var verify_error = 0.0
var camera_size = 3.4
var detail_size = 1.35
func _initialize(): call_deferred("run")
func unpack_v(a: Array) -> Vector3: return Vector3(a[0],a[1],a[2])
func unpack_b(a: Array) -> Basis: return Basis(unpack_v(a[0]),unpack_v(a[1]),unpack_v(a[2]))
func unpack_t(d: Dictionary) -> Transform3D: return Transform3D(unpack_b(d.basis),unpack_v(d.origin))
func pack_v(v: Vector3) -> Array: return [v.x,v.y,v.z]
func pack_t(t: Transform3D) -> Dictionary: return {"origin":pack_v(t.origin),"basis":[pack_v(t.basis.x),pack_v(t.basis.y),pack_v(t.basis.z)]}
func read(path: String): return JSON.parse_string(FileAccess.get_file_as_string(path))

static func source_pose(pose: Dictionary) -> Dictionary:
	# Reconstruct source curves with the production sampler, without fitting.
	var motion = FullMotion.new()
	motion.current.assign(pose.q)
	motion.previous.assign(pose.q)
	motion.root_position = pose.root
	motion.previous_root = pose.root
	var result = motion.sample(1.0)
	var rest = preload("res://scripts/core/rider_body.gd").REST
	var height: float = preload("res://scripts/presentation/skier_equipment.gd").SOLE_ABOVE_SUPPORT+(rest.RightFoot.y+rest.LeftFoot.y)*.5
	for bone in result.joints: result.joints[bone] += Vector3.UP*height
	return result

func run():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--revision="): folder=arg.trim_prefix("--revision=")
		if arg=="--details": details=true
		if arg=="--world-up": world_up=true
		if arg.begins_with("--camera-size="): camera_size=arg.trim_prefix("--camera-size=").to_float()
		if arg.begins_with("--detail-size="): detail_size=arg.trim_prefix("--detail-size=").to_float()
	if camera_size<.5 or camera_size>10.0 or detail_size<.5 or detail_size>10.0:
		push_error("Camera sizes must be within 0.5 to 10 metres."); quit(2); return
	if folder.is_empty():
		push_error("Pass --revision= with an unsealed capture folder."); quit(2); return
	if details and "--diagnostic" in OS.get_cmdline_user_args():
		push_error("Render details and diagnostic source comparisons separately."); quit(2); return
	if FileAccess.file_exists(folder+"/sealed.json"):
		push_error("Review revision is sealed. Rephotograph into a new revision to preserve earlier evidence.")
		quit(2); return
	if DisplayServer.get_name()=="headless": quit(2); return
	root.size=sizes; root.title="Alpine Apex | Frozen pose evidence"
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size=Vector2i.ZERO; root.content_scale_factor=1.0
	Engine.max_fps=120
	scene=Node3D.new(); root.add_child(scene)
	var env=WorldEnvironment.new(); env.environment=Environment.new()
	env.environment.background_mode=Environment.BG_COLOR; env.environment.background_color=Color("a1a4aa")
	env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color=Color("eef2ff"); env.environment.ambient_light_energy=.85; scene.add_child(env)
	for spec in [[Vector3(-40,-30,0),1.5],[Vector3(-25,145,0),.65]]:
		var light=DirectionalLight3D.new(); light.rotation_degrees=spec[0]; light.light_energy=spec[1]; scene.add_child(light)
	skier=Visual.new(); skier.preview_only=true; scene.add_child(skier)
	for i in 3:
		var box=SubViewportContainer.new(); root.add_child(box); box.position=Vector2(i*800,0); box.size=Vector2(800,1000)
		var view=SubViewport.new(); view.size=Vector2i(800,1000); view.world_3d=root.world_3d; view.msaa_3d=Viewport.MSAA_4X; box.add_child(view)
		var camera=Camera3D.new(); view.add_child(camera); camera.current=true; camera.near=.03; camera.far=50
		camera.projection=Camera3D.PROJECTION_ORTHOGONAL; camera.size=3.4; cameras.append(camera)
	await process_frame
	var manifest=read(folder+"/capture/manifest.json")
	assert(manifest.stable_sources and manifest.failures.is_empty(),"Render requires stable, successful capture")
	assert(FileAccess.get_sha256("res://assets/graphics/models/skier_v7.glb")==manifest.sources["res://assets/graphics/models/skier_v7.glb"],"Rig changed since capture; rephotograph with the frozen rig")
	for resource in manifest.sources:
		if resource.begins_with("res://assets/graphics/models/") and resource.ends_with(".glb"):
			assert(FileAccess.get_sha256(resource)==manifest.sources[resource],"Captured rig/equipment changed: "+resource)
	var meta={"version":1,"source_capture":"capture/manifest.json","renderer_sha256":FileAccess.get_sha256("res://tests/pose_reference_render.gd"),"pixels":[2400,1000],"panel_pixels":[800,1000],"views":["Reference angle","Front","Side"],"camera_policy":"Fixed initial terrain normal, yaw follows rider. Removes initial slope from camera only; preserves body bank, ski edges, changing terrain pitch and flight pitch. Frames and bones are unchanged.","scenarios":{}}
	if details:
		meta.views=["Oblique detail","Overhead","Side detail"]
		meta.camera_policy += " Detail focus follows captured pelvis; scale stays fixed at %.2f m."%detail_size
	if world_up: meta.camera_policy = "World up; yaw follows rider. Preserves apparent slope/turn bank without subtracting terrain tilt."
	var selected={}
	if FileAccess.file_exists(folder+"/selection.json"): selected=read(folder+"/selection.json")
	var diagnostic="--diagnostic" in OS.get_cmdline_user_args()
	var selected_only="--selected" in OS.get_cmdline_user_args()
	meta.partial = selected_only
	for item in manifest.scenarios:
		var data=read(folder+"/capture/"+item.name+".json")
		var normal=unpack_b(data.frames[0].root.basis).y.normalized()
		if world_up: normal=Vector3.UP
		var frames=data.frames
		if diagnostic or selected_only:
			var ids: Array=selected.get(item.name,[]).map(func(value): return int(value))
			frames=data.frames.filter(func(row): return int(row.frame) in ids)
			assert(not frames.is_empty() and frames.size()==ids.size(),"Missing selected diagnostic frames")
		var destination=folder+("/diagnosis/" if diagnostic else ("/details/" if details else "/frames/"))+item.name
		DirAccess.make_dir_recursive_absolute(destination)
		var camera_data=[]
		for row in frames:
			restore(row)
			position_cameras(row,normal,item.name)
			if diagnostic:
				await screenshot(destination+"/%04d_final.jpg"%row.frame)
				var wanted={}; var rotations={}
				for bone in row.requested: wanted[bone]=unpack_v(row.requested[bone])
				for bone in row.requested_rotations: rotations[bone]=unpack_b(row.requested_rotations[bone])
				skier.present_authored(wanted,rotations)
				await screenshot(destination+"/%04d_requested.jpg"%row.frame)
				var full=skier.animation.full_motion; var dominant=""; var highest=-1.0
				for name in row.clips:
					if row.clips[name].weight>highest: dominant=name; highest=row.clips[name].weight
				var entry=row.clips[dominant]; var pose=full.sample_clip(dominant,entry.time,entry.loop)
				if entry.mirror: pose=full.mirror_pose(pose)
				var source=source_pose(pose)
				skier.present_authored(source.joints,source.rotations)
				await screenshot(destination+"/%04d_source.jpg"%row.frame)
			else:
				await screenshot(destination+"/%04d.jpg"%row.frame)
				var specs=[]
				for camera in cameras: specs.append({"transform":pack_t(camera.global_transform),"size":camera.size})
				camera_data.append({"frame":row.frame,"cameras":specs})
		meta.scenarios[item.name]=camera_data
		print("POSE_REVIEW_RENDERED ",item.name," frames=",frames.size()," diagnostic=",diagnostic)
	meta.max_restored_bone_error_m=verify_error
	FileAccess.open(folder+("/diagnosis.json" if diagnostic else ("/details.json" if details else "/render.json")),FileAccess.WRITE).store_string(JSON.stringify(meta,"\t"))
	print("POSE_REVIEW_RENDER_COMPLETE max_bone_error=",verify_error)
	scene.queue_free(); await process_frame; quit(0 if verify_error<.00001 else 1)

func restore(row: Dictionary):
	skier.global_transform=unpack_t(row.root)
	var targets={}
	for i in row.final_bones.size(): targets[i]=unpack_t(row.final_bones[i])
	Writer.apply(skier.skeleton,skier.rest,skier.desired,targets)
	for i in 2:
		skier.skis[i].global_transform=unpack_t(row.skis[i]); skier.poles[i].global_transform=unpack_t(row.poles[i])
	for i in row.final_bones.size():
		verify_error=maxf(verify_error,skier.skeleton.get_bone_global_pose(i).origin.distance_to(targets[i].origin))

func position_cameras(row: Dictionary,normal: Vector3,name: String):
	var root_pose=unpack_t(row.root)
	var forward=root_pose.basis.z.slide(normal).normalized()
	var frame=Basis(normal.cross(forward).normalized(),normal,forward)
	var focus=root_pose.origin+frame*Vector3(0,.80,0)
	var directions=[Vector3(-4.5,1.1,2.5) if not name.begins_with("carve") else Vector3(-1.0,1.1,5),Vector3(0,.3,5),Vector3(-5,.25,0)]
	if details:
		focus=root_pose*unpack_v(row.joints.Hips)+frame*Vector3(0,.13,.18)
		directions=[Vector3(-4.5,1.1,2.5),Vector3(0,5,.3),Vector3(-5,.25,0)]
	for i in 3:
		cameras[i].position=focus+frame*directions[i]; cameras[i].look_at(focus,normal)
		# Use a fixed scale for a sequence; do not frame-match individual limbs.
		cameras[i].size=detail_size if details else camera_size

func screenshot(path: String):
	await process_frame; await RenderingServer.frame_post_draw
	var picture=root.get_texture().get_image(); assert(picture.get_size()==sizes)
	picture.save_jpg(path,.95)

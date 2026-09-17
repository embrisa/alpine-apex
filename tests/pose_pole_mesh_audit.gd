extends SceneTree
## Shaft-radius checks against the actual skinned mesh in frozen review poses.
const Visual = preload("res://scripts/presentation/skier_visual.gd")
const Writer = preload("res://scripts/presentation/skier_pose_writer.gd")
var folder = ""
var scenarios = ["regular","tuck","prepare_takeoff"]
func v(a): return Vector3(a[0],a[1],a[2])
func b(a): return Basis(v(a[0]),v(a[1]),v(a[2]))
func t(a): return Transform3D(b(a.basis),v(a.origin))
func _initialize(): call_deferred("run")
func run():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--revision="): folder=arg.trim_prefix("--revision=")
		if arg.begins_with("--scenarios="): scenarios=Array(arg.trim_prefix("--scenarios=").split(","))
	if folder.is_empty():
		push_error("Pass --revision= with an unsealed capture folder."); quit(2); return
	if FileAccess.file_exists(folder+"/sealed.json"):
		push_error("Audit into an unsealed revision; preserve earlier evidence.")
		quit(2); return
	var manifest=JSON.parse_string(FileAccess.get_file_as_string(folder+"/capture/manifest.json"))
	assert(manifest.stable_sources and manifest.failures.is_empty(),"Audit requires a stable production capture")
	var rig_path = "res://assets/graphics/models/skier_v7.glb"
	if manifest.get("source_verification","")=="metadata":
		var metadata = {"size":FileAccess.open(rig_path,FileAccess.READ).get_length(),"modified":FileAccess.get_modified_time(rig_path)}
		var captured: Dictionary = manifest.sources[rig_path]
		assert(metadata.size==int(captured.size) and metadata.modified==int(captured.modified),"Use the captured rig for mesh clearance")
	else:
		assert(FileAccess.get_sha256(rig_path)==manifest.sources[rig_path],"Use the captured rig for mesh clearance")
	var selected = "--selected" in OS.get_cmdline_user_args()
	var include_flight = "--include-flight" in OS.get_cmdline_user_args()
	var selection=JSON.parse_string(FileAccess.get_file_as_string(folder+"/selection.json")) if selected else {}
	var skier = Visual.new(); skier.preview_only=true; root.add_child(skier); await process_frame
	var meshes=[]
	for node in skier.find_children("*","MeshInstance3D",true,false):
		if node.skin!=null: meshes.append(node)
	assert(not meshes.is_empty(),"Audit requires the actual skinned clothing mesh")
	var results=[]; var count=0
	for scenario in scenarios:
		var rows=JSON.parse_string(FileAccess.get_file_as_string(folder+"/capture/"+scenario+".json")).frames
		var selected_frames: Array=selection.get(scenario,[]).map(func(value): return int(value))
		var previous_count=count
		var before_departure=true
		for row in rows:
			# Preparation ends at actual support loss, independent of capture FPS
			# or a particular fixture's frame number. Other scenarios audit in full.
			before_departure=before_departure and row.grounded
			if scenario=="prepare_takeoff" and not before_departure and not include_flight: continue
			if selected and not int(row.frame) in selected_frames: continue
			var poses={}
			for i in row.final_bones.size(): poses[i]=t(row.final_bones[i])
			Writer.apply(skier.skeleton,skier.rest,skier.desired,poses)
			var root_pose=t(row.root); var poles=[]
			for pole in row.poles:
				var transform=root_pose.affine_inverse()*t(pole)
				poles.append(transform)
			var hits=[]
			for mesh in meshes:
				var skin=mesh.skin; var matrices=[]
				for bind in skin.get_bind_count():
					var bone=skin.get_bind_bone(bind)
					if bone<0: bone=skier.skeleton.find_bone(skin.get_bind_name(bind))
					matrices.append(skier.skeleton.get_bone_global_pose(bone)*skin.get_bind_pose(bind))
				for surface in mesh.mesh.get_surface_count():
					var a=mesh.mesh.surface_get_arrays(surface)
					assert(a[Mesh.ARRAY_BONES].size()==4*a[Mesh.ARRAY_VERTEX].size(),"Audit must include every skin influence")
					var material=mesh.mesh.surface_get_material(surface).resource_name
					var points=PackedVector3Array(); points.resize(a[Mesh.ARRAY_VERTEX].size())
					for i in points.size():
						var p=Vector3.ZERO
						for k in 4: p+=matrices[a[Mesh.ARRAY_BONES][i*4+k]]*a[Mesh.ARRAY_VERTEX][i]*a[Mesh.ARRAY_WEIGHTS][i*4+k]
						points[i]=p
					var ids=a[Mesh.ARRAY_INDEX]; var faces=PackedVector3Array(); faces.resize(ids.size())
					for i in ids.size(): faces[i]=points[ids[i]]
					var arrays=[]; arrays.resize(Mesh.ARRAY_MAX); arrays[Mesh.ARRAY_VERTEX]=faces
					var deformed=ArrayMesh.new(); deformed.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
					var triangles=deformed.generate_triangle_mesh()
					for side in 2:
						var pole: Transform3D=poles[side]
						# Grip contact is intentional; inspect the shaft starting 10 cm
						# below the handle, with four rays at its 6 mm radius.
						for offset in [Vector3.ZERO,pole.basis.x*.006,-pole.basis.x*.006,pole.basis.z*.006,-pole.basis.z*.006]:
							var start: Vector3=pole.origin-pole.basis.y*.10+offset
							var hit=triangles.intersect_segment(start,pole.origin-pole.basis.y*1.18+offset)
							if not hit.is_empty():
								hits.append({"side":side,"material":material,"distance_from_grip_m":hit.position.distance_to(start)+.10,"position":[hit.position.x,hit.position.y,hit.position.z]})
			count+=1
			if not hits.is_empty(): results.append({"scenario":scenario,"frame":row.frame,"hits":hits})
		assert(count>previous_count,"Each requested scenario must contain inspected frames")
		print("POLE_MESH_AUDIT ",scenario," inspected=",count," intersecting_frames=",results.size())
	var report={"frames":count,"shaft_radius_m":.006,"handle_exclusion_m":.10,"selected_only":selected,"include_flight":include_flight,"scenarios":scenarios,"intersections":results,"passed":results.is_empty()}
	preload("res://tests/test_report.gd").write(folder+"/pole-mesh-audit.json",JSON.stringify(report,"\t"))
	skier.queue_free(); await process_frame; quit(0 if results.is_empty() else 1)

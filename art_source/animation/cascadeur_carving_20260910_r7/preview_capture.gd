extends SceneTree
const FOLDER = "res://art_source/animation/cascadeur_carving_20260910_r7/"
const REV = "res://artifacts/pose_review/revisions/cascadeur-20260910-r7-source/"
const Visual = preload("res://scripts/presentation/skier_visual.gd")
func _initialize(): call_deferred("run")
func vec(a): return Vector3(a[0],a[1],a[2])
func pack_v(v): return [v.x,v.y,v.z]
func pack_b(b): return [pack_v(b.x),pack_v(b.y),pack_v(b.z)]
func pack_t(t): return {"origin":pack_v(t.origin),"basis":pack_b(t.basis)}
func matrix(a):
	return Transform3D(Basis(Vector3(a[0][0],a[1][0],a[2][0]),Vector3(a[0][1],a[1][1],a[2][1]),Vector3(a[0][2],a[1][2],a[2][2])),Vector3(a[0][3],a[1][3],a[2][3]))
func write(path,data): FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(data,"\t"))
func run():
	assert(not FileAccess.file_exists(REV+"capture/manifest.json"),"Preserve previous capture")
	DirAccess.make_dir_recursive_absolute(REV+"capture")
	var paths=[FOLDER+"carving_r7_animation.glb",FOLDER+"baked_animation_audit.json",FOLDER+"preview_capture.gd"]
	for file in DirAccess.get_files_at("res://scripts/presentation"):
		if file.ends_with(".gd"): paths.append("res://scripts/presentation/"+file)
	for name in ["skier_v7","ski_detailed_v1","ski_detailed_v1_left","binding_detailed_v2","skier_v7_boot_right","skier_v7_boot_left","pole_detailed_v1"]:
		paths.append("res://assets/graphics/models/"+name+".glb")
	var sources={}
	for path in paths: sources[path]=FileAccess.get_sha256(path)
	var document=GLTFDocument.new(); var state=GLTFState.new()
	assert(document.append_from_file(FOLDER+"carving_r7_animation.glb",state)==OK)
	var imported=document.generate_scene(state);root.add_child(imported)
	var skeletons=imported.find_children("*","Skeleton3D",true,false)
	assert(skeletons.size()==1 and skeletons[0].get_bone_count()==24)
	assert(imported.find_children("*","MeshInstance3D",true,false).is_empty())
	var skeleton:Skeleton3D=skeletons[0]
	var players=imported.find_children("*","AnimationPlayer",true,false);assert(players.size()==1)
	var player:AnimationPlayer=players[0]
	var animation_name=""
	for n in player.get_animation_list():
		if n!="RESET":animation_name=n
	assert(not animation_name.is_empty());player.play(animation_name)
	var visual=Visual.new();visual.preview_only=true;root.add_child(visual)
	await process_frame
	var data=JSON.parse_string(FileAccess.get_file_as_string(FOLDER+"baked_animation_audit.json"))
	var rows=[];var max_import=0.;var max_writer=0.;var max_scale=0.;var max_import_basis=0.;var max_writer_basis=0.;var rig=[]
	for i in visual.skeleton.get_bone_count():
		var name=visual.skeleton.get_bone_name(i);var p=visual.skeleton.get_bone_parent(i)
		var other=skeleton.find_bone(name);assert(other>=0)
		var op=skeleton.get_bone_parent(other)
		assert((skeleton.get_bone_name(op) if op>=0 else "")== (visual.skeleton.get_bone_name(p) if p>=0 else ""))
		rig.append({"name":name,"parent":p,"rest":pack_t(visual.rest[i])})
	for frame in data.world_frames.size():
		player.seek(frame/30.,true);skeleton.force_update_all_bone_transforms()
		var joints={};var rotations={};var raw=data.world_frames[frame]
		for name in data.joints:
			var pose=matrix(raw[name]);var id=visual.bone_ids[name]
			joints[name]=pose.origin
			rotations[name]=pose.basis.orthonormalized()*visual.rest[id].basis.orthonormalized().inverse()
			max_import=maxf(max_import,pose.origin.distance_to(skeleton.get_bone_global_pose(skeleton.find_bone(name)).origin))
			max_import_basis=maxf(max_import_basis,(pose.basis.orthonormalized().x-skeleton.get_bone_global_pose(skeleton.find_bone(name)).basis.orthonormalized().x).length())
			max_import_basis=maxf(max_import_basis,(pose.basis.orthonormalized().y-skeleton.get_bone_global_pose(skeleton.find_bone(name)).basis.orthonormalized().y).length())
			max_import_basis=maxf(max_import_basis,(pose.basis.orthonormalized().z-skeleton.get_bone_global_pose(skeleton.find_bone(name)).basis.orthonormalized().z).length())
			max_scale=maxf(max_scale,(pose.basis.get_scale()-Vector3.ONE).length())
		visual.present_authored(joints,rotations)
		visual.skeleton.force_update_all_bone_transforms()
		var bones=[];var pj={};var pr={};var skis=[];var poles=[]
		for i in visual.skeleton.get_bone_count():
			var name=visual.skeleton.get_bone_name(i);var actual=visual.skeleton.get_bone_global_pose(i)
			var source_basis=matrix(raw[name]).basis.orthonormalized()
			max_writer_basis=maxf(max_writer_basis,(actual.basis.x-source_basis.x).length())
			max_writer_basis=maxf(max_writer_basis,(actual.basis.y-source_basis.y).length())
			max_writer_basis=maxf(max_writer_basis,(actual.basis.z-source_basis.z).length())
			bones.append(pack_t(actual));max_writer=maxf(max_writer,actual.origin.distance_to(joints[name]))
		for name in joints:pj[name]=pack_v(joints[name]);pr[name]=pack_b(rotations[name])
		for ski in visual.skis:skis.append(pack_t(ski.global_transform))
		for pole in visual.poles:poles.append(pack_t(pole.global_transform))
		rows.append({"frame":frame,"tick":frame*4,"time":frame/30.,"grounded":true,"root":pack_t(Transform3D.IDENTITY),"joints":pj,"rotations":pr,"final_bones":bones,"skis":skis,"poles":poles})
	var after={}
	for path in paths:after[path]=FileAccess.get_sha256(path)
	var report={"scope":"Isolated authored preview using present_authored and the shared final writer. No simulation or gameplay fitting.","max_import_position_error_m":max_import,"max_writer_position_error_m":max_writer,"max_source_scale_vector_error":max_scale,"max_import_basis_axis_error":max_import_basis,"max_writer_basis_axis_error":max_writer_basis,"frames":rows.size(),"bones":24,"animation":animation_name,"engine":Engine.get_version_info(),"engine_path":OS.get_executable_path(),"engine_sha256":FileAccess.get_sha256(OS.get_executable_path())}
	var passed=max_import<.00002 and max_writer<.00002 and max_scale<.0001 and max_import_basis<.0001 and max_writer_basis<.0001 and sources==after
	write(FOLDER+"godot_preview_audit.json",report)
	write(REV+"capture/cascadeur_carving.json",{"scope":report.scope,"rig":rig,"frames":rows})
	write(REV+"capture/manifest.json",{"version":1,"capture_fps":30,"preview_only":true,"scope":report.scope,"tick_policy":"Authored frame index times four for review tooling; no physics ticks were executed.","stable_sources":sources==after,"sources":sources,"sources_after":after,"failures":[] if passed else ["Import/writer/scale failed"],"scenarios":[{"name":"cascadeur_carving","frames":rows.size()}],"engine":report.engine,"engine_sha256":report.engine_sha256})
	write(REV+"selection.json",{"cascadeur_carving":[0,8,15,22,30,38,45,52,60]})
	write(REV+"selection_reasons.json",{"0":"Neutral","15":"Authored right","30":"Neutral reversal","45":"Authored left","60":"Neutral exit"})
	print("CASCADEUR_PREVIEW_CAPTURE ","PASS" if passed else "FAIL"," ",JSON.stringify(report))
	visual.free();imported.free();quit(0 if passed else 1)

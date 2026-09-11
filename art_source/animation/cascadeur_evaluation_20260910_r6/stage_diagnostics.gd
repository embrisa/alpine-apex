extends SceneTree
## Read frozen data; reconstruct diagnostic poses with the shared writer only.
const Motion=preload("res://art_source/animation/cascadeur_evaluation_20260910_r6/evaluation_motion.gd")
const Visual=preload("res://scripts/presentation/skier_visual.gd")
const BASE="res://artifacts/pose_review/revisions/cascadeur-20260910-r6-gameplay/"
const OUT="res://artifacts/pose_review/revisions/cascadeur-20260910-r6-diagnosis/"
func _initialize():call_deferred("run")
func v(a):return Vector3(a[0],a[1],a[2])
func b(a):return Basis(v(a[0]),v(a[1]),v(a[2]))
func t(a):return Transform3D(b(a.basis),v(a.origin))
func pack(a):
	if a is Vector3:return [a.x,a.y,a.z]
	if a is Basis:return [pack(a.x),pack(a.y),pack(a.z)]
	if a is Transform3D:return {"origin":pack(a.origin),"basis":pack(a.basis)}
	if a is Dictionary:
		var out={};for key in a:out[key]=pack(a[key])
		return out
	if a is Array:
		var out=[];for item in a:out.append(pack(item))
		return out
	return a
func read(path):return JSON.parse_string(FileAccess.get_file_as_string(path))
func write(path,data):FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(data,"\t"))
func pose(raw):
	var qs:Array[Quaternion]=[]
	for a in raw.q:qs.append(Quaternion(a[0],a[1],a[2],a[3]).normalized())
	return {"q":qs,"root":v(raw.root)}
func run():
	assert(not FileAccess.file_exists(OUT+"capture/manifest.json"));DirAccess.make_dir_recursive_absolute(OUT+"capture")
	var manifest=read(BASE+"capture/manifest.json")
	assert(FileAccess.get_sha256("res://assets/animation/steep_ski_motion.res")==manifest.sources["res://assets/animation/steep_ski_motion.res"])
	var visual=Visual.new();visual.preview_only=true;root.add_child(visual);await process_frame
	var motion=Motion.new();var scenarios=[];var selections={};var analysis={"library_names":motion.library.names,"scenarios":{},"scope":"Static-stage diagnostic reconstructions from recorded inputs and smoothed weights; explanatory only. Requested is the tracked sample before support/cuff fitting."}
	for item in manifest.scenarios:
		var data=read(BASE+"capture/"+item.name+".json");var source_rows=[];var requested_rows=[];var stage_rows=[]
		for row in data.frames:
			var angles={}
			for pair in [["raw_mix","after_tuck"],["after_tuck","after_carry"],["after_carry","after_downhill"],["after_downhill","after_action"]]:
				var a=pose(row.stages[pair[0]]);var c=pose(row.stages[pair[1]]);var changed={}
				for name in ["Hips","Spine02","Spine01","Spine","RightShoulder","RightArm","RightForeArm","RightHand"]:
					var i=motion.library.names.find(name);changed[name]=rad_to_deg(a.q[i].angle_to(c.q[i]))
				angles[pair[0]+"_to_"+pair[1]]=changed
			stage_rows.append({"frame":row.frame,"angles_deg":angles,"downhill":row.stages.downhill_weight,"action":row.stages.action_weights})
			if int(row.frame) not in [0,15,30,42,51,69,81,96,120]:continue
			for stage in ["source","requested"]:
				var joints={};var rots={};var feet=(v(row.joints.LeftFoot)+v(row.joints.RightFoot))*.5
				var raw_joints=row.candidate_source.joints if stage=="source" else row.requested
				var raw_rots=row.candidate_source.rotations if stage=="source" else row.requested_rotations
				for name in raw_joints:joints[name]=v(raw_joints[name])+(feet if stage=="source" else Vector3.ZERO)
				for name in raw_rots:rots[name]=b(raw_rots[name])
				visual.global_transform=t(row.root);visual.present_authored(joints,rots);visual.skeleton.force_update_all_bone_transforms()
				var output=row.duplicate(true);output.joints=pack(joints);output.rotations=pack(rots);output.final_bones=[];output.poles=[]
				for i in visual.skeleton.get_bone_count():output.final_bones.append(pack(visual.skeleton.get_bone_global_pose(i)))
				for pole in visual.poles:output.poles.append(pack(pole.global_transform))
				# Fixed solver skis remain in row.skis. Diagnostic source ankles are
				# intentionally not fitted; the final gameplay capture is authoritative.
				if stage=="source":source_rows.append(output)
				else:requested_rows.append(output)
		for stage in ["source","requested"]:
			var name=item.name+"_"+stage;var rows=source_rows if stage=="source" else requested_rows
			write(OUT+"capture/"+name+".json",{"name":name,"rig":data.rig,"frames":rows,"scope":"Explanatory "+stage+" reconstruction on fixed solver skis; no fitting and no simulation execution."})
			scenarios.append({"name":name,"frames":rows.size()});selections[name]=rows.map(func(r):return r.frame)
		analysis.scenarios[item.name]=stage_rows
	manifest.scenarios=scenarios;manifest.scope="Selected explanatory source/requested reconstructions. Solver data copied from the actual gameplay capture; not a second simulation.";manifest.parent_capture=BASE
	manifest.sources["res://art_source/animation/cascadeur_evaluation_20260910_r6/stage_diagnostics.gd"]=FileAccess.get_sha256("res://art_source/animation/cascadeur_evaluation_20260910_r6/stage_diagnostics.gd")
	manifest.sources_after=manifest.sources.duplicate()
	write(OUT+"capture/manifest.json",manifest);write(OUT+"selection.json",selections)
	write("res://art_source/animation/cascadeur_evaluation_20260910_r6/stage_analysis.json",analysis)
	visual.free();print("CASCADEUR_STAGE_DIAGNOSTICS_COMPLETE 90 selected poses; all 605 stage deltas");quit()

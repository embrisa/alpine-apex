extends SceneTree
const Project = preload("res://scripts/workshop/motion_project.gd")
const Exporter = preload("res://scripts/workshop/motion_export.gd")
const Motion = preload("res://scripts/presentation/skier_full_motion.gd")
var checks = 0
var failures: Array = []
const OUTPUT = "res://artifacts/animation_workshop"
func _initialize() -> void: call_deferred("run")
func check(value: bool, text: String) -> void:
	checks += 1
	if not value: failures.append(text); printerr("FAIL: ",text)
func distance(a: Dictionary, b: Dictionary) -> float:
	var result: float = a.root.distance_to(b.root)
	for i in a.q.size(): result = maxf(result,q_error(a.q[i],b.q[i]))
	return result
func q_error(a: Quaternion, b: Quaternion) -> float:
	var delta = (a.inverse()*b).normalized()
	return 2*atan2(Vector3(delta.x,delta.y,delta.z).length(),absf(delta.w))
func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	var project = Project.new(); var sampler = Motion.new()
	var max_error = 0.0
	for name_value in Project.LIBRARY.data.clips:
		var id = project.add_variant(name_value)
		var duration: float = project.variant(id).duration
		var times: Array = [duration*.357,duration]
		for frame in roundi(duration*60)+1: times.append(frame/60.0)
		for at in times:
			max_error = maxf(max_error,distance(project.evaluate(id,at),sampler.sample_raw(Project.LIBRARY.data.clips[name_value],at)))
	check(project.data.variants.size()==33,"All 33 clips can be opened")
	check(max_error<.0001,"Source playback matches production sampler including fractional frames and endpoints")
	var id: String = project.data.variants[0].id
	var original = project.evaluate(id,.5)
	var pose = original.duplicate(true)
	var index: int = project.data.rig.names.find("Head")
	pose.q[index] = pose.q[index]*Quaternion(Vector3.UP,.3)
	var before = project.data.duplicate(true)
	var region_id: String = project.correct_pose(id,.5,pose,["Head"])
	project.commit("Test pose",before)
	check(distance(project.evaluate(id,.5),pose)<.0001,"Correction reaches intended central pose")
	for t in [.1,.35,.65,.9]: check(distance(project.evaluate(id,t),project.evaluate(id,t,false))<.0001,"Correction zero outside influence at "+str(t))
	check(project.evaluate(id,.45).q[index].angle_to(project.evaluate(id,.45,false).q[index])>.01,"Correction interpolates into surrounding frames")
	project.history.undo(); check(project.variant(id).regions.is_empty(),"One undo reverses an entire pose operation")
	project.history.redo(); check(project.variant(id).regions.size()==1,"Redo restores full correction")
	var second = project.evaluate(id,.5); second.q[index] *= Quaternion(Vector3.RIGHT,.2)
	project.correct_pose(id,.5,second,["Head"])
	check(distance(project.evaluate(id,.5),second)<.0001,"Overlapping local corrections compose in creation order")
	project.variant(id).regions[0].muted = true
	check(distance(project.evaluate(id,.5),second)>.1,"Muting a correction removes its effect")
	project.variant(id).regions[0].muted = false
	var bounded = project.variant(id).regions[0].duplicate(true)
	project.resize_region(bounded,.6,.4,project.variant(id).duration)
	check(bounded.start<.5 and bounded.end>.5,"Influence boundaries cannot cross an authored centre key")
	for track in bounded.tracks.Head:
		for k in range(1,track.size()): check(track[k].t>track[k-1].t,"Resized influence keys retain unique increasing times")
	var keys_variant: String = project.duplicate_variant(id,"Explicit key test")
	project.variant(keys_variant).regions.clear()
	var key_pose = project.evaluate(keys_variant,.2); key_pose.q[index] *= Quaternion(Vector3.UP,.2)
	project.correct_pose(keys_variant,.2,key_pose,["Head"],false)
	var later_pose = project.evaluate(keys_variant,.8); later_pose.q[index] *= Quaternion(Vector3.UP,.3)
	project.correct_pose(keys_variant,.8,later_pose,["Head"],false)
	check(project.variant(keys_variant).regions.size()==1,"Explicit poses add keys to a single correction track")
	check(distance(project.evaluate(keys_variant,.2),key_pose)<.0001 and distance(project.evaluate(keys_variant,.8),later_pose)<.0001,"Explicit key poses preserve earlier keys")
	var length_before = project.variant(keys_variant).duration
	project.retime(keys_variant,.2,.8,.1,.7)
	check(Project.validate(project.data).is_empty(),"Moving a range earlier retains a valid monotonic timeline")
	check(absf(project.variant(keys_variant).duration-(length_before-.1))<.00001,"Range movement ripples tail predictably")
	project.history.undo()
	var points = [Project.key(0,0),Project.key(1,1)]
	check(absf(Project.curve(points,.5)-.5)<.00001,"Cubic curve interpolation")
	points[0].mode = "constant"; check(Project.curve(points,.5)==0,"Constant interpolation")
	check(Project.curve(points,1)==1,"Constant interpolation switches exactly at the next key")
	points[0].mode = "linear"; check(absf(Project.curve(points,.25)-.25)<.00001,"Linear interpolation")
	points[0].mode = "cubic"; points[0].out = 2.0
	check(Project.curve(points,.25)>.25,"Tangent changes affect interpolated curve")
	var old_curve = points.duplicate(true)
	Project.split_curve(points,.4)
	var split_error = 0.0
	for frame in 61: split_error = maxf(split_error,absf(Project.curve(points,frame/60.0)-Project.curve(old_curve,frame/60.0)))
	check(split_error<.00001,"Retiming splits cubic curves without changing their shape")
	var prior_angles = Vector3(deg_to_rad(89),.2,.3)
	var next_q = Basis.from_euler(Vector3(deg_to_rad(91),.2,.3),EULER_ORDER_YXZ).get_rotation_quaternion()
	var continuous = Project.continuous_angles(next_q,prior_angles)
	check(continuous.distance_to(prior_angles)<.04,"YXZ channels stay continuous through the alternate Euler branch")
	check(q_error(Basis.from_euler(continuous,EULER_ORDER_YXZ).get_rotation_quaternion(),next_q)<.0001,"Continuous YXZ preserves quaternion orientation")
	check(distance(project.mirror(project.mirror(original)),original)<.0001,"Double mirror preserves original pose")
	for endpoint in ["RightHand","LeftHand","RightFoot","LeftFoot"]:
		var ik_pose = project.evaluate(id,.5)
		var fk = project.fk(ik_pose); var target: Vector3 = fk.joints[endpoint]+Vector3(.03,-.02,.04)
		project.ik(ik_pose,endpoint,target)
		var after = project.fk(ik_pose)
		check(after.joints[endpoint].distance_to(target)<.001,"IK reaches nearby "+endpoint)
		for i in project.data.rig.names.size():
			var parent = int(project.data.rig.parents[i])
			if parent<0: continue
			var bone: String = project.data.rig.names[i]; var p: String = project.data.rig.names[parent]
			var length = Project.v3(project.data.rig.rest[i][0]).distance_to(Project.v3(project.data.rig.rest[parent][0]))
			check(absf(after.joints[bone].distance_to(after.joints[p])-length)<.00001,"IK preserves link "+bone)
		project.ik(ik_pose,endpoint,Vector3(100,100,100))
		check(ik_pose.root.is_finite(),"Unreachable IK stays finite")
	var old_duration: float = project.variant(id).duration
	var midpoint = project.evaluate(id,old_duration*.5)
	project.retime(id,0,old_duration,0,old_duration*2)
	check(distance(project.evaluate(id,old_duration),midpoint)<.0001,"Retiming scales source and corrections together")
	project.history.undo()
	var trim_pose = project.evaluate(id,.25)
	var pre_range = project.evaluate(id,.40); var in_range = project.evaluate(id,.48); var post_range = project.evaluate(id,.60)
	project.retime(id,.45,.55,.45,.65)
	check(distance(project.evaluate(id,.40),pre_range)<.0001 and distance(project.evaluate(id,.51),in_range)<.0001 and distance(project.evaluate(id,.70),post_range)<.0001,"Partial retiming preserves crossing correction curves in the lead-in, range, and tail")
	project.history.undo()
	project.trim(id,.25,1.0)
	check(distance(project.evaluate(id,0),trim_pose)<.0001,"Trim retains pose at new start")
	project.history.undo()
	var copy: String = project.duplicate_variant(id,"A separate variant")
	project.variant(copy).regions.clear()
	check(not project.variant(id).regions.is_empty(),"Variants own separate correction data")
	check(project.save_to(OUTPUT+"/roundtrip.apexmotion")==OK,"Project saves atomically")
	var loaded = Project.new()
	var did_load = loaded.load_from(OUTPUT+"/roundtrip.apexmotion")
	check(did_load,"Project loads: "+loaded.error)
	if not did_load: quit(1); return
	check(distance(loaded.evaluate(id,.5),project.evaluate(id,.5))<.0001,"Project round trip reproduces motion")
	loaded.data.identity.library = "older-source"
	check(loaded.identity_changed(),"Historical source hash is detected")
	check(distance(loaded.evaluate(id,.5),project.evaluate(id,.5))<.0001,"Embedded motion survives source hash differences")
	check(loaded.save_to(OUTPUT+"/recovery.apexmotion",true)==OK,"Recovery save succeeds")
	loaded.save_to(OUTPUT+"/recovery.apexmotion",true)
	var broken = FileAccess.open(OUTPUT+"/recovery.apexmotion",FileAccess.WRITE); broken.store_string("{"); broken.close()
	var recovered = Project.new()
	check(recovered.load_from(OUTPUT+"/recovery.apexmotion"),"Interrupted or corrupt primary save recovers from last-good backup")
	check(distance(recovered.evaluate(id,.5),loaded.evaluate(id,.5))<.0001,"Recovery preserves the exact authored pose")
	check(recovered.path==OUTPUT+"/recovery.apexmotion","Recovered projects save back to the intended filename")
	recovered.dispose()
	check(Project.validate({})!="","Malformed project rejected")
	var invalid = project.data.duplicate(true); invalid.version = 999
	check(Project.validate(invalid)!="","Unsupported schema rejected")
	invalid = project.data.duplicate(true); invalid.rig.parents[0] = 500
	check(Project.validate(invalid)!="","Invalid hierarchy rejected")
	invalid = project.data.duplicate(true); invalid.sources[project.variant(id).source].values.pop_back()
	check(Project.validate(invalid)!="","Truncated sample arrays rejected")
	invalid = project.data.duplicate(true); invalid.sources[project.variant(id).source].values[0] = "bad component"
	check(Project.validate(invalid)!="","Wrong source value types rejected without evaluation")
	invalid = project.data.duplicate(true); invalid.variants[0].id = "../../escape"
	check(Project.validate(invalid)!="","Unsafe exported identifiers rejected")
	invalid = project.data.duplicate(true); invalid.camera = {"yaw":"bad"}
	check(Project.validate(invalid)!="","Malformed camera rejected before opening the viewport")
	invalid = project.data.duplicate(true); invalid.title = []
	check(Project.validate(invalid)!="","Malformed project title rejected before opening the editor")
	var image = Image.create(16,16,false,Image.FORMAT_RGBA8); image.fill(Color.CORNFLOWER_BLUE)
	var note = {"id":Project.uid(),"variant":id,"start":.5,"end":.5,"bones":["Head"],"priority":"High","status":"Open","text":"Keep the head upright.",
		"evidence":{"revision":project.revision,"frames":[{"frame":30,"time":.5,"source_time":.5,"original":Exporter.pack_pose(original),"edited":Exporter.pack_pose(project.evaluate(id,.5)),"image_png":Marshalls.raw_to_base64(image.save_png_to_buffer())}],"camera":{},"context":project.data.preview.duplicate(true)}}
	project.data.comments.append(note)
	var frozen = JSON.stringify(note.evidence)
	project.variant(id).regions.clear()
	check(JSON.stringify(note.evidence)==frozen,"Later edits preserve original comment evidence")
	var exporter = Exporter.new()
	check(await exporter.export_zip(project,OUTPUT+"/review.zip")==OK,"Review ZIP exports: "+exporter.error)
	var zip = ZIPReader.new()
	check(zip.open(OUTPUT+"/review.zip")==OK,"Export archive reopens")
	var exported = JSON.parse_string(zip.read_file("project.apexmotion").get_string_from_utf8())
	check(Project.validate(exported).is_empty(),"Exported project validates")
	var motion = JSON.parse_string(zip.read_file("motion/"+id+".json").get_string_from_utf8())
	var reproduced = Project.new(); reproduced.data = exported
	var export_error = 0.0
	for item in exported.variants:
		var clip_data = JSON.parse_string(zip.read_file("motion/"+item.id+".json").get_string_from_utf8())
		for frame in clip_data.frames:
			for layer in ["original","edited"]:
				var expected = reproduced.evaluate(item.id,frame.time,layer=="edited")
				export_error = maxf(export_error,Project.v3(frame[layer].root).distance_to(expected.root))
				for i in expected.q.size(): export_error = maxf(export_error,q_error(Project.q4(frame[layer].q[i]),expected.q[i]))
	check(export_error<.0001,"Every exported original and edited frame reproduces from the embedded project")
	reproduced.dispose()
	var baked = motion.frames[30].edited
	check(Project.v3(baked.root).distance_to(project.evaluate(id,.5).root)<.00001,"Baked pelvis reproduces evaluator")
	for i in baked.q.size(): check(q_error(Project.q4(baked.q[i]),project.evaluate(id,.5).q[i])<.0001,"Baked joint quaternion reproduces evaluator")
	var notes_data = JSON.parse_string(zip.read_file("comments.json").get_string_from_utf8())
	for exported_note in notes_data:
		for frame in exported_note.evidence.frames: check(zip.file_exists(frame.image),"Comment image reference resolves")
	zip.close()
	var result = {"checks":checks,"failures":failures,"max_source_error":max_error,"max_export_error":export_error}
	Project.atomic_json(OUTPUT+"/suite.json",result)
	print("WORKSHOP_SUITE ",JSON.stringify(result))
	project.dispose(); loaded.dispose()
	project = null; loaded = null
	quit(0 if failures.is_empty() else 1)

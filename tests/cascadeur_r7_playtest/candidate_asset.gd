extends RefCounted
## R6 import convention from its audited gameplay fixture; no scene animation writer.
const SOURCE="res://art_source/animation/cascadeur_carving_20260910_r7/carving_r7_animation.glb"
const SOURCE_SHA="d543ee7a802c09ec5ca36c55d6378fb8a4e0cc064e86e808d60101238f8cb352"
const Motion=preload("res://scripts/presentation/skier_full_motion.gd")
static func load_for(visual) -> Dictionary:
	assert(FileAccess.get_sha256(SOURCE)==SOURCE_SHA,"R7 source changed")
	var doc=GLTFDocument.new();var state=GLTFState.new()
	assert(doc.append_from_file(SOURCE,state)==OK)
	var imported=doc.generate_scene(state);visual.get_tree().root.add_child(imported)
	var skeleton:Skeleton3D=imported.find_children("*","Skeleton3D",true,false)[0]
	var player:AnimationPlayer=imported.find_children("*","AnimationPlayer",true,false)[0]
	assert(skeleton.get_bone_count()==24 and imported.find_children("*","MeshInstance3D",true,false).is_empty())
	player.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var animation_name=""
	for item in player.get_animation_list():
		if item!="RESET":animation_name=item
	assert(is_equal_approx(player.get_animation(animation_name).length,2.0))
	player.play(animation_name);player.advance(0)
	var lib=Motion.library;var values=PackedFloat32Array();var prior=[];var max_fk=0.0
	for frame in 121:
		player.seek(frame/60.0,true);skeleton.force_update_all_bone_transforms()
		var lp=skeleton.get_bone_global_pose(skeleton.find_bone("LeftFoot"));var rp=skeleton.get_bone_global_pose(skeleton.find_bone("RightFoot"))
		var support=(lp.basis*visual.rest[visual.bone_ids.LeftFoot].basis.inverse()).orthonormalized().slerp((rp.basis*visual.rest[visual.bone_ids.RightFoot].basis.inverse()).orthonormalized(),.5)
		var center=(lp.origin+rp.origin)*.5;var globals=[];var positions=[];var this_frame=[]
		for i in lib.names.size():
			var id:String=lib.names[i];var other=skeleton.find_bone(id);assert(other>=0)
			var parent:int=lib.parents[i];var op=skeleton.get_bone_parent(other)
			assert((skeleton.get_bone_name(op) if op>=0 else "")==(lib.names[parent] if parent>=0 else ""))
			var rest:Transform3D=visual.rest[visual.bone_ids[id]]
			assert(rest.origin.distance_to(lib.rest[i].origin)<.0001)
			var pose=skeleton.get_bone_global_pose(other)
			var delta=(support.transposed()*pose.basis*rest.basis.inverse()).orthonormalized();var pos=support.transposed()*(pose.origin-center)
			globals.append(delta);positions.append(pos)
			var local:Basis=globals[parent].transposed()*delta if parent>=0 else delta
			var q=local.get_rotation_quaternion().normalized()
			if frame>0 and prior[i].dot(q)<0:q=-q
			this_frame.append(q);values.append_array(PackedFloat32Array([pos.x,pos.y,pos.z,q.x,q.y,q.z,q.w]))
			if parent>=0:max_fk=maxf(max_fk,(positions[parent]+globals[parent]*(rest.origin-lib.rest[parent].origin)).distance_to(pos))
		prior=this_frame
	assert(max_fk<.0002)
	imported.free()
	return {"duration":2.0,"frames":121,"values":values}


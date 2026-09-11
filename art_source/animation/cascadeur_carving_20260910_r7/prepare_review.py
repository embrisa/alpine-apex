"""Adapt inspected R6 capture/import recipes into this separate carving experiment.
Original sources and sealed evidence are never written. Run once before capture.
"""
from pathlib import Path
import hashlib
root=Path(__file__).resolve().parent
project=root.parents[2]
old=root.with_name('cascadeur_evaluation_20260910_r6')
sha=hashlib.sha256((root/'carving_r7_animation.glb').read_bytes()).hexdigest()
def write(path,text):
    assert not path.exists(),path
    path.write_text(text,encoding='utf-8')
asset=(project/'tests/cascadeur_r6_playtest/candidate_asset.gd').read_text()
asset=asset.replace('cascadeur_evaluation_20260910_r6/ready_compression_r6_animation.glb','cascadeur_carving_20260910_r7/carving_r7_animation.glb').replace('8b25cba89e0f0977cf63d37c8c31080e0dbf8a7b786a15d55d5c60c1e00b5a57',sha).replace('R6 source changed','R7 source changed')
write(project/'tests/cascadeur_r7_playtest/candidate_asset.gd',asset)
capture=(old/'gameplay_capture.gd').read_text()
capture=capture.replace('cascadeur_evaluation_20260910_r6','cascadeur_carving_20260910_r7').replace('cascadeur-20260910-r6-','cascadeur-20260910-r7-').replace('ready_compression_r6_animation.glb','carving_r7_animation.glb')
capture=capture.replace('res://art_source/animation/cascadeur_carving_20260910_r7/evaluation_motion.gd','res://tests/cascadeur_r7_playtest/live_motion.gd')
capture=capture.replace('"evaluation_motion.gd",','"build_controls.py",')
capture=capture.replace('return h\nfunc hash_dir', '''for file in ["candidate_asset.gd","live_motion.gd"]:
		var path="res://tests/cascadeur_r7_playtest/"+file;h[path]=FileAccess.get_sha256(path)
	return h
func hash_dir''')
capture=capture.replace('["straight","compression","steering_left","steering_right","tuck_overlap"]','["straight","steering_left","steering_right","carve_reversal","carve_taps","tuck_turn"]')
begin=capture.index('func input_at(');end=capture.index('func invariant(',begin)
capture=capture[:begin]+'''func input_at(name,t):
	var input=Intent.new()
	var light=.12*smoothstep(.25,.45,t)*(1.0-smoothstep(.95,1.15,t))
	var strong=.65*smoothstep(1.35,1.65,t)*(1.0-smoothstep(2.8,3.1,t))
	if name.begins_with("steering"):input.steer=(light+strong)*(-1.0 if name.ends_with("left") else 1.0)
	if name=="carve_reversal":input.steer=.6 if t>=.3 and t<1.35 else -.6 if t>=1.35 and t<2.5 else .4 if t>=2.5 and t<3.1 else 0.0
	if name=="carve_taps":input.steer=(.55 if int((t-.3)/.16)%2==0 else -.55) if t>=.3 and t<2.8 else 0.0
	if name=="tuck_turn":
		input.steer=strong;input.tuck=.8*smoothstep(.3,1.0,t)*(1.0-smoothstep(2.4,3.2,t))
	return input
''' +capture[end:]
capture=capture.replace(',"substituted":pack(full.substituted)','')
capture=capture.replace('full.clip_time()','.5 if full.diagnostics.get("physical_turn",0)>0 else 1.5')
capture=capture.replace('\trow.stages=pack(full.stages)\n','')
capture=capture.replace('full.landmarks(','landmarks(')
capture=capture.replace('func row_for(','''func landmarks(pose:Dictionary) -> Dictionary:
	var joints={};var rotations={};var library=Motion.library
	for i in library.names.size():
		var name:String=library.names[i];var parent:int=library.parents[i]
		if parent<0:joints[name]=pose.root;rotations[name]=Basis(pose.q[i])
		else:
			var pname:String=library.names[parent]
			joints[name]=joints[pname]+rotations[pname]*(library.rest[i].origin-library.rest[parent].origin)
			rotations[name]=rotations[pname]*Basis(pose.q[i])
	return {"joints":joints,"rotations":rotations}
func row_for(''')
capture=capture.replace('.use_candidate=enabled','.candidate_enabled=enabled')
capture=capture.replace('visual.animation.full_motion.evaluation_time=-1.0;visual.animation.full_motion.ready_only=name=="straight";','')
capture=capture.replace('visual.animation.full_motion.evaluation_time=t;','')
capture=capture.replace('[0,15,30,51,69,81,96,120]','[0,15,27,42,54,75,93,108,120]')
begin=capture.index('\t\treasons[name]=');end=capture.index('\n\t\tprint(',begin)
capture=capture[:begin]+'''\t\treasons[name]={"0":"Warm neutral","15":"Light steer / entry","27":"Light hold","42":"Strong steer / reversal","54":"Loaded turn","75":"Direction or tuck transition","93":"Steer release","108":"Residual turn","120":"Recovery"}'''+capture[end:]
capture=capture.replace('Candidate source slot selection exists only in test subclass.','Cascadeur local offsets over existing carving, before shared anatomy and tracking; direction comes from loaded physical ski edges.')
capture=capture.replace('Source t=clamp(evaluation_time-.7,0,2); ready-only t=0. Forward navigation slots including straight tuck blend in .2-.7s, out 2.7-3.2s. No landing or jump mapping.','Neutral frame 0; right 15; left 45. Local upper-body offsets at 75 percent times physical turn strength, action support gate and tuck attenuation. No time-loop playback; existing turn motion and tracker retained.')
write(root/'gameplay_capture.gd',capture)
preview=(old/'preview_capture.gd').read_text().replace('cascadeur_evaluation_20260910_r6','cascadeur_carving_20260910_r7').replace('cascadeur-20260910-r6-source','cascadeur-20260910-r7-source').replace('ready_compression_r6_animation.glb','carving_r7_animation.glb').replace('cascadeur_grounded','cascadeur_carving')
preview=preview.replace('[0,12,24,30,44,60]','[0,8,15,22,30,38,45,52,60]')
begin=preview.index('\twrite(REV+"selection_reasons.json"');end=preview.index('\n\tprint(',begin)
preview=preview[:begin]+'''\twrite(REV+"selection_reasons.json",{"0":"Neutral","15":"Authored right","30":"Neutral reversal","45":"Authored left","60":"Neutral exit"})'''+preview[end:]
write(root/'preview_capture.gd',preview)
print('Prepared R7 asset importer and paired/source capture recipes. SHA256',sha)

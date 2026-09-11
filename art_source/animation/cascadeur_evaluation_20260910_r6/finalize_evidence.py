"""Finalize the task-owned R6 evidence using the maintained integrity verifier."""
import hashlib,json,sys,shutil
from pathlib import Path
from datetime import datetime,timezone
source=Path(__file__).resolve().parent;root=source.parents[2]
sys.path.insert(0,str(root/'scripts/pose_review'))
from inspect_revision import inspect
from revision import verify_seal
reviews=root/'artifacts/pose_review/revisions';out=root/'artifacts/pose_review/comparisons/cascadeur-20260910-r6'
names=['cascadeur-20260910-r6-'+s for s in ['source','production','gameplay','diagnosis']]
assert not (out/'sealed.json').exists()
assert all(not (reviews/n/'sealed.json').exists() for n in names)
def read(p):return json.loads(p.read_text(encoding='utf-8-sig'))
def write(p,d):p.write_text(json.dumps(d,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
def sha(p):
    with p.open('rb') as f:return hashlib.file_digest(f,'sha256').hexdigest()
integrity={'created_utc':datetime.now(timezone.utc).isoformat(),'scope':'Frozen evidence integrity and coverage, not artistic acceptance.','revisions':{}}
for n in ['cascadeur-20260910-r5']+names:
    check=inspect(n);s=check['sources'];assert not s['live_changed'] and not s['snapshot_missing_or_changed'],(n,s)
    for kind in ['render.json','details.json']:
        if check['checks'][kind]:assert not check['checks'][kind]['missing_images']
    integrity['revisions'][n]={'sources':s,'frames':{c:d['frames'] for c,d in check['scenarios'].items()}}
integrity['revisions']['cascadeur-20260910-r5']['seal']=verify_seal(reviews/'cascadeur-20260910-r5')
assert integrity['revisions']['cascadeur-20260910-r5']['seal']['passed']
engine=root/'.tools/godot-fsr/bin/godot.windows.template_debug.x86_64.exe'
engine_sha=sha(engine);assert engine_sha==read(source/'godot_preview_audit.json')['engine_sha256']
integrity['engine_sha256']=engine_sha
camera_checks=[]
def scalars(v):
    if isinstance(v,dict):return [n for k in sorted(v) for n in scalars(v[k])]
    if isinstance(v,list):return [n for item in v for n in scalars(item)]
    return [v]
for left,right in [('cascadeur-20260910-r6-production','cascadeur-20260910-r6-gameplay'),('cascadeur-20260910-r5','cascadeur-20260910-r6-source')]:
    for file in ['render.json','details.json']:
        a=read(reviews/left/file);b=read(reviews/right/file);count=0;maximum=0.0
        for c,rows in a['scenarios'].items():
            other={int(r['frame']):r for r in b['scenarios'][c]}
            for row in rows:
                delta=max(abs(x-y) for x,y in zip(scalars(row['cameras']),scalars(other[int(row['frame'])]['cameras'])))
                assert delta<1e-7,(left,right,file,c,row['frame'],delta)
                maximum=max(maximum,delta)
                count+=1
        camera_checks.append({'before':left,'after':right,'metadata':file,'matched_frames':count,'all_exact':maximum==0,'max_numeric_difference':maximum,'within_1e_7':True,'note':'Restoring baseline cameras may renormalize basis at float precision. Main frames and source details are exact.'})
integrity['camera_checks']=camera_checks
ga=read(source/'gameplay_analysis.json');comparison=read(out/'comparison.json')
assert comparison['physics_equal'] and comparison['same_engine']
for v in ['production','candidate']:
    for case,data in ga[v].items():
        m=data['metrics'];assert m['frames']==121 and m['all_supported'] and m['attachments_and_lengths_pass'] and m['cuffs_pass'],(v,case)
for suffix,count in [('source',61),('production',605),('gameplay',605)]:
    audit=read(reviews/('cascadeur-20260910-r6-'+suffix)/'pole-mesh-audit.json');assert audit['passed'] and audit['frames']==count and not audit['intersections']
media={}
for n in names:
    folder=reviews/n;m=read(folder/'capture/manifest.json');counts={}
    for item in m['scenarios']:
        rows=read(folder/'capture'/f"{item['name']}.json")['frames']
        assert all((folder/'frames'/item['name']/f"{int(r['frame']):04d}.jpg").exists() for r in rows)
        if n.endswith(('production','gameplay')):
            assert all((folder/'gameplay'/item['name']/f"{int(r['frame']):04d}.jpg").exists() for r in rows)
            assert (folder/'videos'/f"gameplay_{item['name']}.mp4").stat().st_size>1000
        if not n.endswith('diagnosis'):assert (folder/'videos'/f"{item['name']}.mp4").stat().st_size>1000
        counts[item['name']]=len(rows)
    media[n]=counts
assessment={
 'date':'2026-09-10','status':'evaluation_complete_adoption_undecided',
 'recommendation':'Run one bounded presentation experiment letting the source own the grounded posture while preserving anatomy, tracking and solver-owned equipment. Keep production unchanged before that test; do not invest in more clips yet.',
 'authoring':{'retained':'R6 source; modest timing edit preserves accepted R5 silhouette','edit':'Recovery beat 44 -> 48; six timing knots, 31 oriented controls, 61 solved samples','who_did_work':'Custom Python timing/targets; Cascadeur constraint solve, save and GLB export','native_AI_or_AutoPhysics_tested':False,'native_sparse_key_convenience_proven':False,'per_frame_manual_repairs':0,'rig_rebuilds':0,'solve_calls':1,'solve_MCP_seconds':5.009,'save_MCP_seconds':18.885,'copy_load_to_reopened_export_seconds':301.344,'timing_scope':'Observed concurrent call durations, not productivity or performance benchmark','native_material_issue':'Orange/black corruption after reopen persists; original Godot materials valid'},
 'mechanical':{'selected_suite_checks':236,'failures':0,'clothing_audit_frames':{'source':61,'production':605,'candidate':605},'clothing_intersections':0,'matched_solver_input_camera_samples':605,'production_changed':False},
 'visual_review':{'all_front_samples_inspected':{'R5_source':61,'R6_source':61,'production':605,'candidate':605},'full_chronological_triptychs_provided':media,'selected_close_views':'Compression 51, source recovery 44, steering 42/51/69, tuck 51; front chronology includes all entry, light/strong steering and release samples. Selected oblique/side/overhead equipment views inspected. Matched-camera rerenders of compression and right-steer details inspected.','stage_diagnosis':'Source and tracked requested compression frame 51 inspected against final; nine selected frames per case are provided, all 605 static-stage angle deltas recorded.','observations':['Shoulder silhouette remains connected; no R4 collapse returns.','R6 source recovery stays compressed slightly longer at frame 44. Motion remains symmetric and restrained.','Straight compression and full tuck look close to production because existing posture policy replaces source.','At light steering, R6 raises and pulls hands inward relative to production; pole directions change substantially. This does not establish a better balance response.','Front chronology retains continuous strong-turn and exit silhouettes.','Chase camera is correct and matched, but the small character and plain slope limit fine pose assessment.'],'worst_remaining_issue':'Source posture ownership varies across action weights, so the quality payoff of source authoring is unproven.','no_numerical_art_grade':True},
 'browser_review':{'normal_playback':'Both production and candidate active at rate 1, matching timestamps; 2400px media decoded.','half_playback':'Both fitted side-view videos and R5/R6 source videos active at rate 0.5 with matching timestamps.','exact_frames':'All five gameplay cases seek to frame 42 / 1.401666s in both videos; next-frame control reaches 43 / 1.434999s.','gameplay_camera':'Both videos decoded at 1600x900 and played with matching timestamps.','stage_images':'Source/requested/final image triplets load for all five cases.','console_errors_or_warnings_at_final_check':[],'fixes':'Exact frame field now responds on input; play disabled until both videos load; view changes avoid redundant source reload.','scope':'Playback/UI spot checks plus chronological still inspection, not continuous live viewing of every video at both speeds.'},
 'user_acceptance':{'R5_baseline':'It looks decent to me','R6_source':None,'R6_gameplay':None,'Cascadeur_adoption':None},
 'limits':['No production replacement, purchase or release','No independent critic or controller skiing acceptance','No mountain descent or FPS claim','No native AI/AutoPhysics benefit established','No Blender comparison performed','Five-ray clothing audit samples 30 Hz poses, excludes first 10 cm below handle, and does not certify finger contact'],
 'rejected_or_superseded_attempts':['Initial fixture parse used Plane, conflicting with a Godot builtin; corrected to TestPlane before capture. Logs retained in execution history.','Initial detail cameras followed each variant pelvis. Preserved under details_pelvis_focus; matched baseline camera rerenders supersede them.','Initial exact-frame UI change handler did not react to programmatic input; corrected to input handler and verified on all five cases.'],
 'camera_checks':camera_checks
}
write(out/'assessment.json',assessment)
write(out/'camera_comparison.json',camera_checks)
evidence=out/'analysis';evidence.mkdir(exist_ok=True)
for p in source.glob('*audit.json'):shutil.copy2(p,evidence/p.name)
for filename in ['gameplay_analysis.json','stage_analysis.json','native_reopened_frame30.png']:shutil.copy2(source/filename,evidence/filename)
for n in names:
    folder=reviews/n;write(folder/'author_assessment.json',assessment)
    supplement=folder/'supplemental_tooling';supplement.mkdir(exist_ok=True)
    for p in source.iterdir():
        if p.suffix in ['.py','.gd','.ps1']:shutil.copy2(p,supplement/p.name)
    write(folder/'supplemental_tooling.json',{'scope':'Task-specific recipes collected at finalization; original capture source hashes and frozen maintained tools remain separate.','sha256':{p.name:sha(p) for p in supplement.iterdir() if p.is_file()}})
    if n.endswith(('production','gameplay')):
        (folder/'regression').mkdir(exist_ok=True);write(folder/'regression/results.json',read(out/'execution_summary.json')['regressions'])
source_manifest={'scope':'Editable R6 source, recipes and receipts. Not adoption or visual acceptance.','created_utc':integrity['created_utc'],'sha256':{p.relative_to(source).as_posix():sha(p) for p in sorted(source.rglob('*')) if p.is_file() and '__pycache__' not in p.parts and p.name!='manifest.json'}}
write(source/'manifest.json',source_manifest);shutil.copy2(source/'manifest.json',out/'source_manifest.json')
for n in names:
    folder=reviews/n;hashes={p.relative_to(folder).as_posix():sha(p) for p in sorted(folder.rglob('*')) if p.is_file() and p.name!='sealed.json'}
    write(folder/'sealed.json',{'scope':'Frozen evidence integrity, not visual or user acceptance.','status':'R6_user_acceptance_pending','sha256':hashes})
    result=verify_seal(folder);assert result['passed'];integrity['revisions'][n]['seal']=result
write(out/'integrity.json',integrity)
hashes={p.relative_to(out).as_posix():sha(p) for p in sorted(out.rglob('*')) if p.is_file() and p.name!='sealed.json' and not p.name.startswith('server.')}
write(out/'sealed.json',{'scope':'Review page, assessments, receipts and referenced revision integrity. Active local server logs are excluded.','status':'R6_user_acceptance_pending','sha256':hashes})
assert verify_seal(out)['passed']
print(json.dumps({'revisions':{n:r['seal']['listed_files'] for n,r in integrity['revisions'].items()},'comparison_sealed_files':len(hashes),'source_manifest_files':len(source_manifest['sha256']),'camera_checks':camera_checks,'passed':True},indent=2))

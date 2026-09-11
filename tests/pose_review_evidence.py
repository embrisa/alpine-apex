"""Verify frozen evidence/provenance and phase semantics, not visual resemblance."""
import argparse,hashlib,json,math
from pathlib import Path

root=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser();parser.add_argument('--revision',default='20260909-r1');args=parser.parse_args()
rev=root/'artifacts/pose_review/revisions'/args.revision
read=lambda p:json.loads(p.read_text(encoding='utf-8-sig'))
digest=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
data=read(rev/'review/evidence.json');manifest=read(rev/'capture/manifest.json')
assert manifest['stable_sources'] and manifest['failures']==[] and manifest['unranked']
assert data['capture']['physics']==manifest['physics'] and data['capture']['mountain_version']==14
assert data['capture']['seed']==849205174
assert data['capture']['capture_fps']==60 and data['capture']['simulation_hz']==120
for name,sha in manifest['sources'].items():assert digest(rev/'baseline'/name.removeprefix('res://'))==sha,name
rig=manifest['rig'];parents=dict(zip(rig['names'],rig['parents']))
for child,parent in [('Spine02','Hips'),('Spine01','Spine02'),('Spine','Spine01'),('neck','Spine'),('Head','neck')]:assert rig['names'][parents[child]]==parent
for r in data['regions']:assert all(b in rig['names'] for b in r['bones'])
traces={name:read(rev/'capture'/(name+'.json')) for name in data['traceHashes']}
frame_count=sum(len(t['frames']) for t in traces.values())
assert frame_count>0
for name,t in traces.items():
 assert digest(rev/'capture'/(name+'.json'))==data['traceHashes'][name]
 for i,row in enumerate(t['frames']):
  assert row['frame']==i and row['tick']==2*(i+1)
  assert abs(row['time']-row['tick']/120)<1e-10
  assert len(row['final_bones'])==len(rig['names']) and len(row['skis'])==len(row['poles'])==2
  assert abs(sum(c['normalized_weight'] for c in row['clips'].values())-1)<1e-8
  assert all(isinstance(c['mirror'],bool) and c['source_frame']>=0 and c['source_time']>=0 for c in row['clips'].values())
poses={p['id']:p for p in data['poses']};assert len(poses)==3*len(data['sequences'])
for sequence in data['sequences']:
 p=[poses[key] for key in sequence['poses']];assert len(p)==3
 assert p[0]['frame']<p[1]['frame']<p[2]['frame']
 assert [v['panel'] for v in p]==[1,2,3]
 assert all(v['scenario']==sequence['scenario'] for v in p)
for p in poses.values():
 row=traces[p['scenario']]['frames'][p['frame']]
 assert row['tick']==p['tick'] and row['clips']==p['clips']
 assert abs(p['event']['relative_time']-(p['time']-p['event']['time']))<1e-6
 assert len(p['parts'])==20
 for g in [p['overall'],*p['parts'].values()]:
  s=g['score'];assert s is None or (not isinstance(s,bool) and 0<=s<=10 and s*2==int(s*2))
 for g in p['parts'].values():
  assert g['observation'] and g['adjustment'] and g['origin'] and g['range']
  assert all(b in rig['names'] for b in g['bones']+g['coupled_bones'])
  if g['score'] is None:assert any(w in g['observation'].lower() for w in ['obscur','hidden','uncertain'])
for name,sign in [('carve_left',-1),('carve_right',1)]:
 if name not in traces:continue
 seq=next(s for s in data['sequences'] if s['id']==name);peak=poses[seq['poses'][1]]
 row=traces[name]['frames'][peak['frame']]
 assert row['body_roll_rad']*sign>0 and any(f['input']['steer']*sign>0 for f in traces[name]['frames'])
 assert row==max(traces[name]['frames'],key=lambda f:abs(f['body_roll_rad']))
for key in ['preparation_03','takeoff_02']:
 if key not in poses:continue
 p=poses[key];frames=traces[p['scenario']]['frames']
 if key=='preparation_03' and frames[p['frame']]['grounded']:
  assert not frames[p['frame']+1]['grounded'],'A supported final preparation card must be the last frame before departure'
 else:assert p['matchStatus']=='partial' and not frames[p['frame']]['grounded']
if 'landing' in traces:
 landing=traces['landing'];first=next(e for e in landing['events'] if e['type']=='contact')
 contact=next(r for r in landing['frames'] if r['tick']>=first['tick'] and r['grounded'])
 assert poses['landing_01']['frame']==contact['frame']
 # Contact can occur between captured 60 Hz frames of the 120 Hz simulation.
 # Derive the absorption window from that event instead of an old model's tick.
 window=landing['frames'][contact['frame']:contact['frame']+34]
 assert poses['landing_02']['frame']==min(window,key=lambda r:r['joints']['Hips'][1])['frame']
for file,sha in read(rev/'review/asset-hashes.json').items():assert digest(rev/'review'/file)==sha,file
numeric=sum(g['score'] is not None for p in poses.values() for g in p['parts'].values())
report=dict(passed=True,poses=len(poses),bodyRegions=20*len(poses),numericRegionGrades=numeric,unjudgeableRegions=20*len(poses)-numeric,motionGrades=len(data['sequences']),rawFrames=frame_count,frozenInputs=len(manifest['sources']),baselineHashMismatches=0,partialMatches=[p['id'] for p in poses.values() if p['matchStatus']=='partial'],renderMaxJointErrorMetres=data['renderVerification']['max_restored_bone_error_m'])
(rev/'evidence-validation.json').write_text(json.dumps(report,indent=2));print(json.dumps(report))

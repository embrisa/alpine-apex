"""Package reviewed evidence. Scores are authored in assessment-source.json,
never estimated from pixels or fabricated by this builder.
"""
import argparse, hashlib, json, math, shutil, subprocess
from pathlib import Path
import numpy as np
from PIL import Image

ROOT=Path(__file__).resolve().parents[2]
TOOLS=Path(__file__).resolve().parent
REGIONS=[('pelvis','Pelvis','Hips','Core'),('lower_spine','Lower spine','Spine02','Core'),('middle_spine','Middle spine','Spine01','Core'),('upper_spine','Upper spine / chest','Spine','Core'),('neck','Neck','neck','Head & neck'),('head','Head / gaze','Head','Head & neck')]
for side in ['left','right']:
    prefix=side.title()
    for ident,label,bone,group in [('shoulder','Shoulder','Shoulder','Arms'),('upper_arm','Upper arm','Arm','Arms'),('forearm','Forearm / elbow','ForeArm','Arms'),('hand','Hand / wrist','Hand','Arms'),('thigh','Thigh / hip','UpLeg','Legs'),('shin','Shin / knee','Leg','Legs'),('foot','Foot / ankle','Foot','Legs')]:
        REGIONS.append((side+'_'+ident,prefix+' '+label.lower(),prefix+bone,group))

def read(path):return json.loads(path.read_text(encoding='utf-8-sig'))
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def angle(a,b,c):
    u=np.array(a)-np.array(b);v=np.array(c)-np.array(b)
    return round(math.degrees(math.acos(float(np.clip(np.dot(u,v)/(np.linalg.norm(u)*np.linalg.norm(v)),-1,1)))),1)
def transform(t,v):return np.array(t['origin'])+np.array(t['basis']).T@v
def score_valid(score):return score is None or (isinstance(score,(int,float)) and not isinstance(score,bool) and 0<=score<=10 and score*2==int(score*2))

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--revision',required=True);parser.add_argument('--video',action='store_true');args=parser.parse_args()
    rev=ROOT/'artifacts/pose_review/revisions'/args.revision
    if (rev/'sealed.json').exists():
        raise SystemExit('This review revision is sealed. Use a new revision directory; earlier assessments must remain available.')
    assessed=read(rev/'assessment-source.json');manifest=read(rev/'capture/manifest.json');render=read(rev/'render.json')
    assert manifest['stable_sources'] and not manifest['failures']
    assert render['max_restored_bone_error_m']<1e-5
    assert not render.get('partial',False),'A review needs chronological rendered motion, not selected stills only'
    destination=rev/'review';assets=destination/'assets';assets.mkdir(parents=True,exist_ok=True)
    refs={}
    for path in sorted((ROOT/'skier_pose_reference_sheets').glob('*.png')):
        refs[path.name]=sha(path);shutil.copy2(path,assets/path.name)
    trace_hashes={s['name']:sha(rev/'capture'/(s['name']+'.json')) for s in manifest['scenarios']}
    identity=hashlib.sha256(json.dumps({'capture':sha(rev/'capture/manifest.json'),'traces':trace_hashes,'references':refs,'render':sha(rev/'render.json'),'selection':[(p['id'],p['scenario'],p['frame']) for p in assessed['poses']]},sort_keys=True).encode()).hexdigest()
    data={'version':1,'reviewer':'codex','revision':args.revision,'evidenceId':identity,'capture':{k:manifest[k] for k in ['created_utc','engine','physics','seed','mountain_version','capture_fps','simulation_hz','unranked']},'cameraPolicy':render['camera_policy'],
        'limitations':assessed['limitations'],'regions':[{'id':key,'label':label,'bones':[bone]+([bone.replace('Foot','ToeBase')] if key.endswith('_foot') else []),'group':group} for key,label,bone,group in REGIONS],
        'priorities':assessed['priorities'],'sequences':assessed['sequences'],'poses':[],'referenceHashes':refs,'sourceHashes':manifest['sources'],'traceHashes':trace_hashes,'terrain':manifest['terrain'],'renderVerification':{'max_restored_bone_error_m':render['max_restored_bone_error_m']},
        'framing':{'game_uniform_scale':1.6,'game_pivot_pixels':[400,710],'policy':'One fixed uniform body magnification for all poses and cameras; no per-pose height normalization, reflection, stretching or limb repositioning. Some equipment ends fall outside the close frame. The full three-view link and videos preserve complete equipment framing. AI camera and anatomical scale are estimates.'},
        'evidenceLinks':{'captureManifest':'../capture/manifest.json','render':'../render.json','assessmentSource':'../assessment-source.json'}}
    data['sourceStatus']={'kind':'frozen','laterChanges':read(rev/'current-source-differences.json') if (rev/'current-source-differences.json').exists() else [],'message':assessed.get('sourceMessage','Frozen review baseline. Later rig and physics edits in the shared workspace are not assessed here. The original source, skeleton, settings and hashes are retained with this revision.')}
    traces={s['name']:read(rev/'capture'/(s['name']+'.json')) for s in manifest['scenarios']}
    sequences={s['id']:s for s in data['sequences']}
    for p in assessed['poses']:
        sequence=sequences[p['sequence']];row=traces[p['scenario']]['frames'][p['frame']]
        assert row['frame']==p['frame']
        p['time']=row['time'];p['tick']=row['tick'];p['clips']=row['clips']
        anchor={'regular':('stance command starts',.5),'tuck':('release command starts',1.65)}.get(p['scenario'])
        if p['scenario'] in ('prepare_takeoff','landing'):
            kind='jump' if p['scenario']=='prepare_takeoff' else 'contact'
            event=next(e for e in traces[p['scenario']]['events'] if e['type']==kind)
            anchor=('jump / support loss' if kind=='jump' else 'first contact',event['time'])
        if anchor is None:
            peak=max(traces[p['scenario']]['frames'],key=lambda r:abs(r['body_roll_rad']))
            anchor=('strongest physical bank',peak['time'])
        p['event']={'name':anchor[0],'time':anchor[1],'relative_time':round(row['time']-anchor[1],6),'tick':round(anchor[1]*120)}
        p['videoTime']=p['frame']/60
        p['frameEvidence']={'trace':'../capture/'+p['scenario']+'.json','sha256':trace_hashes[p['scenario']],'renderedFrameSha256':sha(rev/'frames'/p['scenario']/f"{p['frame']:04d}.jpg"),'events':traces[p['scenario']]['events']}
        if 'lastSupportedFrame' in p:
            supported_frame=p.pop('lastSupportedFrame');supported=traces[p['scenario']]['frames'][supported_frame]
            assert supported['grounded'] and supported_frame<p['frame']
            name=p['id']+'_last_supported.jpg'
            shutil.copy2(rev/'frames'/p['scenario']/f'{supported_frame:04d}.jpg',assets/name)
            p['lastSupported']={'frame':supported_frame,'tick':supported['tick'],'image':'assets/'+name}
        reference=Image.open(assets/sequence['referenceFile']);width,height=reference.size
        # Unwarped panel crop. Full original is always linked for context.
        left=round((p['panel']-1)*width/3);right=round(p['panel']*width/3)
        crop=reference.crop((left,0,right,height))
        # A padded uniform resize gives both image wells identical canvas geometry.
        # Panel boundaries are retained, including any originally clipped ski/pole.
        scale=1000/height;crop=crop.resize((round(crop.width*scale),1000),Image.Resampling.LANCZOS)
        ref_canvas=Image.new('RGB',(800,1000),(161,164,170));ref_canvas.paste(crop,((800-crop.width)//2,0))
        ref_canvas.save(assets/(p['id']+'_reference.png'))
        p['referenceImage']='assets/'+p['id']+'_reference.png'
        file=rev/'frames'/p['scenario']/f"{p['frame']:04d}.jpg";shutil.copy2(file,assets/(p['id']+'_full.jpg'));p['fullFrame']='assets/'+p['id']+'_full.jpg'
        image=Image.open(file);assert image.size==(2400,1000)
        p['images']=[]
        for i in range(3):
            name=f"{p['id']}_view{i}.jpg";panel=image.crop((i*800,0,(i+1)*800,1000))
            # Uniform whole-image framing, identical for every phase; the raw view is preserved.
            s=1.6;panel=panel.transform((800,1000),Image.Transform.AFFINE,(1/s,0,400*(1-1/s),0,1/s,710*(1-1/s)),Image.Resampling.BICUBIC)
            panel.save(assets/name,quality=96);p['images'].append('assets/'+name)
        p['sourceImages']=[]
        for kind in ['source','requested','final']:
            source=rev/'diagnosis'/p['scenario']/f"{p['frame']:04d}_{kind}.jpg"
            name=p['id']+'_'+kind+'.jpg';Image.open(source).crop((0,0,800,1000)).save(assets/name,quality=96);p['sourceImages'].append('assets/'+name)
        specs=render['scenarios'][p['scenario']][p['frame']]['cameras'];p['landmarks']=[]
        for camera in specs:
            cam=camera['transform'];points={}
            for i,bone in enumerate(manifest['rig']['names']):
                world=transform(row['root'],np.array(row['final_bones'][i]['origin']))
                local=np.array(cam['basis'])@(world-np.array(cam['origin']))
                x=400+local[0]*1000/camera['size'];y=500-local[1]*1000/camera['size']
                points[bone]=[round(400+(x-400)*1.6,2),round(710+(y-710)*1.6,2)]
            p['landmarks'].append(points)
        j=row['joints'];ankles=(np.array(j['LeftFoot'])+np.array(j['RightFoot']))*.5
        p['measurements']={'units':'metres and degrees; skeleton-local coordinates, +Y up, +Z forward; actual game values, not reconstructed reference targets','pelvis_above_mean_ankles_m':round(j['Hips'][1]-ankles[1],3),'pelvis_fore_aft_from_mean_ankles_m':round(j['Hips'][2]-ankles[2],3),
            'left_knee_internal_deg':angle(j['LeftUpLeg'],j['LeftLeg'],j['LeftFoot']),'right_knee_internal_deg':angle(j['RightUpLeg'],j['RightLeg'],j['RightFoot']),
            'left_elbow_internal_deg':angle(j['LeftArm'],j['LeftForeArm'],j['LeftHand']),'right_elbow_internal_deg':angle(j['RightArm'],j['RightForeArm'],j['RightHand']),
            'physical_bank_deg':round(math.degrees(row['body_roll_rad']),1),'speed_kmh':round(row['speed_mps']*3.6,1),'grounded':row['grounded'],'state':row['state'],'fitting':row['diagnostics']}
        scores=p.pop('scores');assert len(scores)==20 and all(score_valid(v) for v in scores)
        overrides=p.pop('partOverrides',{});templates=assessed['partTemplates'][p['template']]
        p['parts']={}
        for (key,label,bone,group),score in zip(REGIONS,scores):
            entry=dict(templates.get(key,templates.get(key.replace('left_','').replace('right_',''),{})))
            assert entry and all(k in entry for k in ['observation','adjustment','origin','confidence']),f'Missing template: {p["id"]} {key}'
            entry.update(overrides.get(key,{}));entry['score']=score;entry['range']=p['adjustmentRange']
            entry['region']=key;entry['bones']=[bone]+([bone.replace('Foot','ToeBase')] if key.endswith('_foot') else [])
            if key.startswith(('left_','right_')):
                side=key.split('_')[0].title()
                entry['coupled_bones']=['Hips',side+'UpLeg',side+'Leg',side+'Foot'] if key.endswith(('_thigh','_shin','_foot')) else ['Spine',side+'Shoulder',side+'Arm',side+'ForeArm',side+'Hand']
            else:entry['coupled_bones']=['Hips','Spine02','Spine01','Spine','neck','Head']
            if score is None:assert 'hidden' in entry['observation'].lower() or 'obscur' in entry['observation'].lower() or 'uncertain' in entry['observation'].lower(),f'Unjudgeable needs explanation: {p["id"]} {key}'
            p['parts'][key]=entry
        del p['template'];data['poses'].append(p)
    assert data['sequences'] and len(data['poses'])==3*len(data['sequences'])
    assert len({p['id'] for p in data['poses']})==len(data['poses'])
    for s in data['sequences']:
        poses=[next(p for p in data['poses'] if p['id']==id) for id in s['poses']]
        assert len(poses)==3 and all(poses[i]['frame']<poses[i+1]['frame'] for i in range(2))
        assert score_valid(s['motion']['score']) and all(score_valid(p['overall']['score']) for p in poses)
        values=[p['overall']['score'] for p in poses if p['overall']['score'] is not None];s['poseScoreRange']=f'{min(values):g}–{max(values):g}'
        s['referenceSheet']='assets/'+s['referenceFile'];s['video']='assets/'+s['scenario']+'.mp4'
    if args.video:
        ffmpeg=ROOT/'.tools/animation-video/imageio_ffmpeg/binaries/ffmpeg-win-x86_64-v7.1.exe'
        for name in dict.fromkeys(s['scenario'] for s in data['sequences']):
            subprocess.run([str(ffmpeg),'-hide_banner','-loglevel','error','-y','-framerate','60','-i',str(rev/'frames'/name/'%04d.jpg'),'-c:v','libx264','-preset','veryfast','-crf','19','-pix_fmt','yuv420p','-movflags','+faststart',str(assets/(name+'.mp4'))],check=True)
    for file in ['index.html','review.css','review.js','review_state.js','feedback.schema.json','evidence.schema.json']:shutil.copy2(TOOLS/file,destination/file)
    (destination/'evidence.json').write_text(json.dumps(data,indent=2,ensure_ascii=False),encoding='utf-8')
    payload=json.dumps(data,ensure_ascii=False).replace('<','\\u003c')
    (destination/'data.js').write_text('window.POSE_REVIEW = '+payload+';\n',encoding='utf-8')
    md=['# Alpine Apex pose review',f'Revision {args.revision} · {manifest["created_utc"]} UTC','',assessed['limitations'],'','Grades: overall reference fit / motion quality. Your scores are separate and initially blank.','']
    for s in data['sequences']:
        md.extend(['## '+s['title'],'',s['summary'],'',s['referenceWarning'],'',f'Motion: {s["motion"]["score"]}/10 — {s["motion"]["reason"]}',''])
        for id in s['poses']:
            p=next(p for p in data['poses'] if p['id']==id)
            md.extend([f'### {p["title"]}: {p["overall"]["score"]}/10','',f'Frame {p["frame"]} · tick {p["tick"]} · {p["time"]:.3f} s · {p["eventLabel"]}',p['matchNote'],'',p['overall']['reason'],'','| Body region | Codex | Observation | Adjustment |','|---|---:|---|---|'])
            for region in data['regions']:
                g=p['parts'][region['id']];md.append(f'| {region["label"]} (`{", ".join(region["bones"])}`) | {g["score"] if g["score"] is not None else "Unjudgeable"} | {g["observation"]} | {g["adjustment"]} |')
            md.append('')
    (destination/'assessment.md').write_text('\n'.join(md),encoding='utf-8')
    referenced={p[k] for p in data['poses'] for k in ['referenceImage','fullFrame']}
    for p in data['poses']:referenced.update(p['images']+p['sourceImages'])
    referenced.update(p['lastSupported']['image'] for p in data['poses'] if 'lastSupported' in p)
    referenced.update(s['video'] for s in data['sequences']);referenced.update(s['referenceSheet'] for s in data['sequences'])
    missing=[path for path in referenced if not (destination/path).is_file()];assert not missing,missing
    (destination/'asset-hashes.json').write_text(json.dumps({p:sha(destination/p) for p in sorted(referenced)},indent=2),encoding='utf-8')
    result={'poses':len(data['poses']),'body_assessments':sum(len(p['parts']) for p in data['poses']),'motion_assessments':len(data['sequences']),'feedback_fields':len(data['poses'])*21+len(data['sequences']),'assets':len(referenced),'missing_assets':missing,'evidence_id':identity}
    (rev/'package-validation.json').write_text(json.dumps(result,indent=2),encoding='utf-8');print(json.dumps(result));print(destination/'index.html')

if __name__=='__main__':main()

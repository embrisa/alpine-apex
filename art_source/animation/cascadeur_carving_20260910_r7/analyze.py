"""Compare actual fitted carving poses, rigid attachments and identical physics."""
import json, sys, math
from pathlib import Path
root=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(root/'.tools/motion-plots'))
import numpy as np
base=root/'artifacts/pose_review/revisions'
read=lambda p:json.loads(p.read_text())
basis=lambda b:np.array(b).T
def world(t,p):return np.array(t['origin'])+basis(t['basis'])@p
report={'scope':'726 paired actual solver poses, 30 Hz captures over 120 Hz simulation. Geometry audit and visual review are separate.','scenarios':{}}
for case in read(base/'cascadeur-20260910-r7-gameplay/capture/manifest.json')['scenarios']:
    name=case['name'];a=read(base/'cascadeur-20260910-r7-production/capture'/f'{name}.json');b=read(base/'cascadeur-20260910-r7-gameplay/capture'/f'{name}.json')
    rig=b['rig'];names=[r['name'] for r in rig];ids={n:i for i,n in enumerate(names)};rest={r['name']:np.array(r['rest']['origin']) for r in rig}
    metrics={'physics_mismatches':0,'max_final_joint_difference_m':0.,'max_binding_error_m':0.,'max_grip_error_m':0.,'max_segment_error_m':0.,'min_cuff_forward_deg':1000.,'max_cuff_forward_deg':-1000.,'max_cuff_side_deg':0.,'max_applied_amount':0.,'frames':len(b['frames']),'max_rotation_step_deg':0.}
    previous=None;diffs=[]
    for old,row in zip(a['frames'],b['frames']):
        for key in ['tick','input','physical_position','physical_velocity','body_roll_rad','ski_edges_rad','ski_loads_n','root','skis','gameplay_camera','grounded']:
            metrics['physics_mismatches']+=int(old[key]!=row[key])
        difference=max(float(np.linalg.norm(np.array(old['joints'][n])-row['joints'][n])) for n in row['joints'])
        diffs.append(difference)
        metrics['max_final_joint_difference_m']=max(metrics['max_final_joint_difference_m'],difference)
        metrics['max_applied_amount']=max(metrics['max_applied_amount'],row['diagnostics']['cascadeur_carve_amount'])
        final={n:np.array(row['final_bones'][i]['origin']) for n,i in ids.items()}
        rot={n:basis(row['final_bones'][i]['basis'])@np.linalg.inv(basis(rig[i]['rest']['basis'])) for n,i in ids.items()}
        for i,r in enumerate(rig):
            if r['parent']<0:continue
            n=r['name'];pn=names[r['parent']]
            metrics['max_segment_error_m']=max(metrics['max_segment_error_m'],float(abs(np.linalg.norm(final[n]-final[pn])-np.linalg.norm(rest[n]-rest[pn]))))
        for side,prefix in enumerate(['Right','Left']):
            ski=row['skis'][side];sb=basis(ski['basis']);foot=prefix+'Foot';knee=prefix+'Leg';hand=prefix+'Hand'
            support=np.array(ski['origin'])-sb@np.array([0,.015,.15])
            expected=support+sb[:,1]*(.032+rest[foot][1]);actual=world(row['root'],final[foot])
            metrics['max_binding_error_m']=max(metrics['max_binding_error_m'],float(np.linalg.norm(actual-expected)))
            grip=final[hand]+rot[hand]@np.array([-.070 if side==0 else .070,0,.018])
            metrics['max_grip_error_m']=max(metrics['max_grip_error_m'],float(np.linalg.norm(world(row['root'],grip)-row['poles'][side]['origin'])))
            axis=sb.T@(world(row['root'],final[knee])-actual)
            forward=math.degrees(math.atan2(axis[2],axis[1]));lateral=abs(math.degrees(math.atan2(axis[0],axis[1])))
            metrics['min_cuff_forward_deg']=min(metrics['min_cuff_forward_deg'],forward);metrics['max_cuff_forward_deg']=max(metrics['max_cuff_forward_deg'],forward);metrics['max_cuff_side_deg']=max(metrics['max_cuff_side_deg'],lateral)
        if previous:
            for n in rot:
                def rigid(m):
                    u,_,v=np.linalg.svd(m);return u@v
                angle=math.degrees(math.acos(float(np.clip((np.trace(rigid(previous[n]).T@rigid(rot[n]))-1)/2,-1,1))))
                metrics['max_rotation_step_deg']=max(metrics['max_rotation_step_deg'],angle)
        previous=rot
    metrics['worst_frame']=int(np.argmax(diffs));metrics['last_difference_m']=diffs[-1]
    metrics['passed']=metrics['physics_mismatches']==0 and max(metrics[k] for k in ['max_binding_error_m','max_grip_error_m','max_segment_error_m'])<.0001 and -.1<=metrics['min_cuff_forward_deg'] and metrics['max_cuff_forward_deg']<=24.1 and metrics['max_cuff_side_deg']<=10.1
    report['scenarios'][name]=metrics
report['passed']=all(m['passed'] for m in report['scenarios'].values())
output=Path(__file__).with_name('gameplay_analysis.json');assert not output.exists()
output.write_text(json.dumps(report,indent=2));print(json.dumps(report,indent=2))
assert report['passed']

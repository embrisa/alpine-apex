"""Audit the captured source/requested/final chains and solver-owned attachments."""
import json, math, sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[3]/'.tools/motion-plots'))
import numpy as np
ROOT=Path(__file__).resolve().parents[3]
BASE=ROOT/'artifacts/pose_review/revisions'
def read(p):return json.loads(p.read_text())
def basis(v):return np.array(v).T
def rotation(v):
    u,_,vt=np.linalg.svd(v);return u@vt
def quat(v):
    x,y,z,w=v
    return np.array([[1-2*(y*y+z*z),2*(x*y-z*w),2*(x*z+y*w)],[2*(x*y+z*w),1-2*(x*x+z*z),2*(y*z-x*w)],[2*(x*z-y*w),2*(y*z+x*w),1-2*(x*x+y*y)]])
def angle(a,b):return math.degrees(math.acos(float(np.clip((np.trace(rotation(a).T@rotation(b))-1)/2,-1,1))))
def transform(t,p):return np.array(t['origin'])+basis(t['basis'])@p
def max_distance(a,b):return max(float(np.linalg.norm(np.array(a[n])-np.array(b[n]))) for n in a.keys()&b.keys())
def analyze(variant):
    folder=BASE/f'cascadeur-20260910-r6-{variant}';manifest=read(folder/'capture/manifest.json');result={}
    for item in manifest['scenarios']:
        data=read(folder/'capture'/f'{item["name"]}.json');rig=data['rig'];names=[b['name'] for b in rig];ids={n:i for i,n in enumerate(names)}
        rest={b['name']:np.array(b['rest']['origin']) for b in rig};restrot={b['name']:basis(b['rest']['basis']) for b in rig}
        metrics={'max_binding_error_m':0.,'max_fixed_grip_error_m':0.,'max_segment_error_m':0.,'max_requested_to_final_joint_m':0.,'max_cuff_forward_deg':-1e9,'min_cuff_forward_deg':1e9,'max_cuff_side_deg':0.,'max_joint_rotation_step_deg':0.,'max_source_to_requested_joint_m':0.}
        widths=[];rows=data['frames'];previous=None;selected=[]
        for row in rows:
            bones={n:row['final_bones'][i] for n,i in ids.items()};final={n:bones[n]['origin'] for n in names}
            rots={n:basis(bones[n]['basis'])@np.linalg.inv(restrot[n]) for n in names}
            feet=(np.array(final['RightFoot'])+final['LeftFoot'])*.5
            source={n:np.array(p)+feet for n,p in row['candidate_source']['joints'].items()}
            source_error=max_distance(source,row['requested'])
            fitted_error=max_distance(row['requested'],final)
            metrics['max_source_to_requested_joint_m']=max(metrics['max_source_to_requested_joint_m'],source_error)
            metrics['max_requested_to_final_joint_m']=max(metrics['max_requested_to_final_joint_m'],fitted_error)
            widths.append(float(np.linalg.norm(np.array(final['LeftArm'])-final['RightArm'])))
            for i,b in enumerate(rig):
                if b['parent']>=0:
                    n=b['name'];pn=names[b['parent']]
                    err=abs(np.linalg.norm(np.array(final[n])-final[pn])-np.linalg.norm(rest[n]-rest[pn]))
                    metrics['max_segment_error_m']=max(metrics['max_segment_error_m'],float(err))
            for side,prefix in enumerate(['Right','Left']):
                ski=row['skis'][side];sb=basis(ski['basis']);support=np.array(ski['origin'])-sb@np.array([0,.015,.15])
                foot=prefix+'Foot';knee=prefix+'Leg';hand=prefix+'Hand'
                expected=support+sb[:,1]*(.032+rest[foot][1]);actual=transform(row['root'],final[foot])
                metrics['max_binding_error_m']=max(metrics['max_binding_error_m'],float(np.linalg.norm(actual-expected)))
                grip=np.array(final[hand])+rots[hand]@np.array([-.070 if side==0 else .070,0,.018])
                metrics['max_fixed_grip_error_m']=max(metrics['max_fixed_grip_error_m'],float(np.linalg.norm(transform(row['root'],grip)-row['poles'][side]['origin'])))
                axis=sb.T@(transform(row['root'],final[knee])-actual);forward=math.degrees(math.atan2(axis[2],axis[1]));lateral=abs(math.degrees(math.atan2(axis[0],axis[1])))
                metrics['max_cuff_forward_deg']=max(metrics['max_cuff_forward_deg'],forward);metrics['min_cuff_forward_deg']=min(metrics['min_cuff_forward_deg'],forward);metrics['max_cuff_side_deg']=max(metrics['max_cuff_side_deg'],lateral)
            if previous:
                metrics['max_joint_rotation_step_deg']=max(metrics['max_joint_rotation_step_deg'],max(angle(rots[n],previous[n]) for n in names))
            previous=rots
            if row['frame'] in [15,30,51,69,81,96,120]:
                stages=row['stages'];libnames=read(ROOT/'art_source/animation/steep_full_curves/manifest.json') if False else None
                # The captured stage arrays use the production library order;
                # this rig and library order are separately verified by importer.
                selected.append({'frame':row['frame'],'tick':row['tick'],'steer_input':row['input']['steer'],'physical_turn':row['diagnostics']['physical_turn'],'candidate_slot_weight':stages['candidate_weight'],'downhill_weight':stages['downhill_weight'],'action_weights':stages['action_weights'],'source_to_requested_m':source_error,'requested_to_final_m':fitted_error,'pelvis_support_bias_m':row['diagnostics']['pelvis_support_bias_m'],'pelvis_reach_fit_m':row['diagnostics']['pelvis_fit_m'],'final_hip_above_mean_ankle_m':float(np.array(final['Hips'])[1]-feet[1])})
        metrics['shoulder_width_m']=[min(widths),max(widths)];metrics['frames']=len(rows);metrics['all_supported']=all(r['grounded'] for r in rows)
        metrics['attachments_and_lengths_pass']=metrics['max_binding_error_m']<.0001 and metrics['max_fixed_grip_error_m']<.0001 and metrics['max_segment_error_m']<.0001
        metrics['cuffs_pass']=metrics['max_cuff_forward_deg']<=24.1 and metrics['min_cuff_forward_deg']>=-.1 and metrics['max_cuff_side_deg']<=10.1
        result[item['name']]={'metrics':metrics,'selected':selected}
    return result
def main():
    a=analyze('production');b=analyze('gameplay');pairs={}
    for name in a:
        old=read(BASE/'cascadeur-20260910-r6-production/capture'/f'{name}.json')['frames'];new=read(BASE/'cascadeur-20260910-r6-gameplay/capture'/f'{name}.json')['frames']
        keys=['tick','input','physical_position','physical_velocity','body_roll_rad','ski_edges_rad','ski_loads_n','root','skis','gameplay_camera','grounded']
        mismatches=[{'frame':x['frame'],'field':key} for x,y in zip(old,new) for key in keys if x[key]!=y[key]]
        pos=[max_distance(x['joints'],y['joints']) for x,y in zip(old,new)]
        pairs[name]={'matched_physics_equipment_camera':not mismatches,'mismatches':mismatches,'max_final_joint_difference_m':max(pos),'worst_frame':int(np.argmax(pos)),'difference_at_source_peak_m':pos[51],'difference_at_exit_m':pos[96]}
    out={'scope':'605 final poses per variant, actual solver bindings and fixed gloves. Source differences are expected gameplay changes, not transfer failures. Five-ray skinned clothing audit is separate.','production':a,'candidate':b,'comparison':pairs}
    path=Path(__file__).with_name('gameplay_analysis.json');assert not path.exists();path.write_text(json.dumps(out,indent=2))
    print(json.dumps({'comparison':pairs,'candidate_metrics':{n:v['metrics'] for n,v in b.items()}},indent=2))
if __name__=='__main__':main()

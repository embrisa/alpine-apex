"""Measure anatomical landmarks in the corrected native research GLB (never export keys).

Requires numpy. Source axes are converted by the GLB root. Distances are normalized
by the rest hip-knee-ankle chain; no source-game metres or runtime phase times inferred.
"""
from pathlib import Path
import argparse, hashlib, json, struct
import numpy as np

DEFAULT = Path(r'C:/Users/hp/Documents/Codex/Reports/Steep-Animations-2026-09-08/exports/Steep_ID01_Female_Core_Motion.glb')
OUT = Path(__file__).resolve().parents[2]/'art_source/animation/apex_ski_v17'
MAPPING = {'Hips':'Hips','Spine':'Spine02','Spine1':'Spine01','Spine2':'Spine','Neck':'neck','Head':'Head'}
for side in ['Left','Right']:
    for role in ['UpLeg','Leg','Foot','Shoulder','Arm','ForeArm','Hand']:
        MAPPING[side+role]=side+role

def rotation(q):
    x,y,z,w=np.asarray(q)/np.linalg.norm(q)
    return np.array([[1-2*(y*y+z*z),2*(x*y-z*w),2*(x*z+y*w)],
                     [2*(x*y+z*w),1-2*(x*x+z*z),2*(y*z-x*w)],
                     [2*(x*z-y*w),2*(y*z+x*w),1-2*(x*x+y*y)]])

def slerp(a,b,u):
    if np.dot(a,b)<0: b=-b
    dot=np.clip(np.dot(a,b),-1,1)
    if dot>.9995: q=a*(1-u)+b*u; return q/np.linalg.norm(q)
    angle=np.arccos(dot)
    return (a*np.sin((1-u)*angle)+b*np.sin(u*angle))/np.sin(angle)

def main(path):
    raw=path.read_bytes(); size=struct.unpack_from('<I',raw,12)[0]
    gltf=json.loads(raw[20:20+size]); binary=raw[28+size:]
    nodes=gltf['nodes']; names={n['name']:i for i,n in enumerate(nodes)}
    def accessor(index):
        a=gltf['accessors'][index]; view=gltf['bufferViews'][a['bufferView']]
        assert a['componentType']==5126 and 'byteStride' not in view
        width={'SCALAR':1,'VEC3':3,'VEC4':4}[a['type']]
        return np.frombuffer(binary,dtype='<f4',count=a['count']*width,offset=view.get('byteOffset',0)+a.get('byteOffset',0)).reshape(-1,width).astype(float)
    def pose(animation=None,t=0):
        trs=[{'translation':n.get('translation',[0,0,0]),'rotation':n.get('rotation',[0,0,0,1]),'scale':n.get('scale',[1,1,1])} for n in nodes]
        if animation:
            for c in animation['channels']:
                sampler=animation['samplers'][c['sampler']]; times=accessor(sampler['input'])[:,0]; values=accessor(sampler['output'])
                j=min(max(0,np.searchsorted(times,t,side='right')-1),len(times)-1); k=min(j+1,len(times)-1)
                u=np.clip((t-times[j])/max(times[k]-times[j],1e-9),0,1)
                prop=c['target']['path']; value=slerp(values[j],values[k],u) if prop=='rotation' else values[j]*(1-u)+values[k]*u
                trs[c['target']['node']][prop]=value
        parents={child:i for i,n in enumerate(nodes) for child in n.get('children',[])}; result={}
        def world(i):
            if i in result: return result[i]
            n=trs[i]; m=np.eye(4); m[:3,:3]=rotation(n['rotation'])@np.diag(n['scale']); m[:3,3]=n['translation']
            result[i]=world(parents[i])@m if i in parents else m
            return result[i]
        return {name:world(i) for name,i in names.items()}
    rest=pose(); point=lambda p,n:p[n][:3,3]
    leg=sum(np.linalg.norm(point(rest,a)-point(rest,b)) for a,b in [('LeftUpLeg','LeftLeg'),('LeftLeg','LeftFoot')])
    def angle(a,b): return float(np.degrees(np.arccos(np.clip(np.dot(a,b)/max(np.linalg.norm(a)*np.linalg.norm(b),1e-9),-1,1))))
    rows=[]; clips={}
    for animation in gltf['animations']:
        duration=max(float(accessor(s['input'])[-1,0]) for s in animation['samplers'])
        clip=[]
        for t in np.linspace(0,duration,61):
            p=pose(animation,float(t)); hip=point(p,'Hips'); ankle=(point(p,'LeftFoot')+point(p,'RightFoot'))*.5
            chest=point(p,'Spine2'); across_hips=point(p,'LeftUpLeg')-point(p,'RightUpLeg'); across_chest=point(p,'LeftShoulder')-point(p,'RightShoulder')
            row={'clip':animation['name'],'source_seconds':float(t),'hip_above_ankles_leg_lengths':float((hip-ankle)[1]/leg),
                 'pelvis_chest_twist_deg':float(np.degrees(np.arctan2(np.cross(across_hips,across_chest)[1],np.dot(across_hips[[0,2]],across_chest[[0,2]])))),
                 'spine_curve_deg':angle(point(p,'Spine1')-point(p,'Spine'),point(p,'Neck')-point(p,'Spine2'))}
            for side in ['Left','Right']:
                knee=point(p,side+'Leg'); thigh=point(p,side+'UpLeg'); foot=point(p,side+'Foot')
                row[side.lower()+'_knee_flex_deg']=180-angle(thigh-knee,foot-knee)
                hand=point(p,side+'Hand')-chest
                row[side.lower()+'_hand_below_chest_leg_lengths']=float(-hand[1]/leg)
                row[side.lower()+'_hand_chest_distance_leg_lengths']=float(np.linalg.norm(hand)/leg)
            clip.append(row); rows.append(row)
        clips[animation['name']]={'stored_duration_s':duration,'metrics':{key:{'min':min(r[key] for r in clip),'max':max(r[key] for r in clip),'mean':float(np.mean([r[key] for r in clip]))} for key in clip[0] if key not in ['clip','source_seconds']},
             'max_hip_extension_source_s':max(clip,key=lambda r:r['hip_above_ankles_leg_lengths'])['source_seconds']}
    OUT.mkdir(parents=True,exist_ok=True)
    report={'source_sha256':hashlib.sha256(raw).hexdigest(),'source':str(path),'source_rig_bones':len(gltf['skins'][0]['joints']),
            'anatomical_mapping':MAPPING,'unmapped_apex':['LeftToeBase','RightToeBase'],
            'rest_leg_source_units':float(leg),'axes':'GLB root converts source Z-up to glTF Y-up; vertical measurements use world Y. Twist uses anatomical lateral landmarks, not local Euler channels.',
            'limitations':'62 animated source bones. Extra neck, fingers and unknown bones excluded. Apex toes remain boot constrained. 61 samples per clip are stored-source times, not runtime timing. Measurements inform original scalar profiles; no extracted tracks ship.',
            'clips':clips}
    (OUT/'native_measurements.json').write_text(json.dumps(report,indent=2)); (OUT/'native_landmarks.json').write_text(json.dumps(rows,indent=2))
    print(json.dumps({'rest_leg_source_units':float(leg),'clips':clips}))

if __name__=='__main__':
    parser=argparse.ArgumentParser(); parser.add_argument('--source',type=Path,default=DEFAULT); main(parser.parse_args().source)

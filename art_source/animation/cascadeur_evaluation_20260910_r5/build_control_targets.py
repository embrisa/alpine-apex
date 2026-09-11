"""Bind-calibrated torso orientation, clavicles and two-bone elbow planes.

Targets for Cascadeur's control rig, in centimetres. Does not edit exported bones.
The R4 movement timing, hips, hand sockets and stationary foot targets are inputs.
"""
import json
import math
from pathlib import Path
import sys
root = Path(__file__).resolve().parent
project = root.parents[1]
sys.path.insert(0,str(project / '.tools/motion-plots'))
import numpy as np
old = root.with_name('cascadeur_rig_20260910_r4')
objects = json.loads((old/'explicit_rest.json').read_text())['objects']
base = {n:np.array(v['samples']['0']['global_position']) for n,v in objects.items() if v['type']=='Point'}
inputs = json.loads((old/'contact_bake_inputs.json').read_text())
body_names = [n for n in base if any(n.startswith(p+'_') for p in ['Hips','Spine02','Spine01','neck','LeftShoulder','RightShoulder'])]
body_names += ['LeftArm_MainPoint','RightArm_MainPoint']
def unit(v):
    assert np.linalg.norm(v)>1e-7
    return v/np.linalg.norm(v)
def frame(axis,normal):
    axis=unit(axis); normal=unit(normal-axis*np.dot(normal,axis))
    return np.column_stack((axis,normal,np.cross(axis,normal)))
rows=[]
for sample in inputs['samples']:
    targets={n:np.array(v) for n,v in dict(sample,**inputs['foot_targets']).items()}
    pelvis=targets['Hips_MainPoint']
    a=targets['neck_MainPoint']-pelvis
    b=base['neck_MainPoint']-base['Hips_MainPoint']
    pitch=math.atan2(a[2],a[1])-math.atan2(b[2],b[1])
    c,s=math.cos(pitch),math.sin(pitch)
    body=np.array([[1,0,0],[0,c,-s],[0,s,c]])
    for n in body_names: targets[n]=pelvis+body@(base[n]-base['Hips_MainPoint'])
    for side,sign in [('Left',1),('Right',-1)]:
        shoulder=targets[side+'Arm_MainPoint']; hand=targets[side+'Hand_MainPoint']
        upper0=base[side+'ForeArm_MainPoint']-base[side+'Arm_MainPoint']
        fore0=base[side+'Hand_MainPoint']-base[side+'ForeArm_MainPoint']
        l1,l2=np.linalg.norm(upper0),np.linalg.norm(fore0)
        axis=unit(hand-shoulder); distance=np.linalg.norm(hand-shoulder)
        assert abs(l1-l2)+1e-3<distance<l1+l2-1e-3, (side,distance,l1,l2)
        along=(l1*l1-l2*l2+distance*distance)/(2*distance)
        radius=math.sqrt(max(0,l1*l1-along*along))
        preferred=body@np.array([sign*.45,-1.,-.35])
        bend=unit(preferred-axis*np.dot(preferred,axis))
        elbow=shoulder+axis*along+bend*radius
        targets[side+'ForeArm_MainPoint']=elbow
        # Use anatomical forward to calibrate the nearly straight rest elbow;
        # its tiny modelling bend is not a reliable hinge-plane normal.
        normal0=unit(np.cross(unit(upper0),np.array([0.,0.,1.])))
        normal=unit(np.cross(elbow-shoulder,hand-elbow))
        rotation=frame(hand-elbow,normal)@frame(fore0,normal0).T
        targets[side+'ForeArm_AdditionalPoint']=elbow+rotation@(base[side+'ForeArm_AdditionalPoint']-base[side+'ForeArm_MainPoint'])
    rows.append({n:v.tolist() for n,v in targets.items()})
(root/'control_targets.json').write_text(json.dumps({'scope':__doc__,'samples':rows},indent=2))
print('Prepared',len(rows),'frames with',len(rows[0]),'explicit controls each')

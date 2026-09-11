"""A small authored carving offset: neutral -> right -> neutral -> left -> neutral.

Centimetre control targets for the established Cascadeur rig. Preserve its feet,
pelvis and segment lengths. Solve these targets inside Cascadeur before export.
"""
import json, math, sys
from pathlib import Path
root = Path(__file__).resolve().parent
project = root.parents[2]
sys.path.insert(0, str(project / '.tools/motion-plots'))
import numpy as np
r5 = root.with_name('cascadeur_evaluation_20260910_r5')
rest = json.loads((r5/'explicit_rest.json').read_text())['objects']
base = {n: np.array(v['samples']['0']['global_position']) for n,v in rest.items() if v['type']=='Point'}
neutral = {n:np.array(v) for n,v in json.loads((r5/'control_targets.json').read_text())['samples'][0].items()}
def unit(v):
    assert np.linalg.norm(v)>1e-7
    return v/np.linalg.norm(v)
def frame(axis, normal):
    axis=unit(axis); normal=unit(normal-axis*np.dot(normal,axis))
    return np.column_stack((axis,normal,np.cross(axis,normal)))
def rotation(axis, degrees):
    a=math.radians(degrees); c,s=math.cos(a),math.sin(a)
    if axis=='x': return np.array([[1,0,0],[0,c,-s],[0,s,c]])
    if axis=='y': return np.array([[c,0,s],[0,1,0],[-s,0,c]])
    return np.array([[c,-s,0],[s,c,0],[0,0,1]])
samples=[]
for f in range(61):
    turn=math.sin(2*math.pi*f/60)
    # Smooth signed poses. Positive turn selects the game's RIGHT source.
    body=rotation('y',5*turn)@rotation('z',-3*turn)@rotation('x',-2*abs(turn))
    pivot=neutral['Hips_MainPoint']
    targets={n:v.copy() for n,v in neutral.items()}
    for n in targets:
        if n.startswith(('Hips_','Spine02_','Spine01_','neck_','Head_','LeftShoulder_','RightShoulder_')) or n in ['LeftArm_MainPoint','RightArm_MainPoint']:
            targets[n]=pivot+body@(neutral[n]-pivot)
    for side,sign in [('Left',1),('Right',-1)]:
        inside=max(0,-sign*turn); outside=max(0,sign*turn)
        targets[side+'Hand_MainPoint']=pivot+body@(neutral[side+'Hand_MainPoint']-pivot)+np.array([sign*(2*inside+6*outside),8*inside-2*outside,7*inside+2*outside])
        for suffix in ['DirectionPoint','AdditionalPoint']:
            targets[side+'Hand_'+suffix]=targets[side+'Hand_MainPoint']+body@(neutral[side+'Hand_'+suffix]-neutral[side+'Hand_MainPoint'])
        shoulder=targets[side+'Arm_MainPoint']; hand=targets[side+'Hand_MainPoint']
        upper0=base[side+'ForeArm_MainPoint']-base[side+'Arm_MainPoint']
        fore0=base[side+'Hand_MainPoint']-base[side+'ForeArm_MainPoint']
        l1,l2=np.linalg.norm(upper0),np.linalg.norm(fore0)
        axis=unit(hand-shoulder); distance=np.linalg.norm(hand-shoulder)
        assert abs(l1-l2)+1e-3<distance<l1+l2-1e-3, (f,side,distance,l1+l2)
        along=(l1*l1-l2*l2+distance*distance)/(2*distance)
        preferred=body@np.array([sign*.45,-1.,-.35])
        bend=unit(preferred-axis*np.dot(preferred,axis))
        elbow=shoulder+axis*along+bend*math.sqrt(max(0,l1*l1-along*along))
        targets[side+'ForeArm_MainPoint']=elbow
        normal0=unit(np.cross(unit(upper0),np.array([0.,0.,1.])))
        normal=unit(np.cross(elbow-shoulder,hand-elbow))
        basis=frame(hand-elbow,normal)@frame(fore0,normal0).T
        targets[side+'ForeArm_AdditionalPoint']=elbow+basis@(base[side+'ForeArm_AdditionalPoint']-base[side+'ForeArm_MainPoint'])
    samples.append({n:v.tolist() for n,v in targets.items()})
output=root/'control_targets.json'; assert not output.exists()
output.write_text(json.dumps({'scope':__doc__,'peak_right_frame':15,'peak_left_frame':45,'neutral_frame':0,'samples':samples},indent=2))
print('Prepared 61 frames, 31 oriented controls; right and left carving offsets.')

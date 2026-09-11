"""Animation-only GLB validation at all 61 export samples (numpy required)."""
import argparse, hashlib, json, math, struct, sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[3]/'.tools/motion-plots'))
import numpy as np
def load(path):
    raw=Path(path).read_bytes(); size,kind=struct.unpack_from('<II',raw,12)
    assert raw[:4]==b'glTF' and kind==0x4e4f534a
    doc=json.loads(raw[20:20+size]); at=20+size
    blob=raw[at+8:at+8+struct.unpack_from('<I',raw,at)[0]]
    return doc,blob
def accessor(doc,blob,index):
    a=doc['accessors'][index]; v=doc['bufferViews'][a['bufferView']]
    assert a['componentType']==5126 and 'sparse' not in a
    n={'SCALAR':1,'VEC3':3,'VEC4':4,'MAT4':16}[a['type']]
    return np.ndarray((a['count'],n),dtype='<f4',buffer=blob,offset=v.get('byteOffset',0)+a.get('byteOffset',0),strides=(v.get('byteStride',n*4),4)).copy()
def matrix(n):
    if 'matrix' in n:return np.array(n['matrix']).reshape(4,4).T
    x,y,z,w=n.get('rotation',[0,0,0,1])
    r=np.array([[1-2*(y*y+z*z),2*(x*y-z*w),2*(x*z+y*w)],[2*(x*y+z*w),1-2*(x*x+z*z),2*(y*z-x*w)],[2*(x*z-y*w),2*(y*z+x*w),1-2*(x*x+y*y)]])
    m=np.eye(4);m[:3,:3]=r@np.diag(n.get('scale',[1,1,1]));m[:3,3]=n.get('translation',[0,0,0]);return m
def sample(path):
    d,b=load(path); assert not d.get('meshes') and len(d['animations'])==1
    a=d['animations'][0]; names=[n.get('name',str(i)) for i,n in enumerate(d['nodes'])]
    parents={c:i for i,n in enumerate(d['nodes']) for c in n.get('children',[])}
    joint_ids=d['skins'][0]['joints']; joints=[names[i] for i in joint_ids]; assert len(set(joints))==24
    channels=[]
    for c in a['channels']:
        s=a['samplers'][c['sampler']]; times=accessor(d,b,s['input'])[:,0]
        assert len(times)==61 and np.max(np.abs(times-np.arange(61)/30))<1e-6
        channels.append((c['target'],accessor(d,b,s['output'])))
    frames=[]
    for f in range(61):
        ns=[dict(n) for n in d['nodes']]
        for target,values in channels:
            n=ns[target['node']]; n.pop('matrix',None); n[target['path']]=values[f].tolist()
        cache={}
        def world(i):
            if i not in cache:cache[i]=(world(parents[i]) if i in parents else np.eye(4))@matrix(ns[i])
            return cache[i]
        frames.append({n:world(i).tolist() for i,n in enumerate(names)})
    worlds=np.array([[frames[f][n] for n in joints] for f in range(61)])
    p=lambda f,n:np.array(frames[f][n])[:3,3]
    feet={n:max(float(np.linalg.norm(p(f,n)-p(0,n))) for f in range(61)) for n in ['LeftFoot','RightFoot','LeftToeBase','RightToeBase']}
    lengths={n:float(np.ptp([np.linalg.norm(p(f,n)-p(f,names[parents[i]])) for f in range(61)])) for i,n in enumerate(names) if i in joint_ids and parents.get(i) in joint_ids}
    def rotation(f,n):
        u,_,vt=np.linalg.svd(np.array(frames[f][n])[:3,:3]);return u@vt
    steps={n: max(math.degrees(math.acos(float(np.clip((np.trace(rotation(f-1,n).T@rotation(f,n))-1)/2,-1,1)))) for f in range(1,61)) for n in joints}
    width=[float(np.linalg.norm(p(f,'LeftArm')-p(f,'RightArm'))) for f in range(61)]
    return {'file':str(path),'sha256':hashlib.sha256(Path(path).read_bytes()).hexdigest(),'bytes':Path(path).stat().st_size,'frames':61,'duration_s':2.,'joints':joints,'parents':{names[i]:names[parents[i]] if parents.get(i) in joint_ids else '' for i in joint_ids},'max_foot_drift_m':feet,'max_segment_length_variation_m':max(lengths.values()),'segment_variation_m':lengths,'max_rotation_steps_deg':steps,'shoulder_width_m':[min(width),max(width)],'max_scale_error':float(np.max(np.abs(np.linalg.norm(worlds[:,:,:3,:3],axis=2)-1))),'world_frames':frames}
def compare(a,b):
    names=a['joints']; assert set(names)==set(b['joints']) and a['parents']==b['parents']
    wa=np.array([[f[n] for n in names] for f in a['world_frames']]); wb=np.array([[f[n] for n in names] for f in b['world_frames']])
    return {'max_position_difference_m':float(np.max(np.linalg.norm(wa[:,:,:3,3]-wb[:,:,:3,3],axis=-1))),'max_basis_coefficient_difference':float(np.max(np.abs(wa[:,:,:3,:3]-wb[:,:,:3,:3])))}
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('input',type=Path);p.add_argument('output',type=Path);p.add_argument('--compare',type=Path);a=p.parse_args()
    assert not a.output.exists(); result=sample(a.input)
    if a.compare:result['comparison']=compare(sample(a.compare),result)
    a.output.write_text(json.dumps(result,indent=2));print(json.dumps({k:v for k,v in result.items() if k not in ('world_frames','segment_variation_m','joints','parents')},indent=2))

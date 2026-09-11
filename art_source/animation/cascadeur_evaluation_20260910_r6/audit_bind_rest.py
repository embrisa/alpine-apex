"""Compare exported inverse-bind frames to the unchanged production body."""
import json
from pathlib import Path
from audit_animation import load,accessor,matrix,np
root=Path(__file__).resolve().parent;project=root.parents[2]
def rest(path):
    d,b=load(path);skin=d['skins'][0]
    if 'inverseBindMatrices' in skin:
        matrices=accessor(d,b,skin['inverseBindMatrices']).reshape(-1,4,4).transpose(0,2,1)
        return {d['nodes'][node]['name']:np.linalg.inv(matrices[i]) for i,node in enumerate(skin['joints'])}
    parents={c:i for i,n in enumerate(d['nodes']) for c in n.get('children',[])};cache={}
    def world(i):
        if i not in cache:cache[i]=(world(parents[i]) if i in parents else np.eye(4))@matrix(d['nodes'][i])
        return cache[i]
    return {d['nodes'][node]['name']:world(node) for node in skin['joints']}
a=rest(project/'assets/graphics/models/skier_v7.glb');b=rest(root/'ready_compression_r6_animation.glb')
assert a.keys()==b.keys()
out={'scope':'Original body inverse-bind rest versus exported default node frames. Animation-only GLB has no inverse-bind matrices; original body supplies skin and bind axes.','names_match':True,'joints':len(a),'max_bind_position_difference_m':max(float(np.linalg.norm(a[n][:3,3]-b[n][:3,3])) for n in a),'max_bind_basis_coefficient_difference':max(float(np.max(np.abs(a[n][:3,:3]-b[n][:3,:3]))) for n in a)}
out['passed']=out['max_bind_position_difference_m']<.0001 and out['max_bind_basis_coefficient_difference']<.0001
p=root/'bind_rest_audit.json';assert not p.exists();p.write_text(json.dumps(out,indent=2));print(json.dumps(out,indent=2))

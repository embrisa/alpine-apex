"""Refine large collision proxies in metres with CoACD (offline only)."""
from pathlib import Path
import json
import sys
import os
import subprocess
from concurrent.futures import ThreadPoolExecutor
import coacd
import numpy as np

ROOT=Path(__file__).resolve().parents[2]
source=json.loads((ROOT/'assets/graphics/minerals_v3/manifest.json').read_text())
worker_option=next((a for a in sys.argv[1:] if a.startswith('--workers=')),None)
if worker_option:
    jobs=[r['asset'] for r in source['assets'] if r['category'] not in ('small','medium')]
    log_dir=ROOT/'artifacts/geology_v11/proxy_bakes'
    log_dir.mkdir(parents=True,exist_ok=True)
    def bake(asset):
        environment=dict(os.environ,OMP_NUM_THREADS='2')
        with (log_dir/f'{asset}.log').open('w') as log:
            options=[a for a in sys.argv[1:] if a.startswith('--tolerance=') or a=='--fast']
            result=subprocess.run([sys.executable,str(Path(__file__).resolve()),asset]+options,
                                  stdout=log,stderr=subprocess.STDOUT,env=environment,
                                  creationflags=subprocess.CREATE_NO_WINDOW if os.name=='nt' else 0)
        print('PROXY_JOB',asset,'exit',result.returncode,flush=True)
        return result.returncode
    with ThreadPoolExecutor(max_workers=int(worker_option.split('=')[1])) as executor:
        results=list(executor.map(bake,jobs))
    sys.exit(1 if any(results) else 0)
coacd.set_log_level('info')
tolerance=float(next((a.split('=')[1] for a in sys.argv if a.startswith('--tolerance=')),'.5'))
fast_search='--fast' in sys.argv
pca_alignment='--pca' in sys.argv
for original in source['assets']:
    if len(sys.argv)>1 and original['asset'] not in sys.argv[1:]:
        continue
    path=ROOT/'assets/graphics/geology_v11/collision'/f"{original['asset']}.json"
    row=json.loads(path.read_text())
    if row['category'] in ('small','medium') or (row.get('collision_bake_version',0)>=3 and '--force' not in sys.argv):
        continue
    print('REFINE_PROXY',row['id'],flush=True)
    prepared=np.load(ROOT/'artifacts/geology_v11/proxy_input'/f"{row['id']}.npz")
    vertices=prepared['vertices']; faces=prepared['faces']
    # Authored formations contain intersecting closed lobes. Decomposing their
    # union forces a voxel remesh that can seal splits; keep each component.
    parent=list(range(len(vertices)))
    def root(index):
        while parent[index]!=index:
            parent[index]=parent[parent[index]]
            index=parent[index]
        return index
    for a,b,c in faces:
        a,b,c=root(int(a)),root(int(b)),root(int(c))
        parent[b]=a; parent[c]=a
    groups={}
    for face in faces:
        groups.setdefault(root(int(face[0])),[]).append(face)
    print('PROXY_COMPONENTS',len(groups),flush=True)
    parts=[]
    for triangles in groups.values():
        used,index=np.unique(np.asarray(triangles),return_inverse=True)
        component=vertices[used]
        if len(component)<4:
            continue
        parts.extend(coacd.run_coacd(coacd.Mesh(component,index.reshape(-1,3)),threshold=tolerance,real_metric=True,
                         preprocess_mode='auto',preprocess_resolution=50,
                         resolution=2000,mcts_iterations=2 if fast_search else 20,mcts_max_depth=1 if fast_search else 2,
                         mcts_nodes=4 if fast_search else 8,pca=pca_alignment,merge=not fast_search,decimate=True,max_ch_vertex=64,seed=849205174))
    assert parts,row['id']
    row['hulls']=[points.tolist() for points,_ in parts]
    row.pop('empty_volume_repairs',None)
    row['collision_bake_version']=3
    row['collision_method']=f'CoACD 1.0.14; {tolerance} m; seed 849205174; '+('unmerged greedy search' if fast_search else 'tree search')
    if pca_alignment: row['collision_method']+='; principal-axis preparation'
    destination=next((a.split('=',1)[1] for a in sys.argv if a.startswith('--destination=')),None)
    if destination:
        path=ROOT/destination/path.name
        path.parent.mkdir(parents=True,exist_ok=True)
    temporary=path.with_suffix('.json.tmp')
    temporary.write_text(json.dumps(row,separators=(',',':')))
    temporary.replace(path)
    print('REFINED_PROXY',row['id'],len(parts),'hulls',flush=True)

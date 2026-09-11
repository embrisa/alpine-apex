"""Read-only Blender audit of rider-sized openings against source triangles.

Run with Blender --background --factory-startup --python this_file. Samples
interior grid points in concave macro assets, checks source BVH occupancy and
nearest-surface clearance, then tests the baked convex union independently.
This is a sampled audit, not a proof of exact triangle equivalence.
"""
from pathlib import Path
import json
import hashlib
import struct
import sys
import bmesh
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree

ROOT = Path(__file__).resolve().parents[1]
source = json.loads((ROOT/'assets/graphics/minerals_v3/manifest.json').read_text())
catalog = {r['id']: r for r in json.loads((ROOT/'assets/graphics/geology_v11/catalog.json').read_text())['assets']}
reports = []
failures = []
options=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
selected=[a for a in options if a.startswith('mineral_')]
output_option=next((a.split('=',1)[1] for a in options if a.startswith('--output=')),'artifacts/geology_v11/proxy_audit.json')
audit_code_sha=hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
cache_directory=ROOT/'artifacts/geology_v11/source_audit_cache'
cache_directory.mkdir(parents=True,exist_ok=True)
for original in source['assets']:
    row = catalog[original['asset']]
    if selected and row['id'] not in selected:
        continue
    row = json.loads((ROOT/'assets/graphics/geology_v11/collision'/f"{row['id']}.json").read_text())
    raw = (ROOT/original['path']).read_bytes()
    assert hashlib.sha256(raw).hexdigest()==original['sha256'],row['id']+' source changed'
    proxy_sha=hashlib.sha256(json.dumps(row['hulls'],separators=(',',':')).encode()).hexdigest()
    cache_path=cache_directory/(row['id']+'.json')
    if cache_path.exists():
        cached=json.loads(cache_path.read_text())
        if cached.get('audit_code_sha256')==audit_code_sha and cached['proxy_sha256']==proxy_sha and cached['source_sha256']==original['sha256']:
            reports.append(cached)
            if cached['blocked_samples']: failures.append(row['id'])
            print('CACHED_PROXY_AUDIT',row['id'],len(cached['blocked_samples']),'blocked',flush=True)
            continue
    length = struct.unpack_from('<I', raw, 12)[0]
    gltf = json.loads(raw[20:20+length])
    def accessor(index):
        a = gltf['accessors'][index]
        v = gltf['bufferViews'][a['bufferView']]
        dtype = {5126:'<f4',5125:'<u4',5123:'<u2'}[a['componentType']]
        width = {'VEC3':3,'SCALAR':1}[a['type']]
        offset = 28+length+v.get('byteOffset',0)+a.get('byteOffset',0)
        step = v.get('byteStride',np.dtype(dtype).itemsize*width)
        return np.ndarray((a['count'],width),dtype=dtype,buffer=raw,offset=offset,strides=(step,np.dtype(dtype).itemsize))
    primitive = gltf['meshes'][0]['primitives'][0]
    vertices = accessor(primitive['attributes']['POSITION'])
    triangles = accessor(primitive['indices']).reshape(-1,3)
    vertices,inverse=np.unique(vertices,axis=0,return_inverse=True)
    triangles=inverse[triangles]
    tree = BVHTree.FromPolygons(vertices.tolist(), triangles.tolist(), all_triangles=True)
    parent=list(range(len(vertices)))
    def root(index):
        while parent[index]!=index:
            parent[index]=parent[parent[index]]
            index=parent[index]
        return index
    for a,b,c in triangles:
        a,b,c=root(int(a)),root(int(b)),root(int(c))
        parent[b]=a;parent[c]=a
    groups={}
    for face in triangles:
        groups.setdefault(root(int(face[0])),[]).append(face.tolist())
    component_trees=[BVHTree.FromPolygons(vertices.tolist(),faces,all_triangles=True) for faces in groups.values()]
    low, high = vertices.min(axis=0), vertices.max(axis=0)
    hull_spans = []
    rider_half = np.array([.35,.8,.35])
    for hull in row['hulls']:
        bm = bmesh.new()
        for p in hull:
            bm.verts.new(p)
        bmesh.ops.convex_hull(bm,input=list(bm.verts),use_existing_faces=False)
        bm.normal_update()
        # Full box/convex SAT, including edge cross axes: checking only the
        # centre misses pieces that obstruct the rider's shoulders or head.
        axes = [list(f.normal) for f in bm.faces] + np.eye(3).tolist()
        for edge in bm.edges:
            direction = np.array(edge.verts[0].co)-np.array(edge.verts[1].co)
            for axis in np.eye(3):
                cross = np.cross(direction,axis)
                length = np.linalg.norm(cross)
                if length>1e-8: axes.append((cross/length).tolist())
        axes = np.unique(np.round(np.array(axes),7),axis=0)
        points = np.array(hull)
        projections = axes @ points.T
        margin = np.abs(axes) @ rider_half
        hull_spans.append((points.min(axis=0)-rider_half,points.max(axis=0)+rider_half,
                           axes,projections.min(axis=1)-margin,projections.max(axis=1)+margin))
        bm.free()
    hull_lows=np.array([s[0] for s in hull_spans])
    hull_highs=np.array([s[1] for s in hull_spans])
    # Centre must fit a 0.7 x 1.6 x 0.7 m rider, with extra surface margin.
    clearance = 1.0
    free = []
    blocked = []
    ambiguous = 0
    directions = [Vector(v).normalized() for v in [(.137,.963,.232),(.897,.153,.413),(-.385,.811,.44)]]
    def source_inside(p, direction):
        for component_tree in component_trees:
            cursor=Vector(p)
            crossings=0
            for crossing in range(64):
                hit, _, _, _=component_tree.ray_cast(cursor,direction)
                if hit is None:
                    break
                crossings+=1
                cursor=hit+direction*.001
            if crossings%2:
                return True
        return False
    for x in np.linspace(low[0],high[0],19)[1:-1]:
        for y in np.linspace(low[1],high[1],19)[1:-1]:
            for z in np.linspace(low[2],high[2],19)[1:-1]:
                p = (float(x),float(y),float(z))
                if source_inside(p,directions[0]):
                    continue
                _, _, _, distance = tree.find_nearest(p)
                if distance is None or distance<clearance:
                    continue
                # Grazing a source triangle edge can change ray parity. Require
                # agreement from three directions before declaring empty space.
                if any(source_inside(p,d) for d in directions[1:]):
                    ambiguous+=1
                    continue
                free.append(p)
                def rider_blocked(index):
                    _,_,axes,span_low,span_high=hull_spans[index]
                    projected=axes@p
                    return np.all(projected>=span_low-1e-5) and np.all(projected<=span_high+1e-5)
                candidates=np.flatnonzero(np.all(p>=hull_lows,axis=1)&np.all(p<=hull_highs,axis=1))
                if any(rider_blocked(index) for index in candidates):
                    blocked.append({'position':p,'source_clearance_m':distance})
    report = {'asset':row['id'],'hulls':len(row['hulls']),'source_sha256':original['sha256'],
              'proxy_sha256':proxy_sha,'audit_code_sha256':audit_code_sha,
              'rider_sized_free_samples':len(free),'ambiguous_candidate_samples':ambiguous,'blocked_samples':blocked}
    reports.append(report)
    cache_path.write_text(json.dumps(report,separators=(',',':')))
    if blocked:
        failures.append(row['id'])
    print('PROXY_OPENINGS',row['id'],len(free),'free;',len(blocked),'blocked',flush=True)
output = ROOT/output_option
output.parent.mkdir(parents=True,exist_ok=True)
output.write_text(json.dumps({'clearance_m':1.0,'rider_size_m':[.7,1.6,.7],'grid_per_axis':19,'assets':reports,'failures':failures},indent=2))
assert not failures, failures

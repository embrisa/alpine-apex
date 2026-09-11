"""Blender background: derive convex SAT axes from the offline Godot hulls.

No source scene is opened or saved. BMesh only operates on disposable hull data.
"""
from pathlib import Path
import bmesh
import hashlib
import json
import math
import struct
import sys
import numpy as np
from mathutils.bvhtree import BVHTree

ROOT = Path(__file__).resolve().parents[2]
PACK = ROOT / 'assets/graphics/geology_v11'


def unique_axis(values):
    axes = {}
    for value in values:
        if value.length < 1e-8:
            continue
        n = value.normalized()
        for component in n:
            if abs(component) > 1e-6:
                if component < 0:
                    n = -n
                break
        axes[tuple(round(x, 5) for x in n)] = list(n)
    return [axes[key] for key in sorted(axes)]


records = []
source = json.loads((ROOT/'assets/graphics/minerals_v3/manifest.json').read_text())
for original in source['assets']:
    path = PACK/'collision'/f"{original['asset']}.json"
    row = json.loads(path.read_text())
    # Half-space intersections can leave numerical line/plane remnants. They
    # are not solid convex volumes and Jolt cannot build them. Reject by rank
    # around the centroid; a global-origin volume sum is unstable for slivers.
    valid_hulls=[]
    for points in row['hulls']:
        cloud=np.asarray(points)
        singular=np.linalg.svd(cloud-cloud.mean(axis=0),compute_uv=False)
        if singular[-1]>=max(1e-4,singular[0]*1e-7): valid_hulls.append(points)
    if '--reuse-prepared' in sys.argv and len(valid_hulls)==len(row['hulls']) and row.get('hull_axes'):
        records.append(row)
        continue
    row['discarded_degenerate_pieces']=row.get('discarded_degenerate_pieces',0)+len(row['hulls'])-len(valid_hulls)
    row['hulls']=valid_hulls
    assert valid_hulls,row['id']
    # Dense underside samples, not just the lowest vertex in a broad bucket.
    # Sparse seating missed intermediate foundations on 150-220 m formations.
    raw = (ROOT/original['path']).read_bytes()
    json_size = struct.unpack_from('<I', raw, 12)[0]
    gltf = json.loads(raw[20:20+json_size])
    binary_start = 20+json_size+8
    def accessor(index):
        a = gltf['accessors'][index]; view = gltf['bufferViews'][a['bufferView']]
        dtype = {5126:'<f4',5125:'<u4',5123:'<u2'}[a['componentType']]
        width = {'VEC3':3,'SCALAR':1}[a['type']]
        offset = binary_start+view.get('byteOffset',0)+a.get('byteOffset',0)
        step = view.get('byteStride',np.dtype(dtype).itemsize*width)
        return np.ndarray((a['count'],width),dtype=dtype,buffer=raw,offset=offset,strides=(step,np.dtype(dtype).itemsize))
    primitive = gltf['meshes'][0]['primitives'][0]
    vertices = accessor(primitive['attributes']['POSITION'])
    faces = accessor(primitive['indices']).reshape(-1,3)
    tree = BVHTree.FromPolygons(vertices.tolist(),faces.tolist(),all_triangles=True)
    low = vertices.min(axis=0); high = vertices.max(axis=0)
    assert abs((high[1]-low[1])-row['size'][1]) < .03, row['id']
    nx = max(16,math.ceil((high[0]-low[0])/2))
    nz = max(16,math.ceil((high[2]-low[2])/2))
    footprint = []
    for z in range(nz+1):
        for x in range(nx+1):
            p = (float(low[0]+(high[0]-low[0])*x/nx),float(low[1]-1),float(low[2]+(high[2]-low[2])*z/nz))
            location,_,_,_ = tree.ray_cast(p,(0,1,0),float(high[1]-low[1]+2))
            seating_ceiling = row['size'][1]*(1.0 if row['family']=='glacier' else .35)
            if location is not None and location.y <= seating_ceiling:
                footprint.append(list(location))
    # Include silhouette boundary samples where a grid ray can miss a thin edge.
    grid_x = np.clip(((vertices[:,0]-low[0])/(high[0]-low[0])*16).astype(int),0,16)
    grid_z = np.clip(((vertices[:,2]-low[2])/(high[2]-low[2])*16).astype(int),0,16)
    order = np.argsort(vertices[:,1],kind='stable')
    _, first = np.unique((grid_x+17*grid_z)[order],return_index=True)
    footprint += [p.tolist() for p in vertices[order[first]] if p[1] <= seating_ceiling]
    row['footprint'] = footprint
    assert footprint,row['id']
    row['hull_axes'] = []
    for points in row['hulls']:
        bm = bmesh.new()
        for point in points:
            bm.verts.new(point)
        bmesh.ops.convex_hull(bm, input=list(bm.verts), use_existing_faces=False)
        bm.normal_update()
        row['hull_axes'].append({
            'normals': unique_axis(face.normal for face in bm.faces),
            'edges': unique_axis(edge.verts[1].co-edge.verts[0].co for edge in bm.edges),
        })
        assert row['hull_axes'][-1]['normals'], row['id']
        bm.free()
    physical = {'hulls': row['hulls'], 'axes': row['hull_axes'], 'footprint': row['footprint']}
    row['collision_sha256'] = hashlib.sha256(json.dumps(physical, sort_keys=True, separators=(',', ':')).encode()).hexdigest()
    path.write_text(json.dumps(row, separators=(',', ':')))
    records.append(row)
assert len(records) == 120
(PACK/'catalog.json').write_text(json.dumps({'version': 1, 'assets': records}, separators=(',', ':')))
print('GEOLOGY_CATALOG',len(records),'assets',sum(len(r['hulls']) for r in records),'hulls')

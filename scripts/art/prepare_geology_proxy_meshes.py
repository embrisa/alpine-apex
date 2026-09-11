"""Blender background: simplify disposable collision input, preserving sources."""
from pathlib import Path
import json
import struct
import sys
import bpy
import bmesh
import numpy as np
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'artifacts/geology_v11/proxy_input'
OUT.mkdir(parents=True,exist_ok=True)
source=json.loads((ROOT/'assets/graphics/minerals_v3/manifest.json').read_text())
options=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
target_triangles=int(next((a.split('=')[1] for a in options if a.startswith('--triangles=')),'4000'))
selected=[a for a in options if a.startswith('mineral_')]
for row in source['assets']:
    if selected and row['asset'] not in selected:
        continue
    if row['category'] in ('small','medium'):
        continue
    raw=(ROOT/row['path']).read_bytes()
    size=struct.unpack_from('<I',raw,12)[0]
    gltf=json.loads(raw[20:20+size])
    def accessor(index):
        a=gltf['accessors'][index];v=gltf['bufferViews'][a['bufferView']]
        dtype={5126:'<f4',5125:'<u4',5123:'<u2'}[a['componentType']]
        width={'VEC3':3,'SCALAR':1}[a['type']]
        start=28+size+v.get('byteOffset',0)+a.get('byteOffset',0)
        stride=v.get('byteStride',np.dtype(dtype).itemsize*width)
        return np.ndarray((a['count'],width),dtype=dtype,buffer=raw,offset=start,strides=(stride,np.dtype(dtype).itemsize))
    primitive=gltf['meshes'][0]['primitives'][0]
    vertices=accessor(primitive['attributes']['POSITION'])
    faces=accessor(primitive['indices']).reshape(-1,3)
    vertices,inverse=np.unique(vertices,axis=0,return_inverse=True)
    faces=inverse[faces]
    mesh=bpy.data.meshes.new('Disposable collision preparation')
    mesh.from_pydata(vertices.tolist(),[],faces.tolist())
    mesh.update()
    obj=bpy.data.objects.new('Disposable collision preparation',mesh)
    bpy.context.collection.objects.link(obj)
    modifier=obj.modifiers.new('Collision simplification','DECIMATE')
    modifier.ratio=min(1.0,target_triangles/len(faces))
    modifier.use_collapse_triangulate=True
    bpy.context.view_layer.update()
    evaluated=obj.evaluated_get(bpy.context.evaluated_depsgraph_get())
    result=evaluated.to_mesh()
    # The disposable decimation can retain inconsistent triangle winding.
    # Repair orientation before CoACD; otherwise its voxel fallback expands a
    # 4k-triangle input to tens of thousands of triangles and seals fine gaps.
    bm=bmesh.new(); bm.from_mesh(result)
    # Remove zero-volume triangular fins left by decimation. These triangles
    # have two open edges and make an otherwise closed component non-manifold.
    # This changes only the disposable collision input, never the source GLB.
    for _ in range(4):
        fins=[face for face in bm.faces if sum(edge.is_boundary for edge in face.edges)>=2]
        if not fins: break
        bmesh.ops.delete(bm,geom=fins,context='FACES')
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    bm.to_mesh(result); bm.free()
    result.calc_loop_triangles()
    v=np.array([list(v.co) for v in result.vertices],dtype=np.float64)
    f=np.array([list(t.vertices) for t in result.loop_triangles],dtype=np.int32)
    np.savez(OUT/f"{row['asset']}.npz",vertices=v,faces=f)
    evaluated.to_mesh_clear()
    bpy.data.objects.remove(obj,do_unlink=True)
    bpy.data.meshes.remove(mesh)
    print('PROXY_INPUT',row['asset'],len(f),'triangles',flush=True)

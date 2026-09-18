"""Reduce a texture-free Meshy pre-remesh GLB, preserving curved source volume.

Run with NumPy + fast-simplification 0.1.13 under an Exclusive guard. Output is a
new clay GLB; transfer textures separately, then review before game integration.
"""
import argparse
import gc
import json
import mmap
import struct
from pathlib import Path
import numpy as np
import fast_simplification

parser = argparse.ArgumentParser()
parser.add_argument('source', type=Path)
parser.add_argument('output', type=Path)
parser.add_argument('--triangles', type=int, default=40000)
args = parser.parse_args()
assert args.source.resolve() != args.output.resolve()
with args.source.open('rb') as stream:
    raw = mmap.mmap(stream.fileno(), 0, access=mmap.ACCESS_READ)
    size = struct.unpack_from('<I', raw, 12)[0]
    doc = json.loads(raw[20:20+size]); start = 28+size
    assert len(doc['meshes']) == 1 and len(doc['meshes'][0]['primitives']) == 1
    primitive = doc['meshes'][0]['primitives'][0]
    assert all(k in ['POSITION','NORMAL'] for k in primitive['attributes'])
    def array(index):
        spec=doc['accessors'][index]; view=doc['bufferViews'][spec['bufferView']]
        dtype={5126:'<f4',5125:'<u4',5123:'<u2'}[spec['componentType']]
        width={'SCALAR':1,'VEC3':3}[spec['type']]
        return np.ndarray((spec['count'],width),dtype=dtype,buffer=raw,
            offset=start+view.get('byteOffset',0)+spec.get('byteOffset',0),
            strides=(view.get('byteStride',np.dtype(dtype).itemsize*width),np.dtype(dtype).itemsize))
    vertex=array(primitive['attributes']['POSITION'])
    face=array(primitive['indices']).reshape(-1,3)
    original_faces=len(face); original_vertices=len(vertex)
    print('RAW_REDUCE weld', original_vertices, original_faces, flush=True)
    # Normals may split records. This source has no UV/material/branch seams.
    # Weld exact positions only; no spatial rounding or surface resampling.
    positions, inverse=np.unique(vertex,axis=0,return_inverse=True)
    triangles=inverse[face].astype(np.int32)
    del inverse,vertex,face
    raw.close()
gc.collect()
print('RAW_REDUCE collapse',len(positions),len(triangles),'target',args.triangles,flush=True)
positions,triangles=fast_simplification.simplify(positions,triangles,target_count=args.triangles,agg=7.0)
positions=positions.astype('<f4');triangles=triangles.astype('<u4')
normal=np.zeros_like(positions)
cross=np.cross(positions[triangles[:,1]]-positions[triangles[:,0]],positions[triangles[:,2]]-positions[triangles[:,0]])
for column in range(3): np.add.at(normal,triangles[:,column],cross)
normal/=np.maximum(np.linalg.norm(normal,axis=1)[:,None],1e-20)
parts=[positions.tobytes(),normal.tobytes(),triangles.tobytes()]
views=[];offset=0
for part in parts:
    views.append(dict(buffer=0,byteOffset=offset,byteLength=len(part)));offset+=len(part)
result=dict(asset=dict(version='2.0',generator='Alpine Apex raw-volume reduction'),
    buffers=[dict(byteLength=offset)],bufferViews=views,
    accessors=[dict(bufferView=0,componentType=5126,count=len(positions),type='VEC3',min=positions.min(axis=0).tolist(),max=positions.max(axis=0).tolist()),
      dict(bufferView=1,componentType=5126,count=len(normal),type='VEC3'),
      dict(bufferView=2,componentType=5125,count=triangles.size,type='SCALAR')],
    meshes=[dict(primitives=[dict(attributes=dict(POSITION=0,NORMAL=1),indices=2,material=0)])],
    nodes=[dict(mesh=0)],scenes=[dict(nodes=[0])],scene=0,
    materials=[dict(pbrMetallicRoughness=dict(baseColorFactor=[.7,.7,.7,1],metallicFactor=0,roughnessFactor=1),doubleSided=True)])
encoded=json.dumps(result,separators=(',',':')).encode();encoded+=b' '*(-len(encoded)%4)
blob=b''.join(parts);blob+=b'\0'*(-len(blob)%4)
args.output.parent.mkdir(parents=True,exist_ok=True)
args.output.write_bytes(struct.pack('<4sII',b'glTF',2,28+len(encoded)+len(blob))+struct.pack('<I4s',len(encoded),b'JSON')+encoded+struct.pack('<I4s',len(blob),b'BIN\0')+blob)
report=dict(source=str(args.source),output=str(args.output),source_triangles=original_faces,source_vertices=original_vertices,
    triangles=len(triangles),vertices=len(positions),target_triangles=args.triangles,
    method='Exact-position weld, Fast-Quadric simplification agg7, smooth area-weighted normals; texture-free',production_acceptance=False)
args.output.with_suffix('.json').write_text(json.dumps(report,indent=2)+'\n')
print('RAW_REDUCE_DONE',json.dumps(report),flush=True)

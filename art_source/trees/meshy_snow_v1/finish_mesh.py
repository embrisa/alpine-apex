"""Bounded snow-surface relaxation and seam-aware normals for a Meshy GLB.

Works offline on a new output. Keeps indices, UVs, materials and embedded images.
Coincident corners move together; opposite-facing sheets keep separate normals.
Run with the art Python environment (NumPy/Pillow), under an Exclusive guard.
"""
import argparse
import io
import json
import struct
from pathlib import Path
import numpy as np
from PIL import Image

parser = argparse.ArgumentParser()
parser.add_argument('source', type=Path)
parser.add_argument('output', type=Path)
parser.add_argument('--relax', type=float, default=0.0125,
                    help='Maximum displacement as a fraction of tree height')
args = parser.parse_args()
assert args.source.resolve() != args.output.resolve()
raw = args.source.read_bytes()
json_size = struct.unpack_from('<I', raw, 12)[0]
doc = json.loads(raw[20:20 + json_size])
blob = bytearray(raw[28 + json_size:])

def accessor(index):
    spec = doc['accessors'][index]; view = doc['bufferViews'][spec['bufferView']]
    dtype = {5126:'<f4', 5125:'<u4', 5123:'<u2', 5121:'u1'}[spec['componentType']]
    dimension = {'SCALAR':1, 'VEC2':2, 'VEC3':3, 'VEC4':4}[spec['type']]
    return np.ndarray((spec['count'], dimension), dtype=dtype, buffer=blob,
        offset=view.get('byteOffset', 0) + spec.get('byteOffset', 0),
        strides=(view.get('byteStride', np.dtype(dtype).itemsize * dimension),
                 np.dtype(dtype).itemsize))

assert len(doc['meshes']) == 1 and len(doc['meshes'][0]['primitives']) == 1
primitive = doc['meshes'][0]['primitives'][0]
vertex = accessor(primitive['attributes']['POSITION'])
normal = accessor(primitive['attributes']['NORMAL'])
uv = accessor(primitive['attributes']['TEXCOORD_0'])
triangles = accessor(primitive['indices']).reshape(-1, 3)
original = vertex.copy(); original_normal = normal.copy()
positions, inverse = np.unique(vertex, axis=0, return_inverse=True)
height = float(np.ptp(vertex[:, 1]))
topology = inverse[triangles]
edges = np.concatenate((topology[:, [0,1]], topology[:, [1,2]], topology[:, [2,0]]))
edges = np.unique(np.sort(edges, axis=1), axis=0)
edges = np.concatenate((edges, edges[:, ::-1]))
degree = np.bincount(edges[:, 0], minlength=len(positions))

material = doc['materials'][primitive['material']]
texture = doc['textures'][material['pbrMetallicRoughness']['baseColorTexture']['index']]
view = doc['bufferViews'][doc['images'][texture['source']]['bufferView']]
offset = view.get('byteOffset', 0)
pixels = np.asarray(Image.open(io.BytesIO(blob[offset:offset + view['byteLength']])).convert('RGB')) / 255.0
xy = (np.clip(uv, 0, 1) * [pixels.shape[1] - 1, pixels.shape[0] - 1]).astype(int)
color = pixels[xy[:, 1], xy[:, 0]]
snow = np.clip((color.min(axis=1) - .48) / .25, 0, 1)
snow *= np.clip(1 - (color.max(axis=1) - color.min(axis=1)) / .25, 0, 1)
weight = np.zeros(len(positions)); np.maximum.at(weight, inverse, snow)
weight[positions[:, 1] < positions[:, 1].min() + height * .10] = 0
start = positions.copy()
for iteration in range(8):
    neighbors = np.zeros_like(positions)
    np.add.at(neighbors, edges[:, 0], positions[edges[:, 1]])
    delta = neighbors / np.maximum(degree[:, None], 1) - positions
    positions += delta * weight[:, None] * (.48 if iteration % 2 == 0 else -.50)
    displacement = positions - start
    length = np.linalg.norm(displacement, axis=1)
    positions = start + displacement * np.minimum(1, height * args.relax / np.maximum(length, 1e-20))[:, None]
vertex[:] = positions[inverse]

cross = np.cross(vertex[triangles[:, 1]] - vertex[triangles[:, 0]],
                 vertex[triangles[:, 2]] - vertex[triangles[:, 0]])
length = np.linalg.norm(cross, axis=1)
direction = cross / np.maximum(length[:, None], 1e-20)
incident = [[] for _ in positions]
for face, corners in enumerate(topology):
    for corner in corners:
        incident[corner].append(face)
for index, group in enumerate(inverse):
    faces = np.asarray(incident[group])
    faces = faces[direction[faces] @ original_normal[index] > .05]
    total = cross[faces].sum(axis=0)
    magnitude = np.linalg.norm(total)
    if magnitude > 1e-12:
        normal[index] = total / magnitude

# Tangents describe the old normals. Godot regenerates them for the finished mesh.
# Omit rather than exporting an inconsistent tangent frame.
primitive['attributes'].pop('TANGENT', None)
pos_spec = doc['accessors'][primitive['attributes']['POSITION']]
pos_spec['min'] = vertex.min(axis=0).tolist(); pos_spec['max'] = vertex.max(axis=0).tolist()
encoded = json.dumps(doc, separators=(',', ':')).encode()
encoded += b' ' * (-len(encoded) % 4)
blob += b'\x00' * (-len(blob) % 4)
result = struct.pack('<4sII', b'glTF', 2, 28 + len(encoded) + len(blob))
result += struct.pack('<I4s', len(encoded), b'JSON') + encoded
result += struct.pack('<I4s', len(blob), b'BIN\x00') + blob
args.output.parent.mkdir(parents=True, exist_ok=True)
args.output.write_bytes(result)
report = {'source':str(args.source), 'output':str(args.output), 'triangles':len(triangles),
    'vertices':len(vertex), 'relax_height_fraction':args.relax,
    'max_displacement_at_12m':float(np.linalg.norm(vertex-original, axis=1).max()/height*12),
    'method':'Snow-only bounded Taubin relaxation; same-hemisphere area-weighted seam normals',
    'production_acceptance':False}
args.output.with_suffix('.json').write_text(json.dumps(report, indent=2) + '\n')
print(json.dumps(report))

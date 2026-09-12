"""Independent GLB structure and Blender reimport checks; no game integration."""
import hashlib
import json
import math
from pathlib import Path
import struct
import sys
import argparse
import bpy

ROOT = Path(__file__).resolve().parents[2]
parser = argparse.ArgumentParser()
parser.add_argument('--kind',choices=['grass','plants'],default='grass')
args = parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
PLANTS = args.kind == 'plants'
PACK = ROOT/('art_source/foliage/plants_v1' if PLANTS else 'art_source/foliage/grass_v1')
ROLE = 'plant_only' if PLANTS else 'grass_only'
catalog = json.loads((PACK/'manifest.json').read_text())
assert catalog['status'] == 'prepared_only_not_integrated'
assert (PACK/'.gdignore').exists()
assert not catalog['rock_geometry'] and not catalog['collision']
assert len(catalog['assets']) == 18


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def decode_glb(path):
    raw = path.read_bytes()
    magic, version, length = struct.unpack_from('<III', raw)
    assert magic == 0x46546C67 and version == 2 and length == len(raw)
    jl, jt = struct.unpack_from('<II', raw, 12)
    assert jt == 0x4E4F534A
    data = json.loads(raw[20:20+jl])
    bl, bt = struct.unpack_from('<II', raw, 20+jl)
    assert bt == 0x004E4942
    return data, raw[28+jl:28+jl+bl]


def floats(data, blob, index):
    acc = data['accessors'][index]
    assert acc['componentType'] == 5126
    width = {'SCALAR':1, 'VEC2':2, 'VEC3':3, 'VEC4':4}[acc['type']]
    view = data['bufferViews'][acc['bufferView']]
    start = view.get('byteOffset',0)+acc.get('byteOffset',0)
    stride = view.get('byteStride',width*4)
    return [struct.unpack_from('<'+'f'*width, blob, start+i*stride) for i in range(acc['count'])]


for entry in catalog['files']:
    assert sha(PACK/entry['path']) == entry['sha256'], entry['path']
assert sha(PACK/'recipes.json') == catalog['recipe_sha256']
assert sha(ROOT/catalog.get('builder_path','scripts/art/prepare_grass_assets.py')) == catalog['builder_sha256']
for path,digest in catalog.get('builder_dependencies',{}).items(): assert sha(ROOT/path) == digest
for entry in catalog['inspected_references_not_embedded']:
    assert sha(ROOT/entry['path']) == entry['sha256'], 'Inspected reference changed'
bpy.ops.wm.open_mainfile(filepath=str(PACK/('plant_library.blend' if PLANTS else 'grass_library.blend')), use_scripts=False)
assert len(bpy.context.scene.objects) == 54
assert all(o.type == 'MESH' and o.get('asset_role') == ROLE for o in bpy.context.scene.objects)
assert not bpy.data.images and not bpy.data.node_groups
assert all(not o.modifiers for o in bpy.context.scene.objects)
report = []
for asset in catalog['assets']:
    counts = [m['triangles'] for m in asset['models']]
    assert counts[0] > counts[1] > counts[2] and counts[0] <= (12000 if PLANTS else 2400)
    for model in asset['models']:
        path = PACK/'models'/model['file']
        data, blob = decode_glb(path)
        assert len(data['meshes']) == 1 and len(data['nodes']) == 1
        assert not any(data.get(k) for k in ['animations','skins','cameras','images','textures'])
        assert all('uri' not in b for b in data['buffers'])
        node = data['nodes'][0]
        assert node['extras']['asset_role'] == ROLE
        assert node.get('translation',[0,0,0]) == [0,0,0]
        assert node.get('scale',[1,1,1]) == [1,1,1]
        assert node.get('rotation',[0,0,0,1]) == [0,0,0,1]
        primitive = data['meshes'][0]['primitives']
        assert len(primitive) == 1 and len(data['materials']) == 1
        mat = data['materials'][0]
        assert mat['doubleSided'] and mat.get('alphaMode','OPAQUE') == 'OPAQUE'
        assert mat['name'] == ('PreparedPlant_VertexPBR' if PLANTS else 'PreparedGrass_VertexPBR')
        attrs = primitive[0]['attributes']
        assert all(k in attrs for k in ['POSITION','NORMAL','COLOR_0','TEXCOORD_0','TEXCOORD_1'])
        pos = floats(data,blob,attrs['POSITION'])
        uv = floats(data,blob,attrs['TEXCOORD_0'])
        pivots = floats(data,blob,attrs['TEXCOORD_1'])
        assert all(math.isfinite(v) for p in pos for v in p)
        assert min(p[1] for p in pos) >= -1e-6
        assert all(-1e-5 <= p[1] <= 1.00001 for p in uv)
        roots = [i for i,t in enumerate(uv) if abs(t[1]) < 1e-5]
        assert len(roots) >= model.get('blades',1)*3
        for i in roots:
            x,z = pivots[i][0]-.5, -(pivots[i][1]-.5)
            assert abs(pos[i][1]) < 1e-5
            assert math.hypot(pos[i][0]-x,pos[i][2]-z) < .01
        assert model['triangles'] == model['base_triangles']+model['snow_triangles']
        assert (model['snow_triangles'] == 0) == (asset['finish'] == 'green')
        bpy.ops.wm.read_factory_settings(use_empty=True)
        bpy.ops.import_scene.gltf(filepath=str(path))
        meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
        assert len(meshes) == 1
        obj = meshes[0]
        obj.data.calc_loop_triangles()
        assert len(obj.data.loop_triangles) == model['triangles']
        assert all(abs(a-b) < 1e-5 for a,b in zip(obj.dimensions,model['dimensions_blender_xyz_m']))
        assert len(obj.data.materials) == 1 and len(obj.data.uv_layers) == 2
        assert obj.data.color_attributes
        # Geometry must consist of narrow blade ribbons, not a hidden ground base.
        assert all(p.area > 1e-13 and p.area < (.01 if PLANTS else .002) for p in obj.data.polygons)
        report.append({'file':model['file'], 'triangles':model['triangles'], 'roundtrip':True,
                       'grass_only_structure':True, 'root_pivots_and_bend_coordinates':True})
out = ROOT/('artifacts/plant_asset_preparation' if PLANTS else 'artifacts/grass_asset_preparation')
out.mkdir(parents=True, exist_ok=True)
(out/'blender_validation.json').write_text(json.dumps({'manifest_sha256':sha(PACK/'manifest.json'),
    'exports_checked':len(report), 'source_reference_hashes_unchanged':True, 'results':report},indent=2)+'\n')
print('GRASS_ROUNDTRIP_COMPLETE',len(report),'exports passed; grass-only structure, pivots, PBR, dimensions and hashes',flush=True)

"""Independent source GLB audit for every promoted runtime grass mesh (stdlib)."""
import hashlib
import json
import math
from pathlib import Path
import struct

ROOT = Path(__file__).resolve().parents[1]


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def run():
    runtime = json.loads((ROOT / 'assets/graphics/grass/manifest.json').read_text())
    source_path = ROOT / 'art_source/foliage/grass_v1/manifest.json'
    source = json.loads(source_path.read_text())
    assert digest(source_path) == runtime['source_manifest_sha256']
    assert not source['rock_geometry'] and not source['collision']
    by_file = {m['file']: m for asset in source['assets'] for m in asset['models']}
    for entry in runtime['assets']:
        path = ROOT / entry['source'].removeprefix('res://')
        model = by_file[path.name]
        assert digest(path) == entry['source_sha256'] == model['sha256']
        assert digest(ROOT / entry['path'].removeprefix('res://')) == entry['sha256']
        raw = path.read_bytes()
        magic, version, length, json_length, json_type = struct.unpack_from('<5I', raw)
        assert (magic, version, length, json_type) == (0x46546C67, 2, len(raw), 0x4E4F534A)
        data = json.loads(raw[20:20+json_length])
        bin_length, bin_type = struct.unpack_from('<II', raw, 20+json_length)
        assert bin_type == 0x004E4942
        blob = raw[28+json_length:28+json_length+bin_length]
        assert len(data['nodes']) == len(data['meshes']) == len(data['materials']) == 1
        assert data['nodes'][0]['extras']['asset_role'] == 'grass_only'
        assert not any(data.get(k) for k in ['animations', 'skins', 'cameras', 'images', 'textures', 'extensions'])
        assert all('uri' not in b for b in data['buffers'])
        material = data['materials'][0]
        assert material['name'] == 'PreparedGrass_VertexPBR' and material['doubleSided']
        assert material.get('alphaMode', 'OPAQUE') == 'OPAQUE'
        primitives = data['meshes'][0]['primitives']
        assert len(primitives) == 1
        attributes = primitives[0]['attributes']
        def floats(name, width):
            acc = data['accessors'][attributes[name]]
            assert acc['componentType'] == 5126
            view = data['bufferViews'][acc['bufferView']]
            offset = view.get('byteOffset', 0) + acc.get('byteOffset', 0)
            return [struct.unpack_from('<'+'f'*width, blob, offset+i*view.get('byteStride', width*4)) for i in range(acc['count'])]
        positions, uv, pivots = floats('POSITION', 3), floats('TEXCOORD_0', 2), floats('TEXCOORD_1', 2)
        assert all(math.isfinite(v) for p in positions for v in p)
        assert min(p[1] for p in positions) >= -1e-6
        roots = [i for i, t in enumerate(uv) if abs(t[1]) < 1e-5]
        assert len(roots) >= model['blades']*3
        for i in roots:
            assert abs(positions[i][1]) < 1e-5
            assert math.hypot(positions[i][0]-(pivots[i][0]-.5), positions[i][2]+(pivots[i][1]-.5)) < .01
        assert model['triangles'] == model['base_triangles']+model['snow_triangles'] == entry['triangles']
        assert (model['snow_triangles'] == 0) == (entry['finish'] == 'green')
    print(f"Runtime grass source audit: {len(runtime['assets'])} independent vegetation-only assets passed")


if __name__ == '__main__':
    run()

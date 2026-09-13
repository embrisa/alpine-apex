"""Independent stdlib GLB checks for the cosmetic pebble source pack."""
import hashlib
import json
import math
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PACK = ROOT / 'art_source/rocks/pebbles_v1'
OUT = ROOT / 'artifacts/rock_pebbles_20260914'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def accessor(doc, binary, index):
    acc = doc['accessors'][index]
    view = doc['bufferViews'][acc['bufferView']]
    widths = {'SCALAR': 1, 'VEC3': 3, 'VEC4': 4}
    formats = {5126: 'f', 5125: 'I', 5123: 'H', 5121: 'B'}
    fmt = '<' + formats[acc['componentType']] * widths[acc['type']]
    stride = view.get('byteStride', struct.calcsize(fmt))
    start = view.get('byteOffset', 0) + acc.get('byteOffset', 0)
    return [struct.unpack_from(fmt, binary, start + i * stride) for i in range(acc['count'])]


def main():
    manifest = json.loads((PACK / 'manifest.json').read_text())
    assert manifest['status'] == 'prepared_only_not_integrated' and (PACK / '.gdignore').exists()
    assert not any(manifest[key] for key in ['collision', 'vegetation', 'terrain_or_pedestal_geometry'])
    assert sha(ROOT / manifest['source']) == manifest['source_sha256']
    assert sha(ROOT / manifest['builder']) == manifest['builder_sha256']
    assert sha(PACK / 'recipes.json') == manifest['recipe_sha256']
    for record in manifest['files']:
        path = PACK / record['path']
        assert sha(path) == record['sha256'] and path.stat().st_size == record['bytes'], path
    checked = []
    for asset in manifest['assets']:
        assert [m['triangles'] for m in asset['models']] == [80, 40, 16]
        for model in asset['models']:
            path = PACK / 'models' / model['file']
            raw = path.read_bytes()
            assert struct.unpack_from('<III', raw) == (0x46546C67, 2, len(raw))
            length, kind = struct.unpack_from('<II', raw, 12)
            assert kind == 0x4E4F534A
            doc = json.loads(raw[20:20+length])
            binary_length, kind = struct.unpack_from('<II', raw, 20+length)
            assert kind == 0x004E4942
            binary = raw[28+length:28+length+binary_length]
            assert len(doc['meshes']) == len(doc['nodes']) == len(doc['materials']) == 1
            assert all(not doc.get(key) for key in ['animations', 'skins', 'images', 'textures', 'cameras', 'extensionsRequired'])
            assert all('uri' not in buffer for buffer in doc['buffers'])
            node = doc['nodes'][0]
            assert node['extras']['asset_role'] == 'cosmetic_rock_pebble'
            assert node['extras']['collision'] is False
            assert node.get('translation', [0, 0, 0]) == [0, 0, 0]
            assert node.get('scale', [1, 1, 1]) == [1, 1, 1]
            assert node.get('rotation', [0, 0, 0, 1]) == [0, 0, 0, 1]
            material = doc['materials'][0]
            assert material.get('alphaMode', 'OPAQUE') == 'OPAQUE'
            assert not material.get('doubleSided', False)
            assert material['pbrMetallicRoughness']['metallicFactor'] == 0
            assert abs(material['pbrMetallicRoughness']['roughnessFactor'] - .93) < 1e-5
            assert len(doc['meshes'][0]['primitives']) == 1
            primitive = doc['meshes'][0]['primitives'][0]
            attrs = primitive['attributes']
            assert all(key in attrs for key in ['POSITION', 'NORMAL', 'COLOR_0'])
            positions = accessor(doc, binary, attrs['POSITION'])
            normals = accessor(doc, binary, attrs['NORMAL'])
            colors = accessor(doc, binary, attrs['COLOR_0'])
            assert all(math.isfinite(v) for row in positions + normals + colors for v in row)
            assert all(abs(sum(v*v for v in normal) - 1) < .001 for normal in normals)
            lower = [min(p[i] for p in positions) for i in range(3)]
            upper = [max(p[i] for p in positions) for i in range(3)]
            assert abs(lower[1]) < 1e-6
            assert all(abs(upper[i] - lower[i] - model['dimensions_godot_xyz_m'][i]) < 1e-6 for i in range(3))
            # Flat normals may split GLB vertices: weld positions for topology checks.
            weld = [tuple(round(v, 7) for v in p) for p in positions]
            indices = [row[0] for row in accessor(doc, binary, primitive['indices'])]
            assert len(indices) == model['triangles'] * 3
            edges, neighbors = {}, {}
            for start in range(0, len(indices), 3):
                face = [weld[indices[start+i]] for i in range(3)]
                assert len(set(face)) == 3
                for i in range(3):
                    a, b = face[i], face[(i+1) % 3]
                    edge = tuple(sorted([a, b]))
                    edges[edge] = edges.get(edge, 0) + 1
                    neighbors.setdefault(a, set()).add(b)
                    neighbors.setdefault(b, set()).add(a)
            assert all(count == 2 for count in edges.values()), 'Open/nonmanifold stone'
            pending, visited = [next(iter(neighbors))], set()
            while pending:
                point = pending.pop()
                if point in visited:
                    continue
                visited.add(point)
                pending.extend(neighbors[point] - visited)
            assert len(visited) == len(neighbors), 'Embedded disconnected support/debris'
            checked.append(model['file'])
    OUT.mkdir(exist_ok=True)
    report = {'result': 'passed', 'models_checked': len(checked), 'files': checked,
              'manifest_sha256': sha(PACK / 'manifest.json'),
              'checks': 'Source/export hashes, embedded GLB, identity transforms, one opaque mesh/material, no collision/vegetation, dimensions/base, normals/colors, exact LOD triangles, closed connected topology',
              'scope': 'Prepared assets only; no runtime placement or performance acceptance'}
    (OUT / 'asset_validation.json').write_text(json.dumps(report, indent=2) + '\n')
    print('PEBBLE_VALIDATION', len(checked), 'models passed')


if __name__ == '__main__':
    main()

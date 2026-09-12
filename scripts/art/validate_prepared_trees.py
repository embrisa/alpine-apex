"""Independent Blender round-trip and package checks for prepared-only trees."""
import hashlib
import json
from pathlib import Path
import bpy

root = Path(__file__).resolve().parents[2]
package = root / 'art_source/trees/colorful_v1'
manifest = json.loads((package / 'manifest.json').read_text())
assert manifest['status'] == 'prepared_only_not_integrated'
assert len(manifest['assets']) == 6
atlases = json.loads((package / 'impostors/manifest.json').read_text())
assert len(atlases) == 6
for atlas in atlases:
    record = next(r for r in manifest['assets'] if r['id'] == atlas['id'])
    assert atlas['source_model_sha256'] == record['models'][0]['sha256'], 'Stale impostor: rebuild with -Mode Bake'
    assert hashlib.sha256((package / 'impostors' / atlas['file']).read_bytes()).hexdigest() == atlas['sha256']
report = []
for record in manifest['assets']:
    assert (package / 'blends' / record['blend']).exists()
    assert hashlib.sha256((package / 'blends' / record['blend']).read_bytes()).hexdigest() == record['blend_sha256']
    bpy.ops.wm.open_mainfile(filepath=str(package / 'blends' / record['blend']))
    assert not any(m.type == 'NODES' for o in bpy.data.objects for m in o.modifiers), 'Vendor generator must not ship'
    assert not any(g.bl_idname == 'GeometryNodeTree' for g in bpy.data.node_groups), 'Vendor node groups must not ship'
    assert record['attachment_sites'] >= 80
    assert record['models'][0]['triangles'] <= 32000
    assert record['models'][1]['triangles'] <= 11000
    assert record['models'][2]['triangles'] < record['models'][1]['triangles']
    for model in record['models'] + [record['leaf_sample']]:
        bpy.ops.wm.read_factory_settings(use_empty=True)
        path = package / 'models' / model['file']
        assert hashlib.sha256(path.read_bytes()).hexdigest() == model['sha256']
        bpy.ops.import_scene.gltf(filepath=str(path))
        meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
        assert len(meshes) == 1, model['file']
        obj = meshes[0]
        obj.data.calc_loop_triangles()
        assert len(obj.data.loop_triangles) == model['triangles']
        assert len(obj.data.materials) == model['surfaces']
        assert all(abs(a - b) < .015 for a, b in zip(obj.dimensions, model['dimensions_blender_xyz_m']))
        assert len(obj.data.uv_layers) == 2
        assert len(obj.data.color_attributes) > 0
        assert all(abs(c.color[3] - 1) < .001 for c in obj.data.color_attributes[0].data)
        assert all(m.use_nodes for m in obj.data.materials)
        leaves = next(m for m in obj.data.materials if 'Leaves' in m.name)
        assert len([n for n in leaves.node_tree.nodes if n.type == 'TEX_IMAGE' and n.image]) >= 3
        assert any(n.type == 'NORMAL_MAP' for n in leaves.node_tree.nodes)
        report.append({'file': model['file'], 'triangles': model['triangles'], 'roundtrip': True,
                       'opaque_vertex_colors': True, 'branch_uv_retained': True, 'textured_leaves': True})
out = root / 'artifacts/colorful_tree_preparation'
out.mkdir(parents=True, exist_ok=True)
(out / 'blender_validation.json').write_text(json.dumps(report, indent=2) + '\n')
print('PREPARED_TREE_ROUNDTRIP', len(report), 'exports passed', flush=True)

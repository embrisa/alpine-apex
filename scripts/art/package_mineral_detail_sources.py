"""Independent GLB reimport audit and editable, packed Blender asset libraries."""
import bpy
import hashlib
import json
import math
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ART = ROOT/'art_source/blender/minerals_v3'
QA = ROOT/'artifacts/minerals_v3'
manifest = json.loads((ROOT/'assets/graphics/minerals_v3/manifest.json').read_text())
results = []
for category in manifest['categories']:
    records = [r for r in manifest['assets'] if r['category'] == category]
    if '--completed-categories' in sys.argv and len(records) != 24:
        continue
    assert len(records) == 24, (category,len(records))
    category_report = ART/(category+'_validation.json')
    category_blend = ART/(category+'.blend')
    if category_report.exists() and category_blend.exists():
        previous = json.loads(category_report.read_text())
        if previous.get('export_hashes') == {r['asset']:r['sha256'] for r in records} and previous.get('blend_sha256') == hashlib.sha256(category_blend.read_bytes()).hexdigest():
            results.extend(previous['assets'])
            print('DETAIL_CATEGORY_PRESERVED',category,flush=True)
            continue
    category_results = []
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.preferences.filepaths.save_version = 0
    scene = bpy.context.scene
    scene.unit_settings.system = 'METRIC'
    for record in records:
        path = ROOT/record['path']
        assert hashlib.sha256(path.read_bytes()).hexdigest() == record['sha256']
        before = set(bpy.data.objects)
        bpy.ops.import_scene.gltf(filepath=str(path))
        added = set(bpy.data.objects)-before
        meshes = [o for o in added if o.type == 'MESH']
        assert len(meshes) == 1
        obj = meshes[0]
        bpy.context.view_layer.update()
        obj.data.calc_loop_triangles()
        assert len(obj.data.loop_triangles) == record['triangles']
        assert len(obj.data.materials) == 1 and len(obj.data.uv_layers) == 1
        assert all(math.isfinite(c) for v in obj.data.vertices for c in v.co)
        assert max(abs(obj.dimensions[i]-record['dimensions_blender_xyz_m'][i]) for i in range(3)) < .015
        assert abs(min((obj.matrix_world@v.co).z for v in obj.data.vertices)) < .015
        transform = obj.matrix_world.copy()
        obj.parent = None
        obj.matrix_world = transform
        for other in added:
            if other != obj: bpy.data.objects.remove(other, do_unlink=True)
        family = manifest['category_families'][category].index(record['family'])
        spacing = max(manifest['categories'][category])*1.35
        obj.location = ((record['variant']-1)*spacing,family*spacing,0)
        obj.asset_mark()
        obj.asset_data.description = f"{record['family']} | {max(record['dimensions_blender_xyz_m']):g} m | {record['triangles']} triangles | baked from supplied generator"
        for tag in ['Alpine Apex',category,record['family'],'detail v3','bare']:
            obj.asset_data.tags.new(tag)
        category_results.append({'asset':record['asset'],'triangles':record['triangles'],'roundtrip_verified':True})
    bpy.ops.file.pack_all()
    bpy.ops.wm.save_as_mainfile(filepath=str(category_blend), compress=True)
    category_report.write_text(json.dumps({'assets':category_results,'export_hashes':{r['asset']:r['sha256'] for r in records},'blend_sha256':hashlib.sha256(category_blend.read_bytes()).hexdigest()},indent=2)+'\n')
    results.extend(category_results)
    print('DETAIL_CATEGORY_PACKED',category,24,flush=True)
assert len(results) == 120 or '--completed-categories' in sys.argv
assert hashlib.sha256((ROOT/'art_source/blender/rock_generator.blend').read_bytes()).hexdigest() == manifest['source_sha256']
(QA/'blender_validation.json').write_text(json.dumps({'passed':True,'partial':len(results)!=120,'asset_count':len(results),'source_preserved':True,'assets':results},indent=2)+'\n')
print('DETAIL_BLENDER_VALIDATED',len(results),flush=True)

"""Independent saved-source and GLB roundtrip verification inside Blender."""
import hashlib
import json
from pathlib import Path
import bpy

PACK = Path(__file__).resolve().parent
ROOT = PACK.parents[2]
manifest = json.loads((PACK/'manifest.json').read_text())
checks, failures = 0, []


def check(value, label):
    global checks
    checks += 1
    if not value:
        failures.append(label)
        print('FAIL:', label, flush=True)


for record in manifest['assets']:
    bpy.ops.wm.open_mainfile(filepath=str(PACK/record['source_blend']['path']), load_ui=False)
    meshes = [o for o in bpy.data.objects if o.type == 'MESH']
    check(len(meshes)==4, record['id']+' editable three-tier source and shadow')
    check(not any(o.modifiers for o in meshes), record['id']+' self-contained baked source')
    check(all(i.packed_file for i in bpy.data.images if i.source=='FILE'), record['id']+' packed material images')
    for model in record['models'] + [record['shadow']]:
        name = Path(model['path']).stem
        obj = bpy.data.objects.get(name)
        check(obj is not None, name+' retained in source')
        if obj:
            obj.data.calc_loop_triangles()
            check(len(obj.data.loop_triangles)==model['triangles'], name+' source triangles')
        bpy.ops.wm.read_factory_settings(use_empty=True)
        bpy.ops.import_scene.gltf(filepath=str(PACK/model['path']))
        imported = [o for o in bpy.context.scene.objects if o.type=='MESH']
        total = 0
        for o in imported:
            o.data.calc_loop_triangles()
            total += len(o.data.loop_triangles)
            check(bool(o.data.color_attributes), name+' reimport colors')
            check(len(o.data.uv_layers)>=2, name+' reimport UV and branch tags')
        check(total == model['triangles'], name+' reimport triangles')
        # Reopen the source before checking the next saved LOD object.
        bpy.ops.wm.open_mainfile(filepath=str(PACK/record['source_blend']['path']), load_ui=False)
    print('PREMIUM_ROUNDTRIP', record['id'], flush=True)

out = ROOT/'artifacts/premium_tree_review/blender_audit.json'
out.parent.mkdir(parents=True, exist_ok=True)
out.write_text(json.dumps(dict(checks=checks,failures=failures,blender=bpy.app.version_string,
    manifest_sha256=hashlib.sha256((PACK/'manifest.json').read_bytes()).hexdigest()),indent=2)+'\n')
print('PREMIUM_BLENDER_RESULTS', checks, 'checks;', len(failures), 'failures', flush=True)
if failures:
    raise RuntimeError('Source/roundtrip failures: '+str(len(failures)))

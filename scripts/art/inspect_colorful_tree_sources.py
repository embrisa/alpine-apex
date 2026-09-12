"""Bounded local TreeDesigner catalog inspection; does not evaluate the library."""
import json
import sys
from pathlib import Path
import bpy

root = Path(__file__).resolve().parents[2]
source = root / 'TreeDesigner + 400 trees/TreeDesigner.blend'
with bpy.data.libraries.load(str(source), link=False) as (available, unused):
    names = [n for n in available.objects if any(s in n.lower() for s in ('maple', 'aspen', 'birch', 'oak'))]
report = {'source': source.relative_to(root).as_posix(), 'objects': names}
if '--evaluate' in sys.argv:
    report['samples'] = []
    for name in ('BirchTree_LowPoly.032', 'MapleTree_LowPoly.032'):
        with bpy.data.libraries.load(str(source), link=False) as (available, selected):
            selected.objects = [name]
        obj = selected.objects[0]
        bpy.context.scene.collection.objects.link(obj)
        obj.hide_viewport = False
        obj.hide_set(False)
        mod = next(m for m in obj.modifiers if m.type == 'NODES')
        inputs = []
        for socket in mod.node_group.interface.items_tree:
            if socket.item_type != 'SOCKET' or socket.in_out != 'INPUT':
                continue
            value = getattr(getattr(mod.properties.inputs, socket.identifier, None), 'value', None)
            if isinstance(value, (str, bool, int, float)):
                inputs.append({'id': socket.identifier, 'name': socket.name, 'value': value})
        bpy.context.view_layer.update()
        dg = bpy.context.evaluated_depsgraph_get()
        mesh = bpy.data.meshes.new_from_object(obj.evaluated_get(dg), depsgraph=dg)
        counts = {}
        for p in mesh.polygons:
            counts[str(p.material_index)] = counts.get(str(p.material_index), 0) + 1
        report['samples'].append({'name': name, 'inputs': inputs, 'faces': counts,
                                  'materials': [m.name if m else None for m in mesh.materials],
                                  'attributes': [a.name for a in mesh.attributes]})
        bpy.data.objects.remove(obj, do_unlink=True)
out = root / 'artifacts/colorful_tree_preparation'
out.mkdir(parents=True, exist_ok=True)
(out / 'source_inventory.json').write_text(json.dumps(report, indent=2) + '\n')
print('COLORFUL_TREE_SOURCES', json.dumps(report), flush=True)

"""Read the locally purchased library without evaluating the entire forest."""
import bpy
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'TreeDesigner + 400 trees/TreeDesigner.blend'
OUT = ROOT / 'artifacts/treedesigner'
OUT.mkdir(parents=True, exist_ok=True)
with bpy.data.libraries.load(str(SOURCE), link=False) as (src, dst):
    names = [n for n in src.objects if 'spr' in n.lower()]
    print('SPRUCE_OBJECTS', names, flush=True)
    dst.objects = names[:1]
obj = dst.objects[0]
bpy.context.scene.collection.objects.link(obj)
records = []
for modifier in obj.modifiers:
    if modifier.type != 'NODES':
        continue
    group = modifier.node_group
    inputs = []
    for socket in group.interface.items_tree:
        if socket.item_type != 'SOCKET' or socket.in_out != 'INPUT':
            continue
        prop = getattr(modifier.properties.inputs, socket.identifier, None)
        value = getattr(prop, 'value', None)
        if isinstance(value, bpy.types.ID):
            value = value.name
        elif value is not None and not isinstance(value, (bool, str, int, float)):
            try: value = list(value)
            except TypeError: value = str(value)
        inputs.append(dict(name=socket.name, id=socket.identifier, type=socket.socket_type, value=value))
    records.append(dict(modifier=modifier.name, group=group.name, inputs=inputs))
report = dict(blender=bpy.app.version_string, objects=names, selected=obj.name,
              modifiers=records, materials=[m.name if m else None for m in obj.data.materials],
              images=[dict(name=i.name, path=i.filepath, packed=bool(i.packed_file)) for i in bpy.data.images])
(OUT / 'inspection.json').write_text(json.dumps(report, indent=2))
print('INSPECTION', str(OUT / 'inspection.json'), flush=True)

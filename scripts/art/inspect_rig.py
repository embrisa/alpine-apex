import bpy, json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(ROOT/'art_source/meshy/skier_rig.glb'))
report=[]
for o in bpy.context.scene.objects:
    row=dict(name=o.name,type=o.type,location=list(o.location),scale=list(o.scale),rotation=list(o.rotation_euler))
    if o.type=='ARMATURE':
        row['bones']=[dict(name=b.name,parent=b.parent.name if b.parent else None,head=list(b.head_local),tail=list(b.tail_local)) for b in o.data.bones]
    if o.type=='MESH':row.update(vertices=len(o.data.vertices),faces=len(o.data.polygons),dimensions=list(o.dimensions))
    report.append(row)
(ROOT/'art_source/meshy/rig_inspection.json').write_text(json.dumps(report,indent=2))
print(json.dumps(report,indent=2))

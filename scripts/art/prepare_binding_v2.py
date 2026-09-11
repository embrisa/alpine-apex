"""Remove the spacer assembly and fit the binding housing to a low boot seat.

Local derivative of the retained v1 asset. Run with background Blender.
"""
import bpy, bmesh, json, hashlib, sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from prepare_equipment_v1 import load_mesh, export, info, refresh_normals

ROOT = Path(__file__).resolve().parents[2]
source = ROOT/'assets/graphics/models/binding_detailed_v1.glb'
obj = load_mesh(source)
bm = bmesh.new(); bm.from_mesh(obj.data)
riser = {i for i,m in enumerate(obj.data.materials) if m.name.startswith('EquipmentV1Riser')}
assert riser, 'Expected separately identified spacer assembly'
bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.material_index in riser], context='FACES')
bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context='VERTS')
bm.to_mesh(obj.data); bm.free()
# The reconstructed housing previously sat above the support deck. Fit its
# base to the ski and reduce housing height around the new 17 mm boot seat.
base = min(v.co.z for v in obj.data.vertices)
for v in obj.data.vertices: v.co.z = (v.co.z-base)*.65
# Reconstructed toe/heel undersides still had a 0.3-2 mm gap even with the
# overall minimum at zero. Seat the existing underside faces on the ski; no
# new plate, columns or spacer geometry is added.
for v in obj.data.vertices:
    t=min(1.0,max(0.0,(v.co.z-.004)/.008))
    v.co.z *= t*t*(3-2*t)
for i in sorted(riser, reverse=True): obj.data.materials.pop(index=i)
obj.name='EquipmentV2Binding'
refresh_normals(obj)
target=ROOT/'assets/graphics/models/binding_detailed_v2.glb'
export(obj,target)
result=info(load_mesh(target))
assert not any('Riser' in m for m in result['materials'])
report={'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),
        'sha256':hashlib.sha256(target.read_bytes()).hexdigest(),
        'boot_seat_above_ski_m':.017,'binding_origin_above_ski_m':0,'result':result}
(ROOT/'art_source/meshy/equipment_v1/binding_v2_qa.json').write_text(json.dumps(report,indent=2)+'\n')
print('BINDING_V2',json.dumps(report))

"""Install verified local hand derivatives without overwriting concurrent edits."""
import datetime
import hashlib
import json
import shutil
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
SOURCE=ROOT/'art_source/meshy/hands_v1'
qa=json.loads((SOURCE/'runtime_qa.json').read_text())
record_path=SOURCE/'installation.json'
previous=json.loads(record_path.read_text()) if record_path.exists() else {}

def digest(path):return hashlib.sha256(path.read_bytes()).hexdigest()

pairs=[('assets/graphics/models/skier_v7.glb','skier_staged.glb','skier_v7.glb'),
       ('art_source/blender/skier_v7.blend','skier_staged.blend','skier_v7.blend')]
assert digest(SOURCE/'skier_staged.glb')==qa['output_glb_sha256']
assert qa['roundtrip_verified'] and qa['skin_weights_verified']
assert qa['non_glove_bytes_unchanged'] and qa['nodes_and_bind_transforms_unchanged']
assert qa['non_glove_materials_unchanged'] and qa['paired_glove_triangles']<=6000
for target,staged,baseline in pairs:
    allowed={digest(SOURCE/'baseline'/baseline),digest(SOURCE/staged),previous.get('sha256',{}).get(target)}
    assert digest(ROOT/target) in allowed, 'Concurrent asset edit: '+target
for target,staged,_ in pairs:
    destination=ROOT/target
    temporary=destination.with_name(destination.name+'.hands-v1.tmp')
    shutil.copy2(SOURCE/staged,temporary)
    assert digest(temporary)==digest(SOURCE/staged)
    temporary.replace(destination)
paths=[p[0] for p in pairs]+['art_source/blender/skier_glove_v1.blend']
ledger=json.loads((SOURCE/'credit_ledger.json').read_text())
record={'recorded_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),
        'sha256':{p:digest(ROOT/p) for p in paths},'body_triangles':38272,
        'glove_triangles':qa['paired_glove_triangles'],'material_identifier':'SkierV7Gloves',
        'mesh_generation_credits':ledger['consumed_credits'],
        'unused_authorized_credits':ledger['authorized_credits']-ledger['consumed_credits'],
        'originals':'art_source/meshy/hands_v1/baseline','asset_qa':'art_source/meshy/hands_v1/runtime_qa.json'}
record_path.write_text(json.dumps(record,indent=2)+'\n')
print('HANDS_INSTALLED',record['sha256']['assets/graphics/models/skier_v7.glb'])

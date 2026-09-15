"""Seal completed native atlas outputs into the source manifest."""
import hashlib
import json
from pathlib import Path

pack = Path(__file__).resolve().parent
path = pack / 'manifest.json'
manifest = json.loads(path.read_text())
bake_path = pack.parents[2]/'artifacts/premium_tree_review/native/bake_manifest.json'
baked = {r['id']:r for r in json.loads(bake_path.read_text())['assets']}
for asset in manifest['assets']:
    if asset['id'] not in baked:
        continue
    record = baked[asset['id']]
    if record['source_model_sha256'] != asset['models'][0]['sha256']:
        raise SystemExit('Native bake source drift: '+asset['id'])
    for name in ('color','normal','canopy'):
        entry = asset['impostor'][name]
        file = pack / entry['path']
        if not file.exists():
            raise SystemExit('Missing native bake: ' + str(file))
        digest = hashlib.sha256(file.read_bytes()).hexdigest()
        if digest != record['files'][name]['sha256']:
            raise SystemExit('Native bake output drift: '+str(file))
        entry.update(bytes=file.stat().st_size, sha256=digest)
    asset['impostor']['near_sha256'] = asset['models'][0]['sha256']
manifest['review_producer_hashes'] = {p:hashlib.sha256((pack/p).read_bytes()).hexdigest()
                                     for p in ('review.gd','far.gdshader')}
path.write_text(json.dumps(manifest,indent=2)+'\n')
print('Sealed native atlases for', len(baked), 'trees')

"""Fetch only the selected CC0 sources. No credentials or paid API calls.

Run with system Python. Source files are cached and verified by published MD5;
the local provenance ledger also records SHA-256. Runtime exports are separate.
"""
import hashlib
import json
from pathlib import Path
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'art_source/flavor_v1'
IDS = ['garden_gnome', 'WetFloorSign_01', 'ArmChair_01', 'wooden_picnic_table',
       'stone_fire_pit', 'vintage_radio_transceiver', 'wooden_crate_01', 'rubber_duck_toy']
HEADERS = {'User-Agent': 'AlpineApexAssetLibrary/1.0 (Poly Haven CC0 assets)'}

def read(url):
    with urlopen(Request(url, headers=HEADERS), timeout=90) as response:
        return response.read()

def fetch(descriptor, path):
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists() and hashlib.md5(path.read_bytes()).hexdigest() == descriptor['md5']:
        data = path.read_bytes()
    else:
        data = read(descriptor['url'])
        assert hashlib.md5(data).hexdigest() == descriptor['md5'], path
        path.write_bytes(data)
    return {'path': path.relative_to(ROOT).as_posix(), 'url': descriptor['url'],
            'sha256': hashlib.sha256(data).hexdigest(), 'bytes': len(data)}

def main():
    records = []
    for asset_id in IDS:
        files = json.loads(read('https://api.polyhaven.com/files/' + asset_id))
        metadata = json.loads(read('https://api.polyhaven.com/info/' + asset_id))
        folder = OUT / 'raw' / asset_id
        descriptor = files['gltf']['2k']['gltf']
        downloads = [fetch(descriptor, folder / (asset_id + '.gltf'))]
        for relative, included in descriptor.get('include', {}).items():
            target = (folder / relative).resolve()
            assert target.is_relative_to(folder.resolve())
            downloads.append(fetch(included, target))
        records.append({'asset_id': asset_id, 'name': metadata.get('name', asset_id),
                        'author': metadata.get('authors'), 'source': 'Poly Haven',
                        'source_url': 'https://polyhaven.com/a/' + asset_id,
                        'license': 'CC0-1.0', 'texture_resolution': 2048,
                        'files': downloads})
        (OUT / 'polyhaven_sources.json').write_text(json.dumps(records, indent=2) + '\n')
        print('FETCHED', asset_id, sum(r['bytes'] for r in downloads), flush=True)
    texture = 'weathered_brown_planks'
    files = json.loads(read('https://api.polyhaven.com/files/' + texture))
    maps = []
    for channel in ['Diffuse', 'nor_gl', 'arm']:
        maps.append(fetch(files[channel]['2k']['jpg'], OUT / 'raw/gate_wood' / (channel + '.jpg')))
    (OUT / 'gate_material_source.json').write_text(json.dumps({
        'asset_id': texture, 'source_url': 'https://polyhaven.com/a/' + texture,
        'license': 'CC0-1.0', 'files': maps}, indent=2) + '\n')

if __name__ == '__main__':
    main()

"""Download the pinned CC0 4K derivatives used by the PC High preset."""
from pathlib import Path
import hashlib
import json
import urllib.request

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets/graphics/textures'
manifest = []
for asset, prefix in [('snow_02', 'snow'), ('rock_face_03', 'rock'), ('bark_brown_02', 'bark')]:
    metadata = json.loads((ROOT / 'art_source' / (asset + '_files.json')).read_text())
    for channel, suffix in [('Diffuse', 'albedo'), ('nor_gl', 'normal'), ('arm', 'orm')]:
        entry = metadata[channel]['4k']['jpg']
        target = OUT / f'{prefix}_{suffix}_high.jpg'
        if not target.exists():
            request = urllib.request.Request(entry['url'], headers={'User-Agent': 'AlpineApex/1.0'})
            with urllib.request.urlopen(request, timeout=120) as response:
                data = response.read()
            if hashlib.md5(data).hexdigest() != entry['md5']:
                raise RuntimeError(f'Checksum mismatch: {asset} / {channel}')
            target.write_bytes(data)
        data = target.read_bytes()
        assert hashlib.md5(data).hexdigest() == entry['md5'], target
        manifest.append({'asset': asset, 'channel': channel, 'path': target.relative_to(ROOT).as_posix(),
                         'url': entry['url'], 'sha256': hashlib.sha256(data).hexdigest(),
                         'license': 'CC0-1.0', 'resolution': 4096})
        print('Verified', target.name, flush=True)
(ROOT / 'art_source/pc_texture_sources.json').write_text(json.dumps(manifest, indent=2) + '\n')

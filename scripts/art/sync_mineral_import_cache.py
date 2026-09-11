"""Copy only v3 import products into the main project's rebuildable cache.

The isolated review uses the same res:// paths. No editor settings, UID cache,
unrelated import products or source assets are overwritten.
"""
from pathlib import Path
import re
import shutil

ROOT = Path(__file__).resolve().parents[2]
PACK = ROOT/'assets/graphics/minerals_v3'
QA_CACHE = ROOT/'artifacts/minerals_v3/qa_project/.godot/imported'
MAIN_CACHE = ROOT/'.godot/imported'
MAIN_CACHE.mkdir(parents=True,exist_ok=True)
names = set()
for sidecar in PACK.rglob('*.import'):
    for name in re.findall(r'res://\.godot/imported/([^"\r\n]+)',sidecar.read_text()):
        if '/' in name or '\\' in name or '..' in name:
            raise ValueError(f'Unexpected import product: {name}')
        names.add(name)
        names.add(re.sub(r'(\.(s3tc|bptc|etc2|astc))?\.(ctex|scn)$','.md5',name))
copied = 0
for name in sorted(names):
    source = QA_CACHE/name
    if source.is_file():
        shutil.copy2(source,MAIN_CACHE/name)
        copied += 1
print('DETAIL_CACHE_SYNC',copied,'asset import products')

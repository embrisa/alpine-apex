"""Configure v3 import sidecars only. Run after Godot's first asset import."""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]
PACK = ROOT/'assets/graphics/minerals_v3'
for path in PACK.glob('*/*.glb.import'):
    original = path.read_text()
    text = original
    for name, value in {'meshes/generate_lods': 'true', 'animation/import': 'false',
                        'import_script/path': '"res://scripts/art/mineral_detail_post_import.gd"'}.items():
        text = re.sub(r'^'+re.escape(name)+r'=.*$', name+'='+value, text, flags=re.M)
    if text != original:
        path.write_text(text)
for path in (PACK/'textures').glob('*.import'):
    original = path.read_text()
    text = original
    for name, value in {'mipmaps/generate': 'true', 'compress/mode': '2'}.items():
        text = re.sub(r'^'+re.escape(name)+r'=.*$', name+'='+value, text, flags=re.M)
    if text != original:
        path.write_text(text)
print('DETAIL_IMPORTS_CONFIGURED')

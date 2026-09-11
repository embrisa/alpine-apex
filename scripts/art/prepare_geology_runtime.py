"""Scoped texture import preparation/cache sync; no source asset edits.

Run --setup, Godot --headless --editor --import in the printed isolated project,
then --configure, import once more, and --sync. Godot source/toolkit imports are
never scanned. Run with the system Python; only the standard library is needed.
"""
from pathlib import Path
import json
import re
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
PACK = ROOT/'assets/graphics/geology_v11'
QA = ROOT/'artifacts/geology_v11/import_project'

if '--setup' in sys.argv:
    (QA/'assets/graphics').mkdir(parents=True,exist_ok=True)
    target = QA/'assets/graphics/geology_v11'
    if not target.exists():
        subprocess.run(['powershell','-NoProfile','-Command',
                        f"New-Item -ItemType Junction -Path '{target}' -Target '{PACK}' | Out-Null"],check=True)
    if target.resolve() != PACK.resolve():
        raise RuntimeError('Unexpected geology import mount')
    (QA/'project.godot').write_text('config_version=5\n[application]\nconfig/name="Geology runtime import"\n')
    print(QA)

if '--configure' in sys.argv:
    count = 0
    for path in (PACK/'textures').glob('*.import'):
        text = path.read_text()
        for key,value in {'compress/mode':'2','mipmaps/generate':'true',
                          'compress/normal_map':'1' if '_normal.png' in path.name else '2'}.items():
            text = re.sub(r'(?m)^'+re.escape(key)+r'=.*$',key+'='+value,text)
        path.write_text(text)
        count += 1
    print('Configured',count,'runtime texture imports')

if '--sync' in sys.argv:
    names = set()
    for path in PACK.rglob('*.import'):
        for name in re.findall(r'res://\.godot/imported/([^"\r\n]+)',path.read_text()):
            if '/' in name or '\\' in name or '..' in name:
                raise ValueError(name)
            names.add(name)
            names.add(re.sub(r'(\.(s3tc|bptc|etc2|astc))?\.(ctex|scn)$','.md5',name))
    count=0
    for name in sorted(names):
        source=QA/'.godot/imported'/name
        if source.is_file():
            shutil.copy2(source,ROOT/'.godot/imported'/name)
            count+=1
    print('Scoped geology cache sync',count,'products')

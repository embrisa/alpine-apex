"""Configure only this pack's Godot import sidecars after an initial import."""
from pathlib import Path
import re
import shutil

ROOT=Path(__file__).resolve().parents[2]
PACK=ROOT/'assets/graphics/minerals'
textures=PACK/'textures'
textures.mkdir(parents=True,exist_ok=True)
for name in ['rock_albedo.jpg','rock_normal.jpg']:
    shutil.copy2(ROOT/'art_source/blender/minerals/textures'/name,textures/name)
for path in PACK.glob('*/*.glb.import'):
    text=path.read_text()
    for name,value in {'meshes/generate_lods':'true','animation/import':'false',
        'import_script/path':'"res://scripts/art/mineral_post_import.gd"'}.items():
        text=re.sub(r'^'+re.escape(name)+r'=.*$',name+'='+value,text,flags=re.M)
    path.write_text(text)
for path in textures.glob('*.jpg.import'):
    text=path.read_text()
    for name,value in {'mipmaps/generate':'true','compress/mode':'2'}.items():
        text=re.sub(r'^'+re.escape(name)+r'=.*$',name+'='+value,text,flags=re.M)
    if 'normal' in path.name:
        text=re.sub(r'^compress/normal_map=.*$','compress/normal_map=1',text,flags=re.M)
    path.write_text(text)
print('MINERAL_IMPORTS_CONFIGURED')

"""Apply runtime texture filtering/compression and preserve artist-authored LODs.
Run after Godot's first import, then import once more. No addon files are edited.
"""
from pathlib import Path
import re
ROOT=Path(__file__).resolve().parents[2]
for folder in ['textures','models']:
 for p in (ROOT/'assets/graphics'/folder).glob('*.import'):
  s=p.read_text()
  if p.name.endswith('.glb.import'):
   s=re.sub(r'meshes/generate_lods=.*','meshes/generate_lods=false',s)
  else:
   s=re.sub(r'mipmaps/generate=.*','mipmaps/generate=true',s)
   s=re.sub(r'compress/mode=.*','compress/mode=2',s)
   if 'normal' in p.name:s=re.sub(r'compress/normal_map=.*','compress/normal_map=1',s)
  p.write_text(s)

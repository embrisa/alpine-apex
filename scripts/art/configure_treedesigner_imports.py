"""Configure only TreeDesigner derivatives after their first Godot import."""
from pathlib import Path
import re
root=Path(__file__).resolve().parents[2]/'assets/graphics'
for path in sorted(root.glob('models/td_*.glb.import')):
    text=path.read_text()
    text=re.sub(r'meshes/generate_lods=.*','meshes/generate_lods=false',text)
    path.write_text(text)
for path in sorted(root.glob('textures/td_*.png.import')):
    text=path.read_text()
    text=re.sub(r'mipmaps/generate=.*','mipmaps/generate=true',text)
    text=re.sub(r'compress/mode=.*','compress/mode=2',text)
    path.write_text(text)

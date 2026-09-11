"""Only configure the new tree collection, never unrelated art imports."""
import re
from pathlib import Path
base=Path(__file__).resolve().parents[2]/'assets/graphics/trees'
for p in (base/'models').glob('*.glb.import'):
    original=s=p.read_text()
    s=re.sub(r'meshes/generate_lods=.*','meshes/generate_lods=false',s)
    s=re.sub(r'import_script/path=.*','import_script/path="res://scripts/art/tree_collection_post_import.gd"',s)
    if s!=original: p.write_text(s)
for p in (base/'textures').glob('*.png.import'):
    original=s=p.read_text()
    s=re.sub(r'mipmaps/generate=.*','mipmaps/generate=true',s)
    s=re.sub(r'compress/mode=.*','compress/mode=2',s)
    if s!=original: p.write_text(s)

"""Derive shared 2K/1K runtime PBR textures from the preserved Meshy source."""
from PIL import Image
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
for channel,filename in [('albedo','base_color.png'),('normal','normal.png'),('roughness','roughness.png')]:
 image=Image.open(ROOT/'art_source/meshy/spruce_textures'/filename).convert('RGB')
 for suffix,size in [('',2048),('_low',1024)]:
  image.resize((size,size),Image.Resampling.LANCZOS).save(ROOT/'assets/graphics/textures'/f'spruce_model_{channel}{suffix}.jpg',quality=94)

for i in range(1,4):
 path=ROOT/'assets/graphics/textures'/f'spruce_impostor_{i}.png'
 if path.exists():
  Image.open(path).resize((512,512),Image.Resampling.LANCZOS).save(path.with_name(f'spruce_impostor_{i}_low.png'))

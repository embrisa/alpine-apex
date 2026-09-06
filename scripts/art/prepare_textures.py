"""Fetch pinned CC0 source textures and prepare runtime resolutions / spruce atlas."""
from pathlib import Path
import hashlib, json, random, subprocess
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets/graphics/textures'
OUT.mkdir(parents=True, exist_ok=True)
manifest = []
for asset, prefix in [('snow_02','snow'), ('rock_face_03','rock'), ('bark_brown_02','bark')]:
    metadata = ROOT / 'art_source' / (asset+'_files.json')
    if not metadata.exists():
        subprocess.run(['curl','-fsSL','-A','AlpineApex/1.0 (asset import)',f'https://api.polyhaven.com/files/{asset}','-o',str(metadata)],check=True)
    files = json.loads(metadata.read_text())
    for channel, suffix in [('Diffuse','albedo'),('nor_gl','normal'),('arm','orm')]:
        entry = files[channel]['2k']['jpg']
        target = OUT / f'{prefix}_{suffix}.jpg'
        if not target.exists():
            subprocess.run(['curl','-fsSL','--retry','2',entry['url'],'-o',str(target)],check=True)
        assert hashlib.md5(target.read_bytes()).hexdigest() == entry['md5'], target
        Image.open(target).resize((1024,1024),Image.Resampling.LANCZOS).save(OUT/f'{prefix}_{suffix}_low.jpg',quality=94)
        manifest.append(dict(asset=asset,channel=channel,path=str(target.relative_to(ROOT)),url=entry['url'],md5=entry['md5'],license='CC0-1.0',source=f'https://polyhaven.com/a/{asset}'))

# An authored spruce spray: thin central twig, branching stems, individual needles.
# This is a deterministic texture source, not an AI image or downloaded foliage.
random.seed(61941)
im=Image.new('RGBA',(512,1024),(30,50,39,0)); d=ImageDraw.Draw(im)
d.line([(255,1000),(249,40)],fill=(74,65,45,255),width=8)
for side in [-1,1]:
    for k in range(18):
        y=140+k*46; reach=(75+130*k/18)*random.uniform(.8,1.1)
        start=(252,y+70); end=(252+side*reach,y-random.uniform(30,80))
        d.line([start,end],fill=(57,70,42,255),width=4)
        for n in range(28):
            t=n/28; x=start[0]+(end[0]-start[0])*t; yy=start[1]+(end[1]-start[1])*t
            for s in [-1,1]:
                length=random.uniform(13,34)*(1-.35*t)
                tip=(x+side*length*.65,yy+s*length)
                col=random.choice([(42,69,45,255),(62,86,55,255),(79,100,63,255),(48,77,56,255)])
                d.line([(x,yy),tip],fill=col,width=random.choice([2,3,4]))
im.save(OUT/'spruce_needles.png')
im.resize((256,512),Image.Resampling.LANCZOS).save(OUT/'spruce_needles_low.png')
(ROOT/'art_source/texture_sources.json').write_text(json.dumps(manifest,indent=2))
print('Prepared',len(manifest),'verified source maps, 1K derivatives and spruce atlas')

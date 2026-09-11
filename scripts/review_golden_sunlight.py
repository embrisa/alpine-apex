"""Build a local, matched evidence gallery. Screenshots are never recolored."""
from pathlib import Path
import argparse
import json
import os
import subprocess
import sys
from PIL import Image, ImageDraw
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'artifacts/golden_sunlight/review'
PC = ROOT / 'artifacts/pc_environment'

def build_gallery():
    OUT.mkdir(parents=True, exist_ok=True)
    before, after = PC/'golden_baseline', PC/'golden_final'
    a = {v['name']: v for v in json.loads((before/'fixtures.json').read_text())}
    b = {v['name']: v for v in json.loads((after/'fixtures.json').read_text())}
    pairs, stats = [], []
    for name in a.keys() & b.keys():
        if not (before/f'{name}.png').exists():
            continue
        keys = ['position','basis','fov','weather','hour','cloud_offset','sun_direction','sha_height','sha_obstacles']
        assert all(a[name][key] == b[name][key] for key in keys), name
        urls = [os.path.relpath(p/f'{name}.png',OUT).replace('\\','/') for p in [before,after]]
        pairs.append({'name':name,'before':urls[0],'after':urls[1]})
        for stage, path in [('before',before),('after',after)]:
            im = Image.open(path/f'{name}.png').convert('RGB')
            assert im.size == (3840,2160)
            data = np.asarray(im)
            stats.append({'scene':name,'stage':stage,'pixels':list(im.size),
                          'all_channels_254_fraction':float((data.min(axis=2)>=254).mean())})
    pairs.sort(key=lambda p: p['name'])
    (OUT/'matched.json').write_text(json.dumps({'matched':len(pairs),'pairs':pairs,'pixel_statistics':stats},indent=2))
    chosen = ['clear_900_toward','clear_1370_across','clear_2170_away']
    sheet = Image.new('RGB',(1920,3*574),(18,25,34))
    draw = ImageDraw.Draw(sheet)
    for row,name in enumerate(chosen):
        for col,stage in enumerate([before,after]):
            im=Image.open(stage/f'{name}.png').convert('RGB')
            im.thumbnail((960,540),Image.Resampling.LANCZOS)
            sheet.paste(im,(col*960,row*574+34))
            draw.text((col*960+12,row*574+10),('BEFORE' if col==0 else 'GOLDEN NOON')+' | '+name,fill='white')
    sheet.save(OUT/'comparison.jpg',quality=95)
    page='''<!doctype html><meta charset="utf-8"><title>Alpine Apex — golden noon review</title>
<style>body{margin:24px;background:#101923;color:#edf3fa;font:16px system-ui}select,button{font:inherit;padding:8px;margin:8px}main{position:relative;width:min(100%,1600px);aspect-ratio:16/9}main img{position:absolute;inset:0;width:100%;height:100%}#new{clip-path:inset(0 0 0 50%)}input{width:min(100%,1600px)}.grid{display:grid;grid-template-columns:repeat(2,minmax(200px,1fr));gap:16px}#canopy,#quality{grid-template-columns:repeat(3,minmax(200px,1fr))}video{width:100%}a{color:#ffda9b}@media(max-width:700px){.grid,#canopy,#quality{grid-template-columns:1fr}}</style>
<h1>Golden sunlight · unchanged noon</h1><p>Matched 3840 × 2160 output, 75% FSR2, High, 120 FPS cap, SDFGI off. Same camera, weather, cloud phase and v7 surface. Left: fresh baseline. Right: golden lighting.</p>
<p><a href="../../../docs/RENDERING.md">Acceptance report</a> · <a href="../benchmarks.md">Benchmark comparison</a> · <a href="matched.json">Matched metadata</a> · <a href="comparison.jpg">Before/after overview</a></p>
<label>View <select id="scene"></select></label><button id="toggle">Toggle full before/after</button><main><img id="old"><img id="new"></main><input id="wipe" type="range" min="0" max="100" value="50" aria-label="Before after divider"><p id="caption"></p>
<h2>Nearby shadowed rays</h2><p>Four matched positions beneath existing trees. The controls disable only volumetrics or disable directional shadows. The latter changes surface shadows too and is diagnostic only. Click a capture for its native 4K image.</p><div class="grid" id="canopy"></div>
<h2>Quality presets</h2><p>Identical camera and noon light. Low disables glow and shafts; Balanced enables highlight glow; High adds the nearby shadowed volume.</p><div class="grid" id="quality"></div>
<h2>Motion evidence</h2><p>Real 120 Hz solver and fixed 60 Hz presentation/particle steps. Review videos contain 90 sampled frames over 3 seconds at 30 FPS, reduced from 4K to 1080p. Capture overhead is excluded from benchmarks. Adjacent 60 Hz native frames remain available.</p><div class="grid" id="videos"></div>
<script>const pairs=PAIRS;const scene=document.querySelector('#scene'),old=document.querySelector('#old'),fresh=document.querySelector('#new'),wipe=document.querySelector('#wipe');for(const p of pairs){const o=new Option(p.name,p.name);scene.add(o)}function select(){const p=pairs.find(p=>p.name===scene.value);old.src=p.before;fresh.src=p.after;document.querySelector('#caption').textContent=p.name+' — geometry and camera metadata matched';}scene.onchange=select;wipe.oninput=()=>fresh.style.clipPath=`inset(0 0 0 ${wipe.value}%)`;document.querySelector('#toggle').onclick=()=>{wipe.value=wipe.value<50?100:0;wipe.oninput()};scene.value='clear_900_toward';select();const clips=CLIPS;for(const c of clips){const box=document.createElement('div'),v=document.createElement('video'),p=document.createElement('p');v.src=c.url;v.controls=true;v.loop=true;v.preload='none';p.textContent=c.name;box.append(v,p);document.querySelector('#videos').append(box)}</script>'''
    clips=[{'name':p.stem,'url':os.path.relpath(p,OUT).replace('\\','/')} for p in sorted((PC/'golden_motion').glob('*.mp4'))]
    def capture_cards(folder, names):
        cards=[]
        for name in names:
            path=folder/f'{name}.png'
            assert path.exists(),path
            url=os.path.relpath(path,OUT).replace('\\','/')
            cards.append(f'<figure style="margin:0"><a href="{url}"><img loading="lazy" src="{url}" alt="{name}" style="width:100%"></a><figcaption>{name}</figcaption></figure>')
        return ''.join(cards)
    canopy_names=[f'canopy_{tree}_{distance}m{suffix}' for tree in [0,1] for distance in [8,14]
                  for suffix in ['', '_shafts_off', '_occlusion_off']]
    for tree in [0,1]:
        for distance in [8,14]:
            group=[b[f'canopy_{tree}_{distance}m{suffix}'] for suffix in ['', '_shafts_off', '_occlusion_off']]
            assert all(group[0][key]==v[key] for v in group[1:] for key in keys)
    page=page.replace('<div class="grid" id="canopy"></div>', '<div class="grid" id="canopy">'+capture_cards(after,canopy_names)+'</div>')
    page=page.replace('<div class="grid" id="quality"></div>', '<div class="grid" id="quality">'+capture_cards(PC/'golden_quality',['quality_low','quality_balanced','quality_high'])+'</div>')
    (OUT/'index.html').write_text(page.replace('PAIRS',json.dumps(pairs)).replace('CLIPS',json.dumps(clips)),encoding='utf-8')
    print('MATCHED_GALLERY',len(pairs),'pairs;',len(clips),'videos')

def encode_motion():
    sys.path.insert(0,str(ROOT/'artifacts/golden_sunlight/python_libs'))
    import imageio_ffmpeg
    ffmpeg=imageio_ffmpeg.get_ffmpeg_exe()
    folder=PC/'golden_motion'
    report=json.loads((folder/'motion.json').read_text())
    for clip in report['clips']:
        target=folder/(clip['clip']+'.mp4')
        if target.exists():
            continue
        subprocess.run([ffmpeg,'-v','error','-framerate','30','-i',str(folder/clip['clip']/'%03d.jpg'),'-frames:v','90','-c:v','libx264','-preset','fast','-crf','18','-pix_fmt','yuv420p','-movflags','+faststart',str(target)],check=True)
        print('ENCODED',target.name,flush=True)

if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--encode',action='store_true')
    args=parser.parse_args()
    if args.encode: encode_motion()
    build_gallery()

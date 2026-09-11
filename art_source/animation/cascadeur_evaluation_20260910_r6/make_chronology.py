"""Full front chronology, 32 consecutive samples per contact sheet."""
import argparse,json,sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[3]/'.tools/motion-plots'))
from PIL import Image,ImageDraw
p=argparse.ArgumentParser();p.add_argument('revision',type=Path);a=p.parse_args()
out=a.revision/'chronology';out.mkdir(exist_ok=True)
m=json.loads((a.revision/'capture/manifest.json').read_text())
for case in m['scenarios']:
    for start in range(0,case['frames'],32):
        sheet=Image.new('RGB',(1920,1280),'#171a20');draw=ImageDraw.Draw(sheet)
        for k,frame in enumerate(range(start,min(start+32,case['frames']))):
            photo=Image.open(a.revision/'frames'/case['name']/f'{frame:04d}.jpg').crop((800,0,1600,1000));photo.thumbnail((240,300))
            x=(k%8)*240;y=(k//8)*320;sheet.paste(photo,(x,y+20));draw.text((x+5,y+3),f'{case["name"]} {frame:03d} / {frame/30:.3f}s',fill='white')
        path=out/f'{case["name"]}-{start:03d}.jpg';assert not path.exists();sheet.save(path,quality=93)
print(out)

"""Chronological front-view inspection sheets. Every frame retained in order."""
import json, sys, math
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[3]/'.tools/motion-plots'))
from PIL import Image,ImageDraw,ImageFont
base=Path(__file__).resolve().parents[3]/'artifacts/pose_review/revisions'
font=ImageFont.truetype('consola.ttf',17)
for variant in ['source','production','gameplay']:
    folder=base/f'cascadeur-20260910-r7-{variant}'
    output=folder/'inspection';output.mkdir(exist_ok=True)
    manifest=json.loads((folder/'capture/manifest.json').read_text())
    for case in manifest['scenarios']:
        name=case['name'];files=sorted((folder/'frames'/name).glob('*.jpg'))
        assert len(files)==case['frames']
        for page in range(math.ceil(len(files)/42)):
            chunk=files[page*42:(page+1)*42]
            sheet=Image.new('RGB',(7*230,6*230+35),'#18212b');draw=ImageDraw.Draw(sheet)
            draw.text((8,5),f'{variant} / {name} / frames {chunk[0].stem}-{chunk[-1].stem}',fill='white',font=font)
            for i,p in enumerate(chunk):
                # Crop the whole front-view rider and full poles, with common bounds.
                image=Image.open(p).crop((800,220,1600,880));image.thumbnail((230,205))
                x=i%7*230;y=i//7*230+35;sheet.paste(image,(x,y));draw.text((x+5,y+205),p.stem,fill='white',font=font)
            target=output/f'{name}_front_{page}.jpg';assert not target.exists();sheet.save(target,quality=94)
print('All front-frame inspection sheets prepared.')

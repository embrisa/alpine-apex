"""Inspect chronology and prepare analytical contact sheets, without pose edits."""
import argparse, json, math
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
from revision import ensure_writable, load_capture, read_json, selected_rows
from select_frames import select

ROOT = Path(__file__).resolve().parents[2]
parser = argparse.ArgumentParser()
parser.add_argument('--revision', required=True)
parser.add_argument('--sheets', action='store_true')
args = parser.parse_args()
revision, manifest, captures = load_capture(args.revision)
selection = read_json(revision / 'selection.json') if (revision / 'selection.json').exists() else {}
if args.sheets: ensure_writable(revision)
try: font = ImageFont.truetype('consola.ttf', 18)
except OSError: font = ImageFont.load_default()
for case in manifest['scenarios']:
    name = case['name']
    trace = captures[name]
    rows = trace['frames']
    print(name, 'events', trace['events'])
    print(' frame time phase hips_m tuck prepare bank_deg')
    ids = selection.get(name) or select(dict(trace, name=name))[0]
    for r in selected_rows(rows, ids):
        print(int(r['frame']), round(r['time'],3), r['phase'], round(r['joints']['Hips'][1],3), round(r['state']['tuck'],2), round(r['state']['prepare'],2), round(math.degrees(r['body_roll_rad']),1))
    if args.sheets:
        indices=list(range(0,len(rows),12))
        sheet=Image.new('RGB',(6*300,math.ceil(len(indices)/6)*420),'#16212b')
        draw=ImageDraw.Draw(sheet)
        for idx,index in enumerate(indices):
            frame = int(rows[index]['frame'])
            image=Image.open(revision/'frames'/name/f'{frame:04d}.jpg').crop((0,0,800,1000))
            image.thumbnail((300,375))
            x=(idx%6)*300;y=(idx//6)*420
            sheet.paste(image,(x,y))
            draw.text((x+5,y+378),f'{frame:03d} {rows[index]["time"]:.3f}s',font=font,fill='white')
            draw.text((x+5,y+398),rows[index]['phase'],font=font,fill='#ffb376')
        out=revision/'inspection';out.mkdir(exist_ok=True)
        target=out/(name+'.jpg')
        if target.exists(): raise ValueError(f'Contact sheet already exists: {target}')
        sheet.save(target,quality=95)

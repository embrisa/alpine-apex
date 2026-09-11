"""Create chronological inspection sheets and leg-view videos from frozen renders."""
import json
import subprocess
import sys
from pathlib import Path

ROOT=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(ROOT/'.tools/motion-plots'))
from PIL import Image, ImageDraw

FFMPEG=ROOT/'.tools/animation-video/imageio_ffmpeg/binaries/ffmpeg-win-x86_64-v7.1.exe'
for variant in ('before','after'):
    revision=f'cascadeur-20260911-r8-01-{variant}'
    folder=ROOT/'artifacts/pose_review/revisions'/revision
    assert not (folder/'sealed.json').exists()
    subprocess.run([sys.executable,str(ROOT/'scripts/pose_review/encode_videos.py'),'--revision',revision,'--ffmpeg',str(FFMPEG)],check=True)
    inspection=folder/'inspection';inspection.mkdir(exist_ok=False)
    for case in json.loads((folder/'capture/manifest.json').read_text())['scenarios']:
        name=case['name']
        frames=sorted((folder/'frames'/name).glob('*.jpg'))
        assert len(frames)==121
        subprocess.run([str(FFMPEG),'-hide_banner','-loglevel','error','-n','-framerate','30','-i',str(folder/'frames'/name/'%04d.jpg'),'-frames:v','121','-vf','crop=800:600:800:350','-c:v','libx264','-threads','2','-crf','18','-pix_fmt','yuv420p','-movflags','+faststart',str(folder/'videos'/f'{name}_legs.mp4')],check=True)
        for start in range(0,len(frames),42):
            sheet=Image.new('RGB',(7*230,6*305+35),'#18212b');draw=ImageDraw.Draw(sheet)
            draw.text((8,8),f'{variant} / {name} / chronological frames {start:04d}-{min(start+41,120):04d}',fill='white')
            for idx,path in enumerate(frames[start:start+42]):
                tile=Image.open(path).crop((800,0,1600,1000)).resize((230,287))
                x=idx%7*230;y=35+idx//7*305
                sheet.paste(tile,(x,y));draw.text((x+5,y+287),path.stem,fill='white')
            sheet.save(inspection/f'{name}_{start//42}.jpg',quality=92)
    print('R8_MEDIA_COMPLETE',variant,flush=True)

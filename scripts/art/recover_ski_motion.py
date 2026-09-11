"""Expand the local research set without editing the decoder or native originals.

python scripts/art/recover_ski_motion.py --decoder PATH/decoder
Then run retarget_ski_research.py against artifacts/steep_motion_gameplay/exports/
Steep_ID01_Female_Core_Motion.glb, with --out .../retarget --skip-sheet.
Requires the already verified local AnvilToolkit decoder, not an archive rewrite.
"""
import argparse
import hashlib
import json
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CLIPS = """NAV_MED_FWD NAV_MED_LEFT NAV_MED_RIGHT OLLIE_BACKFLIP_TO_AIR
AIR_BACKFLIP_LONG AIR_TO_LAND_BACKFLIP GRAB_SAFETY AIR_TO_LAND_BACKFLIP_SPINLEFT_PANIC
NAV_SLOW_FWD NAV_SLOW_LEFT NAV_SLOW_RIGHT NAV_FAST_FWD NAV_FAST_FWD_SPEED
NAV_FAST_LEFT_SPEED NAV_FAST_RIGHT_SPEED NAV_OLLIE_FWD OLLIE_HIGH_TO_AIR AIR AIR_LONG
AIR_TO_LAND LANDING_TO_FWD_MED_P01_01 LANDING_TO_FWD_MED_P03_01
NAV_DRIFT_LEFT_FWD_10 NAV_DRIFT_LEFT_FWD_90 NAV_MED_TURNS_SWITCH
NAV_OLLIE_FWD_SWITCH_HEAD_LEFT OLLIE_HIGH_TO_AIR_SWITCH_HEAD_LEFT
LANDING_TO_FWD_MED_P01_01_SWITCH_HEAD_LEFT AIR_SPINLEFT_LONG AIR_SPINRIGHT_LONG
AIR_FRONTFLIP_LONG GRAB_MUTE NAV_FWD_SOFT_COLLISION_01""".split()


def main():
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument('--decoder', type=Path, required=True)
    parser.add_argument('--out', type=Path, default=ROOT/'artifacts/steep_motion_gameplay')
    args = parser.parse_args()
    source = args.decoder.resolve()
    work = args.out.resolve()/'decoder'
    assert not work.is_relative_to(source) and not source.is_relative_to(work)
    work.mkdir(parents=True, exist_ok=True)
    sys.path.insert(0, str(source))
    from probe_tracks import inspect, ANIMS
    from decode_times import times_from_track
    records = []
    for name in CLIPS:
        files = list(ANIMS.glob('*_-_ID01_PS00_female_'+name+'.Animation'))
        assert len(files) == 1, (name, files)
        rec = inspect(files[0])
        assert len(rec['candidates']) == 1 and rec['candidates'][0]['trailing'] == 0
        records.append(rec)
    layouts = work/'selected-track-layouts.json'
    layouts.write_text(json.dumps(records, indent=2))
    subprocess.run([str(source/'bin/probe/Probe.exe'), 'keys', str(layouts),
                    str(ANIMS), str(work/'selected-decoded-keys.json')], check=True)
    clips = json.loads((work/'selected-decoded-keys.json').read_text())
    corrections = 0
    for clip, layout in zip(clips, records, strict=True):
        data = (ANIMS/layout['file']).read_bytes()
        for track, raw in zip(clip['tracks'], layout['candidates'][0]['tracks'], strict=True):
            times = times_from_track(data, raw)
            for key, time in zip(track['keys'], times, strict=True):
                corrections += abs(key['time']-time) > 1e-5
                key['time'] = time
    (work/'selected-decoded-tracks.json').write_text(json.dumps(clips, indent=2))
    for name in ['sample-rigs.json', 'bone-names.json', 'build_glb.py']:
        shutil.copyfile(source/name, work/name)
    subprocess.run([sys.executable, str(work/'build_glb.py')], check=True)
    report = {'clips': CLIPS, 'corrected_timestamps': corrections,
              'original_resources': [{'file': r['file'], 'sha256': r['sha256']} for r in records],
              'decoder_files': {n: hashlib.sha256((source/n).read_bytes()).hexdigest()
                                for n in ['probe_tracks.py', 'decode_times.py', 'build_glb.py', 'Program.cs']},
              'scope': 'Local core-body prototype. Names select candidates; gameplay roles are Apex mappings, not recovered Steep graph timing.'}
    (args.out/'recovery-manifest.json').write_text(json.dumps(report, indent=2))
    print('RECOVERED', len(clips), 'clips; corrected', corrections, 'timestamps')


if __name__ == '__main__':
    main()

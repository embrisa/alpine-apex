"""Audit and encode actual v13 gameplay frames; never generate substitute images."""
import argparse
import hashlib
import json
import math
import re
import subprocess
from pathlib import Path
from statistics import mean

ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT/'artifacts/steep_motion_gameplay'


def visual_folder(variant, name):
    return BASE/f'{variant}_visual'


def vector(value):
    return [float(x) for x in value[value.index('(')+1:value.index(')')].split(',')]


def stats(values):
    if not values:
        return {}
    a = sorted(values)
    return {'n':len(a), 'mean':mean(a), 'p95':a[int((len(a)-1)*.95)],
            'p99':a[int((len(a)-1)*.99)], 'max':a[-1]}


def report():
    before = json.loads((BASE/'before_visual/results.json').read_text())
    after = json.loads((BASE/'after_visual/results.json').read_text())
    assert before['height_sha256']==after['height_sha256']
    assert before['obstacle_sha256']==after['obstacle_sha256']
    assert before['physics']==after['physics']==19
    if 'sources' in before or 'sources' in after:
        assert before['sources']==after['sources'], 'Runtime sources changed between native runs'
        for path, expected in after['sources'].items():
            assert hashlib.sha256((ROOT/path).read_bytes()).hexdigest()==expected, 'Evidence source is stale: '+path
    results = []
    for left, right in zip(before['cases'], after['cases'], strict=True):
        name = right['scenario']
        assert left['scenario']==name
        assert left['samples']==right['samples'], 'Different physical input/state '+name
        for a,b in zip(left['orientation_trace'], right['orientation_trace'], strict=True):
            assert a['physical_q']==b['physical_q'], 'Different physical frame '+name
        pose = json.loads((visual_folder('after',name)/f'{name}_motion.json').read_text())
        residuals = {}
        final_steps = []
        angular_steps = []
        velocity_changes = []
        prior = None
        prior_velocity = {}
        for row in pose['trace']:
            phase = row['diagnostics']['phase']
            stage = residuals.setdefault(phase, {})
            for k,v in row['diagnostics'].items():
                if isinstance(v,(int,float)):
                    stage.setdefault(k,[]).append(v)
            for joint in ('Hips','Spine','LeftHand','RightHand','LeftLeg','RightLeg'):
                if joint not in row['requested']: continue
                a,b = vector(row['requested'][joint]),vector(row['joints'][joint])
                stage.setdefault(joint+'_source_to_final_m',[]).append(math.dist(a,b))
            if prior:
                dt = row['seconds']-prior['seconds']
                for joint,point in row['joints'].items():
                    p0,p1 = vector(prior['joints'][joint]),vector(point)
                    final_steps.append(math.dist(p0,p1))
                    velocity = [(b-a)/dt for a,b in zip(p0,p1)]
                    if joint in prior_velocity:
                        velocity_changes.append(math.dist(prior_velocity[joint],velocity))
                    prior_velocity[joint] = velocity
                for joint,q1 in row['rotations'].items():
                    a,b = vector(prior['rotations'][joint]),vector(q1)
                    dot = abs(sum(x*y for x,y in zip(a,b)))/(math.sqrt(sum(x*x for x in a))*math.sqrt(sum(x*x for x in b)))
                    angular_steps.append(2*math.acos(min(1,dot)))
            prior = row
        results.append({'name':name,'physical_equality':True,'hops':right['hops'],
                        'airtime_s':right['airtime_s'],'crash':right['crash'],
                        'render_sample_hz':30,'final_joint_steps_m':stats(final_steps),
                        'final_joint_angular_steps_rad':stats(angular_steps),
                        'final_joint_velocity_changes_mps':stats(velocity_changes),
                        'fitting_by_phase':{p:{k:stats(v) for k,v in d.items()} for p,d in residuals.items()}})
    data = {'cases':results,'failures':before['failures']+after['failures'],
            'physical_comparison':'Same initial states and inputs; recorded physical positions, reserve, orientation and supported state match.',
            'scope':'Native scripted gameplay. Stored source pose, post-fitting landmarks, final skeleton and continuous traces; human skiing acceptance is separate.'}
    (BASE/'comparison.json').write_text(json.dumps(data,indent=2))
    print('MATCHED',len(results),'gameplay scenarios; failures',data['failures'])


def timing_report():
    paths = [BASE/f'{variant}_timing/results.json' for variant in ('before','after')]
    if not all(path.exists() for path in paths): return
    before, after = [json.loads(path.read_text()) for path in paths]
    for key in ('actual_pixels','display','quality','height_sha256','obstacle_sha256','physics','sources'):
        assert before[key]==after[key], 'Mismatched timing input: '+key
    assert after['actual_pixels']==[3840,2160]
    assert after['display']['internal_pixels_from_viewport_scale']==[2880,1620]
    assert after['quality']=='high'
    for path, expected in after['sources'].items():
        assert hashlib.sha256((ROOT/path).read_bytes()).hexdigest()==expected, 'Timing source is stale: '+path
    for a,b in zip(before['cases'],after['cases'],strict=True):
        assert a['scenario']==b['scenario'] and a['samples']==b['samples']
    data = {'scope':'Exclusive Godot v13 scripted gameplay; 29 seconds of simulation across seven fixtures per variant. User-authorized concurrent WoW and Discord capture activity is logged in timing-gpu.jsonl. No screenshots during timing. Shared-load results do not certify isolated FPS or whole-course performance.',
            'procedural':before,'full_motion':after,
            'mean_fps':{k:1000/v['frame_ms']['mean'] for k,v in [('procedural',before),('full_motion',after)]}}
    (BASE/'performance.json').write_text(json.dumps(data,indent=2))
    print('4K TIMING',data['mean_fps'])


def encode():
    executable = ROOT/'.tools/animation-video/imageio_ffmpeg/binaries/ffmpeg-win-x86_64-v7.1.exe'
    output = BASE/'clips'; output.mkdir(exist_ok=True)
    records = json.loads((BASE/'after_visual/results.json').read_text())['cases']
    manifest = []
    for view in ('chase','side'):
        files = []
        for record in records:
            name = record['scenario']
            folders = [visual_folder(variant,name)/f'{name}_{view}' for variant in ('before','after')]
            count = int(round(record['samples'][-1]['seconds']*30))+15
            # Actual duration comes from the physical trace, not directory glob
            # counts: older quick captures must never extend a recorded run.
            count = len(record['orientation_trace'])
            assert all((d/f'{i:04d}.jpg').exists() for d in folders for i in range(count))
            target = output/f'{name}_{view}.mp4'
            args = [str(executable),'-hide_banner','-loglevel','error','-y','-filter_complex_threads','1']
            for folder in folders: args += ['-threads','1','-framerate','30','-i',str(folder/'%04d.jpg')]
            args += ['-filter_complex','[0:v][1:v]hstack=inputs=2[v]','-map','[v]',
                     '-c:v','libx264','-threads','2','-preset','fast','-crf','19','-frames:v',str(count),
                     '-pix_fmt','yuv420p','-movflags','+faststart',str(target)]
            subprocess.run(args,check=True)
            files.append(target.name)
            manifest.append({'name':name,'view':view,'frames':count,'fps':30,'path':str(target)})
        concat = output/f'{view}.txt'
        concat.write_text(''.join(f"file '{n}'\n" for n in files),encoding='utf-8')
        subprocess.run([str(executable),'-hide_banner','-loglevel','error','-y','-f','concat',
                        '-safe','1','-i',str(concat),'-c','copy','-movflags','+faststart',
                        str(output/f'comparison_{view}.mp4')],check=True)
    (output/'manifest.json').write_text(json.dumps(manifest,indent=2))
    print('ENCODED',len(manifest),'matched native motion clips')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument('--encode',action='store_true')
    args = parser.parse_args()
    report()
    timing_report()
    if args.encode: encode()

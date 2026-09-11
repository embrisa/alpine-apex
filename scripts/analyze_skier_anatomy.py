"""Independent audit of recorded production poses; no synthetic render evidence."""
import json
import math
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / '.tools/motion-plots'))
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from PIL import Image

BASE = ROOT / 'artifacts/skier_anatomy'
FINAL = BASE / 'after_visual'
OLD = ROOT / 'artifacts/steep_motion_gameplay/after_visual'


def value(s):
    return np.array([float(x) for x in s.split('(', 1)[1].split(')', 1)[0].split(',')])


def multiply(a, b):
    return np.r_[a[3]*b[:3]+b[3]*a[:3]+np.cross(a[:3], b[:3]), a[3]*b[3]-a[:3]@b[:3]]


def inverse(q):
    return np.r_[-q[:3], q[3]]


def rotvec(q):
    q = q / np.linalg.norm(q)
    if q[3] < 0: q = -q
    n = np.linalg.norm(q[:3])
    return q[:3]/max(n, 1e-12)*2*math.atan2(n, max(0., q[3]))


def twist(q, axis):
    return (2*math.atan2(q[:3]@axis, q[3])+math.pi) % (2*math.pi)-math.pi


def normalized(v):
    return v / np.linalg.norm(v)


def main():
    text = (ROOT / 'scripts/core/rider_body.gd').read_text()
    rest = {k: np.array([float(x) for x in v.split(',')]) for k, v in
            re.findall(r'"([A-Za-z0-9]+)":Vector3\(([^)]+)\)', text)}
    maxima = {}
    cases = {}
    failures = []

    def measure(key, degrees, limit, case, row):
        if degrees > maxima.get(key, {}).get('degrees', -1):
            maxima[key] = dict(degrees=float(degrees), limit_degrees=limit,
                               case=case, seconds=row['seconds'])

    report = json.loads((FINAL / 'results.json').read_text())
    for case in report['cases']:
        name = case['scenario']
        rows = json.loads((FINAL / (name+'_motion.json')).read_text())['trace']
        for row in rows:
            r = {k: value(v) for k, v in row['rotations'].items()}
            for parent, child, limits in [('Hips', 'Spine02', (20, 10, 8)),
                                         ('Spine02', 'Spine01', (20, 10, 8)),
                                         ('Spine01', 'Spine', (20, 10, 8)),
                                         ('Spine', 'neck', (22, 28, 14)),
                                         ('neck', 'Head', (30, 30, 12))]:
                v = np.degrees(rotvec(multiply(inverse(r[parent]), r[child])))
                for i, axis in enumerate('xyz'):
                    measure(child+'_'+axis, abs(v[i]), limits[i], name, row)
            for side in ['Right', 'Left']:
                for arm in [True, False]:
                    a, b, c = [side+s for s in (('Arm', 'ForeArm', 'Hand') if arm else ('UpLeg', 'Leg', 'Foot'))]
                    hinge = normalized(np.cross(rest[b]-rest[a], rest[c]-rest[b]))
                    v = rotvec(multiply(inverse(r[a]), r[b]))
                    off = np.linalg.norm(v-hinge*(v@hinge))
                    measure(('elbow' if arm else 'knee')+'_off_axis', math.degrees(off), .12, name, row)
                q = multiply(inverse(r[side+'Foot']), r[side+'Leg'])
                measure('shin_twist', abs(math.degrees(twist(q, np.array([0., 1., 0.])))), 18.1, name, row)
                axis = normalized(rest[side+'Hand']-rest[side+'ForeArm'])
                q = multiply(inverse(r[side+'ForeArm']), r[side+'Hand'])
                angle = twist(q, axis)
                swing = rotvec(multiply(q, np.r_[axis*math.sin(-angle/2), math.cos(angle/2)]))
                measure('wrist_swing', math.degrees(np.linalg.norm(swing)), 28.1, name, row)
                measure('wrist_twist', abs(math.degrees(angle)), 55.1, name, row)
        cases[name] = dict(frames=len(rows), crash=case['crash'])
    for key, peak in maxima.items():
        if peak['degrees'] > peak['limit_degrees']+.02:
            failures.append(f'{key}: {peak}')
    old = json.loads((OLD/'results.json').read_text())
    old_cases = {c['scenario']: c for c in old['cases']}
    identical = old['height_sha256'] == report['height_sha256'] and old['obstacle_sha256'] == report['obstacle_sha256']
    for case in report['cases']:
        previous = old_cases[case['scenario']]
        identical &= case['orientation_trace'] == previous['orientation_trace'] and case['samples'] == previous['samples']
    if not identical:
        failures.append('Physical state or world identity differs from the recorded comparison')
    result = dict(cases=cases, maxima=maxima, failures=failures,
                  physical_trace_identical_to_rejected_integration=bool(identical), native_failures=report['failures'])
    (BASE/'native-anatomy-audit.json').write_text(json.dumps(result, indent=2))

    # Sequential native frames expose pose changes that a single still hides.
    plt.rcParams.update({'figure.facecolor': '#f3f5f7', 'font.size': 9})
    for name in ['edge_change', 'tuck_to_turn', 'prepared_hop', 'safety_grab', 'mute_grab', 'flip_release']:
        count = cases[name]['frames']
        indices = np.linspace(0, count-1, 6).astype(int)
        fig, axes = plt.subplots(2, 6, figsize=(18, 4.8), layout='constrained')
        for vi, view in enumerate(['chase', 'side']):
            for col, index in enumerate(indices):
                axes[vi, col].imshow(Image.open(FINAL / (name+'_'+view) / f'{index:04d}.jpg'))
                axes[vi, col].axis('off')
                axes[vi, col].set_title(f'{view} / {index/30:.2f}s')
        fig.suptitle(name.replace('_', ' ').title()+' — corrected production gameplay, chronological frames')
        fig.savefig(BASE / (name+'-sequence.png'), dpi=150)
        plt.close(fig)
    print(json.dumps(result, indent=2))
    return 1 if failures or report['failures'] else 0


if __name__ == '__main__':
    raise SystemExit(main())

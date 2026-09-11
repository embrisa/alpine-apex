"""Audit final production gameplay poses, including the calibrated elbow zero."""
import json
import math
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / '.tools/motion-plots'))
import numpy as np

BASE = ROOT / 'artifacts/deep_tuck'

def value(s):
    return np.array([float(x) for x in s.split('(', 1)[1].split(')', 1)[0].split(',')])

def unit(v):
    return v / max(np.linalg.norm(v), 1e-12)

def mul(a, b):
    return np.r_[a[3]*b[:3]+b[3]*a[:3]+np.cross(a[:3], b[:3]), a[3]*b[3]-a[:3]@b[:3]]

def inv(q):
    return np.r_[-q[:3], q[3]]

def rotate(q, v):
    return mul(mul(q, np.r_[v, 0.]), inv(q))[:3]

def rotvec(q):
    q = unit(q)
    if q[3] < 0: q = -q
    return unit(q[:3])*2*math.atan2(np.linalg.norm(q[:3]), max(0., q[3]))

def axis_angle(axis, angle):
    return np.r_[axis*math.sin(angle/2), math.cos(angle/2)]

def twist(q, axis):
    return (2*math.atan2(q[:3]@axis, q[3])+math.pi) % (2*math.pi)-math.pi

def main():
    rest = {k: np.array([float(x) for x in v.split(',')]) for k, v in
            re.findall(r'"([A-Za-z0-9]+)":Vector3\(([^)]+)\)', (ROOT/'scripts/core/rider_body.gd').read_text())}
    report = json.loads((BASE/'after_visual/results.json').read_text())
    peaks, failures, cases = {}, [], {}

    def bound(key, measured, limit, case, seconds):
        if measured > peaks.get(key, {}).get('value', -1):
            peaks[key] = dict(value=float(measured), limit=limit, case=case, seconds=seconds)

    for case in report['cases']:
        name = case['scenario']
        rows = json.loads((BASE/'after_visual'/f'{name}_motion.json').read_text())['trace']
        silhouette = []
        for row in rows:
            r = {k: value(v) for k, v in row['rotations'].items()}
            j = {k: value(v) for k, v in row['joints'].items()}
            for parent, child, limits in [(None, 'Hips', (55,25,32)), ('Hips','Spine02',(20,10,8)),
                    ('Spine02','Spine01',(20,10,8)), ('Spine01','Spine',(20,10,8)),
                    ('Spine','neck',(22,28,14)), ('neck','Head',(30,30,12)),
                    ('Spine','RightShoulder',(12,15,12)), ('Spine','LeftShoulder',(12,15,12))]:
                local = mul(inv(r[parent]), r[child]) if parent else r[child]
                for axis, measured, limit in zip('xyz', np.degrees(abs(rotvec(local))), limits):
                    bound(child+'_'+axis+'_deg', measured, limit+.1, name, row['seconds'])
            for side in ['Right','Left']:
                for arm in [True, False]:
                    a,b,c = [side+s for s in (('Arm','ForeArm','Hand') if arm else ('UpLeg','Leg','Foot'))]
                    upper, lower = rest[b]-rest[a], rest[c]-rest[b]
                    axis = unit(np.cross(upper, np.array([0.,0.,1.]) if arm else lower))
                    local = mul(inv(r[a]),r[b])
                    if arm:
                        u, v = unit(lower), unit(lower-axis*(lower@axis))
                        zero = unit(np.r_[np.cross(u,v), 1+u@v])
                        local = mul(local,inv(zero))
                    rv = rotvec(local)
                    bound(('elbow' if arm else 'knee')+'_off_axis_deg', math.degrees(np.linalg.norm(rv-axis*(rv@axis))), .12, name, row['seconds'])
                    bend = math.degrees(math.acos(np.clip(unit(j[b]-j[a])@unit(j[c]-j[b]),-1,1)))
                    bound(('elbow' if arm else 'knee')+'_bend_deg', bend, 145.1 if arm else 155., name, row['seconds'])
                for bone, parent, axis, swing_limit, twist_limit in [
                        (side+'Arm',side+'Shoulder',unit(rest[side+'ForeArm']-rest[side+'Arm']),125.1,55.1),
                        (side+'Hand',side+'ForeArm',unit(rest[side+'Hand']-rest[side+'ForeArm']),28.1,55.1)]:
                    local = mul(inv(r[parent]),r[bone]); axial = twist(local,axis)
                    swing = np.linalg.norm(rotvec(mul(local,axis_angle(axis,-axial))))
                    bound(bone+'_swing_deg',math.degrees(swing),swing_limit,name,row['seconds'])
                    bound(bone+'_twist_deg',abs(math.degrees(axial)),twist_limit,name,row['seconds'])
            if name=='deep_tuck' and row['seconds']>=1.0 and row['grounded']:
                chest = rotate(r['Spine'], np.array([0.,1.,0.]))
                lateral = rotate(r['Spine'],np.array([1.,0.,0.]))
                silhouette.append(dict(seconds=row['seconds'],pitch_deg=math.degrees(math.atan2(chest[2],chest[1])),
                    hand_span_m=float((j['LeftHand']-j['RightHand'])@lateral),
                    elbow_span_m=float((j['LeftForeArm']-j['RightForeArm'])@lateral)))
        previous_folder = BASE/'hinge_fold_visual' if name not in ['safety_grab','mute_grab'] else ROOT/'artifacts/skier_anatomy/after_visual'
        previous = json.loads((previous_folder/'results.json').read_text())
        old = next(c for c in previous['cases'] if c['scenario']==name)
        equal = all(case[k]==old[k] for k in ['orientation_trace','samples']) and all(report[k]==previous[k] for k in ['height_sha256','obstacle_sha256'])
        if not equal: failures.append(name+': physical/world samples differ')
        cases[name] = dict(frames=len(rows), physics_identical=equal, crash=case['crash'], silhouette=silhouette)
    for key, peak in peaks.items():
        if peak['value']>peak['limit']+.02: failures.append(key+': '+str(peak))
    failures += report['failures']
    result = dict(cases=cases,peaks=peaks,failures=failures)
    (BASE/'native-audit.json').write_text(json.dumps(result,indent=2))
    print(json.dumps(dict(cases=len(cases), frames=sum(c['frames'] for c in cases.values()),failures=failures)))
    return bool(failures)

if __name__=='__main__':
    raise SystemExit(main())

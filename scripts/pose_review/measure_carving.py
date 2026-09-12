"""Gravity/heading lean and response trace for proportional-carving captures."""
import argparse
import json
import math
import statistics
from pathlib import Path
from revision import ensure_writable, write_json


def sub(a, b):
    return [x-y for x, y in zip(a, b)]


def world(basis, vector):
    return [sum(basis[j][i]*vector[j] for j in range(3)) for i in range(3)]


def lean(vector, heading):
    lateral = -math.cos(heading)*vector[0]+math.sin(heading)*vector[2]
    return math.degrees(math.asin(max(-1, min(1, lateral/max(1e-9, math.sqrt(sum(x*x for x in vector)))))))


def measure(row):
    j = row['joints']
    feet = [(a+b)/2 for a, b in zip(j['LeftFoot'], j['RightFoot'])]
    body = world(row['root']['basis'], sub(j['Spine'], feet))
    torso = world(row['root']['basis'], row['rotations']['Spine'][1])
    pelvis = world(row['root']['basis'], sub(j['Hips'], feet))
    h = row['heading_rad']
    return {'time': row['time'], 'body_deg': lean(body, h), 'torso_deg': lean(torso, h),
            'pelvis_lateral_m': -math.cos(h)*pelvis[0]+math.sin(h)*pelvis[2],
            'turn_rate_rad_s': row['turn_rate_rad_s'], 'speed_mps': row['speed_mps'],
            'turn_acceleration_mps2': row['turn_rate_rad_s']*row['speed_mps'],
            'bank_deg': math.degrees(row['body_roll_rad']), 'input': row['input']['steer'],
            'edge_channel': row['diagnostics']['physical_turn'],
            'animation_turn': row['diagnostics']['animation_turn'],
            'downhill': row['downhill_weight'], 'action': row['action_weights'][0]}


def summarize(rows):
    trace = [measure(r) for r in rows]
    active = [r for r in trace if r['input']]
    release = active[-1]['time'] if active else 0
    initial = trace[28]
    direction = math.copysign(1, active[0]['input']) if active else 1
    entry = [r for r in active if r['time'] < active[0]['time']+.75]
    def settling(predicate):
        tail = [r for r in trace if r['time'] > release]
        bad = [r['time'] for r in tail if not predicate(r)]
        last = max(bad, default=release)
        return last-release if trace[-1]['time']-last >= .25 else None

    result = {'peak_body_deg': max(abs(r['body_deg']) for r in trace),
              'peak_torso_deg': max(abs(r['torso_deg']) for r in trace),
              'opposite_body_deg': max([0]+[-direction*(r['body_deg']-initial['body_deg']) for r in entry]),
              'opposite_torso_deg': max([0]+[-direction*(r['torso_deg']-initial['torso_deg']) for r in entry]),
              'peak_time_s': max(trace, key=lambda r: abs(r['body_deg']))['time'],
              'peak_turn_acceleration_mps2': max(abs(r['turn_acceleration_mps2']) for r in trace),
              'max_action': max(r['action'] for r in trace),
              'peak_pelvis_lateral_m': max(abs(r['pelvis_lateral_m']) for r in trace),
              'opposite_entry_seconds': sum(-direction*(r['body_deg']-initial['body_deg']) > 1 for r in entry)/60,
              'path_settling_s': settling(lambda r: abs(r['turn_acceleration_mps2']) < .5),
              'support_settling_s': settling(lambda r: abs(r['turn_acceleration_mps2']) < .5 and abs(r['edge_channel']) < .22),
              'pose_settling_s': settling(lambda r: abs(r['body_deg']) < 3 and abs(r['torso_deg']) < 2),
              'tail_body_deg': trace[-1]['body_deg'], 'release_s': release,
              'step_us_median': statistics.median(r['animation_timing_us']['step'] for r in rows[30:]),
              'fit_us_median': statistics.median(r['animation_timing_us']['fit'] for r in rows[30:]),
              'trace': trace}
    return result


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--revision', required=True)
    parser.add_argument('--before')
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]/'artifacts/pose_review/revisions'
    folder = root/args.revision
    ensure_writable(folder)
    manifest = json.loads((folder/'capture/manifest.json').read_text())
    result = {'cases': {}, 'physical_equal': True, 'paired_frames': 0}
    fields = ['tick','input','physical_position','velocity','heading_rad','turn_rate_rad_s','physical_com','body_roll_rad','ski_edges_rad','ski_loads_n','skis']
    for spec in manifest['scenarios']:
        name = spec['name']
        rows = json.loads((folder/f'capture/{name}.json').read_text())['frames']
        result['cases'][name] = summarize(rows)
        if args.before:
            old = json.loads((root/args.before/f'capture/{name}.json').read_text())['frames']
            assert len(old) == len(rows)
            result['physical_equal'] &= all(a[k] == b[k] for a, b in zip(old, rows) for k in fields)
            result['paired_frames'] += len(rows)
        print(name, json.dumps({k: round(v, 3) if v is not None else None for k, v in result['cases'][name].items() if k != 'trace'}))
    write_json(folder/'carving.json', result)
    if args.before:
        print('paired physical frames:', result['paired_frames'], 'equal:', result['physical_equal'])
        assert result['physical_equal']


if __name__ == '__main__':
    main()

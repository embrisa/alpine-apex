"""Read final joints and world equipment, reporting silhouette metrics without grades."""
import argparse
import json
import math
from revision import load_capture, read_json, selected_rows, write_json


def add(a, b): return [x + y for x, y in zip(a, b)]
def sub(a, b): return [x - y for x, y in zip(a, b)]
def scale(a, s): return [x * s for x in a]
def dot(a, b): return sum(x * y for x, y in zip(a, b))
def cross(a, b): return [a[1]*b[2]-a[2]*b[1], a[2]*b[0]-a[0]*b[2], a[0]*b[1]-a[1]*b[0]]


def unit(a):
    length = math.sqrt(dot(a, a))
    if not math.isfinite(length) or length < 1e-8:
        raise ValueError('Degenerate or non-finite measurement axis')
    return scale(a, 1 / length)


def measure(row, pole_length=1.18):
    if not math.isfinite(pole_length) or pole_length <= 0:
        raise ValueError('Pole length must be positive and finite')
    joints, rotations, root = row['joints'], row['rotations'], row['root']
    axes = root['basis']  # Columns: dot with each column inverts a rigid basis.
    if any(abs(dot(a, b) - (1 if i == j else 0)) > 1e-4
           for i, a in enumerate(axes) for j, b in enumerate(axes)):
        raise ValueError('Metrics require a rigid root basis, without scale or shear')
    up = unit(add(rotations['LeftFoot'][1], rotations['RightFoot'][1]))
    forward = add(rotations['LeftFoot'][2], rotations['RightFoot'][2])
    forward = unit(sub(forward, scale(up, dot(forward, up))))
    lateral = unit(cross(up, forward))
    tips, flare = [], []
    if len(row['poles']) != 2:
        raise ValueError('This measurement profile requires two ski poles')
    for pole in row['poles']:
        grip = [dot(axis, sub(pole['origin'], root['origin'])) for axis in axes]
        shaft = unit([-dot(axis, pole['basis'][1]) for axis in axes])
        tips.append(dot(sub(add(grip, scale(shaft, pole_length)), joints['Hips']), lateral))
        flare.append(math.degrees(math.asin(min(1, abs(dot(shaft, lateral))))))
    chest_x = unit(rotations['Spine'][0])
    values = {
        'pole_tip_width_m': max(tips) - min(tips),
        'max_shaft_flare_degrees': max(flare),
        'elbow_span_m': abs(dot(sub(joints['LeftForeArm'], joints['RightForeArm']), chest_x)),
        'hand_span_m': abs(dot(sub(joints['LeftHand'], joints['RightHand']), chest_x)),
        'hand_forward_of_chest_m': max(dot(sub(joints[hand], joints['Spine']), forward)
                                       for hand in ('LeftHand', 'RightHand')),
    }
    if not all(math.isfinite(v) for v in values.values()):
        raise ValueError('Non-finite pose measurement')
    return values


def report(revision, pole_length=1.18):
    folder, manifest, captures = load_capture(revision)
    selection = read_json(folder / 'selection.json') if (folder / 'selection.json').exists() else {}
    result = {'version': 1, 'revision': str(folder), 'capture_fps': manifest.get('capture_fps'),
              'pole_length_m': pole_length, 'units': 'metres and degrees',
              'scope': 'Final silhouette measurements; smaller is not universally better. No collision or visual grade inferred.',
              'scenarios': {}}
    for name, data in captures.items():
        samples = [dict(frame=int(row['frame']), tick=int(row['tick']), grounded=row['grounded'],
                        **measure(row, pole_length)) for row in data['frames']]
        chosen = selected_rows(samples, selection[name]) if name in selection else []
        result['scenarios'][name] = {'frames': len(samples), 'selected': chosen, 'samples': samples}
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--revision', required=True)
    parser.add_argument('--pole-length', type=float, default=1.18, help='Current mesh length in metres; verify for other equipment')
    parser.add_argument('--output', help='New JSON file; omit to print, including for sealed revisions')
    args = parser.parse_args()
    data = report(args.revision, args.pole_length)
    if args.output:
        write_json(args.output, data)
        print(f'Measured {sum(s["frames"] for s in data["scenarios"].values())} frames: {args.output}')
    else:
        print(json.dumps(data, indent=2, allow_nan=False))


if __name__ == '__main__':
    main()

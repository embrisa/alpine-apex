"""Select reproducible phases and event neighbours; inspect the full sequence too."""
import argparse
import json
from revision import load_capture, write_json


def select(data):
    rows = data['frames']
    reasons = {}

    def add(index, reason):
        frame = int(rows[max(0, min(index, len(rows) - 1))]['frame'])
        reasons.setdefault(frame, []).append(reason)

    for fraction, reason in ((0, 'entry'), (.5, 'mid-sequence'), (1, 'end/release')):
        add(round((len(rows) - 1) * fraction), reason)
    for index in range(1, len(rows)):
        if rows[index]['grounded'] != rows[index - 1]['grounded']:
            event = 'contact' if rows[index]['grounded'] else 'support loss'
            for offset in (-1, 0, 1):
                add(index + offset, f'{event} {offset:+d}')
    for event in data.get('events', []):
        index = next((i for i, row in enumerate(rows) if row['tick'] >= event['tick']), len(rows) - 1)
        for offset in (-1, 0, 1):
            add(index + offset, f"{event['type']} {offset:+d}")
    supported = [(i, row) for i, row in enumerate(rows) if row['grounded']]
    if data.get('name') == 'prepare_takeoff':
        departure = next((i for i, row in enumerate(rows) if not row['grounded']), len(rows))
        supported = [(i, row) for i, row in supported if i < departure]
    if supported:
        # Candidate phase, not a judgement that maximum compression is best.
        index, _ = min(supported, key=lambda pair: pair[1]['joints']['Hips'][1]
                       - (pair[1]['joints']['LeftFoot'][1] + pair[1]['joints']['RightFoot'][1]) / 2)
        add(index, 'lowest supported pelvis (candidate compression)')
    for channel in ('tuck', 'prepare'):
        values = [row.get('state', {}).get(channel, 0) for row in rows]
        if max(values) > .01:
            add(values.index(max(values)), f'peak {channel} channel')
    if data.get('name', '').startswith('carve'):
        add(max(range(len(rows)), key=lambda i: abs(rows[i]['body_roll_rad'])), 'peak physical bank')
    return sorted(reasons), {str(k): reasons[k] for k in sorted(reasons)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--revision', required=True, help='Revision name or path; never overwrites an existing selection')
    args = parser.parse_args()
    folder, _, captures = load_capture(args.revision)
    selection, reasons = {}, {}
    for name, data in captures.items():
        selection[name], reasons[name] = select(dict(data, name=name))
    if (folder / 'selection-reasons.json').exists():
        raise ValueError('Selection reasons already exist; preserve the previous choice')
    write_json(folder / 'selection.json', selection)
    write_json(folder / 'selection-reasons.json', reasons)
    print(json.dumps(selection, indent=2))


if __name__ == '__main__':
    main()

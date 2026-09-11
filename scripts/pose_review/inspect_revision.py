"""Read-only provenance and coverage report; missing checks remain missing."""
import argparse
import json
from revision import load_capture, read_json, selected_rows, source_status, verify_seal


def inspect(revision):
    folder, manifest, captures = load_capture(revision)
    selection = read_json(folder / 'selection.json') if (folder / 'selection.json').exists() else {}
    for name, ids in selection.items():
        selected_rows(captures[name]['frames'], ids)
    result = {'revision': str(folder), 'sealed': (folder / 'sealed.json').exists(),
              'engine': manifest.get('engine'), 'physics': manifest.get('physics'),
              'mountain_version': manifest.get('mountain_version'),
              'sources': source_status(folder, manifest), 'scenarios': {}, 'checks': {},
              'visual_acceptance': 'Not inferred; read the independent review records and user feedback.'}
    for name, data in captures.items():
        rows = data['frames']
        result['scenarios'][name] = {'frames': len(rows), 'supported': sum(bool(r['grounded']) for r in rows),
                                     'selected': selection.get(name, []), 'events': data.get('events', [])}
    for filename in ('render.json', 'details.json', 'pole-mesh-audit.json', 'regression/results.json'):
        path = folder / filename
        result['checks'][filename] = read_json(path) if path.exists() else None
        if filename in ('render.json', 'details.json') and path.exists():
            meta = result['checks'][filename]
            subfolder = 'frames' if filename == 'render.json' else 'details'
            result['checks'][filename] = {
                key: value for key, value in meta.items() if key != 'scenarios'}
            result['checks'][filename]['listed_frames'] = {name: len(rows) for name, rows in meta['scenarios'].items()}
            result['checks'][filename]['missing_images'] = [f'{name}/{int(row["frame"]):04d}.jpg'
                for name, rows in meta['scenarios'].items() for row in rows
                if not (folder / subfolder / name / f'{int(row["frame"]):04d}.jpg').is_file()]
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--revision', required=True)
    parser.add_argument('--require-live', action='store_true', help='Fail if live sources differ; historical drift otherwise remains informational')
    parser.add_argument('--require-snapshot', action='store_true', help='Fail if any captured source is absent or changed in baseline/')
    parser.add_argument('--verify-seal', action='store_true', help='Verify every listed file hash in sealed.json; fail on missing/changed evidence')
    args = parser.parse_args()
    result = inspect(args.revision)
    if args.verify_seal:
        result['seal_integrity'] = verify_seal(result['revision'])
    print(json.dumps(result, indent=2, allow_nan=False))
    if (args.require_live and result['sources']['live_changed']) or (
            args.require_snapshot and result['sources']['snapshot_missing_or_changed']) or (
            args.verify_seal and not result['seal_integrity']['passed']):
        raise SystemExit(1)


if __name__ == '__main__':
    main()

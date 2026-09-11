"""Shared capture readers. Measurements are evidence, never visual grades."""
import hashlib
import json
import math
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def resolve_revision(value):
    value = str(value).removeprefix('res://')
    path = Path(value)
    if not path.is_absolute():
        path = (ROOT / 'artifacts/pose_review/revisions' / path
                if len(path.parts) == 1 else ROOT / path)
    return path.resolve()


def read_json(path):
    return json.loads(Path(path).read_text(encoding='utf-8-sig'))


def ensure_writable(path):
    path = Path(path).resolve()
    for parent in (path, *path.parents):
        if (parent / 'sealed.json').is_file():
            raise ValueError(f'Sealed evidence is read-only: {parent}')


def write_new(path, text):
    path = Path(path)
    ensure_writable(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open('x', encoding='utf-8', newline='\n') as stream:
        stream.write(text)


def write_json(path, data):
    write_new(path, json.dumps(data, indent=2, allow_nan=False) + '\n')


def load_capture(revision):
    revision = resolve_revision(revision)
    manifest = read_json(revision / 'capture/manifest.json')
    if not manifest.get('stable_sources') or manifest.get('failures'):
        raise ValueError('Capture failed or its source files changed during capture')
    if not manifest.get('sources'):
        raise ValueError('Capture has no source provenance')
    if manifest.get('sources_after', manifest['sources']) != manifest['sources']:
        raise ValueError('Capture source hashes disagree')
    captures = {}
    for item in manifest['scenarios']:
        name = item['name']
        if not re.fullmatch(r'[a-z0-9_]+', name) or name in captures:
            raise ValueError(f'Invalid or duplicate scenario: {name}')
        data = read_json(revision / 'capture' / f'{name}.json')
        rows = data['frames']
        if not rows or len(rows) != item['frames']:
            raise ValueError(f'{name}: missing or empty frame coverage')
        for field in ('frame', 'tick'):
            values = [row[field] for row in rows]
            if any(isinstance(v, bool) or not isinstance(v, (int, float))
                   or not math.isfinite(v) or int(v) != v for v in values):
                raise ValueError(f'{name}: {field} must contain finite integer IDs')
            if any(a >= b for a, b in zip(values, values[1:])):
                raise ValueError(f'{name}: {field} IDs must increase strictly')
        captures[name] = data
    if not captures:
        raise ValueError('Capture has no scenarios')
    return revision, manifest, captures


def selected_rows(rows, ids):
    # JSON numbers can be floats; do not rely on implicit engine membership casts.
    if not ids or any(isinstance(i, bool) or not isinstance(i, (int, float))
                      or not math.isfinite(i) or int(i) != i for i in ids):
        raise ValueError('Selection must contain finite integer frame IDs')
    ids = [int(i) for i in ids]
    lookup = {int(row['frame']): row for row in rows}
    if len(set(ids)) != len(ids) or any(i not in lookup for i in ids):
        raise ValueError('Selection contains duplicate or missing frame IDs')
    return [lookup[i] for i in sorted(ids)]


def source_status(revision, manifest):
    result = {'recorded_files': len(manifest['sources']), 'live_changed': [],
              'snapshot_missing_or_changed': []}
    for resource, digest in manifest['sources'].items():
        relative = Path(resource.removeprefix('res://'))
        if relative.is_absolute() or '..' in relative.parts:
            raise ValueError(f'Invalid source path: {resource}')
        for root, key in ((ROOT, 'live_changed'),
                          (Path(revision) / 'baseline', 'snapshot_missing_or_changed')):
            file = root / relative
            if not file.is_file() or hashlib.sha256(file.read_bytes()).hexdigest() != digest:
                result[key].append(resource)
    return result


def verify_seal(revision):
    revision = Path(revision).resolve()
    seal = read_json(revision / 'sealed.json')
    hashes = seal.get('sha256', {})
    if not hashes:
        raise ValueError('Seal has no file hashes to verify')
    changed = []
    for name, digest in hashes.items():
        path = (revision / name).resolve()
        if not path.is_relative_to(revision) or not re.fullmatch('[0-9a-f]{64}', digest):
            raise ValueError(f'Invalid sealed file record: {name}')
        if not path.is_file() or hashlib.sha256(path.read_bytes()).hexdigest() != digest:
            changed.append(name)
    return {'listed_files': len(hashes), 'missing_or_changed': changed, 'passed': not changed,
            'scope': 'Integrity of files listed in this seal; not visual acceptance.'}

"""Freeze one runtime for cosmetic on/off measurements; no Git or live edits."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parents[1]


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', required=True)
    args = parser.parse_args()
    assert os.environ.get('ALPINE_VALIDATION_MODE') == 'Exclusive'
    destination = (ROOT / args.output).resolve()
    destination.relative_to(ROOT / 'artifacts')
    assert not destination.exists(), 'Choose a fresh snapshot; preserve older evidence.'
    project = destination / 'project'
    files = []
    for folder in ['scripts', 'config', 'tests', 'scenes', 'addons', 'examples', 'assets']:
        files += [p for p in (ROOT / folder).rglob('*') if p.is_file() and '__pycache__' not in p.parts]
    files += [p for p in ROOT.iterdir() if p.is_file() and p.suffix in ('.godot', '.tscn', '.svg', '.import')]
    files += list((ROOT / '.godot').glob('*')) + list((ROOT / '.godot/imported').rglob('*'))
    hashes = {}
    for path in sorted(set(p for p in files if p.is_file())):
        relative = path.relative_to(ROOT).as_posix()
        target = project / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        if path.suffix.lower() in ('.res', '.glb', '.png', '.jpg', '.webp', '.ogg', '.wav', '.dll', '.ctex', '.scn'):
            os.link(path, target)
        else:
            shutil.copy2(path, target)
        hashes[relative] = digest(target)
    drift = [p for p, value in hashes.items()
             if not os.path.samefile(project / p, ROOT / p) and digest(ROOT / p) != value]
    # A concurrent edit cannot be presented as a single live source revision.
    # These are the actual copied bytes, shared by every feature mode.
    trace = 'artifacts/rock_gravel/standard_trace.json'
    (project / trace).parent.mkdir(parents=True)
    shutil.copy2(ROOT / trace, project / trace)
    (project / 'artifacts/.gdignore').touch()
    receipt = {'schema': 1, 'source_hashes': hashes, 'copied_source_drift': drift,
               'trace': trace, 'trace_sha256': digest(project / trace),
               'scope': 'One explicitly observed runtime copy for all/off/dense/sparse gravel. No source overrides; no physical regeneration. Private code/import registry and shader caches; immutable binary assets hard-linked and rehashed.'}
    (destination / 'snapshot.json').write_text(json.dumps(receipt, indent=2) + '\n')
    print(json.dumps({'output': str(destination), 'files': len(hashes), 'source_drift': drift}))


if __name__ == '__main__':
    main()

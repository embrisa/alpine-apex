"""Retain the exact live inputs of a stable capture; refuse changed sources."""
import argparse, hashlib, shutil
from datetime import datetime, timezone
from revision import ROOT, ensure_writable, load_capture, write_json

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--revision', required=True)
    args = parser.parse_args()
    revision, manifest, _ = load_capture(args.revision)
    ensure_writable(revision)
    destination = revision / 'baseline'
    if destination.exists() or (revision / 'tooling.json').exists() or (revision / 'tooling').exists():
        raise ValueError('A source/tool snapshot already exists; preserve it.')
    paths = [(ROOT / name.removeprefix('res://'), name.removeprefix('res://'), digest)
             for name, digest in manifest['sources'].items()]
    for source, _, digest in paths:
        if not source.resolve().is_relative_to(ROOT):
            raise ValueError(f'Source outside project: {source}')
        if hashlib.sha256(source.read_bytes()).hexdigest() != digest:
            raise ValueError(f'Changed since capture: {source}')
    for source, relative, digest in paths:
        target = destination / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, target)
        assert hashlib.sha256(target.read_bytes()).hexdigest() == digest
    # These tools are snapshotted NOW, separately from capture-time provenance.
    # Their presence does not imply a render, mesh audit or review has run.
    tools = [p for p in (ROOT / 'scripts/pose_review').iterdir() if p.is_file()]
    tools += [ROOT / path for path in (
        'tests/pose_reference_capture.gd', 'tests/pose_reference_render.gd', 'tests/pose_pole_mesh_audit.gd',
        'scripts/validate_downhill_posture.ps1', 'scripts/run_guarded.ps1',
        'scripts/guarded_child.ps1', 'scripts/guarded_job.cs', 'godotw.ps1')]
    hashes = {}
    for source in tools:
        relative = source.relative_to(ROOT)
        target = revision / 'tooling' / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, target)
        hashes[relative.as_posix()] = hashlib.sha256(target.read_bytes()).hexdigest()
    write_json(revision / 'tooling.json', {
        'created_utc': datetime.now(timezone.utc).isoformat(), 'sources': hashes,
        'scope': 'Review tools at snapshot time, not evidence that their checks ran. Pin the engine separately.'})
    print(f'Frozen and verified {len(paths)} source files: {destination}')

if __name__ == '__main__':
    main()

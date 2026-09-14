"""Freeze an exact forest A/B without editing the shared checkout or Git state."""
import argparse
import hashlib
import json
import os
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OVERRIDES = [
    'assets/graphics/pc_forest_tree.gdshader', 'assets/graphics/pc_tree_impostor.gdshader',
    'assets/graphics/trees/manifest.json', 'assets/graphics/trees/branches.json',
    'scripts/presentation/alpine_assets.gd', 'scripts/presentation/forest_placement.gd',
    'scripts/presentation/tree_motion.gd', 'scripts/world/alpine_scenery.gd',
    'scripts/world/alpine_world.gd',
]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--output', required=True)
    ap.add_argument('--baseline', required=True)
    ap.add_argument('--trace', required=True)
    ap.add_argument('--resume-candidate', action='store_true', help='Freeze an already completed candidate copy after reported live-source drift; no original files are recopied.')
    args = ap.parse_args()
    assert os.environ.get('ALPINE_VALIDATION_MODE') == 'Exclusive', 'Use the original checkout Exclusive guard.'
    destination = (ROOT / args.output).resolve()
    destination.relative_to(ROOT / 'artifacts')
    assert not destination.exists() or args.resume_candidate, 'Choose a fresh evidence directory.'
    revision = subprocess.check_output(['git', 'rev-parse', args.baseline], cwd=ROOT, text=True).strip()
    trace = (ROOT / args.trace).resolve(); trace.relative_to(ROOT)
    files = []
    for folder in ['scripts', 'config', 'tests', 'scenes', 'addons', 'examples', 'assets']:
        files += [p for p in (ROOT / folder).rglob('*') if p.is_file() and '__pycache__' not in p.parts and not p.name.startswith('~')]
    files += [p for p in ROOT.iterdir() if p.is_file() and p.suffix in ('.godot', '.tscn', '.svg', '.import')]
    files += list((ROOT / '.godot').glob('*'))
    files += list((ROOT / '.godot/imported').rglob('*'))
    files = sorted(set(p for p in files if p.is_file()))
    candidate = destination / 'candidate'
    if args.resume_candidate:
        assert candidate.is_dir() and not (destination / 'baseline').exists() and not (destination / 'snapshot.json').exists()
        # Preserve the observed copy itself, not an invented live-source point.
        # Both arms use these exact inputs. Their full hashes remain checked.
        before = {p.relative_to(candidate).as_posix(): sha(p) for p in candidate.rglob('*') if p.is_file()}
        live_drift = [p for p,h in before.items() if not (ROOT/p).is_file() or sha(ROOT/p)!=h]
        assert not set(live_drift).intersection(OVERRIDES), 'Forest candidate changed; create a new snapshot instead.'
    else:
        before = {p.relative_to(ROOT).as_posix(): sha(p) for p in files}
        destination.mkdir(parents=True)
        for path in files:
            relative = path.relative_to(ROOT)
            target = candidate / relative; target.parent.mkdir(parents=True, exist_ok=True)
            # Only immutable binary artwork is linked; source and registries
            # are private copies. Shader caches are never shared.
            if path.suffix.lower() in ('.res', '.glb', '.png', '.jpg', '.webp', '.ogg', '.wav', '.dll', '.ctex', '.scn'):
                os.link(path, target)
            else:
                shutil.copy2(path, target)
        live_drift = [p.relative_to(ROOT).as_posix() for p in files if sha(p)!=before[p.relative_to(ROOT).as_posix()]]
        assert not live_drift, f'Source changed while freezing: {live_drift}. Retain the copy; inspect before an explicit resume.'
    target_trace = candidate / args.trace; target_trace.parent.mkdir(parents=True, exist_ok=True); shutil.copy2(trace, target_trace)
    (candidate / 'artifacts/.gdignore').touch()
    baseline = destination / 'baseline'
    # Copy code/metadata independently; share only the same immutable binaries.
    for path in candidate.rglob('*'):
        if not path.is_file(): continue
        target = baseline / path.relative_to(candidate); target.parent.mkdir(parents=True, exist_ok=True)
        if path.suffix.lower() in ('.res', '.glb', '.png', '.jpg', '.webp', '.ogg', '.wav', '.dll', '.ctex', '.scn'):
            os.link(path, target)
        else: shutil.copy2(path, target)
    overrides = {}
    for relative in OVERRIDES:
        data = subprocess.check_output(['git', 'show', f'{revision}:{relative}'], cwd=ROOT)
        (baseline / relative).write_bytes(data)
        overrides[relative] = hashlib.sha256(data).hexdigest()
    # Helper is snapshot-owned and can only restore an already valid physical
    # fixture. Preparation occurs under Exclusive, outside timing.
    warm = '''extends SceneTree
func _initialize(): call_deferred("run")
func run():
 if OS.get_environment("ALPINE_VALIDATION_MODE")!="Exclusive": quit(2); return
 var field=preload("res://tests/validation_mountain.gd").load_standard()
 if field==null: quit(2); return
 var quality=preload("res://scripts/presentation/graphics_quality.gd").numbered(7)
 var prepared=preload("res://scripts/world/mountain_preparation.gd").new()
 if not prepared.load_cached(field,quality,field.job):
  var assets=preload("res://scripts/presentation/alpine_assets.gd").new(preload("res://scripts/presentation/cloud_lighting.gd").new(),quality)
  var metadata=await preload("res://scripts/presentation/forest_placement.gd").metadata_async(assets,Callable(),field.job)
  prepared.build(field,metadata,quality,field.job)
 print("FROZEN_FOREST_CACHE ",prepared.ready," hit=",prepared.cache_hit," families=",prepared.forest.family_counts)
 quit(0 if prepared.ready else 1)
'''
    for project in [baseline, candidate]:
        (project / 'artifacts/warm_forest.gd').write_text(warm, encoding='utf-8')
    receipt = {'baseline_revision': revision, 'candidate_source_sha256': before,
               'resumed_observed_copy': args.resume_candidate, 'differences_from_live_checkout': live_drift,
               'baseline_overrides': overrides, 'trace': args.trace, 'trace_sha256': sha(trace),
               'scope': 'Same frozen runtime inputs except nine enumerated forest source/catalog files. Original checkout untouched; no physical generation.'}
    (destination / 'snapshot.json').write_text(json.dumps(receipt, indent=2)+'\n')
    print(json.dumps({'output': str(destination), 'files': len(files), 'overrides': len(overrides)}))


if __name__ == '__main__':
    main()

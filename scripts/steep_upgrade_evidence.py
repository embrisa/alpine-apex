"""Freeze current skier sources and run suites without overwriting historical evidence."""
from pathlib import Path
import argparse, hashlib, json, os, re, subprocess, time

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'artifacts/steep_animation_physics_upgrade'
SUITES = 'physics runtime downhill_control downhill_contact handling handling_upgrade high_speed_turns high_speed_balance jump airborne_control airborne_pose ski_attachment turn_anatomy impact_recovery rock_terrain competitive rider_lifecycle skier_motion skier_animation skier_refinement steep_upgrade race ragdoll'.split()

def engine():
    return os.environ.get('GODOT_BIN') or str(next(Path(os.environ['LOCALAPPDATA']).glob('Microsoft/WinGet/Packages/GodotEngine.GodotEngine_*/Godot*_console.exe')))

def freeze():
    target = OUT / 'reference'
    if target.exists():
        raise SystemExit('Reference already exists; refusing to replace baseline.')
    files = list((ROOT/'scripts/core').glob('*.gd'))
    files += [ROOT/p for p in ['scripts/main.gd', 'scripts/presentation/skier_visual.gd', 'scripts/presentation/skier_animation.gd', 'scripts/presentation/skier_animation_tuning.gd', 'scripts/presentation/skier_ragdoll.gd', 'config/ski_default.tres', 'main.tscn']]
    # Input keeps the live contract: old physics ignores later optional fields.
    files = [p for p in files if p.name not in ('rider_input.gd','input_router.gd','run_session.gd')]
    mapping = {p.relative_to(ROOT).as_posix(): 'artifacts/steep_animation_physics_upgrade/reference/'+p.name for p in files}
    manifest = {}
    target.mkdir(parents=True)
    for p in files:
        original = p.read_text(encoding='utf-8-sig')
        manifest[p.relative_to(ROOT).as_posix()] = hashlib.sha256(p.read_bytes()).hexdigest()
        raw = OUT/'baseline_sources'/p.relative_to(ROOT)
        raw.parent.mkdir(parents=True,exist_ok=True); raw.write_bytes(p.read_bytes())
        text = original
        for source,dest in mapping.items():
            text = text.replace('res://'+source,'res://'+dest)
        text = re.sub(r'^class_name (SkiSimulation|SkiTuning)\n','',text,flags=re.M)
        text = text.replace('SkiTuning.new()', 'load("res://'+mapping['scripts/core/ski_tuning.gd']+'").new()')
        text = re.sub(r'\bSkiTuning\b','Resource',text)
        text = re.sub(r'\bSkiSimulation\b','RefCounted',text)
        (target/p.name).write_text(text,encoding='utf-8')
    manifest.update(engine=subprocess.check_output([engine(),'--version'],text=True).strip())
    (OUT/'baseline_manifest.json').write_text(json.dumps(manifest,indent=2))

def suites(label, selected):
    output = OUT/label; output.mkdir(parents=True,exist_ok=True)
    (output/'suite_artifacts').mkdir(exist_ok=True)
    copied = output/'suites'; copied.mkdir(exist_ok=True)
    results = []
    for name in selected or SUITES:
        suite = name if name.endswith('_suite') else name+'_suite'
        source = ROOT/'tests'/f'{suite}.gd'
        if not source.exists():
            print('MISSING',suite,flush=True); continue
        text = source.read_text(encoding='utf-8-sig')
        # Only artifact destinations change; production code and fixtures remain live.
        text = text.replace('res://artifacts/',f'res://artifacts/steep_animation_physics_upgrade/{label}/suite_artifacts/')
        for destination in re.findall(r'"(res://artifacts/[^"\n]+)"',text):
            directory = ROOT/destination.removeprefix('res://')
            if directory.suffix: directory = directory.parent
            directory.mkdir(parents=True,exist_ok=True)
        script = copied/source.name; script.write_text(text,encoding='utf-8')
        started = time.time()
        print('START',suite,flush=True)
        run = subprocess.run([engine(),'--path',str(ROOT),'--headless','--script',str(script)],cwd=ROOT,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
        (output/f'{suite}.log').write_text(run.stdout,encoding='utf-8')
        problems = [s for s in run.stdout.splitlines() if re.match(r'^(FAIL:|SCRIPT ERROR:|ERROR:)',s)]
        row = dict(suite=suite,exit_code=run.returncode,seconds=time.time()-started,problems=problems)
        results.append(row); (output/'suites.json').write_text(json.dumps(results,indent=2))
        print('END',suite,run.returncode,'problems',len(problems),flush=True)
    return any(r['exit_code'] or r['problems'] for r in results)

if __name__ == '__main__':
    parser=argparse.ArgumentParser(); parser.add_argument('--freeze',action='store_true'); parser.add_argument('--label',default='after'); parser.add_argument('suites',nargs='*')
    args=parser.parse_args(); OUT.mkdir(parents=True,exist_ok=True)
    if args.freeze: freeze()
    else: raise SystemExit(suites(args.label,args.suites))

"""Record the R7 handoff and seal completed evidence; never overwrite a revision."""
import hashlib
import json
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / 'scripts/pose_review'))
from inspect_revision import inspect
from revision import verify_seal

SOURCE = Path(__file__).resolve().parent
COMPARISON = ROOT / 'artifacts/pose_review/comparisons/cascadeur-20260910-r7'
REVISIONS = {v: ROOT / 'artifacts/pose_review/revisions' / f'cascadeur-20260910-r7-{v}'
             for v in ('source', 'production', 'gameplay')}


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def write(path, value):
    with path.open('x', encoding='utf-8') as stream:
        json.dump(value, stream, indent=2, allow_nan=False)
        stream.write('\n')


def sha(path):
    return hashlib.file_digest(path.open('rb'), 'sha256').hexdigest()


def main():
    for path in (*REVISIONS.values(), COMPARISON):
        assert not (path / 'sealed.json').exists(), path
    now = datetime.now(timezone.utc).isoformat()
    inspected = {v: inspect(path) for v, path in REVISIONS.items()}
    for v, report in inspected.items():
        assert not report['sources']['live_changed'], v
        assert not report['sources']['snapshot_missing_or_changed'], v
        assert not report['checks']['render.json']['partial'], v
        for kind in ('render.json', 'details.json'):
            assert not report['checks'][kind]['missing_images'], (v, kind)
    before = read(REVISIONS['production'] / 'pole-mesh-audit.json')
    after = read(REVISIONS['gameplay'] / 'pole-mesh-audit.json')
    hit_keys = lambda audit: {(x['scenario'], int(x['frame']), tuple(sorted({h['side'] for h in x['hits']})))
                              for x in audit['intersections']}
    assert hit_keys(before) == hit_keys(after) == {('tuck_turn',44,(0,1)),('tuck_turn',45,(0,1))}
    clothing = {'before_passed': before['passed'], 'after_passed': after['passed'],
                'frames_per_variant': before['frames'],
                'shared_failure_frames': [44,45], 'shared_failure_scenario': 'tuck_turn',
                'affected_sides': [0,1], 'new_intersecting_frames': [],
                'note': 'Hit positions differ slightly. Both full clothing audits fail; the existing transition issue remains unresolved.'}
    write(COMPARISON / 'clothing_comparison.json', clothing)
    guards = {}
    for folder in sorted((ROOT / 'artifacts/guarded').glob('cascadeur-r7-*')):
        if not (folder / 'guard.json').is_file():
            continue
        data = read(folder / 'guard.json')
        guards[folder.name] = {k: data.get(k) for k in
                              ('file','arguments','concurrent','started','finished','exit_code','stop_reason')}
        guards[folder.name]['files_sha256'] = {p.name: sha(p) for p in folder.iterdir() if p.is_file()}
    focused = None
    suites = []
    for line in (ROOT / 'artifacts/guarded/cascadeur-r7-tests/stdout.log').read_text(encoding='utf-8-sig').splitlines():
        if '_RESULTS ' in line:
            label, body = line.split(' ',1)
            result = json.loads(body)
            if label == 'CASCADEUR_CARVING_MOTION_RESULTS':
                focused = result
            else:
                assert not result['failures']
                suites.append({'label':label, 'checks':result['checks'], 'failures':result['failures']})
        if line.startswith('COMPACT_POSTURE '):
            assert line == 'COMPACT_POSTURE 36 checks, 0 failures'
            suites.append({'label':'COMPACT_POSTURE','checks':36,'failures':[]})
    assert focused['passed'] and sum(s['checks'] for s in suites) == 236
    ready = read(ROOT / 'artifacts/cascadeur_r7_live_playtest/ready.json')
    assert all(ready[k] for k in ('ready','manual_input','unranked','F9_and_restart_checked'))
    execution = {'created_utc':now, 'scope':'Functional and rendered evidence; no FPS or human/controller acceptance claim.',
                 'guards':guards, 'focused_motion':focused, 'suites':suites,
                 'live_playtest_startup':ready,
                 'failed_run_disposition':{
                     'cascadeur-r7-capture':'Missing R6-only diagnostic helper; fixed before successful capture02 and source freeze.',
                     'cascadeur-r7-finish':'Source audit passed; baseline clothing audit failed on tuck_turn 44/45; batch stopped before media.',
                     'cascadeur-r7-candidate-audit':'Same two intersecting frames and sides as baseline. Retained as a known shared failure.',
                     'cascadeur-r7-media':'Separate Videos/Chase completion, exit 0; does not turn clothing audits into passes.'}}
    write(COMPARISON / 'execution_summary.json', execution)
    shutil.copyfile(ROOT / 'artifacts/cascadeur_r7_live_playtest/ready.png', COMPARISON / 'playtest_ready.png')
    shutil.copyfile(ROOT / 'docs/CASCADEUR_CARVING_R7.md', COMPARISON / 'handoff.md')
    assessment = {'created_utc':now, 'reviewer':'Codex author inspection',
                  'status':'Optional carving variant ready for user comparison',
                  'user_request':'can we do carving and maybe make it sligthly different and see if we like that more than our current?',
                  'observed_difference':'Higher, broader hand carry and a modest upper-body adjustment in loaded turns; no straight-travel difference.',
                  'tradeoff':'At strong banks the arms look more extended and can read as stiff. No preference or improvement grade is claimed.',
                  'inspection':{
                      'front_chronology':'All 61 source frames and all 726 frames per gameplay variant inspected in ordered contact sheets.',
                      'matched_details':['source 15','steering_right 75','steering_left 75','tuck_turn 45','gameplay chase carve_reversal 36'],
                      'additional_candidate_triptychs':['carve_reversal 54','carve_taps 67','tuck_turn 68','steering_right 108'],
                      'continuous_playback':'Normal and half-speed playback supplied. Continuous playback judgement and controller feel remain open.',
                      'occlusions':'Some strong-bank hands and pole tips leave front/overhead crops. Do not use those crops to claim complete shaft clearance.'},
                  'clothing':clothing, 'independent_review':None, 'user_acceptance':None, 'visual_grade':None,
                  'normal_default_changed':False,
                  'next_action':'Use F9 during linked turns in the normal mountain playtest and compare the more open arm carry.'}
    write(COMPARISON / 'assessment.json', assessment)
    for v, path in REVISIONS.items():
        write(path / 'provenance_check.json', inspected[v])
        write(path / 'author_assessment.json', dict(assessment, evidence_variant=v))
    files = [p for p in SOURCE.rglob('*') if p.is_file() and p.suffix not in ('.pyc','.uid') and '__pycache__' not in p.parts]
    files += [p for p in (ROOT / 'tests/cascadeur_r7_playtest').iterdir() if p.suffix in ('.gd','.tscn')]
    files += [ROOT / p for p in ('Play Cascadeur Carving.ps1','Play Cascadeur Carving.cmd','docs/CASCADEUR_CARVING_R7.md','scripts/presentation/skier_full_motion.gd')]
    manifest = {'created_utc':now, 'scope':'Handoff source hashes, not an adoption or quality certificate.',
                'sha256':{p.relative_to(ROOT).as_posix():sha(p) for p in sorted(files)}}
    write(SOURCE / 'handoff_manifest.json', manifest)
    write(COMPARISON / 'handoff_manifest.json', manifest)
    for path in (*REVISIONS.values(), COMPARISON):
        seal = {'scope':'Frozen evidence integrity, not visual or user acceptance.',
                'status':'R7_user_acceptance_pending_known_shared_clothing_failure',
                'sha256':{p.relative_to(path).as_posix():sha(p) for p in sorted(path.rglob('*')) if p.is_file()}}
        write(path / 'sealed.json', seal)
        result = verify_seal(path)
        assert result['passed'], (path,result)
        print(path.name, json.dumps(result))


if __name__ == '__main__':
    main()

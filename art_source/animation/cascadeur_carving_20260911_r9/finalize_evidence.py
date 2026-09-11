"""Record R9 evidence boundaries and seal completed comparisons without rewriting R8."""
import hashlib
import json
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
SOURCE = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT / 'scripts/pose_review'))
from inspect_revision import inspect
from revision import verify_seal

COMPARISON = ROOT / 'artifacts/pose_review/comparisons/cascadeur-20260911-r9'
REVISIONS = {v: ROOT / 'artifacts/pose_review/revisions' / f'cascadeur-20260911-r9-02-{v}' for v in ('before', 'after')}

def read(p):
    return json.loads(p.read_text(encoding='utf-8-sig'))

def write(p, value):
    with p.open('x', encoding='utf-8') as f:
        json.dump(value, f, indent=2, allow_nan=False)
        f.write('\n')

def sha(p):
    with p.open('rb') as f:
        return hashlib.file_digest(f, 'sha256').hexdigest()

def world(transform, point):
    return [transform['origin'][i] + sum(transform['basis'][j][i] * point[j] for j in range(3)) for i in range(3)]

def boot_sample(row):
    positions = [world(s, [0, .017, -.15]) for s in row['skis']]
    return {'frame': row['frame'], 'boot_origins_world_m': positions,
            'world_y_gap_m': abs(positions[0][1] - positions[1][1]),
            'pressure_depths_m': [s['pressure_sink_m'] for s in row['snow_contacts']]}

def suite_results():
    results = {}
    log = ROOT / 'artifacts/guarded/cascadeur-r9-final-checks/stdout.log'
    for line in log.read_text(encoding='utf-8-sig').splitlines():
        for marker in ('R8_CONTACT_RESULTS', 'PHYSICS_RESULTS', 'RUNTIME_RESULTS'):
            if line.startswith(marker + ' '):
                data = json.loads(line[len(marker) + 1:])
                assert not data['failures']
                results[data.get('experiment', marker)] = data
    expected = {'cascadeur-r8-pressure-snow-v1': 28, 'cascadeur-r9-deep-pressure-v1': 28, 'PHYSICS_RESULTS': 56, 'RUNTIME_RESULTS': 170}
    assert {k: v['checks'] for k, v in results.items()} == expected
    return results

def seal(p, status):
    write(p / 'sealed.json', {'scope': 'Evidence integrity only; not visual or user acceptance.', 'status': status,
                            'sha256': {f.relative_to(p).as_posix(): sha(f) for f in sorted(p.rglob('*')) if f.is_file()}})
    result = verify_seal(p)
    assert result['passed'], p
    print(p.name, json.dumps(result), flush=True)

def main():
    for p in (*REVISIONS.values(), COMPARISON):
        assert not (p / 'sealed.json').exists(), p
    now = datetime.now(timezone.utc).isoformat()
    reports = {v: inspect(p) for v, p in REVISIONS.items()}
    manifests = {v: read(p / 'capture/manifest.json') for v, p in REVISIONS.items()}
    for v, report in reports.items():
        assert report['sources']['recorded_files'] == 105
        assert not report['sources']['snapshot_missing_or_changed']
        assert manifests[v]['base_model'] == 28 and manifests[v]['stable_sources']
        assert not manifests[v]['failures']
        for name in ('render.json', 'details.json'):
            check = report['checks'][name]
            assert not check['partial'] and not check['missing_images']
            assert len(check['listed_frames']) == 6 and set(check['listed_frames'].values()) == {121}
        assert all(s['frames'] == s['supported'] == 121 for s in report['scenarios'].values())
        for name in ('snow_support.gd', 'simulation.gd', 'live_motion.gd'):
            assert not any(p.endswith('/' + name) for p in report['sources']['live_changed'])
    assert manifests['before']['engine_sha256'] == manifests['after']['engine_sha256']
    audits = {v: read(p / 'pole-mesh-audit.json') for v, p in REVISIONS.items()}
    keys = lambda audit: {(hit['scenario'], int(hit['frame']), side) for hit in audit['intersections'] for side in {h['side'] for h in hit['hits']}}
    for a in audits.values():
        assert a['frames'] == 726 and not a['selected_only']
    before_keys, after_keys = keys(audits['before']), keys(audits['after'])
    clothing = {'passed': all(a['passed'] for a in audits.values()), 'frames_per_variant': 726,
                'shared_scenario_frame_side': sorted(before_keys & after_keys),
                'new_scenario_frame_side': sorted(after_keys - before_keys),
                'removed_scenario_frame_side': sorted(before_keys - after_keys),
                'intersections': {v: a['intersections'] for v, a in audits.items()},
                'note': 'Actual skinned mesh and 6 mm shaft-radius audit. Failure is retained, not converted to a passing grade.'}
    coords = {'base_model': 28, 'scenario': 'steering_right', 'attachment_local_m': [0, .017, -.15],
              'definition': 'Absolute difference of boot mesh origins in world Y; includes terrain and ski position/orientation.',
              'strong_turn_frames': [54, 75], 'variants': {}}
    for v, p in REVISIONS.items():
        rows = read(p / 'capture/steering_right.json')['frames']
        samples = [boot_sample(row) for row in rows]
        coords['variants'][v] = {'profile': manifests[v]['physics'], 'frame54': samples[54], 'frame62': samples[62],
                                'strong_turn_max': max(samples[54:76], key=lambda s: s['world_y_gap_m']),
                                'sequence_max': max(samples, key=lambda s: s['world_y_gap_m'])}
    assert .169 < coords['variants']['after']['strong_turn_max']['world_y_gap_m'] < .170
    geometry = read(SOURCE / 'gameplay_analysis.json')
    assert len(geometry['scenarios']) == 6 and all(s['passed'] and s['frames'] == 121 for s in geometry['scenarios'].values())
    ready = read(ROOT / 'artifacts/cascadeur_r9_live_playtest/ready.json')
    assert ready['base_model'] == 28 and ready['experiment'] == 'cascadeur-r9-deep-pressure-v1'
    assert all(ready[k] for k in ('ready', 'manual_input', 'unranked', 'pressure_enabled', 'R7_hands_enabled', 'F9_and_restart_checked', 'laboratory'))
    guards = {}
    for p in sorted((ROOT / 'artifacts/guarded').glob('cascadeur-r9-*')):
        if not (p / 'guard.json').is_file():
            continue
        guard = read(p / 'guard.json')
        guards[p.name] = {k: guard.get(k) for k in ('file', 'arguments', 'concurrent', 'started', 'finished', 'exit_code', 'stop_reason')}
        guards[p.name]['files_sha256'] = {f.name: sha(f) for f in p.iterdir() if f.is_file()}
    assert guards['cascadeur-r9-final-checks']['exit_code'] == 0
    assert guards['cascadeur-r9-clothing03']['finished'] and not guards['cascadeur-r9-clothing03']['stop_reason']
    execution = {'created_utc': now, 'base_model': 28, 'guards': guards, 'suites': suite_results(), 'laboratory_startup': ready,
                 'scope': 'Functional tests and frozen rendered comparison. No performance or controller acceptance claim.',
                 'live_source_drift': {v: r['sources']['live_changed'] for v, r in reports.items()},
                 'drift_disposition': 'Concurrent steering-clip direction changes in skier_full_motion.gd are preserved. Movies restore frozen final bones; no claim that every live presentation frame still matches.',
                 'attempt_dispositions': {'revision01': 'Superseded 0.17 m sink cap yielded about 16.3 cm in the strong turn; revision02 uses 0.177 m.',
                                         'initial_analysis_output_collision': 'Existing attempt01 analysis was preserved, then revision02 analysis was generated separately.',
                                         'cascadeur-r9-clothing02': '120-second timeout before full coverage; replaced by complete 600-second-budget clothing03, retaining the failed guard.',
                                         'cascadeur-r9-clothing03': 'Completed both variants; nonzero exit preserves actual clothing intersections.'}}
    assessment = {'created_utc': now, 'reviewer': 'Codex author inspection', 'status': 'Optional deeper-support trial; clothing failures and user preference remain open.',
                  'user_feedback': 'i think we could do even 17 cm at deepest point',
                  'prior_authorization': 'Include soft-snow sinking and leg motion',
                  'observed_difference': 'Greater ski-height separation is visible in matched frame62 side/oblique views. Knees and boots remain connected in the inspected views.',
                  'remaining_limits': 'Extreme banks still read as a long inclined stance. Detail/leg crops omit some limbs and pole tips; full views and clothing audit are separate.',
                  'inspection': {'front_chronology': 'All 726 frames per variant inspected on chronological front sheets.',
                                 'matched_full_views': ['steering_right 62', 'tuck_turn 45', 'steering_left 63', 'carve_reversal 27'],
                                 'matched_detail_views': ['steering_right 62: oblique, overhead, side', 'steering_left 63: oblique, overhead, side', 'carve_reversal 27: oblique, overhead, side'],
                                 'startup': 'Rendered laboratory ready.png inspected.',
                                 'not_performed': ['continuous normal/half-speed quality grading', 'independent review', 'controller acceptance', 'R9 full-mountain descent']},
                  'chains': {'pelvis_thighs_knees': 'Independent response visible; preference unrated.',
                             'ankles_boots_bindings': 'Connected in matched views; full attachment/cuff checks pass. Visual score unrated.',
                             'spine_head_shoulders_arms': 'R7 hand source retained; physical balance differs. Visual score unrated.',
                             'wrists_grips_poles': 'Fixed grip checks pass; clothing audit fails. See exact newly affected frames.'},
                  'clothing': clothing, 'visual_grade': None, 'independent_review': None, 'user_acceptance': None,
                  'production_pressure_support_enabled': False, 'new_cascadeur_clip': False}
    for name, value in [('coordinate_summary.json', coords), ('clothing_comparison.json', clothing), ('execution_summary.json', execution), ('assessment.json', assessment)]:
        write(COMPARISON / name, value)
    shutil.copyfile(SOURCE / 'gameplay_analysis.json', COMPARISON / 'gameplay_analysis.json')
    shutil.copyfile(ROOT / 'docs/CASCADEUR_DEEP_CARVING_R9.md', COMPARISON / 'handoff.md')
    shutil.copyfile(ROOT / 'artifacts/cascadeur_r9_live_playtest/ready.png', COMPARISON / 'laboratory_ready.png')
    for v, p in REVISIONS.items():
        write(p / 'provenance_check.json', reports[v])
        write(p / 'author_assessment.json', dict(assessment, evidence_variant=v))
    files = [p for p in SOURCE.rglob('*') if p.is_file() and p.suffix not in ('.pyc', '.uid') and '__pycache__' not in p.parts]
    for folder in ('tests/cascadeur_r8_playtest', 'tests/cascadeur_r9_playtest'):
        files += [p for p in (ROOT / folder).iterdir() if p.suffix in ('.gd', '.tscn', '.ps1')]
    files += [ROOT / p for p in ('scripts/launchers/Play Cascadeur Deep Carving.ps1', 'scripts/launchers/Play Cascadeur Deep Carving.cmd', 'scripts/main.gd', 'docs/CASCADEUR_DEEP_CARVING_R9.md')]
    manifest = {'created_utc': now, 'scope': 'Live handoff sources; each movie has its own frozen snapshot.',
                'sha256': {p.relative_to(ROOT).as_posix(): sha(p) for p in sorted(files)}}
    write(SOURCE / 'handoff_manifest.json', manifest)
    write(COMPARISON / 'handoff_manifest.json', manifest)
    for p in (*REVISIONS.values(), COMPARISON):
        seal(p, 'R9_optional_trial_user_acceptance_pending_clothing_failure')

if __name__ == '__main__':
    main()

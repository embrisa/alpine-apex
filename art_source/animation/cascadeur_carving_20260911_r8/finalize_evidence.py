"""Seal R8-01 movies and separate live compatibility receipts without rewriting history."""
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

COMPARISON = ROOT / 'artifacts/pose_review/comparisons/cascadeur-20260911-r8'
REVISIONS = {v: ROOT / 'artifacts/pose_review/revisions' / f'cascadeur-20260911-r8-01-{v}' for v in ('before','after')}

def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))

def write(path, value):
    with path.open('x', encoding='utf-8') as stream:
        json.dump(value, stream, indent=2, allow_nan=False)
        stream.write('\n')

def sha(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()

def world(transform, point):
    return [transform['origin'][i] + sum(transform['basis'][j][i]*point[j] for j in range(3)) for i in range(3)]

def suite_results(label):
    results = {}
    for line in (ROOT / 'artifacts/guarded' / label / 'stdout.log').read_text(encoding='utf-8-sig').splitlines():
        for marker in ('R8_CONTACT_RESULTS','PHYSICS_RESULTS','RUNTIME_RESULTS'):
            if line.startswith(marker+' '):
                result = json.loads(line[len(marker)+1:])
                assert not result['failures'], (label,marker)
                results[marker] = result
    assert [results[k]['checks'] for k in ('R8_CONTACT_RESULTS','PHYSICS_RESULTS','RUNTIME_RESULTS')] == [28,56,170]
    return results

def main():
    for folder in (*REVISIONS.values(),COMPARISON):
        assert not (folder/'sealed.json').exists(), folder
    now = datetime.now(timezone.utc).isoformat()
    inspected = {v:inspect(p) for v,p in REVISIONS.items()}
    for variant, report in inspected.items():
        assert report['sources']['recorded_files']==99
        assert not report['sources']['snapshot_missing_or_changed'], variant
        assert not report['checks']['render.json']['partial']
        assert not report['checks']['render.json']['missing_images']
        assert set(report['checks']['render.json']['listed_frames'].values())=={121}
        for critical in ('snow_support.gd','simulation.gd','live_motion.gd'):
            assert not any(p.endswith('/'+critical) for p in report['sources']['live_changed']), critical
    audits = {v:read(p/'pole-mesh-audit.json') for v,p in REVISIONS.items()}
    keys = lambda a:{(x['scenario'],int(x['frame']),tuple(sorted({h['side'] for h in x['hits']}))) for x in a['intersections']}
    assert keys(audits['before']) == keys(audits['after']) == {('tuck_turn',44,(0,1)),('tuck_turn',45,(0,1))}
    clothing = {'passed':False,'frames_per_variant':726,'new_intersecting_frames':[],
                'shared_scenario':'tuck_turn','shared_frames':[44,45],'affected_sides':[0,1],
                'hits_per_frame':{v:[len(x['hits']) for x in a['intersections']] for v,a in audits.items()},
                'note':'Both complete clothing audits fail. The existing transition defect is retained; hit positions are not identical.'}
    coordinates = {'base_model':27,'scenario':'steering_right','frame':54,'time_s':1.8,
                   'attachment_local_m':[0,.017,-.15], 'definition':'Recorded rendered ski transform times Equipment.BOOT_ORIGIN; absolute world-Y separation.', 'variants':{}}
    for v,p in REVISIONS.items():
        row=read(p/'capture/steering_right.json')['frames'][54]
        positions=[world(s,coordinates['attachment_local_m']) for s in row['skis']]
        coordinates['variants'][v]={'boot_origins_world_m':positions,'world_y_gap_m':abs(positions[0][1]-positions[1][1]),'pressure_depths_m':[s['pressure_sink_m'] for s in row['snow_contacts']]}
    probe=read(ROOT/'artifacts/cascadeur_r8_current_coordinates/probe.json')
    assert probe['base_model']==28 and probe['stable_sources']
    assert probe['variants']['before']['row']['physics_experiment']=='production-model-28'
    assert .12 < probe['variants']['after']['world_y_gap_m'] < .14
    ready=read(ROOT/'artifacts/cascadeur_r8_model27_receipt/ready.json')
    assert ready['base_model']==27 and all(ready[k] for k in ('ready','manual_input','unranked','pressure_enabled','R7_hands_enabled','F9_and_restart_checked'))
    guards={}
    for folder in sorted((ROOT/'artifacts/guarded').glob('cascadeur-r8-*')):
        if not (folder/'guard.json').is_file():continue
        data=read(folder/'guard.json')
        guards[folder.name]={k:data.get(k) for k in ('file','arguments','concurrent','started','finished','exit_code','stop_reason')}
        guards[folder.name]['files_sha256']={p.name:sha(p) for p in folder.iterdir() if p.is_file()}
    execution={'created_utc':now,'scope':'Functional tests, frozen model-27 renders, and a separate current model-28 coordinate probe. No FPS/controller acceptance claim.',
               'guards':guards,'model27_suites':suite_results('cascadeur-r8-physics-runtime'),
               'current_model28_suites':suite_results('cascadeur-r8-current-compatibility01'),
               'model27_playtest_startup':ready,
               'current_coordinate_probe':'current_model28_coordinates.json',
               'live_source_drift':inspected['after']['sources']['live_changed'],
               'drift_disposition':'Concurrent model-28 snow handling and air-input edits are preserved. Capture metadata now derives the model label dynamically. Original snapshots and movies remain model 27.',
               'failed_run_disposition':{'cascadeur-r8-contact01':'Harness constant Plane conflicted with a builtin type; renamed before successful validation and source freeze.',
                                         'cascadeur-r8-clothing01':'Both full audits failed on the same two tuck frames. Preserved as a known shared defect.'},
               'coordinate_attempt01_disposition':'Correct coordinate values, but an inherited row label still said model 27. Attempt02 repeats with dynamic labels; source implementation unchanged.'}
    assessment={'created_utc':now,'reviewer':'Codex author inspection','status':'Optional trial ready for user comparison; known shared clothing failure',
                'user_feedback':'The hands are okay but the is no feeling in the legs, there should be some height difference between the feet while carving because carving is the act of pushing one foot down hard into the snow while the other follows along at the top of the snow.',
                'authorization':'Include soft-snow sinking and leg motion',
                'observed_difference':'Independent boot heights and knee bend during loading. R7 hand source retained. Contact changes also alter bank recovery.',
                'remaining_visual_limits':'At extreme banks both legs can still read as one inclined stance. Strong-bank front crops omit some pole tips. Existing tuck-transition poles cross clothing.',
                'inspection':{'front_chronology':'All 726 frames per variant inspected on chronological front sheets.',
                              'triptychs':['both steering_right 54','both tuck_turn 45','after steering_left 54','after carve_reversal 108'],
                              'not_performed':['overhead detail review','continuous normal/half-speed motion grading','independent review','controller feel acceptance']},
                'chains':{'pelvis_thighs_knees':'Visible independent response to support; preference unrated.',
                          'ankles_boots_bindings':'Connected in inspected views and full mechanical attachment checks; visual score unrated.',
                          'spine_head_shoulders_arms':'R7 source retained; balance differs with the physical turn. Visual score unrated.',
                          'wrists_grips_poles':'Fixed grips pass. Clothing fails at the recorded shared frames; full silhouette partly cropped.'},
                'clothing':clothing,'visual_grade':None,'independent_review':None,'user_acceptance':None,
                'production_pressure_support_enabled':False,'new_cascadeur_clip':False,
                'next_action':'Compare F9 during linked turns on sufficiently deep snow; assess leg readability and bank recovery.'}
    for name,data in [('clothing_comparison.json',clothing),('coordinate_example.json',coordinates),('current_model28_coordinates.json',probe),('execution_summary.json',execution),('assessment.json',assessment)]:write(COMPARISON/name,data)
    shutil.copyfile(SOURCE/'gameplay_analysis.json',COMPARISON/'gameplay_analysis.json')
    shutil.copyfile(ROOT/'docs/CASCADEUR_SNOW_LEGS_R8.md',COMPARISON/'handoff.md')
    shutil.copyfile(ROOT/'artifacts/cascadeur_r8_model27_receipt/ready.png',COMPARISON/'model27_playtest_ready.png')
    for v,p in REVISIONS.items():
        write(p/'provenance_check.json',inspected[v])
        write(p/'author_assessment.json',dict(assessment,evidence_variant=v))
    files=[p for p in SOURCE.rglob('*') if p.is_file() and p.suffix not in ('.pyc','.uid') and '__pycache__' not in p.parts]
    files += [p for p in (ROOT/'tests/cascadeur_r8_playtest').iterdir() if p.suffix in ('.gd','.tscn','.ps1')]
    files += [ROOT/p for p in ('scripts/launchers/Play Cascadeur Snow Carving.ps1','scripts/launchers/Play Cascadeur Snow Carving.cmd','scripts/main.gd','docs/CASCADEUR_SNOW_LEGS_R8.md')]
    manifest={'created_utc':now,'scope':'Live R8 handoff sources. Movie snapshots separately retain the prior model-27 source.',
              'sha256':{p.relative_to(ROOT).as_posix():sha(p) for p in sorted(files)}}
    write(SOURCE/'handoff_manifest.json',manifest);write(COMPARISON/'handoff_manifest.json',manifest)
    for p in (*REVISIONS.values(),COMPARISON):
        write(p/'sealed.json',{'scope':'Frozen evidence integrity, not visual or user acceptance.',
                              'status':'R8_user_acceptance_pending_known_shared_clothing_failure',
                              'sha256':{f.relative_to(p).as_posix():sha(f) for f in sorted(p.rglob('*')) if f.is_file()}})
        result=verify_seal(p);assert result['passed'];print(p.name,json.dumps(result),flush=True)

if __name__=='__main__':main()

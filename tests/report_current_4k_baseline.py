"""Verify a guarded three-descent baseline and publish its compact tracked receipt.

Run from the repository root after scripts/benchmark_pc.ps1 completes.
The input trace and detailed samples stay in ignored artifacts.
"""
import argparse
import copy
import hashlib
import json
import math
import re
import statistics
import subprocess
from collections import defaultdict
from datetime import datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def digest(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def require(condition, message):
    if not condition:
        raise ValueError(message)


def stats(values):
    ordered = sorted(values)
    require(bool(ordered), 'Missing frame samples')
    require(all(math.isfinite(x) and x >= 0 for x in ordered), 'Invalid timing samples')
    return {'count': len(ordered), 'mean': statistics.mean(ordered),
            'p95': ordered[min(len(ordered)-1, int(len(ordered)*.95))],
            'p99': ordered[min(len(ordered)-1, int(len(ordered)*.99))],
            'max': ordered[-1]}


def verify_stats(actual, expected):
    for key, value in stats(actual).items():
        require(math.isclose(value, expected[key], rel_tol=1e-8, abs_tol=1e-8),
                f'Raw timing disagrees with report: {key}')


def medians(values):
    first = values[0]
    if isinstance(first, dict):
        return {key: medians([row[key] for row in values]) for key in first
                if all(key in row for row in values)
                and isinstance(first[key], (dict, int, float)) and not isinstance(first[key], bool)}
    return statistics.median(values)


def memory_and_background(samples):
    require(bool(samples), 'No process telemetry during measured interval')
    apps = defaultdict(list)
    observed_totals = []
    other_gpu = {}
    for sample in samples:
        for allocation in sample['other_gpu_allocations']:
            key = allocation['Name']
            previous = other_gpu.setdefault(key, {'counter':key,'peak_dedicated_bytes':0,'peak_shared_bytes':0})
            previous['peak_dedicated_bytes'] = max(previous['peak_dedicated_bytes'],allocation['DedicatedUsage'])
            previous['peak_shared_bytes'] = max(previous['peak_shared_bytes'],allocation['SharedUsage'])
        grouped = defaultdict(float)
        for app in sample['background_processes']:
            grouped[app['name']] += app['cpu_machine_percent']
        for name, value in grouped.items():
            apps[name].append(value)
        observed_totals.append(sum(grouped.values()))
    gpu = [s['gpu_memory'] for s in samples if s['gpu_memory']]
    return {'sample_count': len(samples),
            'peak_working_set_bytes': max(s['working_set_bytes'] for s in samples),
            'peak_private_bytes': max(s['private_bytes'] for s in samples),
            'minimum_system_free_bytes': min(s['system_free_bytes'] for s in samples),
            'peak_gpu_dedicated_allocated_bytes': max((s['dedicated_bytes'] for s in gpu), default=None),
            'peak_gpu_shared_allocated_bytes': max((s['shared_bytes'] for s in gpu), default=None),
            'other_godot_observations': sum(bool(s['other_godot_processes']) for s in samples),
            'wow_observations': sum(s['wow_running'] for s in samples),
            'other_gpu_allocations':sorted(other_gpu.values(),key=lambda x:x['peak_dedicated_bytes'],reverse=True),
            'observed_background_cpu_machine_percent': stats(observed_totals),
            'background_apps': sorted([{'name': name, 'observed_mean_cpu_machine_percent': sum(values)/len(samples),
                                      'peak_cpu_machine_percent': max(values)} for name, values in apps.items()],
                                     key=lambda app: app['observed_mean_cpu_machine_percent'], reverse=True)[:12]}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--label', default='player-v15-4k-focused-20260912')
    parser.add_argument('--guard', default='player-v15-4k-focused')
    parser.add_argument('--evidence', default='artifacts/player_v15_4k_baseline')
    parser.add_argument('--trace', default='artifacts/player_recordings/player-20260911-221639/attempt_008.json')
    parser.add_argument('--output', default='docs/V15_PERFORMANCE_BASELINE_RESULTS.json')
    args = parser.parse_args()
    folder = ROOT / 'artifacts/pc_environment' / args.label
    guard_folder = ROOT / 'artifacts/guarded' / args.guard
    evidence = ROOT / args.evidence
    production = read(folder / 'production.json')
    system = read(folder / 'system.json')
    guard = read(guard_folder / 'guard.json')
    trace_path = ROOT / args.trace
    trace = read(trace_path)
    require(guard['exit_code'] == 0 and not guard['stop_reason'] and not guard['concurrent'] and guard['workload_launched'], 'Guard failed or wrong scope')
    require('scripts/benchmark_pc.ps1' in guard['arguments'], 'Wrong guarded workload')
    require(system['exit_code'] == 0 and not system['changed_sources'], 'Failed benchmark or source drift')
    require(system['source_sha256_before'] == system['source_sha256_after'], 'Source snapshots differ')
    for source, expected in system['source_sha256_before'].items():
        require(digest(ROOT / source).lower() == expected.lower(), f'Source drift since measurement: {source}')
    require(digest(Path(system['engine_path'])).lower() == system['engine_sha256'].lower(), 'Runtime changed')
    runtime = read(evidence/'runtime_observed.json')
    require(digest(Path(runtime['worker_path'])).lower() == runtime['worker_sha256'].lower() == trace['engine_sha256'].lower(), 'Engine worker differs from recorded runtime')
    logs = (folder/'stdout.log').read_text(encoding='utf-8') + (folder/'stderr.log').read_text(encoding='utf-8')
    require(not re.search(r'^(ERROR:|SCRIPT ERROR:|FAIL )', logs, re.M), 'Engine/test errors')
    require(not production['failures'] and len(production['rows']) == 3, 'Need three successful trials')
    require(production['identity'] == trace['identity'] and production['trace_sha256'] == digest(trace_path), 'Trace identity mismatch')
    require(trace['identity']['model'] == 28 and trace['identity']['generator'] == 15 and trace['seed'] == 849205174, 'Wrong current baseline identity')
    require(production['scope'] == 'complete_production_descent' and production['warmup_frames'] == 240, 'Wrong workload/warmup')
    require(trace['origin'] == 'player' and trace['scope'] == 'complete_descent' and not trace['recording_error'] and not trace['configuration_changed'], 'Invalid player recording')
    require(set(trace['mountain']['settings'].values()) == {1.0}, 'Not Standard mountain settings')
    require(trace['result']['finished'] and not trace['result']['crash'], 'Unsuccessful trace')
    require(production['actual_pixels'] == [3840,2160] and production['graphics_preset'] == 7, 'Wrong pixels/preset')
    prefs = production['display']['preferences']
    require(prefs['upscaler'] == 'auto' and prefs['render_scale'] == .75 and not prefs['frame_generation'], 'Wrong upscaling/FG settings')
    require(production['renderer'] == 'forward_plus' and production['rendering_driver'] == 'd3d12', 'Wrong renderer/backend')
    require(production['display']['internal_pixels_from_viewport_scale'] == [2880,1620], 'Wrong internal pixels')
    require(production['display']['fidelityfx']['active_upscaler_version'] == '4.1.1', 'Auto did not resolve FSR 4.1.1')
    require(production['engine'] == trace['engine'], 'Different engine build from recording')
    require(production['weather'] == 'clear' and production['camera'] == trace['presentation']['camera'], 'Wrong weather or recorded camera settings')
    require(not prefs['custom'] and not prefs['overrides'], 'Custom graphics overrides enabled')
    require(production['display']['fps_limit'] == 120 and not production['sdfgi'], 'Wrong frame cap/GI')
    require(production['unranked'] and not production['capture_overhead_included'], 'Wrong record/capture isolation')
    before, after = read(evidence/'preferences_before.json'), read(evidence/'preferences_after.json')
    require(bool(before) and before == after, 'Personal settings or records changed')
    rows = copy.deepcopy(production['rows'])
    for index, row in enumerate(rows, 1):
        require(row['wall_seconds'] > 0 and row['ended_unix_seconds'] > row['started_unix_seconds'], 'Invalid measured interval')
        require(row['run'] == index and row['finished'] and not row['crash'] and row['exact_trace'] and row['ticks'] == trace['result']['ticks'], 'Incomplete or inexact trial')
        require(row['unfocused_frames'] == 0, 'Window focus changed during measured workload')
        require(bool(row['cpu_scopes_us']), 'Missing CPU scope timings')
        require(not row['fsr_begin']['frame_generation_active'] and not row['fsr_end']['frame_generation_active'], 'FG active')
        raw = read(folder/f'frame_samples_{index}.json')
        for raw_key, report_key in [('frame_ms','frame_ms'), ('gpu_ms','gpu_ms'), ('render_cpu_ms','render_cpu_ms'), ('draw_calls','draw_calls')]:
            verify_stats(raw[raw_key], row[report_key])
            require(len(raw[raw_key]) == len(raw['frame_ms']), 'Timing sample counts disagree')
        ordered = sorted(raw['frame_ms'])
        derived = {'average_fps':1000/statistics.mean(ordered), 'p50':statistics.median(ordered),
                   'median_fps':1000/statistics.median(ordered),
                   'slowest_one_percent_fps':1000/statistics.mean(ordered[-max(1,math.ceil(len(ordered)*.01)):])}
        for key, value in derived.items():
            require(math.isclose(value,row['frame_ms'][key],rel_tol=1e-8), f'Incorrect FPS statistic: {key}')
        require(set(raw['sections']) == {'open','powder','minerals','forest'}, 'Incomplete route bands')
        require(sum(len(v) for v in raw['sections'].values()) == len(raw['frame_ms']), 'Incomplete section coverage')
        for section, frames in raw['sections'].items():
            verify_stats(frames, row['sections'][section])
        require(row['forest_coverage']['forest']['frames_with_resident_regions'] > 0, 'No forest residency in lower route')
        selected = [s for s in system['samples'] if row['started_unix_seconds'] <= datetime.fromisoformat(s['utc']).timestamp() <= row['ended_unix_seconds']]
        row['system'] = memory_and_background(selected)
        require(row['system']['other_godot_observations'] == 0, 'Concurrent engine workload')
        row['targets'] = {'p95_ms':11.1,'p99_ms':16.7,'p95_pass':row['frame_ms']['p95'] <= 11.1,'p99_pass':row['frame_ms']['p99'] <= 16.7}
    require(all(rows[i]['ended_unix_seconds'] < rows[i+1]['started_unix_seconds'] for i in range(2)), 'Trials overlapped')
    receipt = {key: value for key, value in production.items() if key != 'rows'}
    receipt.update({'status':'complete', 'task':'AA-20260911-153903-current-4k-performance-baseline',
                    'recording':{'path':trace_path.relative_to(ROOT).as_posix(),'origin':trace['origin'],'recorded_utc':trace['recorded_utc'],
                                 'seconds':trace['result']['seconds'],'ticks':trace['result']['ticks'],'face':trace['face'],
                                 'checkpoints':len(trace['checkpoints']),'camera_samples':len(trace['camera_samples']),
                                 'recording_engine_sha256':trace['engine_sha256'],
                                 'camera_first_person_ticks':sum(bool(c[0]) for c in trace['camera_samples']),
                                 'camera_chase_ticks':sum(not c[0] for c in trace['camera_samples'])},
                    'route_provenance':read(evidence/'route_provenance.json'),
                    'benchmark_started_utc':system['started_utc'], 'benchmark_ended_utc':system['ended_utc'],
                    'rows':rows, 'medians_of_run_statistics':medians([{k:r[k] for k in
                        ['wall_seconds','frame_ms','gpu_ms','render_cpu_ms','draw_calls','cpu_scopes_us','sections',
                         'peak_video_bytes','peak_engine_static_bytes','forest','forest_coverage','system']} for r in rows]),
                    'all_runs_meet_tail_targets':all(r['targets']['p95_pass'] and r['targets']['p99_pass'] for r in rows),
                    'environment':system['environment'], 'cpu':system['cpu'], 'installed_ram_bytes':system['installed_ram_bytes'],
                    'engine_worker':runtime, 'engine_path':system['engine_path'], 'engine_sha256':system['engine_sha256'],
                    'source_sha256':system['source_sha256_before'], 'changed_sources':system['changed_sources'],
                    'preferences_and_records':{'unchanged':True,'checked_files':len(before)},
                    'before_first_trial_system':memory_and_background([s for s in system['samples'] if datetime.fromisoformat(s['utc']).timestamp() < rows[0]['started_unix_seconds']]),
                    'background_policy':system['background_policy'],
                    'limits':['One ordinary-input route on default Standard seed; not all faces, weather, or cameras.',
                              'Radial section names are route bands, not universal biome classifications; resident regions are not visible-tree counts.',
                              'Trial 1 is the first traversal; trials 2 and 3 reuse loaded scene/resources with separate 240-frame warmups.',
                              'Pre-trial telemetry includes process/scene setup and the first warmup; it is not isolated cache-loading memory.',
                              'Cold generation was not measured. original_bake_ms is cached metadata, not this startup.',
                              'CPU scopes overlap and must not be summed. Engine render CPU timing is not total main-thread frame cost.',
                              'Windows GPU allocations and engine-reported memory are different measures, not exact physical VRAM occupancy.',
                              'Background CPU is sampled every two seconds from the top 20 observed active/large processes; GPU utilization is not sampled.',
                              'Capture-free engine frame intervals exclude generated frames; monitor delivery, latency and human/controller smoothness remain unverified.']})
    evidence_paths = [folder/'production.json',folder/'system.json',folder/'stdout.log',folder/'stderr.log',guard_folder/'guard.json',
                      trace_path,evidence/'preferences_before.json',evidence/'preferences_after.json',evidence/'runtime_observed.json',evidence/'route_provenance.json']
    evidence_paths += [folder/f'frame_samples_{i}.json' for i in range(1,4)]
    receipt['evidence'] = {'files_sha256':{p.relative_to(ROOT).as_posix():digest(p) for p in evidence_paths},
                           'benchmark_arguments':guard['arguments'], 'guard_limits':guard['limits'],
                           'guard_exit_code':guard['exit_code'], 'guard_wait_seconds':guard['wait_seconds'],
                           'guard_wall_seconds':(datetime.fromisoformat(guard['finished'])-datetime.fromisoformat(guard['started'])).total_seconds(),
                           'guard_background_driver_app_errors':guard['background_driver_app_errors'],
                           'receipt_command':subprocess.list2cmdline(['python','tests/report_current_4k_baseline.py','--label',args.label,'--guard',args.guard,'--trace',args.trace,'--evidence',args.evidence,'--output',args.output]),
                           'receipt_producer_sha256':digest(Path(__file__)),
                           'checkout_head_at_receipt':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip()}
    output = ROOT / args.output
    output.write_text(json.dumps(receipt,indent=2,sort_keys=True)+'\n',encoding='utf-8',newline='\n')
    print(json.dumps({'output':str(output),'runs':3,'frame_ms_medians':receipt['medians_of_run_statistics']['frame_ms'],
                      'all_runs_meet_tail_targets':receipt['all_runs_meet_tail_targets']},indent=2))


if __name__ == '__main__':
    main()

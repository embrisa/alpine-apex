"""Write a bounded evidence report, including interrupted and pending checks."""
from datetime import datetime, timezone
import hashlib
import json
from geology_evidence import ROOT, INPUTS, read, digest, catalog_rows, identity_matches, render_sources_match, guard_failure

OUT = ROOT / 'artifacts/geology_v11'
generation = read('artifacts/geology_v11/generation_tests.json')
audit = read('artifacts/geology_v11/proxy_audit.json')
default = next(r for r in generation['seeds'] if r['seed'] == 849205174)
source_rows = {r['asset']: r for r in audit['assets']}
physical = []
pieces = 0
for row in catalog_rows():
    hull_sha = hashlib.sha256(json.dumps(row['hulls'], separators=(',', ':')).encode()).hexdigest()
    assert source_rows[row['id']]['proxy_sha256'] == hull_sha, 'Stale source audit: ' + row['id']
    pieces += len(row['hulls'])
    physical.append([row['id'], row['collision_sha256']])
assert len(physical) == len(source_rows) == 120
fingerprint = hashlib.sha256(json.dumps(physical, separators=(',', ':')).encode()).hexdigest()
jolt = read('artifacts/geology_v11/jolt.json')
assert jolt['pieces'] == pieces and jolt['catalog_sha256'] == fingerprint, 'Stale Jolt validation'
assert not guard_failure('geology_jolt_suite', 'artifacts/geology_v11/jolt.json')

lines = ['# Geology v11 validation status', '',
    'Generated ' + datetime.now(timezone.utc).isoformat(timespec='seconds') + '.', '',
    '**Acceptance is incomplete.** Automated, rendered, hardware and user skiing evidence are separate.',
    'Seed 849205174 / v11. The 4 m terrain remains authoritative for skiing; exposed mineral placements are solid obstacles.', '',
    '## Automated checks', '', '| Suite | Checks | Status |', '|---|---:|---|']
statuses = {}
for name, path, guard_label in [
    ('Assets', 'artifacts/geology_v11/assets.json', 'geology_asset_suite'),
    ('Continuous collision and camera', 'artifacts/geology_v11/collision_tests.json', 'geology_collision_suite'),
    ('Geology integration and Jolt', 'artifacts/geology_v11/integration_contracts.json', 'geology_contract_suite'),
    ('Mountain reference/cache', 'artifacts/geology_v11/contracts.json', 'massif_contract_suite'),
    ('Physics', 'artifacts/physics_results.json', 'physics_suite'),
    ('Runtime', 'artifacts/runtime_results.json', 'runtime_suite'),
    ('Race', 'artifacts/race_results.json', 'race_suite'),
    ('Flavor', 'artifacts/flavor_integration/data_results.json', 'flavor_integration_suite'),
    ('Mountain library', 'artifacts/summit_mountain/library_results.json', 'mountain_library_suite'),
    ('Interface lifecycle', 'artifacts/ui_refresh/interface_headless.json', 'interface_suite'),
    ('Staged scenery equivalence', 'artifacts/geology_v11/scenery_loading.json', 'scenery_loading_suite'),
    ('Tree grounding', 'artifacts/trees_v2/grounding/contracts.json', 'tree_grounding_suite'),
    ('Archived v10', 'artifacts/massif_v10/generator_results.json', None),
]:
    result = read(path, optional=True)
    reason = guard_failure(guard_label, path) if guard_label else ''
    if result is None:
        reason = reason or 'No completed report'
    elif result['failures']:
        reason = f"{len(result['failures'])} failed checks"
    elif 'height_sha256' in result and not identity_matches(result, default):
        reason = 'Stale mountain identity'
    if result and 'collision_catalog_sha256' in result and result['collision_catalog_sha256'] != fingerprint:
        reason = 'Stale collision catalog'
    status = 'Pending: ' + reason if reason else ('Pass (earlier archived baseline)' if guard_label is None else 'Pass')
    statuses[name] = status
    count = result.get('checks', 'See JSON') if result and not reason else '—'
    lines.append(f'| {name} | {count} | {status} |')
generation_reason = guard_failure('geology_generation_suite', 'artifacts/geology_v11/generation_tests.json')
if {row['seed'] for row in generation['seeds']} != {849205174, 0, 1, 42, 12981, 2147483647}:
    generation_reason = 'The complete six-seed report is not available'
if generation['failures']:
    generation_reason = f"{len(generation['failures'])} failed generation checks"
statuses['Six-seed generation'] = 'Pending: ' + generation_reason if generation_reason else 'Pass'
lines += ['', ('Generation pending: ' + generation_reason + '.') if generation_reason else
    'Generation: 0 failures across six requested seeds, including independent cache bake and warm reconstruction.',
    f'Actual Jolt backend: {len(physical)} assets / {pieces:,} convex pieces, with a clean runner engine log.', '',
    '| Seed | Placements | Unique assets | Maximum foundation raise (m) | Cold generation (s) |',
    '|---:|---:|---:|---:|---:|']
for row in generation['seeds']:
    stats = row['statistics']
    lines.append(f"| {row['seed']} | {stats['placements']} | {stats['unique_assets']} | {stats['max_stamp_m']:.3f} | {row['generation_ms']/1000:.2f} |")
lines += ['', f"Default categories: {json.dumps(default['statistics']['categories'])}.",
    f"Default faces 0–5: {default['statistics']['faces']}.",
    f"Source audit: {sum(r['rider_sized_free_samples'] for r in audit['assets']):,} full-rider-box clearance samples; {len(audit['failures'])} assets fail.",
    'This samples empty space at authored scale; it does not prove every possible route, rotation or surface detail.', '',
    'Catalog SHA-256: ' + fingerprint + '.',
    'Default height SHA-256: ' + default['height_sha256'] + '.',
    'Default obstacle SHA-256: ' + default['obstacle_sha256'] + '.', '']
descents = read('artifacts/geology_v11/descents.json', optional=True)
descent_reason = guard_failure('geology_descent_suite', 'artifacts/geology_v11/descents.json')
if not identity_matches(descents, default) or descents.get('collision_catalog_sha256') != fingerprint:
    descent_reason = 'Missing or stale mountain/collision identity'
elif descents['failures']:
    descent_reason = f"{len(descents['failures'])} failed routes"
statuses['Six-face automated descent'] = 'Pending: ' + descent_reason if descent_reason else 'Pass'
if descent_reason:
    lines += ['Automated descents pending: ' + descent_reason + '.', '']
else:
    lines += [f"Survey pilot v{descents['pilot_version']} supplies ordinary rider input using actual rock coverage and obstacles. Rock wear remains enabled.", '',
        '| Automated face | Finished | Crash | Simulated seconds | Peak km/h |', '|---:|---|---|---:|---:|']
    for row in descents['results']:
        lines.append(f"| {row['face']} | {row['finished']} | {row['crash'] or 'None'} | {row['seconds']:.2f} | {row['peak_kmh']:.1f} |")

lines += ['', '## Rendered inspection', '']
views_path = 'artifacts/pc_environment/geology_v11_release_views/views.json'
views = read(views_path, optional=True)
view_reason = guard_failure('geology_release_views', views_path)
if not identity_matches(views, default):
    view_reason = 'Existing captures predate the current mountain/collision identity.'
elif not render_sources_match(views):
    view_reason = 'Rendering sources changed or capture provenance is missing.'
elif views.get('view_face', -1) >= 0:
    view_reason = 'Only one face was captured; all-face inspection remains incomplete.'
if view_reason:
    lines += ['**Pending.** ' + view_reason,
        'Historical captures remain in artifacts/pc_environment/geology_v11_release_views/; they are not final acceptance evidence.']
else:
    lines += [f"{len(views['captures'])} current native captures at {views['display'].get('output_pixels', 'see manifest')} pixels.",
        '[Capture manifest](../pc_environment/geology_v11_release_views/views.json). Capture completion is separate from visual inspection.']
review = read('artifacts/geology_v11/visual_review.json', optional=True)
review_reason = view_reason
if not review_reason:
    if not identity_matches(review, default) or not render_sources_match(review):
        review_reason = 'Image review is missing or predates the current sources.'
    elif review.get('capture_manifest_sha256') != digest(ROOT / views_path):
        review_reason = 'Captures changed after image review.'
    elif review.get('review_notes_sha256') != digest(OUT / 'VISUAL_REVIEW.md'):
        review_reason = 'Review notes changed after their manifest was recorded.'
    else:
        for path, expected in review.get('images', {}).items():
            if not (ROOT / path).is_file() or digest(ROOT / path) != expected:
                review_reason = 'An inspected image changed: ' + path
                break
            INPUTS[path] = expected
        if not review.get('images'):
            review_reason = 'No inspected images recorded.'
if not review_reason:
    INPUTS['artifacts/geology_v11/VISUAL_REVIEW.md'] = review['review_notes_sha256']
    lines += ['', f"{len(review['images'])} native images inspected by Codex across all six faces, both weather states, huge crags, ice joins and three quality/distance samples.",
        '[Visual findings and limitations](VISUAL_REVIEW.md): seated formations and retained silhouettes in sampled views; patchy terrain snow, repeated source forms and close-up texture softness remain visible.',
        'Static image review does not establish temporal LOD quality or human skiing acceptance.']
else:
    lines += ['', 'Recorded visual review pending: ' + review_reason]
seating_path = 'artifacts/geology_v11/seating.json'
seating = read(seating_path, optional=True)
if identity_matches(seating, default) and not guard_failure('geology_seating', seating_path):
    lines += ['', f"Local seating fixture: {seating['asset']}, {seating['placements']} nearby placements, {len(seating['captures'])} captures at {seating['output_pixels']} pixels and {seating['fps_cap']} FPS cap.",
        '[Local capture manifest](seating.json). This bounded area is separate from the full-world inspection.']
face_captures = []
for face in range(6):
    path = f'artifacts/pc_environment/geology_v11_face_{face}/views.json'
    captured = read(path, optional=True)
    if captured is not None:
        reason = guard_failure(f'geology_face_{face}', path)
        if not identity_matches(captured, default) or not render_sources_match(captured) or captured.get('view_face') != face:
            reason = 'Stale or wrong face'
        face_captures.append((face, len(captured['captures']), reason))
if face_captures:
    lines += ['', '| Separate face capture | Images | Status |', '|---:|---:|---|']
    for face, count, reason in face_captures:
        lines.append(f"| {face} | {count} | {reason or 'Current capture; inspection separate'} |")
lines += ['', '## Hardware performance', '',
    'Requested: full descents at 3840×2160 output, High, 75% FSR2, 120 FPS cap and SDFGI off. Target: 90–120 FPS.', '',
    '| Weather | Status |', '|---|---|']
benchmarks = []
performance_statuses = {}
for weather in ('clear', 'snowfall'):
    label = 'geology_v11_high_' + weather
    path = f'artifacts/pc_environment/{label}/native_-1_{weather}.json'
    result = read(path, optional=True)
    system = read(f'artifacts/pc_environment/{label}/system.json', optional=True)
    reason = 'Not measured' if result is None or system is None else guard_failure(label, path)
    if not reason and not identity_matches(result, default):
        reason = 'Stale mountain identity'
    if not reason and (system['exit_code'] != 0 or system['changed_sources']):
        reason = 'Run failed or sources changed during measurement'
    if not reason and (result['actual_pixels'] != [3840, 2160] or not result['finished'] or result['scope'] != 'full_descent'):
        reason = 'Incomplete descent or wrong output resolution'
    if not reason:
        settings = result['display']['preferences']
        target = {'quality': 2, 'upscaler': 'fsr2', 'render_scale': .75, 'terrain_gi': False}
        if any(settings.get(key) != value for key, value in target.items()) or result['display']['fps_limit'] != 120:
            reason = 'Graphics settings do not match the requested target'
    lines.append(f"| {weather} | {reason or 'Completed; measurements below'} |")
    performance_statuses[weather] = reason or 'Completed'
    if not reason:
        benchmarks.append((weather, result, system))

def number(value):
    return 'Unavailable' if value is None else f'{value:.2f}'

if benchmarks:
    lines += ['', '| Weather | FPS mean | p95 / p99 (ms) | Slowest 1% FPS | CPU / GPU mean (ms) | Draw calls mean / p99 |', '|---|---:|---:|---:|---:|---:|']
    for weather, result, system in benchmarks:
        frame = result['frame_ms']
        lines.append(f"| {weather} | {frame['average_fps']:.2f} | {frame['p95']:.2f} / {frame['p99']:.2f} | {frame['slowest_one_percent_fps']:.2f} | {number(result['render_cpu_ms'].get('mean'))} / {number(result['render_gpu_ms'].get('mean'))} | {result['draw_calls']['mean']:.0f} / {result['draw_calls']['p99']:.0f} |")
    lines += ['', '| Weather | Peak resident / private / VRAM (GiB) | Field load / world build (s) | Max frame (ms) |', '|---|---:|---:|---:|']
    for weather, result, system in benchmarks:
        gpu_samples = [s['gpu_memory']['dedicated_bytes'] for s in system['samples'] if s.get('gpu_memory')]
        ram = max(s['working_set_bytes'] for s in system['samples']) / 2**30
        private = max(s['private_bytes'] for s in system['samples']) / 2**30
        gpu = max(gpu_samples) / 2**30 if gpu_samples else None
        lines.append(f"| {weather} | {ram:.2f} / {private:.2f} / {number(gpu)} | {result['generation_ms']/1000:.2f} / {result['world_build_ms']/1000:.2f} | {result.get('max_frame_ms', 0):.2f} |")
    lines += ['', 'CPU/GPU timings are Godot render timings. Windows process memory peaks use two-second samples including loading; they are not total system usage. Resident memory is the working set; private bytes include nonresident committed allocations.',
        'Pilot search CPU time is recorded separately but remains included in measured frame times. Existing applications remain part of the measured environment.']
    lines += ['', '| Weather | Render CPU / GPU p95 (ms) | Ski step / pilot p95 (ms) | Target assessment |', '|---|---:|---:|---|']
    for weather, result, system in benchmarks:
        meets = result['frame_ms']['average_fps'] >= 90 and result['frame_ms']['p95'] <= 11.1 and result['frame_ms']['p99'] <= 16.7
        performance_statuses[weather] = 'Pass' if meets else 'Below target'
        lines.append(f"| {weather} | {number(result['render_cpu_ms'].get('p95'))} / {number(result['render_gpu_ms'].get('p95'))} | {result['physics_step_us']['p95']/1000:.2f} / {result['pilot_input_us']['p95']/1000:.2f} | {'Pass' if meets else 'Below target'} |")
    lines += ['', 'Assessment requires mean ≥90 FPS, p95 ≤11.1 ms and p99 ≤16.7 ms, following docs/RENDERING.md. It does not imply a strict 90 FPS minimum.']
    snapshot = read('artifacts/geology_v11/benchmark_snapshot.json', optional=True)
    if snapshot:
        lines += ['', 'The final runs use frozen project code so concurrent UI tasks can continue. Runtime assets and imported resources are shared, with asset/source hashes checked before and after each run.',
            f"Snapshot: `{snapshot['snapshot_root']}`. [Snapshot manifest](benchmark_snapshot.json). Later UI edits are outside this hardware measurement; the geology and terrain identities above identify the measured environment."]
else:
    lines += ['', '**No final hardware-performance claim is supported.** Short, capped checks cannot establish the requested full-descent target.']

lines += ['', '## Driver incidents and workload policy', '',
    'Two Windows graphics timeouts occurred during validation, including one during a headless library check. The cause remains undetermined. See [incident record](DRIVER_INCIDENT.md).',
    'The runner admits one workload at a time, keeps existing applications open, and stops on engine errors, timeout or fresh display-driver/compositor failures.',
    'GPU allocation sampling is informational by default; an explicit GPU allocation cutoff remains available for diagnostics.',
    'A later Discord Clips APPCRASH in an AMD user-mode DLL was initially misclassified by the runner. No accompanying display reset or compositor crash was logged. The filter now records unrelated app errors without aborting validation.',
    '', '## User skiing acceptance', '', '**Pending.** Automated routes do not establish human steering feel, every possible impact or subjective visual acceptance.',
    '', '## Reproduction', '',
    'See [GEOLOGY_V11.md](../../docs/WORLD.md). Regenerate with python scripts/report_geology_v11.py (CPU-only; streams one catalog asset at a time).',
    '[report_inputs.json](report_inputs.json) records hashes of all reports and catalog inputs used.', '']
OUT.mkdir(parents=True, exist_ok=True)
(OUT / 'REPORT.md').write_text('\n'.join(lines), encoding='utf-8')
(OUT / 'report_inputs.json').write_text(json.dumps(INPUTS, indent=2), encoding='utf-8')
(OUT / 'acceptance_status.json').write_text(json.dumps({'automated': statuses,
    'rendered': review_reason or review['status'],
    'performance_runs': len(benchmarks), 'performance': performance_statuses,
    'user_skiing': 'Pending'}, indent=2), encoding='utf-8')
print(OUT / 'REPORT.md')

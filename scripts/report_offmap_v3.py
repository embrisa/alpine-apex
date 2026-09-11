"""Compact local scenery comparison gallery, with separate validation evidence."""
from pathlib import Path
import hashlib
import html
import json
import re
from statistics import median
from datetime import datetime

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'artifacts/offmap_v3'
NATIVE = ROOT / 'artifacts/pc_environment'


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig')) if path.exists() else None


def audit(label):
    system = read(NATIVE / label / 'system.json')
    guard = read(ROOT / 'artifacts/guarded' / label / 'guard.json')
    if not system or not guard:
        return {'complete': False}
    result_name = {'views': 'offmap_v3.json', 'fixed': 'comparison.json', 'descents': 'production.json', 'boundary_motion': 'boundary_motion.json'}[label.removeprefix('offmap_v3_')]
    result_path = NATIVE / label / result_name
    fresh_result = result_path.exists() and result_path.stat().st_mtime >= datetime.fromisoformat(guard['started']).timestamp()
    changed = []
    for name, expected in system['source_sha256_before'].items():
        path = Path(name)
        if not path.exists() or hashlib.sha256(path.read_bytes()).hexdigest().upper() != expected.upper():
            changed.append(name)
    samples = guard.get('samples', [])
    log_path = ROOT / 'artifacts/guarded' / label / 'stdout.log'
    stages = dict((name, float(ms)) for name, ms in re.findall(r'GENERATION_STAGE (\w+) ([\d.]+) ms', log_path.read_text(encoding='utf-8', errors='replace'))) if log_path.exists() else {}
    return {'complete': guard['exit_code'] == 0 and not system['changed_sources'] and fresh_result,
            'result_written_during_run': fresh_result,
            'matches_current_sources': not changed, 'changed_since_run': changed,
            'concurrent': guard['concurrent'], 'started': guard['started'], 'finished': guard['finished'],
            'loading_stages_ms': stages,
            'memory_scope': 'Whole comparison process with both v2 and v3 fixtures resident; not an incremental scenery allocation.',
            'peak_task_private_bytes': max((s.get('task_private_bytes') or 0 for s in samples), default=0),
            'peak_task_gpu_allocation_bytes': max((s.get('task_gpu_dedicated_bytes') or 0 for s in samples), default=0)}


def pair_card(label):
    title = html.escape(label.replace('_', ' '))
    return f'<article data-name="{title}"><h2>{title}</h2><div class="pair">'+''.join(
        f'<figure><a href="../pc_environment/offmap_v3_views/{label}_{s}.png"><img loading="lazy" src="../pc_environment/offmap_v3_views/{label}_{s}.png"></a><figcaption>{t}</figcaption></figure>'
        for s, t in [('before', 'Before - v2'), ('after', 'After - shared v3 asset')])+'</div></article>'


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    views = read(NATIVE / 'offmap_v3_views/offmap_v3.json')
    timing = read(NATIVE / 'offmap_v3_fixed/comparison.json')
    descents = read(NATIVE / 'offmap_v3_descents/production.json')
    boundary_motion = read(NATIVE / 'offmap_v3_boundary_motion/boundary_motion.json')
    report = {'views': views, 'fixed_views': timing, 'descents': descents, 'boundary_motion': boundary_motion,
              'human_acceptance': 'pending', 'automated': {}, 'native_audits': {}}
    for label in ['footprint', 'wilderness', 'atmosphere', 'geometry', 'fingerprints', 'graphics', 'loading', 'scenery_loading', 'weather', 'lifecycle', 'integrity', 'contracts', 'interface', 'mountain_library']:
        guard = read(ROOT / 'artifacts/guarded' / f'offmap_v3_{label}' / 'guard.json')
        if guard:
            entry = {k: guard.get(k) for k in ['exit_code', 'stop_reason', 'concurrent', 'started', 'finished']}
            log = (ROOT / 'artifacts/guarded' / f'offmap_v3_{label}' / 'stdout.log').read_text(encoding='utf-8', errors='replace')
            for line in reversed(log.splitlines()):
                match = re.match(r'^[A-Z0-9_]+\s+(\{.*\})$', line)
                if match:
                    result = json.loads(match[1])
                    if 'checks' in result or ('samples' in result and 'failures' in result):
                        entry.update(checks=result.get('checks', len(result.get('samples', []))), failures=result.get('failures', []))
                        break
            if label == 'weather':
                match = re.search(r'RENDER_EFFICIENCY (\d+) checks; (\d+) failures', log)
                if match: entry.update(checks=int(match[1]), failure_count=int(match[2]))
            if label == 'scenery_loading':
                entry.update(read(ROOT / 'artifacts/geology_v11/scenery_loading.json') or {})
            if label == 'geometry':
                entry.update(checks=len(re.findall(r'^PASS:', log, re.M)),
                             failures=re.findall(r'^FAIL:.*$', log, re.M))
            report['automated'][label] = entry
    report['automated_checks'] = sum(entry.get('checks', 0) for entry in report['automated'].values())
    for label in ['views', 'fixed', 'descents', 'boundary_motion']:
        report['native_audits'][label] = audit('offmap_v3_'+label)
    # An interrupted retry can leave an older result beside the new failure log.
    # Keep it in the detailed record, but never present it as that run's timing.
    if not all(report['native_audits']['fixed'].get(k) for k in ['complete', 'matches_current_sources']): timing = None
    if not all(report['native_audits']['descents'].get(k) for k in ['complete', 'matches_current_sources']): descents = None
    if descents:
        # The descent harness keeps raw samples but its shared cost summary has no median.
        # Derive the requested metric from those samples, without changing native evidence.
        for row in descents['rows']:
            path = NATIVE / 'offmap_v3_descents' / f"frame_samples_{row['run']}.json"
            samples = read(path)
            assert samples and len(samples['gpu_ms']) == row['gpu_ms']['count'], path
            assert len(samples['frame_ms']) == row['frame_ms']['count'], path
            row['gpu_ms']['median'] = median(samples['gpu_ms'])
            row['median_source'] = {'path': str(path.relative_to(ROOT)),
                                    'sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
                                    'method': 'statistics.median over all recorded GPU frame samples'}
        paired = []
        for weather in ['clear', 'snowfall']:
            trials = {r['offmap_version']: r for r in descents['rows'] if r['trial_weather'] == weather}
            if 2 not in trials or 3 not in trials: continue
            a, b = trials[2], trials[3]
            result = {'weather': weather, 'gpu_delta_ms': b['gpu_ms']['median']-a['gpu_ms']['median'],
                      'p95_ratio': b['frame_ms']['p95']/a['frame_ms']['p95'], 'p99_ratio': b['frame_ms']['p99']/a['frame_ms']['p99']}
            result['relative_pass'] = result['gpu_delta_ms'] <= .5 and result['p95_ratio'] <= 1.05 and result['p99_ratio'] <= 1.05
            result['absolute_pass'] = b['frame_ms']['p95'] <= 11.1 and b['frame_ms']['p99'] <= 16.7
            result['exact_traces'] = a['exact_trace'] and b['exact_trace']
            paired.append(result)
        report['descent_comparisons'] = paired
    cards, other, clips = [], [], []
    if views:
        from PIL import Image
        featured = ['summit_clear_day_0', 'edge_corner', 'edge_overview', 'ride_clear_day_0_2750_pov', 'boundary_clear_day_diagonal',
                    'summit_snowfall_day_3', 'summit_clear_dusk_3', 'summit_clear_night_3']
        ordered = [label for label in featured if label in views['pairs']] + [label for label in views['pairs'] if label not in featured]
        for label in ordered:
            for state in ['before', 'after']:
                with Image.open(NATIVE / 'offmap_v3_views' / f'{label}_{state}.png') as im:
                    assert im.size == (3840, 2160), (label, im.size)
            (cards if label in featured else other).append(pair_card(label))
        if views.get('clips'):
            for label in ['pan_0', 'pan_3', 'ride_motion'] + (['boundary_motion'] if boundary_motion else []):
                parts = []
                for state in ['before', 'after']:
                    directory = 'offmap_v3_boundary_motion' if label == 'boundary_motion' else 'offmap_v3_views'
                    sources = [NATIVE / directory / f'{label}_{state}_{index:03d}.jpg' for index in range(24)]
                    preview = OUT / f'{label}_{state}.webp'
                    if not preview.exists() or preview.stat().st_mtime < max(path.stat().st_mtime for path in sources):
                        frames = []
                        for path in sources:
                            with Image.open(path) as frame:
                                assert frame.size == (3840, 2160), path
                                frame.thumbnail((1280, 720)); frames.append(frame.copy())
                        frames[0].save(preview, save_all=True, append_images=frames[1:], duration=100, loop=0, quality=85)
                    parts.append(f'<figure><img loading="lazy" src="{label}_{state}.webp"><figcaption>{state}</figcaption></figure>')
                clips.append(f'<article><h2>{label} - sampled motion</h2><div class="pair">'+''.join(parts)+'</div></article>')
    report['evidence_complete'] = all(a.get('complete') and a.get('matches_current_sources') and not a.get('concurrent') for a in report['native_audits'].values()) and bool(views and len(views['pairs']) == 73 and boundary_motion and boundary_motion['frames'] == 48 and descents and len(descents['rows']) == 4)
    (OUT / 'report.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
    rows = []
    if timing:
        for key, title in [('baseline', 'Fixed views - v2'), ('upgraded', 'Fixed views - v3')]:
            r=timing['pooled'][key]; rows.append((title, r['gpu_ms']['median'], r['frame_ms']['p95'], r['frame_ms']['p99']))
    if descents:
        for r in descents['rows']:
            rows.append((f"{r['trial_weather']} descent - v{r['offmap_version']}", r['gpu_ms']['median'], r['frame_ms']['p95'], r['frame_ms']['p99']))
    table='<table><tr><th>Matched workload</th><th>Median GPU</th><th>Frame p95</th><th>Frame p99</th></tr>'+''.join(f'<tr><td>{html.escape(r[0])}</td>'+''.join(f'<td>{x:.2f} ms</td>' for x in r[1:])+'</tr>' for r in rows)+'</table>'
    loading = '<table><tr><th>Run</th><th>Peak process private memory</th><th>Peak GPU allocation</th></tr>'
    for label in ['fixed', 'descents']:
        entry = report['native_audits'][label]
        if entry.get('complete'):
            loading += f'<tr><td>{label}</td><td>{entry["peak_task_private_bytes"]/2**30:.2f} GiB</td><td>{entry["peak_task_gpu_allocation_bytes"]/2**30:.2f} GiB</td></tr>'
    loading += '</table><p>Memory includes both comparison fixtures resident at once; it is not the incremental cost of v3. Loading-stage timings are recorded separately in the audit details.</p>'
    if timing and descents:
        loading += '<table><tr><th>Loading workload</th><th>Asset read</th><th>Prop preparation</th><th>Prop submission</th></tr>'
        for label, geometry in [('Fixed-view startup', timing['geometry']), ('Descent startup', descents['rows'][0]['offmap'])]:
            loading += f'<tr><td>{label}</td><td>{geometry["asset_read_ms"]:.1f} ms</td><td>{geometry["props"]["prepare_ms"]:.1f} ms</td><td>{geometry["props"]["upload_ms"]:.1f} ms</td></tr>'
        loading += '</table><p>Submission is elapsed time including loading checkpoints, frame pacing and upload; it is not CPU execution time or steady-state GPU cost. These starts read the existing physical/scenery caches.</p>'
    metrics = html.escape(json.dumps({'fixed_budget': timing.get('budget') if timing else None, 'descents': report.get('descent_comparisons'), 'automated': report['automated'], 'native_audits': report['native_audits']}, indent=2))
    page='''<!doctype html><meta charset="utf-8"><title>Alpine Apex - shared background v3</title>
<style>body{max-width:1500px;margin:32px auto;padding:0 24px;background:#101a24;color:#e5edf5;font:16px/1.5 system-ui}h1{font-size:30px}h2{font-size:18px}.pair{display:grid;grid-template-columns:1fr 1fr;gap:12px}figure{margin:0}img{width:100%;display:block}article{margin:32px 0}figcaption{padding:8px;color:#b6c9d9}pre{white-space:pre-wrap;overflow-wrap:anywhere;background:#1b2a37;padding:18px}a{color:#9ad6f5}th,td{text-align:left;padding:8px 18px;border-bottom:1px solid #35434f}summary{cursor:pointer;padding:16px;background:#1b2a37}input{padding:10px;font:inherit;width:90%}@media(max-width:700px){.pair{grid-template-columns:1fr}}</style>
<h1>Shared alpine background and distant valley fog</h1><p>One reusable authored asset, the normal mountain's snow/rock sources, and unused square corners replaced by a closer, irregular scenery connection. The 2.85 km skiing boundary is unchanged. Matched v2/v3 views on v15 Standard at 4K. Open stills at full resolution.</p>
<p>Automated checks, rendered inspection and measured performance are separate. Sampled clips contain capture overhead; user skiing acceptance remains pending.</p>'''
    status='Complete stable evidence set.' if report['evidence_complete'] else 'Validation evidence is incomplete or stale; see audit details.'
    measured = [timing['budget']] + report.get('descent_comparisons', []) if timing else []
    verdict = ''
    if report['evidence_complete']:
        verdict = 'Relative budgets pass on all three measured workloads. ' if all(r['relative_pass'] for r in measured) else 'At least one relative budget is unmet. '
        verdict += 'Absolute frame-time targets pass.' if all(r['absolute_pass'] for r in measured) else 'Absolute frame-time targets remain unmet.'
    page+=f'<p><strong>{status} {verdict}</strong> {report["automated_checks"]} automated checks are recorded.</p><details><summary>Performance, loading, memory and automated checks</summary>'+table+'<p>The relative budget is +0.5 ms median GPU and at most 5% p95/p99 regression. The absolute targets are p95 11.1 ms and p99 16.7 ms.</p>'+loading+'<details><summary>Full validation audit</summary><pre>'+metrics+'</pre></details></details>'+''.join(cards)+''.join(clips)
    page+='<details><summary>All remaining bearings, weather, boundary and quality comparisons</summary><input placeholder="Filter views" oninput="document.querySelectorAll(\'article[data-name]\').forEach(e=>e.hidden=!e.dataset.name.includes(this.value.toLowerCase()))">'+''.join(other)+'</details>'
    (OUT / 'index.html').write_text(page, encoding='utf-8')
    print(json.dumps({'gallery': str(OUT / 'index.html'), 'pairs': len(views['pairs']) if views else 0, 'evidence_complete': report['evidence_complete'], 'fixed_budget': timing.get('budget') if timing else None, 'descents': report.get('descent_comparisons')}, indent=2))

if __name__ == '__main__': main()

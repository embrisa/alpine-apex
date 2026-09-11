"""Compact local scenery comparison gallery, with separate validation evidence."""
from pathlib import Path
import hashlib
import html
import json

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
    changed = []
    for name, expected in system['source_sha256_before'].items():
        path = Path(name)
        if not path.exists() or hashlib.sha256(path.read_bytes()).hexdigest().upper() != expected.upper():
            changed.append(name)
    samples = guard.get('samples', [])
    return {'complete': guard['exit_code'] == 0 and not system['changed_sources'],
            'matches_current_sources': not changed, 'changed_since_run': changed,
            'concurrent': guard['concurrent'], 'started': guard['started'], 'finished': guard['finished'],
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
    report = {'views': views, 'fixed_views': timing, 'descents': descents,
              'human_acceptance': 'pending', 'automated': {}, 'native_audits': {}}
    for label in ['wilderness', 'atmosphere', 'geometry', 'fingerprints', 'graphics', 'loading', 'scenery_loading', 'weather', 'lifecycle']:
        guard = read(ROOT / 'artifacts/guarded' / f'offmap_v3_{label}' / 'guard.json')
        if guard:
            report['automated'][label] = {k: guard.get(k) for k in ['exit_code', 'stop_reason', 'concurrent']}
    for label in ['views', 'fixed', 'descents']:
        report['native_audits'][label] = audit('offmap_v3_'+label)
    if descents:
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
        featured = ['summit_clear_day_0', 'ride_clear_day_0_2750_pov', 'boundary_clear_day_east',
                    'summit_snowfall_day_3', 'summit_clear_dusk_3', 'ride_clear_night_0_2750_chase']
        for label in views['pairs']:
            for state in ['before', 'after']:
                with Image.open(NATIVE / 'offmap_v3_views' / f'{label}_{state}.png') as im:
                    assert im.size == (3840, 2160), (label, im.size)
            (cards if label in featured else other).append(pair_card(label))
        if views.get('clips'):
            for label in ['pan_0', 'pan_3', 'ride_motion']:
                parts = []
                for state in ['before', 'after']:
                    frames = []
                    for index in range(24):
                        with Image.open(NATIVE / 'offmap_v3_views' / f'{label}_{state}_{index:03d}.jpg') as frame:
                            frame.thumbnail((1280, 720)); frames.append(frame.copy())
                    frames[0].save(OUT / f'{label}_{state}.webp', save_all=True, append_images=frames[1:], duration=100, loop=0, quality=85)
                    parts.append(f'<figure><img loading="lazy" src="{label}_{state}.webp"><figcaption>{state}</figcaption></figure>')
                clips.append(f'<article><h2>{label} - sampled motion</h2><div class="pair">'+''.join(parts)+'</div></article>')
    report['evidence_complete'] = all(a.get('complete') and a.get('matches_current_sources') and not a.get('concurrent') for a in report['native_audits'].values()) and bool(views and len(views['pairs']) == 67 and descents and len(descents['rows']) == 4)
    (OUT / 'report.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
    rows = []
    if timing:
        for key, title in [('baseline', 'Fixed views - v2'), ('upgraded', 'Fixed views - v3')]:
            r=timing['pooled'][key]; rows.append((title, r['gpu_ms']['median'], r['frame_ms']['p95'], r['frame_ms']['p99']))
    if descents:
        for r in descents['rows']:
            rows.append((f"{r['trial_weather']} descent - v{r['offmap_version']}", r['gpu_ms']['median'], r['frame_ms']['p95'], r['frame_ms']['p99']))
    table='<table><tr><th>Matched workload</th><th>Median GPU</th><th>Frame p95</th><th>Frame p99</th></tr>'+''.join(f'<tr><td>{html.escape(r[0])}</td>'+''.join(f'<td>{x:.2f} ms</td>' for x in r[1:])+'</tr>' for r in rows)+'</table>'
    metrics = html.escape(json.dumps({'fixed_budget': timing.get('budget') if timing else None, 'descents': report.get('descent_comparisons'), 'automated': report['automated'], 'native_audits': report['native_audits']}, indent=2))
    page='''<!doctype html><meta charset="utf-8"><title>Alpine Apex - shared background v3</title>
<style>body{max-width:1500px;margin:32px auto;padding:0 24px;background:#101a24;color:#e5edf5;font:16px/1.5 system-ui}h1{font-size:30px}h2{font-size:18px}.pair{display:grid;grid-template-columns:1fr 1fr;gap:12px}figure{margin:0}img{width:100%;display:block}article{margin:32px 0}figcaption{padding:8px;color:#b6c9d9}pre{white-space:pre-wrap;overflow-wrap:anywhere;background:#1b2a37;padding:18px}a{color:#9ad6f5}th,td{text-align:left;padding:8px 18px;border-bottom:1px solid #35434f}summary{cursor:pointer;padding:16px;background:#1b2a37}input{padding:10px;font:inherit;width:90%}@media(max-width:700px){.pair{grid-template-columns:1fr}}</style>
<h1>Shared alpine background and distant valley fog</h1><p>One reusable authored asset, the normal mountain's snow/rock sources, and a shorter boundary connection. Matched v2/v3 views on v15 Standard at 4K. Open stills at full resolution.</p>
<p>Automated checks, rendered inspection and measured performance are separate. Sampled clips contain capture overhead; user skiing acceptance remains pending.</p>'''
    status='Complete stable evidence set.' if report['evidence_complete'] else 'Validation evidence is incomplete or stale; see audit details.'
    page+=f'<p><strong>{status}</strong></p>'+table+'<details><summary>Validation and performance details</summary><pre>'+metrics+'</pre></details>'+''.join(cards)+''.join(clips)
    page+='<details><summary>All remaining bearings, weather, boundary and quality comparisons</summary><input placeholder="Filter views" oninput="document.querySelectorAll(\'article[data-name]\').forEach(e=>e.hidden=!e.dataset.name.includes(this.value.toLowerCase()))">'+''.join(other)+'</details>'
    (OUT / 'index.html').write_text(page, encoding='utf-8')
    print(json.dumps({'gallery': str(OUT / 'index.html'), 'pairs': len(views['pairs']) if views else 0, 'evidence_complete': report['evidence_complete'], 'fixed_budget': timing.get('budget') if timing else None, 'descents': report.get('descent_comparisons')}, indent=2))

if __name__ == '__main__': main()

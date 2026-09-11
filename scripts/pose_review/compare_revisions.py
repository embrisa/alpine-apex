"""Build a static before/after review from frozen, tick-matched evidence. No grades."""
import argparse
import html
import json
import os
from pathlib import Path
from urllib.parse import quote
from measure_alignment import measure
from revision import ensure_writable, load_capture, read_json, selected_rows, write_json, write_new

PHYSICAL_FIELDS = ('tick', 'physical_position', 'body_roll_rad', 'speed_mps', 'grounded', 'input', 'skis')


def compare(before, after):
    left, lm, lc = load_capture(before)
    right, rm, rc = load_capture(after)
    if lc.keys() != rc.keys():
        raise ValueError('Capture scenarios differ. Make a matched capture for a controlled comparison.')
    if lm.get('capture_fps') != rm.get('capture_fps') or not lm.get('capture_fps', 0) > 0:
        raise ValueError('Comparison requires matching, positive capture FPS')
    selection = read_json(right / 'selection.json')
    report = {'before': str(left), 'after': str(right), 'physics_fields': PHYSICAL_FIELDS,
              'same_engine': lm.get('engine') == rm.get('engine'), 'capture_fps': rm['capture_fps'],
              'physics_equal': True, 'scenarios': {}, 'visual_grade': None,
              'acceptance': 'Pending reviewer judgement; no scores assigned by this tool.'}
    for name in lc:
        a, b = lc[name]['frames'], rc[name]['frames']
        if [(r['frame'], r['tick']) for r in a] != [(r['frame'], r['tick']) for r in b]:
            raise ValueError(f'{name}: frame/tick coverage differs; do not pair unrelated instants')
        changed = {field: sum(x[field] != y[field] for x, y in zip(a, b)) for field in PHYSICAL_FIELDS}
        report['physics_equal'] &= not any(changed.values())
        chosen_a = selected_rows(a, selection[name])
        chosen_b = selected_rows(b, selection[name])
        pairs = []
        for x, y in zip(chosen_a, chosen_b):
            old, new = measure(x), measure(y)
            pairs.append({'frame': int(x['frame']), 'tick': int(x['tick']), 'before': old, 'after': new,
                          'delta': {key: new[key] - old[key] for key in old}})
        report['scenarios'][name] = {'frames': len(a), 'physical_differences': changed, 'selected': pairs,
                                     'events_before': lc[name].get('events', []), 'events_after': rc[name].get('events', [])}
    return report


def build_page(report, output):
    output = Path(output).resolve()
    ensure_writable(output)
    if output.exists():
        raise ValueError('Comparison output already exists; use a new folder')
    before, after = Path(report['before']), Path(report['after'])

    def link(path):
        return quote(os.path.relpath(path, output).replace('\\', '/'), safe='/')

    def picture(folder, subfolder, scenario, frame, label):
        path = folder / subfolder / scenario / f'{frame:04d}.jpg'
        if not path.exists():
            return f'<p class="missing">{html.escape(label)}: {subfolder} image unavailable for frame {frame}</p>'
        url = link(path)
        return f'<figure><figcaption>{html.escape(label)}</figcaption><a href="{url}"><img loading="lazy" src="{url}" alt="{html.escape(label)} {subfolder}, frame {frame}"></a></figure>'

    parts = ['<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">',
             '<title>Animation comparison</title><style>body{font:16px system-ui;background:#151b22;color:#edf1f5;margin:24px auto;max-width:1500px;padding:0 20px;line-height:1.5}a{color:#90cfff}h1,h2,h3{line-height:1.2}section{border-top:1px solid #465668;padding:20px 0}figure{margin:0}img,video{width:100%;display:block;background:#2a333e}figcaption{padding:8px 0}.pair{display:grid;grid-template-columns:1fr 1fr;gap:14px}.notice{background:#263849;padding:16px;border-radius:8px}.missing{color:#ffc581}table{border-collapse:collapse;margin:14px 0}td,th{text-align:left;padding:5px 16px 5px 0}summary{cursor:pointer}@media(max-width:800px){.pair{grid-template-columns:1fr}}</style>',
             f'<h1>{html.escape(before.name)} → {html.escape(after.name)}</h1>',
             '<p class="notice">No visual grades assigned. Compare the whole body, wrists and full equipment; review entry, hold and release. Smaller measurements are not automatically better. Click images for full resolution.</p>',
             f'<p>Identical recorded physics and ski fields: <strong>{report["physics_equal"]}</strong>. Same capture engine: <strong>{report["same_engine"]}</strong>. Frames are paired by capture tick. Camera metadata is linked below; confirm matching angle and scale before judging.</p>',
             '<p><a href="comparison.json">Measurements and physical comparison</a></p>']
    for name, data in report['scenarios'].items():
        parts.append(f'<section data-fps="{report["capture_fps"]}"><h2>{html.escape(name.replace("_", " "))}</h2><p>{data["frames"]} chronological frames in each capture.</p>')
        for meta in ('capture/manifest.json', 'render.json', 'details.json'):
            for folder, label in ((before, 'Before'), (after, 'After')):
                if (folder / meta).is_file():
                    parts.append(f'<a href="{link(folder / meta)}">{label} {meta}</a> · ')
        parts.append('<div class="pair">')
        for folder, label in ((before, 'Before'), (after, 'After')):
            candidates = [folder / 'videos' / f'{name}.mp4', folder / 'review/assets' / f'{name}.mp4', folder / f'{name}.mp4']
            video = next((p for p in candidates if p.is_file()), None)
            parts.append(f'<figure><figcaption>{label}: full sequence</figcaption><video controls preload="metadata" src="{link(video)}"></video></figure>'
                         if video else f'<p class="missing">{label}: video unavailable. Render and encode the chronological sequence before motion acceptance.</p>')
        parts.append('</div>')
        parts.append('<p class="playback"><button data-action="play">Play pair</button> '
                     '<button data-action="pause">Pause pair</button> <button data-action="start">Start</button> '
                     '<label>Speed <select><option value="1">1×</option><option value="0.5">½×</option><option value="0.25">¼×</option></select></label> '
                     f'<label>Frame <input type="range" min="0" max="{data["frames"] - 1}" value="0"></label> <output>Frame 0</output></p>')
        for row in data['selected']:
            frame = row['frame']
            parts.append(f'<h3>Frame {frame} · tick {row["tick"]}</h3>')
            for subfolder in ('frames', 'details'):
                parts.append('<div class="pair">' + picture(before, subfolder, name, frame, 'Before')
                             + picture(after, subfolder, name, frame, 'After') + '</div>')
            parts.append('<details><summary>Final silhouette measurements (metres / degrees)</summary><table><tr><th>Measure</th><th>Before</th><th>After</th><th>Change</th></tr>')
            for key, old in row['before'].items():
                parts.append(f'<tr><td>{key}</td><td>{old:.4f}</td><td>{row["after"][key]:.4f}</td><td>{row["delta"][key]:+.4f}</td></tr>')
            parts.append('</table></details>')
        parts.append('</section>')
    parts.append('<script src="comparison.js"></script></html>')
    # Compute everything before creating output. Source revisions remain untouched.
    write_json(output / 'comparison.json', report)
    write_new(output / 'comparison.js', Path(__file__).with_name('comparison.js').read_text(encoding='utf-8'))
    write_new(output / 'index.html', '\n'.join(parts))
    return output / 'index.html'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--before', required=True)
    parser.add_argument('--after', required=True)
    parser.add_argument('--output', required=True, help='New sibling folder under the same HTTP server root')
    parser.add_argument('--require-physics-match', action='store_true')
    args = parser.parse_args()
    result = compare(args.before, args.after)
    if args.require_physics_match and not result['physics_equal']:
        raise ValueError('Recorded physics or ski fields differ; inspect the capture before claiming presentation-only equivalence')
    print(build_page(result, args.output))


if __name__ == '__main__':
    main()

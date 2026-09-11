"""Build the dated Cascadeur visual report from retained, sealed evidence.

This composes existing rendered evidence; it never runs or modifies the game.
"""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys
from datetime import datetime, timezone

from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from revision import verify_seal

ROOT = Path(__file__).resolve().parents[3]
EVIDENCE = ROOT / 'artifacts/pose_review'
GROUPS = {
    'r7': ('cascadeur-20260910-r7-production', 'cascadeur-20260910-r7-gameplay', 'cascadeur-20260910-r7'),
    'r6': ('cascadeur-20260910-r6-production', 'cascadeur-20260910-r6-gameplay', 'cascadeur-20260910-r6'),
    'r9': ('cascadeur-20260911-r9-02-before', 'cascadeur-20260911-r9-02-after', 'cascadeur-20260911-r9'),
}
CASES = [
    ('r7', 'steering_right', 'Carving / right', 75, 'Watch the hands and elbows first. At frame 75, hand span increases from 98.5 to 108.2 cm. The legs and skis remain very similar. Decide whether the broader arm carry feels balanced or stiff.'),
    ('r7', 'steering_left', 'Carving / left', 75, 'Check that your preference survives the opposite turn. At frame 75, hand span increases from 99.0 to 109.2 cm. The front view makes this clearer than the chase camera.'),
    ('r7', 'carve_reversal', 'Linked turns / reversal', 54, 'Follow the hands as the turn changes direction. Judge the whole transition, then pause: a good isolated pose can still feel stiff when the skier changes sides.'),
    ('r7', 'carve_taps', 'Quick steering taps', 67, 'Watch how quickly the arms respond and settle. Compare normal speed before slowing down; exaggerated reactions to small corrections are easier to notice in motion.'),
    ('r7', 'tuck_turn', 'Tuck into a turn', 45, 'Watch the tuck open into a balancing pose. Both historical variants have pole/clothing audit failures at frames 44–45. A fixed hand grip does not prove the whole pole clears the jacket.'),
    ('r7', 'straight', 'Straight / unchanged control', 75, 'These two versions should look the same: the R7 carving change is inactive in straight travel. This is a useful check that the viewer is not manufacturing a difference.'),
    ('r7', 'gameplay_carve_reversal', 'Linked turns / chase camera', 36, 'This uses the recorded game camera on a plain test slope. Look at normal size first. If you only prefer a pose when zoomed in, its everyday visual payoff may be small. This is not a mountain-descent recording.'),
    ('r6', 'compression', 'Earlier R6 / compression', 51, 'The imported source differs, but the fitted compression pose looks very close to our baseline. Existing posture rules replace much of the source shape. There is no need to force a preference if you cannot see a useful difference.'),
    ('r6', 'steering_right', 'Earlier R6 / steering', 51, 'This earlier experiment can change hand placement and pole direction during steering, even where compression looks similar. It is a different candidate from the broader R7 carving pose.'),
    ('r9', 'steering_right', 'R9 snow support / right', 62, 'Use the side view and compare boot heights at frame 62. Both versions already use the R7 hand pose; the change here is physical snow support. This cannot establish that Cascadeur makes better animations.'),
    ('r9', 'steering_left', 'R9 snow support / left', 63, 'The audit found a new pole/clothing intersection at frame 63. Inspect the whole sequence and full equipment: a more interesting leg stance can introduce a clearance problem elsewhere.'),
    ('r9', 'carve_reversal', 'R9 snow support / reversal', 27, 'The audit also found a new intersection at frame 27. Inputs and ticks match, but physical support, motion and camera positions can differ. Do not use overlay alignment to judge this case.'),
]


def read(path):
    return json.loads(path.read_text(encoding='utf-8'))


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def run(args):
    subprocess.run([str(a) for a in args], check=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--ffmpeg', required=True)
    parser.add_argument('--output', required=True, type=Path)
    args = parser.parse_args()
    out = args.output.resolve()
    if out.exists():
        raise SystemExit('Use a fresh output directory; reports are retained snapshots.')
    out.mkdir(parents=True)
    (out / 'media').mkdir()
    (out / 'evidence').mkdir()
    receipt = {'created_utc': datetime.now(timezone.utc).isoformat(), 'git_head_at_build': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(), 'git_status_at_build': subprocess.check_output(['git', 'status', '--short'], cwd=ROOT, text=True), 'scope': 'Historical evidence compilation, not a capture of current main.', 'revisions': {}, 'pairs': {}, 'sources': {}, 'outputs': {}}
    for before, after, comparison in GROUPS.values():
        for name in (before, after):
            folder = EVIDENCE / 'revisions' / name
            seal = verify_seal(folder)
            if not seal['passed']:
                raise RuntimeError(f'Seal verification failed: {name}: {seal}')
            manifest = read(folder / 'capture/manifest.json')
            receipt['revisions'][name] = {'seal': seal, 'engine_sha256': manifest['engine_sha256'], 'engine': manifest['engine'], 'physics': manifest['physics'], 'capture_fps': manifest['capture_fps']}
            print(f'Verified {name}: {seal["listed_files"]} sealed files', flush=True)
        for filename in ('comparison.json', 'assessment.json'):
            source = EVIDENCE / 'comparisons' / comparison / filename
            shutil.copy2(source, out / 'evidence' / f'{comparison}-{filename}')

    payload = []
    for group, scenario, title, frame, note in CASES:
        before, after, comparison = GROUPS[group]
        dirs = [EVIDENCE / 'revisions' / rev for rev in (before, after)]
        comparison_data = read(EVIDENCE / 'comparisons' / comparison / 'comparison.json')
        capture_case = scenario.removeprefix('gameplay_')
        captures = [read(d / 'capture' / f'{capture_case}.json')['frames'] for d in dirs]
        if len(captures[0]) != 121 or len(captures[1]) != 121:
            raise RuntimeError('Unexpected sequence length')
        fields = comparison_data['physics_fields']
        mismatches = {field: sum(a.get(field) != b.get(field) for a, b in zip(*captures)) for field in fields}
        if group != 'r9' and any(mismatches.values()):
            raise RuntimeError(f'Physical mismatch in {title}')
        if any(a['tick'] != b['tick'] or a['input'] != b['input'] for a, b in zip(*captures)):
            raise RuntimeError(f'Input/tick mismatch in {title}')
        cameras_equal = all(a.get('gameplay_camera') == b.get('gameplay_camera') for a, b in zip(*captures)) if scenario.startswith('gameplay_') else read(dirs[0] / 'render.json')['scenarios'][capture_case] == read(dirs[1] / 'render.json')['scenarios'][capture_case]
        # Studio metadata rows contain camera transforms and frame IDs only.
        if group != 'r9' and not cameras_equal:
            raise RuntimeError(f'Camera mismatch in {title}')
        key = f'{group}-{scenario}'
        receipt['pairs'][key] = {'frames': 121, 'physical_differences': mismatches, 'cameras_equal': cameras_equal, 'before': before, 'after': after}
        source_movies = [d / 'videos' / f'{scenario}.mp4' for d in dirs]
        target = out / 'media' / f'{key}.mp4'
        # One movie contains both variants, so playback and every seek are intrinsically synchronized.
        # Keep all three 800x1000 camera panels. The viewer crops only the selected panel.
        run([args.ffmpeg, '-hide_banner', '-loglevel', 'error', '-n', '-threads', '2', '-i', source_movies[0], '-threads', '2', '-i', source_movies[1], '-filter_complex_threads', '2', '-filter_complex', '[0:v][1:v]vstack=inputs=2[v]', '-map', '[v]', '-an', '-c:v', 'libx264', '-threads', '2', '-preset', 'veryfast', '-crf', '19', '-pix_fmt', 'yuv420p', '-movflags', '+faststart', target])
        # Count decoded output frames; no interpolation or gap renumbering.
        decoded = subprocess.run([args.ffmpeg, '-hide_banner', '-loglevel', 'error', '-i', str(target), '-map', '0:v:0', '-f', 'framehash', '-'], capture_output=True, text=True, check=True)
        count = sum(bool(line.strip()) and not line.startswith('#') for line in decoded.stdout.splitlines())
        if count != 121:
            raise RuntimeError(f'{key}: decoded {count} frames, expected 121')
        receipt['pairs'][key]['decoded_output_frames'] = count
        for source in source_movies:
            receipt['sources'][str(source.relative_to(ROOT))] = digest(source)
        payload.append({'id': key, 'group': group, 'scenario': scenario, 'title': title, 'frame': frame, 'note': note, 'movie': f'media/{key}.mp4', 'chase': scenario.startswith('gameplay_'), 'cameraMatch': cameras_equal, 'phases': [{'frame': int(f['frame']), 'steer': f['input'].get('steer', 0), 'tuck': f['input'].get('tuck', 0)} for f in captures[0]]})
        print(f'Built and decoded {key}', flush=True)

    # Fixed, identical pixel crops from the full-body cameras; never refocus each variant independently.
    plates = [
        ('r7', 'steering_right', 75, 1, 'carving-front', '1  /  CARVING: HANDS + ELBOWS', 'Our baseline · hand span 98.5 cm', 'Cascadeur R7 · hand span 108.2 cm'),
        ('r7', 'steering_right', 75, 2, 'carving-side', '2  /  SAME MOMENT: SIDE VIEW', 'Our baseline · frame 75', 'Cascadeur R7 · frame 75'),
        ('r6', 'compression', 51, 2, 'compression', '3  /  WHY SOME CHANGES LOOK SIMILAR', 'Our baseline · frame 51', 'Cascadeur R6 · frame 51'),
        ('r9', 'steering_right', 62, 2, 'snow-support', '4  /  PHYSICAL SUPPORT EXPERIMENT', 'R7 pose · original support', 'Same R7 pose · deeper support'),
    ]
    font_dir = Path('C:/Windows/Fonts')
    font = ImageFont.truetype(str(font_dir / 'segoeui.ttf'), 25)
    bold = ImageFont.truetype(str(font_dir / 'segoeuib.ttf'), 27)
    for group, scenario, frame, panel, name, heading, left, right in plates:
        canvas = Image.new('RGB', (1600, 1120), '#101a24')
        draw = ImageDraw.Draw(canvas)
        draw.text((24, 18), heading, font=bold, fill='#f1f6fa')
        for idx, rev in enumerate(GROUPS[group][:2]):
            source = EVIDENCE / 'revisions' / rev / 'frames' / scenario / f'{frame:04d}.jpg'
            image = Image.open(source)
            if image.size != (2400, 1000):
                raise RuntimeError(f'Unexpected image size: {source}')
            canvas.paste(image.crop((panel * 800, 0, panel * 800 + 800, 1000)), (idx * 800, 120))
            draw.rectangle((idx * 800, 65, (idx + 1) * 800, 119), fill=('#174553' if idx == 0 else '#724127'))
            draw.text((idx * 800 + 24, 77), (left, right)[idx], font=font, fill='white')
            receipt['sources'][str(source.relative_to(ROOT))] = digest(source)
        canvas.save(out / 'media' / f'{name}.jpg', quality=94)
    # Give the original source demonstration a distinct role from the fitted game comparisons.
    source_clip = EVIDENCE / 'revisions/cascadeur-20260910-r7-source/videos/cascadeur_carving.mp4'
    source_seal = verify_seal(source_clip.parents[1])
    if not source_seal['passed']:
        raise RuntimeError('Source preview seal failed')
    receipt['source_preview_seal'] = source_seal
    receipt['sources'][str(source_clip.relative_to(ROOT))] = digest(source_clip)
    shutil.copy2(source_clip, out / 'media/source-preview.mp4')
    template = (Path(__file__).parent / 'template.html').read_text(encoding='utf-8')
    (out / 'index.html').write_text(template.replace('__REPORT_DATA__', json.dumps(payload).replace('</', '<\\/')), encoding='utf-8')
    shutil.copy2(Path(__file__).parent / 'viewer.js', out / 'viewer.js')
    (out / 'README.txt').write_text('Alpine Apex / Cascadeur visual comparison\n\nOpen index.html in Chrome or Edge. All viewing media is included; no server or internet is required.\n\nStart with Carving / right, then compare the chase camera. Play at 1x before using slow motion. The stills below explain where to look.\n\nThese are sealed September 10-11 experiments, not the September 12 live checkout. R6/R7 compare animation with matched physics and cameras. R9 changes physical support and retains the R7 hand pose. No tool adoption or visual winner is implied.\n\nBuild provenance and pair verification are in evidence/receipt.json.\n', encoding='utf-8')
    for file in sorted(out.rglob('*')):
        if file.is_file():
            receipt['outputs'][file.relative_to(out).as_posix()] = digest(file)
    (out / 'evidence/receipt.json').write_text(json.dumps(receipt, indent=2), encoding='utf-8')
    print(f'Report ready: {out / "index.html"}', flush=True)


if __name__ == '__main__':
    main()

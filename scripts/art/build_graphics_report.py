"""Rebuild the historical 2026-09-05 graphics evidence index, including removed Terrain3D results."""
import json
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
ART = ROOT / 'artifacts'
FONT_PATH = Path('/System/Library/Fonts/Supplemental/Arial.ttf')
FONT = ImageFont.truetype(str(FONT_PATH), 22) if FONT_PATH.exists() else ImageFont.load_default()


def sheet(filename, panels, columns=2, width=800):
    image_height, title_height = round(width * 900 / 1440), 38
    height = image_height + title_height
    result = Image.new('RGB', (columns * width, ((len(panels) + columns - 1) // columns) * height), '#101720')
    draw = ImageDraw.Draw(result)
    for index, (path, title) in enumerate(panels):
        image = Image.open(ROOT / path).convert('RGB')
        image.thumbnail((width, image_height), Image.Resampling.LANCZOS)
        x, y = (index % columns) * width, (index // columns) * height
        draw.text((x + 14, y + 7), title, fill='#f2f5fa', font=FONT)
        result.paste(image, (x + (width - image.width) // 2, y + title_height + (image_height - image.height) // 2))
    result.save(ART / filename)


sheet('graphics_before_after.png', [
    ('art_source/baseline/chase_day.png', 'Before / chase camera'),
    ('artifacts/light_chase_day_clear.png', 'After / chase camera / Balanced'),
    ('art_source/baseline/pov_day.png', 'Before / first person'),
    ('artifacts/light_pov_day_clear.png', 'After / first person / Balanced'),
])
sheet('graphics_handling_comparison.png', [
    ('artifacts/graphics_skier_tuck.png', 'Skier detail / tuck'),
    ('artifacts/feel_loaded_turn.png', 'Loaded carve / snow spray'),
    ('artifacts/feel_braking.png', 'Braking'),
    ('artifacts/feel_airborne.png', 'Airtime'),
    ('artifacts/feel_landing.png', 'Landing compression'),
    ('artifacts/graphics_settings.png', 'Independent graphics / weather controls'),
])
sheet('graphics_conditions.png', [
    ('artifacts/light_chase_dawn_clear.png', 'Dawn / clear'),
    ('artifacts/light_chase_dusk_snowfall.png', 'Dusk / snowfall illumination'),
    ('artifacts/light_moving_chase_night_snowfall.png', 'Night / moving snowfall'),
    ('artifacts/light_moving_pov_night_rain.png', 'Night / moving rain / first person'),
    ('artifacts/feel_weather_snowfall_chase_200.png', 'High-speed snowfall / 200 km/h entry'),
    ('artifacts/graphics_terrain_edge_left.png', 'Terrain3D / laboratory side boundary'),
])


def read(path):
    return json.loads((ROOT / path).read_text())


tests = {}
for name in ['physics', 'runtime', 'graphics', 'mountain', 'terrain3d', 'presentation', 'weather_presentation', 'lighting']:
    path = f'artifacts/{name}_results.json'
    result = read(path)
    assert not result['failures'], f'Failed suite: {name}'
    tests[name] = {'report': path, 'failures': result['failures']}
    if 'checks' in result:
        tests[name]['checks'] = result['checks']
    if 'captures' in result:
        tests[name]['captures'] = len(result['captures']) + (2 if name == 'lighting' else 0)
for name, log in [('mountain', 'mountain_suite_final.log'), ('terrain3d', 'terrain3d_suite_native_final.log')]:
    tests[name]['checks'] = sum(line.startswith('PASS:') for line in (ART / log).read_text().splitlines())
    tests[name]['log'] = f'artifacts/{log}'
identity = read('artifacts/simulation_source_identity.json')
assert not identity['changed']
ledger = read('art_source/meshy/credit_ledger.json')
assert sum(operation['consumed_credits'] for operation in ledger['operations']) == ledger['spent_credits'] <= ledger['budget_credits']
benchmarks = []
for label in ['final_legacy_balanced_1440p', 'final_t3d_balanced_1440p', 'final_low_1080p', 'final_high_4k', 'final_snowfall_balanced', 'final_baseline_resolution']:
    path = f'artifacts/weather_benchmark_{label}.json'
    result = read(path)
    assert result['finished'] and not result['crashed'] and result['course_id'] == 'laboratory-v2-physics-v3-default'
    benchmarks.append({'report': path, **{key: result[key] for key in ['device', 'platform', 'graphics_driver', 'actual_render_pixels', 'graphics_quality', 'terrain_renderer', 'weather', 'capture_overhead_included', 'mean_frame_ms', 'p95_frame_ms', 'p99_frame_ms', 'one_percent_low_fps', 'peak_video_memory_bytes', 'world_build_ms', 'run_time_s', 'peak_kmh']}, 'average_fps': 1000 / result['mean_frame_ms'], 'mean_draw_calls': result['draw_calls']['mean']})
report = {
    'date': '2026-09-05',
    'tests': tests,
    'source_identity': 'artifacts/simulation_source_identity.json',
    'graphics_captures': len(read('artifacts/graphics_presentation.json')['captures']),
    'credit_ledger': 'art_source/meshy/credit_ledger.json',
    'spent_credits': ledger['spent_credits'],
    'runtime_assets': 'assets/graphics/manifest.json',
    'standalone_pbr_assets': 'art_source/reusable/manifest.json',
    'packed_blender_sources': 'art_source/blender/packed_sources.json',
    'benchmarks': benchmarks,
    'default_terrain_renderer': 'legacy',
    'default_reason': 'This single-machine comparison does not establish a Terrain3D performance advantage in the current bounded course.',
    'limitations': [
        '1440p/120 FPS and 1% lows above 90 FPS were not reached on this M4 in Balanced.',
        'The specified Windows/Linux GPUs, M2 baseline and export packages were not tested.',
        '4K/60 FPS was not reached on this M4 in High.',
        'Metal GPU timings unavailable; these are elapsed desktop frame measurements.',
        'Batch LOD transitions can pop; far billboards lack 3D parallax.',
        'Extreme crash/hand deformation still needs art refinement.',
        'Seed reproduction across platforms has not been established.',
        'Mountains outside the original contact laboratory are decorative; no streaming or erosion simulation.',
    ],
}
(ART / 'graphics_validation.json').write_text(json.dumps(report, indent=2) + '\n')
print(json.dumps({'tests': tests, 'credits': ledger['spent_credits'], 'benchmarks': benchmarks}, indent=2))

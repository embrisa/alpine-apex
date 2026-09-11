"""Behavioral checks for reusable evidence tools; no visual quality assertions."""
import copy
import hashlib
import json
import math
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'scripts/pose_review'))
from compare_revisions import build_page, compare
from measure_alignment import measure
from revision import load_capture, selected_rows, source_status, verify_seal, write_json
from select_frames import select


def frame(index):
    return {'frame': index, 'tick': (index + 1) * 2, 'grounded': True, 'body_roll_rad': 0,
            'physical_position': [0, 0, index], 'speed_mps': 20, 'input': {'steer': 0}, 'skis': [],
            'state': {'tuck': 1}, 'root': {'origin': [0, 0, 0], 'basis': [[1, 0, 0], [0, 1, 0], [0, 0, 1]]},
            'joints': {'Hips': [0, .5, 0], 'LeftFoot': [.1, 0, 0], 'RightFoot': [-.1, 0, 0],
                       'Spine': [0, 1, 0], 'LeftHand': [.18, .9, .2], 'RightHand': [-.18, .9, .2],
                       'LeftForeArm': [.22, .8, 0], 'RightForeArm': [-.22, .8, 0]},
            'rotations': {k: [[1, 0, 0], [0, 1, 0], [0, 0, 1]] for k in ('LeftFoot', 'RightFoot', 'Spine')},
            'poles': [{'origin': [x, .9, .2], 'basis': [[1, 0, 0], [0, 0, 1], [0, -1, 0]]} for x in (-.18, .18)]}


def capture(path, rows=None):
    rows = rows if rows is not None else [frame(i) for i in range(4)]
    sources = {'res://AGENTS.md': hashlib.sha256((ROOT / 'AGENTS.md').read_bytes()).hexdigest()}
    write_json(path / 'capture/manifest.json', {'stable_sources': True, 'sources': sources, 'sources_after': sources,
               'failures': [], 'capture_fps': 60, 'engine': 'test', 'scenarios': [{'name': 'tuck', 'frames': len(rows)}]})
    write_json(path / 'capture/tuck.json', {'name': 'tuck', 'frames': rows, 'events': []})
    write_json(path / 'selection.json', {'tuck': [rows[0]['frame'], rows[-1]['frame']]})


class EvidenceTools(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)

    def tearDown(self):
        self.temp.cleanup()

    def test_world_rotation_and_translation_do_not_change_model_metrics(self):
        row = frame(0)
        before = measure(row)
        cosine, sine = math.cos(.7), math.sin(.7)
        def rotate(v): return [cosine*v[0] + sine*v[2], v[1], -sine*v[0] + cosine*v[2]]
        shift = [129, 27, -91]
        row['root'] = {'origin': shift, 'basis': [rotate(v) for v in row['root']['basis']]}
        for pole in row['poles']:
            pole['origin'] = [a + b for a, b in zip(rotate(pole['origin']), shift)]
            pole['basis'] = [rotate(v) for v in pole['basis']]
        after = measure(row)
        for name in before:
            self.assertAlmostEqual(before[name], after[name], places=10, msg=name)
        self.assertAlmostEqual(after['hand_span_m'], .36)
        self.assertAlmostEqual(after['elbow_span_m'], .44)
        self.assertAlmostEqual(after['pole_tip_width_m'], .36)

    def test_pole_tip_flare_detected_when_grips_do_not_move(self):
        row = frame(0)
        old = measure(row)
        angle = math.radians(15)
        for pole, side in zip(row['poles'], (-1, 1)):
            pole['basis'][1] = [-side*math.sin(angle), 0, math.cos(angle)]
        new = measure(row)
        self.assertAlmostEqual(new['max_shaft_flare_degrees'], 15)
        self.assertGreater(new['pole_tip_width_m'], old['pole_tip_width_m'] + .5)
        self.assertEqual(new['hand_span_m'], old['hand_span_m'])

    def test_scaled_root_is_not_silently_treated_as_rotation(self):
        row = frame(0)
        row['root']['basis'][0][0] = 2
        with self.assertRaises(ValueError): measure(row)

    def test_json_float_ids_work_but_unknown_ids_fail(self):
        rows = [frame(10), frame(20)]
        self.assertEqual(selected_rows(rows, [20.0])[0]['frame'], 20)
        for ids in ([], [20, 20], [20.5], [99], [True]):
            with self.assertRaises(ValueError): selected_rows(rows, ids)

    def test_prepare_selection_uses_support_loss_and_keeps_departure(self):
        rows = [frame(i*10) for i in range(8)]
        for i, row in enumerate(rows):
            row['joints']['Hips'][1] = .7 - i*.05
            row['grounded'] = i < 3
        ids, reasons = select({'name': 'prepare_takeoff', 'frames': rows})
        self.assertIn(20, ids)
        self.assertIn(30, ids)
        self.assertIn(40, ids)
        compression = [key for key, why in reasons.items() if any('lowest supported' in x for x in why)]
        self.assertEqual(compression, ['20'])

    def test_empty_and_duplicate_capture_coverage_fail(self):
        for name, rows in (('empty', []), ('duplicates', [frame(0), frame(0)])):
            path = self.root / name
            if not rows:
                capture(path)
                (path / 'capture/tuck.json').write_text('{"frames": []}')
            else:
                capture(path, rows)
            with self.assertRaises(ValueError): load_capture(path)

    def test_capture_source_drift_flag_cannot_be_overridden_by_stable_boolean(self):
        path = self.root / 'capture'
        capture(path)
        manifest_path = path / 'capture/manifest.json'
        manifest = json.loads(manifest_path.read_text())
        manifest['sources_after']['res://AGENTS.md'] = 'changed'
        manifest_path.write_text(json.dumps(manifest))
        with self.assertRaises(ValueError): load_capture(path)

    def test_sealed_evidence_and_existing_output_are_preserved(self):
        path = self.root / 'sealed'
        capture(path)
        write_json(path / 'sealed.json', {'version': 1})
        with self.assertRaises(ValueError): write_json(path / 'new/nested.json', {})
        self.assertFalse((path / 'new').exists())
        write_json(self.root / 'outside.json', {'keep': True})
        with self.assertRaises(FileExistsError): write_json(self.root / 'outside.json', {})
        self.assertEqual(json.loads((self.root / 'outside.json').read_text()), {'keep': True})

    def test_exact_physical_change_is_reported_without_assigning_grade(self):
        before, after = self.root / 'before', self.root / 'after'
        capture(before)
        rows = [frame(i) for i in range(4)]
        rows[-1]['physical_position'][0] = .00001
        capture(after, rows)
        result = compare(before, after)
        self.assertFalse(result['physics_equal'])
        self.assertEqual(result['scenarios']['tuck']['physical_differences']['physical_position'], 1)
        self.assertIsNone(result['visual_grade'])
        page = build_page(result, self.root / 'comparison')
        self.assertIn('video unavailable', page.read_text())
        self.assertIn('No visual grades assigned', page.read_text())

    def test_tick_mismatch_cannot_be_presented_as_matched_phase(self):
        before, after = self.root / 'before', self.root / 'after'
        capture(before)
        rows = [frame(i) for i in range(4)]
        rows[-1]['tick'] += 1
        capture(after, rows)
        with self.assertRaises(ValueError): compare(before, after)

    def test_snapshot_missing_and_snapshot_changed_are_not_validated(self):
        path = self.root / 'revision'
        capture(path)
        _, manifest, _ = load_capture(path)
        self.assertTrue(source_status(path, manifest)['snapshot_missing_or_changed'])
        (path / 'baseline').mkdir()
        (path / 'baseline/AGENTS.md').write_bytes((ROOT / 'AGENTS.md').read_bytes())
        self.assertFalse(source_status(path, manifest)['snapshot_missing_or_changed'])
        (path / 'baseline/AGENTS.md').write_text('stale')
        self.assertTrue(source_status(path, manifest)['snapshot_missing_or_changed'])

    def test_seal_flag_does_not_hide_changed_or_missing_evidence(self):
        path = self.root / 'sealed'
        capture(path)
        file = path / 'capture/tuck.json'
        write_json(path / 'sealed.json', {'sha256': {'capture/tuck.json': hashlib.sha256(file.read_bytes()).hexdigest()}})
        self.assertTrue(verify_seal(path)['passed'])
        file.write_text('changed')
        self.assertFalse(verify_seal(path)['passed'])
        file.unlink()
        self.assertFalse(verify_seal(path)['passed'])

    def test_empty_seal_cannot_pass(self):
        write_json(self.root / 'sealed.json', {'sha256': {}})
        with self.assertRaises(ValueError): verify_seal(self.root)


if __name__ == '__main__':
    unittest.main(verbosity=2)

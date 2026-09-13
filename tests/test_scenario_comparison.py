"""Evidence integrity and comparison behavior; no engine required."""
import copy
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

SPEC = importlib.util.spec_from_file_location("scenario_compare", Path(__file__).resolve().parents[1] / "scripts/pose_review/compare_scenarios.py")
compare = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(compare)


class ScenarioComparisonTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.manifest = {"format": compare.FORMAT, "version": 1, "simulation_hz": 120, "scenario": "hop", "stimulus": {"jump": 1}, "identity": {"sources": {"solver": "a"}, "engine_sha256": "engine"}, "stable_sources": True, "status": "complete", "telemetry": "telemetry.json", "tuning": {"grip": 1}, "captures": [], "camera": {"view": "side"}}
        self.rows = [{"tick": t, "time": t / 120, "input": [0], "state": {"position": [0, 0, t], "grounded": t > 1}, "metrics": {"speed_mps": t}, "events": ["landing"] if t == 2 else []} for t in range(4)]

    def evidence(self, name, manifest=None, rows=None):
        folder = self.root / name
        folder.mkdir()
        (folder / "manifest.json").write_text(json.dumps(manifest or self.manifest))
        (folder / "telemetry.json").write_text(json.dumps(self.rows if rows is None else rows))
        return folder

    def pair(self, changed=None, manifest=None):
        return compare.load_evidence(self.evidence("a")), compare.load_evidence(self.evidence("b", manifest, changed))

    def test_first_divergence_and_numeric_units(self):
        changed = copy.deepcopy(self.rows)
        changed[2]["state"]["position"][0] = .5
        result = compare.compare(*self.pair(changed))
        self.assertEqual(result["first_divergence_tick"], 2)
        self.assertEqual(result["first_divergence_fields"], ["position"])
        self.assertEqual(result["maximum_position_difference_m"], .5)
        self.assertEqual(result["metric_statistics"]["speed_mps"]["before"]["mean"], 1.5)

    def test_identical_with_optional_new_channel(self):
        changed = copy.deepcopy(self.rows)
        for row in changed: row["state"]["body_roll"] = 0
        result = compare.compare(*self.pair(changed))
        self.assertIsNone(result["first_divergence_tick"])
        self.assertEqual(result["excluded_fields"], ["body_roll"])

    def test_tolerance_does_not_hide_boolean_state(self):
        self.assertTrue(compare.different(False, True, 10))
        self.assertFalse(compare.different([1.0], [1.000001], .00001))

    def test_source_tuning_differences_are_identified(self):
        manifest = copy.deepcopy(self.manifest)
        manifest["identity"]["sources"]["solver"] = "b"
        manifest["identity"]["sources"]["newly_hashed_asset"] = "asset"
        manifest["tuning"]["grip"] = 2
        result = compare.compare(*self.pair(manifest=manifest))
        self.assertEqual(result["source_changes"], ["solver"])
        self.assertEqual(result["tuning_changes"], ["grip"])
        self.assertEqual(result["unpaired_source_hashes"]["after_only"], ["newly_hashed_asset"])

    def test_recorded_states_use_recorded_identity(self):
        manifest = copy.deepcopy(self.manifest)
        manifest["state_origin"] = "recorded_pose"
        manifest["recorded_identity"] = {"sources": {"solver": "old"}, "engine_sha256": "old"}
        result = compare.compare(*self.pair(manifest=manifest))
        self.assertEqual(result["source_changes"], ["solver"])
        self.assertIn("Simulation engine identities differ.", result["issues"])

    def test_mismatched_input_and_coverage_remain_visible(self):
        changed = copy.deepcopy(self.rows[:3])
        changed[1]["input"] = [1]
        result = compare.compare(*self.pair(changed))
        self.assertEqual(result["first_input_difference_tick"], 1)
        self.assertEqual(result["coverage"]["overlap"], [0, 2])
        self.assertTrue(any("unmatched tail" in x for x in result["issues"]))

    def test_failed_unstable_and_mismatched_stimulus(self):
        manifest = copy.deepcopy(self.manifest)
        manifest.update(status="failed", stable_sources=False, stimulus={"jump": 0})
        result = compare.compare(*self.pair(manifest=manifest))
        self.assertTrue(any("unmatched comparison" in x for x in result["issues"]))
        self.assertTrue(any("producer failed" in x for x in result["issues"]))
        self.assertTrue(any("source changed" in x for x in result["issues"]))

    def test_rejects_nonfinite_discontinuous_and_wrong_time(self):
        variants = [[], [dict(self.rows[0], time=1)], [dict(self.rows[0], tick=.5)], [self.rows[0], self.rows[2]], [dict(self.rows[0], metrics={"x": float("nan")})]]
        for i, rows in enumerate(variants):
            with self.subTest(i=i), self.assertRaises(ValueError): compare.load_evidence(self.evidence(str(i), rows=rows))

    def test_rejects_schema_and_escaping_assets(self):
        for i, patch in enumerate([{"version": 2}, {"telemetry": "../telemetry.json"}, {"telemetry": "C:/secret"}, {"captures": [{"tick": 1, "path": "https://host/image.png"}]}, {"captures": [{"tick": 1, "path": "code.html"}]}]):
            with self.subTest(i=i), self.assertRaises(ValueError): compare.load_evidence(self.evidence(str(i), dict(self.manifest, **patch)))

    def test_missing_frames_and_requested_vs_actual_tick(self):
        manifest = dict(self.manifest, captures=[{"tick": 2, "captured_tick": 1, "time": 2/120, "path": "missing.png"}])
        a, b = self.pair(manifest=manifest)
        self.assertEqual(b["missing"], ["missing.png"])
        result = compare.build(a["path"], b["path"], self.root / "review")
        self.assertTrue(any("missing capture" in x for x in result["issues"]))
        self.assertIn('"captured_tick": 1', (self.root / "review/index.html").read_text(encoding="utf-8"))

    def test_report_escapes_notes_and_refuses_overwrite(self):
        manifest = dict(self.manifest, scenario="</script><img onerror=alert(1)>", notes={"observed": "</script><script>alert(1)</script>"})
        a, b = self.pair(manifest=manifest)
        review = self.root / "review"
        compare.build(a["path"], b["path"], review)
        page = (review / "index.html").read_text(encoding="utf-8")
        self.assertNotIn("<script>alert", page)
        self.assertIn("\\u003c/script>", page)
        with self.assertRaises(ValueError): compare.build(a["path"], b["path"], review)


if __name__ == "__main__":
    unittest.main(verbosity=2)

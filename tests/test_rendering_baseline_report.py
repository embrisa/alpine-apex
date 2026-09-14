import copy
import importlib.util
import json
import tempfile
import unittest
from pathlib import Path

spec = importlib.util.spec_from_file_location(
    "report",
    Path(__file__).resolve().parents[1] / "scripts/rendering_baseline_report.py",
)
report = importlib.util.module_from_spec(spec)
spec.loader.exec_module(report)


class BaselineReportTests(unittest.TestCase):
    def setUp(self):
        self.data = {
            "failures": [],
            "unranked": True,
            "capture_overhead_included": False,
            "warmup_frames": 240,
            "loading": {"physical_cache_hit": True, "scenery_cache_hit": True},
            "actual_pixels": [3840, 2160],
            "display": {
                "internal_pixels_from_viewport_scale": [2880, 1620],
                "fidelityfx": {
                    "frame_generation_active": False,
                    "active_upscaler_version": "4.1.1",
                },
            },
            "graphics_preset": 7,
            "sdfgi": False,
            "trial_seconds": 15,
            "trial_start_seconds": 0,
            "rows": [
                {
                    "run": 1,
                    "exact_trace": True,
                    "unfocused_frames": 0,
                    "crash": "",
                    "ticks": 1800,
                    "frame_ms": {"count": 100},
                    "gpu_ms": {"mean": 10},
                }
            ],
        }
        self.system = {
            "exit_code": 0,
            "changed_sources": [],
            "source_sha256_before": {"a": "hash"},
            "source_sha256_after": {"a": "hash"},
            "engine_sha256": "engine",
        }
        self.data.update(
            {
                "identity": {"model": 35},
                "trace_sha256": "trace",
                "camera": {"fov": 68},
                "graphics_profile": {"high": True},
                "renderer": "forward_plus",
                "rendering_driver": "d3d12",
            }
        )
        for scope in [
            "render_cpu_ms",
            "draw_calls",
            "submitted_primitives",
            "submitted_objects",
        ]:
            self.data["rows"][0][scope] = {"mean": 1}

    def test_valid_receipt(self):
        self.assertEqual([], report.validity(self.data, self.system, 1))

    def test_reject_focus_endpoint_duration(self):
        for key, value in [
            ("unfocused_frames", 1),
            ("exact_trace", False),
            ("ticks", 1799),
        ]:
            data = copy.deepcopy(self.data)
            data["rows"][0][key] = value
            self.assertTrue(report.validity(data, self.system, 1), key)

    def test_reject_missing_or_drifting_inputs(self):
        for key, value in [
            ("source_sha256_after", {"a": "new"}),
            ("changed_sources", None),
            ("engine_sha256", ""),
        ]:
            system = self.system | {key: value}
            self.assertTrue(report.validity(self.data, system, 1), key)

    def test_reject_cache_pixels_capture_and_partial_repetitions(self):
        for key, value in [
            ("loading", {}),
            ("actual_pixels", [1920, 1080]),
            ("capture_overhead_included", True),
            ("warmup_frames", 0),
        ]:
            self.assertTrue(
                report.validity(self.data | {key: value}, self.system, 1), key
            )
        self.assertTrue(report.validity(self.data, self.system, 3))

    def test_reject_missing_identity_and_nonfinite_samples(self):
        for key in ["trace_sha256", "identity", "camera", "graphics_profile"]:
            self.assertTrue(
                report.validity(self.data | {key: None}, self.system, 1), key
            )
        self.data["rows"][0]["gpu_ms"]["mean"] = float("nan")
        self.assertTrue(report.validity(self.data, self.system, 1))

    def test_controls_must_share_identity_and_validity(self):
        row = {
            "label": "A",
            "control_group": "same",
            "valid": True,
            "comparison_identity": "one",
            "medians_of_run_statistics": dict.fromkeys(
                ["frame_ms", "gpu_ms", "p95_ms", "p99_ms"], 10
            ),
        }
        other = row | {"label": "B"}
        self.assertTrue(report.compare([row, other])["same"]["matched_valid_controls"])
        self.assertFalse(
            report.compare([row, other | {"comparison_identity": "different"}])["same"][
                "matched_valid_controls"
            ]
        )
        self.assertFalse(
            report.compare([row, other | {"valid": False}])["same"][
                "matched_valid_controls"
            ]
        )
        self.assertFalse(
            report.compare(
                [row | {"profile_only": True}, other | {"profile_only": True}]
            )["same"]["matched_valid_controls"]
        )

    def test_return_range_keeps_first_trial_outlier(self):
        rows = [
            {
                "label": str(i),
                "control_group": "same",
                "valid": True,
                "comparison_identity": "one",
                "medians_of_run_statistics": dict.fromkeys(
                    ["frame_ms", "gpu_ms", "p95_ms", "p99_ms"], v
                ),
            }
            for i, v in enumerate([12, 10, 10])
        ]
        spread = report.compare(rows)["same"]["observed_process_median_ranges"][
            "frame_ms"
        ]
        self.assertEqual(12, spread["max"])
        self.assertAlmostEqual(20, spread["spread_percent_of_min"])

    def test_pass_start_labels_and_boundary_exclusion(self):
        with tempfile.TemporaryDirectory() as directory:
            frames = [
                {
                    "trial": 1,
                    "markers": [
                        ["Render Opaque Pass", 0, 0],
                        ["FSR2", 2000000, 1],
                        ["<scope", 5000000, 2],
                        [">scope", 9000000, 3],
                    ],
                }
                for _ in range(9)
            ]
            data = {"frames": frames, "dropped_frames": 0, "frames_with_passes": 9}
            path = Path(directory) / "gpu_passes.json"
            path.write_text(json.dumps(data))
            intervals = report.passes(Path(directory))["intervals"]
            self.assertEqual(
                {"FSR2": 3, "Render Opaque Pass": 2},
                {v["name"]: v["mean_ms"] for v in intervals},
            )
            self.assertTrue(all(v["count"] == 1 for v in intervals))
            data["dropped_frames"] = 1
            path.write_text(json.dumps(data))
            with self.assertRaises(ValueError):
                report.passes(Path(directory))

    def test_godot_integral_float_run_uses_original_raw_filename(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            columns = {
                key: [1.0]
                for key in [
                    "frame_ms",
                    "gpu_ms",
                    "render_cpu_ms",
                    "draw_calls",
                    "submitted_primitives",
                    "submitted_objects",
                ]
            }
            (root / "frame_samples_1.json").write_text(json.dumps(columns))
            (root / "streaming_events_1.json").write_text(
                json.dumps({"frames": [[7, 0, 1000, 2, 0, 0, 0]], "events": []})
            )
            self.assertEqual(
                1,
                report.chronology(root, {"run": 1.0, "ticks": 1800})["bins"][0][
                    "frames"
                ],
            )
            with self.assertRaises(ValueError):
                report.chronology(root, {"run": 1.2, "ticks": 1800})

    def test_missing_run_retained_as_invalid(self):
        with tempfile.TemporaryDirectory() as directory:
            result = report.audit(
                {"path": "missing", "label": "rejected"}, Path(directory)
            )
            self.assertFalse(result["valid"])
            self.assertIn("FileNotFoundError", result["errors"][0])

    def test_empty_production_rows_retained_as_invalid(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "production.json").write_text(json.dumps(self.data | {"rows": []}))
            (root / "system.json").write_text(json.dumps(self.system))
            result = report.audit({"path": ".", "label": "partial"}, root)
            self.assertFalse(result["valid"])
            self.assertIn("incomplete repetitions", result["errors"])
            self.assertEqual([], result["available_rejected_production"]["rows"])


if __name__ == "__main__":
    unittest.main()

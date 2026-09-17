"""Synthetic wrapper receipts: no renderer, benchmark or saved baseline is run."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

REPO = Path(__file__).resolve().parents[1]


@unittest.skipUnless(shutil.which("pwsh"), "PowerShell targeted wrapper")
class TargetedBenchmarkMetadataTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="targeted metadata ")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        for name in ("scripts/benchmark_targeted.ps1", "scripts/benchmark_metadata.py",
                     "scripts/resolve_godot_engine.ps1", "tests/fixtures/performance_maps.json"):
            dest = self.root / name
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(REPO / name, dest)
        self.output = self.root / "results"
        # The wrapper invokes this fake executable exactly where it would invoke
        # Godot. Deliberately inconsistent synthetic receipts must fail closed.
        self.engine = self.root / "fake engine.ps1"
        self.engine.write_text(r'''
$targetArg = @($args | Where-Object { $_ -like '--output=*' })[0]
$target = $targetArg.Substring('--output='.Length)
New-Item -ItemType Directory -Path $target | Out-Null
$trial = [int]([IO.Path]::GetFileName($target).Substring(6))
$fixtureMode = $env:TARGETED_FIXTURE_MODE
$inputMetadata = @{schema=2;method='scoped_file_metadata';project_root=$PSScriptRoot;
 scope=@{producer='tests/targeted_performance.gd'};versions=@{physics=35};
 engine_files=@{'engine.exe'=@{size=42;mtime_ns=1789000000000000000}};
 files=@{'runtime.gd'=@{size=9;mtime_ns=1789000000000000000};'@engine:engine.exe'=@{size=42;mtime_ns=1789000000000000000}}}
if ($fixtureMode -eq 'between-drift' -and $trial -eq 2) { $inputMetadata.files['runtime.gd'].size=10 }
if ($fixtureMode -ne 'missing') {
 $inputMetadata | ConvertTo-Json -Depth 12 | Set-Content (Join-Path $target 'inputs_before.json')
 if ($fixtureMode -eq 'within-drift') { $inputMetadata.files['runtime.gd'].mtime_ns+=100 }
 $inputMetadata | ConvertTo-Json -Depth 12 | Set-Content (Join-Path $target 'inputs_after.json')
}
$row=@{schema=2;source_verification='scoped_file_metadata';stable_sources=$true;failures=@();performance_evidence=$true;
 map=@{identity='fixture'};actual_pixels=@(3840,2160);graphics=@{quality='High'};
 setup_seconds=1;average_fps=120;frame_ms=@{p95=9;p99=10}}
if ($fixtureMode -eq 'legacy') { $row.schema=1;$row.source_verification='hashes' }
if ($fixtureMode -eq 'map-drift' -and $trial -eq 2) { $row.map.identity='other' }
if ($fixtureMode -eq 'settings-drift' -and $trial -eq 2) { $row.graphics.quality='Low' }
if ($fixtureMode -eq 'pixel-drift' -and $trial -eq 2) { $row.actual_pixels=@(1280,720) }
if ($fixtureMode -eq 'invalid-timing') { $row.performance_evidence=$false }
if ($fixtureMode -eq 'focus-loss') { $row.failures=@('Focused non-minimized measurement') }
$row | ConvertTo-Json -Depth 12 | Set-Content (Join-Path $target 'results.json')
exit 0
''', encoding="utf-8")

    def run_wrapper(self, mode="valid", extra=()):
        env = dict(os.environ, ALPINE_VALIDATION_ROOT=str(self.root),
                   ALPINE_VALIDATION_MODE="FpsCritical", GODOT_BIN=str(self.engine),
                   TARGETED_FIXTURE_MODE=mode)
        return subprocess.run(["pwsh", "-NoProfile", "-File",
                               str(self.root / "scripts/benchmark_targeted.ps1"),
                               "-Map", "mixed", "-Repetitions", "2", "-Output", str(self.output), *extra],
                              env=env, capture_output=True, text=True, timeout=30)

    def test_plan_preserves_admission_settings_and_does_not_create_output(self):
        result = self.run_wrapper(extra=("-PlanOnly",))
        self.assertEqual(0, result.returncode, result.stderr)
        plan = json.loads(result.stdout)
        for key, value in {"source_verification": "scoped_file_metadata", "map": "perf-mixed",
                           "workload_mode": "FpsCritical", "quality": "High", "resolution": "3840x2160",
                           "render_scale": "0.75", "seconds": 6, "full_mountain": False}.items():
            self.assertEqual(value, plan[key])
        self.assertFalse(self.output.exists())

    def test_valid_receipts_aggregate_without_hash_fields(self):
        result = self.run_wrapper()
        self.assertEqual(0, result.returncode, result.stdout + result.stderr)
        summary = json.loads((self.output / "summary.json").read_text(encoding="utf-8-sig"))
        self.assertEqual(2, summary["schema"])
        self.assertEqual(120, summary["median_average_fps"])
        self.assertEqual(2, len(summary["trials"]))
        self.assertNotIn("source_hashes", summary["trials"][0])
        self.assertNotIn("engine_sha256", summary["trials"][0])

    def test_changed_missing_historical_or_invalid_trials_are_rejected(self):
        for mode in ("within-drift", "between-drift", "missing", "legacy", "map-drift",
                     "settings-drift", "pixel-drift", "invalid-timing", "focus-loss"):
            with self.subTest(mode=mode):
                self.output = self.root / mode
                result = self.run_wrapper(mode)
                self.assertNotEqual(0, result.returncode, result.stdout)
                self.assertFalse((self.output / "summary.json").exists())

    def test_capture_is_never_performance_evidence(self):
        result = self.run_wrapper(extra=("-Capture",))
        self.assertEqual(0, result.returncode, result.stderr)
        summary = json.loads((self.output / "summary.json").read_text(encoding="utf-8-sig"))
        self.assertFalse(summary["performance_evidence"])
        self.assertEqual(1, len(summary["trials"]))


if __name__ == "__main__":
    unittest.main()

"""Real PowerShell/process/pipe/lock checks in disposable roots; no Godot needed."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

PROJECT = Path(__file__).resolve().parents[1]
AREA = PROJECT / "artifacts" / "validation_runner_tests"
PWSH = shutil.which("pwsh")


@unittest.skipUnless(os.name == "nt" and PWSH, "Windows PowerShell runner")
class ValidationRunnerTests(unittest.TestCase):
    def setUp(self):
        AREA.mkdir(parents=True, exist_ok=True)
        self.temp = tempfile.TemporaryDirectory(dir=AREA, prefix="runner space ")
        self.root = Path(self.temp.name).resolve()
        (self.root / "scripts").mkdir()
        (self.root / "tests").mkdir()
        for name in ("run_guarded.ps1", "guarded_job.cs", "guarded_child.ps1",
                     "validation_output.cs", "test_pc_environment.ps1"):
            shutil.copy2(PROJECT / "scripts" / name, self.root / "scripts" / name)
        self.env = dict(os.environ)
        self.env.pop("ALPINE_VALIDATION_ROOT", None)
        self.children = []

    def tearDown(self):
        for child in self.children:
            if child.poll() is None:
                child.kill()
            child.communicate(timeout=15)
        assert self.root.is_relative_to(AREA.resolve())
        self.temp.cleanup()

    def write(self, name, body):
        target = self.root / name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(body, encoding="utf-8")
        return target

    def run_ps(self, script, *args):
        return subprocess.run([PWSH, "-NoProfile", "-File", str(self.root / script), *args],
                              cwd=self.root, env=self.env, text=True, encoding="utf-8",
                              capture_output=True, timeout=30)

    def start_ps(self, script):
        child = subprocess.Popen([PWSH, "-NoProfile", "-File", str(self.root / script)],
                                 cwd=self.root, env=self.env, text=True, encoding="utf-8",
                                 stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        self.children.append(child)
        return child

    def guard(self, child_body, options=""):
        self.write("child.ps1", child_body)
        self.write("invoke.ps1", "& ./scripts/run_guarded.ps1 -FilePath pwsh "
                   "-Arguments @('-NoProfile','-File','child.ps1') -Label test "
                   "-TimeoutSeconds 10 -WaitTimeoutSeconds 2 -OutputMode all " + options + "\nexit $LASTEXITCODE\n")

    def receipt(self):
        return json.loads((self.root / "artifacts/guarded/test/guard.json").read_text(encoding="utf-8-sig"))

    def hold_lock(self):
        self.write("holder.ps1", "New-Item -ItemType Directory -Force artifacts | Out-Null\n"
                   "$lock=[IO.File]::Open((Join-Path $PWD 'artifacts/validation.lock'),'OpenOrCreate','ReadWrite','Read')\n"
                   "$bytes=[Text.Encoding]::UTF8.GetBytes('{\"label\":\"fixture-owner\"}')\n"
                   "$lock.Write($bytes,0,$bytes.Length); $lock.Flush()\n"
                   "Write-Output 'LOCK_HELD'\n"
                   "try { while (-not (Test-Path release)) { Start-Sleep -Milliseconds 100 } } finally { $lock.Dispose() }")
        holder = self.start_ps("holder.ps1")
        self.assertEqual(holder.stdout.readline().strip(), "LOCK_HELD")
        return holder

    def test_streams_before_exit_and_keeps_final_unicode_line(self):
        self.guard("Write-Output 'PHASE_READY'; Start-Sleep -Seconds 2; [Console]::Write('final åäö'); exit 0")
        child = self.start_ps("invoke.ps1")
        seen = []
        for line in child.stdout:
            seen.append(line)
            if line.strip() == "PHASE_READY":
                self.assertIsNone(child.poll(), "progress arrived only after completion")
                break
        else:
            self.fail("no live phase output")
        rest, _ = child.communicate(timeout=15)
        self.assertEqual(child.returncode, 0, "".join(seen) + rest)
        self.assertIn("final åäö", rest)
        self.assertTrue(self.receipt()["workload_launched"])

    def test_error_cannot_be_hidden_by_later_output(self):
        self.guard("[Console]::Error.WriteLine('SCRIPT ERROR: sentinel'); 1..200 | ForEach-Object { Write-Output \"line $_\" }; exit 0")
        result = self.run_ps("invoke.ps1")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.receipt()["exit_code"], 1)
        self.assertIn("SCRIPT ERROR: sentinel", (self.root / "artifacts/guarded/test/stderr.log").read_text())

    def test_fail_colon_with_zero_exit_is_failure(self):
        self.guard("Write-Output 'FAIL: sentinel'; exit 0")
        result = self.run_ps("invoke.ps1")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.receipt()["exit_code"], 1)

    def test_wait_then_launch_and_separate_wait_time(self):
        holder = self.hold_lock()
        self.guard("Write-Output 'CHILD_LAUNCHED'; exit 0")
        child = self.start_ps("invoke.ps1")
        line = child.stdout.readline()
        self.assertIn("GUARDED_WAIT", line)
        self.assertIn("fixture-owner", line)
        self.assertIsNone(holder.poll())
        self.write("release", "go")
        rest, _ = child.communicate(timeout=15)
        holder.communicate(timeout=10)
        self.assertEqual(child.returncode, 0, rest)
        self.assertIn("CHILD_LAUNCHED", rest)
        self.assertGreater(self.receipt()["wait_seconds"], 0)

    def test_wait_timeout_preserves_owner_and_existing_receipt(self):
        holder = self.hold_lock()
        self.write("artifacts/guarded/test/guard.json", '{"owner":"previous"}')
        self.write("artifacts/guarded/test/stdout.log", "previous output")
        self.guard("Set-Content launched yes")
        result = self.run_ps("invoke.ps1")
        self.assertNotEqual(result.returncode, 0)
        self.assertIsNone(holder.poll())
        self.assertFalse((self.root / "launched").exists())
        self.assertEqual(self.receipt(), {"owner": "previous"})
        receipts = list((self.root / "artifacts/guarded/test").glob("request-*.json"))
        self.assertEqual(len(receipts), 1)
        self.assertFalse(json.loads(receipts[0].read_text())["workload_launched"])
        self.write("release", "go")
        holder.communicate(timeout=10)

    def test_workload_timeout_releases_lock(self):
        self.guard("Set-Content owned.pid $PID; Start-Sleep -Seconds 25")
        result = self.run_ps("invoke.ps1")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("wall-clock", self.receipt()["stop_reason"])
        self.write("check_owned.ps1", "if (Get-Process -Id ([int](Get-Content owned.pid)) -ErrorAction SilentlyContinue) { exit 1 }; exit 0")
        self.assertEqual(self.run_ps("check_owned.ps1").returncode, 0, "owned descendant survived timeout")
        self.guard("Write-Output 'AFTER_TIMEOUT'; exit 0")
        result = self.run_ps("invoke.ps1")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertTrue(list((self.root / "artifacts/guarded/test/history").glob("*/guard.json")))

    def fake_suites(self):
        for suite in ("ok", "bad", "later", "summary", "text_summary", "summary_bad", "physics_suite", "runtime_suite"):
            self.write("tests/" + suite + ".gd", "fixture")
        self.write("godotw.ps1", "$suite=[IO.Path]::GetFileNameWithoutExtension($args[-1])\n"
                   "Add-Content visited $suite\n"
                   "if ($suite -eq 'bad') { Write-Output 'FAIL: intentional'; exit 0 }\n"
                   "if ($suite -eq 'summary') { Write-Output 'GENERATION_CONTRACTS {\"checks\":3,\"failures\":[]}'; exit 0 }\n"
                   "if ($suite -eq 'text_summary') { Write-Output 'V15_ESTIMATES 5 checks; failures=[]'; exit 0 }\n"
                   "if ($suite -eq 'summary_bad') { Write-Output 'SUMMARY_RESULTS {\"checks\":3,\"failures\":[\"intentional\"]}'; exit 0 }\n"
                   "Write-Output 'PASS: colon'; Write-Output 'PASS space'; exit 0")

    def test_batch_default_plan_and_preflight(self):
        self.fake_suites()
        plan = self.run_ps("scripts/test_pc_environment.ps1", "-PlanOnly")
        self.assertEqual(plan.returncode, 0, plan.stderr)
        self.assertEqual(json.loads(plan.stdout)["suites"], ["physics_suite", "runtime_suite"])
        result = self.run_ps("scripts/test_pc_environment.ps1", "-Suites", "ok,missing")
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((self.root / "visited").exists())

    def test_single_suite_keeps_array_plan_and_results(self):
        self.fake_suites()
        result = self.run_ps("scripts/test_pc_environment.ps1", "-Suites", "ok")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        rows = json.loads((self.root / "artifacts/pc_environment/regression/results.json").read_text())
        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0]["suite"], "ok")
        self.assertEqual(rows[0]["checks_passed"], 2)

    def test_batch_fail_fast_and_explicit_continue(self):
        self.fake_suites()
        result = self.run_ps("scripts/test_pc_environment.ps1", "-Suites", "ok,bad,later")
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        report = self.root / "artifacts/pc_environment/regression"
        rows = json.loads((report / "results.json").read_text())
        self.assertEqual([r["suite"] for r in rows], ["ok", "bad"])
        self.assertEqual(rows[0]["checks_passed"], 2)
        self.assertEqual(json.loads((report / "run.json").read_text())["suites"][-1]["status"], "not_run")
        result = self.run_ps("scripts/test_pc_environment.ps1", "-Suites", "ok,bad,later", "-ContinueOnFailure")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(len(json.loads((report / "results.json").read_text())), 3)

    def test_nested_guard_fails_immediately(self):
        self.guard("& ./scripts/run_guarded.ps1 -FilePath pwsh -Arguments @('-NoProfile','-Command','exit 0') -Label nested")
        result = self.run_ps("invoke.ps1")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Nested validation guards", result.stdout + result.stderr)

    def test_batch_counts_summary_only_suites_and_catches_summary_failure(self):
        self.fake_suites()
        result = self.run_ps("scripts/test_pc_environment.ps1", "-Suites", "summary,text_summary,summary_bad,later")
        self.assertNotEqual(result.returncode, 0)
        rows = json.loads((self.root / "artifacts/pc_environment/regression/results.json").read_text())
        self.assertEqual([r["checks_passed"] for r in rows], [3, 5, 2])
        self.assertEqual(rows[-1]["status"], "failed")


if __name__ == "__main__":
    unittest.main(verbosity=2)

"""Real PowerShell/process/pipe/lock checks in disposable roots; no Godot needed."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time
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
        for name in ("run_guarded.ps1", "validation_lease.ps1", "guarded_job.cs", "guarded_child.ps1",
                     "validation_output.cs", "test_pc_environment.ps1", "clean_artifacts.ps1", "versioning.py"):
            shutil.copy2(PROJECT / "scripts" / name, self.root / "scripts" / name)
        # These fixtures exercise process/lock ownership without launching an
        # engine. Unrelated real game jobs must not control their outcome.
        with (self.root / "scripts/validation_lease.ps1").open("a", encoding="utf-8") as f:
            f.write("\nfunction Get-ValidationExternalWork { if (Test-Path external.busy) { return @('fixture unregistered workload') }; return @() }\n")
        self.env = dict(os.environ)
        self.env.pop("ALPINE_VALIDATION_ROOT", None)
        self.env.pop("ALPINE_VALIDATION_MODE", None)
        self.env.pop("ALPINE_VALIDATION_RESOURCES", None)
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

    def wait_path(self, name, timeout=15):
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            if (self.root / name).exists():
                return
            time.sleep(.05)
        self.fail(f"Timed out waiting for {name}")

    def start_workload(self, name, mode="Shared", resource=None):
        self.write(name+".ps1", f"Set-Content {name}.pid $PID\nSet-Content {name}.started yes\n"
                   f"while (-not (Test-Path {name}.release)) {{ Start-Sleep -Milliseconds 50 }}\n")
        options = f" -ResourceKeys @('{resource}')" if resource else ""
        self.write("invoke_"+name+".ps1", "& ./scripts/run_guarded.ps1 -FilePath pwsh "
                   f"-Arguments @('-NoProfile','-File','{name}.ps1') -Label {name} -WorkloadMode {mode} "
                   "-TimeoutSeconds 30 -WaitTimeoutSeconds 20"+options+"\nexit $LASTEXITCODE\n")
        return self.start_ps("invoke_"+name+".ps1")

    def finish_workload(self, name, child):
        self.write(name+".release", "go")
        output, _ = child.communicate(timeout=20)
        self.assertEqual(child.returncode, 0, output)

    def test_shared_workloads_overlap(self):
        first = self.start_workload("first")
        self.wait_path("first.started")
        second = self.start_workload("second")
        self.wait_path("second.started")
        self.assertIsNone(first.poll())
        self.assertIsNone(second.poll())
        third = self.start_workload("third")
        self.wait_path("third.started")
        self.assertIsNone(first.poll())
        self.assertIsNone(second.poll())
        self.finish_workload("first", first)
        self.finish_workload("second", second)
        self.finish_workload("third", third)

    def test_wrapped_shared_batch_requires_its_output_scope(self):
        self.fake_suites()
        self.guard("& ./scripts/test_pc_environment.ps1 -Suites ok\nexit $LASTEXITCODE")
        result = self.run_ps("invoke.ps1")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("does not reserve", result.stdout + result.stderr)
        self.assertFalse((self.root / "visited").exists())

    def test_cancelled_waiting_exclusive_does_not_block_readers(self):
        first = self.start_workload("first")
        self.wait_path("first.started")
        writer = self.start_workload("fps", "FpsCritical")
        self.wait_path("artifacts/guarded/fps")
        time.sleep(.5)
        writer.kill(); writer.communicate(timeout=15)
        later = self.start_workload("later")
        self.wait_path("later.started")
        self.assertIsNone(first.poll())
        self.finish_workload("first", first)
        self.finish_workload("later", later)

    def test_exclusive_waits_for_readers_and_blocks_later_readers(self):
        first = self.start_workload("first")
        self.wait_path("first.started")
        writer = self.start_workload("fps", "FpsCritical")
        deadline = time.monotonic()+15
        while time.monotonic()<deadline:
            try:
                rows = [json.loads(p.read_text()) for p in (self.root/"artifacts/validation_leases").glob("*.json")]
            except (OSError, json.JSONDecodeError):
                time.sleep(.05)
                continue
            if any(row["label"]=="fps" and row["state"]=="waiting" for row in rows): break
            time.sleep(.05)
        else: self.fail("exclusive request did not queue")
        later = self.start_workload("later")
        time.sleep(.5)
        self.assertFalse((self.root/"fps.started").exists())
        self.assertFalse((self.root/"later.started").exists())
        self.finish_workload("first", first)
        self.wait_path("fps.started")
        self.assertFalse((self.root/"later.started").exists())
        self.finish_workload("fps", writer)
        self.wait_path("later.started")
        self.finish_workload("later", later)

    def test_shared_output_reservation_serializes_only_conflicting_jobs(self):
        first = self.start_workload("first", resource="shared-output")
        self.wait_path("first.started")
        second = self.start_workload("second", resource="shared-output")
        free = self.start_workload("free", resource="different-output")
        self.wait_path("free.started")
        self.assertFalse((self.root/"second.started").exists())
        self.finish_workload("free", free)
        self.finish_workload("first", first)
        self.wait_path("second.started")
        self.finish_workload("second", second)

    def test_cancelled_owner_releases_lease_and_its_child_tree(self):
        first = self.start_workload("first", "FpsCritical")
        self.wait_path("first.started")
        first.kill(); first.communicate(timeout=15)
        self.write("check_owned.ps1", "if (Get-Process -Id ([int](Get-Content first.pid)) -ErrorAction SilentlyContinue) { exit 1 }; exit 0")
        self.assertEqual(self.run_ps("check_owned.ps1").returncode, 0)
        second = self.start_workload("second")
        self.wait_path("second.started")
        self.finish_workload("second", second)
        self.assertEqual(list((self.root/"artifacts/validation_leases").glob("*.json")), [])

    def test_unregistered_workload_is_preserved(self):
        self.write("external.busy", "existing")
        self.guard("Set-Content launched yes")
        result = self.run_ps("invoke.ps1")
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((self.root/"launched").exists())
        self.assertTrue((self.root/"external.busy").exists())

    def test_known_benchmarks_are_exclusive_and_launchers_do_not_serialize_readers(self):
        self.write("classify.ps1", ". ./scripts/validation_lease.ps1\n"
                   "$a=Get-ValidationWorkload './godotw.ps1' @('--script','tests/physics_suite.gd') 'Shared' @()\n"
                   "$b=Get-ValidationWorkload 'pwsh' @('-File','scripts/benchmark_pc.ps1') 'Shared' @()\n"
                   "$c=Get-ValidationWorkload './godotw.ps1' @('--import') 'Shared' @()\n"
                   "$d=Get-ValidationWorkload './godotw.ps1' @('--script',(Join-Path $PWD 'tests/physics_suite.gd')) 'Shared' @()\n"
                   "@($a,$b,$c,$d) | ConvertTo-Json -Depth 5\n")
        result = self.run_ps("classify.ps1")
        self.assertEqual(result.returncode, 0, result.stderr)
        rows = json.loads(result.stdout)
        self.assertEqual([r["mode"] for r in rows], ["Shared","FpsCritical","Exclusive","Shared"])
        self.assertEqual(rows[0]["resources"], ["script:tests/physics_suite.gd"])
        self.assertEqual(rows[0]["resources"], rows[3]["resources"])

    def test_external_process_discovery_excludes_registered_descendants(self):
        helper = str(PROJECT / "scripts/validation_lease.ps1").replace("'", "''")
        self.write("discover.ps1", f". '{helper}'\n" +
                   "function Get-CimInstance { return @(\n"
                   "[pscustomobject]@{ProcessId=70001;ParentProcessId=70000;Name='Godot.exe';CommandLine='--script owned.gd'},\n"
                   "[pscustomobject]@{ProcessId=80001;ParentProcessId=80000;Name='Godot.exe';CommandLine='--script external.gd'},\n"
                   "[pscustomobject]@{ProcessId=90001;ParentProcessId=90000;Name='Godot.exe';CommandLine='--path game'}) }\n"
                   "$peers=@([pscustomobject]@{pid=70000})\n"
                   "$shared=@(Get-ValidationExternalWork @{Metadata=@{mode='Shared'}} $peers)\n"
                   "$fps=@(Get-ValidationExternalWork @{Metadata=@{mode='FpsCritical'}} $peers)\n"
                   "@{shared=$shared;fps=$fps} | ConvertTo-Json -Depth 5\n")
        result = self.run_ps("discover.ps1")
        self.assertEqual(result.returncode, 0, result.stderr)
        rows = json.loads(result.stdout)
        self.assertEqual(len(rows["shared"]), 1)
        self.assertIn("80001", rows["shared"][0])
        self.assertEqual(len(rows["fps"]), 2)
        self.assertNotIn("70001", json.dumps(rows))

    def test_cleanup_preserves_a_waiting_process_lease(self):
        self.write("artifacts/validation_leases/waiting.json", "waiting")
        self.write("artifacts/obsolete/report.txt", "disposable")
        self.write("clean.ps1", "$lease=[IO.File]::Open((Join-Path $PWD 'artifacts/validation_leases/waiting.json'),'Open','ReadWrite','Read')\n"
                   "function Get-Process { return @() }\n"
                   "try { & ./scripts/clean_artifacts.ps1 -Confirm:$false } finally { $lease.Dispose() }\n")
        result = self.run_ps("clean.ps1")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual((self.root / "artifacts/validation_leases/waiting.json").read_text(), "waiting")
        self.assertFalse((self.root / "artifacts/obsolete").exists())

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

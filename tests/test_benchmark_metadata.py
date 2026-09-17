import copy
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

REPO = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("metadata", REPO / "scripts/benchmark_metadata.py")
metadata = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(metadata)


class BenchmarkMetadataTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="benchmark metadata ")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        for args in (("init", "-q"), ("config", "user.name", "Fixture"), ("config", "user.email", "fixture@example.invalid")):
            self.git(*args)
        self.write("runtime/mesh.bin", b"mesh")
        self.write("tests/producer.gd", 'extends "res://tests/helper.gd"\n')
        self.write("tests/helper.gd", "extends SceneTree\n")
        self.write("docs/unrelated.md", "notes")
        self.write("trace.json", json.dumps({"face": 1, "result": {"side": 0}}))
        self.write("engine/godot.exe", b"engine")
        self.scope = self.root / "scope.json"
        self.scope.write_text(json.dumps({"schema": 1, "roots": ["runtime"], "paths": ["optional.cfg"]}))
        self.git("add", "."); self.git("commit", "-qm", "fixture")

    def git(self, *args):
        return subprocess.run(["git", "-C", str(self.root), *args], check=True, capture_output=True)

    def write(self, path, content):
        p = self.root / path; p.parent.mkdir(parents=True, exist_ok=True)
        p.write_bytes(content if isinstance(content, bytes) else content.encode())

    def capture(self, **kwargs):
        return metadata.capture(self.root, self.scope, "tests/producer.gd", "res://trace.json", self.root / "engine/godot.exe", **kwargs)

    def test_scoped_add_edit_delete_and_optional_input_creation(self):
        before = self.capture()
        self.write("runtime/mesh.bin", b"changed mesh")
        self.write("runtime/new.bin", b"new")
        self.write("optional.cfg", "created")
        (self.root / "tests/helper.gd").unlink()
        changed = metadata.compare(before, self.capture())
        self.assertEqual(["optional.cfg", "runtime/mesh.bin", "runtime/new.bin", "tests/helper.gd"], changed)

    def test_unrelated_work_and_unrelated_commit_do_not_invalidate(self):
        before = self.capture()
        self.write("docs/unrelated.md", "new notes")
        self.write("tests/unrelated.gd", "unrelated fixture")
        self.git("add", "."); self.git("commit", "-qm", "unrelated work")
        after = self.capture()
        self.assertNotEqual(before["git"], after["git"])
        self.assertEqual([], metadata.compare(before, after))

    def test_dirty_start_is_recorded_and_permitted(self):
        self.write("runtime/mesh.bin", b"candidate")
        before = self.capture()
        self.assertIn("runtime/mesh.bin", before["git"]["status"])
        self.assertEqual([], metadata.compare(before, self.capture()))

    def test_trace_engine_and_runtime_dll_edits_are_detected(self):
        before = self.capture()
        self.write("trace.json", '{"different":true}')
        self.write("engine/godot.exe", b"new engine")
        self.write("engine/provider.dll", b"new provider")
        changed = metadata.compare(before, self.capture())
        self.assertEqual(3, len(changed))
        self.assertTrue(any(p.startswith("@trace:") for p in changed))
        self.assertEqual(2, sum(p.startswith("@engine:") for p in changed))

    def test_required_inputs_and_corrupt_receipts_fail_closed(self):
        before = self.capture()
        for key in ("files", "engine_files", "schema", "method"):
            after = copy.deepcopy(before); after[key] = None
            with self.assertRaises(ValueError): metadata.compare(before, after)
        (self.root / "trace.json").unlink()
        with self.assertRaises(ValueError): self.capture()

    def test_extra_paths_are_literal_and_detect_edits(self):
        before = self.capture(extra_paths=["docs/unrelated.md"])
        self.write("docs/unrelated.md", "explicitly relevant")
        self.assertEqual(["docs/unrelated.md"], metadata.compare(before, self.capture(extra_paths=["docs/unrelated.md"])))
        for path in (".", "../outside", "runtime/*", "C:/outside", ".git/config"):
            with self.assertRaises(ValueError): self.capture(extra_paths=[path])

    @unittest.skipUnless(shutil.which("pwsh"), "PowerShell launch-plan fixture")
    def test_plan_only_preserves_workload_and_creates_no_output(self):
        env = dict(os.environ, GODOT_BIN=str(self.root / "engine/godot.exe"))
        result = subprocess.run(["pwsh", "-NoProfile", "-File", str(REPO / "scripts/benchmark_pc.ps1"),
                                 "-ProjectRoot", str(self.root), "-MetadataScope", str(self.scope), "-InputTrace", "res://trace.json",
                                 "-Label", "fixture", "-ScenarioReplay", "-TrialSeconds", "12", "-FrameCap", "0", "-PlanOnly"],
                                env=env, capture_output=True, text=True, timeout=30)
        self.assertEqual(0, result.returncode, result.stdout + result.stderr)
        plan = json.loads(result.stdout)
        self.assertEqual("tests/performance_descent.gd", plan["producer"])
        for arg in ("--face=1", "--side=-1", "--trial-seconds=12", "--trial-start-seconds=0", "--scenario-replay", "--benchmark-no-captures", "--fps-limit=0"):
            self.assertIn(arg, plan["arguments"])
        self.assertEqual("unchanged", plan["runtime_replay_cache_checks"])
        self.assertTrue(plan["full_mountain_required"])
        self.assertFalse((self.root / "artifacts").exists())

    @unittest.skipUnless(shutil.which("pwsh"), "PowerShell engine selection fixture")
    def test_metadata_engine_selection_never_reads_binary_hashes(self):
        self.write(".tools/fidelityfx-runtime.json", '{"enabled":true}')
        directory = ".tools/godot-fsr/bin/"
        for name in ("godot.windows.template_debug.x86_64.exe", "godot.windows.template_debug.x86_64.console.exe"):
            self.write(directory + name, b"fixture executable")
        script = self.root / "resolve.ps1"
        script.write_text("$ErrorActionPreference='Stop'\n$env:GODOT_BIN=''\n"
                          "function Get-FileHash { throw 'Hashing forbidden in this fixture' }\n"
                          f". '{str(REPO / 'scripts/resolve_godot_engine.ps1').replace(chr(39), chr(39)*2)}'\n"
                          f"Get-AlpineGodotEngine -ProjectRoot '{str(self.root).replace(chr(39), chr(39)*2)}' -MetadataOnly\n")
        result = subprocess.run(["pwsh", "-NoProfile", "-File", str(script)], capture_output=True, text=True, timeout=30)
        self.assertEqual(0, result.returncode, result.stdout + result.stderr)
        self.assertTrue(result.stdout.strip().endswith(".console.exe"))


if __name__ == "__main__":
    unittest.main()

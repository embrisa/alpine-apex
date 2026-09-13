"""Exercise actual Git history/index boundaries in disposable repositories."""
import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import unittest

SPEC = importlib.util.spec_from_file_location("versioning", Path(__file__).resolve().parents[1] / "scripts/versioning.py")
v = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(v)


class VersioningTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        self.git("init", "-b", "main")
        for name, value in [("user.name", "Version Fixture"), ("user.email", "test@example.invalid"), ("core.autocrlf", "false"), ("commit.gpgsign", "false")]:
            self.git("config", name, value)
        self.write(".gitignore", "ignored/\n")
        for path, constant in v.OWNERS.values():
            existing = v.content(self.root, path) or b""
            self.write(path, existing.decode() + f"const {constant} = 1\n")
        self.write(v.TUNING, "tuning")
        self.write("project.godot", "common/physics_ticks_per_second=120\n")
        self.commit()
        self.base = self.git("rev-parse", "HEAD")
        v.save(self.root / v.CONFIG, {"schema": 1, "baseline_commit": self.base})

    def git(self, *args):
        return v.git(self.root, *args).decode().strip()

    def write(self, name, data):
        path = self.root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(data, encoding="utf-8")

    def commit(self):
        self.git("add", ".")
        self.git("commit", "-m", "Fixture milestone")

    def note(self, paths=None):
        paths = paths or [v.CONFIG]
        path = v.create_note(self.root, {"write_paths": paths, "read_paths": []}, "Document fixture", ["Maintenance"])
        v.capture_inputs(self.root, path)
        note = v.read_json(self.root / path)
        note["areas"] = ["fixture"]
        note["checks"] = [{"kind": "automated", "command": "fixture check", "result": "passed", "details": "Fixture assertion passed"}]
        note["compatibility"]["decisions"] = {key: {"effect": "preserved", "reason": "No behavior change"} for key in ["physics", "world", "data"]}
        note["compatibility"]["data"] = {key: {"effect": "preserved", "reason": "Metadata only"} for key in v.DATA}
        v.save(self.root / path, note)
        return path

    def test_baseline_successive_history_and_independent_notes(self):
        self.assertIsNone(v.identity(self.root)["dev"])
        path = self.note()
        self.assertEqual(v.check_note(self.root, path), [])
        self.commit()
        self.assertEqual(v.check_commit(self.root), [])
        first = v.identity(self.root)
        self.assertEqual(first["dev"], 1)
        self.assertFalse(first["modified"])
        self.write("one.md", "one")
        self.write("two.md", "two")
        one = self.note(["one.md"])
        two = self.note(["two.md"])
        self.assertNotEqual(one, two)
        self.git("add", "one.md", one)
        self.git("commit", "-m", "First concurrent milestone", "--", "one.md", one)
        self.assertEqual(v.check_commit(self.root), [])
        self.assertEqual(v.check_note(self.root, two), [])
        self.git("add", "two.md", two)
        self.git("commit", "-m", "Second concurrent milestone", "--", "two.md", two)
        self.assertEqual(v.identity(self.root)["dev"], 3)
        self.assertIn("## Dev 3", v.markdown(v.history(self.root)))
        self.assertEqual(v.history(self.root)[-1]["commit"], first["commit"])

    def test_missing_notes_and_append_only(self):
        self.commit()
        self.assertIn("no milestone note", v.identity(self.root)["warning"])
        self.assertTrue(v.check_commit(self.root))
        self.assertIn("Missing milestone note", v.markdown(v.history(self.root)))
        self.write("readme.md", "new")
        path = self.note(["readme.md"])
        self.commit()
        self.assertTrue(any("append-only" in p for p in v.check_note(self.root, path)))

    def test_modified_deleted_untracked_and_index_identity(self):
        path = self.note(); self.commit()
        clean = v.identity(self.root)
        self.write("ignored/noise", "ignored")
        self.assertFalse(v.identity(self.root)["modified"])
        self.write("untracked space.txt", "one")
        first = v.identity(self.root)
        self.assertTrue(first["modified"])
        self.assertEqual(first["dev"], clean["dev"])
        self.write("untracked space.txt", "two")
        self.assertNotEqual(first["changes_sha256"], v.identity(self.root)["changes_sha256"])
        (self.root / v.TUNING).unlink()
        self.assertIsNone(v.dirty_snapshot(self.root)[v.TUNING]["sha256"])
        self.git("add", "untracked space.txt")
        staged = v.identity(self.root)
        self.write("untracked space.txt", "three")
        self.assertNotEqual(staged["changes_sha256"], v.identity(self.root)["changes_sha256"])
        self.assertEqual(v.check_commit(self.root), [])

    def test_scope_preserves_unrelated_staged_changes(self):
        path = self.note(); self.commit()
        self.write("owned.md", "owned")
        self.write("peer.md", "peer")
        self.git("add", "peer.md")
        peer_index = self.git("ls-files", "--stage", "peer.md")
        note = self.note(["owned.md"])
        self.assertEqual(v.check_note(self.root, note), [])
        self.git("add", "owned.md", note)
        self.assertEqual(v.check_note(self.root, note, staged=True), [])
        self.assertEqual(self.git("ls-files", "--stage", "peer.md"), peer_index)
        self.write("owned.md", "changed after staging")
        problems = v.check_note(self.root, note, staged=True)
        self.assertTrue(any("Tested input changed" in p for p in problems))
        self.assertTrue(any("Index differs" in p for p in problems))

    def test_compatibility_declaration_and_tested_read_drift(self):
        self.note(); self.commit()
        owner = v.OWNERS["physics"][0]
        self.write(owner, "const MODEL_VERSION = 2\n")
        note_path = self.note([owner])
        self.assertTrue(any("identity changed" in p for p in v.check_note(self.root, note_path)))
        note = v.read_json(self.root / note_path)
        note["compatibility"]["decisions"]["physics"]["effect"] = "changed"
        for key in ["records", "ghosts"]: note["compatibility"]["data"][key]["effect"] = "incompatible"
        v.save(self.root / note_path, note)
        self.assertEqual(v.check_note(self.root, note_path), [])
        self.write(v.TUNING, "peer changed tested dependency")
        self.assertTrue(any(v.TUNING in p for p in v.check_note(self.root, note_path)))

    def stage_asset_pointer(self, asset, pointer, hydrated):
        # Real Git index/commit blobs, no LFS installation or network required.
        (self.root / asset).write_bytes(pointer)
        self.git("add", asset)
        (self.root / asset).write_bytes(hydrated)

    def test_lfs_staged_content_and_historical_note_hash(self):
        self.note(); self.commit()
        asset = "assets/grass.res"
        self.write(asset, "hydrated mesh payload")
        hydrated = (self.root / asset).read_bytes()
        pointer = f"version https://git-lfs.github.com/spec/v1\noid sha256:{v.sha(hydrated)}\nsize {len(hydrated)}\n".encode()
        note = self.note([asset])
        self.stage_asset_pointer(asset, pointer, hydrated)
        self.git("add", note)
        self.assertEqual(v.check_note(self.root, note, staged=True), [])
        self.git("commit", "-m", "LFS asset fixture")
        self.assertEqual(v.check_commit(self.root), [])
        self.write(asset, "unrelated later worktree bytes")
        self.assertEqual(v.check_commit(self.root), [])

    def test_lfs_rejects_wrong_oid_size_malformed_and_unhydrated(self):
        self.note(); self.commit()
        asset = "assets/grass.res"
        self.write(asset, "hydrated mesh payload")
        hydrated = (self.root / asset).read_bytes()
        pointer = f"version https://git-lfs.github.com/spec/v1\noid sha256:{v.sha(hydrated)}\nsize {len(hydrated)}\n".encode()
        note = self.note([asset])
        self.git("add", note)
        for corrupt in [pointer.replace(v.sha(hydrated).encode(), b"0"*64), pointer.replace(b"size 21", b"size 22"), pointer.rstrip(b"\n"), pointer+b"extra invalid\n"]:
            with self.subTest(pointer=corrupt):
                self.stage_asset_pointer(asset, corrupt, hydrated)
                self.assertTrue(any("Index differs" in p for p in v.check_note(self.root, note, staged=True)))
        self.stage_asset_pointer(asset, pointer, pointer)
        self.assertTrue(any("Index differs" in p for p in v.check_note(self.root, note, staged=True)))
        self.stage_asset_pointer(asset, pointer.replace(v.sha(hydrated).encode(), b"0"*64), hydrated)
        self.git("commit", "-m", "Invalid asset pointer fixture")
        self.assertTrue(any("Tested input changed" in p for p in v.check_commit(self.root)))

    def test_changed_behavior_requires_identity_bump(self):
        self.note(); self.commit()
        owner = v.OWNERS["physics"][0]
        self.write(owner, "const MODEL_VERSION = 1\n# behavior change\n")
        path = self.note([owner])
        note = v.read_json(self.root / path)
        note["compatibility"]["decisions"]["physics"]["effect"] = "changed"
        v.save(self.root / path, note)
        self.assertTrue(any("requires a model" in p for p in v.check_note(self.root, path)))

    def test_failed_or_incomplete_verification(self):
        path = self.note()
        note = v.read_json(self.root / path)
        note["checks"][0]["result"] = "failed"
        v.save(self.root / path, note)
        self.assertTrue(v.check_note(self.root, path))

    def test_shallow_and_unrelated_baseline_do_not_invent_numbers(self):
        self.note(); self.commit()
        with tempfile.TemporaryDirectory() as target:
            subprocess.run(["git", "clone", "--depth=1", self.root.as_uri(), target], check=True, capture_output=True)
            self.assertIsNone(v.identity(Path(target))["dev"])
        v.save(self.root / v.CONFIG, {"schema": 1, "baseline_commit": "f" * 40})
        self.commit()
        self.assertIsNone(v.identity(self.root)["dev"])

    def test_export_inputs_exclude_documentation_drift(self):
        self.note(); self.commit()
        before = v.identity(self.root)
        self.write("docs/other.md", "peer documentation")
        self.assertEqual(before["source_sha256"], v.identity(self.root)["source_sha256"])
        self.write("scripts/game.gd", "extends Node")
        self.assertNotEqual(before["source_sha256"], v.identity(self.root)["source_sha256"])

    def test_unsafe_scope_and_extra_commit_files_rejected(self):
        for path in ["../escape", "/absolute", "C:/drive", ".git/config", "scripts/*"]:
            with self.assertRaises(ValueError): v.safe_path(path)
        self.note()
        self.write("extra.txt", "accidental inclusion")
        self.commit()
        self.assertTrue(any("outside" in p for p in v.check_commit(self.root)))

    def test_stamp_integrity_and_actual_export_source_drift(self):
        self.note(); self.commit()
        self.write("ignored/engine.exe", "fixture executable")
        stamp = self.root / "ignored/stamp.json"
        import sys
        command = [sys.executable, str(Path(v.__file__)), "stamp", "--root", str(self.root), "--output", str(stamp), "--engine", str(self.root / "ignored/engine.exe")]
        result = subprocess.run(command, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stdout)
        saved = v.read_json(stamp)
        self.assertEqual(saved["dev"], 1)
        self.assertEqual(saved["commit"], self.git("rev-parse", "HEAD"))
        command[2] = "verify-stamp"
        self.assertEqual(subprocess.run(command, capture_output=True).returncode, 0)
        self.write("scripts/changed.gd", "changed during export")
        failed = subprocess.run(command, capture_output=True, text=True)
        self.assertIn("Source changed", failed.stdout)
        self.assertNotEqual(failed.returncode, 0)
        saved["dev"] = 900
        v.save(stamp, saved)
        self.assertIn("integrity mismatch", subprocess.run(command, capture_output=True, text=True).stdout)

    def test_declared_read_dependency_cannot_be_omitted(self):
        self.write("read.md", "dependency")
        path = self.note()
        note = v.read_json(self.root / path)
        note["read_paths"] = ["read.md"]
        v.save(self.root / path, note)
        self.assertTrue(any("missing owned/identity inputs" in p for p in v.check_note(self.root, path)))

    def test_reserved_note_cli_is_exact_atomic_and_history_is_utf8(self):
        import sys
        self.note(); self.commit()
        self.write("ignored/scope.json", json.dumps({"write_paths": ["future.md"], "read_paths": []}))
        reserved = "changes/" + "a" * 32 + ".json"
        command = [sys.executable, str(Path(v.__file__)), "note", "--root", str(self.root), "--scope", str(self.root / "ignored/scope.json"), "--note", reserved, "--summary", "Reserved change", "--category", "Maintenance"]
        result = subprocess.run(command, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertEqual(json.loads(result.stdout)["note"], reserved)
        original = (self.root / reserved).read_bytes()
        self.assertNotEqual(subprocess.run(command, capture_output=True).returncode, 0)
        self.assertEqual((self.root / reserved).read_bytes(), original)
        output = subprocess.run([sys.executable, str(Path(v.__file__)), "history", "--root", str(self.root)], capture_output=True, check=True).stdout.decode("utf-8")
        self.assertIn("## Dev 1 ·", output)


if __name__ == "__main__": unittest.main()

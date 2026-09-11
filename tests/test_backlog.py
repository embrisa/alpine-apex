"""Exercise real CLI/state/Git boundaries without touching the project queue."""
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timedelta, timezone
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

PROJECT = Path(__file__).resolve().parent.parent
HELPER = PROJECT / "scripts" / "backlog.py"
TEST_AREA = PROJECT / ".validation" / "backlog-tests"


class BacklogTests(unittest.TestCase):
    def setUp(self):
        TEST_AREA.mkdir(parents=True, exist_ok=True)
        self.temporary = tempfile.TemporaryDirectory(dir=TEST_AREA)
        self.base = Path(self.temporary.name).resolve()
        assert self.base.is_relative_to(TEST_AREA.resolve())
        self.root = self.base / "checkout"
        self.root.mkdir()
        self.run_git("init", "-b", "main")
        self.run_git("config", "user.name", "Backlog Fixture")
        self.run_git("config", "user.email", "backlog@example.invalid")
        self.run_git("config", "commit.gpgsign", "false")
        self.run_git("config", "core.autocrlf", "false")
        (self.root / ".gitignore").write_text("backlog/.runtime/\n", encoding="utf-8")
        self.commit()
        self.runtime = self.root / "backlog" / ".runtime"
        self.runtime.mkdir(parents=True)
        self.snapshot_path = self.runtime / "activity.json"
        self.receipt()

    def tearDown(self):
        assert self.base.is_relative_to(TEST_AREA.resolve())
        self.temporary.cleanup()

    def run_git(self, *args):
        proc = subprocess.run(["git", "-C", str(self.root), *args], text=True, capture_output=True)
        self.assertEqual(proc.returncode, 0, proc.stderr)
        return proc.stdout.strip()

    def commit(self):
        self.run_git("add", ".")
        self.run_git("commit", "-m", "Fixture checkpoint")

    def task(self, task_id="AA-test", status="ready", deps=None, priority="P2"):
        folder = self.root / "backlog" / ("archive" if status == "done" else "tasks")
        folder.mkdir(parents=True, exist_ok=True)
        data = dict(id=task_id, title="Fixture documentation task", status=status, priority=priority,
                    depends_on=deps or [], created="2026-09-11T12:00:00Z", updated="2026-09-11T12:00:00Z", source_thread=None)
        path = folder / (task_id + ".md")
        path.write_text("---\n" + "\n".join(f"{k}: {json.dumps(v)}" for k, v in data.items()) +
                        "\n---\n# Fixture\n\n## Open questions\n\nNone.\n\n## Completion record\n\nPending implementation.\n", encoding="utf-8")
        return path

    def receipt(self, threads=None, known=None, read_only=None, age=0, unavailable=False):
        data = {"observed_at": (datetime.now(timezone.utc) - timedelta(seconds=age)).isoformat(),
                "project_id": "fixture", "listing": {"threads": threads or [], "pinnedThreads": [],
                "unavailableHosts": ["local"] if unavailable else [], "unavailableSources": []},
                "known_threads": known or [], "read_only": read_only or []}
        self.snapshot_path.write_text(json.dumps(data), encoding="utf-8")

    def person(self, thread_id, status="active"):
        return dict(id=thread_id, projectId="fixture", cwd=str(self.root), kind="codex", title=thread_id, status=status)

    def call(self, action, *args, owner="manager", error=False):
        command = [sys.executable, str(HELPER), action, "--root", str(self.root), "--owner", owner, *args]
        if action in {"check", "claim", "prepare", "accept", "recover"}:
            command += ["--snapshot", str(self.snapshot_path)]
        proc = subprocess.run(command, text=True, capture_output=True)
        result = json.loads(proc.stdout)
        self.assertEqual(proc.returncode, 2 if error else 0, (proc.stdout, proc.stderr))
        return result

    def prepare(self):
        self.task()
        self.commit()
        self.assertEqual(self.call("claim")["status"], "ok")
        return self.call("prepare", "--task", "AA-test")["claim"]["token"]

    def record(self, token, outcome="blocked"):
        note = self.runtime / "completion.md"
        note.write_text("Verified fixture behavior. Human acceptance is not claimed.", encoding="utf-8")
        return self.call("record", "--token", token, "--outcome", outcome, "--record", str(note), owner="worker")

    def test_empty_and_wrapper(self):
        self.assertEqual(self.call("validate")["eligible"], [])
        proc = subprocess.run(["pwsh", "-NoProfile", "-File", str(PROJECT / "scripts" / "backlog.ps1"),
                               "validate", "--root", str(self.root)], text=True, capture_output=True)
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertEqual(json.loads(proc.stdout)["tasks"], [])

    def test_simultaneous_managers_only_one_claim(self):
        with ThreadPoolExecutor(max_workers=6) as pool:
            results = list(pool.map(lambda i: self.call("claim", owner=f"manager-{i}"), range(6)))
        self.assertEqual(sum(r["status"] == "ok" for r in results), 1)
        self.assertEqual(sum(r["status"] == "skipped" for r in results), 5)

    def test_busy_read_only_and_unavailable(self):
        self.receipt([self.person("manual")])
        self.assertEqual(self.call("check")["status"], "skipped")
        self.assertEqual(self.call("claim")["status"], "skipped")
        self.receipt([self.person("planner")], read_only=[dict(thread_id="planner", reason="Current turn is planning only", turn_id="turn-1")])
        self.assertEqual(self.call("check")["status"], "ok")
        self.receipt(unavailable=True)
        self.assertIn("unavailable", self.call("claim", error=True)["reason"])

    def test_unknown_status_and_dirty_checkout(self):
        self.receipt([self.person("manual", "unexpected")])
        self.assertEqual(self.call("check")["status"], "skipped")
        self.receipt()
        (self.root / "unrelated.gd.uid").write_text("uid://untouched", encoding="utf-8")
        self.assertIn("unfinished", self.call("claim")["reason"])
        self.assertTrue((self.root / "unrelated.gd.uid").exists())

    def test_stale_receipt(self):
        self.receipt(age=121)
        self.assertIn("stale", self.call("claim", error=True)["reason"])

    def test_ideas_are_never_loaded_as_executable_tasks(self):
        idea_folder = self.root / "backlog/ideas"
        idea_folder.mkdir(parents=True)
        (idea_folder / "IDEA-follow-up.md").write_text("# Proposed idea\nstatus: ready\n", encoding="utf-8")
        self.assertEqual(self.call("validate")["tasks"], [])
        self.assertEqual(self.call("validate")["eligible"], [])

    def test_dependencies_and_cycles(self):
        self.task("AA-prerequisite", "blocked")
        self.task("AA-dependent", deps=["AA-prerequisite"], priority="P0")
        self.task("AA-independent", priority="P2")
        self.assertEqual(self.call("validate")["eligible"], ["AA-independent"])
        self.task("AA-prerequisite", deps=["AA-dependent"])
        self.assertIn("cycle", self.call("validate", error=True)["reason"])

    def test_ready_questions_and_missing_dependency_rejected(self):
        path = self.task()
        path.write_text(path.read_text().replace("None.", "Choose the behavior."), encoding="utf-8")
        self.assertIn("open questions", self.call("validate", error=True)["reason"])
        self.task(deps=["AA-missing"])
        self.assertIn("Missing dependency", self.call("validate", error=True)["reason"])

    def test_changed_task_rejected_at_accept(self):
        token = self.prepare()
        path = self.root / "backlog/tasks/AA-test.md"
        path.write_text(path.read_text().replace("# Fixture", "# Changed scope"), encoding="utf-8")
        self.commit()
        self.assertIn("changed", self.call("accept", "--token", token, owner="worker", error=True)["reason"])

    def test_wrong_owner_token_and_second_worker(self):
        token = self.prepare()
        self.call("attach", "--token", token, "--worker", "worker")
        self.call("accept", "--token", "wrong", owner="worker", error=True)
        self.call("accept", "--token", token, owner="other-worker", error=True)
        self.call("accept", "--token", token, owner="worker")
        self.call("release", "--token", token, owner="manager", error=True)
        self.call("accept", "--token", token, owner="worker", error=True)

    def test_manual_starts_between_prepare_and_accept(self):
        token = self.prepare()
        self.receipt([self.person("manual")])
        result = self.call("accept", "--token", token, owner="worker")
        self.assertEqual(result["status"], "skipped")
        self.assertEqual(self.call("status")["tasks"][0]["status"], "ready")

    def test_uncertain_dispatch_and_stopped_child(self):
        token = self.prepare()
        self.call("release", error=True)
        self.receipt(known=[self.person("manager", "idle")])
        self.assertIn("Uncertain dispatch", self.call("recover", owner="next", error=True)["reason"])
        self.call("attach", "--token", token, "--worker", "worker")
        self.receipt(known=[self.person("manager", "idle"), self.person("worker", "idle")])
        self.call("recover", owner="next")
        self.assertEqual(self.call("status")["tasks"][0]["status"], "blocked")

    def test_ownership_never_expires_by_age_or_absence(self):
        self.call("claim")
        state_path = self.runtime / "state.json"
        state = json.loads(state_path.read_text())
        state["claim"]["created"] = "2000-01-01T00:00:00Z"
        state_path.write_text(json.dumps(state), encoding="utf-8")
        self.assertEqual(self.call("claim", owner="next")["status"], "skipped")
        self.call("recover", owner="next", error=True)
        self.receipt(known=[self.person("manager")])
        self.assertIn("still active", self.call("recover", owner="next", error=True)["reason"])
        self.receipt(known=[self.person("manager", "idle")])
        self.call("recover", owner="next")
        self.assertIsNone(self.call("status")["state"]["claim"])

    def test_worker_stopped_with_partial_edits_blocks_other_work(self):
        token = self.prepare()
        self.call("accept", "--token", token, owner="worker")
        (self.root / "partial.gd").write_text("unfinished", encoding="utf-8")
        self.receipt(known=[self.person("worker", "idle")])
        self.call("recover", owner="next")
        self.assertEqual(self.call("status")["tasks"][0]["status"], "blocked")
        self.assertEqual(self.call("claim", owner="next")["status"], "skipped")
        self.assertEqual((self.root / "partial.gd").read_text(), "unfinished")

    def test_fast_worker_finishes_before_manager_attach(self):
        token = self.prepare()
        self.call("accept", "--token", token, owner="worker")
        self.record(token)
        self.call("release", "--token", token, owner="worker")
        receipt = self.call("attach", "--token", token, "--worker", "worker")
        self.assertIn("already finished", receipt["reason"])
        self.assertIsNone(self.call("status")["state"]["claim"])

    def test_done_requires_committed_pushed_record(self):
        remote = self.base / "origin.git"
        proc = subprocess.run(["git", "init", "--bare", str(remote)], capture_output=True)
        self.assertEqual(proc.returncode, 0)
        self.run_git("remote", "add", "origin", str(remote))
        self.run_git("push", "-u", "origin", "main")
        token = self.prepare()
        self.call("accept", "--token", token, owner="worker")
        self.record(token, "done")
        self.call("release", "--token", token, owner="worker", error=True)
        self.commit()
        self.call("release", "--token", token, owner="worker", error=True)
        self.run_git("push", "origin", "main")
        self.call("release", "--token", token, owner="worker")
        self.assertTrue((self.root / "backlog/archive/AA-test.md").exists())
        self.assertEqual(self.call("status")["state"]["last_dispatch"]["outcome"], "done")

    def test_corrupt_state_is_not_replaced(self):
        path = self.runtime / "state.json"
        path.write_text('{"version": 99}', encoding="utf-8")
        self.call("claim", error=True)
        self.assertEqual(path.read_text(), '{"version": 99}')


if __name__ == "__main__":
    unittest.main(verbosity=2)

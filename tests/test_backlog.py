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

    def receipt(self, threads=None, known=None, read_only=None, age=0, unavailable=False, work=None, inspections=None):
        data = {"observed_at": (datetime.now(timezone.utc) - timedelta(seconds=age)).isoformat(),
                "project_id": "fixture", "listing": {"threads": threads or [], "pinnedThreads": [],
                "unavailableHosts": ["local"] if unavailable else [], "unavailableSources": []},
                "known_threads": known or [], "read_only": read_only or [],
                "work": work or [], "inspections": inspections or []}
        self.snapshot_path.write_text(json.dumps(data), encoding="utf-8")

    def person(self, thread_id, status="active"):
        return dict(id=thread_id, projectId="fixture", cwd=str(self.root), kind="codex", title=thread_id, status=status)

    def call(self, action, *args, owner="manager", error=False):
        command = [sys.executable, str(HELPER), action, "--root", str(self.root), "--owner", owner, *args]
        if action in {"check", "claim", "prepare", "accept", "scope", "recover"}:
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

    def test_versioned_worker_cannot_release_a_commit_without_note(self):
        token = self.prepare()
        self.call("accept", "--token", token, owner="worker")
        self.record(token, "done")
        config = self.root / "config/development_version.json"
        config.parent.mkdir()
        config.write_text(json.dumps({"schema": 1, "baseline_commit": self.run_git("rev-parse", "HEAD")}), encoding="utf-8")
        self.commit()
        remote = self.base / "version-origin.git"
        subprocess.run(["git", "init", "--bare", str(remote)], check=True, capture_output=True)
        self.run_git("remote", "add", "origin", str(remote))
        self.run_git("push", "-u", "origin", "main")
        result = self.call("release", "--token", token, owner="worker", error=True)
        self.assertIn("Incomplete development milestone", result["reason"])
        self.assertIn("exactly one note", result["reason"])

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
        self.assertEqual(self.call("check")["status"], "ok")
        self.assertEqual(self.call("claim")["status"], "ok")
        self.assertTrue((self.root / "unrelated.gd.uid").exists())

    def test_deleted_idea_and_unrelated_edits_allow_dispatch_and_pushed_completion(self):
        self.task()
        idea = self.root / "backlog/ideas/archive/IDEA-old.md"
        idea.parent.mkdir(parents=True)
        idea.write_text("Archived proposal", encoding="utf-8")
        staged = self.root / "staged file.txt"
        staged.write_text("original", encoding="utf-8")
        self.commit()
        idea.unlink()
        staged.write_text("staged user edit", encoding="utf-8")
        self.run_git("add", "staged file.txt")
        staged.write_text("unstaged user edit", encoding="utf-8")
        extra = self.root / "unrelated ü.gd.uid"
        extra.write_text("uid://preserve", encoding="utf-8")
        before = self.run_git("status", "--porcelain")
        self.call("claim")
        prepared = self.call("prepare", "--task", "AA-test")
        token = prepared["claim"]["token"]
        baseline = prepared["claim"]["dirty_baseline"]
        self.assertEqual(set(baseline), {"backlog/ideas/archive/IDEA-old.md", "staged file.txt", "unrelated ü.gd.uid"})
        self.assertEqual(self.call("accept", "--token", token, owner="worker")["status"], "ok")
        self.record(token, "done")
        self.assertIn("Uncommitted", self.call("release", "--token", token, owner="worker", error=True)["reason"])
        self.run_git("add", "backlog/tasks", "backlog/archive")
        # Commit only worker paths, preserving the user's staged and unstaged edit.
        self.run_git("commit", "--only", "-m", "Worker result", "--", "backlog/tasks/AA-test.md", "backlog/archive/AA-test.md")
        remote = self.base / "origin.git"
        subprocess.run(["git", "init", "--bare", str(remote)], check=True, capture_output=True)
        self.run_git("remote", "add", "origin", str(remote))
        self.run_git("push", "-u", "origin", "main")
        leftover = self.root / "worker-leftover.gd"
        leftover.write_text("unfinished worker output", encoding="utf-8")
        self.assertIn("worker-leftover.gd", self.call("release", "--token", token, owner="worker", error=True)["reason"])
        leftover.unlink()
        staged.write_text("accidental overwrite", encoding="utf-8")
        self.assertIn("staged file.txt", self.call("release", "--token", token, owner="worker", error=True)["reason"])
        staged.write_text("unstaged user edit", encoding="utf-8")
        self.assertEqual(self.call("release", "--token", token, owner="worker")["status"], "ok")
        self.assertEqual(self.run_git("status", "--porcelain"), before)
        self.assertEqual(staged.read_text(), "unstaged user edit")
        self.assertEqual(self.run_git("show", ":staged file.txt"), "staged user edit")
        self.assertFalse(idea.exists())

    def test_dirty_selected_task_can_be_skipped_for_another_task(self):
        path = self.task()
        self.task("AA-other")
        self.commit()
        path.write_text(path.read_text() + "\nUser edit\n", encoding="utf-8")
        self.call("claim")
        self.assertEqual(self.call("prepare", "--task", "AA-test")["status"], "skipped")
        self.assertEqual(self.call("prepare", "--task", "AA-other")["status"], "ok")

    def test_baseline_change_before_accept_preserves_reservation(self):
        token = self.prepare()
        (self.root / "new-edit.txt").write_text("Changed after prepare", encoding="utf-8")
        self.assertEqual(self.call("accept", "--token", token, owner="worker")["status"], "skipped")
        self.assertEqual(self.call("status")["state"]["claim"]["role"], "dispatch")

    def test_unfinished_git_operation_and_wrong_branch_block_claim(self):
        (self.root / ".git/MERGE_HEAD").write_text(self.run_git("rev-parse", "HEAD"), encoding="utf-8")
        self.assertIn("Git operation", self.call("claim")["reason"])
        (self.root / ".git/MERGE_HEAD").unlink()
        self.run_git("switch", "-c", "other")
        self.assertIn("not on main", self.call("claim")["reason"])

    def test_merge_conflict_blocks_claim(self):
        path = self.root / "conflict.txt"
        path.write_text("base\n", encoding="utf-8")
        self.commit()
        self.run_git("switch", "-c", "other")
        path.write_text("theirs\n", encoding="utf-8")
        self.commit()
        self.run_git("switch", "main")
        path.write_text("ours\n", encoding="utf-8")
        self.commit()
        proc = subprocess.run(["git", "-C", str(self.root), "merge", "other"], capture_output=True)
        self.assertNotEqual(proc.returncode, 0)
        self.assertTrue(self.run_git("ls-files", "--unmerged"))
        self.assertIn("merge conflicts", self.call("claim")["reason"])

    def test_existing_rename_is_preserved_during_accept(self):
        self.task()
        (self.root / "old name.txt").write_text("User content", encoding="utf-8")
        self.commit()
        self.run_git("mv", "old name.txt", "new name.txt")
        self.call("claim")
        claim = self.call("prepare", "--task", "AA-test")["claim"]
        self.assertEqual(set(claim["dirty_baseline"]), {"old name.txt", "new name.txt"})
        self.assertEqual(self.call("accept", "--token", claim["token"], owner="worker")["status"], "ok")
        self.assertEqual((self.root / "new name.txt").read_text(), "User content")

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

    def test_worker_stopped_with_partial_edits_does_not_block_independent_work(self):
        token = self.prepare()
        self.call("accept", "--token", token, owner="worker")
        (self.root / "partial.gd").write_text("unfinished", encoding="utf-8")
        self.receipt(known=[self.person("worker", "idle")])
        self.call("recover", owner="next")
        self.assertEqual(self.call("status")["tasks"][0]["status"], "blocked")
        self.assertEqual(self.call("claim", owner="next")["status"], "ok")
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

    def write_scope(self, name, writes=None, reads=None, fps=False):
        path = self.runtime / (name + "-scope.json")
        path.write_text(json.dumps(dict(write_paths=writes or [name + ".gd"],
                                      read_paths=reads or [], fps_sensitive=fps,
                                      reason="Inspected fixture owns independent code; no FPS measurement")), encoding="utf-8")
        return str(path)

    def parallel_receipt(self, extras=None):
        state = self.call("status")["state"]
        claims = ([state["claim"]] if state["claim"] else []) + state.get("workers", [])
        self.receipt([self.person(c["owner"]) for c in claims if c["role"] == "worker"] + (extras or []))

    def start_scoped(self, name, scope=None):
        scope = scope or self.write_scope(name)
        self.parallel_receipt()
        self.assertEqual(self.call("claim", "--scope", scope, owner="manager-" + name)["status"], "ok")
        result = self.call("prepare", "--task", "AA-" + name, "--scope", scope, owner="manager-" + name)
        self.assertEqual(result["status"], "ok", result)
        token = result["claim"]["token"]
        self.assertEqual(self.call("accept", "--token", token, owner="worker-" + name)["status"], "ok")
        return token

    def parallel_tasks(self, *names):
        for name in names:
            self.task("AA-" + name)
            (self.root / (name + ".gd")).write_text("base", encoding="utf-8")
        self.commit()

    def finish_scoped(self, name, token, outcome="blocked"):
        note = self.runtime / (name + "-completion.md")
        note.write_text("Fixture result", encoding="utf-8")
        self.call("record", "--token", token, "--outcome", outcome, "--record", str(note), owner="worker-" + name)

    def test_three_workers_complete_out_of_order_with_growing_dirty_peers(self):
        self.parallel_tasks("a", "b", "c")
        remote = self.base / "origin.git"
        subprocess.run(["git", "init", "--bare", str(remote)], check=True, capture_output=True)
        self.run_git("remote", "add", "origin", str(remote))
        self.run_git("push", "-u", "origin", "main")
        tokens = {name: self.start_scoped(name) for name in ("a", "b", "c")}
        state = self.call("status")["state"]
        self.assertEqual(len(state["workers"]), 2)
        for name in tokens:
            (self.root / (name + ".gd")).write_text("worker " + name, encoding="utf-8")
        # The middle worker can commit and release while both other workers edit.
        self.finish_scoped("b", tokens["b"], "done")
        paths = ["b.gd", "backlog/tasks/AA-b.md", "backlog/archive/AA-b.md"]
        self.run_git("add", "--", *paths)
        self.run_git("commit", "--only", "-m", "B delivered", "--", *paths)
        self.run_git("push", "origin", "main")
        self.assertEqual(self.call("release", "--token", tokens["b"], owner="worker-b")["status"], "ok")
        self.assertEqual((self.root / "a.gd").read_text(), "worker a")
        for name in ("c", "a"):
            self.finish_scoped(name, tokens[name])
            self.call("release", "--token", tokens[name], owner="worker-" + name)
        # A late attach finds the correct receipt even after two other completions.
        self.assertIn("already finished", self.call("attach", "--token", tokens["b"], "--worker", "worker-b", owner="manager-b")["reason"])
        state = self.call("status")["state"]
        self.assertIsNone(state["claim"])
        self.assertEqual(state["workers"], [])

    def test_peer_changes_during_dispatch_allowed_unknown_changes_rejected(self):
        self.parallel_tasks("a", "b")
        self.start_scoped("a")
        self.parallel_receipt()
        scope = self.write_scope("b")
        self.call("claim", "--scope", scope, owner="manager-b")
        token = self.call("prepare", "--task", "AA-b", "--scope", scope, owner="manager-b")["claim"]["token"]
        (self.root / "a.gd").write_text("concurrent edit", encoding="utf-8")
        unknown = self.root / "unknown.gd"
        unknown.write_text("do not touch", encoding="utf-8")
        self.assertEqual(self.call("accept", "--token", token, owner="worker-b")["status"], "skipped")
        unknown.unlink()  # fixture-owned injected condition only
        self.assertEqual(self.call("accept", "--token", token, owner="worker-b")["status"], "ok")

    def test_scope_conflict_skips_candidate_then_independent_task_starts(self):
        self.parallel_tasks("a", "b", "c")
        self.start_scoped("a")
        self.parallel_receipt()
        self.assertEqual(self.call("claim", owner="manager-b")["status"], "ok")
        conflict = self.write_scope("b", reads=["a.gd"])
        result = self.call("prepare", "--task", "AA-b", "--scope", conflict, owner="manager-b")
        self.assertEqual(result["status"], "skipped")
        self.assertIn("a.gd", result["reason"])
        independent = self.write_scope("c")
        self.assertEqual(self.call("prepare", "--task", "AA-c", "--scope", independent, owner="manager-b")["status"], "ok")

    def test_fps_exclusion_and_scope_upgrade_are_atomic(self):
        self.parallel_tasks("a", "b")
        token = self.start_scoped("a")
        self.parallel_receipt()
        sensitive = self.write_scope("b", fps=True)
        self.assertEqual(self.call("claim", "--scope", sensitive, owner="manager-b")["status"], "skipped")
        peer = self.start_scoped("b")
        self.parallel_receipt()
        upgrade = self.write_scope("a", fps=True)
        self.assertEqual(self.call("scope", "--token", token, "--scope", upgrade, owner="worker-a")["status"], "skipped")
        self.finish_scoped("b", peer)
        self.call("release", "--token", peer, owner="worker-b")
        self.parallel_receipt()
        self.assertEqual(self.call("scope", "--token", token, "--scope", upgrade, owner="worker-a")["status"], "ok")
        self.assertEqual(self.call("claim", owner="manager-next")["status"], "skipped")

    def test_dirty_overlap_and_unsafe_scopes_cannot_bypass_selection(self):
        self.parallel_tasks("a", "b")
        (self.root / "a.gd").write_text("unfinished user change", encoding="utf-8")
        self.call("claim")
        scope = self.write_scope("a")
        result = self.call("prepare", "--task", "AA-a", "--scope", scope)
        self.assertEqual(result["status"], "skipped")
        self.assertIn("a.gd", result["reason"])
        for path in ("../outside", "C:/outside", "scripts/*", ".git", "backlog/.runtime", "a/../b", "a\\b"):
            bad = self.write_scope("bad", writes=[path])
            self.call("prepare", "--task", "AA-b", "--scope", bad, error=True)
        self.assertEqual(self.call("prepare", "--task", "AA-b", "--scope", self.write_scope("b"))["status"], "ok")

    def test_manual_work_needs_current_inspection_and_disjoint_scope(self):
        self.parallel_tasks("a")
        manual = self.person("manual")
        spec = dict(write_paths=["manual.gd"], read_paths=[], fps_sensitive=False, reason="Current turn edits manual.gd only")
        work = [dict(thread_id="manual", turn_id="turn-now", scope=spec)]
        self.receipt([manual], work=work)
        self.call("claim", error=True)
        inspection = dict(thread=manual, turns=[dict(id="turn-now", status="inProgress")])
        self.receipt([manual], work=work, inspections=[inspection])
        self.assertEqual(self.call("claim")["status"], "ok")
        self.assertEqual(self.call("prepare", "--task", "AA-a", "--scope", self.write_scope("a"))["status"], "ok")
        self.receipt([self.person("manual", "systemError")], work=work, inspections=[inspection])
        token = self.call("status")["state"]["claim"]["token"]
        self.assertEqual(self.call("accept", "--token", token, owner="worker")["status"], "skipped")

    def test_unclassified_live_claim_can_be_classified_without_replacing_token(self):
        token = self.prepare()
        self.call("accept", "--token", token, owner="worker")
        worker = self.person("worker")
        self.receipt([worker])
        self.assertEqual(self.call("claim", owner="next")["status"], "skipped")
        spec = dict(write_paths=["original.gd"], read_paths=[], fps_sensitive=False, reason="Exact current turn has no timing workload")
        self.receipt([worker], work=[dict(thread_id="worker", turn_id="turn", scope=spec)],
                     inspections=[dict(thread=worker, turns=[dict(id="turn", status="inProgress")])])
        # An explicit scope update, rather than a manager weakening an existing
        # FPS reservation, is required once a scope was already declared.
        update = self.write_scope("original")
        self.assertEqual(self.call("scope", "--token", token, "--scope", update, owner="worker")["status"], "ok")
        self.assertEqual(self.call("claim", owner="next")["status"], "ok")
        self.assertEqual(self.call("status")["state"]["workers"][0]["token"], token)

    def test_existing_unscoped_worker_is_adopted_from_exact_inspection(self):
        token = self.prepare()
        self.call("accept", "--token", token, owner="worker")
        state_path = self.runtime / "state.json"
        state = json.loads(state_path.read_text())
        del state["claim"]["scope"]  # Exact shape of a worker started before this feature.
        state_path.write_text(json.dumps(state), encoding="utf-8")
        worker = self.person("worker")
        spec = dict(write_paths=["original.gd"], read_paths=[], fps_sensitive=False, reason="Current non-timing work inspected")
        self.receipt([worker], work=[dict(thread_id="worker", turn_id="turn", scope=spec)],
                     inspections=[dict(thread=worker, turns=[dict(id="turn", status="inProgress")])])
        self.assertEqual(self.call("claim", owner="next")["status"], "ok")
        adopted = self.call("status")["state"]["workers"][0]
        self.assertEqual(adopted["token"], token)
        self.assertIn("backlog/tasks/AA-test.md", adopted["scope"]["write_paths"])

    def test_scope_expansion_preserves_unrelated_dirty_files(self):
        self.parallel_tasks("a")
        token = self.start_scoped("a")
        (self.root / "new.gd").write_text("user edit", encoding="utf-8")
        scope = self.write_scope("a", writes=["a.gd", "new.gd"])
        self.parallel_receipt()
        result = self.call("scope", "--token", token, "--scope", scope, owner="worker-a")
        self.assertEqual(result["status"], "skipped")
        self.assertIn("new.gd", result["reason"])
        self.assertEqual((self.root / "new.gd").read_text(), "user edit")

    def test_dirty_read_input_can_dispatch_without_staging_or_changing_it(self):
        self.parallel_tasks("snow", "poles")
        pole = self.root / "poles.gd"
        pole.write_text("staged candidate", encoding="utf-8")
        self.run_git("add", "--", "poles.gd")
        pole.write_text("unfinished pole candidate", encoding="utf-8")
        index = self.run_git("ls-files", "--stage", "--", "poles.gd")
        token = self.start_scoped("snow", self.write_scope("snow", reads=["poles.gd"]))
        self.assertEqual(pole.read_text(), "unfinished pole candidate")
        self.assertEqual(self.run_git("ls-files", "--stage", "--", "poles.gd"), index)
        claim = self.call("status")["state"]["claim"]
        self.assertIn("poles.gd", claim["dirty_baseline"])
        self.assertEqual(claim["token"], token)

    def test_new_dirty_read_scope_can_complete_with_input_preserved(self):
        self.parallel_tasks("snow", "poles")
        remote = self.base / "origin.git"
        subprocess.run(["git", "init", "--bare", str(remote)], check=True, capture_output=True)
        self.run_git("remote", "add", "origin", str(remote))
        self.run_git("push", "-u", "origin", "main")
        token = self.start_scoped("snow")
        pole = self.root / "poles.gd"
        pole.write_text("preserved candidate", encoding="utf-8")
        self.run_git("add", "--", "poles.gd")
        index = self.run_git("ls-files", "--stage", "--", "poles.gd")
        scope = self.write_scope("snow", reads=["poles.gd"])
        self.parallel_receipt()
        result = self.call("scope", "--token", token, "--scope", scope, owner="worker-snow")
        self.assertEqual(result["status"], "ok", result)
        baseline = result["claim"]["dirty_baseline"]["poles.gd"]
        # Repeated scope changes cannot bless modifications to an existing input.
        pole.write_text("changed during validation", encoding="utf-8")
        self.parallel_receipt()
        result = self.call("scope", "--token", token, "--scope", scope, owner="worker-snow")
        self.assertEqual(result["claim"]["dirty_baseline"]["poles.gd"], baseline)
        self.finish_scoped("snow", token, "done")
        paths = ["backlog/tasks/AA-snow.md", "backlog/archive/AA-snow.md"]
        self.run_git("add", "--", *paths)
        self.run_git("commit", "--only", "-m", "Snow delivered", "--", *paths)
        self.run_git("push", "origin", "main")
        rejected = self.call("release", "--token", token, owner="worker-snow", error=True)
        self.assertIn("poles.gd", rejected["reason"])
        pole.write_text("preserved candidate", encoding="utf-8")  # Restore fixture-only injected change.
        self.assertEqual(self.call("release", "--token", token, owner="worker-snow")["status"], "ok")
        self.assertEqual(self.run_git("ls-files", "--stage", "--", "poles.gd"), index)
        self.assertEqual(self.run_git("show", "HEAD:poles.gd"), "base")

    def test_active_dirty_writer_still_blocks_read_scope(self):
        self.parallel_tasks("snow", "poles")
        token = self.start_scoped("snow")
        self.start_scoped("poles")
        (self.root / "poles.gd").write_text("active candidate", encoding="utf-8")
        self.parallel_receipt()
        result = self.call("scope", "--token", token, "--scope",
                           self.write_scope("snow", reads=["poles.gd"]), owner="worker-snow")
        self.assertEqual(result["status"], "skipped")
        self.assertIn("Reserved paths overlap", result["reason"])

    def test_incomplete_dirty_task_does_not_block_independent_queue(self):
        broken = self.task("AA-edited")
        self.task("AA-dependent", deps=["AA-edited"])
        self.task("AA-independent")
        self.commit()
        before = broken.read_text().replace("## Open questions\n\nNone.", "## User feedback\n\nA new request")
        broken.write_text(before, encoding="utf-8")
        self.call("validate", error=True)
        status = self.call("validate", "--preserve-dirty")
        self.assertEqual(status["eligible"], ["AA-independent"])
        self.assertIn("AA-edited", status["unavailable_tasks"])
        self.assertEqual(self.call("claim")["status"], "ok")
        token = self.call("prepare", "--task", "AA-independent")["claim"]["token"]
        self.assertEqual(self.call("accept", "--token", token, owner="worker")["status"], "ok")
        self.assertEqual(broken.read_text(), before)

    def test_deleted_dirty_prerequisite_is_unavailable_not_completed(self):
        original = self.task("AA-original", status="done")
        self.task("AA-dependent", deps=["AA-original"])
        self.task("AA-independent")
        self.commit()
        original.unlink()
        status = self.call("check")
        self.assertEqual(status["status"], "ok")
        self.assertEqual(status["eligible"], ["AA-independent"])
        self.assertIn("AA-original", status["unavailable_tasks"])

    def test_declared_fps_reservation_cannot_be_weakened_by_observation(self):
        self.parallel_tasks("a")
        self.start_scoped("a", self.write_scope("a", fps=True))
        worker = self.person("worker-a")
        spec = dict(write_paths=["a.gd"], read_paths=[], fps_sensitive=False, reason="Attempted weaker classification")
        self.receipt([worker], work=[dict(thread_id="worker-a", turn_id="turn", scope=spec)],
                     inspections=[dict(thread=worker, turns=[dict(id="turn", status="inProgress")])])
        self.assertEqual(self.call("claim", owner="next")["status"], "skipped")

    def test_recover_one_stopped_worker_preserves_other_owners(self):
        self.parallel_tasks("a", "b")
        first = self.start_scoped("a")
        second = self.start_scoped("b")
        self.receipt([self.person("worker-a", "idle"), self.person("worker-b")])
        self.call("recover", owner="manager-next", error=True)
        self.assertEqual(self.call("recover", "--token", first, owner="manager-next")["status"], "ok")
        state = self.call("status")["state"]
        self.assertEqual(state["claim"]["token"], second)
        self.assertEqual(state["workers"], [])


if __name__ == "__main__":
    unittest.main(verbosity=2)

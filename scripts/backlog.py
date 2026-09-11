"""Local backlog records and scheduled-worker ownership. Python 3.10+, stdlib only.

App task inspection/creation stays in Codex's native tools. This helper consumes
fresh inspection receipts and never creates, resumes, or terminates a Codex task.
"""
from __future__ import annotations

import argparse
from contextlib import contextmanager
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import time
import uuid

STATUSES = {"draft", "ready", "in_progress", "blocked", "done", "retired"}
FIELDS = {"id", "title", "status", "priority", "depends_on", "created", "updated", "source_thread"}
TERMINAL = {"done", "blocked", "retired"}


def now():
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def timestamp(value):
    result = datetime.fromisoformat(value.replace("Z", "+00:00"))
    if result.tzinfo is None:
        raise ValueError("Timestamps must include a timezone")
    return result


def atomic_write(path, text):
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(prefix=".backlog-", dir=path.parent)
    try:
        with os.fdopen(fd, "w", encoding="utf-8", newline="\n") as stream:
            stream.write(text)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


@contextmanager
def locked(runtime):
    runtime.mkdir(parents=True, exist_ok=True)
    with (runtime / "mutex").open("a+b") as stream:
        stream.seek(0, os.SEEK_END)
        if not stream.tell():
            stream.write(b"0")
            stream.flush()
        deadline = time.monotonic() + 3
        while True:
            try:
                stream.seek(0)
                if os.name == "nt":
                    import msvcrt
                    msvcrt.locking(stream.fileno(), msvcrt.LK_NBLCK, 1)
                else:
                    import fcntl
                    fcntl.flock(stream, fcntl.LOCK_EX | fcntl.LOCK_NB)
                break
            except OSError:
                if time.monotonic() >= deadline:
                    raise ValueError("Another backlog command owns the state mutex")
                time.sleep(0.05)
        try:
            yield
        finally:
            stream.seek(0)
            if os.name == "nt":
                msvcrt.locking(stream.fileno(), msvcrt.LK_UNLCK, 1)
            else:
                fcntl.flock(stream, fcntl.LOCK_UN)


def parse_task(path):
    text = path.read_text(encoding="utf-8")
    match = re.match(r"\A---\n(.*?)\n---\n(.*)\Z", text, re.S)
    if not match:
        raise ValueError(f"{path.name}: missing YAML frontmatter")
    metadata = {}
    # Deliberately restricted YAML: one key per line, JSON strings/lists/null,
    # and bare status/priority tokens. No third-party runtime dependency.
    for line in match[1].splitlines():
        item = re.fullmatch(r"([a-z_]+):\s*(.+)", line)
        if not item or item[1] not in FIELDS or item[1] in metadata:
            raise ValueError(f"{path.name}: unsupported/duplicate metadata: {line}")
        key, raw = item.groups()
        if key in {"status", "priority"} and not raw.startswith('"'):
            value = raw
        else:
            value = json.loads(raw)
        metadata[key] = value
    if set(metadata) != FIELDS:
        raise ValueError(f"{path.name}: expected metadata fields {sorted(FIELDS)}")
    task_id = metadata["id"]
    if not isinstance(task_id, str) or not re.fullmatch(r"AA-[A-Za-z0-9-]+", task_id) or path.stem != task_id:
        raise ValueError(f"{path.name}: task ID must match its safe filename")
    if metadata["status"] not in STATUSES or metadata["priority"] not in {"P0", "P1", "P2", "P3"}:
        raise ValueError(f"{task_id}: invalid status/priority")
    if not isinstance(metadata["title"], str) or not metadata["title"].strip():
        raise ValueError(f"{task_id}: missing title")
    deps = metadata["depends_on"]
    if not isinstance(deps, list) or any(not isinstance(x, str) for x in deps) or len(set(deps)) != len(deps):
        raise ValueError(f"{task_id}: dependencies must be unique task IDs")
    for key in ("created", "updated"):
        timestamp(metadata[key])
    if metadata["source_thread"] is not None and not isinstance(metadata["source_thread"], str):
        raise ValueError(f"{task_id}: source_thread must be a string or null")
    body = match[2]
    if metadata["status"] == "ready":
        questions = re.search(r"^## Open questions\s*\n(.*?)(?=^## |\Z)", body, re.M | re.S)
        if not questions or questions[1].strip().rstrip(".").lower() != "none":
            raise ValueError(f"{task_id}: ready tasks must explicitly have no open questions")
        if "REPLACE_WITH_" in text:
            raise ValueError(f"{task_id}: unfilled template")
    return {**metadata, "path": path, "body": body, "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}


def load_tasks(root):
    tasks = {}
    for folder in ("tasks", "archive"):
        for path in sorted((root / "backlog" / folder).glob("*.md")):
            if path.is_symlink() or not path.resolve().is_relative_to(root / "backlog"):
                raise ValueError("Task files must remain inside backlog")
            task = parse_task(path)
            if task["id"] in tasks:
                raise ValueError(f"Duplicate task ID: {task['id']}")
            if folder == "archive" and task["status"] not in {"done", "retired"}:
                raise ValueError(f"{path.name}: nonterminal task in archive")
            tasks[task["id"]] = task
    visited, pending = set(), set()

    def visit(task_id):
        if task_id not in tasks:
            raise ValueError(f"Missing dependency: {task_id}")
        if task_id in pending:
            raise ValueError(f"Dependency cycle: {task_id}")
        if task_id in visited:
            return
        pending.add(task_id)
        for dependency in tasks[task_id]["depends_on"]:
            visit(dependency)
        pending.remove(task_id)
        visited.add(task_id)

    for task_id in tasks:
        visit(task_id)
    return tasks


def eligible(tasks):
    return sorted((t for t in tasks.values() if t["status"] == "ready" and
                   all(tasks[d]["status"] == "done" for d in t["depends_on"])),
                  key=lambda t: (t["priority"], t["created"], t["id"]))


def git(root, *args):
    result = subprocess.run(["git", "-C", str(root), *args], capture_output=True, text=True, timeout=30)
    if result.returncode:
        raise ValueError(result.stderr.strip() or "Git command failed")
    return result.stdout.strip()


def workspace_problem(root):
    if Path(git(root, "rev-parse", "--show-toplevel")).resolve() != root:
        raise ValueError("Root must be the exact Git checkout, not a subdirectory")
    if git(root, "branch", "--show-current") != "main":
        return "Checkout is not on main"
    dirty = git(root, "status", "--porcelain", "--untracked-files=all")
    if dirty:
        return "Checkout has unfinished changes:\n" + dirty
    return None


def pushed(root):
    return git(root, "rev-parse", "HEAD") == git(root, "rev-parse", "@{upstream}")


def snapshot(path):
    if not path:
        raise ValueError("A fresh native-app activity snapshot is required")
    data = json.loads(Path(path).read_text(encoding="utf-8"))
    age = (datetime.now(timezone.utc) - timestamp(data["observed_at"])).total_seconds()
    if not -5 <= age <= 120:
        raise ValueError("Activity snapshot is stale; refresh the native app inspection")
    listing = data["listing"]
    for key in ("threads", "pinnedThreads", "unavailableHosts", "unavailableSources"):
        if not isinstance(listing.get(key), list):
            raise ValueError(f"Incomplete native task listing: {key}")
    if listing["unavailableHosts"] or listing["unavailableSources"]:
        raise ValueError("Native task activity is unavailable; do not dispatch")
    # Exact reads resolve owners outside the recency-limited list. They must be
    # read in this same inspection, not recycled from an older snapshot.
    threads = {t["id"]: t for t in listing["pinnedThreads"] + listing["threads"]}
    for t in data.get("known_threads", []):
        threads[t["id"]] = t
    data["all_threads"] = threads
    return data


def thread_status(thread):
    status = thread.get("status")
    return status.get("type") if isinstance(status, dict) else status


def activity_problem(root, data, exempt):
    read_only = set()
    for item in data.get("read_only", []):
        if not item.get("reason") or not item.get("turn_id"):
            raise ValueError("Read-only exemptions need current-turn evidence")
        read_only.add(item["thread_id"])
    for t in data["all_threads"].values():
        if t["id"] in exempt or t["id"] in read_only:
            continue
        same_project = data.get("project_id") and t.get("projectId") == data["project_id"]
        cwd = t.get("cwd")
        same_path = cwd and Path(cwd).resolve().is_relative_to(root)
        if not (same_project or same_path):
            continue
        if thread_status(t) not in {"idle", "notLoaded"}:
            return f"Project task is active or uncertain: {t.get('title', t['id'])} ({t['id']})"
    return None


def stopped(data, thread_id):
    thread = data["all_threads"].get(thread_id)
    if not thread:
        raise ValueError(f"Read owner {thread_id} explicitly; absence from the recent list is not proof it stopped")
    if thread_status(thread) not in {"idle", "notLoaded", "systemError"}:
        raise ValueError("Recorded owner is still active; its claim cannot be recovered")


def save_task(root, task, outcome, record):
    metadata = {key: task[key] for key in FIELDS}
    metadata["status"], metadata["updated"] = outcome, now()
    order = ("id", "title", "status", "priority", "depends_on", "created", "updated", "source_thread")
    header = "\n".join(f"{key}: {json.dumps(metadata[key], ensure_ascii=False)}" for key in order)
    body = re.sub(r"^## Completion record\s*\n.*\Z", "", task["body"], flags=re.M | re.S).rstrip()
    body += "\n\n## Completion record\n\n" + record.strip() + "\n"
    destination = root / "backlog" / ("archive" if outcome in {"done", "retired"} else "tasks") / task["path"].name
    if destination != task["path"] and destination.exists():
        raise ValueError("Archive/task destination already exists")
    atomic_write(task["path"], "---\n" + header + "\n---\n" + body)
    if destination != task["path"]:
        destination.parent.mkdir(parents=True, exist_ok=True)
        os.replace(task["path"], destination)
    return destination


def operate(args):
    root = Path(args.root).resolve()
    runtime = root / "backlog" / ".runtime"
    state_path = runtime / "state.json"
    with locked(runtime):
        state = json.loads(state_path.read_text(encoding="utf-8")) if state_path.exists() else {
            "version": 1, "revision": 0, "claim": None, "last_dispatch": None}
        if state.get("version") != 1 or not {"revision", "claim", "last_dispatch"} <= state.keys():
            raise ValueError("Unknown/corrupt state; preserve it and investigate")
        claim = state["claim"]
        tasks = load_tasks(root)

        def save():
            state["revision"] += 1
            atomic_write(state_path, json.dumps(state, indent=2) + "\n")

        def output(status="ok", **extra):
            return {"status": status, **extra}

        def owner(role=None):
            if not claim or claim["owner"] != args.owner or (role and claim["role"] != role):
                raise ValueError("Caller does not own the required claim")

        def token():
            if not claim or not args.token or claim.get("token") != args.token:
                raise ValueError("Dispatch token does not match the current claim")

        def gate(data, exempt):
            return activity_problem(root, data, exempt) or workspace_problem(root)

        if args.action in {"status", "validate", "check"}:
            result = output(state=state, tasks=[{k: t[k] for k in ("id", "title", "status", "priority", "depends_on")}
                                               for t in tasks.values()], eligible=[t["id"] for t in eligible(tasks)])
            if args.action == "check":
                data = snapshot(args.snapshot)
                reason = gate(data, {args.owner})
                if claim:
                    reason = reason or "Scheduled-work claim is occupied"
                if reason:
                    result.update(status="skipped", reason=reason)
            return result
        if not args.owner:
            raise ValueError("--owner must be the current Codex thread ID")

        if args.action == "claim":
            data = snapshot(args.snapshot)
            if claim:
                return output("skipped", reason="Scheduled-work claim is occupied", claim=claim)
            reason = gate(data, {args.owner})
            if reason:
                return output("skipped", reason=reason)
            state["claim"] = {"role": "manager", "owner": args.owner, "manager": args.owner, "created": now()}
            save()
            return output(claim=state["claim"])

        if args.action == "prepare":
            owner("manager")
            data = snapshot(args.snapshot)
            reason = gate(data, {args.owner})
            if reason:
                return output("skipped", reason=reason)
            if args.task not in {t["id"] for t in eligible(tasks)}:
                raise ValueError("Task is not ready with completed dependencies")
            task = tasks[args.task]
            claim.update(role="dispatch", token=str(uuid.uuid4()), task=args.task,
                         task_sha256=task["sha256"], worker=None, prepared=now())
            save()
            return output(claim=claim)

        if args.action == "attach":
            previous = state.get("last_dispatch")
            if not claim and previous and previous.get("token") == args.token and previous.get("worker") == args.worker and previous.get("manager") == args.owner:
                return output(reason="Worker already finished; receipt preserved", receipt=previous)
            token()
            if claim["manager"] != args.owner or not args.worker or (claim.get("worker") and claim["worker"] != args.worker):
                raise ValueError("Only the dispatching manager may attach the matching worker")
            claim["worker"] = args.worker
            save()
            return output(claim=claim)

        if args.action == "accept":
            token()
            if claim["role"] != "dispatch" or (claim.get("worker") and claim["worker"] != args.owner):
                raise ValueError("Dispatch is already accepted or assigned to another worker")
            data = snapshot(args.snapshot)
            reason = gate(data, {args.owner, claim["manager"]})
            if reason:
                return output("skipped", reason=reason)
            task = tasks[claim["task"]]
            if task["sha256"] != claim["task_sha256"] or task["id"] not in {t["id"] for t in eligible(tasks)}:
                raise ValueError("Task changed after dispatch; do not implement stale instructions")
            # Persist ownership before touching the task, so a crash still leaves
            # an identifiable worker. Recovery never depends on elapsed time.
            claim.update(role="worker", owner=args.owner, worker=args.owner, accepted=now())
            save()
            path = save_task(root, task, "in_progress", f"Worker `{args.owner}` accepted dispatch `{args.token}` at {now()}.")
            return output(claim=claim, task_path=str(path))

        if args.action == "record":
            owner("worker")
            token()
            if args.outcome not in {"done", "blocked"} or not args.record:
                raise ValueError("Record requires done/blocked and --record pointing to a completion note")
            note = Path(args.record).read_text(encoding="utf-8").strip()
            if not note:
                raise ValueError("Completion note cannot be empty")
            path = save_task(root, tasks[claim["task"]], args.outcome, note + f"\n\nWorker: `{args.owner}`. Dispatch: `{args.token}`.")
            claim["outcome"] = args.outcome
            save()
            return output(task_path=str(path), outcome=args.outcome, next="Commit/push the task record, then release ownership")

        if args.action == "release":
            owner()
            if claim["role"] == "manager":
                state["claim"] = None
            elif claim["role"] == "worker":
                token()
                task = tasks[claim["task"]]
                if task["status"] not in TERMINAL:
                    raise ValueError("Record completion or a blocker before releasing a worker")
                if task["status"] == "done" and (workspace_problem(root) or not pushed(root)):
                    raise ValueError("Done requires a clean checkout and HEAD equal to its pushed upstream")
                state["last_dispatch"] = {**claim, "outcome": task["status"], "released": now(), "head": git(root, "rev-parse", "HEAD")}
                state["claim"] = None
            else:
                raise ValueError("Prepared dispatch cannot be released blindly; reconcile the worker first")
            save()
            return output(state=state)

        if args.action == "recover":
            data = snapshot(args.snapshot)
            if not claim:
                return output(reason="No claim to recover")
            problem = activity_problem(root, data, {args.owner, claim["owner"], claim.get("worker")})
            if problem:
                return output("skipped", reason=problem)
            stopped(data, claim["owner"])
            if claim["role"] == "dispatch":
                if not claim.get("worker"):
                    raise ValueError("Uncertain dispatch: locate the child by token and attach it; never create a duplicate")
                stopped(data, claim["worker"])
            if claim.get("task"):
                task = tasks[claim["task"]]
                completed = task["status"] == "done" and not workspace_problem(root) and pushed(root)
                if not completed:
                    old_record = re.search(r"^## Completion record\s*\n(.*)\Z", task["body"], re.M | re.S)
                    note = (old_record[1].strip() + "\n\n" if old_record else "")
                    note += f"Recovery {now()}: the recorded worker stopped before verified delivery. Investigate before any explicit retry; preserve unfinished changes."
                    save_task(root, task, "blocked", note)
                state["last_dispatch"] = {**claim, "outcome": "done" if completed else "blocked", "recovered": now()}
            state["claim"] = None
            save()
            return output(state=state, next="Commit/push any recovery record before another dispatch; preserve unrelated edits")
        raise ValueError("Unknown action")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("status", "validate", "check", "claim", "prepare", "attach", "accept", "record", "release", "recover"))
    parser.add_argument("--root", default=str(Path(__file__).resolve().parent.parent))
    parser.add_argument("--owner", default=os.environ.get("CODEX_THREAD_ID"))
    parser.add_argument("--snapshot")
    parser.add_argument("--task")
    parser.add_argument("--token")
    parser.add_argument("--worker")
    parser.add_argument("--record")
    parser.add_argument("--outcome", choices=("done", "blocked"))
    args = parser.parse_args()
    try:
        result = operate(args)
        print(json.dumps(result, ensure_ascii=False, indent=2))
        return 0
    except (ValueError, KeyError, TypeError, OSError, subprocess.SubprocessError) as error:
        print(json.dumps({"status": "error", "reason": str(error)}, ensure_ascii=False))
        return 2


if __name__ == "__main__":
    sys.exit(main())

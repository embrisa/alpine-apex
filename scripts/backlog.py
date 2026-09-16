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
TASK_FOLDERS = {
    "tasks": {"draft", "ready", "in_progress"},
    "completed": {"done"},
    "blocked": {"blocked"},
    "abandoned": {"retired"},
}


def task_folder(status):
    return next(folder for folder, statuses in TASK_FOLDERS.items() if status in statuses)


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


def load_tasks(root, dirty_paths=(), unavailable=None):
    tasks = {}
    unavailable = unavailable if unavailable is not None else {}
    for relative in dirty_paths:
        path = root / relative
        if (path.parent in {root / "backlog" / folder for folder in TASK_FOLDERS}
                and path.suffix == ".md" and not path.exists()):
            unavailable[path.stem] = f"Uncommitted task deletion: {relative}"
    for folder, statuses in TASK_FOLDERS.items():
        for path in sorted((root / "backlog" / folder).glob("*.md")):
            if path.is_symlink() or not path.resolve().is_relative_to(root / "backlog"):
                raise ValueError("Task files must remain inside backlog")
            try:
                task = parse_task(path)
                if task["status"] not in statuses:
                    raise ValueError(f"{path.name}: {task['status']} task belongs in backlog/{task_folder(task['status'])}")
            except (ValueError, TypeError, KeyError) as error:
                if path.relative_to(root).as_posix() not in dirty_paths:
                    raise
                unavailable[path.stem] = f"Preserved incomplete task edit: {error}"
                continue
            if task["id"] in tasks:
                raise ValueError(f"Duplicate task ID: {task['id']}")
            tasks[task["id"]] = task
            # A valid moved record is available even while its old path is an
            # uncommitted deletion. Missing/malformed records remain excluded.
            unavailable.pop(task["id"], None)
    visited, pending = set(), set()

    def visit(task_id):
        if task_id in unavailable and task_id not in tasks:
            return
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
                   all(d in tasks and tasks[d]["status"] == "done" for d in t["depends_on"])),
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
    if git(root, "ls-files", "--unmerged"):
        return "Checkout has unresolved merge conflicts"
    for marker in ("MERGE_HEAD", "rebase-merge", "rebase-apply", "CHERRY_PICK_HEAD", "REVERT_HEAD"):
        path = Path(git(root, "rev-parse", "--git-path", marker))
        if (path if path.is_absolute() else root / path).exists():
            return f"Checkout has an unfinished Git operation: {marker}"
    return None


def dirty_snapshot(root):
    """Fingerprint existing edits without staging, restoring or reading ignored outputs.

    NUL records and disabled rename detection keep arbitrary filenames unambiguous.
    Index identities also catch staged-only changes while working bytes stay equal.
    """
    # Preserve the leading status column; git() normally strips whitespace.
    records = subprocess.run(["git", "-C", str(root), "status", "--porcelain=v1", "-z",
                              "--no-renames", "--untracked-files=all"],
                             capture_output=True, check=True, timeout=30).stdout.decode("utf-8")
    index = {}
    for entry in git(root, "ls-files", "--stage", "-z").split("\0"):
        if entry:
            identity, path = entry.split("\t", 1)
            index.setdefault(path, []).append(identity)
    result = {}
    for entry in records.split("\0"):
        if not entry:
            continue
        path = entry[3:]
        target = root / path
        if target.is_symlink():
            content = os.readlink(target).encode("utf-8")
        elif target.is_file():
            digest = hashlib.sha256()
            with target.open("rb") as stream:
                for chunk in iter(lambda: stream.read(1024 * 1024), b""):
                    digest.update(chunk)
            result[path] = {"status": entry[:2], "index": index.get(path), "worktree": digest.hexdigest()}
            continue
        else:
            content = b"missing" if not target.exists() else b"directory"
        result[path] = {"status": entry[:2], "index": index.get(path),
                        "worktree": hashlib.sha256(content).hexdigest()}
    return result


def delivery_problem(root, claim, task, peer_paths=()):
    problem = workspace_problem(root)
    if problem:
        return problem
    baseline = claim.get("dirty_baseline", {})
    dirty = dirty_snapshot(root)
    changed = [path for path, value in dirty.items()
               if baseline.get(path) != value and not covered(path, peer_paths)]
    # The terminal record must always be committed, even if it was present before.
    task_path = task["path"].relative_to(root).as_posix()
    if task_path in dirty and task_path not in changed:
        changed.append(task_path)
    if changed:
        return "Uncommitted changes since dispatch:\n" + "\n".join(changed)
    if not pushed(root):
        return "HEAD must equal its pushed upstream"
    if (root / "config/development_version.json").is_file():
        import versioning
        base = claim.get("version_base")
        commits = git(root, "rev-list", "--first-parent", f"{base}..HEAD").splitlines() if base else [git(root, "log", "-1", "--format=%H", "--", task_path)]
        owned = claim.get("scope", {}).get("write_paths", []) + [task_path]
        for commit in commits:
            if not commit or not any(covered(path, owned) for path in versioning.changed_paths(root, commit)):
                continue
            errors = versioning.check_commit(root, commit)
            if errors:
                return "Incomplete development milestone " + commit + ": " + "; ".join(errors)
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


def scope_spec(root, value=None, task=None):
    # Missing classification remains exclusive, including already-running work.
    if value is None:
        value = {"write_paths": [], "read_paths": [], "fps_sensitive": True,
                 "reason": "Unclassified work requires exclusive execution"}
    if (not isinstance(value, dict) or type(value.get("fps_sensitive")) is not bool
            or not isinstance(value.get("reason"), str) or not value["reason"].strip()):
        raise ValueError("Scope requires fps_sensitive boolean and an evidence-based reason")
    result = {"fps_sensitive": value["fps_sensitive"], "reason": value["reason"]}
    for key in ("write_paths", "read_paths"):
        paths = value.get(key, [])
        if not isinstance(paths, list):
            raise ValueError("Scope paths must be lists")
        normalized = []
        for path in paths:
            if not isinstance(path, str) or not path or "\\" in path:
                raise ValueError("Use literal repository-relative scope paths with forward slashes")
            clean = path.rstrip("/")
            if (not clean or any(p in {"", ".", ".."} for p in clean.split("/"))
                    or any(c in path for c in ":*?[]") or Path(path).is_absolute()
                    or not (root / clean).resolve().is_relative_to(root)
                    or clean.casefold().startswith((".git/", "backlog/.runtime/"))
                    or clean.casefold() in {".git", "backlog/.runtime"}):
                raise ValueError("Unsafe or non-literal scope path: " + path)
            normalized.append(clean)
        result[key] = sorted(set(normalized))
    if task:
        result["write_paths"] = sorted(set(result["write_paths"] + [
            f"backlog/{folder}/{task}.md" for folder in TASK_FOLDERS]))
    return result


def covered(path, paths):
    path = path.replace("\\", "/").casefold()
    return any(path == p.casefold() or path.startswith(p.casefold() + "/") for p in paths)


def scope_conflict(first, second):
    if first["fps_sensitive"] or second["fps_sensitive"]:
        return "FPS-sensitive or unclassified work requires exclusive execution"
    for writes, other in ((first["write_paths"], second["write_paths"] + second["read_paths"]),
                          (second["write_paths"], first["read_paths"])):
        for path in writes:
            for peer in other:
                if covered(path, [peer]) or covered(peer, [path]):
                    return f"Reserved paths overlap: {path} / {peer}"
    return None


def observed_work(root, data):
    """Manual/unclassified work needs a real current-turn inspection, not a title guess."""
    inspections = {item["thread"]["id"]: item for item in data.get("inspections", [])}
    result = {}
    for item in data.get("work", []):
        inspection = inspections.get(item.get("thread_id"))
        turns = inspection.get("turns", []) if inspection else []
        if (not turns or item.get("turn_id") != turns[0].get("id")
                or turns[0].get("status") != "inProgress"
                or thread_status(inspection["thread"]) != "active"):
            raise ValueError("Work classification requires an exact current active-turn inspection")
        if item["thread_id"] in result:
            raise ValueError("Duplicate work classification")
        result[item["thread_id"]] = scope_spec(root, item.get("scope"))
    return result


def activity_problem(root, data, exempt, candidate=None, reservations=()):
    candidate = scope_spec(root, candidate)
    observed = observed_work(root, data)
    reserved = {c.get("worker") or c["owner"]: c for c in reservations}
    read_only = set()
    for item in data.get("read_only", []):
        if not item.get("reason") or not item.get("turn_id"):
            raise ValueError("Read-only exemptions need current-turn evidence")
        read_only.add(item["thread_id"])
    for t in data["all_threads"].values():
        if t["id"] in exempt:
            continue
        same_project = data.get("project_id") and t.get("projectId") == data["project_id"]
        cwd = t.get("cwd")
        same_path = cwd and Path(cwd).resolve().is_relative_to(root)
        if not (same_project or same_path):
            continue
        if thread_status(t) in {"idle", "notLoaded"}:
            continue
        if thread_status(t) != "active":
            return f"Project task is active or uncertain: {t.get('title', t['id'])} ({t['id']})"
        reservation = reserved.get(t["id"])
        if t["id"] in read_only and not reservation and not candidate["fps_sensitive"]:
            continue
        peer = reservation.get("scope") if reservation else None
        peer = peer or observed.get(t["id"])
        if peer is None:
            return f"Inspect unclassified active work: {t.get('title', t['id'])} ({t['id']})"
        problem = scope_conflict(candidate, scope_spec(root, peer))
        if problem:
            return f"{problem}: {t.get('title', t['id'])} ({t['id']})"
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
    destination = root / "backlog" / task_folder(outcome) / task["path"].name
    if destination != task["path"] and destination.exists():
        raise ValueError("Task destination already exists")
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
        workers = state.setdefault("workers", [])
        receipts = state.setdefault("receipts", {})
        if not isinstance(workers, list) or not isinstance(receipts, dict):
            raise ValueError("Corrupt ownership collections; preserve state")
        claims = ([state["claim"]] if state["claim"] else []) + workers
        claim = next((c for c in claims if (c.get("token") == args.token if args.token
                     else c["owner"] == args.owner)), None)
        # Recovery without a token is unambiguous only for one outstanding claim.
        if args.action == "recover" and not args.token and not claim:
            if len(claims) > 1:
                raise ValueError("Multiple reservations: recover the exact --token")
            claim = claims[0] if claims else None
        unavailable = {}
        dirty_paths = dirty_snapshot(root) if args.action != "validate" or args.preserve_dirty else ()
        tasks = load_tasks(root, dirty_paths, unavailable)

        def remove_claim():
            if state["claim"] is claim:
                state["claim"] = None
            else:
                workers.remove(claim)

        def remember(receipt):
            state["last_dispatch"] = receipt
            receipts[receipt["token"]] = receipt

        def other_claims():
            return [c for c in claims if c is not claim]

        def peer_paths(data=None):
            # Persist the identities/scopes observed at prepare so peers may finish
            # or commit independently without making their leftovers our output.
            peers = dict(claim.get("peers", {})) if claim else {}
            for other in other_claims():
                if other.get("scope"):
                    peers[other.get("token", other["owner"])] = other["scope"]
            if data:
                for thread_id, spec in observed_work(root, data).items():
                    if thread_id != args.owner:
                        peers[thread_id] = spec
            own = scope_spec(root, claim.get("scope") if claim else None)
            return [p for spec in peers.values()
                    if not scope_conflict({**own, "fps_sensitive": False}, {**spec, "fps_sensitive": False})
                    for p in spec["write_paths"]]

        def candidate_scope(task_id=None):
            if args.scope:
                return scope_spec(root, json.loads(Path(args.scope).read_text(encoding="utf-8")), task_id)
            if claim and claim.get("scope"):
                return scope_spec(root, claim["scope"], task_id)
            if args.action in {"claim", "check"}:
                return scope_spec(root, {"write_paths": [], "read_paths": [], "fps_sensitive": False,
                                         "reason": "Manager inspection; candidate classified at prepare"})
            return scope_spec(root, task=task_id)

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

        def gate(data, exempt, spec):
            problem = workspace_problem(root) or activity_problem(root, data, exempt, spec, claims)
            if problem:
                return problem
            for other in other_claims():
                if other["role"] != "worker":
                    return "Manager or uncertain dispatch reservation is occupied"
                thread = data["all_threads"].get(other["owner"])
                if not thread:
                    return "Inspect recorded worker outside listing: " + other["owner"]
                if thread_status(thread) != "active":
                    return "Reconcile stopped/uncertain worker: " + other["owner"]
                other_scope = other.get("scope") or observed_work(root, data).get(other["owner"])
                problem = scope_conflict(spec, scope_spec(root, other_scope))
                if problem:
                    return f"{problem}: {other.get('task', other['owner'])}"
            return None

        if args.action in {"status", "validate", "check"}:
            result = output(state=state, unavailable_tasks=unavailable,
                            tasks=[{k: t[k] for k in ("id", "title", "status", "priority", "depends_on")}
                                               for t in tasks.values()], eligible=[t["id"] for t in eligible(tasks)])
            if args.action == "check":
                result["existing_changes"] = dirty_snapshot(root)
                data = snapshot(args.snapshot)
                reason = gate(data, {args.owner}, candidate_scope())
                if claim and claim["role"] != "worker":
                    reason = reason or "Caller already owns a manager/dispatch reservation"
                if reason:
                    result.update(status="skipped", reason=reason)
            return result
        if not args.owner:
            raise ValueError("--owner must be the current Codex thread ID")

        if args.action == "claim":
            data = snapshot(args.snapshot)
            if any(c["role"] != "worker" for c in claims) or claim:
                return output("skipped", reason="Scheduled-work claim is occupied", claim=claim)
            reason = gate(data, {args.owner}, candidate_scope())
            if reason:
                return output("skipped", reason=reason)
            if state["claim"]:
                workers.append(state["claim"])
            # Keep original active tokens intact while freeing the manager slot.
            for other in claims:
                if not other.get("scope") and other["owner"] in observed_work(root, data):
                    other["scope"] = scope_spec(root, observed_work(root, data)[other["owner"]], other.get("task"))
            state["claim"] = {"role": "manager", "owner": args.owner, "manager": args.owner, "created": now()}
            save()
            return output(claim=state["claim"])

        if args.action == "prepare":
            owner("manager")
            data = snapshot(args.snapshot)
            spec = candidate_scope(args.task)
            reason = gate(data, {args.owner}, spec)
            if reason:
                return output("skipped", reason=reason)
            if args.task not in {t["id"] for t in eligible(tasks)}:
                raise ValueError("Task is not ready with completed dependencies")
            task = tasks[args.task]
            baseline = dirty_snapshot(root)
            if task["path"].relative_to(root).as_posix() in baseline:
                return output("skipped", reason="Selected task has uncommitted edits; preserve it and select another eligible task")
            # Reading preserved edits is valid: gate() already excludes active
            # writers and baseline fingerprints protect the bytes/index. Dirty
            # inputs do not imply that the candidate intends to overwrite them.
            overlaps = [p for p in baseline if covered(p, spec["write_paths"])]
            if overlaps:
                return output("skipped", reason="Candidate overlaps unfinished paths: " + ", ".join(overlaps))
            peers = {c.get("token", c["owner"]): scope_spec(root, c.get("scope"), c.get("task"))
                     for c in other_claims()}
            peers.update(observed_work(root, data))
            claim.update(role="dispatch", token=str(uuid.uuid4()), task=args.task,
                         task_sha256=task["sha256"], worker=None, prepared=now(), dirty_baseline=baseline,
                         scope=spec, peers=peers)
            for other in other_claims():
                other.setdefault("peers", {})[claim["token"]] = spec
            save()
            return output(claim=claim)

        if args.action == "attach":
            previous = receipts.get(args.token) or state.get("last_dispatch")
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
            reason = gate(data, {args.owner, claim["manager"]}, scope_spec(root, claim.get("scope")))
            if reason:
                return output("skipped", reason=reason)
            task = tasks[claim["task"]]
            if task["sha256"] != claim["task_sha256"] or task["id"] not in {t["id"] for t in eligible(tasks)}:
                raise ValueError("Task changed after dispatch; do not implement stale instructions")
            baseline, dirty = claim.get("dirty_baseline", {}), dirty_snapshot(root)
            allowed = peer_paths(data)
            changed = [p for p in set(baseline) | set(dirty)
                       if baseline.get(p) != dirty.get(p) and not covered(p, allowed)]
            if changed:
                return output("skipped", reason="Existing edits changed after prepare; reconcile the reservation before implementation")
            claim.setdefault("peers", {}).update(observed_work(root, data))
            # Persist ownership before touching the task, so a crash still leaves
            # an identifiable worker. Recovery never depends on elapsed time.
            claim.update(role="worker", owner=args.owner, worker=args.owner, accepted=now(), version_base=git(root, "rev-parse", "HEAD"))
            save()
            path = save_task(root, task, "in_progress", f"Worker `{args.owner}` accepted dispatch `{args.token}` at {now()}.")
            return output(claim=claim, task_path=str(path))

        if args.action == "scope":
            token()
            owner("worker")
            if not args.scope:
                raise ValueError("Scope update requires --scope")
            data = snapshot(args.snapshot)
            spec = candidate_scope(claim["task"])
            reason = gate(data, {args.owner}, spec)
            if reason:
                return output("skipped", reason=reason)
            old = scope_spec(root, claim.get("scope"), claim["task"])
            # Keep every previous write reservation until completion: a phase
            # change cannot hide already-dirty owned files as somebody else's.
            spec["write_paths"] = sorted(set(spec["write_paths"] + old["write_paths"]))
            reason = gate(data, {args.owner}, spec)
            if reason:
                return output("skipped", reason=reason)
            dirty = dirty_snapshot(root)
            overlaps = [p for p in dirty
                        if covered(p, spec["write_paths"])
                        and not covered(p, old["write_paths"])]
            if overlaps:
                return output("skipped", reason="Expanded scope overlaps unfinished paths: " + ", ".join(overlaps))
            # A newly reserved read may have appeared/changed since dispatch.
            # Preserve its current bytes and index as input, never owned output.
            # Do not rebaseline existing reads or writes and hide later edits.
            for path, value in dirty.items():
                if (covered(path, spec["read_paths"])
                        and not covered(path, spec["write_paths"] + old["read_paths"])):
                    claim.setdefault("dirty_baseline", {})[path] = value
            claim["scope"] = spec
            for other in other_claims():
                other.setdefault("peers", {})[claim["token"]] = spec
            save()
            return output(claim=claim)

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
                remove_claim()
            elif claim["role"] == "worker":
                token()
                task = tasks[claim["task"]]
                if task["status"] not in TERMINAL:
                    raise ValueError("Record completion or a blocker before releasing a worker")
                if task["status"] == "done":
                    problem = delivery_problem(root, claim, task, peer_paths())
                    if problem:
                        raise ValueError("Done requires committed/pushed worker delivery: " + problem)
                remember({**claim, "outcome": task["status"], "released": now(), "head": git(root, "rev-parse", "HEAD")})
                remove_claim()
            else:
                raise ValueError("Prepared dispatch cannot be released blindly; reconcile the worker first")
            save()
            return output(state=state)

        if args.action == "recover":
            data = snapshot(args.snapshot)
            if not claim:
                if args.token:
                    raise ValueError("Recovery token does not match an outstanding reservation")
                return output(reason="No claim to recover")
            recovery_scope = scope_spec(root, {"write_paths": [], "read_paths": [], "fps_sensitive": False,
                                               "reason": "Recover only the stopped task record"}, claim.get("task"))
            problem = workspace_problem(root) or activity_problem(
                root, data, {args.owner, claim["owner"], claim.get("worker")}, recovery_scope, claims)
            if problem:
                return output("skipped", reason=problem)
            stopped(data, claim["owner"])
            if claim["role"] == "dispatch":
                if not claim.get("worker"):
                    raise ValueError("Uncertain dispatch: locate the child by token and attach it; never create a duplicate")
                stopped(data, claim["worker"])
            if claim.get("task"):
                task = tasks[claim["task"]]
                completed = task["status"] == "done" and not delivery_problem(root, claim, task, peer_paths(data))
                if not completed:
                    old_record = re.search(r"^## Completion record\s*\n(.*)\Z", task["body"], re.M | re.S)
                    note = (old_record[1].strip() + "\n\n" if old_record else "")
                    note += f"Recovery {now()}: the recorded worker stopped before verified delivery. Investigate before any explicit retry; preserve unfinished changes."
                    save_task(root, task, "blocked", note)
                remember({**claim, "outcome": "done" if completed else "blocked", "recovered": now()})
            remove_claim()
            save()
            return output(state=state, next="Commit/push any recovery record before another dispatch; preserve unrelated edits")
        raise ValueError("Unknown action")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("status", "validate", "check", "claim", "prepare", "attach", "accept", "scope", "record", "release", "recover"))
    parser.add_argument("--root", default=str(Path(__file__).resolve().parent.parent))
    parser.add_argument("--owner", default=os.environ.get("CODEX_THREAD_ID"))
    parser.add_argument("--snapshot")
    parser.add_argument("--task")
    parser.add_argument("--scope", help="JSON write/read path reservations and FPS sensitivity")
    parser.add_argument("--preserve-dirty", action="store_true",
                        help="Validate usable queue while reporting incomplete unrelated task edits")
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

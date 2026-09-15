"""Internal development identity and milestone notes. Python 3.10+, stdlib only.

Read operations never stage, restore, commit, or install hooks. Evidence input
hashes describe tested bytes; a declared pass is not independently certified.
"""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import subprocess
import sys
import uuid

CONFIG = "config/development_version.json"
CATEGORIES = {"Maintenance", "Presentation", "Gameplay", "World", "Data format"}
DATA = {"mountains", "races", "records", "ghosts", "caches"}
OWNERS = {
    "physics": ("scripts/core/ski_simulation.gd", "MODEL_VERSION"),
    "world": ("scripts/world/mountain_definition.gd", "CURRENT_VERSION"),
    "replay": ("scripts/racing/run_replay.gd", "VERSION"),
    "race": ("scripts/racing/race_definition.gd", "SCHEMA"),
    "archive": ("scripts/racing/competitive_record.gd", "VERSION"),
    "mountain_file": ("scripts/world/mountain_definition.gd", "SCHEMA"),
}
TUNING = "config/ski_default.tres"


def git(root, *args):
    proc = subprocess.run(["git", "-C", str(root), *args], capture_output=True, timeout=30)
    if proc.returncode:
        raise ValueError(proc.stderr.decode("utf-8", errors="replace").strip() or "Git failed")
    return proc.stdout


def sha(data):
    return hashlib.sha256(data).hexdigest()


def digest(value):
    return sha(json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=True).encode())


def read_json(path):
    return json.loads(Path(path).read_text(encoding="utf-8-sig"))


def save(path, value):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def safe_path(value):
    if not isinstance(value, str) or not value or "\\" in value or ":" in value or "\0" in value:
        raise ValueError("Use literal repository-relative paths with forward slashes")
    path = PurePosixPath(value)
    if path.is_absolute() or any(p in {"..", ".git"} for p in path.parts) or any(c in value for c in "*?["):
        raise ValueError("Unsafe scope path: " + value)
    return path.as_posix()


def content(root, path, ref=None):
    path = safe_path(path)
    if ref:
        try:
            return git(root, "show", f":{path}" if ref == ":" else f"{ref}:{path}")
        except ValueError:
            return None
    target = root / path
    # Do not follow links/junctions outside the checkout while hashing.
    if not target.resolve().is_relative_to(root.resolve()):
        raise ValueError("Scope resolves outside checkout: " + path)
    if target.is_symlink():
        return os.readlink(target).encode()
    return target.read_bytes() if target.is_file() else None


def lfs_pointer(data):
    # Git stores canonical pointer text; evidence hashes the hydrated asset.
    # Fail closed for malformed/unsupported pointers, without running filters
    # or fetching remote objects during a read-only milestone check.
    if data is None or len(data) >= 1024:
        return None
    match = re.fullmatch(rb"version https://git-lfs.github.com/spec/v1\noid sha256:([0-9a-f]{64})\nsize (0|[1-9][0-9]*)\n", data)
    return (match[1].decode(), int(match[2])) if match else None


def file_hash(root, path, ref=None):
    data = content(root, path, ref)
    pointer = lfs_pointer(data) if ref else None
    if pointer:
        return pointer[0]
    return sha(data) if data is not None else None


def index_matches_worktree(root, path):
    staged = content(root, path, ":")
    working = content(root, path)
    pointer = lfs_pointer(staged)
    if pointer:
        return working is not None and pointer == (sha(working), len(working))
    return staged == working


def identities(root, ref=None, overlay=None):
    def read(path):
        return content(root, path, None if overlay is not None and path in overlay else ref)
    result = {}
    for key, (path, constant) in OWNERS.items():
        source = (read(path) or b"").decode("utf-8-sig")
        match = re.search(r"^const\s+" + constant + r"(?:\s*:\s*\w+)?\s*=\s*(\d+)", source, re.M)
        result[key] = int(match[1]) if match else None
    tuning = read(TUNING)
    result["tuning_sha256"] = sha(tuning) if tuning is not None else None
    source = (read("project.godot") or b"").decode("utf-8-sig")
    tick = re.search(r"^common/physics_ticks_per_second=(\d+)", source, re.M)
    result["tick_hz"] = int(tick[1]) if tick else None
    return result


def tracked_paths(root):
    return {p for p in git(root, "ls-files", "-z").decode("utf-8").split("\0") if p}


def is_note(path):
    return path.startswith("changes/") and path.endswith(".json")


def dirty_snapshot(root):
    raw = git(root, "status", "--porcelain=v1", "-z", "--no-renames", "--untracked-files=all")
    index = {}
    for row in git(root, "ls-files", "--stage", "-z").decode("utf-8").split("\0"):
        if row:
            value, path = row.split("\t", 1)
            index.setdefault(path, []).append(value)
    return {row[3:]: {"status": row[:2], "index": index.get(row[3:], []),
                      "sha256": file_hash(root, row[3:])}
            for row in raw.decode("utf-8").split("\0") if row}


def source_path(path):
    # Export inputs, including native assets and build scripts. These excluded
    # roots are documentation, authoring, or evidence, never packaged gameplay.
    return not path.startswith(("docs/", "changes/", "tests/", "backlog/", "art_source/",
                                ".agents/", ".codex/", ".github/", "examples/")) and path not in {"AGENTS.md", "README.md"}


def source_fingerprint(root, dirty):
    entries = {}
    for row in git(root, "ls-tree", "-r", "HEAD", "-z").decode("utf-8").split("\0"):
        if row:
            value, path = row.split("\t", 1)
            if source_path(path):
                entries[path] = value
    for path, value in dirty.items():
        if source_path(path):
            entries[path] = {"worktree_sha256": value["sha256"]}
    return digest(entries)


def revisions(root, ref="HEAD"):
    config = json.loads(content(root, CONFIG, ref) or content(root, CONFIG) or b"{}")
    base = config.get("baseline_commit", "")
    if config.get("schema") != 1 or not re.fullmatch(r"[0-9a-f]{40}", base):
        raise ValueError("Missing or invalid development baseline")
    # Require the baseline itself in the first-parent chain; rev-list A..B alone
    # would invent a count for shallow or unrelated history.
    chain = git(root, "rev-list", "--first-parent", ref).decode().splitlines()
    if base not in chain:
        raise ValueError("Development baseline is absent from first-parent history; fetch complete history")
    return list(reversed(chain[:chain.index(base)]))


def changed_paths(root, commit):
    return [p for p in git(root, "diff", "--name-only", "--no-renames", "-z", commit + "^1", commit).decode().split("\0") if p]


def added_notes(root, commit):
    return [p for p in git(root, "diff", "--name-only", "--diff-filter=A", "-z", commit + "^1", commit, "--", "changes").decode().split("\0") if p.endswith(".json")]


def identity(root):
    result = {"schema": 1, "dev": None, "commit": "", "modified": None,
              "changes_sha256": "", "source_sha256": "", "categories": [],
              "compatibility": identities(root), "warning": ""}
    try:
        result["commit"] = git(root, "rev-parse", "HEAD").decode().strip()
        dirty = dirty_snapshot(root)
        result.update(modified=bool(dirty), changes_sha256=digest(dirty), source_sha256=source_fingerprint(root, dirty))
        commits = revisions(root)
        result["dev"] = len(commits) if commits else None
        if commits:
            notes = added_notes(root, commits[-1])
            for path in notes:
                note = json.loads(content(root, path, commits[-1]))
                result["categories"] += [c for c in note.get("categories", []) if c in CATEGORIES and c not in result["categories"]]
            if not notes:
                result["warning"] = "This commit has no milestone note; validation is undocumented"
        else:
            result["warning"] = "Version tracking has not been committed yet"
    except (ValueError, OSError, subprocess.SubprocessError) as error:
        result["warning"] = str(error)
    return result


def label(value):
    return (f"Dev {value['dev']}" if value.get("dev") is not None else "Dev unknown") + (" + modified" if value.get("modified") else "")


def expand(root, paths):
    # Scope expansion needs names, not a content audit of every dirty asset.
    untracked = git(root, "ls-files", "--others", "--exclude-standard", "-z").decode("utf-8").split("\0")
    known = tracked_paths(root) | {p for p in untracked if p}
    result = set()
    for value in paths:
        value = safe_path(value)
        matches = {p for p in known if p == value or p.startswith(value + "/")}
        result.update(matches or {value})
    return sorted(result)


def create_note(root, scope, summary, categories, reserved_path=None):
    owned = expand(root, scope["write_paths"])
    if reserved_path is not None and not re.fullmatch(r"changes/[0-9a-f]{32}\.json", reserved_path):
        raise ValueError("Reserved note must be changes/<32 lowercase hexadecimal UUID>.json")
    note_id = PurePosixPath(reserved_path).stem if reserved_path else uuid.uuid4().hex
    path = f"changes/{note_id}.json"
    note = {"schema": 1, "id": note_id, "summary": summary, "categories": categories,
            "areas": [], "owned_paths": [p for p in owned if not is_note(p)],
            "read_paths": expand(root, scope.get("read_paths", [])),
            "compatibility": {"before": {}, "after": {}, "decisions": {}, "data": {}},
            "checks": [], "outstanding_acceptance": [], "evidence": {"inputs": {}}}
    (root / path).parent.mkdir(parents=True, exist_ok=True)
    # Exclusive creation preserves another worker's note even if two callers
    # accidentally reuse a reservation. There is no shared mutable counter.
    with (root / path).open("x", encoding="utf-8") as output:
        output.write(json.dumps(note, indent=2, ensure_ascii=False) + "\n")
    return path


def input_metadata(root, path):
    target = root / safe_path(path)
    if not target.resolve().is_relative_to(root.resolve()):
        raise ValueError("Scope resolves outside checkout: " + path)
    if not target.exists():
        return None
    info = target.lstat()
    return {"size": info.st_size, "mtime_ns": info.st_mtime_ns}


def capture_inputs(root, path, metadata_only=False):
    note = read_json(root / safe_path(path))
    paths = expand(root, note["owned_paths"] + note["read_paths"] + [p for p, _ in OWNERS.values()] + [TUNING, "project.godot"])
    if metadata_only:
        build = {"commit": git(root, "rev-parse", "HEAD").decode().strip(),
                 "dev": len(revisions(root)), "modified": bool(git(root, "status", "--porcelain"))}
    else:
        build = identity(root)
    note["evidence"] = {"captured_utc": datetime.now(timezone.utc).isoformat(),
                        "verification": "metadata" if metadata_only else "hashes",
                        "build": build,
                        "inputs": {p: input_metadata(root, p) if metadata_only else file_hash(root, p)
                                   for p in paths if not is_note(p)}}
    note["compatibility"]["before"] = identities(root, "HEAD")
    note["compatibility"]["after"] = identities(root, "HEAD", note["owned_paths"])
    save(root / path, note)
    return note["evidence"]


def sensitive(paths):
    result = set()
    for path in paths:
        if path.startswith(("scripts/core/", "config/ski_")) or path in {"project.godot", "scripts/main.gd"}:
            result.add("physics")
        if path.startswith(("scripts/world/", "assets/graphics/geology", "assets/graphics/trees/")):
            result.add("world")
        if path.startswith("scripts/racing/"):
            result.add("data")
    return result


def check_note(root, path, commit=None, staged=False):
    problems = []
    path = safe_path(path)
    raw = content(root, path, commit)
    if raw is None:
        return ["Missing milestone note: " + path]
    try:
        note = json.loads(raw)
        if note.get("schema") != 1 or not re.fullmatch(r"changes/[0-9a-f]{32}\.json", path) or path != f"changes/{note.get('id')}.json":
            problems.append("Invalid note schema/id/path")
        for key in ["summary"]:
            if not isinstance(note.get(key), str) or not note[key].strip(): problems.append("Missing " + key)
        for key in ["categories", "areas", "owned_paths"]:
            if not isinstance(note.get(key), list) or not note[key]: problems.append("Missing " + key)
        if not set(note.get("categories", [])) <= CATEGORIES: problems.append("Unknown category")
        owned = [safe_path(p) for p in note.get("owned_paths", [])]
        if any(is_note(p) for p in owned): problems.append("Notes cannot be evidence inputs or owned source paths")
        before_ref = commit + "^" if commit else "HEAD"
        baseline_before = content(root, CONFIG, before_ref)
        baseline_after = content(root, CONFIG, commit) if commit else content(root, CONFIG)
        if baseline_before is not None and baseline_after != baseline_before:
            problems.append("Development baseline is immutable after introduction")
        before = identities(root, before_ref)
        after = identities(root, commit) if commit else identities(root, "HEAD", owned)
        if any(value is None for value in after.values()): problems.append("Current compatibility identity is incomplete")
        compat = note["compatibility"]
        if compat.get("before") != before or compat.get("after") != after:
            problems.append("Declared identities differ from milestone sources; recapture and revalidate affected inputs")
        required = sensitive(owned)
        for key in OWNERS:
            if before.get(key) != after.get(key): required.add("physics" if key == "physics" else "world" if key == "world" else "data")
        for domain in required:
            decision = compat.get("decisions", {}).get(domain, {})
            if decision.get("effect") not in {"preserved", "changed"} or not decision.get("reason", "").strip():
                problems.append(f"Explicit {domain} compatibility decision and rationale required")
            keys = ["physics", "tuning_sha256", "tick_hz"] if domain == "physics" else ["world", "mountain_file"] if domain == "world" else ["replay", "race", "archive"]
            if decision.get("effect") == "preserved" and any(before.get(k) != after.get(k) for k in keys):
                problems.append(f"{domain} declared preserved but its identity changed")
            if domain == "physics" and decision.get("effect") == "changed" and before.get("physics") == after.get("physics") and before.get("tuning_sha256") == after.get("tuning_sha256") and before.get("tick_hz") == after.get("tick_hz"):
                problems.append("Changed physics requires a model, tuning, or tick identity change")
            if domain == "world" and decision.get("effect") == "changed" and before.get("world") == after.get("world"):
                problems.append("Changed physical world requires a generator version change")
        impacts = compat.get("data", {})
        if set(impacts) != DATA or any(v.get("effect") not in {"preserved", "incompatible", "regenerate", "not_applicable"} or not v.get("reason", "").strip() for v in impacts.values()):
            problems.append("Declare effect and rationale for mountains, races, records, ghosts, and caches")
        invalidated = set()
        if any(before.get(k) != after.get(k) for k in ["physics", "tuning_sha256"]): invalidated.update(["records", "ghosts"])
        if before.get("world") != after.get("world"):
            invalidated.update(["mountains", "races", "records", "ghosts"])
            if impacts.get("caches", {}).get("effect") != "regenerate": problems.append("Changed generator requires cache regeneration")
        for key, affected in {"replay": ["ghosts"], "archive": ["records", "ghosts"], "race": ["races", "records", "ghosts"], "mountain_file": ["mountains"]}.items():
            if before.get(key) != after.get(key): invalidated.update(affected)
        for key in invalidated:
            if impacts.get(key, {}).get("effect") != "incompatible": problems.append("Changed compatibility identity invalidates " + key)
        checks = note.get("checks", [])
        if not checks or not any(c.get("result") == "passed" for c in checks): problems.append("No passed validation recorded")
        for row in checks:
            if row.get("kind") not in {"automated", "rendered", "performance", "human"} or row.get("result") not in {"passed", "not_required", "pending"} or not row.get("command", "").strip() or not row.get("details", "").strip():
                problems.append("Incomplete or failed validation entry")
            if row.get("result") == "pending" and row.get("kind") != "human": problems.append("Required non-human verification is pending")
        if not isinstance(note.get("outstanding_acceptance"), list): problems.append("Missing outstanding acceptance list")
        if any(c.get("result") == "pending" for c in checks) and not note.get("outstanding_acceptance"):
            problems.append("Pending acceptance must be explained")
        inputs = note.get("evidence", {}).get("inputs", {})
        metadata_only = note.get("evidence", {}).get("verification") == "metadata"
        required_inputs = set(owned) | {safe_path(p) for p in note.get("read_paths", [])} | {p for p, _ in OWNERS.values()} | {TUNING, "project.godot"}
        if not required_inputs <= set(inputs): problems.append("Evidence is missing owned/identity inputs")
        if any(is_note(p) for p in inputs): problems.append("Evidence cannot hash its own notes")
        for p, expected in inputs.items():
            safe_path(p)
            # Historical checks must verify delivered files against the commit.
            # Preserved dirty read dependencies remain identified observations.
            if commit and p not in owned: continue
            if metadata_only:
                if expected is not None and (not isinstance(expected, dict) or set(expected) != {"size", "mtime_ns"}):
                    problems.append("Invalid input metadata: " + p)
                elif not commit and input_metadata(root, p) != expected:
                    problems.append("Tested input changed: " + p)
                elif commit and (bool(git(root, "ls-tree", commit, "--", p)) != (expected is not None)):
                    problems.append("Delivered input presence changed: " + p)
            elif file_hash(root, p, commit) != expected:
                problems.append("Tested input changed: " + p)
        existing = content(root, path, before_ref)
        if existing is not None: problems.append("Milestone notes are append-only; create a new note")
        if commit:
            changed = set(changed_paths(root, commit))
            if changed - set(owned) - {path}: problems.append("Commit includes changes outside its milestone scope")
        if staged:
            unstaged = set(git(root, "diff", "--name-only", "--no-renames", "-z", "--", *owned, path).decode().split("\0")) if metadata_only else set()
            for p in owned + [path]:
                if metadata_only:
                    mismatch = p in unstaged or bool(git(root, "ls-files", "--", p)) != (root / p).exists()
                else:
                    mismatch = not index_matches_worktree(root, p)
                if mismatch:
                    problems.append("Index differs from checked working bytes: " + p)
    except (KeyError, TypeError, AttributeError, ValueError) as error:
        problems.append("Malformed milestone note: " + str(error))
    return problems


def check_commit(root, commit="HEAD"):
    commit = git(root, "rev-parse", commit).decode().strip()
    notes = added_notes(root, commit)
    if len(notes) != 1: return ["Each milestone commit must add exactly one note: " + commit]
    return check_note(root, notes[0], commit=commit)


def history(root):
    rows = []
    for number, commit in reversed(list(enumerate(revisions(root), 1))):
        notes = []
        for path in added_notes(root, commit):
            try: notes.append(json.loads(content(root, path, commit)))
            except (ValueError, TypeError): notes.append({"summary": "Malformed milestone note"})
        rows.append({"dev": number, "commit": commit, "notes": notes,
                     "subject": git(root, "show", "-s", "--format=%s", commit).decode().strip()})
    return rows


def markdown(rows):
    text = ["# Alpine Apex internal change history", "", "Dev numbers identify development milestones, not public releases.", ""]
    for row in rows:
        text += [f"## Dev {row['dev']} · {row['commit'][:12]}", ""]
        if not row["notes"]: text += ["**Missing milestone note; validation is undocumented.** " + row["subject"], ""]
        for note in row["notes"]:
            text += [note.get("summary", "Missing summary"), "", ", ".join(note.get("categories", [])), ""]
            for name, impact in note.get("compatibility", {}).get("data", {}).items():
                text.append(f"- {name.capitalize()}: {impact.get('effect')} — {impact.get('reason')}")
            text.append("")
            for check in note.get("checks", []):
                text.append(f"- {check.get('kind')}: {check.get('result')} — {check.get('command')}. {check.get('details')}")
            text += [""] + ["- Pending acceptance: " + s for s in note.get("outstanding_acceptance", [])] + [""]
    return "\n".join(text)


def main():
    # PowerShell and the desktop command transport consume UTF-8, including when
    # Python otherwise selects the legacy Windows ANSI code page for a pipe.
    if hasattr(sys.stdout, "reconfigure"): sys.stdout.reconfigure(encoding="utf-8")
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=["identity", "note", "capture", "check", "history", "stamp", "verify-stamp"])
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parent.parent)
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--note")
    parser.add_argument("--scope", type=Path, help="JSON write_paths/read_paths; never stages or commits")
    parser.add_argument("--summary", default="")
    parser.add_argument("--category", action="append", choices=sorted(CATEGORIES))
    parser.add_argument("--commit")
    parser.add_argument("--staged", action="store_true")
    parser.add_argument("--metadata-only", action="store_true", help="Capture scoped file size/time instead of content hashes")
    parser.add_argument("--output", type=Path)
    parser.add_argument("--engine", type=Path)
    args = parser.parse_args()
    root = args.root.resolve()
    try:
        if args.action == "identity": result = identity(root)
        elif args.action == "note":
            if not args.scope or not args.summary or not args.category: raise ValueError("note requires --scope, --summary, and --category")
            result = {"note": create_note(root, read_json(args.scope), args.summary, args.category, args.note)}
        elif args.action == "capture":
            if not args.note: raise ValueError("capture requires --note; run before verification")
            result = capture_inputs(root, args.note, metadata_only=args.metadata_only)
        elif args.action == "check":
            problems = check_note(root, args.note, staged=args.staged) if args.note else check_commit(root, args.commit or "HEAD")
            result = {"status": "incomplete" if problems else "ok", "problems": problems}
            print(json.dumps(result, indent=2)); return 1 if problems else 0
        elif args.action == "history":
            rows = history(root)
            result = rows if args.json else markdown(rows)
        elif args.action == "stamp":
            if not args.output or not args.engine or not args.engine.is_file(): raise ValueError("stamp requires --output and --engine")
            problems = check_note(root, args.note) if args.note else check_commit(root)
            if problems: raise ValueError("Incomplete milestone: " + "; ".join(problems))
            result = identity(root)
            if result["modified"] and not args.note:
                result["warning"] = "Modified development package: only the committed milestone is documented; local changes are unverified"
            result["engine_sha256"] = sha(args.engine.read_bytes())
            result["prepared_utc"] = datetime.now(timezone.utc).isoformat()
            result["milestone_note"] = args.note or added_notes(root, "HEAD")[0]
            result["integrity_sha256"] = digest(result)
        else:
            if not args.output: raise ValueError("verify-stamp requires --output")
            saved = read_json(args.output)
            expected = saved.pop("integrity_sha256", "")
            if digest(saved) != expected: raise ValueError("Build manifest integrity mismatch")
            current = identity(root)
            if any(saved.get(k) != current.get(k) for k in ["commit", "source_sha256", "compatibility"]):
                raise ValueError("Source changed during export; discard this incomplete package and rebuild")
            if args.engine and sha(args.engine.read_bytes()) != saved.get("engine_sha256"): raise ValueError("Target engine changed during export")
            result = {"status": "ok"}
        if args.output and args.action != "verify-stamp":
            if isinstance(result, str):
                args.output.parent.mkdir(parents=True, exist_ok=True); args.output.write_text(result, encoding="utf-8")
            else: save(args.output, result)
        if args.json or not isinstance(result, str):
            if args.action == "identity" and not args.json:
                print(label(result) + " · " + result["commit"][:12]); print(json.dumps(result, indent=2))
            else: print(json.dumps(result, indent=2))
        else: print(result)
        return 0
    except (ValueError, OSError, subprocess.SubprocessError) as error:
        print(json.dumps({"status": "incomplete", "problems": [str(error)]})); return 1


if __name__ == "__main__":
    sys.exit(main())

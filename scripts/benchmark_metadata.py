"""Scoped benchmark file metadata; no content hashes or repository filesystem walk.

This is an edit detector, not cryptographic identity. Runtime replay and cache
compatibility remain the responsibility of their existing Godot producers.
"""
import argparse
from datetime import datetime, timezone
import json
from pathlib import Path, PurePosixPath
import re
import subprocess

SCHEMA = 2
VERSIONS = {
    "physics": ("scripts/core/ski_simulation.gd", "MODEL_VERSION"),
    "world": ("scripts/world/mountain_definition.gd", "CURRENT_VERSION"),
    "replay": ("scripts/racing/run_replay.gd", "VERSION"),
    "race": ("scripts/racing/race_definition.gd", "SCHEMA"),
}


def git(root, *args):
    return subprocess.run(["git", "-C", str(root), *args], check=True,
                          capture_output=True, timeout=30).stdout.decode("utf-8")


def literal(value):
    p = PurePosixPath(value)
    if (not value or value in (".", "/") or p.is_absolute() or
            any(part in ("..", ".git") for part in p.parts) or
            any(c in value for c in "\\:*?[]\0")):
        raise ValueError("Scope requires literal repository-relative paths: " + value)
    return p.as_posix()


def file_metadata(path):
    if not path.exists():
        return None
    if not path.is_file():
        raise ValueError("Expected a file: " + str(path))
    info = path.stat()
    return {"size": info.st_size, "mtime_ns": info.st_mtime_ns}


def test_dependencies(root, producer):
    """Only the selected diagnostic and its literal test references; no test tree scan."""
    pending, seen = [literal(producer)], set()
    while pending:
        path = pending.pop()
        if path in seen:
            continue
        seen.add(path)
        source = root / path
        if source.suffix in (".gd", ".tscn", ".tres") and source.is_file():
            for ref in re.findall(r'res://(tests/[^"\s]+)', source.read_text(encoding="utf-8-sig")):
                if (root / ref).is_file():
                    pending.append(literal(ref))
    return seen


def capture(root, scope_path, producer, trace, engine, extra_paths=()):
    root, scope_path, engine = root.resolve(), scope_path.resolve(), engine.resolve()
    scope = json.loads(scope_path.read_text(encoding="utf-8-sig"))
    if scope.get("schema") != 1 or not scope.get("roots") or not scope.get("paths"):
        raise ValueError("Missing or incompatible benchmark metadata scope")
    roots = sorted({literal(p) for p in scope["roots"]})
    paths = {literal(p) for p in scope["paths"]}
    paths.update(p for p in git(root, "ls-files", "--cached", "--others", "--exclude-standard", "-z", "--", *roots).split("\0") if p)
    paths.update(test_dependencies(root, producer))
    paths.update(literal(p) for p in extra_paths)
    files = {}
    for path in sorted(paths):
        target = root / path
        if not target.resolve().is_relative_to(root):
            raise ValueError("Scoped input resolves outside project: " + path)
        files[path] = file_metadata(target)
    # Explicit inputs may live outside the project (frozen traces or installed engines).
    if not (root / producer).is_file() or not engine.is_file():
        raise ValueError("Producer and engine must exist")
    files["@scope:" + str(scope_path)] = file_metadata(scope_path)
    if trace:
        trace_path = root / trace.removeprefix("res://") if trace.startswith("res://") else Path(trace)
        if not trace_path.is_absolute():
            trace_path = root / trace_path
        if not trace_path.is_file():
            raise ValueError("Input trace must exist")
        files["@trace:" + str(trace_path.resolve())] = file_metadata(trace_path)
    engine_paths = {engine}
    worker = engine.with_name(engine.name.replace(".console.exe", ".exe").replace("_console.exe", ".exe"))
    if worker != engine:
        if not worker.is_file():
            raise ValueError("Selected console engine is missing its worker: " + str(worker))
        engine_paths.add(worker)
    # Only the selected executable directory, not .tools/ or the SDK checkout.
    engine_paths.update(engine.parent.glob("*.dll"))
    engine_paths.update((engine.parent / "D3D12").glob("*.dll"))
    engines = {str(p): file_metadata(p) for p in sorted(engine_paths)}
    for p, metadata in engines.items():
        files["@engine:" + p] = metadata
    versions = {}
    for key, (path, symbol) in VERSIONS.items():
        source = root / path
        if source.is_file():
            match = re.search(r"(?m)^const " + symbol + r"\s*(?::\s*int)?\s*=\s*(\d+)", source.read_text(encoding="utf-8-sig"))
            if match:
                versions[key] = int(match[1])
    return {"schema": SCHEMA, "method": "scoped_file_metadata", "captured_utc": datetime.now(timezone.utc).isoformat(),
            "project_root": str(root), "scope": {"path": str(scope_path), "roots": roots, "extra_paths": sorted(extra_paths), "producer": producer},
            "git": {"commit": git(root, "rev-parse", "HEAD").strip(), "branch": git(root, "branch", "--show-current").strip(),
                    "status": git(root, "status", "--porcelain=v1", "--untracked-files=normal")},
            "versions": versions, "engine_files": engines, "files": files,
            "limits": "Size and modification time detect ordinary edits, not byte identity. Git context alone does not invalidate timing; changes to scoped files do."}


def compare(before, after):
    if any(r.get("schema") != SCHEMA or r.get("method") != "scoped_file_metadata" or not r.get("files") or not r.get("engine_files") for r in (before, after)):
        raise ValueError("Missing or incompatible scoped metadata receipt")
    changed = sorted(p for p in before["files"].keys() | after["files"].keys() if before["files"].get(p) != after["files"].get(p) or (p in before["files"]) != (p in after["files"]))
    if before["scope"] != after["scope"] or before["project_root"] != after["project_root"]:
        changed.append("@scope-definition")
    if before["versions"] != after["versions"]:
        changed.append("@runtime-versions")
    return changed


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("capture", "compare"))
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--scope", type=Path)
    parser.add_argument("--producer")
    parser.add_argument("--trace")
    parser.add_argument("--engine", type=Path)
    parser.add_argument("--extra-path", action="append", default=[])
    parser.add_argument("--before", type=Path)
    parser.add_argument("--after", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    if args.action == "capture":
        if not all((args.scope, args.producer, args.engine)):
            parser.error("capture requires --scope, --producer, --engine")
        result = capture(args.root, args.scope, args.producer, args.trace, args.engine, args.extra_path)
    else:
        if not args.before or not args.after:
            parser.error("compare requires --before and --after")
        before, after = [json.loads(p.read_text(encoding="utf-8-sig")) for p in (args.before, args.after)]
        changed = compare(before, after)
        result = {"method": "scoped_file_metadata", "changed_inputs": changed, "stable_inputs": not changed}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, ensure_ascii=True, separators=(",", ":")) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()

"""Exclusive, bounded source-edit/cache-reuse integration check. No mountain bake."""
import argparse
import json
import os
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
DISPLAY = ["scripts/presentation/foliage_sight.gd", "assets/graphics/foliage_sight.gdshaderinc"]


def main():
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument("--engine", required=True)
    parser.add_argument("--output", default="artifacts/scenery_dependency_root_20260918")
    args = parser.parse_args()
    if os.environ.get("ALPINE_VALIDATION_MODE") != "Exclusive":
        raise RuntimeError("Run under an Exclusive validation guard; this temporarily edits two sources.")
    output = (ROOT / args.output).resolve()
    if not output.is_relative_to((ROOT / "artifacts").resolve()):
        raise ValueError("Output must stay within artifacts")
    output.mkdir(parents=True, exist_ok=True)
    command = [args.engine, "--path", str(ROOT), "--headless", "--script",
               "tests/scenery_cache_dependency_suite.gd", "--", "--output=res://" + output.relative_to(ROOT).as_posix()]
    subprocess.run(command + ["--integration=prime"], cwd=ROOT, check=True)
    archive = output / "bounded.scenery"
    saved_archive = archive.read_bytes()
    saved_archive_mtime = archive.stat().st_mtime_ns
    originals = {}
    try:
        for name in DISPLAY:
            path = ROOT / name
            original = path.read_bytes()
            stat = path.stat()
            suffix = b"\n# cache dependency probe\n" if name.endswith(".gd") else b"\n// cache dependency probe\n"
            changed = original + suffix
            originals[path] = (original, changed, stat.st_atime_ns, stat.st_mtime_ns)
            path.write_bytes(changed)
        subprocess.run(command + ["--integration=reuse"], cwd=ROOT, check=True)
        assert archive.read_bytes() == saved_archive and archive.stat().st_mtime_ns == saved_archive_mtime, "Reuse rewrote the archive"
    finally:
        for path, (original, changed, atime, mtime) in originals.items():
            if path.read_bytes() != changed:
                raise RuntimeError(f"Concurrent edit detected; refusing to overwrite {path}")
            path.write_bytes(original)
            os.utime(path, ns=(atime, mtime))
    (output / "integration.json").write_text(json.dumps({"source_edits_restored": True,
        "archive_unchanged": True, "changed_sources": DISPLAY,
        "scope": "Actual source-build cache keys and bounded packed-array reuse; no mountain startup or FPS timing."}, indent=2) + "\n")


if __name__ == "__main__":
    main()

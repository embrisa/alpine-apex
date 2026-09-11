"""Freeze matched runtime projects without touching the working tree or personal saves."""
from pathlib import Path
import argparse
import hashlib
import json
import os
import shutil

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "artifacts/snow_dreamlike"
FOLDERS = ("scripts", "config", "tests", "scenes", "assets", "addons")
TEXT = {".gd", ".gdshader", ".gdshaderinc", ".tres", ".tscn", ".json", ".import", ".uid", ".ps1", ".py", ".godot", ".gdextension", ".cfg"}
RUNTIME = [
    "assets/graphics/snow_crystals.gdshaderinc", "assets/cloud_light.gdshaderinc",
    "assets/graphics/alpine_surface_fragment.gdshaderinc", "assets/graphics/powder_cap.gdshader",
    "assets/graphics/ski_track.gdshader", "scripts/presentation/graphics_quality.gd",
    "scripts/presentation/alpine_atmosphere.gd", "scripts/presentation/alpine_assets.gd",
    "scripts/presentation/snow_tracks.gd", "scripts/world/alpine_scenery.gd",
]

def digest(p):
    return hashlib.file_digest(p.open("rb"), "sha256").hexdigest()

def sources(root):
    files = [root / "project.godot", root / "main.tscn"]
    for folder in FOLDERS:
        files += [p for p in (root / folder).rglob("*") if p.is_file() and p.suffix in TEXT]
    return {p.relative_to(root).as_posix(): digest(p) for p in files}

def freeze():
    base = OUT / "before"
    if base.exists():
        raise SystemExit("Refusing to overwrite a frozen baseline")
    base.mkdir(parents=True)
    for folder in FOLDERS:
        shutil.copytree(ROOT / folder, base / folder, ignore=shutil.ignore_patterns("__pycache__"))
    for name in ("project.godot", "main.tscn", "godotw.ps1"):
        shutil.copy2(ROOT / name, base / name)
    (base / ".godot").mkdir()
    for name in ("global_script_class_cache.cfg", "uid_cache.bin", "extension_list.cfg"):
        if (ROOT / ".godot" / name).exists():
            shutil.copy2(ROOT / ".godot" / name, base / ".godot" / name)
    shutil.copytree(ROOT / ".godot/imported", base / ".godot/imported")
    (base / "artifacts").mkdir()
    (base / "artifacts/.gdignore").touch()
    (OUT / "baseline_sources.json").write_text(json.dumps(sources(base), indent=2))
    print("FROZEN", base, flush=True)

def upgrade():
    base, after = OUT / "before", OUT / "after"
    if not after.exists():
        # Only immutable binary assets/imports link to our private frozen base.
        # Source/config and every mutable engine cache remain separate files.
        def copy(src, dst):
            p = Path(src)
            if p.suffix not in TEXT and ("assets" in p.parts or "imported" in p.parts):
                os.link(src, dst)
                return dst
            return shutil.copy2(src, dst)
        for folder in FOLDERS:
            shutil.copytree(base / folder, after / folder, copy_function=copy)
        shutil.copytree(base / ".godot", after / ".godot", copy_function=copy,
                        ignore=shutil.ignore_patterns("shader_cache", "editor"))
        for name in ("project.godot", "main.tscn", "godotw.ps1"):
            shutil.copy2(base / name, after / name)
        (after / "artifacts").mkdir()
        (after / "artifacts/.gdignore").touch()
    for name in RUNTIME:
        shutil.copy2(ROOT / name, after / name)
    for p in (ROOT / "tests").glob("snow_dreamlike*.gd"):
        for target in (base, after):
            shutil.copy2(p, target / "tests" / p.name)
    old, new = sources(base), sources(after)
    diff = [name for name in sorted(set(old) | set(new)) if old.get(name) != new.get(name)]
    assert diff == sorted(RUNTIME), diff
    (OUT / "comparison_sources.json").write_text(json.dumps({"runtime_differences": diff, "before": old, "after": new}, indent=2))
    print("MATCHED_RUNTIME_DIFF", len(diff), flush=True)

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("action", choices=("freeze", "upgrade"))
    args = parser.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    (freeze if args.action == "freeze" else upgrade)()

"""Freeze current production shaders for an explicit material-only comparison.

Run before editing, with a new output directory. Expanded source avoids mutable
includes and imports; this is not the historical offmap-v2 geometry fixture.
"""
import argparse
import json
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("output", type=Path)
    parser.add_argument("--ref", help="Read material sources from this Git revision instead of the checkout")
    parser.add_argument("--current-include", action="append", default=[], help="Keep this shared include at current checkout bytes when restoring an older material")
    args = parser.parse_args()
    revision = subprocess.check_output(["git", "rev-parse", "--verify", (args.ref or "HEAD") + "^{commit}"], cwd=ROOT, text=True).strip()
    args.output.mkdir(parents=True, exist_ok=False)
    sources = {}

    def expand(path):
        historical = args.ref and path not in args.current_include
        data = subprocess.check_output(["git", "show", f"{revision}:{path}"], cwd=ROOT) if historical else (ROOT / path).read_bytes()
        sources[path] = {"bytes": len(data), "source": revision if historical else "working_tree"}
        return re.sub(r'#include "res://([^"]+)"',
                      lambda m: expand(m[1]), data.decode("utf-8"))

    shaders = {}
    for name in ("alpine_wilderness", "alpine_apron"):
        data = expand(f"assets/graphics/{name}.gdshader").encode("utf-8")
        filename = name + ".txt"
        (args.output / filename).write_bytes(data)
        shaders[filename] = {"bytes": len(data)}
    manifest = {"commit": revision, "source": "git" if args.ref else "working_tree", "verification": "paths and sizes; no hash audit",
                "sources": sources, "shaders": shaders,
                "scope": "Production material only; comparison uses identical current geometry, camera, weather and engine."}
    (args.output / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(manifest, indent=2))


if __name__ == "__main__":
    main()

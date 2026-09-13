"""Freeze current production shaders for an explicit material-only comparison.

Run before editing, with a new output directory. Expanded source avoids mutable
includes and imports; this is not the historical offmap-v2 geometry fixture.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=False)
    sources = {}

    def expand(path):
        data = (ROOT / path).read_bytes()
        sources[path] = hashlib.sha256(data).hexdigest()
        return re.sub(r'#include "res://([^"]+)"',
                      lambda m: expand(m[1]), data.decode("utf-8"))

    shaders = {}
    for name in ("alpine_wilderness", "alpine_apron"):
        data = expand(f"assets/graphics/{name}.gdshader").encode("utf-8")
        filename = name + ".txt"
        (args.output / filename).write_bytes(data)
        shaders[filename] = hashlib.sha256(data).hexdigest()
    manifest = {"commit": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
                "sources": sources, "shaders": shaders,
                "scope": "Production material only; comparison uses identical current geometry, camera, weather and engine."}
    (args.output / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(manifest, indent=2))


if __name__ == "__main__":
    main()

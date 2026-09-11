"""Freeze a committed snow shader graph for an isolated rendered comparison."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("revision")
    parser.add_argument("--output", default="artifacts/soft_snow/baseline")
    args = parser.parse_args()
    project = Path(__file__).resolve().parents[1]
    output = (project / args.output).resolve()
    output.relative_to(project / "artifacts")
    revision = subprocess.check_output(["git", "rev-parse", args.revision], cwd=project, text=True).strip()
    manifest = output / "manifest.json"
    if manifest.exists():
        previous = json.loads(manifest.read_text())
        if previous["revision"] != revision:
            raise ValueError("Use a new output directory for a different baseline")
        for path, digest in previous["frozen_sha256"].items():
            assert hashlib.sha256((output / path).read_bytes()).hexdigest() == digest, path
        print(f"Verified existing frozen snow sources: {revision}")
    elif output.exists() and any(output.iterdir()):
        raise ValueError("Refusing to overwrite an incomplete baseline")
    sources: dict[str, bytes] = {}
    includes = re.compile(rb'#include\s+"res://([^\"]+)"')

    def collect(path: str) -> None:
        if path in sources:
            return
        data = subprocess.check_output(["git", "show", f"{revision}:{path}"], cwd=project)
        sources[path] = data
        for child in includes.findall(data):
            collect(child.decode())

    for root in ("assets/snow.gdshader", "assets/graphics/alpine_surface.gdshader",
                 "assets/graphics/alpine_apron.gdshader",
                 "assets/graphics/ski_track.gdshader", "assets/graphics/powder_cap.gdshader",
                 "assets/graphics/powder_surface.gdshader",
                 "scripts/presentation/graphics_quality.gd"):
        collect(root)
    prefix = "res://" + output.relative_to(project).as_posix() + "/"
    original, frozen = {}, {}
    for path, data in sources.items():
        target = output / path
        target.parent.mkdir(parents=True, exist_ok=True)
        reference = includes.sub(lambda match: b'#include "' + prefix.encode() + match[1] + b'"', data)
        if target.exists():
            assert target.read_bytes() == reference, f"Frozen content differs: {path}"
        else:
            target.write_bytes(reference)
        original[path] = hashlib.sha256(data).hexdigest()
        frozen[path] = hashlib.sha256(reference).hexdigest()
    manifest.write_text(json.dumps({"revision": revision, "source_sha256": original,
                                    "frozen_sha256": frozen}, indent=2) + "\n")
    print(f"Frozen {len(sources)} snow sources at {revision}")


if __name__ == "__main__":
    main()

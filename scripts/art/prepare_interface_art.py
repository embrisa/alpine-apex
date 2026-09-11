"""Package supplied JPEGs for Godot without recompression or generative edits.

The shared Godot material owns grading and subject-aware framing at output
resolution. Originals remain untouched; .jfif inputs get a supported extension.
Run: python scripts/art/prepare_interface_art.py
"""
import hashlib
import json
from pathlib import Path
import re
import shutil

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets/images/loading screens"
OUTPUT = ROOT / "assets/images/prepared"


def main():
    OUTPUT.mkdir(parents=True, exist_ok=True)
    entries = []
    for number in range(1, 10):
        source = SOURCE / f"p{number}{'.jfif' if number < 4 else '.jpg'}"
        target = OUTPUT / f"p{number}.jpg"
        data = source.read_bytes()
        if not data.startswith(b"\xff\xd8"):
            raise ValueError(f"Expected JPEG content: {source}")
        if not target.exists() or target.read_bytes() != data:
            shutil.copyfile(source, target)
        entries.append({"source":source.relative_to(ROOT).as_posix(),
                        "runtime":target.relative_to(ROOT).as_posix(),
                        "sha256":hashlib.sha256(data).hexdigest(), "bytes":len(data)})
    # Godot writes the import descriptors on first import. Rerunning configures
    # the same lossless GPU upload and mip filtering for every runtime asset.
    for asset in [*(OUTPUT / e["runtime"].split("/")[-1] for e in entries),
                  ROOT / "assets/images/branding/alpine_apex.svg",
                  ROOT / "assets/images/branding/alpine_apex_compact.svg",
                  ROOT / "assets/images/branding/alpine_apex_ice.svg"]:
        descriptor = asset.with_suffix(asset.suffix + ".import")
        if descriptor.exists():
            config = descriptor.read_text(encoding="utf-8")
            config = re.sub(r"compress/mode=\d+", "compress/mode=0", config)
            config = config.replace("mipmaps/generate=false", "mipmaps/generate=true")
            config = config.replace("detect_3d/compress_to=1", "detect_3d/compress_to=0")
            descriptor.write_text(config, encoding="utf-8")
    (OUTPUT / "manifest.json").write_text(json.dumps({
        "pipeline":"Byte-preserving JPEG packaging; AlpinePhoto shader grades and composes at native UI resolution",
        "logo_source":"assets/images/branding/alpine_apex_ice.svg",
        "logo_master_source":"assets/images/branding/alpine_apex.svg",
        "logo_sha256":hashlib.sha256((ROOT / "assets/images/branding/alpine_apex_ice.svg").read_bytes()).hexdigest(),
        "assets":entries}, indent=2) + "\n", encoding="utf-8")
    print(f"Packaged {len(entries)} photographs ({sum(e['bytes'] for e in entries):,} bytes); originals unchanged.")


if __name__ == "__main__":
    main()

"""Package the six user-downloaded startup photographs; preserve source bytes.

Requires Pillow. --import-from accepts the Downloads directory once; subsequent
rebuilds use retained art_source masters. No network requests or generative edits.
"""
from pathlib import Path
import argparse
import hashlib
import json
import re
import shutil
from PIL import Image, ImageOps

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "art_source/photography/startup_20260914"
OUTPUT = ROOT / "assets/images/startup"
PHOTOS = [
    ("gio-almonte-jlFllcwVJqg-unsplash.jpg", "Gio Almonte", "Unsplash", "jlFllcwVJqg"),
    ("khaled-ali-DxkbYY8uehU-unsplash.jpg", "Khaled Ali", "Unsplash", "DxkbYY8uehU"),
    ("pexels-leon-aschemann-734730704-30607344.jpg", "Leon Aschemann", "Pexels", "30607344"),
    ("pexels-radoslaw-krupa-3227938-11258013.jpg", "Radoslaw Krupa", "Pexels", "11258013"),
    ("sanjeev-shakya-UHrlQWfAi84-unsplash.jpg", "Sanjeev Shakya", "Unsplash", "UHrlQWfAi84"),
    ("xandro-vandewalle-Qaz5eJdE06k-unsplash.jpg", "Xandro Vandewalle", "Unsplash", "Qaz5eJdE06k"),
]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--import-from", type=Path)
    args = parser.parse_args()
    SOURCE.mkdir(parents=True, exist_ok=True)
    OUTPUT.mkdir(parents=True, exist_ok=True)
    entries = []
    for name, author, provider, source_id in PHOTOS:
        original = SOURCE / name
        if args.import_from:
            incoming = args.import_from / name
            if original.exists() and sha(original) != sha(incoming):
                raise ValueError(f"Refusing to replace retained source {original}")
            if not original.exists():
                shutil.copyfile(incoming, original)
        image = ImageOps.exif_transpose(Image.open(original)).convert("RGB")
        source_size = list(image.size)
        image.thumbnail((3840, 2160), Image.Resampling.LANCZOS)
        target = OUTPUT / name
        image.save(target, "JPEG", quality=90, subsampling=0, optimize=True)
        descriptor = target.with_suffix(".jpg.import")
        if descriptor.exists():
            data = descriptor.read_text()
            data = re.sub(r"compress/mode=\d+", "compress/mode=0", data)
            data = data.replace("mipmaps/generate=false", "mipmaps/generate=true")
            data = data.replace("detect_3d/compress_to=1", "detect_3d/compress_to=0")
            descriptor.write_text(data)
        entries.append({"file":name,"author":author,"provider":provider,"source_id":source_id,
                        "source_page":f"https://unsplash.com/photos/{source_id}" if provider == "Unsplash" else f"https://www.pexels.com/photo/{source_id}/",
                        "license":"https://unsplash.com/license" if provider == "Unsplash" else "https://www.pexels.com/license/",
                        "source":original.relative_to(ROOT).as_posix(),"source_sha256":sha(original),
                        "source_pixels":source_size,"runtime_sha256":sha(target),"runtime_pixels":list(image.size),"bytes":target.stat().st_size,
                        "focus":[0.5,0.46],"credit":f"Photo: {author} / {provider}"})
    manifest = {"schema":1,"provenance":"User downloads, 2026-09-14. Authors and source IDs retained from supplied filenames; provider license pages checked 2026-09-14. Individual page retrieval unavailable in automated browser.",
                "preparation":"EXIF orientation, proportional fit within 3840x2160, Lanczos, JPEG 90 / 4:4:4; no crop or generated image edits.","photos":entries}
    (OUTPUT / "manifest.json").write_text(json.dumps(manifest,indent=2)+"\n")
    print(f"Prepared {len(entries)} startup photographs: {sum(e['bytes'] for e in entries):,} runtime bytes")


if __name__ == "__main__": main()

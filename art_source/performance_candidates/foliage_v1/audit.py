"""Structural audit of the isolated candidate GLBs; requires only Python 3."""

import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parent
manifest = json.loads((ROOT / "manifest.json").read_text(encoding="utf-8"))
records = manifest["records"]
assert len(records) == 24
assert manifest["collisions"] == 0
assert manifest["materials"][0]["textures"] == []
assert hashlib.sha256((ROOT / "build.py").read_bytes()).hexdigest() == manifest["build_py_sha256"]
assert hashlib.sha256((ROOT / "foliage_candidates.blend").read_bytes()).hexdigest() == manifest["source_blend_sha256"]
for name, digest in manifest["preview_sha256"].items():
    assert hashlib.sha256((ROOT / "previews" / name).read_bytes()).hexdigest() == digest

counts = {}
for record in records:
    path = ROOT / record["glb"]
    blob = path.read_bytes()
    assert hashlib.sha256(blob).hexdigest() == record["sha256"]
    assert blob[:4] == b"glTF" and int.from_bytes(blob[4:8], "little") == 2
    length = int.from_bytes(blob[12:16], "little")
    assert blob[16:20] == b"JSON"
    data = json.loads(blob[20:20 + length])
    assert len(data.get("scenes", [])) == len(data.get("nodes", [])) == len(data.get("meshes", [])) == 1
    assert data["nodes"][0].get("name") == record["id"]
    assert data["nodes"][0].get("mesh") == 0
    assert not any(key in data for key in ("skins", "animations", "cameras", "extensionsUsed"))
    assert len(data.get("materials", [])) == record["material_slots"] == 1
    material = data["materials"][0]
    assert material.get("name") == "FoliageVertexOpaque"
    assert material.get("alphaMode", "OPAQUE") == "OPAQUE"
    assert material.get("doubleSided") is True
    assert data.get("textures", []) == data.get("images", []) == []
    assert len(data["meshes"][0]["primitives"]) == 1
    primitive = data["meshes"][0]["primitives"][0]
    assert primitive.get("mode", 4) == 4 and primitive.get("material") == 0
    assert {"POSITION", "NORMAL", "TEXCOORD_0", "COLOR_0"} <= set(primitive["attributes"])
    index_count = data["accessors"][primitive["indices"]]["count"]
    assert index_count == record["triangles"] * 3
    position = data["accessors"][primitive["attributes"]["POSITION"]]
    assert -0.0001 <= position["min"][1] <= 0.01
    assert 0.12 <= position["max"][1] <= 0.42
    assert record["alpha_tested_surfaces"] == 0 and record["opaque_surfaces"] == 1
    assert record["texture_dependencies"] == []
    key = (record["shape"], record["finish"])
    counts.setdefault(key, {})[record["lod"]] = record["triangles"]

for levels in counts.values():
    assert set(levels) == {0, 1, 2}
    assert levels[0] > levels[1] > levels[2] > 0
print(f"PASS: {len(records)} vegetation-only GLBs, 4 silhouettes, 3 LODs, 2 finishes; no alpha, textures or collision")

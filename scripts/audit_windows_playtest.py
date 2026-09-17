"""Check packaged runtime sources and exclusions without importing the project."""
import hashlib
import json
import re
import struct
import sys
from pathlib import Path

root = Path(__file__).resolve().parent.parent
build = Path(sys.argv[1]).resolve()
with (build / "AlpineApex.pck").open("rb") as stream:
    def number(fmt):
        return struct.unpack(fmt, stream.read(struct.calcsize(fmt)))[0]

    magic, version, major, minor, patch, flags = [number("<I") for _ in range(6)]
    assert magic == 0x43504447 and version in (3, 4) and not flags & 1
    base, directory = number("<Q"), number("<Q")
    stream.seek(directory)
    count = number("<I")
    entries = {}
    for _ in range(count):
        path = stream.read(number("<I")).rstrip(b"\0").decode().removeprefix("res://")
        offset, size = number("<Q"), number("<Q")
        stream.read(16)
        number("<I")
        assert path not in entries
        entries[path] = (base + offset, size)

    forbidden = ("art_source/", "artifacts/", "tests/", "builds/", ".tools/", ".agents/", "addons/godot_mcp_toolkit/", "addons/generation_export/", "TreeDesigner + 400 trees/")
    unexpected = [p for p in entries if p.startswith(forbidden)]
    assert not unexpected, unexpected
    required = ["main.tscn.remap", "scripts/world/mountain_cache_v17.gd", "config/generation_dependencies.json", "scripts/core/ski_simulation.gd", "assets/graphics/geology_v11/catalog.json"]
    assert all(p in entries for p in required)
    assert not any(p.startswith('assets/graphics/trees/density_v13/') for p in entries)
    def read_entry(path):
        offset,size=entries[path]
        stream.seek(offset)
        return stream.read(size)
    trees=json.loads(read_entry('assets/graphics/trees/manifest.json'))
    assert trees['version']==3 and len(trees['assets'])==24
    build_paths=['scripts/art/build_tree_collection.py','scripts/art/foliage_clusters.py']
    build_paths+=['assets/graphics/trees/textures/foliage_'+channel+suffix+'.res'
                  for channel in ('color','normal_ao') for suffix in ('','_balanced','_low')]
    build_values={path:hashlib.sha256((root/path).read_bytes()).hexdigest() for path in build_paths}
    build_values.update(source=trees['source_sha256'],blender=trees['blender'])
    build_identity=hashlib.sha256(json.dumps(build_values,sort_keys=True).encode()).hexdigest()
    foliage_meshes=0
    for tree in trees['assets']:
        if tree['family'] in ('spruce','fir','pine'):
            assert tree['build_identity']==build_identity,tree['id']
        models=tree['models']+([tree['shadow']] if tree['family'] in ('spruce','fir','pine') else [])
        for model in models:
            assert hashlib.sha256((root/model['path']).read_bytes()).hexdigest()==model['sha256']
            imported=read_entry(model['path']+'.import').decode()
            destinations=re.findall(r'^path="res://([^"]+)"',imported,re.MULTILINE)
            assert destinations and all(path in entries for path in destinations),model['path']
            foliage_meshes+=1
    assert foliage_meshes==84
    for channel in ('color','normal_ao'):
        for suffix in ('','_balanced','_low'):
            assert 'assets/graphics/trees/textures/foliage_'+channel+suffix+'.res' in entries
    offset, size = entries["config/generation_dependencies.json"]
    stream.seek(offset)
    manifest = json.loads(stream.read(size))
    assert manifest["schema"] == 1
    for group in ["physical", "scenery"]:
        digests = manifest[group]
        canonical = json.dumps(digests, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode()
        assert hashlib.sha256(canonical).hexdigest() == manifest[group + "_sha256"]
        for path, digest in digests.items():
            assert hashlib.sha256((root / path.removeprefix("res://")).read_bytes()).hexdigest() == digest, path
    checked = 0
    for path, (offset, size) in entries.items():
        if path.endswith(".gd"):
            source = root / path
            assert source.is_file(), path
            stream.seek(offset)
            assert hashlib.sha256(stream.read(size)).digest() == hashlib.sha256(source.read_bytes()).digest(), path
            checked += 1

selection = json.loads((root / ".tools/fidelityfx-runtime.json").read_text(encoding="utf-8-sig"))
assert hashlib.sha256((build / "AlpineApex.exe").read_bytes()).hexdigest() == selection["engine_sha256"]
assert (build / "data/default_mountain_v18.physical").is_file()
assert (build / "data/default_mountain_v18.scenery").is_file()
assert manifest["engine_sha256"] == selection["engine_sha256"]
print(json.dumps(dict(dependency_manifest_verified=True, pack_files=count, current_scripts_verified=checked, foliage_meshes_verified=foliage_meshes, foliage_quality_textures=6, development_content_excluded=True, validated_engine=True)))

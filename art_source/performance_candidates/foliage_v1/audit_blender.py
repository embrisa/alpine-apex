"""Independent Blender source/GLB roundtrip check. Run under validation lock."""

import json
from pathlib import Path

import bpy


ROOT = Path(__file__).resolve().parent
records = json.loads((ROOT / "manifest.json").read_text(encoding="utf-8"))["records"]
source = {obj.name: obj for obj in bpy.data.objects}
assert set(source) == {row["id"] for row in records}
assert all(obj.type == "MESH" and len(obj.material_slots) == 1 for obj in source.values())
assert all(len(obj.data.polygons) == row["triangles"] for row in records for obj in [source[row["id"]]])
assert all(min(vertex.co.z for vertex in obj.data.vertices) >= -0.0001 for obj in source.values())
assert all(abs(loop.color[3] - 1.0) < 0.0001 for obj in source.values()
           for layer in obj.data.vertex_colors for loop in layer.data)

for row in records:
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(ROOT / row["glb"]))
    added = set(bpy.data.objects) - before
    meshes = [obj for obj in added if obj.type == "MESH"]
    assert len(meshes) == 1 and len(meshes[0].data.polygons) == row["triangles"]
    assert len(meshes[0].material_slots) == 1
    for obj in added:
        bpy.data.objects.remove(obj, do_unlink=True)

print(f"PASS: editable Blender source and all {len(records)} GLB roundtrips")

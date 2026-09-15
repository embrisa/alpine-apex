"""Build a small, vegetation-only comparison library with Blender 5.2.

Run from the repository root through scripts/run_guarded.ps1. No runtime assets
or project imports are touched. Coordinates in this editable source are Z-up;
glTF exports are Y-up, metres, with a ground-level pivot.
"""

import hashlib
import json
import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector


ROOT = Path(__file__).resolve().parent
MODELS = ROOT / "models"
PREVIEWS = ROOT / "previews"
SHAPES = ("alpine_blade", "meadow_tuft", "alpine_rosette", "fern_spray")
FINISHES = ("green", "dusted")
LODS = (0, 1, 2)
GREEN = (0.21, 0.37, 0.13, 1)
GREEN_LIGHT = (0.37, 0.52, 0.20, 1)
SNOW = (0.82, 0.91, 0.96, 1)


def shade(finish, t, alternating=False, snow_eligible=True):
    base = GREEN_LIGHT if alternating else GREEN
    if finish == "dusted" and snow_eligible and t >= 0.7:
        return SNOW
    return base


class MeshDraft:
    def __init__(self):
        self.vertices = []
        self.faces = []
        self.colors = []
        self.uvs = []

    def polygon(self, points, colors, uvs):
        assert len(points) == len(colors) == len(uvs)
        start = len(self.vertices)
        self.vertices.extend(points)
        for i in range(1, len(points) - 1):
            self.faces.append((start, start + i, start + i + 1))
            self.colors.append((colors[0], colors[i], colors[i + 1]))
            self.uvs.append((uvs[0], uvs[i], uvs[i + 1]))

    def object(self, name, material):
        mesh = bpy.data.meshes.new(name)
        mesh.from_pydata(self.vertices, [], self.faces)
        mesh.update()
        mesh.materials.append(material)
        attribute = mesh.vertex_colors.new(name="Color")
        uv = mesh.uv_layers.new(name="UVMap")
        for polygon, colors, uvs in zip(mesh.polygons, self.colors, self.uvs):
            for index, color, coord in zip(polygon.loop_indices, colors, uvs):
                attribute.data[index].color = color
                uv.data[index].uv = coord
        obj = bpy.data.objects.new(name, mesh)
        bpy.context.collection.objects.link(obj)
        return obj


def ribbon(draft, origin, angle, height, width, bend, segments, finish, index):
    # Flat opaque blade with a tapered silhouette, a root at z=0, and UV.y
    # increasing toward the wind/sweep-sensitive tip.
    direction = Vector((math.cos(angle), math.sin(angle), 0))
    side = Vector((-math.sin(angle), math.cos(angle), 0))
    for segment in range(segments):
        a = segment / segments
        b = (segment + 1) / segments

        def edge(t, sign):
            center = origin + direction * (bend * t * t)
            return (center + side * (width * (1 - 0.82 * t) * sign), height * t)

        p0, z0 = edge(a, -1)
        p1, z1 = edge(a, 1)
        p2, z2 = edge(b, 1)
        p3, z3 = edge(b, -1)
        draft.polygon(
            [(p0.x, p0.y, z0), (p1.x, p1.y, z1), (p2.x, p2.y, z2), (p3.x, p3.y, z3)],
            [shade(finish, a, index % 3 == 0, index % 2 == 0),
             shade(finish, a, index % 3 == 0, index % 2 == 0),
             shade(finish, b, index % 3 == 0, index % 2 == 0),
             shade(finish, b, index % 3 == 0, index % 2 == 0)],
            [(0, a), (1, a), (1, b), (0, b)],
        )


def grass(shape, finish, lod):
    draft = MeshDraft()
    specs = {
        "alpine_blade": ((18, 11, 6), (3, 2, 1), 0.25, 0.0080, 0.065, 0.040),
        "meadow_tuft": ((24, 14, 8), (3, 2, 1), 0.36, 0.0130, 0.110, 0.062),
    }
    counts, segments, height, width, bend, radius = specs[shape]
    count = counts[lod]
    for i in range(count):
        angle = i * math.tau * 0.61803398875
        radial = radius * math.sqrt((i + 0.5) / count)
        origin = Vector((math.cos(angle) * radial, math.sin(angle) * radial, 0))
        h = height * (0.77 + 0.23 * ((i * 7) % 11) / 10)
        ribbon(draft, origin, angle, h, width, bend, segments[lod], finish, i)
    return draft


def rosette(finish, lod):
    draft = MeshDraft()
    counts = (10, 7, 4)
    count = counts[lod]
    for i in range(count):
        angle = i * math.tau / count + 0.17
        direction = Vector((math.cos(angle), math.sin(angle), 0))
        side = Vector((-direction.y, direction.x, 0))
        root = direction * 0.012
        mid = direction * 0.087
        tip = direction * 0.15
        peak = 0.13 + 0.025 * (i % 3) / 2
        # Broad lanceolate leaf: 2 opaque triangles, with a central fold in
        # the source silhouette and snow colored toward the tip.
        draft.polygon(
            [(root.x, root.y, 0.0),
             (mid.x - side.x * 0.026, mid.y - side.y * 0.026, peak * 0.76),
             (tip.x, tip.y, peak),
             (mid.x + side.x * 0.026, mid.y + side.y * 0.026, peak * 0.76)],
            [shade(finish, 0, i % 3 == 0, i % 3 == 0),
             shade(finish, 0.76, i % 3 == 0, i % 3 == 0),
             shade(finish, 1, i % 3 == 0, i % 3 == 0),
             shade(finish, 0.76, i % 3 == 0, i % 3 == 0)],
            [(0.5, 0), (0, 0.76), (0.5, 1), (1, 0.76)],
        )
    return draft


def fern(finish, lod):
    draft = MeshDraft()
    fronds, pairs = ((5, 4), (3, 3), (3, 2))[lod]
    for i in range(fronds):
        angle = i * math.tau / fronds + 0.2
        direction = Vector((math.cos(angle), math.sin(angle), 0))
        side = Vector((-direction.y, direction.x, 0))
        span = 0.20
        height = 0.36 + 0.05 * (i % 2)
        # A single narrow rachis, with paired tapering pinnae. All vegetation.
        draft.polygon(
            [(-side.x * 0.002, -side.y * 0.002, 0),
             (side.x * 0.002, side.y * 0.002, 0),
             (direction.x * span, direction.y * span, height)],
            [shade(finish, 0, snow_eligible=False),
             shade(finish, 0, snow_eligible=False),
             shade(finish, 1, snow_eligible=False)],
            [(0, 0), (1, 0), (0.5, 1)],
        )
        for j in range(pairs):
            t = (j + 1) / (pairs + 1)
            center = direction * (span * t)
            z = height * t
            length = 0.057 * (1 - t * 0.6)
            for sign in (-1, 1):
                tip = center + side * (length * sign) + direction * 0.023
                inner = center + direction * 0.032
                draft.polygon(
                    [(center.x, center.y, z),
                     (tip.x, tip.y, z + 0.035),
                     (inner.x, inner.y, z + 0.055)],
                    [shade(finish, t, snow_eligible=(i + j + (sign > 0)) % 3 == 0),
                     shade(finish, min(1, t + 0.25), snow_eligible=(i + j + (sign > 0)) % 3 == 0),
                     shade(finish, min(1, t + 0.15), snow_eligible=(i + j + (sign > 0)) % 3 == 0)],
                    [(0, t), (1, min(1, t + 0.25)), (0.5, min(1, t + 0.15))],
                )
    return draft


def material():
    mat = bpy.data.materials.new("FoliageVertexOpaque")
    mat.use_nodes = True
    mat.use_backface_culling = False
    node = mat.node_tree.nodes.get("Principled BSDF")
    color = mat.node_tree.nodes.new("ShaderNodeVertexColor")
    color.layer_name = "Color"
    mat.node_tree.links.new(color.outputs["Color"], node.inputs["Base Color"])
    node.inputs["Roughness"].default_value = 0.9
    return mat


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def glb_json(path):
    data = path.read_bytes()
    assert data[:4] == b"glTF" and int.from_bytes(data[4:8], "little") == 2
    length = int.from_bytes(data[12:16], "little")
    assert data[16:20] == b"JSON"
    return json.loads(data[20:20 + length])


def preview(objects, family):
    # Original source meshes are not modified or re-saved by the preview.
    for obj in objects.values():
        obj.hide_render = True
    temporary = []
    for row, lod in enumerate(LODS):
        for column, (shape, finish) in enumerate((s, f) for s in family for f in FINISHES):
            specimen = objects[f"{shape}_{finish}_lod{lod}"].copy()
            specimen.data = specimen.data.copy()
            bpy.context.collection.objects.link(specimen)
            specimen.hide_render = False
            specimen.location = ((column - 1.5) * 0.53, 0, (1 - row) * 0.59)
            temporary.append(specimen)
            bpy.ops.object.text_add(location=((column - 1.5) * 0.53 - 0.21, 0, (1 - row) * 0.59 + 0.43),
                                    rotation=(math.pi / 2, 0, 0))
            label = bpy.context.object
            label.name = "PreviewLabel"
            short = {"alpine_blade": "blade", "meadow_tuft": "tuft",
                     "alpine_rosette": "rosette", "fern_spray": "fern"}[shape]
            label.data.body = f"{short} / {finish} / L{lod}"
            label.data.size = 0.032
            label.location.z = (1 - row) * 0.59 - 0.11
            temporary.append(label)
    bpy.ops.object.camera_add(location=(0, -6.0, 0.0))
    camera = bpy.context.object
    camera.rotation_euler = (math.pi / 2, 0, 0)
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 3.05
    bpy.context.scene.camera = camera
    temporary.append(camera)
    bpy.ops.object.light_add(type="AREA", location=(-2, -3, 4))
    light = bpy.context.object
    light.data.energy = 500
    light.data.shape = "DISK"
    light.data.size = 5
    temporary.append(light)
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 1800
    scene.render.resolution_y = 1300
    scene.render.resolution_percentage = 100
    scene.world.color = (0.16, 0.20, 0.25)
    scene.render.image_settings.file_format = "PNG"
    scene.render.filepath = str(PREVIEWS / ("grass.png" if family[0].startswith("alpine_blade") else "plants.png"))
    bpy.ops.render.render(write_still=True)
    for obj in temporary:
        bpy.data.objects.remove(obj, do_unlink=True)
    for obj in objects.values():
        obj.hide_render = False


def main():
    ROOT.mkdir(parents=True, exist_ok=True)
    old_manifest = ROOT / "manifest.json"
    if old_manifest.exists():
        if "--rebuild" not in sys.argv:
            raise SystemExit("Candidate pack exists; use --rebuild after reviewing source changes")
        old = json.loads(old_manifest.read_text(encoding="utf-8"))
        protected = [(ROOT / "foliage_candidates.blend", old["source_blend_sha256"])]
        protected += [(ROOT / row["glb"], row["sha256"]) for row in old["records"]]
        protected += [(PREVIEWS / name, digest) for name, digest in old["preview_sha256"].items()]
        if any(not path.exists() or sha(path) != digest for path, digest in protected):
            raise SystemExit("Existing candidate output was edited; preserve it before rebuilding")
    MODELS.mkdir(exist_ok=True)
    PREVIEWS.mkdir(exist_ok=True)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    mat = material()
    bpy.context.preferences.filepaths.save_version = 0
    objects = {}
    records = []
    for shape in SHAPES:
        for finish in FINISHES:
            for lod in LODS:
                name = f"{shape}_{finish}_lod{lod}"
                draft = (grass(shape, finish, lod) if shape in SHAPES[:2]
                         else rosette(finish, lod) if shape == "alpine_rosette"
                         else fern(finish, lod))
                obj = draft.object(name, mat)
                objects[name] = obj
                bpy.ops.object.select_all(action="DESELECT")
                obj.select_set(True)
                bpy.context.view_layer.objects.active = obj
                path = MODELS / f"{name}.glb"
                bpy.ops.export_scene.gltf(filepath=str(path), export_format="GLB",
                                          use_selection=True, export_apply=False,
                                          export_texcoords=True, export_yup=True,
                                          export_vertex_color="NAME", export_vertex_color_name="Color",
                                          export_all_vertex_colors=False, export_materials="EXPORT")
                raw = glb_json(path)
                assert len(raw.get("meshes", [])) == 1
                assert len(raw.get("materials", [])) == 1
                assert len(raw.get("textures", [])) == 0
                assert len(raw.get("images", [])) == 0
                assert raw["materials"][0].get("alphaMode", "OPAQUE") == "OPAQUE"
                primitive = raw["meshes"][0]["primitives"][0]
                assert "COLOR_0" in primitive["attributes"] and "TEXCOORD_0" in primitive["attributes"]
                bounds = [tuple(round(v, 4) for v in corner) for corner in obj.bound_box]
                records.append({
                    "id": name, "family": "grass" if shape in SHAPES[:2] else "plant",
                    "shape": shape, "finish": finish, "lod": lod,
                    "triangles": len(obj.data.polygons), "material_slots": len(obj.material_slots),
                    "opaque_surfaces": 1, "alpha_tested_surfaces": 0,
                    "texture_dependencies": [], "bounds_blender_m": {
                        "min": [min(p[i] for p in bounds) for i in range(3)],
                        "max": [max(p[i] for p in bounds) for i in range(3)]},
                    "glb": str(path.relative_to(ROOT)).replace("\\", "/"),
                    "sha256": sha(path), "bytes": path.stat().st_size,
                })
    preview(objects, SHAPES[:2])
    preview(objects, SHAPES[2:])
    # Make the editable source useful on opening: four green LOD0 specimens are
    # spread in a gallery, while the other finishes/LODs remain in the Outliner.
    # Export happened at identity before these source-only gallery transforms.
    for index, shape in enumerate(SHAPES):
        for finish in FINISHES:
            for lod in LODS:
                obj = objects[f"{shape}_{finish}_lod{lod}"]
                obj.location = ((index - 1.5) * 0.75, 0, 0)
                hidden = finish != "green" or lod != 0
                obj.hide_set(hidden)
                obj.hide_render = hidden
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT / "foliage_candidates.blend"))
    manifest = {
        "schema": 1, "units": "metres", "source": "Original procedural meshes authored for this pack; no vendor models or copied geometry",
        "coordinate_system": "Blender Z-up source; exported glTF Y-up", "collisions": 0,
        "materials": [{"name": mat.name, "slots_per_mesh": 1, "opaque": True,
                       "double_sided": True, "textures": [], "vertex_color": "COLOR_0"}],
        "records": records,
        "build_py_sha256": sha(ROOT / "build.py"),
        "source_blend_sha256": sha(ROOT / "foliage_candidates.blend"),
        "preview_sha256": {p.name: sha(p) for p in PREVIEWS.glob("*.png")},
    }
    (ROOT / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(f"PASS vegetation-only candidate build: {len(records)} GLBs, 2 previews")


if __name__ == "__main__":
    main()

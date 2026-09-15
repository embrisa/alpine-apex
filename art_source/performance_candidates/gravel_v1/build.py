"""Build two deterministic, source-only 8 m gravel cluster templates.

Run Blender through scripts/run_guarded.ps1. The script reads existing pebble
source GLBs and textures, and writes only beside itself. It never imports the
game, modifies terrain, or measures performance.
"""
import hashlib
import json
import math
import random
from pathlib import Path

import bpy
from mathutils import Vector

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]
PEBBLES = REPO / "art_source/rocks/pebbles_v1"
SEED = 20260914
CELL = 8.0
MIX = {
    "dense": [("grit", .78), ("gravel", .19), ("pebble", .025), ("shale_chip", .005)],
    "sparse": [("grit", .20), ("gravel", .55), ("pebble", .20), ("shale_chip", .05)],
}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def source_shapes():
    records = {}
    for family in ("grit", "gravel", "pebble", "shale_chip"):
        for variant in (1, 2, 3):
            name = f"{family}_{variant:02d}"
            for lod in (0, 2):
                path = PEBBLES / "models" / f"{name}_lod{lod}.glb"
                before = set(bpy.data.objects)
                bpy.ops.import_scene.gltf(filepath=str(path))
                added = [obj for obj in bpy.data.objects if obj not in before]
                meshes = [obj for obj in added if obj.type == "MESH"]
                assert len(meshes) == 1, (path, len(meshes))
                obj = meshes[0]
                mesh = obj.data
                mesh.calc_loop_triangles()
                uv = mesh.uv_layers.active
                color = mesh.color_attributes.active_color
                assert uv and color and len(mesh.loop_triangles) == (80 if lod == 0 else 16)
                triangles = []
                for tri in mesh.loop_triangles:
                    loops = []
                    for li in tri.loops:
                        vi = mesh.loops[li].vertex_index
                        loops.append((tuple(mesh.vertices[vi].co), tuple(uv.data[li].uv),
                                      tuple(color.data[li].color)))
                    triangles.append(loops)
                records[(name, lod)] = triangles
                for added_obj in added:
                    bpy.data.objects.remove(added_obj, do_unlink=True)
    return records


def choose_family(rng, kind):
    t = rng.random()
    for family, weight in MIX[kind]:
        t -= weight
        if t <= 0:
            return family
    return MIX[kind][-1][0]


def irregular_radius(theta):
    return 1.09 + .16 * math.sin(3 * theta + .4) + .10 * math.sin(7 * theta - 1.3)


def positions(kind, dims, rng):
    """Sample a dense, irregular ~2 m bed or a sparse 8 m transition.

    A spatial hash prevents overlapping visible silhouettes. The sparse field
    thins near a synthetic snow line for authoring review only; the production
    mask and physical terrain remain runtime-owned.
    """
    target = 3300 if kind == "dense" else 440
    buckets = {}
    placed = []
    max_tries = target * 70
    for _ in range(max_tries):
        if len(placed) >= target:
            break
        if kind == "dense":
            x = rng.uniform(2.35, 4.75)
            y = rng.uniform(2.55, 5.05)
            dx, dy = x - 3.55, y - 3.82
            theta = math.atan2(dy, dx)
            radius = math.hypot(dx, dy)
            if radius > irregular_radius(theta):
                continue
            # Soft, ragged rim; core density remains the source preset's scale.
            if radius > .72 and rng.random() < (radius - .72) * .65:
                continue
        else:
            x = rng.uniform(.16, 5.95)
            y = rng.uniform(.16, 7.84)
            boundary = 5.50 + .24 * math.sin(y * 1.4) + .10 * math.sin(y * 4.7)
            if x > boundary or rng.random() > min(1.0, (boundary - x) / .85):
                continue
        family = choose_family(rng, kind)
        variant = rng.randint(1, 3)
        name = f"{family}_{variant:02d}"
        sx, sy, _ = dims[name]
        width = max(sx, sy)
        radius = width * .49
        gx, gy = int(x / .06), int(y / .06)
        overlap = False
        for ix in range(gx - 2, gx + 3):
            for iy in range(gy - 2, gy + 3):
                for ox, oy, other_radius in buckets.get((ix, iy), ()):
                    if (x - ox) ** 2 + (y - oy) ** 2 < (radius + other_radius + .001) ** 2:
                        overlap = True
                        break
                if overlap:
                    break
            if overlap:
                break
        if overlap:
            continue
        buckets.setdefault((gx, gy), []).append((x, y, radius))
        placed.append((x, y, name, rng.uniform(0, math.tau)))
    assert len(placed) == target, (kind, len(placed), target)
    return placed


def material():
    mat = bpy.data.materials.new("Gravel_Source_SharedPBR")
    mat.use_nodes = True
    mat.use_backface_culling = True
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    bsdf = nodes.get("Principled BSDF")
    bsdf.inputs["Metallic"].default_value = 0
    uv = nodes.new("ShaderNodeUVMap")
    uv.uv_map = "StoneUV"
    image_nodes = {}
    for channel, name, colorspace in (
        ("albedo", "stone_albedo.png", "sRGB"),
        ("normal", "stone_normal.png", "Non-Color"),
        ("roughness", "stone_metallic_roughness.png", "Non-Color"),
    ):
        image = bpy.data.images.load(str(PEBBLES / "textures" / name), check_existing=True)
        image.colorspace_settings.name = colorspace
        image.pack()
        tex = nodes.new("ShaderNodeTexImage")
        tex.image = image
        links.new(uv.outputs["UV"], tex.inputs["Vector"])
        image_nodes[channel] = tex
    tint = nodes.new("ShaderNodeVertexColor")
    tint.layer_name = "Color"
    multiply = nodes.new("ShaderNodeMixRGB")
    multiply.blend_type = "MULTIPLY"
    multiply.inputs[0].default_value = 1
    links.new(image_nodes["albedo"].outputs["Color"], multiply.inputs[1])
    links.new(tint.outputs["Color"], multiply.inputs[2])
    links.new(multiply.outputs[0], bsdf.inputs["Base Color"])
    normal = nodes.new("ShaderNodeNormalMap")
    normal.uv_map = "StoneUV"
    normal.inputs["Strength"].default_value = .22
    links.new(image_nodes["normal"].outputs["Color"], normal.inputs["Color"])
    # The source image carries roughness in G, as the runtime map does.
    separate = nodes.new("ShaderNodeSeparateColor")
    links.new(image_nodes["roughness"].outputs["Color"], separate.inputs["Color"])
    links.new(separate.outputs["Green"], bsdf.inputs["Roughness"])
    return mat


def cluster_mesh(kind, lod, shapes, placed, mat):
    verts, faces, uv_values, root_values, color_values = [], [], [], [], []
    counts = {family: 0 for family, _ in MIX[kind]}
    source_heights = {name: max(point[0][2] for tri in tris for point in tri)
                      for (name, level), tris in shapes.items() if level == lod}
    for x, y, name, angle in placed:
        if lod == 0:
            counts[name.rsplit("_", 1)[0]] += 1
        c, s = math.cos(angle), math.sin(angle)
        height = source_heights[name]
        burial = max(height * .30, height - .01)
        for triangle in shapes[(name, lod)]:
            face = []
            loop_uv, loop_root, loop_color = [], [], []
            for (px, py, pz), uv, color in triangle:
                # Imported glTF is Blender Z-up. Sink at least 30% and leave
                # no more than 1 cm exposed on this level authoring plane.
                index = len(verts)
                verts.append((x + px * c - py * s, y + px * s + py * c,
                              pz - burial))
                face.append(index)
                loop_uv.append(uv)
                loop_root.append((x, y))
                loop_color.append(color)
            faces.append(face)
            uv_values.append(loop_uv)
            root_values.append(loop_root)
            color_values.append(loop_color)
    mesh = bpy.data.meshes.new(f"{kind}_cell_lod{lod}")
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    mesh.materials.append(mat)
    uv_layer = mesh.uv_layers.new(name="StoneUV")
    root_layer = mesh.uv_layers.new(name="StoneRoot")
    colors = mesh.color_attributes.new(name="Color", type="FLOAT_COLOR", domain="CORNER")
    for poly, uvs, roots, tints in zip(mesh.polygons, uv_values, root_values, color_values):
        for li, uv, root, tint in zip(poly.loop_indices, uvs, roots, tints):
            uv_layer.data[li].uv = uv
            root_layer.data[li].uv = root
            colors.data[li].color = tint
    obj = bpy.data.objects.new(f"{kind.upper()}_8m_LOD{lod}", mesh)
    bpy.context.collection.objects.link(obj)
    obj.hide_render = lod == 2
    obj["purpose"] = "Source-only cosmetic cell cluster; no collision or terrain"
    obj["cell_size_m"] = CELL
    obj["stone_count"] = len(placed)
    obj["fade_contract"] = "Near/far complementary dither and cell fade remain runtime-owned"
    return obj, {
        "vertices": len(mesh.vertices), "triangles": len(mesh.polygons),
        "material_slots": len(mesh.materials),
        "bounds_min_m": [round(min(v.co[i] for v in mesh.vertices), 5) for i in range(3)],
        "bounds_max_m": [round(max(v.co[i] for v in mesh.vertices), 5) for i in range(3)],
        "family_counts": counts if lod == 0 else None,
    }


def preview(kind, obj):
    previews = HERE / "previews"
    previews.mkdir(exist_ok=True)
    # All context geometry is temporary and excluded from the saved source.
    temp = []
    def flat_material(name, color):
        mat = bpy.data.materials.new(name)
        mat.use_nodes = True
        nodes = mat.node_tree.nodes
        nodes.clear()
        output = nodes.new("ShaderNodeOutputMaterial")
        emit = nodes.new("ShaderNodeEmission")
        emit.inputs["Color"].default_value = (*color, 1)
        emit.inputs["Strength"].default_value = 1
        mat.node_tree.links.new(emit.outputs["Emission"], output.inputs["Surface"])
        return mat
    rock = flat_material("Preview_Rock", (.085, .11, .135))
    snow = flat_material("Preview_Snow", (.69, .79, .85))
    ink = flat_material("Preview_Ink", (.007, .015, .025))
    pale = flat_material("Preview_PaleLabel", (.9, .94, .97))
    def slab(name, coords, mat):
        mesh = bpy.data.meshes.new(name)
        mesh.from_pydata(coords, [], [(0, 1, 2), (0, 2, 3)])
        mesh.materials.append(mat)
        item = bpy.data.objects.new(name, mesh)
        bpy.context.collection.objects.link(item)
        temp.append(item)
    slab("Rock review plane", [(0, 0, -.012), (5.5, 0, -.012),
                               (5.5, 8, -.012), (0, 8, -.012)], rock)
    slab("Snow boundary review plane", [(5.5, 0, -.011), (8, 0, -.011),
                                         (8, 8, -.011), (5.5, 8, -.011)], snow)
    def label(body, location, size, mat):
        curve = bpy.data.curves.new("Preview label", "FONT")
        curve.body = body
        curve.size = size
        curve.extrude = 0
        curve.materials.append(mat)
        text = bpy.data.objects.new(body, curve)
        bpy.context.collection.objects.link(text)
        text.location = location
        temp.append(text)
    label("DENSE  /  8 m CELL  /  SOURCE ONLY" if kind == "dense" else
          "SPARSE TRANSITION  /  8 m CELL  /  SOURCE ONLY", (.15, -.56, .03), .25, pale)
    label("ROCK", (.2, 7.55, .02), .22, pale)
    label("SNOW", (6.2, 7.55, .02), .22, ink)
    bpy.ops.object.light_add(type="AREA", location=(3, 3, 7))
    light = bpy.context.object
    light.data.energy = 1700
    light.data.shape = "DISK"
    light.data.size = 6
    temp.append(light)
    bpy.ops.object.camera_add(location=(4, 4, 12))
    camera = bpy.context.object
    direction = Vector((4, 4, 0)) - camera.location
    camera.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 10.4
    bpy.context.scene.camera = camera
    temp.append(camera)
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 1600
    scene.render.resolution_y = 1200
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.filepath = str(previews / f"{kind}_8m_cell.png")
    scene.world.color = (.12, .15, .18)
    obj.hide_render = False
    bpy.ops.render.render(write_still=True)
    # A second still makes the individual centimetre stones legible without
    # pretending to show actual in-game terrain seating or LOD transitions.
    camera.location = (3.55, 3.82, 3.4) if kind == "dense" else (2.2, 3.8, 3.4)
    camera.data.ortho_scale = 2.5 if kind == "dense" else 2.8
    scene.render.filepath = str(previews / f"{kind}_detail.png")
    bpy.ops.render.render(write_still=True)
    for item in temp:
        bpy.data.objects.remove(item, do_unlink=True)
    obj.hide_render = True


def main():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    bpy.context.preferences.filepaths.save_version = 0
    source_manifest = json.loads((PEBBLES / "manifest.json").read_text(encoding="utf-8"))
    dims = {record["id"]: tuple(record["models"][0]["dimensions_godot_xyz_m"][i]
                                for i in (0, 2, 1)) for record in source_manifest["assets"]}
    shapes = source_shapes()
    mat = material()
    output = {}
    for kind in ("dense", "sparse"):
        rng = random.Random(f"gravel-v1:{SEED}:{kind}")
        placed = positions(kind, dims, rng)
        records = {}
        near = None
        for lod in (0, 2):
            obj, record = cluster_mesh(kind, lod, shapes, placed, mat)
            near = obj if lod == 0 else near
            records[f"lod{lod}"] = record
        output[kind] = {"stones": len(placed), "lods": records}
        # A temporary review surface shows the snow/rock boundary but does not
        # enter the editable source payload.
        preview(kind, near)
    for obj in bpy.data.objects:
        if obj.type == "MESH":
            obj.hide_render = obj.name.endswith("LOD2")
            obj.hide_viewport = obj.name.endswith("LOD2")
    # Imported GLBs and temporary preview planes leave unlinked datablocks.
    # Keep the editable file to four meshes, one material and three shared maps.
    for mesh in list(bpy.data.meshes):
        if mesh.users == 0:
            bpy.data.meshes.remove(mesh)
    for curve in list(bpy.data.curves):
        if curve.users == 0:
            bpy.data.curves.remove(curve)
    for other in list(bpy.data.materials):
        if other != mat:
            bpy.data.materials.remove(other)
    for image in list(bpy.data.images):
        if image.users == 0:
            bpy.data.images.remove(image)
    assert len(bpy.data.materials) == 1
    assert len([o for o in bpy.data.objects if o.type == "MESH"]) == 4
    blend = HERE / "gravel_cell_candidates.blend"
    bpy.ops.wm.save_as_mainfile(filepath=str(blend))
    deps = [PEBBLES / "manifest.json"]
    deps += [PEBBLES / "textures" / n for n in
             ("stone_albedo.png", "stone_normal.png", "stone_metallic_roughness.png")]
    deps += [PEBBLES / "models" / f"{family}_{variant:02d}_lod{lod}.glb"
             for family in ("grit", "gravel", "pebble", "shale_chip")
             for variant in (1, 2, 3) for lod in (0, 2)]
    manifest = {
        "schema": 1, "units": "metres", "cell_size_m": CELL,
        "purpose": "Source-only 8 m cosmetic cluster templates, not runtime replacements",
        "seed": SEED, "collision": False, "terrain_write_back": False,
        "vegetation": False, "source_objects": 4, "shared_materials": 1,
        "textures_shared": [str(p.relative_to(REPO)).replace("\\", "/") for p in deps[1:4]],
        "source_hashes": {str(p.relative_to(REPO)).replace("\\", "/"): sha(p) for p in deps},
        "payloads": output,
        "blend_sha256": sha(blend),
        "preview_sha256": {p.name: sha(p) for p in (HERE / "previews").glob("*.png")},
    }
    (HERE / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print("PASS source-only cosmetic gravel clusters: two payloads, near/far objects, two static previews")


if __name__ == "__main__":
    main()

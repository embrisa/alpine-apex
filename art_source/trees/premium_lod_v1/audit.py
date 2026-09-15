"""Audit the prepared premium tree pack using only Python's standard library.

This reads actual GLB accessor data, embedded materials and PNG pixels; export
metadata alone is not evidence. It does not import assets or run an engine, and
its result does not establish visual quality, runtime FPS or LOD blending.
"""

from __future__ import annotations

import argparse
import base64
import hashlib
import json
import math
import re
import struct
import sys
import zlib
from datetime import datetime, timezone
from pathlib import Path


PACKAGE = Path(__file__).resolve().parent
REPOSITORY = PACKAGE.parents[2]
COMPONENTS = {5120: ("b", 1), 5121: ("B", 1), 5122: ("h", 2),
              5123: ("H", 2), 5125: ("I", 4), 5126: ("f", 4)}
WIDTHS = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}
IDENTITY = (1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
# Bare branch silhouettes have less redundant foliage to remove. Their middle
# representation must still reduce geometry, without imposing the leaf/spray
# reduction target on the visible branch structure itself.
BARE_FAMILIES = {"birch", "dead", "broken"}


class Invalid(ValueError):
    """A malformed or incomplete source asset."""


def require(condition, message):
    if not condition:
        raise Invalid(message)


def finite(values):
    return all(isinstance(v, (int, float)) and math.isfinite(v) for v in values)


def digest(blob):
    return hashlib.sha256(blob).hexdigest()


def relative_file(root, name):
    require(isinstance(name, str) and name, "file path must be a nonempty string")
    require(not Path(name).is_absolute() and not re.match(r"^[A-Za-z]:", name),
            f"absolute path is not portable: {name}")
    require(".." not in name.replace("\\", "/").split("/"), f"parent path is forbidden: {name}")
    path = (root / name).resolve()
    require(path.is_relative_to(root.resolve()), f"path escapes package: {name}")
    require(path.is_file(), f"missing file: {name}")
    return path


def checked_file(root, record, expected_path=None):
    require(isinstance(record, dict), "file record must be an object")
    name = record["path"]
    if expected_path:
        require(name.replace("\\", "/") == expected_path, f"unexpected file path: {name}")
    path = relative_file(root, name)
    blob = path.read_bytes()
    require(not blob.startswith(b"version https://git-lfs.github.com/spec/v1"),
            f"unhydrated LFS pointer: {name}")
    require(record["bytes"] == len(blob), f"byte count mismatch: {name}")
    require(record["sha256"] == digest(blob), f"SHA-256 mismatch: {name}")
    return blob


def near(a, b, tolerance=0.002):
    return len(a) == len(b) and all(abs(x - y) <= tolerance for x, y in zip(a, b))


def bounds(points):
    require(points, "empty geometry")
    return ([min(p[i] for p in points) for i in range(3)],
            [max(p[i] for p in points) for i in range(3)])


def multiply(a, b):
    return tuple(sum(a[k * 4 + row] * b[col * 4 + k] for k in range(4))
                 for col in range(4) for row in range(4))


def transform(matrix, point):
    return tuple(sum(matrix[col * 4 + row] * point[col] for col in range(3))
                 + matrix[12 + row] for row in range(3))


def node_matrix(node):
    if "matrix" in node:
        matrix = node["matrix"]
        require(len(matrix) == 16 and finite(matrix), "invalid node matrix")
        require(not any(key in node for key in ("translation", "rotation", "scale")),
                "node mixes matrix and TRS")
        require(near([matrix[i] for i in (3, 7, 11, 15)], [0, 0, 0, 1]),
                "node matrix is not affine")
        return matrix
    translation = node.get("translation", [0, 0, 0])
    rotation = node.get("rotation", [0, 0, 0, 1])
    scale = node.get("scale", [1, 1, 1])
    require(len(translation) == 3 and finite(translation), "invalid node translation")
    require(len(scale) == 3 and finite(scale) and all(v > 0 for v in scale), "invalid node scale")
    require(len(rotation) == 4 and finite(rotation), "invalid node rotation")
    require(abs(sum(v * v for v in rotation) - 1) < 0.002, "non-unit node quaternion")
    x, y, z, w = rotation
    result = [1 - 2 * (y*y + z*z), 2 * (x*y + z*w), 2 * (x*z - y*w), 0,
              2 * (x*y - z*w), 1 - 2 * (x*x + z*z), 2 * (y*z + x*w), 0,
              2 * (x*z + y*w), 2 * (y*z - x*w), 1 - 2 * (x*x + y*y), 0,
              *translation, 1]
    for col in range(3):
        for row in range(3):
            result[col * 4 + row] *= scale[col]
    return result


class Glb:
    def __init__(self, blob):
        require(len(blob) >= 28, "truncated GLB")
        magic, version, length = struct.unpack_from("<4sII", blob)
        require(magic == b"glTF" and version == 2, "expected GLB 2")
        require(length == len(blob), "GLB header length mismatch")
        chunks = []
        offset = 12
        while offset < len(blob):
            require(offset + 8 <= len(blob), "truncated GLB chunk header")
            size, kind = struct.unpack_from("<I4s", blob, offset)
            require(size % 4 == 0 and offset + 8 + size <= len(blob), "invalid GLB chunk size")
            chunks.append((kind, blob[offset + 8:offset + 8 + size]))
            offset += 8 + size
        require([c[0] for c in chunks] == [b"JSON", b"BIN\0"], "GLB must contain JSON then BIN only")
        self.data = json.loads(chunks[0][1])
        self.binary = chunks[1][1]
        require(self.data.get("asset", {}).get("version") == "2.0", "invalid glTF asset version")
        buffers = self.data.get("buffers", [])
        require(len(buffers) == 1 and "uri" not in buffers[0], "GLB buffer must be embedded")
        self.buffer_size = buffers[0]["byteLength"]
        require(isinstance(self.buffer_size, int) and 0 <= len(self.binary) - self.buffer_size <= 3,
                "embedded buffer length mismatch")
        require(not self.data.get("extensionsRequired"), "required extensions are not portable core glTF")
        require(not any(self.data.get(key) for key in ("skins", "animations", "cameras")),
                "source tree must not contain skins, animations or cameras")
        self.cache = {}
        self.reject_physics(self.data)

    @staticmethod
    def reject_physics(value):
        if isinstance(value, dict):
            for key, item in value.items():
                if key.lower() in {"collision", "collisions", "collider", "rigidbody", "physics"}:
                    require(item in (False, 0, [], {}, None), f"unexpected physics payload: {key}")
                if key == "name" and isinstance(item, str):
                    require(not re.search(r"(^|[_\s-])(collision|collider|rigidbody)([_\s-]|$)|-col(only)?$", item, re.I),
                            f"collision node/material name: {item}")
                if key == "extensions" and isinstance(item, dict):
                    require(not any(re.search("physics|collision|rigidbody", name, re.I) for name in item),
                            "physics extension is forbidden")
                Glb.reject_physics(item)
        elif isinstance(value, list):
            for item in value:
                Glb.reject_physics(item)

    def item(self, collection, index):
        entries = self.data.get(collection, [])
        require(type(index) is int and 0 <= index < len(entries), f"invalid {collection} index: {index}")
        return entries[index]

    def view(self, index):
        view = self.item("bufferViews", index)
        require(view.get("buffer", 0) == 0, "bufferView refers to external buffer")
        start, length = view.get("byteOffset", 0), view["byteLength"]
        require(type(start) is int and type(length) is int and start >= 0 and length > 0
                and start + length <= self.buffer_size, "bufferView exceeds BIN buffer")
        return view, start, length

    def accessor(self, index):
        if index in self.cache:
            return self.cache[index]
        accessor = self.item("accessors", index)
        require("sparse" not in accessor, "sparse accessors are outside this source-pack contract")
        require(accessor["type"] in WIDTHS and accessor["componentType"] in COMPONENTS,
                "unsupported accessor shape/component type")
        width = WIDTHS[accessor["type"]]
        code, size = COMPONENTS[accessor["componentType"]]
        view, start, length = self.view(accessor["bufferView"])
        count, offset = accessor["count"], accessor.get("byteOffset", 0)
        stride = view.get("byteStride", width * size)
        require(type(count) is int and count > 0, "accessor must have vertices")
        require(type(offset) is int and offset >= 0 and offset % size == 0, "invalid accessor offset")
        require(type(stride) is int and width * size <= stride <= 252 and stride % size == 0,
                "invalid accessor stride")
        require(offset + (count - 1) * stride + width * size <= length, "accessor exceeds bufferView")
        unpacker = struct.Struct("<" + code * width)
        rows = [unpacker.unpack_from(self.binary, start + offset + i * stride) for i in range(count)]
        require(all(finite(row) for row in rows), "non-finite accessor values")
        for key, reducer in (("min", min), ("max", max)):
            if key in accessor:
                claimed = accessor[key]
                actual = [reducer(row[i] for row in rows) for i in range(width)]
                require(len(claimed) == width and finite(claimed) and near(claimed, actual, 0.0002),
                        f"accessor {key} differs from actual bytes")
        if accessor.get("normalized", False):
            divisor = {5120: 127, 5121: 255, 5122: 32767, 5123: 65535}.get(accessor["componentType"])
            require(divisor is not None, "invalid normalized accessor component type")
            rows = [tuple(max(-1, v / divisor) for v in row) for row in rows]
        self.cache[index] = rows
        return rows

    def image(self, index):
        image = self.item("images", index)
        if "uri" in image:
            uri = image["uri"]
            require(isinstance(uri, str) and uri.startswith("data:"), "external image URI is forbidden")
            header, body = uri.split(",", 1)
            require(header in {"data:image/png;base64", "data:image/jpeg;base64"}, "unsupported image data URI")
            blob = base64.b64decode(body, validate=True)
        else:
            require(image.get("mimeType") in {"image/png", "image/jpeg"}, "image MIME type is not portable")
            _, start, size = self.view(image["bufferView"])
            blob = self.binary[start:start + size]
        require(blob.startswith(b"\x89PNG\r\n\x1a\n") or blob.startswith(b"\xff\xd8\xff"),
                "embedded image has invalid signature")
        return blob

    def materials(self, attributes, material_index):
        material = self.item("materials", material_index)
        pbr = material.get("pbrMetallicRoughness")
        require(isinstance(pbr, dict), "portable material requires core PBR values")
        alpha_mode = material.get("alphaMode", "OPAQUE")
        require(alpha_mode in {"OPAQUE", "MASK"}, "source trees permit OPAQUE or MASK materials only; BLEND is forbidden")
        if alpha_mode == "MASK":
            require("baseColorTexture" in pbr, "cutout material requires an embedded base color texture")
            cutoff = material.get("alphaCutoff", 0.5)
            require(finite([cutoff]) and 0 < cutoff <= 1, "invalid material alpha cutoff")
        for key, default in (("metallicFactor", 1), ("roughnessFactor", 1)):
            value = pbr.get(key, default)
            require(finite([value]) and 0 <= value <= 1, f"invalid material {key}")
        base = pbr.get("baseColorFactor", [1, 1, 1, 1])
        require(len(base) == 4 and finite(base) and all(0 <= v <= 1 for v in base), "invalid material base color")
        textures = [(pbr, "baseColorTexture"), (pbr, "metallicRoughnessTexture"),
                    (material, "normalTexture"), (material, "occlusionTexture"), (material, "emissiveTexture")]
        for owner, key in textures:
            if key not in owner:
                continue
            texture_info = owner[key]
            texture = self.item("textures", texture_info["index"])
            require(f"TEXCOORD_{texture_info.get('texCoord', 0)}" in attributes,
                    f"material {key} has no corresponding UV attribute")
            self.image(texture["source"])
            if "sampler" in texture:
                self.item("samplers", texture["sampler"])

    def inspect(self, lod):
        scenes = self.data.get("scenes", [])
        require(len(scenes) == 1 and self.data.get("scene", 0) == 0, "expected one default scene")
        roots = scenes[0].get("nodes", [])
        require(len(roots) == 1, "expected one source-tree scene root")
        for index in range(len(self.data.get("bufferViews", []))):
            self.view(index)
        for index in range(len(self.data.get("images", []))):
            self.image(index)
        positions, seen_nodes, seen_meshes = [], set(), set()
        triangles = primitives = vertices = 0
        material_indices, uv1_present = set(), True

        def walk(index, parent):
            nonlocal triangles, primitives, vertices, uv1_present
            require(index not in seen_nodes, "scene cycle or multiply-instanced node")
            seen_nodes.add(index)
            node = self.item("nodes", index)
            world = multiply(parent, node_matrix(node))
            require("skin" not in node and "weights" not in node, "skinning/morph weights are forbidden")
            if "mesh" in node:
                mesh_index = node["mesh"]
                require(mesh_index not in seen_meshes, "multiply-instanced source mesh")
                seen_meshes.add(mesh_index)
                mesh = self.item("meshes", mesh_index)
                require(mesh.get("primitives"), "empty source mesh")
                for primitive in mesh["primitives"]:
                    primitives += 1
                    require(primitive.get("mode", 4) == 4, "only triangle primitives are allowed")
                    require(not primitive.get("targets"), "morph targets are forbidden")
                    attrs = primitive["attributes"]
                    required = {"POSITION", "NORMAL", "COLOR_0", "TEXCOORD_0"}
                    if lod < 2:
                        required.add("TEXCOORD_1")
                    require(required <= set(attrs), f"missing attributes: {sorted(required - set(attrs))}")
                    uv1_present &= "TEXCOORD_1" in attrs
                    pos = self.accessor(attrs["POSITION"])
                    count = len(pos)
                    vertices += count
                    require(self.item("accessors", attrs["POSITION"])["type"] == "VEC3", "position must be VEC3")
                    require(self.item("accessors", attrs["POSITION"])["componentType"] == 5126, "position must be float")
                    require(all(key in self.item("accessors", attrs["POSITION"]) for key in ("min", "max")),
                            "position accessor requires actual min/max")
                    for semantic, accessor_index in attrs.items():
                        rows = self.accessor(accessor_index)
                        require(len(rows) == count, f"{semantic} count differs from POSITION")
                        if semantic == "NORMAL":
                            require(all(len(row) == 3 and 0.8 < sum(v*v for v in row) < 1.2 for row in rows),
                                    "normal is not a finite unit vector")
                        elif semantic.startswith("COLOR_"):
                            require(all(len(row) in (3, 4) and all(-0.0001 <= v <= 1.0001 for v in row) for row in rows),
                                    "color values must be within 0..1")
                        elif semantic.startswith("TEXCOORD_"):
                            require(all(len(row) == 2 for row in rows), "UV accessor must be VEC2")
                    index_accessor = self.item("accessors", primitive["indices"])
                    require(index_accessor["type"] == "SCALAR" and index_accessor["componentType"] in (5121, 5123, 5125)
                            and not index_accessor.get("normalized", False), "invalid index accessor type")
                    indices = [row[0] for row in self.accessor(primitive["indices"])]
                    require(len(indices) % 3 == 0 and all(0 <= v < count for v in indices), "triangle indices exceed vertices")
                    require(all(len(set(indices[i:i + 3])) == 3 for i in range(0, len(indices), 3)),
                            "degenerate triangle has duplicate indices")
                    triangles += len(indices) // 3
                    positions.extend(transform(world, point) for point in pos)
                    self.materials(attrs, primitive["material"])
                    if lod == 2:
                        material = self.item("materials", primitive["material"])
                        require(material.get("alphaMode") == "MASK", "far card requires a portable MASK cutout material")
                        require("baseColorTexture" in material["pbrMetallicRoughness"],
                                "far card requires an embedded first-view base color texture")
                    material_indices.add(primitive["material"])
            for child in node.get("children", []):
                walk(child, world)

        walk(roots[0], IDENTITY)
        require(len(seen_nodes) == len(self.data.get("nodes", [])), "unattached scene nodes")
        require(len(seen_meshes) == len(self.data.get("meshes", [])), "unattached source meshes")
        low, high = bounds(positions)
        require(finite(low + high), "non-finite transformed bounds")
        return {"triangles": triangles, "vertices": vertices, "primitives": primitives,
                "materials": len(material_indices), "bounds_min": low, "bounds_max": high,
                "uv1": uv1_present, "embedded_images": len(self.data.get("images", []))}


def png_pixels(blob):
    """Decode noninterlaced 8-bit PNGs and validate CRCs, scanlines and zlib EOF."""
    require(blob.startswith(b"\x89PNG\r\n\x1a\n"), "invalid PNG signature")
    offset, chunks, compressed = 8, [], bytearray()
    while offset < len(blob):
        require(offset + 12 <= len(blob), "truncated PNG chunk")
        size = struct.unpack_from(">I", blob, offset)[0]
        kind = blob[offset + 4:offset + 8]
        require(offset + 12 + size <= len(blob), "PNG chunk exceeds file")
        body = blob[offset + 8:offset + 8 + size]
        crc = struct.unpack_from(">I", blob, offset + 8 + size)[0]
        require(zlib.crc32(kind + body) & 0xffffffff == crc, "PNG CRC mismatch")
        chunks.append(kind)
        if kind == b"IHDR":
            require(chunks == [b"IHDR"] and size == 13, "invalid PNG IHDR")
            width, height, depth, color, compression, filtering, interlace = struct.unpack(">IIBBBBB", body)
        elif kind == b"IDAT":
            compressed.extend(body)
        elif kind == b"IEND":
            require(size == 0 and offset + 12 == len(blob), "data after PNG IEND")
        offset += size + 12
    require(chunks and chunks[0] == b"IHDR" and chunks[-1] == b"IEND" and b"IDAT" in chunks,
            "PNG is missing required chunks")
    require(0 < width <= 16384 and 0 < height <= 16384 and width * height <= 32_000_000,
            "PNG dimensions outside source-pack limit")
    require(depth == 8 and color in (0, 2, 4, 6) and (compression, filtering, interlace) == (0, 0, 0),
            "PNG must be noninterlaced 8-bit gray, RGB, gray-alpha or RGBA")
    channels = {0: 1, 2: 3, 4: 2, 6: 4}[color]
    stride = width * channels
    expected = height * (stride + 1)
    decoder = zlib.decompressobj()
    raw = decoder.decompress(compressed, expected + 1)
    require(len(raw) == expected and decoder.eof and not decoder.unused_data and not decoder.unconsumed_tail,
            "PNG decompressed length/stream mismatch")
    pixels = bytearray(height * stride)
    previous = bytearray(stride)
    for y in range(height):
        filter_type = raw[y * (stride + 1)]
        row = bytearray(raw[y * (stride + 1) + 1:(y + 1) * (stride + 1)])
        require(filter_type <= 4, "invalid PNG row filter")
        if filter_type:
            for x in range(stride):
                left = row[x - channels] if x >= channels else 0
                above = previous[x]
                upper_left = previous[x - channels] if x >= channels else 0
                if filter_type == 1:
                    predictor = left
                elif filter_type == 2:
                    predictor = above
                elif filter_type == 3:
                    predictor = (left + above) // 2
                else:
                    p = left + above - upper_left
                    distances = (abs(p - left), abs(p - above), abs(p - upper_left))
                    predictor = (left, above, upper_left)[distances.index(min(distances))]
                row[x] = (row[x] + predictor) & 255
        pixels[y * stride:(y + 1) * stride] = row
        previous = row
    return width, height, channels, pixels


def audit_atlas(package, asset):
    atlas = asset["impostor"]
    require(atlas["views"] == 8 and atlas["tile_size"] == 512, "expected eight 512px atlas views")
    require(finite([atlas["ortho_scale"], atlas["center_z"]]) and atlas["ortho_scale"] > 0,
            "invalid atlas framing")
    near_record = next(record for record in asset["models"] if record["lod"] == 0)
    require(atlas["near_sha256"] == near_record["sha256"], "atlas was baked from a different near model")
    report = {"views": 8, "tile_size": 512, "ortho_scale": atlas["ortho_scale"], "center_z": atlas["center_z"]}
    for role in ("color", "normal", "canopy"):
        record = atlas[role]
        blob = checked_file(package, record, f"impostors/{asset['id']}_{role}.png")
        width, height, channels, pixels = png_pixels(blob)
        require((width, height) == (4096, 512), f"{role} atlas must be 4096x512")
        item = {"bytes": len(blob), "sha256": digest(blob), "dimensions": [width, height], "channels": channels}
        if role == "color":
            require(channels == 4, "color atlas requires RGBA transparency")
            alphas = pixels[3::4]
            coverage = []
            for view in range(8):
                count = sum(sum(a > 8 for a in alphas[y * width + view * 512:y * width + (view + 1) * 512])
                            for y in range(height))
                fraction = count / (512 * 512)
                require(0.001 < fraction < 0.90, f"color atlas view {view} is empty or lacks transparent framing")
                coverage.append(round(fraction, 6))
            item["view_alpha_coverage"] = coverage
        report[role] = item
    return report


def audit_asset(package, asset, runtime_asset):
    name = asset["id"]
    require(re.fullmatch(r"[a-z][a-z0-9_]*", name), "invalid asset ID")
    require(asset["family"] == runtime_asset["family"], "family differs from production ID")
    require(type(asset["seed"]) is int, "asset seed must be an integer")
    require(finite([asset["height_m"]]) and asset["height_m"] > 0, "invalid nominal asset height")
    source = checked_file(package, asset["source_blend"], f"blends/{name}.blend")
    require(source.startswith(b"BLENDER") or source.startswith(b"\x1f\x8b") or source.startswith(b"\x28\xb5\x2f\xfd"),
            "source is not a Blender file (plain, gzip or zstd)")
    records = asset["models"]
    require(len(records) == 3 and {r["lod"] for r in records} == {0, 1, 2}, "expected exactly LOD0, LOD1 and LOD2")
    def inspect_record(record, expected_path):
        lod = record["lod"]
        blob = checked_file(package, record, expected_path)
        actual = Glb(blob).inspect(lod)
        require(actual["triangles"] == record["triangles"], f"LOD{lod} triangle metadata mismatch")
        for key in ("bounds_min", "bounds_max"):
            claimed = record[key]
            require(len(claimed) == 3 and finite(claimed) and near(actual[key], claimed), f"LOD{lod} {key} mismatch")
        actual.update({"bytes": len(blob), "sha256": digest(blob), "path": record["path"]})
        return actual

    levels = {record["lod"]: inspect_record(record, f"models/{name}_lod{record['lod']}.glb") for record in records}
    require(asset["shadow"]["lod"] == -1, "shadow derivative must be tagged lod=-1")
    shadow = inspect_record(asset["shadow"], f"models/{name}_shadow.glb")
    require(0 < shadow["triangles"] <= 1400, "independent shadow derivative exceeds 1400-triangle budget")
    near_model, mid_model, far_model = (levels[i] for i in range(3))
    height = near_model["bounds_max"][1] - near_model["bounds_min"][1]
    require(height > 1, "tree height is implausibly small")
    require(abs(height - asset["height_m"]) <= max(0.03, asset["height_m"] * 0.10), "near height differs from asset height")
    for lod in (0, 1):
        model = levels[lod]
        require(abs(model["bounds_min"][1]) <= max(0.04, height * 0.01), f"LOD{lod} is not grounded at Y=0")
        require(model["bounds_min"][0] <= 0 <= model["bounds_max"][0]
                and model["bounds_min"][2] <= 0 <= model["bounds_max"][2], f"LOD{lod} does not straddle its origin")
    bound_error = []
    for axis in range(3):
        span = max(near_model["bounds_max"][axis] - near_model["bounds_min"][axis], 0.1)
        error = max(abs(near_model[key][axis] - mid_model[key][axis]) for key in ("bounds_min", "bounds_max")) / span
        require(error < 0.10, f"near/mid axis {axis} bound difference is {error:.1%}, expected <10%")
        bound_error.append(round(error, 6))
    ratio = mid_model["triangles"] / near_model["triangles"]
    limit = 1.0 if asset["family"] in BARE_FAMILIES else 0.30
    require(0 < ratio < limit, f"mid/near triangle ratio {ratio:.3f} exceeds contract <{limit:.2f}")
    require(far_model["triangles"] == 2, "far model must be a two-triangle card")
    atlas = audit_atlas(package, asset)
    scale, center = atlas["ortho_scale"], atlas["center_z"]
    require(near(far_model["bounds_min"], [-scale / 2, center - scale / 2, 0])
            and near(far_model["bounds_max"], [scale / 2, center + scale / 2, 0]),
            "far card bounds do not match atlas framing in Y-up space")
    radius = max(math.hypot(x, z) for x in (near_model["bounds_min"][0], near_model["bounds_max"][0])
                 for z in (near_model["bounds_min"][2], near_model["bounds_max"][2]))
    # The rotated rectangular bounds are conservative: report horizontal margin
    # without asserting that all their empty corners contain tree geometry.
    require(center - scale / 2 <= near_model["bounds_min"][1] + 0.002
            and center + scale / 2 >= near_model["bounds_max"][1] - 0.002, "atlas framing clips tree height")
    return {"id": name, "family": asset["family"], "seed": asset["seed"], "status": "pass",
            "height_m_actual": height, "mid_near_triangle_ratio": round(ratio, 6),
            "mid_near_triangle_ratio_limit_exclusive": limit,
            "near_mid_bounds_relative_error": bound_error,
            "atlas_conservative_horizontal_margin_m": round(scale / 2 - radius, 6),
            "source_blend_sha256": digest(source), "models": [levels[i] for i in range(3)],
            "shadow": shadow, "impostor": atlas}


def input_identities(identities, repository):
    require(isinstance(identities, (dict, list)), "identity hashes must be an object or a list")
    entries = identities.items() if isinstance(identities, dict) else ((r["path"], r["sha256"]) for r in identities)
    checked = {}
    for name, expected in entries:
        if isinstance(expected, dict):
            expected = expected["sha256"]
        require(isinstance(expected, str) and re.fullmatch(r"[0-9a-f]{64}", expected), f"invalid input hash: {name}")
        actual = digest(relative_file(repository, name).read_bytes())
        require(actual == expected, f"production/source input changed: {name}")
        checked[name] = actual
    return checked


def audit(package, repository):
    report = {"schema_version": 1, "created_utc": datetime.now(timezone.utc).isoformat(),
              "package": str(package.resolve()), "auditor_sha256": digest(Path(__file__).read_bytes()),
              "acceptance": "Source integrity and representation contracts only; visual review and measured runtime performance remain separate.",
              "status": "fail", "errors": [], "assets": []}
    try:
        raw_manifest = (package / "manifest.json").read_bytes()
        manifest = json.loads(raw_manifest)
        report["manifest_sha256"] = digest(raw_manifest)
        require(manifest.get("version") is not None, "manifest version is missing")
        require(manifest.get("collisions", 0) == 0, "source pack declares collision content")
        runtime_path = repository / "assets/graphics/trees/manifest.json"
        runtime_bytes = runtime_path.read_bytes()
        runtime = json.loads(runtime_bytes)
        runtime_assets = {r["id"]: r for r in runtime["assets"]}
        require(len(runtime_assets) == 30, "production tree manifest no longer contains 30 unique IDs; review coverage contract")
        report["runtime_manifest_sha256"] = digest(runtime_bytes)
        assets = manifest["assets"]
        require(isinstance(assets, list), "manifest assets must be an array")
        ids = [r["id"] for r in assets]
        require(len(ids) == len(set(ids)), "duplicate source asset IDs")
        missing, extra = sorted(set(runtime_assets) - set(ids)), sorted(set(ids) - set(runtime_assets))
        require(not missing and not extra, f"production ID coverage mismatch; missing={missing}, extra={extra}")
        report["input_hashes"] = input_identities(manifest.get("input_hashes", {}), repository)
        for field in ("authoring_hashes", "review_producer_hashes"):
            if field in manifest:
                report[field] = input_identities(manifest[field], package)
        for asset in assets:
            try:
                report["assets"].append(audit_asset(package, asset, runtime_assets[asset["id"]]))
            except (Invalid, KeyError, TypeError, ValueError, OSError, struct.error, zlib.error) as exc:
                message = f"{asset.get('id', '<missing id>')}: {type(exc).__name__}: {exc}"
                report["errors"].append(message)
                report["assets"].append({"id": asset.get("id"), "status": "fail", "error": message})
        passed = [asset for asset in report["assets"] if asset["status"] == "pass"]
        report["summary"] = {"assets_expected": 30, "assets_passed": len(passed), "models_passed": len(passed) * 3,
                             "shadows_passed": len(passed),
                             "atlases_passed": len(passed) * 3,
                             "triangles_by_lod": {str(lod): sum(a["models"][lod]["triangles"] for a in passed) for lod in range(3)}}
        report["status"] = "pass" if not report["errors"] and len(passed) == 30 else "fail"
    except (Invalid, KeyError, TypeError, ValueError, OSError, struct.error, zlib.error) as exc:
        report["errors"].append(f"{type(exc).__name__}: {exc}")
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--package", type=Path, default=PACKAGE, help="prepared pack directory")
    parser.add_argument("--repository", type=Path, default=REPOSITORY, help="repository containing the production tree manifest")
    parser.add_argument("--output", type=Path, default=REPOSITORY / "artifacts/premium_tree_review/audit.json")
    args = parser.parse_args()
    report = audit(args.package, args.repository)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2, allow_nan=False) + "\n", encoding="utf-8")
    print(f"{report['status'].upper()}: {report.get('summary', {}).get('assets_passed', 0)}/30 tree assets; report: {args.output}")
    for error in report["errors"]:
        print(error, file=sys.stderr)
    return 0 if report["status"] == "pass" else 1


if __name__ == "__main__":
    raise SystemExit(main())

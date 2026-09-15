"""Original, deterministic Alpine Apex premium tree geometry recipes.

This module has no Blender or Godot dependency. ``build(record, lod)`` returns
metre-scale Z-up geometry; the exporter owns materials and engine conventions.
All levels evaluate one seeded botanical plan. LOD1 retains every crown lobe,
snow placement and primary branch; only local tessellation and fine twigs change.
UV2/tag Y deliberately uses the source-export convention (1 - pivot / 32).
Conifers use curved, intersecting branch sprays with the existing four-cell
needle atlas. Broadleaf silhouettes are actual folded leaf geometry. No tier
uses solid inflated canopy pillows or whole-tree crossed cards.
"""

from __future__ import annotations

import math
import random

TAU = math.tau


def add(a, b):
    return tuple(x + y for x, y in zip(a, b))


def sub(a, b):
    return tuple(x - y for x, y in zip(a, b))


def mul(a, s):
    return tuple(x * s for x in a)


def dot(a, b):
    return sum(x * y for x, y in zip(a, b))


def cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def unit(a):
    return mul(a, 1.0 / max(1e-12, math.sqrt(dot(a, a))))


def mix(a, b, t):
    return add(mul(a, 1 - t), mul(b, t))


def srgb(rgb):
    return tuple(x / 12.92 if x <= .04045 else ((x + .055) / 1.055) ** 2.4 for x in rgb)


PALETTES = {
    "spruce": ((.235, .435, .355), (.355, .555, .425)),
    "fir": ((.255, .455, .395), (.415, .595, .48)),
    "pine": ((.29, .445, .29), (.43, .575, .345)),
    "golden": ((.765, .49, .105), (.97, .76, .235)),
    "maple": ((.69, .225, .085), (.925, .445, .125)),
}


class Mesh:
    def __init__(self, height):
        self.height = height
        self.vertices, self.faces, self.colors = [], [], []
        self.roles, self.uvs, self.tags = [], [], []

    def vertex(self, point, color, uv=(.5, .5), tag=(0., 1.)):
        idx = len(self.vertices)
        self.vertices.append(tuple(point))
        self.colors.append((*color[:3], 1.))
        self.uvs.append(tuple(uv))
        self.tags.append(tuple(tag))
        return idx

    def face(self, ids, role):
        self.faces.append(tuple(ids))
        self.roles.append(role)

    def result(self):
        return {key: getattr(self, key) for key in ("vertices", "faces", "colors", "roles", "uvs", "tags")}


def tag_for(index, pivot):
    return ((index % 12) / 16., 1. - pivot / 32.)


def tube(mesh, points, radii, color, sides=6, tag=(0., 1.), phase=0., cap=True):
    """Tapered curved branch with longitudinal UVs and a continuous frame."""
    rings = []
    distance = 0.
    for k, (p, radius) in enumerate(zip(points, radii)):
        tangent = unit(sub(points[min(k + 1, len(points) - 1)], points[max(0, k - 1)]))
        across = unit(cross(tangent, (0., 1., .17)))
        up = unit(cross(tangent, across))
        if k:
            distance += math.dist(p, points[k - 1])
        ring = []
        for j in range(sides):
            angle = TAU * j / sides + phase
            bark = 1 + .055 * math.sin(j * 2.7 + phase) + .045 * math.sin(k * 2.1 + j)
            v = add(p, mul(add(mul(across, math.cos(angle)), mul(up, math.sin(angle))), radius * bark))
            tint = tuple(min(1., c * (.96 + .045 * math.cos(angle))) for c in color)
            ring.append(mesh.vertex(v, tint, (j / sides, distance * 1.6), tag))
        rings.append(ring)
    for a, b in zip(rings, rings[1:]):
        for j in range(sides):
            n = (j + 1) % sides
            mesh.face((a[j], a[n], b[n]), "wood")
            mesh.face((a[j], b[n], b[j]), "wood")
    if cap:
        for ring, point, reverse in ((rings[0], points[0], True), (rings[-1], points[-1], False)):
            center = mesh.vertex(point, color, (.5, .5), tag)
            for j in range(sides):
                ids = (center, ring[(j + 1) % sides], ring[j]) if reverse else (center, ring[j], ring[(j + 1) % sides])
                mesh.face(ids, "wood")


def frame(angle, tilt):
    x = (math.cos(angle) * math.cos(tilt), math.sin(angle) * math.cos(tilt), math.sin(tilt))
    y = (-math.sin(angle), math.cos(angle), 0.)
    return x, y, cross(x, y)


def ellipsoid_point(center, axes, size, direction):
    return add(center, add(add(mul(axes[0], direction[0] * size[0]), mul(axes[1], direction[1] * size[1])), mul(axes[2], direction[2] * size[2])))


def lobe(mesh, center, size, angle, tilt, color, seed, lod, tag, role="foliage"):
    """Scalloped closed branch pillow, with a nested silhouette contour.

    The middle tier keeps every other contour vertex and all axial extrema.
    Near subdivision adds
    curled shoulder geometry without changing the whole-branch crown plan.
    """
    axes = frame(angle, tilt)
    rng = random.Random(seed)
    phases = [rng.uniform(0., TAU) for _ in range(3)]
    contour = []
    count = (6 if lod else 12) if role == "snow" else (8 if lod else 16)
    for j in range(count):
        a = TAU * j / count
        ripple = 1 + .09 * math.sin(a * 3 + phases[0]) + .045 * math.sin(a * 5 + phases[1])
        # Pointed outer shoots and slightly asymmetric left/right fans.
        contour.append((math.cos(a) * ripple, math.sin(a) * ripple * (1 + .065 * math.cos(a + phases[2]))))
    # Poles and equator are identical in both LODs, limiting transition drift.
    rings = []
    latitudes = (-.58, 0., .58) if lod == 0 else (0.,)
    for latitude in latitudes:
        ring = []
        reach = math.sqrt(1 - latitude * latitude)
        for j, (x, y) in enumerate(contour):
            undulation = .055 * math.sin(j * 2.4 + phases[0]) * (1 - abs(latitude))
            direction = (x * reach, y * reach, latitude + undulation)
            p = ellipsoid_point(center, axes, size, direction)
            light = (.94 + .09 * latitude + .075 * math.sin(j * 1.9 + phases[1])) if role == "foliage" else (.99 + latitude * .02)
            tint = tuple(max(.005, min(1., c * light)) for c in color)
            ring.append(mesh.vertex(p, tint, (.5 + x * .45, .5 + y * .45), tag))
        rings.append(ring)
    for a, b in zip(rings, rings[1:]):
        for j in range(count):
            n = (j + 1) % count
            mesh.face((a[j], a[n], b[n]), role)
            mesh.face((a[j], b[n], b[j]), role)
    lower = mesh.vertex(ellipsoid_point(center, axes, size, (0., 0., -1.)), tuple(c * .93 for c in color), (.5, .5), tag)
    upper = mesh.vertex(ellipsoid_point(center, axes, size, (.07, -.025, 1.)), color, (.5, .5), tag)
    for j in range(count):
        n = (j + 1) % count
        mesh.face((lower, rings[0][n], rings[0][j]), role)
        mesh.face((upper, rings[-1][j], rings[-1][n]), role)
    return axes


def needle(mesh, origin, direction, length, width, color, tag):
    """Four-triangle opaque tapered needle; never a camera-facing card."""
    direction = unit(direction)
    side = unit(cross(direction, (0., .1, 1.)))
    normal = unit(cross(direction, side))
    a = mesh.vertex(add(origin, mul(side, width)), color, (0., .5), tag)
    b = mesh.vertex(add(origin, mul(side, -width)), tuple(c * .88 for c in color), (1., .5), tag)
    c = mesh.vertex(add(origin, mul(normal, width * .65)), tuple(min(1., c * 1.09) for c in color), (.5, 0.), tag)
    d = mesh.vertex(add(origin, mul(direction, length)), color, (.5, 1.), tag)
    for face in ((a, b, c), (a, d, b), (b, d, c), (c, d, a)):
        mesh.face(face, "foliage")


def needle_detail(mesh, center, size, angle, tilt, color, seed, tag, pine=False):
    rng = random.Random(seed ^ 0xA183)
    axes = frame(angle, tilt)
    for j in range(6):
        a = TAU * j / 6 + rng.uniform(-.17, .17)
        outward = (math.cos(a), math.sin(a), rng.uniform(.12, .5))
        origin = ellipsoid_point(center, axes, size, (outward[0] * .80, outward[1] * .80, .10 + .24 * math.sin(j)))
        for k in range(4):
            spread = (k - 1.5) * (.37 if pine else .23)
            d = add(add(mul(axes[0], math.cos(a + spread)), mul(axes[1], math.sin(a + spread))), mul(axes[2], rng.uniform(-.10, .50)))
            length = min(size[0], size[1]) * (.23 if pine else .28) * rng.uniform(.70, 1.05)
            needle(mesh, origin, d, length, length * (.045 if pine else .08), color, tag)


def needle_shell(mesh, center, size, angle, tilt, roll, seed, tag, lod, tile=0, tint=(.96, 1., .96), simple=False):
    """Bowed branch spray, UV-mapped to one real needle-atlas quadrant."""
    axes = frame(angle, tilt)
    long = axes[0]
    across = add(mul(axes[1], math.cos(roll)), mul(axes[2], math.sin(roll)))
    normal = unit(cross(long, across))
    tile_x, tile_y = tile % 2, (tile // 2) % 2
    tint = tuple(c * (.98 + .025 * math.sin(seed)) for c in tint)
    rows = []
    segments = 1 if simple else (4 if lod == 0 else 2)
    for j in range(segments + 1):
        t = j / segments
        row = []
        for side in ((-1., 1.) if simple else (-1., 0., 1.)):
            p = add(center, add(mul(long, (2 * t - 1) * size[0]), mul(across, side * size[1])))
            bow = math.sin(t * math.pi) * size[2] * .55 - abs(side) * size[2] * .31
            p = add(p, mul(normal, bow))
            uv = ((tile_x + (.04 + .92 * (side + 1) * .5)) * .5, (tile_y + .04 + .92 * t) * .5)
            row.append(mesh.vertex(p, tint, uv, tag))
        rows.append(row)
    for a, b in zip(rows, rows[1:]):
        for j in range(len(a) - 1):
            mesh.face((a[j], b[j], b[j + 1]), "foliage")
            mesh.face((a[j], b[j + 1], a[j + 1]), "foliage")


def needle_cloud(mesh, item, lod, family):
    """Shared dimensional cluster envelope; fine near sprays fill its surface."""
    center, size, angle, tilt, seed, tag = (item[k] for k in ("center", "size", "angle", "tilt", "seed", "tag"))
    pine = family == "pine"
    tile = {"spruce": 3, "fir": 1, "pine": 2}[family]
    tint = {"spruce": (.88, 1.0, .96), "fir": (.88, 1.02, 1.02), "pine": (1.04, 1.0, .81)}[family]
    # Two opposed folded shells maintain depth from oblique/side views.
    for roll in (-.82, .82):
        needle_shell(mesh, center, size, angle, tilt, roll, seed, tag, lod, tile, tint)
    rng = random.Random(seed ^ 0x719A)
    axes = frame(angle, tilt)
    for j in range(6):
        along = -.63 + .245 * j
        side = -1 if j % 2 else 1
        c = ellipsoid_point(center, axes, size, (along, side * .34, rng.uniform(-.24, .38)))
        branch_size = (size[0] * .46, size[1] * .53, size[2] * .55)
        branch_angle = angle + side * (.36 if pine else .47)
        child_tilt = tilt + rng.uniform(-.30, .15)
        child_roll = side * rng.uniform(.34, 1.35)
        # The middle tier keeps two opposing interior sprays at exact near
        # anchors. Four additional triangles close its interior coverage gap
        # without enlarging the silhouette or introducing big leaf blades.
        if lod == 0 or j in (2, 3):
            needle_shell(mesh, c, branch_size, branch_angle, child_tilt, child_roll, seed + j, tag, lod, tile, tint, simple=lod > 0)


def broadleaf(mesh, origin, direction, length, width, color, tag, maple=False, turn=0., simplified=False):
    """Small folded solid leaf; rounded birch and five-lobed maple outlines."""
    direction = unit(direction)
    side = unit(cross(direction, (math.sin(turn), math.cos(turn), .33)))
    normal = unit(cross(side, direction))
    outline = ((0., -.55), (.35, -.42), (.5, -.05), (.38, .36), (0., .68), (-.38, .36), (-.5, -.05), (-.35, -.42))
    if maple:
        outline = ((0., -.50), (.20, -.28), (.56, -.30), (.38, -.03), (.63, .20), (.24, .20), (0., .76), (-.24, .20), (-.63, .20), (-.38, -.03), (-.56, -.30), (-.20, -.28))
    if simplified:
        # More, smaller leaves keep the middle canopy granular. Fewer outline
        # vertices pay for that coverage without oversized star-shaped leaves.
        outline = ((0., -.55), (.5, -.05), (.38, .36), (0., .68), (-.38, .36), (-.5, -.05))
        if maple:
            outline = ((0., -.50), (.52, -.10), (.25, .19), (0., .70), (-.25, .19), (-.52, -.10), (-.20, -.32))
    ids = []
    for x, y in outline:
        p = add(origin, add(mul(side, x * width), mul(direction, y * length)))
        p = add(p, mul(normal, -.075 * abs(x) * length))
        ids.append(mesh.vertex(p, color, (.5 + x * .7, .4 + y * .75), tag))
    top = mesh.vertex(add(origin, mul(normal, length * .045)), tuple(min(1., c * 1.06) for c in color), (.5, .5), tag)
    for j in range(len(ids)):
        n = (j + 1) % len(ids)
        mesh.face((top, ids[j], ids[n]), "foliage")

    # Individual thin leaves are explicitly two-sided in the export material.
    # Each folded silhouette receives the matching half of the vein atlas.
    start = min(ids + [top])
    for k in range(start, len(mesh.uvs)):
        u, v = mesh.uvs[k]
        mesh.uvs[k] = ((.5 if maple else 0.) + u * .5, v)


def leaf_detail(mesh, center, size, angle, tilt, color, seed, tag, maple=False, lod=0):
    rng = random.Random(seed ^ 0x419B)
    axes = frame(angle, tilt)
    count = (20 if maple else 28) if lod == 0 else 8
    for j in range(count):
        z = 1 - 2 * (j + .5) / count
        a = j * 2.3999632297 + rng.uniform(-.22, .22)
        r = math.sqrt(max(0., 1 - z * z))
        origin = ellipsoid_point(center, axes, size, (math.cos(a) * r * (.78 if lod == 0 else .65), math.sin(a) * r * (.78 if lod == 0 else .65), z * (.72 if lod == 0 else .62)))
        direction = unit((math.cos(a + .4), math.sin(a + .4), rng.uniform(-.55, .65)))
        length = min(size) * rng.uniform(.91, 1.18) * (1 if lod == 0 else 1.45)
        tint = tuple(min(1., c * rng.uniform(.92, 1.10)) for c in color)
        broadleaf(mesh, origin, direction, length, length * (.9 if maple else .72), tint, tag, maple, a, simplified=lod > 0)


def trunk_point(t, height, variant, phase, broad=False):
    lean = (.012, -.018, .027, -.025)[(variant - 1) % 4]
    bend = (.016 if broad else .008) * math.sin(t * 4 + phase) * t
    return (height * (lean * t + bend), height * .014 * math.sin(t * 3.2 + phase) * t, height * t)


def trunk(mesh, height, variant, phase, color, lod, broad=False, broken=False):
    steps = 13 if lod == 0 else 8
    end = .94 if broken else 1.
    points = [trunk_point(end * i / steps, height, variant, phase, broad) for i in range(steps + 1)]
    factor = .012 if broad else .015
    radii = [height * factor * (1 - end * i / steps) ** .83 + height * .00045 for i in range(steps + 1)]
    radii[0] *= 1.32
    tube(mesh, points, radii, color, 11 if lod == 0 else 6, phase=phase)
    # Root flares are tree tissue, tapering into snow; no loose ground props.
    for k in range(5):
        a = k * TAU / 5 + phase
        start = (math.cos(a) * height * .024, math.sin(a) * height * .024, height * .001)
        middle = (start[0] * .43, start[1] * .43, height * .017)
        tube(mesh, [start, middle, points[0]], [height * .002, height * .007, height * .009], color, 5 if lod == 0 else 3, phase=a)
    return points


def ground_conifer_boughs(height, family, branches, lobes):
    """Raise complete low boughs, preserving the shared near/mid crown plan.

    A wide veteran crown can droop below the root plane. Test the actual spray
    vertices in both tiers, then translate that whole branch, snow, and pivot
    together. Never clip vertices, flatten triangles, or float the tree trunk.
    The tiny root-flare undershoot remains intentional terrain penetration.
    """
    offsets = {}
    for item in lobes:
        # A conservative support bound excludes the great majority of crowns
        # before generating any temporary geometry for the clearance check.
        if item["center"][2] - sum(item["size"]) > 0:
            continue
        minimum = 0.
        for lod in (0, 1):
            sample = Mesh(height)
            needle_cloud(sample, item, lod, family)
            minimum = min(minimum, min(vertex[2] for vertex in sample.vertices))
        if minimum < 0:
            offsets[item["tag"]] = max(offsets.get(item["tag"], 0.), height * .01 - minimum)
    if not offsets:
        return branches, lobes
    grounded = []
    for root, middle, tip, length, angle, index in branches:
        delta = (0., 0., offsets.get(tag_for(index, root[2]), 0.))
        grounded.append((add(root, delta), add(middle, delta), add(tip, delta), length, angle, index))
    for item in lobes:
        lift = offsets.get(item["tag"], 0.)
        if lift:
            item["center"] = add(item["center"], (0., 0., lift))
            item["tag"] = (item["tag"][0], item["tag"][1] - lift / 32.)
    return grounded, lobes


def conifer_plan(record):
    rng = random.Random(int(record["seed"]))
    family, variant = record["family"], int(record["variant"])
    h = float(record.get("height_m", record["nominal_height_m"]))
    phase = rng.uniform(0, TAU)
    branches, lobes = [], []
    levels = (12, 13, 14, 13)[variant - 1]
    crown_start = (.16, .20, .24, .15)[variant - 1]
    width = (.228, .218, .188, .246)[variant - 1]
    if family == "fir":
        width *= .96
        crown_start -= .025
    for level in range(levels):
        # Upper internodes get progressively shorter, retaining a full crown.
        t = crown_start + (.978 - crown_start) * (1 - (1 - level / (levels - 1)) ** 1.30)
        count = (5 if level < levels - 3 else 4) + (1 if variant == 4 and level < 3 else 0)
        for j in range(count):
            a = phase + j * TAU / count + level * 2.39996 + rng.uniform(-.16, .16)
            z = h * min(.981, t + rng.uniform(-.037, .037))
            root = trunk_point(z / h, h, variant, phase)
            length = h * width * ((1 - t) / (1 - crown_start)) ** .48 * rng.uniform(.83, 1.12)
            # A persistent asymmetric crown notch is a true form variant.
            if variant == 2 and math.cos(a - phase) > .60 and level in (2, 3, 4):
                length *= .72
            slope = (-.22 if family == "spruce" else -.08) + rng.uniform(-.14, .09)
            end = add(root, (math.cos(a) * length, math.sin(a) * length, length * slope))
            mid = mix(root, end, .52)
            mid = add(mid, (0., 0., length * .025))
            tip = add(end, (0., 0., length * (.015 if family == "spruce" else .12)))
            index = len(branches)
            branches.append((root, mid, tip, length, a, index))
            for p, s in ((.40, .43), (.77, .38)):
                center = mix(root, tip, p)
                center = add(center, (0., 0., length * (.12 if p < .5 else -.025)))
                size = (max(length * s, h * .022), max(length * (.35 if family == "spruce" else .38), h * .017), max(length * .23, h * .012))
                shade = rng.random()
                rgb = mix(*PALETTES[family], shade)
                # Inner ascending fans and outer hanging sprays close the crown
                # vertically, without stacking flat horizontal umbrellas.
                tilt = rng.uniform(.47, .93) if p < .5 else rng.uniform(-.55, -.18)
                if family == "fir":
                    tilt += .14
                lobes.append(dict(center=center, size=size, angle=a + rng.uniform(-.24, .24), tilt=tilt, color=srgb(rgb), seed=rng.randrange(1 << 30), tag=tag_for(index, z), snow=rng.random() < (.34 if family == "spruce" else .40)))
            if level < 4 and (j + level + variant) % 2 == 0:
                lateral = 1 if (j + level) % 2 else -1
                center = add(mix(root, tip, .53), (-math.sin(a) * length * .20 * lateral, math.cos(a) * length * .20 * lateral, length * .015))
                lobes.append(dict(center=center, size=(length * .27, length * .17, length * .085), angle=a + lateral * .58, tilt=slope, color=srgb(mix(*PALETTES[family], rng.random())), seed=rng.randrange(1 << 30), tag=tag_for(index, z), snow=rng.random() < .27))
    # Short, softly feathered leader replaces a solid cone at the crown tip.
    for k in range(5):
        z = h * (.955 + .007 * k)
        lobes.append(dict(center=trunk_point(z / h, h, variant, phase), size=(h * (.038 - .003 * k), h * (.027 - .002 * k), h * .025), angle=phase + k * 2.4, tilt=1.1, color=srgb(PALETTES[family][1]), seed=rng.randrange(1 << 30), tag=tag_for(11, h * .9), snow=False))
    branches, lobes = ground_conifer_boughs(h, family, branches, lobes)
    return h, phase, branches, lobes


def render_lobes(mesh, lobes, lod, family):
    for item in lobes:
        values = {key: item[key] for key in ("center", "size", "angle", "tilt", "color", "seed", "tag")}
        if family in ("golden", "maple"):
            leaf_detail(mesh, **values, maple=family == "maple", lod=lod)
        else:
            needle_cloud(mesh, item, lod, family)
        if item["snow"]:
            x, y, z = item["center"]
            sx, sy, sz = item["size"]
            # Snow lies above the upper foliage shoulder; narrow irregular caps
            # leave green branch margins and retain visible gaps between boughs.
            size = (sx * .66, sy * .48, max(.012, sz * .22))
            center = (x - math.cos(item["angle"]) * sx * .08, y - math.sin(item["angle"]) * sx * .08, z + sy * .43)
            lobe(mesh, center, size, item["angle"] + .06, item["tilt"] * .44, srgb((.885, .927, .962)), item["seed"] ^ 72, lod, item["tag"], "snow")


def build_conifer(mesh, record, lod):
    h, phase, branches, lobes = conifer_plan(record)
    wood = srgb((.395, .29, .205) if record["family"] == "spruce" else (.405, .375, .315))
    trunk(mesh, h, record["variant"], phase, wood, lod)
    for root, middle, tip, length, angle, index in branches:
        radius = max(h * .0014, length * .016)
        points = [root, mix(root, middle, .6), middle, tip] if lod == 0 else [root, tip]
        radii = [radius * (1 - k / len(points)) ** 1.4 + h * .0004 for k in range(len(points))]
        tube(mesh, points, radii, wood, 5 if lod == 0 else 3, tag_for(index, root[2]), angle, cap=lod == 0)
        if lod == 0:
            for j in (-1, 1):
                end = add(mix(root, tip, .68), (-math.sin(angle) * length * .23 * j, math.cos(angle) * length * .23 * j, length * .015))
                tube(mesh, [mix(root, tip, .3), end], [radius * .45, h * .00035], wood, 3, tag_for(index, root[2]))
    render_lobes(mesh, lobes, lod, record["family"])


def branching_plan(record, leafy=False, pine=False):
    rng = random.Random(int(record["seed"]))
    h, variant = float(record.get("height_m", record["nominal_height_m"])), int(record["variant"])
    phase = rng.uniform(0., TAU)
    family = record["family"]
    branches, lobes = [], []
    count = 16 if leafy else (17 if pine else 12)
    for i in range(count):
        t = (.37 if leafy else (.39 if pine else .26)) + (.49 if leafy or pine else .62) * i / (count - 1)
        a = phase + i * 2.39996 + rng.uniform(-.26, .26)
        root = trunk_point(t, h, variant, phase, True)
        width = (.25 if family == "maple" else (.24 if pine else .195))
        width *= (1., 1.13, .88, 1.05)[variant - 1]
        length = h * width * max(.3, math.sin((t - .22) * math.pi)) * rng.uniform(.77, 1.12)
        lift = length * (.48 if leafy else (.34 if pine else .70))
        bend = rng.uniform(-.35, .35)
        middle = add(root, (math.cos(a + bend) * length * .45, math.sin(a + bend) * length * .45, lift * .23))
        tip = add(root, (math.cos(a) * length, math.sin(a) * length, lift))
        if family == "golden":
            tip = add(tip, (0., 0., -.1 * length))
        branches.append(dict(points=[root, middle, tip], radius=h * (.0060 if pine else .0049) * rng.uniform(.72, 1.16), index=i, level=0))
        if pine:
            center = add(mix(root, tip, .52), (0., 0., length * .14))
            lobes.append(dict(center=center, size=(length * .46, length * .36, length * .29), angle=a + rng.uniform(-.20, .20), tilt=rng.uniform(.38, .83), color=srgb(mix(*PALETTES[family], rng.random())), seed=rng.randrange(1 << 30), tag=tag_for(i, root[2]), snow=i % 3 == 1))
        for j in range(3):
            side = (j - 1) * .66 + rng.uniform(-.15, .15)
            start = mix(middle, tip, .20 + j * .16)
            extension = length * rng.uniform(.36, .49)
            end = add(start, (math.cos(a + side) * extension, math.sin(a + side) * extension, extension * (.18 if pine else .45)))
            if family == "golden":
                end = add(end, (0., 0., -extension * .34))
            curve = add(mix(start, end, .55), (0., 0., extension * .12))
            branches.append(dict(points=[start, curve, end], radius=h * .0018 * rng.uniform(.8, 1.25), index=i, level=1))
            if leafy or pine:
                size = (extension * (1.18 if pine else .99), extension * (.91 if pine else .89), extension * (.62 if pine else .74))
                center = mix(start, end, .52 if pine else .70)
                center = add(center, (0., 0., size[2] * .26))
                lobes.append(dict(center=center, size=size, angle=a + side, tilt=rng.uniform(-.46, .68) if pine else .20, color=srgb(mix(*PALETTES[family], rng.random())), seed=rng.randrange(1 << 30), tag=tag_for(i, root[2]), snow=rng.random() < (.37 if pine else .16)))
            else:
                for k in range(3):
                    s = mix(start, end, .38 + k * .23)
                    angle = a + side + (k - 1) * .62
                    twiglen = extension * rng.uniform(.40, .63)
                    e = add(s, (math.cos(angle) * twiglen, math.sin(angle) * twiglen, twiglen * rng.uniform(.45, 1.2)))
                    branches.append(dict(points=[s, mix(s, e, .45), e], radius=h * .00073, index=i, level=2))
    if leafy or pine:
        # Crown bridges around the leader prevent a hollow parasol silhouette.
        for i in range(7):
            a = phase + i * 2.39996
            t = .83 + .02 * (i % 5)
            size = (h * .070, h * .067, h * (.047 if pine else .077))
            center = add(trunk_point(t, h, variant, phase, True), (math.cos(a) * h * .057, math.sin(a) * h * .057, 0.))
            lobes.append(dict(center=center, size=size, angle=a, tilt=.14, color=srgb(mix(*PALETTES[family], rng.random())), seed=rng.randrange(1 << 30), tag=tag_for(i, h * .7), snow=i in (1, 4)))
    return h, phase, branches, lobes


def build_branching(mesh, record, lod):
    family, variant = record["family"], int(record["variant"])
    leafy, pine = family in ("golden", "maple"), family == "pine"
    h, phase, branches, lobes = branching_plan(record, leafy, pine)
    wood = srgb((.77, .75, .67) if family in ("golden", "birch") else ((.44, .29, .17) if pine else (.395, .31, .235)))
    trunk(mesh, h, variant, phase, wood, lod, True)
    for branch in branches:
        points, radius, index = branch["points"], branch["radius"], branch["index"]
        level = branch["level"]
        sides = (7 if level == 0 else (5 if level == 1 else 3)) if lod == 0 else (4 if level == 0 else 3)
        tag = tag_for(index, branches[index * (4 if leafy or pine else 13)]["points"][0][2] if index * (4 if leafy or pine else 13) < len(branches) else points[0][2])
        if lod and level == 1 and (leafy or pine):
            points = [points[0], points[-1]]
        radii = [radius, h * .00025] if len(points) == 2 else [radius, radius * .56, h * .00025]
        tube(mesh, points, radii, wood, sides, tag, phase, cap=lod == 0)
        if lod == 0 and level == 2:
            for j in (-1, 1):
                start = mix(points[1], points[2], .18)
                delta = sub(points[2], points[1])
                end = add(points[2], (-delta[1] * .35 * j, delta[0] * .35 * j, h * .013))
                tube(mesh, [start, end], [h * .00037, h * .00009], wood, 3, tag)
        if not leafy and not pine and level == 0 and index % 3 == 1:
            center = add(points[1], (0., 0., radius * .85))
            direction = sub(points[2], points[0])
            angle = math.atan2(direction[1], direction[0])
            length = math.dist(points[0], points[2])
            lobe(mesh, center, (length * .22, radius * 1.45, radius * .5), angle, .22, srgb((.89, .93, .96)), int(record["seed"]) + index, lod, tag, "snow")
    render_lobes(mesh, lobes, lod, family)


def build_snag(mesh, record, lod):
    rng = random.Random(int(record["seed"]))
    h, variant = float(record.get("height_m", record["nominal_height_m"])), int(record["variant"])
    phase = rng.uniform(0., TAU)
    broken = record["family"] == "broken"
    wood = srgb((.495, .45, .375))
    trunk(mesh, h, variant, phase, wood, lod, True, broken)
    count = (9 if broken else 13) + variant
    for i in range(count):
        t = .19 + (.60 if broken else .68) * i / (count - 1)
        a = phase + i * 2.39996 + rng.uniform(-.4, .4)
        root = trunk_point(t, h, variant, phase, True)
        length = h * rng.uniform(.115, .21) * (1 - .45 * t)
        end = add(root, (math.cos(a) * length, math.sin(a) * length, length * rng.uniform(-.55, .65)))
        middle = add(mix(root, end, .59), (0., 0., length * .13))
        tag = tag_for(i, root[2])
        radius = h * rng.uniform(.0027, .0045)
        tube(mesh, [root, middle, end], [radius, radius * .58, h * .00045], wood, 7 if lod == 0 else 4, tag, a)
        for j in range(2 if broken else 3):
            start = mix(middle, end, .14 + .23 * j)
            angle = a + (j - 1) * .65
            tip = add(start, (math.cos(angle) * length * .34, math.sin(angle) * length * .34, length * rng.uniform(.12, .42)))
            tube(mesh, [start, tip], [radius * .39, h * .00016], wood, 5 if lod == 0 else 3, tag, a)
            if lod == 0 and (i + j) % 2 == 0:
                split = add(tip, (-math.sin(angle) * length * .10, math.cos(angle) * length * .10, length * .15))
                tube(mesh, [mix(start, tip, .6), split], [radius * .19, h * .00008], wood, 3, tag)
        if i % 4 == 1:
            lobe(mesh, add(middle, (0., 0., radius)), (length * .25, radius * 1.55, radius * .6), a, .06, srgb((.87, .92, .96)), int(record["seed"]) + i, lod, tag, "snow")
    if broken:
        # Separate sharp splinters form an irregular fractured crown, with no
        # flat circular saw cut and no foliage masquerading as a broken stem.
        root = trunk_point(.93, h, variant, phase, True)
        radius = h * .0042
        for i in range(7):
            a = phase + i * TAU / 7
            start = add(root, (math.cos(a) * radius, math.sin(a) * radius, 0.))
            end = add(start, (math.cos(a) * radius * .72, math.sin(a) * radius * .72, h * rng.uniform(.027, .074)))
            tube(mesh, [start, end], [radius * .44, radius * .025], srgb((.63, .46, .27)), 4 if lod == 0 else 3, phase=a)


def build(record: dict, lod: int) -> dict:
    """Return original tree geometry for near (0) or efficient middle (1/2).

    LOD2 is the same full-volume representation as LOD1; the runtime far tier
    should use multi-view captures of LOD0, not another geometry simplification.
    No input mutation, file I/O, global random state or generated timestamps.
    """
    if lod not in (0, 1, 2):
        raise ValueError("lod must be 0, 1 or 2")
    family = record["family"]
    if family not in ("spruce", "fir", "pine", "birch", "dead", "broken", "golden", "maple"):
        raise ValueError(f"Unsupported tree family: {family}")
    height = float(record.get("height_m", record["nominal_height_m"]))
    if height <= 0:
        raise ValueError("Tree height must be positive")
    mesh = Mesh(height)
    if family in ("spruce", "fir"):
        build_conifer(mesh, record, min(lod, 1))
    elif family in ("pine", "birch", "golden", "maple"):
        build_branching(mesh, record, min(lod, 1))
    else:
        build_snag(mesh, record, min(lod, 1))
    if family == "maple":
        # Terminal maple forks can overtop the nominal central stem. Normalize
        # the complete botanical shape once from the near crown's actual span,
        # then apply exactly the same uniform scale to every tier and pivot.
        reference = mesh
        if lod:
            reference = Mesh(height)
            build_branching(reference, record, 0)
        span = max(v[2] for v in reference.vertices) - min(v[2] for v in reference.vertices)
        scale = height / span
        mesh.vertices = [mul(v, scale) for v in mesh.vertices]
        mesh.tags = [(tag[0], 1. - (1. - tag[1]) * scale) for tag in mesh.tags]
    return mesh.result()

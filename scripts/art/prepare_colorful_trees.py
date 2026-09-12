"""Prepare six standalone trees. Never writes production assets or manifests.

Run with Blender through scripts/prepare_colorful_trees.ps1. Source generator
stays local; the saved blends contain only baked, editable derived geometry.
"""
import argparse
import hashlib
import json
import math
import random
import sys
import uuid
from pathlib import Path

import bpy
from mathutils import Vector
from mathutils.kdtree import KDTree

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).parent))
from colorful_tree_geometry import Geometry, export_glb, join, linear, material, simplify, tag
from bake_colorful_leaf_maps import bake

OUT = ROOT / 'art_source/trees/colorful_v1'
SOURCE = ROOT / 'TreeDesigner + 400 trees/TreeDesigner.blend'
RECIPES = {
    'golden_birch_01': ('BirchTree_LowPoly.032', 'rounded', 8.0, .28, (.88, .67, .16), 1901),
    'golden_birch_02': ('BirchTree_LowPoly.042', 'rounded', 11.0, .26, (.83, .57, .11), 1927),
    'golden_birch_03': ('BirchTree_LowPoly.054', 'rounded', 14.0, .29, (.82, .71, .23), 1953),
    'autumn_maple_01': ('MapleTree_LowPoly.032', 'lobed', 8.5, .38, (.76, .36, .095), 2111),
    'autumn_maple_02': ('MapleTree_LowPoly.033', 'lobed', 11.5, .4, (.63, .16, .10), 2137),
    'autumn_maple_03': ('MapleTree_LowPoly.034', 'lobed', 13.5, .42, (.83, .47, .10), 2163),
}


def source_geometry(preset, height, width, seed):
    with bpy.data.libraries.load(str(SOURCE), link=False) as (_, selected):
        selected.objects = [preset]
    original = selected.objects[0]
    assert original, preset
    bpy.context.scene.collection.objects.link(original)
    original.hide_viewport = False
    original.hide_render = False
    original.hide_set(False)
    modifier = next(m for m in original.modifiers if m.type == 'NODES')
    # Existing collection's bounded branch resolution; preserve each preset's
    # branching topology instead of forcing every family into a conifer recipe.
    settings = {'Socket_47': seed, 'Socket_40': seed + 11, 'Socket_174': True,
                'Socket_102': False, 'Socket_25': 10, 'Socket_50': 5,
                'Socket_57': 10, 'Socket_24': 16}
    for key, value in settings.items():
        getattr(modifier.properties.inputs, key).value = value
    bpy.context.view_layer.update()
    dg = bpy.context.evaluated_depsgraph_get()
    mesh = bpy.data.meshes.new_from_object(original.evaluated_get(dg), preserve_all_data_layers=True, depsgraph=dg)
    wood_faces = [p for p in mesh.polygons if p.material_index != 1]
    high = max(mesh.vertices[v].co.z for p in wood_faces for v in p.vertices)
    extent = max(math.hypot(mesh.vertices[v].co.x, mesh.vertices[v].co.y) for p in wood_faces for v in p.vertices)

    def transform(v):
        p = Vector((v.x * height * width / extent, v.y * height * width / extent, v.z * height / high))
        # Seat root geometry to the existing nominal proxy; integration will
        # perform the actual terrain-specific seating, without growing trunks.
        if p.z < height * .065:
            r = math.hypot(p.x, p.y)
            limit = .44 * height / 10.5
            if r > limit:
                p.x *= limit / r
                p.y *= limit / r
        return p

    uv = mesh.attributes.get('New Uv')
    wood = []
    indices = sorted({v for p in wood_faces for v in p.vertices})
    tree = KDTree(len(indices))
    for i, vi in enumerate(indices):
        tree.insert(transform(mesh.vertices[vi].co), i)
    tree.balance()
    candidates = []
    for p in mesh.polygons:
        points = [transform(mesh.vertices[v].co) for v in p.vertices]
        center = sum(points, Vector()) / len(points)
        if p.material_index == 1:
            if center.z > height * .24:
                anchor, _, distance = tree.find(center)
                candidates.append((anchor.copy(), center.copy()))
        else:
            tex = [tuple(uv.data[i].vector) for i in p.loop_indices] if uv else [(0, 0)] * len(points)
            wood.append((points, tex))
    assert len(candidates) > 40, f'Insufficient foliage attachment sites: {preset}'
    # Stable spatial thinning followed by deterministic sampling bounds leaf cost.
    occupied, sites = set(), []
    random.Random(seed).shuffle(candidates)
    for anchor, center in candidates:
        key = tuple(math.floor(v / (height * .022)) for v in anchor)
        if key in occupied:
            continue
        occupied.add(key)
        sites.append((anchor, center))
        if len(sites) == 210:
            break
    bpy.data.objects.remove(original, do_unlink=True)
    return wood, sites, settings


def build(name):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.preferences.filepaths.save_version = 0
    preset, shape, height, width, palette, seed = RECIPES[name]
    wood, sites, settings = source_geometry(preset, height, width, seed)
    bark = material('PreparedTree_Wood', ROOT / 'assets/graphics/textures/bark_albedo_low.jpg')
    leaves = material('PreparedTree_Leaves', leaf_maps=OUT / 'textures')
    snowmat = material('PreparedTree_Snow')
    records, objects = [], []
    for lod in (0, 1, 2):
        timber, foliage, snow = Geometry(), Geometry(), Geometry()
        for points, tex in wood:
            center = sum(points, Vector()) / len(points)
            tint = (.67, .61, .50) if shape == 'rounded' else (.44, .32, .21)
            timber.face(points, tint, tex, tag(center, height))
        timber_obj = timber.object(name + '_wood', bark, True)
        # Keep the near skeleton intact at every level. Stronger decimation of
        # these thin source branches tore trunks apart in native review. Far
        # production rendering should use the prepared directional atlases.
        simplify(timber_obj, 6200)
        selected = sites[::(1, 2, 4)[lod]]
        count = (6, 4, 3)[lod]
        leaf_count = 0
        for i, (anchor, center) in enumerate(selected):
            rng = random.Random(seed + int(anchor.x * 1000) + int(anchor.z * 1000))
            radial = Vector((center.x, center.y, height * .12)).normalized()
            direction = (center - anchor).normalized() if (center - anchor).length > .001 else radial
            for k in range(count):
                angle = k * 2.399 + rng.uniform(-.35, .35)
                along = Vector((math.cos(angle), math.sin(angle), rng.uniform(-.6, .7))).normalized()
                side = along.cross(Vector((0, 0, 1))).normalized()
                origin = anchor + direction * height * rng.uniform(.005, .04)
                origin += along * height * rng.uniform(.005, .026)
                size = height * rng.uniform(.026, .043) * (1, 1.6, 2.25)[lod]
                variance = rng.uniform(.76, 1.08)
                color = linear(tuple(min(1, c * variance) for c in palette))
                foliage.leaf(origin, along, side, size, shape, color, lod == 0, tag(anchor, height))
                # Visible petiole reaches the actual source branch anchor.
                petiole_width = size * .009
                foliage.face([anchor - side * petiole_width, anchor + side * petiole_width,
                              origin + side * petiole_width, origin - side * petiole_width],
                             (.12, .085, .025), tag=tag(anchor, height))
                # Small upper patches preserve warm crown color; distinct material
                # permits a later snow-mask conversion without recoloring bark.
                if k == 0 and i % 7 == 0:
                    z = Vector((0, 0, size * .13))
                    c = origin + along * size * .5 + z
                    snow.face([c - side * size * .19, c + along * size * .27,
                               c + side * size * .19, c - along * size * .12], (.82, .87, .91), tag=tag(anchor, height))
                leaf_count += 1
        parts = [timber_obj, foliage.object(name + '_leaves', leaves), snow.object(name + '_snow', snowmat)]
        obj = join(parts, name + f'_lod{lod}')
        obj['family'] = 'golden_birch' if shape == 'rounded' else 'autumn_maple'
        obj['leaf_type'] = shape
        obj['integration_status'] = 'prepared_only'
        path = OUT / 'models' / (obj.name + '.glb')
        record = export_glb(obj, path)
        record['leaf_count'] = leaf_count
        records.append(record)
        obj.hide_render = True
        obj.hide_set(True)
        objects.append(obj)
    objects[0].hide_render = False
    objects[0].hide_set(False)
    objects[0].asset_mark()
    objects[0].asset_data.catalog_id = str(uuid.uuid5(uuid.NAMESPACE_URL, 'alpine-apex/prepared-trees/' + objects[0]['family']))
    objects[0].asset_data.description = f'{name}: {shape} leaves, prepared for review; not integrated'
    for value in ('Alpine Apex', 'Prepared trees', shape):
        objects[0].asset_data.tags.new(value)
    # Leaf sample for scale-independent shape inspection and native preview.
    swatch = Geometry()
    swatch.leaf(Vector(), Vector((0, 0, 1)), Vector((1, 0, 0)), 1, shape, linear(palette))
    leaf = swatch.object(name + '_leaf', leaves)
    leaf_record = export_glb(leaf, OUT / 'models' / (name + '_leaf.glb'))
    leaf.hide_render = True
    leaf.hide_set(True)
    bpy.data.orphans_purge(do_recursive=True)
    bpy.ops.file.pack_all()
    blend = OUT / 'blends' / (name + '.blend')
    bpy.ops.wm.save_as_mainfile(filepath=str(blend), compress=True)
    result = {'id': name, 'family': objects[0]['family'], 'leaf_type': shape,
              'nominal_height_m': height, 'palette_srgb': palette, 'source_preset': preset,
              'seed': seed, 'source_settings': settings, 'attachment_sites': len(sites),
              'models': records, 'leaf_sample': leaf_record, 'blend': blend.name,
              'blend_sha256': hashlib.sha256(blend.read_bytes()).hexdigest()}
    print('PREPARED_TREE', name, 'sites', len(sites), 'triangles', [r['triangles'] for r in records], flush=True)
    return result


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--asset', choices=RECIPES)
    args = parser.parse_args(sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else [])
    for sub in ('models', 'blends'):
        (OUT / sub).mkdir(parents=True, exist_ok=True)
    (OUT / '.gdignore').touch()
    bake(OUT / 'textures')
    catalogs = ['# Blender Asset Catalog Definition File', 'VERSION 1', '']
    for family in ('golden_birch', 'autumn_maple'):
        cid = str(uuid.uuid5(uuid.NAMESPACE_URL, 'alpine-apex/prepared-trees/' + family))
        catalogs.append(f'{cid}:Prepared trees/{family}:{family}')
    (OUT / 'blends/blender_assets.cats.txt').write_text('\n'.join(catalogs) + '\n')
    manifest_path = OUT / 'manifest.json'
    manifest = json.loads(manifest_path.read_text()) if manifest_path.exists() else {'assets': []}
    identity = {p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest() for p in
                ('scripts/art/prepare_colorful_trees.py', 'scripts/art/colorful_tree_geometry.py',
                 'scripts/art/bake_colorful_leaf_maps.py',
                 'art_source/trees/colorful_v1/textures/bake.json',
                 'art_source/trees/colorful_v1/textures/provenance.json',
                 'assets/graphics/textures/bark_albedo_low.jpg')}
    manifest.update(schema=1, status='prepared_only_not_integrated', blender=bpy.app.version_string,
                    source='TreeDesigner + 400 trees/TreeDesigner.blend',
                    source_sha256=hashlib.sha256(SOURCE.read_bytes()).hexdigest(), authoring=identity,
                    coordinates='GLB: Y-up, metres; Blender: Z-up, metres',
                    material_contract='Three portable PBR surfaces: Wood, Leaves, Snow. COLOR_0 opaque; UV1 texture coordinates; UV2 branch sector/pivot compatible data. No production shader registration.',
                    lod_contract='LOD0 near geometry; LOD1 reduced geometry; LOD2 coarse geometry. Directional impostors prepared by the isolated native preview bake; integration remains deferred.')
    for name in RECIPES:
        if args.asset and name != args.asset:
            continue
        record = build(name)
        record['authoring'] = identity
        manifest['assets'] = [r for r in manifest['assets'] if r['id'] != name] + [record]
        manifest['assets'].sort(key=lambda r: r['id'])
        manifest_path.write_text(json.dumps(manifest, indent=2) + '\n')
    assert manifest['source_sha256'] == hashlib.sha256(SOURCE.read_bytes()).hexdigest()
    print('PREPARED_COLLECTION_COMPLETE', len(manifest['assets']), flush=True)


if __name__ == '__main__':
    main()

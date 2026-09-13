"""Extract the supplied generator's stone branch into cosmetic GLBs.

Run with guarded Blender --background --factory-startup --disable-autoexec
--python-exit-code 1 --python scripts/art/build_rock_pebbles.py [-- --rebuild].
Never saves over the supplied generator. No runtime placement or collision.
"""
import argparse
import hashlib
import json
import random
import struct
import sys
import time
from pathlib import Path

import bpy
from mathutils import Vector, noise

ROOT = Path(__file__).resolve().parents[2]
PACK = ROOT / 'art_source/rocks/pebbles_v1'
SOURCE = ROOT / 'art_source/blender/rock_generator.blend'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def activate(obj):
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj


def triangle_count(mesh):
    mesh.calc_loop_triangles()
    return len(mesh.loop_triangles)


def fit(mesh, dimensions):
    lower = Vector([min(v.co[i] for v in mesh.vertices) for i in range(3)])
    upper = Vector([max(v.co[i] for v in mesh.vertices) for i in range(3)])
    for vertex in mesh.vertices:
        for axis in range(3):
            vertex.co[axis] = ((vertex.co[axis] - lower[axis]) / (upper[axis] - lower[axis])
                               - (0.0 if axis == 2 else 0.5)) * dimensions[axis]
    mesh.update()


def stone_material():
    material = bpy.data.materials.new('CosmeticPebble_TexturedPBR')
    material.use_nodes = True
    material.use_backface_culling = True
    material.diffuse_color = (1, 1, 1, 1)
    nodes, links = material.node_tree.nodes, material.node_tree.links
    bsdf = nodes.get('Principled BSDF')
    bsdf.inputs['Metallic'].default_value = 0
    images = []
    uv_node = nodes.new('ShaderNodeUVMap')
    uv_node.uv_map = 'StoneUV'
    work = ROOT / 'artifacts/rock_pebble_scale_20260914/texture_work'
    work.mkdir(parents=True, exist_ok=True)
    for source_name, label, colorspace in [
            ('ROCK_Base Color.jpeg', 'Pebble_Albedo', 'sRGB'),
            ('ROCK_Normal.jpeg', 'Pebble_Normal', 'Non-Color'),
            ('ROCK_Roughness.jpeg', 'Pebble_Roughness', 'Non-Color')]:
        img = bpy.data.images[source_name].copy()
        img.name = label
        img.colorspace_settings.name = colorspace
        img.scale(1024, 1024)
        # A copied packed image can retain the original encoded 2K payload.
        # Save/reload the resized pixels before the portable glTF export.
        img.file_format = 'PNG'
        img.filepath_raw = str(work / (label + '.png'))
        img.save()
        resized = bpy.data.images.load(img.filepath_raw, check_existing=False)
        resized.colorspace_settings.name = colorspace
        resized.pack()
        bpy.data.images.remove(img)
        img = resized
        tex = nodes.new('ShaderNodeTexImage')
        tex.image = img
        tex.extension = 'REPEAT'
        links.new(uv_node.outputs['UV'], tex.inputs['Vector'])
        images.append(img)
        if label.endswith('Albedo'):
            tint = nodes.new('ShaderNodeVertexColor')
            tint.layer_name = 'Color'
            mix = nodes.new('ShaderNodeMixRGB')
            mix.blend_type = 'MULTIPLY'
            mix.inputs[0].default_value = 1
            links.new(tex.outputs['Color'], mix.inputs[1])
            links.new(tint.outputs['Color'], mix.inputs[2])
            links.new(mix.outputs[0], bsdf.inputs['Base Color'])
        elif label.endswith('Normal'):
            normal = nodes.new('ShaderNodeNormalMap')
            normal.uv_map = 'StoneUV'
            normal.inputs['Strength'].default_value = .22
            links.new(tex.outputs['Color'], normal.inputs['Color'])
            links.new(normal.outputs['Normal'], bsdf.inputs['Normal'])
        else:
            links.new(tex.outputs['Color'], bsdf.inputs['Roughness'])
    return material, images


def stone_uv(mesh, dimensions, seed):
    for existing in list(mesh.uv_layers):
        mesh.uv_layers.remove(existing)
    uv = mesh.uv_layers.new(name='StoneUV')
    uv.active_render = True
    rng = random.Random(seed)
    shift = Vector((rng.random(), rng.random()))
    # Metre-scaled box projection avoids the stretched poles of spherical UVs,
    # particularly on flat chips and coarse LODs. Small grit samples a small
    # part of the source stone texture instead of shrinking a whole cliff onto it.
    for polygon in mesh.polygons:
        axis = max(range(3), key=lambda i: abs(polygon.normal[i]))
        axes = [(1, 2), (0, 2), (0, 1)][axis]
        for loop in polygon.loop_indices:
            p = mesh.vertices[mesh.loops[loop].vertex_index].co
            uv.data[loop].uv = (p[axes[0]] / .23 + shift.x, p[axes[1]] / .23 + shift.y)


def share_glb_textures(path, texture_hashes):
    """Keep GLB geometry embedded and reuse three byte-identical PBR maps."""
    raw = path.read_bytes()
    json_size = struct.unpack_from('<I', raw, 12)[0]
    doc = json.loads(raw[20:20 + json_size])
    binary = raw[28 + json_size:]
    material = doc['materials'][0]
    pbr = material['pbrMetallicRoughness']
    roles = {'albedo': pbr['baseColorTexture']['index'],
             'normal': material['normalTexture']['index'],
             'metallic_roughness': pbr['metallicRoughnessTexture']['index']}
    removed = set()
    for role, texture in roles.items():
        image = doc['images'][doc['textures'][texture]['source']]
        index = image['bufferView']
        removed.add(index)
        view = doc['bufferViews'][index]
        data = binary[view.get('byteOffset', 0):view.get('byteOffset', 0) + view['byteLength']]
        ext = '.png' if image['mimeType'] == 'image/png' else '.jpg'
        filename = 'stone_' + role + ext
        digest = hashlib.sha256(data).hexdigest()
        if role in texture_hashes:
            assert texture_hashes[role]['sha256'] == digest, 'Unexpected per-mesh texture duplication'
        else:
            texture_path = PACK / 'textures' / filename
            texture_path.parent.mkdir(exist_ok=True)
            texture_path.write_bytes(data)
            texture_hashes[role] = {'path': 'textures/' + filename, 'sha256': digest,
                                    'bytes': len(data), 'size': [1024, 1024]}
        image.pop('bufferView')
        image.pop('mimeType')
        image['uri'] = '../textures/' + filename
    views, remap, packed = [], {}, bytearray()
    for index, view in enumerate(doc['bufferViews']):
        if index in removed:
            continue
        while len(packed) % 4:
            packed.append(0)
        start = view.get('byteOffset', 0)
        new = dict(view, byteOffset=len(packed))
        packed.extend(binary[start:start + view['byteLength']])
        remap[index] = len(views)
        views.append(new)
    for acc in doc['accessors']:
        if 'bufferView' in acc:
            acc['bufferView'] = remap[acc['bufferView']]
    doc['bufferViews'] = views
    doc['buffers'] = [{'byteLength': len(packed)}]
    while len(packed) % 4:
        packed.append(0)
    encoded = json.dumps(doc, separators=(',', ':')).encode()
    encoded += b' ' * (-len(encoded) % 4)
    data = struct.pack('<III', 0x46546C67, 2, 28 + len(encoded) + len(packed))
    data += struct.pack('<II', len(encoded), 0x4E4F534A) + encoded
    data += struct.pack('<II', len(packed), 0x004E4942) + packed
    # Exporters/Windows scanners can briefly hold the just-written GLB. Build
    # the compact payload separately and replace it only after a complete write.
    pending = path.with_suffix('.compact.tmp')
    pending.write_bytes(data)
    for attempt in range(20):
        try:
            pending.replace(path)
            break
        except OSError:
            if attempt == 19:
                raise
            time.sleep(.1)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--rebuild', action='store_true')
    args = parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
    recipe = json.loads((PACK / 'recipes.json').read_text())
    previous_path = PACK / 'manifest.json'
    if previous_path.exists():
        previous = json.loads(previous_path.read_text())
        if not args.rebuild:
            raise RuntimeError('Pack exists; use --rebuild after preserving any manual edits.')
        for record in previous['files']:
            if sha(PACK / record['path']) != record['sha256']:
                raise RuntimeError('Refusing to overwrite modified export: ' + record['path'])
    elif (PACK / 'models').exists() or (PACK / 'pebble_library.blend').exists():
        raise RuntimeError('Unreceipted outputs exist; inspect/preserve them before rebuilding.')
    source_hash = sha(SOURCE)
    bpy.ops.wm.open_mainfile(filepath=str(SOURCE), use_scripts=False)
    bpy.context.preferences.filepaths.save_version = 0
    generator = bpy.data.objects['Cube']
    graph = generator.modifiers[0].node_group.copy()
    generator.modifiers[0].node_group = graph
    # Reuse the actual stone shape before its instances, large rock or grass.
    graph.links.new(graph.nodes[recipe['source_branch']].outputs['Geometry'],
                    graph.nodes['Group Output'].inputs['Geometry'])
    position = graph.nodes.new('GeometryNodeInputPosition')
    offset = graph.nodes.new('ShaderNodeVectorMath')
    offset.operation = 'ADD'
    graph.links.new(position.outputs['Position'], offset.inputs[0])
    graph.links.new(offset.outputs['Vector'], graph.nodes['Noise Texture.004'].inputs['Vector'])
    for obj in list(bpy.data.objects):
        if obj != generator:
            bpy.data.objects.remove(obj, do_unlink=True)
    material, retained_images = stone_material()
    texture_hashes = {}
    model_dir = PACK / 'models'
    model_dir.mkdir(exist_ok=True)
    records, library = [], []
    for entry in recipe['assets']:
        dims = entry['dimensions_blender_xyz_m']
        assert .01 <= max(dims[0], dims[1]) <= .10, 'Cosmetic gravel must be 1-10 cm across'
        assert dims[2] <= .016, 'Cosmetic stone body is too tall'
        rng = random.Random(entry['seed'])
        offset.inputs[1].default_value = [rng.uniform(-100, 100) for _ in range(3)]
        graph.update_tag()
        generator.update_tag()
        bpy.context.view_layer.update()
        evaluated = generator.evaluated_get(bpy.context.evaluated_depsgraph_get())
        base = bpy.data.meshes.new_from_object(evaluated)
        assert len(base.vertices) > 0, 'Empty source stone branch'
        base.materials.clear()
        fit(base, entry['dimensions_blender_xyz_m'])
        models = []
        for lod, budget in enumerate(recipe['lod_triangle_budgets']):
            mesh = base.copy()
            obj = bpy.data.objects.new(entry['id'] + f'_lod{lod}', mesh)
            bpy.context.collection.objects.link(obj)
            activate(obj)
            if triangle_count(mesh) > budget:
                modifier = obj.modifiers.new('Pebble detail reduction', 'DECIMATE')
                modifier.ratio = budget / triangle_count(mesh)
                bpy.ops.object.modifier_apply(modifier=modifier.name)
            mesh = obj.data
            # Keep LOD extents/base identical; placement can share one transform.
            fit(mesh, entry['dimensions_blender_xyz_m'])
            stone_uv(mesh, entry['dimensions_blender_xyz_m'], entry['seed'])
            mesh.materials.append(material)
            for existing in list(mesh.color_attributes):
                mesh.color_attributes.remove(existing)
            colors = mesh.color_attributes.new(name='Color', type='FLOAT_COLOR', domain='POINT')
            for vertex in mesh.vertices:
                p = vertex.co / max(entry['dimensions_blender_xyz_m'])
                variation = 0.91 + 0.18 * (0.5 + 0.5 * noise.noise(p * 5 + Vector((entry['seed'] % 41, 3, 7))))
                tint = max(entry['linear_color'])
                colors.data[vertex.index].color = tuple(c / tint * variation for c in entry['linear_color']) + (1,)
            mesh.color_attributes.active_color = colors
            for polygon in mesh.polygons:
                polygon.use_smooth = entry['smooth']
                polygon.material_index = 0
            obj['asset_role'] = 'cosmetic_rock_pebble'
            obj['collision'] = False
            obj['source_seed'] = entry['seed']
            obj['lod'] = lod
            obj['units'] = 'metres'
            assert triangle_count(mesh) <= budget
            path = model_dir / (obj.name + '.glb')
            bpy.ops.export_scene.gltf(filepath=str(path), export_format='GLB', use_selection=True,
                                      export_yup=True, export_apply=True, export_extras=True,
                                      export_animations=False, export_cameras=False, export_lights=False,
                                      export_materials='EXPORT', export_normals=True,
                                      export_tangents=True, export_texcoords=True,
                                      export_vertex_color='NAME', export_vertex_color_name='Color',
                                      export_all_vertex_colors=False)
            share_glb_textures(path, texture_hashes)
            dims = entry['dimensions_blender_xyz_m']
            models.append({'file': path.name, 'sha256': sha(path), 'bytes': path.stat().st_size,
                           'lod': lod, 'triangles': triangle_count(mesh),
                           'dimensions_godot_xyz_m': [dims[0], dims[2], dims[1]]})
            library.append(obj)
        bpy.data.meshes.remove(base)
        records.append({'id': entry['id'], 'seed': entry['seed'], 'models': models})
        print('PEBBLE_EXPORTED', entry['id'], [m['triangles'] for m in models], flush=True)
    bpy.data.objects.remove(generator, do_unlink=True)
    for block in list(bpy.data.node_groups):
        bpy.data.node_groups.remove(block)
    for block in list(bpy.data.images):
        if block not in retained_images:
            bpy.data.images.remove(block)
    for index, obj in enumerate(library):
        obj.location = ((index // 3) * 0.38, (index % 3) * 0.3, 0)
        obj.asset_mark()
    bpy.data.orphans_purge(do_recursive=True)
    bpy.context.scene.unit_settings.system = 'METRIC'
    bpy.context.scene.unit_settings.scale_length = 1
    bpy.ops.wm.save_as_mainfile(filepath=str(PACK / 'pebble_library.blend'), compress=True)
    assert sha(SOURCE) == source_hash, 'Original generator changed'
    outputs = sorted(model_dir.glob('*.glb')) + [PACK / t['path'] for t in texture_hashes.values()] + [PACK / 'pebble_library.blend']
    # Replaced encoded image files were hash-checked before authoring. Remove
    # only those obsolete generated texture files from this owned package.
    if previous_path.exists():
        current = {p.resolve() for p in outputs}
        for record in previous['files']:
            old = (PACK / record['path']).resolve()
            if old.parent == (PACK / 'textures').resolve() and old not in current:
                old.unlink()
    manifest = {
        'version': recipe['version'], 'status': 'prepared_only_not_integrated',
        'source': SOURCE.relative_to(ROOT).as_posix(), 'source_sha256': source_hash,
        'source_branch': recipe['source_branch'], 'source_preserved': True,
        'builder': Path(__file__).relative_to(ROOT).as_posix(), 'builder_sha256': sha(Path(__file__)),
        'recipe_sha256': sha(PACK / 'recipes.json'), 'blender_version': bpy.app.version_string,
        'field_presets_sha256': sha(PACK / 'field_presets.json'),
        'collision': False, 'vegetation': False, 'terrain_or_pedestal_geometry': False,
        'cosmetic_size_limits': recipe['cosmetic_size_limits'],
        'material': {'name': material.name, 'opaque': True, 'normal_strength': .22,
                     'metallic': 0, 'vertex_color': 'COLOR_0 tint', 'textures': texture_hashes, 'surfaces_per_mesh': 1,
                     'source_images': ['ROCK_Base Color.jpeg', 'ROCK_Normal.jpeg', 'ROCK_Roughness.jpeg'],
                     'sharing': 'All GLBs reference the same ../textures files. Preserve the models/textures directory relationship.'},
        'coordinates': 'GLB metres Y-up; base y=0; centered XZ; identity node transforms',
        'assets': records,
        'files': [{'path': p.relative_to(PACK).as_posix(), 'sha256': sha(p), 'bytes': p.stat().st_size} for p in outputs],
    }
    previous_path.write_text(json.dumps(manifest, indent=2) + '\n')
    print('PEBBLE_PACK_COMPLETE', len(records), 'variants,', len(library), 'GLBs', flush=True)


if __name__ == '__main__':
    main()

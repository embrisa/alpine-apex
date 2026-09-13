"""Extract the supplied generator's stone branch into cosmetic GLBs.

Run with guarded Blender --background --factory-startup --disable-autoexec
--python-exit-code 1 --python scripts/art/build_rock_pebbles.py [-- --rebuild].
Never saves over the supplied generator. No runtime placement or collision.
"""
import argparse
import hashlib
import json
import random
import sys
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
    material = bpy.data.materials.new('CosmeticPebble_VertexPBR')
    material.use_nodes = True
    material.use_backface_culling = True
    material.diffuse_color = (1, 1, 1, 1)
    bsdf = material.node_tree.nodes.get('Principled BSDF')
    bsdf.inputs['Roughness'].default_value = 0.93
    bsdf.inputs['Metallic'].default_value = 0
    color = material.node_tree.nodes.new('ShaderNodeVertexColor')
    color.layer_name = 'Color'
    material.node_tree.links.new(color.outputs['Color'], bsdf.inputs['Base Color'])
    model_dir = PACK / 'models'
    model_dir.mkdir(exist_ok=True)
    records, library = [], []
    for entry in recipe['assets']:
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
            mesh.materials.append(material)
            colors = mesh.color_attributes.new(name='Color', type='FLOAT_COLOR', domain='POINT')
            for vertex in mesh.vertices:
                p = vertex.co / max(entry['dimensions_blender_xyz_m'])
                variation = 0.91 + 0.18 * (0.5 + 0.5 * noise.noise(p * 5 + Vector((entry['seed'] % 41, 3, 7))))
                colors.data[vertex.index].color = tuple(c * variation for c in entry['linear_color']) + (1,)
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
                                      export_all_vertex_colors=True)
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
        bpy.data.images.remove(block)
    for index, obj in enumerate(library):
        obj.location = ((index // 3) * 0.38, (index % 3) * 0.3, 0)
        obj.asset_mark()
    bpy.data.orphans_purge(do_recursive=True)
    bpy.context.scene.unit_settings.system = 'METRIC'
    bpy.context.scene.unit_settings.scale_length = 1
    bpy.ops.wm.save_as_mainfile(filepath=str(PACK / 'pebble_library.blend'), compress=True)
    assert sha(SOURCE) == source_hash, 'Original generator changed'
    outputs = sorted(model_dir.glob('*.glb')) + [PACK / 'pebble_library.blend']
    manifest = {
        'version': recipe['version'], 'status': 'prepared_only_not_integrated',
        'source': SOURCE.relative_to(ROOT).as_posix(), 'source_sha256': source_hash,
        'source_branch': recipe['source_branch'], 'source_preserved': True,
        'builder': Path(__file__).relative_to(ROOT).as_posix(), 'builder_sha256': sha(Path(__file__)),
        'recipe_sha256': sha(PACK / 'recipes.json'), 'blender_version': bpy.app.version_string,
        'collision': False, 'vegetation': False, 'terrain_or_pedestal_geometry': False,
        'material': {'name': material.name, 'opaque': True, 'roughness': 0.93,
                     'metallic': 0, 'vertex_color': 'COLOR_0', 'textures': 0, 'surfaces_per_mesh': 1},
        'coordinates': 'GLB metres Y-up; base y=0; centered XZ; identity node transforms',
        'assets': records,
        'files': [{'path': p.relative_to(PACK).as_posix(), 'sha256': sha(p), 'bytes': p.stat().st_size} for p in outputs],
    }
    previous_path.write_text(json.dumps(manifest, indent=2) + '\n')
    print('PEBBLE_PACK_COMPLETE', len(records), 'variants,', len(library), 'GLBs', flush=True)


if __name__ == '__main__':
    main()

"""V3 detail bake: original GN surfaces and material, no voxel smoothing.

Blender --background --factory-startup --disable-autoexec --python-exit-code 1
--python scripts/art/rebuild_mineral_detail_library.py [-- --asset NAME]
The v2 exports and the supplied source remain untouched. An interrupted run
resumes from verified hashes. Recipe composition is shared with the v2 builder.
"""
import ast
import bpy
import hashlib
import json
import math
import random
import sys
import time
import numpy as np
from pathlib import Path
from mathutils import Vector, Matrix, noise

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'art_source/blender/rock_generator.blend'
OUT = ROOT / 'assets/graphics/minerals_v3'
ART = ROOT / 'art_source/blender/minerals_v3'
QA = ROOT / 'artifacts/minerals_v3'
CATEGORIES = ['small', 'medium', 'large', 'huge_boulders', 'cliffs']
FAMILIES = ['rounded', 'fractured', 'sedimentary', 'outcrop', 'cliff', 'glacier']
CATEGORY_FAMILIES = {c: FAMILIES for c in CATEGORIES[:3]}
CATEGORY_FAMILIES['huge_boulders'] = ['erratic', 'block', 'split', 'dome', 'overhang', 'monolith']
CATEGORY_FAMILIES['cliffs'] = ['wall', 'layered_wall', 'corner', 'recess', 'overhang_wall', 'buttress']
LENGTHS = {'small': [.35, .60, .90, 1.2], 'medium': [2, 3.2, 4.8, 6.5],
           'large': [10, 16, 24, 36], 'huge_boulders': [40, 55, 75, 100], 'cliffs': [60, 100, 150, 220]}
BUDGETS = dict(zip(CATEGORIES, [6000, 18000, 45000, 90000, 120000]))
FILTER = sys.argv[sys.argv.index('--asset')+1] if '--asset' in sys.argv else None


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def activate(obj):
    bpy.ops.object.select_all(action='DESELECT')
    obj.hide_set(False)
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj


def triangles(obj):
    obj.data.calc_loop_triangles()
    return len(obj.data.loop_triangles)


def fit(mesh, dims, bottom=True):
    values = np.empty(len(mesh.vertices)*3,dtype=np.float32)
    mesh.vertices.foreach_get('co',values)
    points = values.reshape(-1,3)
    lo, hi = points.min(axis=0), points.max(axis=0)
    points[:] = ((points-lo)/(hi-lo)-np.array([.5,.5,0 if bottom else .5],dtype=np.float32))*np.asarray(dims,dtype=np.float32)
    mesh.vertices.foreach_set('co',values)
    mesh.update()


def generated_part(seed, variation, dims, loc=(0, 0, 0), tilt=(0, 0, 0), rounded=False):
    constants['Seed'].integer = seed
    constants['Variation'].integer = variation
    graph.update_tag()
    generator.update_tag()
    bpy.context.view_layer.update()
    ev = generator.evaluated_get(bpy.context.evaluated_depsgraph_get())
    mesh = bpy.data.meshes.new_from_object(ev)
    assert len(mesh.vertices), (seed, variation)
    # Preserve source-local coordinates for its layered procedural material,
    # even after each part is fitted, rotated and joined into a formation.
    attribute = mesh.attributes.new('generator_position', 'FLOAT_VECTOR', 'POINT')
    coordinates = np.empty(len(mesh.vertices)*3,dtype=np.float32)
    mesh.vertices.foreach_get('co', coordinates)
    attribute.data.foreach_set('vector', coordinates)
    obj = bpy.data.objects.new('Source part ' + str(seed), mesh)
    bpy.context.collection.objects.link(obj)
    fit(mesh, (1, 1, 1), False)
    if rounded:
        weight = .42 if rounded is True else min(float(rounded)*.55, .42)
        for v in mesh.vertices:
            p = v.co.copy()
            if p.length > .001:
                target = p.normalized()*(.50+.025*noise.noise(p*5+Vector((seed % 31, 3, 9))))
                v.co = p.lerp(target, weight)
    fit(mesh, dims)
    rotation = Matrix.Rotation(tilt[2], 4, 'Z') @ Matrix.Rotation(tilt[1], 4, 'Y') @ Matrix.Rotation(tilt[0], 4, 'X')
    mesh.vertices.foreach_get('co',coordinates)
    points = coordinates.reshape(-1,3)
    points[:] = points @ np.asarray(rotation.to_3x3(),dtype=np.float32).T + np.asarray(loc,dtype=np.float32)
    mesh.vertices.foreach_set('co',coordinates)
    mesh.polygons.foreach_set('use_smooth',np.ones(len(mesh.polygons),dtype=bool))
    mesh.update()
    return obj


# Load only this pure composition function, without executing the old builder.
recipe_ast = ast.parse((ROOT/'scripts/art/build_mineral_library.py').read_text())
recipe = next(n for n in recipe_ast.body if isinstance(n, ast.FunctionDef) and n.name == 'compose_shape_parts')
exec(compile(ast.Module(body=[recipe], type_ignores=[]), str(ROOT/'scripts/art/build_mineral_library.py'), 'exec'))


def setup():
    global generator, graph, constants, ice
    bpy.ops.wm.open_mainfile(filepath=str(SOURCE), use_scripts=False)
    generator = bpy.data.objects['Cube']
    graph = generator.modifiers[0].node_group.copy()
    generator.modifiers[0].node_group = graph
    constants = {}
    for name, value in [('Seed', 69), ('Variation', 0), ('Stone Density', 3), ('Add Grass', 0)]:
        node = graph.nodes.new('FunctionNodeInputInt')
        node.integer = value
        for link in list(graph.links):
            if link.from_node.bl_idname == 'NodeGroupInput' and link.from_socket.name == name:
                graph.links.new(node.outputs[0], link.to_socket)
        constants[name] = node
    graph.nodes['Subdivide Mesh'].inputs['Level'].default_value = 5
    # Each composed part is the actual rock body. Repeating the source's wide
    # display pedestal in every layer produces artificial fins and sandwiches.
    graph.links.new(graph.nodes['Convex Hull'].outputs[0], graph.nodes['Subdivide Mesh'].inputs['Mesh'])
    output = graph.nodes['Group Output'].inputs['Geometry']
    graph.links.new(graph.nodes['Set Material'].outputs['Geometry'], output)
    # Avoid reevaluating an unnecessary live generator during every bake.
    generator.hide_render = True
    for obj in list(bpy.context.scene.objects):
        if obj != generator and obj.name != 'grass':
            bpy.data.objects.remove(obj, do_unlink=True)
    if bpy.data.objects.get('grass'):
        bpy.data.objects['grass'].hide_render = True
    for name in ['Rock', 'Stone']:
        mat = bpy.data.materials[name]
        nodes, links = mat.node_tree.nodes, mat.node_tree.links
        attr = nodes.new('ShaderNodeAttribute')
        attr.attribute_name = 'generator_position'
        for link in list(links):
            if (link.from_node.type == 'TEX_COORD' and link.from_socket.name == 'Object') or (link.from_node.type == 'NEW_GEOMETRY' and link.from_socket.name == 'Position'):
                links.new(attr.outputs['Vector'], link.to_socket)
        for n in nodes:
            if n.type == 'TEX_IMAGE' and n.image and n.image.name.startswith('ROCK_') and not n.inputs['Vector'].is_linked:
                mapping = nodes.get('Mapping')
                if mapping:
                    links.new(mapping.outputs['Vector'], n.inputs['Vector'])
    texdir = OUT/'textures'; texdir.mkdir(exist_ok=True)
    detail_path = texdir/'rock_detail.jpg'
    if not detail_path.exists():
        detail_path.write_bytes(bpy.data.images['ROCK_Base Color.jpeg'].packed_file.data)
    grass_path = texdir/'grass.png'
    if not grass_path.exists():
        grass_path.write_bytes(bpy.data.images['grass.png'].packed_file.data)
    ice = bpy.data.materials.new('Glacial ice source')
    ice.use_nodes = True
    n, l = ice.node_tree.nodes, ice.node_tree.links
    bs = n.get('Principled BSDF')
    bs.inputs['Roughness'].default_value = .3
    bs.inputs['IOR'].default_value = 1.31
    geom = n.new('ShaderNodeNewGeometry')
    xyz = n.new('ShaderNodeSeparateXYZ')
    l.new(geom.outputs['Normal'], xyz.inputs[0])
    ramp = n.new('ShaderNodeValToRGB')
    ramp.color_ramp.elements[0].position = .25
    ramp.color_ramp.elements[0].color = (.06, .25, .37, 1)
    ramp.color_ramp.elements[1].position = .87
    ramp.color_ramp.elements[1].color = (.80, .94, 1, 1)
    l.new(xyz.outputs['Z'], ramp.inputs[0]); l.new(ramp.outputs[0], bs.inputs['Base Color'])
    tex = n.new('ShaderNodeTexNoise'); tex.inputs['Scale'].default_value = 32
    tex.inputs['Detail'].default_value = 4
    bump = n.new('ShaderNodeBump'); bump.inputs['Strength'].default_value = .24
    bump.inputs['Distance'].default_value = .006
    l.new(tex.outputs['Fac'], bump.inputs['Height']); l.new(bump.outputs[0], bs.inputs['Normal'])
    scene = bpy.context.scene
    scene.unit_settings.system = 'METRIC'
    scene.render.engine = 'CYCLES'
    scene.cycles.samples = 8
    prefs = bpy.context.preferences.addons['cycles'].preferences
    prefs.compute_device_type = 'HIP'
    prefs.get_devices()
    for device in prefs.devices:
        device.use = device.type == 'HIP'
    scene.cycles.device = 'GPU' if any(d.use for d in prefs.devices) else 'CPU'
    scene.render.bake.use_selected_to_active = True
    scene.render.bake.use_pass_direct = False
    scene.render.bake.use_pass_indirect = False
    scene.render.bake.use_pass_color = True
    scene.render.bake.use_clear = True
    scene.render.bake.margin = 6
    bpy.context.preferences.filepaths.save_version = 0


def build(category, family, variant):
    start = time.time()
    # Ice contains no loose rock chips.
    constants['Stone Density'].integer = 0 if family == 'glacier' else 3
    if family == 'sedimentary':
        seed = 920700 + CATEGORIES.index(category)*10000 + FAMILIES.index(family)*1000 + variant*83
        parts = [generated_part(seed, variant, (1, .72+variant*.04, .48+variant*.06),
                                tilt=(0, .02*(variant-1), variant*.18))]
    else:
        parts, seed = compose_shape_parts(category, family, variant)
    activate(parts[0])
    for obj in parts:
        obj.select_set(True)
    bpy.ops.object.join()
    high = bpy.context.object
    high.name = 'High source ' + str(seed)
    if family == 'glacier':
        high.data.materials.clear(); high.data.materials.append(ice)
        for p in high.data.polygons: p.material_index = 0
    high_count = triangles(high)
    low = high.copy(); low.data = high.data.copy()
    bpy.context.collection.objects.link(low)
    low.name = f'mineral_{category}_{family}_{variant+1:02}'
    activate(low)
    dec = low.modifiers.new('Silhouette preserving game mesh', 'DECIMATE')
    dec.ratio = (BUDGETS[category]-40)/high_count
    bpy.ops.object.modifier_apply(modifier=dec.name)
    tr = low.modifiers.new('Portable triangles', 'TRIANGULATE')
    bpy.ops.object.modifier_apply(modifier=tr.name)
    low.data.validate()
    low.data.materials.clear()
    mat = bpy.data.materials.new(low.name+'_PBR'); mat.use_nodes = True
    mat.use_backface_culling = True
    low.data.materials.append(mat)
    for p in low.data.polygons:
        p.material_index = 0; p.use_smooth = True
    bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=.0005)
    bpy.ops.object.mode_set(mode='OBJECT')
    bpy.context.view_layer.update()
    span = max(high.dimensions)
    scene = bpy.context.scene
    scene.render.bake.cage_extrusion = span*.003
    scene.render.bake.max_ray_distance = span*.02
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    bs = nodes.get('Principled BSDF')
    images = []
    sizes = {'albedo': 1024 if category == 'small' else 2048,
             'normal': 2048 if category == 'small' else 4096, 'roughness': 1024}
    for label, kind in [('albedo', 'DIFFUSE'), ('normal', 'NORMAL'), ('roughness', 'ROUGHNESS')]:
        img = bpy.data.images.new(low.name+'_'+label, width=sizes[label], height=sizes[label], alpha=False)
        if label != 'albedo': img.colorspace_settings.name = 'Non-Color'
        node = nodes.new('ShaderNodeTexImage'); node.image = img; nodes.active = node
        activate(low); high.hide_render = False; high.hide_set(False); high.select_set(True)
        bpy.ops.object.bake(type=kind)
        # Save temporarily outside the imported asset tree. GLB embeds these maps.
        img.file_format = 'PNG'; img.filepath_raw = str(QA/(low.name+'_'+label+'.png'))
        img.save(); img.pack(); images.append(img)
        if label == 'normal':
            normal = nodes.new('ShaderNodeNormalMap')
            links.new(node.outputs['Color'], normal.inputs['Color'])
            links.new(normal.outputs['Normal'], bs.inputs['Normal'])
        else:
            links.new(node.outputs['Color'], bs.inputs['Base Color' if label == 'albedo' else 'Roughness'])
    # A map used for an earlier pass can remain connected, but the high source
    # alone contributes to selected-to-active passes.
    high.hide_render = True
    activate(low)
    bpy.context.view_layer.update()
    dims = low.dimensions.copy()*LENGTHS[category][variant]/max(low.dimensions)
    fit(low.data, dims)
    if low.data.attributes.get('generator_position'):
        low.data.attributes.remove(low.data.attributes['generator_position'])
    low['asset_id'] = low.name; low['units'] = 'metres'; low['size_category'] = category
    low['family'] = family; low['seed'] = seed; low['variation'] = variant
    low['generator_version'] = 'mineral-library-v3-detail'
    folder = OUT/category; folder.mkdir(parents=True, exist_ok=True)
    path = folder/(low.name+'.glb')
    bpy.ops.export_scene.gltf(filepath=str(path), export_format='GLB', use_selection=True,
                             export_apply=True, export_animations=False, export_extras=True,
                             export_cameras=False, export_lights=False, export_image_format='AUTO')
    bpy.context.view_layer.update()
    raw = path.read_bytes(); doc = json.loads(raw[20:20+int.from_bytes(raw[12:16], 'little')])
    primitive = doc['meshes'][0]['primitives'][0]
    assert len(doc['meshes']) == 1 and len(doc['meshes'][0]['primitives']) == 1
    assert 'TEXCOORD_0' in primitive['attributes']
    assert 'normalTexture' in doc['materials'][0]
    assert len(doc['images']) == 3
    assert triangles(low) <= BUDGETS[category]
    assert all(math.isfinite(c) for v in low.data.vertices for c in v.co)
    result = {'asset': low.name, 'category': category, 'family': family, 'variant': variant+1,
              'seed': seed, 'dimensions_blender_xyz_m': list(low.dimensions),
              'dimensions_godot_xyz_m': [low.dimensions.x, low.dimensions.z, low.dimensions.y],
              'triangles': triangles(low), 'high_source_triangles': high_count,
              'texture_sizes': sizes, 'path': path.relative_to(ROOT).as_posix(),
              'sha256': sha(path), 'bytes': path.stat().st_size, 'elapsed_seconds': round(time.time()-start, 1)}
    if FILTER:
        # The high mesh uses normalized composition coordinates; game mesh is in metres.
        bpy.ops.wm.save_as_mainfile(filepath=str(ART/(low.name+'.blend')), compress=True)
    for obj in [low, high]:
        mesh = obj.data; bpy.data.objects.remove(obj, do_unlink=True); bpy.data.meshes.remove(mesh)
    bpy.data.materials.remove(mat)
    for img in images:
        file = Path(img.filepath_raw)
        bpy.data.images.remove(img)
        file.unlink(missing_ok=True)
    for mesh in list(bpy.data.meshes):
        if mesh.users == 0:
            bpy.data.meshes.remove(mesh)
    print('DETAIL_ASSET', json.dumps(result), flush=True)
    return result


def main():
    for folder in [OUT, ART, QA]: folder.mkdir(parents=True, exist_ok=True)
    source_hash = sha(SOURCE)
    old = json.loads((ROOT/'assets/graphics/minerals/manifest.json').read_text())
    manifest_path = OUT/'manifest.json'
    manifest = json.loads(manifest_path.read_text()) if manifest_path.exists() else {
        'version': 'mineral-library-v3-detail', 'source_sha256': source_hash,
        'categories': LENGTHS, 'category_families': CATEGORY_FAMILIES,
        'triangle_budgets': BUDGETS, 'surface_default': 'bare rock; frost on glacier assets',
        'collision': 'Visual surfaces with intersecting shells; no gameplay collision',
        'assets': []}
    setup()
    for category in CATEGORIES:
        for family in CATEGORY_FAMILIES[category]:
            for variant in range(4):
                name = f'mineral_{category}_{family}_{variant+1:02}'
                if FILTER and name != FILTER: continue
                prior = next((r for r in manifest['assets'] if r['asset'] == name), None)
                if prior and (ROOT/prior['path']).exists() and sha(ROOT/prior['path']) == prior['sha256'] and not FILTER:
                    continue
                result = build(category, family, variant)
                manifest['assets'] = [r for r in manifest['assets'] if r['asset'] != name] + [result]
                manifest['asset_count'] = len(manifest['assets'])
                manifest_path.write_text(json.dumps(manifest, indent=2)+'\n')
    assert sha(SOURCE) == source_hash
    for row in old['assets']:
        assert sha(ROOT/row['path']) == row['sha256'], row['asset']
    manifest['source_preserved'] = True; manifest['v2_exports_preserved'] = True
    manifest_path.write_text(json.dumps(manifest, indent=2)+'\n')
    print('DETAIL_LIBRARY_COMPLETE', manifest['asset_count'], flush=True)


if __name__ == '__main__':
    main()

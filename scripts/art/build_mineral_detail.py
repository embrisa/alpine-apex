"""Preserve the supplied generator's detail, then bake it for game export.

Run with Blender --background --factory-startup --disable-autoexec --python
scripts/art/build_mineral_detail.py. Writes a separate review pack; source and
the existing 120-asset library are never overwritten.
"""
import bpy
import hashlib
import json
import math
import sys
import time
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'rock_generator.blend'
ART = ROOT / 'art_source/blender/mineral_detail'
OUT = ROOT / 'artifacts/mineral_detail/prototype_assets'
QA = ROOT / 'artifacts/mineral_detail'


def activate(obj):
    bpy.ops.object.select_all(action='DESELECT')
    obj.hide_set(False)
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj


def count(obj):
    obj.data.calc_loop_triangles()
    return len(obj.data.loop_triangles)


def setup_studio():
    scene = bpy.context.scene
    world = bpy.data.worlds.new('Detail review neutral studio')
    world.use_nodes = True
    world.node_tree.nodes['Background'].inputs[0].default_value = (.32, .37, .43, 1)
    world.node_tree.nodes['Background'].inputs[1].default_value = .35
    scene.world = world
    data = bpy.data.lights.new('Large soft key', 'AREA')
    obj = bpy.data.objects.new(data.name, data)
    scene.collection.objects.link(obj)
    obj.location = (-9, -10, 16)
    data.energy = 2500
    data.size = 9
    obj.rotation_euler = (Vector((0, 0, 2))-obj.location).to_track_quat('-Z', 'Y').to_euler()
    data = bpy.data.lights.new('Raking daylight', 'SUN')
    obj = bpy.data.objects.new(data.name, data)
    scene.collection.objects.link(obj)
    data.energy = 2
    data.angle = .15
    obj.rotation_euler = (.45, -.65, -.6)
    data = bpy.data.cameras.new('Detail review camera')
    camera = bpy.data.objects.new(data.name, data)
    scene.collection.objects.link(camera)
    data.type = 'ORTHO'
    data.ortho_scale = 21
    camera.location = (21, -28, 19)
    camera.rotation_euler = (Vector((0, 0, 1.8))-camera.location).to_track_quat('-Z', 'Y').to_euler()
    scene.camera = camera
    scene.render.engine = 'BLENDER_EEVEE'
    scene.render.resolution_x = 1600
    scene.render.resolution_y = 1200
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = 'PNG'
    scene.view_settings.view_transform = 'AgX'
    scene.render.film_transparent = False
    return camera


def render(obj, name):
    for other in bpy.context.scene.objects:
        if other.type == 'MESH':
            other.hide_render = other != obj
    obj.hide_set(False)
    scene = bpy.context.scene
    scene.render.engine = 'BLENDER_EEVEE'
    scene.render.filepath = str(QA / (name + '.png'))
    bpy.ops.render.render(write_still=True)


def prepare():
    bpy.ops.wm.open_mainfile(filepath=str(SOURCE), use_scripts=False)
    generator = bpy.data.objects['Cube']
    graph = generator.modifiers[0].node_group.copy()
    generator.modifiers[0].node_group = graph
    grass = graph.nodes.new('FunctionNodeInputInt')
    grass.integer = 0
    for link in list(graph.links):
        if link.from_node.bl_idname == 'NodeGroupInput' and link.from_socket.name == 'Add Grass':
            graph.links.new(grass.outputs[0], link.to_socket)
    output = graph.nodes['Group Output'].inputs['Geometry']
    realize = graph.nodes.new('GeometryNodeRealizeInstances')
    graph.links.new(output.links[0].from_socket, realize.inputs['Geometry'])
    graph.links.new(realize.outputs[0], output)
    graph.update_tag()
    generator.update_tag()
    bpy.context.view_layer.update()
    evaluated = generator.evaluated_get(bpy.context.evaluated_depsgraph_get())
    mesh = bpy.data.meshes.new_from_object(evaluated)
    high = bpy.data.objects.new('Source_bare_seed69', mesh)
    bpy.context.collection.objects.link(high)
    high.matrix_world = generator.matrix_world.copy()
    for obj in list(bpy.context.scene.objects):
        if obj != high:
            bpy.data.objects.remove(obj, do_unlink=True)
    for poly in high.data.polygons:
        poly.use_smooth = True
    camera = setup_studio()
    report = {'source_sha256': hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
              'high_triangles': count(high),
              'dimensions': list(high.dimensions),
              'uv_layers': [u.name for u in high.data.uv_layers],
              'material_faces': {str(i): sum(p.material_index == i for p in mesh.polygons)
                                 for i in range(len(mesh.materials))},
              'ramps': {m.name: {n.name: [(e.position, list(e.color)) for e in n.color_ramp.elements]
                                for n in m.node_tree.nodes if n.type == 'VALTORGB'}
                        for m in mesh.materials if m and m.use_nodes}}
    (QA / 'source_report.json').write_text(json.dumps(report, indent=2))
    print('SOURCE_READY', json.dumps({k:v for k,v in report.items() if k != 'ramps'}), flush=True)
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.file.pack_all()
    bpy.ops.wm.save_as_mainfile(filepath=str(ART / 'source_bare.blend'), compress=True)
    render(high, 'source_bare')


def bake_sample():
    bpy.ops.wm.open_mainfile(filepath=str(ART / 'source_bare.blend'), use_scripts=False)
    scene = bpy.context.scene
    high = bpy.data.objects['Source_bare_seed69']
    low = high.copy()
    low.data = high.data.copy()
    low.name = 'detail_rock_bare_01'
    scene.collection.objects.link(low)
    activate(low)
    mod = low.modifiers.new('Preserve silhouette by direct decimation', 'DECIMATE')
    mod.ratio = 80000 / count(low)
    bpy.ops.object.modifier_apply(modifier=mod.name)
    triangulate = low.modifiers.new('Portable triangles', 'TRIANGULATE')
    bpy.ops.object.modifier_apply(modifier=triangulate.name)
    # The source's intersecting rock shells and loose stone chips are retained.
    # This is render geometry, not a watertight collision approximation.
    low.data.materials.clear()
    material = bpy.data.materials.new('Detail_rock_baked_PBR')
    material.use_nodes = True
    material.use_backface_culling = True
    low.data.materials.append(material)
    for polygon in low.data.polygons:
        polygon.material_index = 0
        polygon.use_smooth = True
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=.0004)
    bpy.ops.object.mode_set(mode='OBJECT')
    print('LOW_READY', count(low), 'triangles', flush=True)
    scene.render.engine = 'CYCLES'
    scene.cycles.samples = 16
    scene.cycles.use_denoising = False
    prefs = bpy.context.preferences.addons['cycles'].preferences
    try:
        prefs.compute_device_type = 'HIP'
        prefs.get_devices()
        gpu = False
        for device in prefs.devices:
            device.use = device.type == 'HIP'
            gpu |= device.use
        scene.cycles.device = 'GPU' if gpu else 'CPU'
        print('BAKE_DEVICE', [(d.name, d.type, d.use) for d in prefs.devices], flush=True)
    except Exception as error:
        scene.cycles.device = 'CPU'
        print('CPU_BAKE', str(error), flush=True)
    nodes = material.node_tree.nodes
    links = material.node_tree.links
    shader = nodes.get('Principled BSDF')
    scene.render.bake.use_selected_to_active = True
    scene.render.bake.cage_extrusion = .065
    scene.render.bake.max_ray_distance = .16
    scene.render.bake.margin = 16
    scene.render.bake.use_clear = True
    scene.render.bake.use_pass_direct = False
    scene.render.bake.use_pass_indirect = False
    scene.render.bake.use_pass_color = True
    images = {}
    for label, kind in [('albedo', 'DIFFUSE'), ('normal', 'NORMAL'), ('roughness', 'ROUGHNESS')]:
        image = bpy.data.images.new('detail_rock_' + label, width=4096, height=4096, alpha=False)
        if label != 'albedo':
            image.colorspace_settings.name = 'Non-Color'
        target = nodes.new('ShaderNodeTexImage')
        target.name = 'Baked ' + label
        target.image = image
        nodes.active = target
        activate(low)
        high.hide_render = False
        high.hide_set(False)
        high.select_set(True)
        low.hide_render = False
        start = time.time()
        bpy.ops.object.bake(type=kind)
        image.filepath_raw = str(OUT / ('detail_rock_01_' + label + '.png'))
        image.file_format = 'PNG'
        image.save()
        image.pack()
        images[label] = target
        print('BAKED', label, round(time.time()-start, 1), flush=True)
    links.new(images['albedo'].outputs['Color'], shader.inputs['Base Color'])
    normal = nodes.new('ShaderNodeNormalMap')
    normal.inputs['Strength'].default_value = 1
    links.new(images['normal'].outputs['Color'], normal.inputs['Color'])
    links.new(normal.outputs['Normal'], shader.inputs['Normal'])
    links.new(images['roughness'].outputs['Color'], shader.inputs['Roughness'])
    shader.inputs['Specular IOR Level'].default_value = .3
    high.hide_render = True
    high.hide_set(True)
    # Keep the source transform during baking, then normalize the exported asset
    # to a 6.5 m span with an origin at its bottom centre.
    render(low, 'baked_bare')
    bpy.ops.file.pack_all()
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_as_mainfile(filepath=str(ART / 'detail_bake_working.blend'), compress=True)
    activate(low)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    lo = Vector([min(v.co[i] for v in low.data.vertices) for i in range(3)])
    hi = Vector([max(v.co[i] for v in low.data.vertices) for i in range(3)])
    factor = 6.5 / max(hi-lo)
    offset = Vector(((hi.x+lo.x)/2, (hi.y+lo.y)/2, lo.z))
    for v in low.data.vertices:
        v.co = (v.co-offset)*factor
    low['units'] = 'metres'
    low['source_seed'] = 69
    low['surface'] = 'bare rock'
    low['high_source_triangles'] = count(high)
    path = OUT / 'detail_rock_bare_01.glb'
    bpy.ops.export_scene.gltf(filepath=str(path), export_format='GLB', use_selection=True,
                             export_apply=True, export_animations=False, export_extras=True,
                             export_cameras=False, export_lights=False, export_image_format='AUTO')
    bpy.context.view_layer.update()
    report = {'source_triangles': count(high), 'game_triangles': count(low),
              'dimensions_blender_xyz_m': list(low.dimensions),
              'texture_size': 4096, 'maps': ['albedo', 'tangent_normal', 'roughness'],
              'path': path.relative_to(ROOT).as_posix(), 'sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
              'bytes': path.stat().st_size}
    (OUT / 'review_manifest.json').write_text(json.dumps(report, indent=2)+'\n')
    print('DETAIL_EXPORTED', json.dumps(report), flush=True)


if __name__ == '__main__':
    for folder in [ART, OUT, QA]:
        folder.mkdir(parents=True, exist_ok=True)
    if '--bake' in sys.argv:
        bake_sample()
    else:
        prepare()

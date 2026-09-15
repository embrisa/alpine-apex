"""Build the prepared, original 30-tree family in Blender; no runtime writes.

Use prepare.ps1. Rebuilding requires --replace and refuses modified previous
outputs. Editable blends retain both geometry tiers, the far card and recipe.
"""
import argparse
import hashlib
import json
import math
import os
import sys
import time
from pathlib import Path

import bpy
from mathutils import Vector

PACK = Path(__file__).resolve().parent
ROOT = PACK.parents[2]
sys.path.insert(0, str(PACK))
import geometry


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def receipt(path):
    return dict(path=path.relative_to(PACK).as_posix(), bytes=path.stat().st_size, sha256=sha(path))


def save_blend(path):
    temporary = path.with_name(path.stem + '_pending.blend')
    bpy.ops.wm.save_as_mainfile(filepath=str(temporary), compress=True)
    for attempt in range(20):
        try:
            os.replace(temporary, path)
            return
        except PermissionError:
            if attempt == 19:
                raise
            time.sleep(.25)


def foliage_image(path, name, normal=False):
    image = bpy.data.images.load(str(ROOT/path), check_existing=False)
    image.name = name
    if normal:
        image.colorspace_settings.name = 'Non-Color'
    if image.size[0] > 1024:
        image.scale(1024, int(image.size[1]*1024/image.size[0]))
    image.pack()
    return image


def material(role, family):
    mat = bpy.data.materials.new('PremiumTree_' + role.title())
    mat.use_nodes = True
    mat.use_backface_culling = False
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    bsdf = nodes.get('Principled BSDF')
    bsdf.inputs['Roughness'].default_value = .88 if role == 'snow' else .78
    vc = nodes.new('ShaderNodeVertexColor')
    vc.layer_name = 'Color'
    links.new(vc.outputs['Color'], bsdf.inputs['Base Color'])
    if role == 'wood' and family not in ('birch', 'golden'):
        tex = nodes.new('ShaderNodeTexImage')
        tex.image = bpy.data.images.load(str(ROOT / 'assets/graphics/textures/bark_albedo_low.jpg'), check_existing=True)
        mix = nodes.new('ShaderNodeMixRGB')
        mix.blend_type = 'MULTIPLY'
        mix.inputs[0].default_value = 1.0
        links.new(vc.outputs['Color'], mix.inputs[1])
        links.new(tex.outputs['Color'], mix.inputs[2])
        links.new(mix.outputs[0], bsdf.inputs['Base Color'])
    if role == 'foliage' and family in ('spruce','fir','pine','golden','maple'):
        conifer = family in ('spruce','fir','pine')
        color_path = 'assets/graphics/trees/textures/foliage_color.png' if conifer else 'art_source/trees/colorful_v1/textures/leaf_albedo.png'
        tex = nodes.new('ShaderNodeTexImage')
        tex.image = foliage_image(color_path,'Prepared foliage color')
        mix = nodes.new('ShaderNodeMixRGB')
        mix.blend_type = 'MULTIPLY'
        mix.inputs[0].default_value = 1.0
        links.new(vc.outputs['Color'],mix.inputs[1])
        links.new(tex.outputs['Color'],mix.inputs[2])
        links.new(mix.outputs[0],bsdf.inputs['Base Color'])
        if conifer:
            clip = nodes.new('ShaderNodeMath')
            clip.operation = 'GREATER_THAN'
            clip.inputs[1].default_value = .35
            links.new(tex.outputs['Alpha'],clip.inputs[0])
            links.new(clip.outputs[0],bsdf.inputs['Alpha'])
            mat.surface_render_method = 'DITHERED'
        normal_path = 'assets/graphics/trees/textures/foliage_normal_ao.png' if conifer else 'art_source/trees/colorful_v1/textures/leaf_normal.png'
        texnormal = nodes.new('ShaderNodeTexImage')
        texnormal.image = foliage_image(normal_path,'Prepared foliage normal',True)
        normal = nodes.new('ShaderNodeNormalMap')
        normal.inputs['Strength'].default_value = .4
        links.new(texnormal.outputs['Color'],normal.inputs['Color'])
        links.new(normal.outputs['Normal'],bsdf.inputs['Normal'])
    mat['role'] = role
    return mat


def make_object(data, name, mats):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(data['vertices'], [], data['faces'])
    mesh.update()
    roles = ['wood', 'foliage', 'snow']
    for role in roles:
        mesh.materials.append(mats[role])
    vc = mesh.color_attributes.new(name='Color', type='FLOAT_COLOR', domain='CORNER')
    uv = mesh.uv_layers.new(name='UVMap')
    tags = mesh.uv_layers.new(name='BranchPivot')
    for poly, role in zip(mesh.polygons, data['roles']):
        poly.material_index = roles.index('foliage' if role == 'needles' else role)
        poly.use_smooth = True
        for li in poly.loop_indices:
            vi = mesh.loops[li].vertex_index
            vc.data[li].color = data['colors'][vi]
            uv.data[li].uv = data['uvs'][vi]
            tags.data[li].uv = data['tags'][vi]
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def export(obj, lod):
    bpy.ops.object.select_all(action='DESELECT')
    obj.hide_set(False)
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    path = PACK / 'models' / (obj.name + '.glb')
    bpy.ops.export_scene.gltf(filepath=str(path), export_format='GLB', use_selection=True,
                             export_animations=False, export_yup=True,
                             export_vertex_color='NAME', export_vertex_color_name='Color',
                             export_all_vertex_colors=False, export_materials='EXPORT')
    obj.data.calc_loop_triangles()
    points = [Vector((v.co.x, v.co.z, -v.co.y)) for v in obj.data.vertices]
    return dict(receipt(path), lod=lod, triangles=len(obj.data.loop_triangles),
                bounds_min=[min(v[i] for v in points) for i in range(3)],
                bounds_max=[max(v[i] for v in points) for i in range(3)])


def validate_old(record):
    files = record['models'] + [record['source_blend']] + ([record['shadow']] if 'shadow' in record else [])
    files += [v for v in record.get('impostor', {}).values() if isinstance(v, dict) and 'sha256' in v]
    for entry in files:
        p = PACK / entry['path']
        if not p.exists() or sha(p) != entry['sha256']:
            raise RuntimeError('Preserve edited/missing prior output before rebuild: ' + str(p))


def build(record):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.preferences.filepaths.save_version = 0
    mats = {role: material(role, record['family']) for role in ('wood', 'foliage', 'snow')}
    objects, models = [], []
    for lod in (0, 1):
        obj = make_object(geometry.build(record, lod), record['id'] + f'_lod{lod}', mats)
        models.append(export(obj, lod))
        objects.append(obj)
    lo, hi = models[0]['bounds_min'], models[0]['bounds_max']
    center = (lo[1] + hi[1]) * .5
    # A square atlas must contain the maximum horizontal diagonal at any yaw.
    radial = max(math.hypot(v.co.x, v.co.y) for v in objects[0].data.vertices)
    scale = max(hi[1] - lo[1], radial * 2) * 1.12
    far = dict(vertices=[(-scale/2,0,center-scale/2),(scale/2,0,center-scale/2),
                         (scale/2,0,center+scale/2),(-scale/2,0,center+scale/2)],
               faces=[(0,1,2),(0,2,3)], colors=[(1,1,1,1)]*4,
               uvs=[(0,0),(1,0),(1,1),(0,1)], tags=[(0,1)]*4,
               roles=['foliage','foliage'])
    card = make_object(far, record['id'] + '_lod2', mats)
    models.append(export(card, 2))
    objects.append(card)
    shadow = objects[1].copy()
    shadow.data = objects[1].data.copy()
    shadow.name = record['id'] + '_shadow'
    bpy.context.scene.collection.objects.link(shadow)
    bpy.context.view_layer.objects.active = shadow
    shadow.data.calc_loop_triangles()
    if len(shadow.data.loop_triangles) > 1400:
        decimate = shadow.modifiers.new('Independent shadow budget', 'DECIMATE')
        decimate.ratio = 1380 / len(shadow.data.loop_triangles)
        bpy.ops.object.modifier_apply(modifier=decimate.name)
    shadow.data.validate(verbose=False)
    shadow_record = export(shadow, -1)
    objects.append(shadow)
    for obj in objects:
        obj.hide_render = obj != objects[0]
        obj.hide_set(obj != objects[0])
        obj['asset_id'] = record['id']
        obj['recipe_seed'] = int(record['seed'])
        obj['purpose'] = 'Prepared source; no collision or production registration'
    bpy.ops.file.pack_all()
    path = PACK / 'blends' / (record['id'] + '.blend')
    save_blend(path)
    return dict(id=record['id'], family=record['family'], variant=int(record['variant']),
                seed=int(record['seed']), height_m=record['height_m'], models=models,
                source_blend=receipt(path), shadow=shadow_record,
                impostor=dict(views=8,tile_size=512,ortho_scale=scale,center_z=center,
                              color=dict(path=f"impostors/{record['id']}_color.png"),
                              normal=dict(path=f"impostors/{record['id']}_normal.png"),
                              canopy=dict(path=f"impostors/{record['id']}_canopy.png")),
                baseline_triangles=[m['triangles'] for m in record['models']])


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--asset')
    parser.add_argument('--sample', action='store_true')
    parser.add_argument('--replace', action='store_true')
    parser.add_argument('--resume', action='store_true')
    opt = parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
    for directory in ('models','blends','impostors'):
        (PACK / directory).mkdir(exist_ok=True)
    inputs = ['assets/graphics/trees/manifest.json','assets/graphics/textures/bark_albedo_low.jpg',
              'assets/graphics/trees/textures/foliage_color.png','assets/graphics/trees/textures/foliage_normal_ao.png',
              'art_source/trees/colorful_v1/textures/leaf_albedo.png','art_source/trees/colorful_v1/textures/leaf_normal.png',
              'scripts/world/packed_trees.gd','scripts/presentation/forest_placement.gd',
              'scripts/core/ski_simulation.gd','config/ski_default.tres']
    catalog = json.loads((ROOT / inputs[0]).read_text())
    path = PACK / 'manifest.json'
    manifest = json.loads(path.read_text()) if path.exists() else dict(version=1, assets=[])
    authoring = {p:sha(PACK/p) for p in ('geometry.py','build.py')}
    if opt.resume and manifest.get('authoring_hashes', authoring) != authoring:
        raise RuntimeError('Authoring changed; --resume would retain stale geometry. Use explicit --replace.')
    manifest.update(status='prepared; not installed in the live forest',
                    authorship='Original deterministic branch and crown recipes; existing bark derivative retained',
                    coordinate_system='GLB Y up; Blender Z up; metres', blender=bpy.app.version_string,
                    input_hashes={p:sha(ROOT/p) for p in inputs},
                    authoring_hashes=authoring)
    selected = [r for r in catalog['assets'] if not opt.asset or r['id']==opt.asset]
    if opt.sample:
        selected = [r for r in selected if r['id'] in ('forest_spruce_02','forest_fir_02','forest_pine_02')]
    if not selected:
        raise RuntimeError('No matching tree ID')
    for record in selected:
        old = next((r for r in manifest['assets'] if r['id']==record['id']), None)
        if old:
            validate_old(old)
            if opt.resume:
                continue
            if not opt.replace:
                raise RuntimeError('Existing source requires --replace: ' + record['id'])
        result = build(record)
        manifest['assets'] = sorted([r for r in manifest['assets'] if r['id']!=record['id']]+[result], key=lambda r:r['id'])
        path.write_text(json.dumps(manifest,indent=2)+'\n')
        print('PREMIUM_BUILT', record['id'], [m['triangles'] for m in result['models']], flush=True)


if __name__ == '__main__':
    main()

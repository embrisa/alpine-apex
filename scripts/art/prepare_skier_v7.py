"""Build the Meshy 7 skier and separate boots; no network or paid operations.

Run: blender --background --python scripts/art/prepare_skier_v7.py
Preserves original source and previous runtime skier. Exports model-only GLBs.
"""
import bpy
import bmesh
import json
import sys
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'art_source/meshy/skier_v7'
OUT = ROOT / 'assets/graphics/models'
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(SOURCE / 'rig.glb'))
arm = next(o for o in bpy.context.scene.objects if o.type == 'ARMATURE')
meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH'
          and any(m.type == 'ARMATURE' for m in o.modifiers)]
assert len(meshes) == 1
body = meshes[0]
for obj in list(bpy.context.scene.objects):
    if obj not in [arm, body]:
        bpy.data.objects.remove(obj, do_unlink=True)
for obj in [arm, body]:
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if obj.animation_data:
        obj.animation_data_clear()

# Repair display tails without changing bind transforms or joint locations.
bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode='EDIT')
next_bone = {'Hips': 'Spine02', 'Spine02': 'Spine01', 'Spine01': 'Spine',
             'Spine': 'neck', 'neck': 'Head', 'Head': 'head_end'}
for side in ['Left', 'Right']:
    for a, b in [('Shoulder', 'Arm'), ('Arm', 'ForeArm'), ('ForeArm', 'Hand'),
                 ('UpLeg', 'Leg'), ('Leg', 'Foot'), ('Foot', 'ToeBase')]:
        next_bone[side+a] = side+b
for bone in arm.data.edit_bones:
    bone.tail = (arm.data.edit_bones[next_bone[bone.name]].head if bone.name in next_bone
                 else bone.head + (bone.tail-bone.head).normalized()*.06)
bpy.ops.object.mode_set(mode='OBJECT')

mat = body.data.materials[0]
mat.name = 'SkierV7Shell'
p = mat.node_tree.nodes.get('Principled BSDF')
# Meshy's rig viewer uses the albedo as emission. Remove that viewer-only setup
# so the portable GLBs respond correctly to lighting outside Godot as well.
for socket in ['Emission Color', 'Emission Strength']:
    for link in list(p.inputs[socket].links):
        mat.node_tree.links.remove(link)
p.inputs['Emission Color'].default_value = (0, 0, 0, 1)
p.inputs['Emission Strength'].default_value = 0
p.inputs['Specular IOR Level'].default_value = .5
for socket in ['Base Color', 'Metallic', 'Roughness', 'Normal']:
    for link in list(p.inputs[socket].links):
        mat.node_tree.links.remove(link)
for filename, socket in [('base_color.png', 'Base Color'), ('roughness.png', 'Roughness'),
                         ('metallic.png', 'Metallic'), ('normal.png', 'Normal')]:
    image = bpy.data.images.load(str(SOURCE / 'candidate_textures' / filename), check_existing=True)
    if socket != 'Base Color':
        image.colorspace_settings.name = 'Non-Color'
    node = mat.node_tree.nodes.new('ShaderNodeTexImage')
    node.image = image
    if socket == 'Normal':
        normal = mat.node_tree.nodes.new('ShaderNodeNormalMap')
        normal.inputs['Strength'].default_value = .5
        mat.node_tree.links.new(node.outputs['Color'], normal.inputs['Color'])
        mat.node_tree.links.new(normal.outputs['Normal'], p.inputs[socket])
    else:
        mat.node_tree.links.new(node.outputs['Color'], p.inputs[socket])
mat.use_backface_culling = True
for node in list(mat.node_tree.nodes):
    if node.type == 'TEX_IMAGE' and not any(output.is_linked for output in node.outputs):
        mat.node_tree.nodes.remove(node)

def cut(obj, point, normal, clear_outer):
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.bisect_plane(bm, geom=list(bm.verts)+list(bm.edges)+list(bm.faces),
                          plane_co=point, plane_no=normal, dist=.00001,
                          clear_outer=clear_outer, clear_inner=not clear_outer)
    bm.to_mesh(obj.data)
    bm.free()

def reduce(obj, ratio):
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    dec = obj.modifiers.new('Runtime reduction', 'DECIMATE')
    dec.ratio = ratio
    bpy.ops.object.modifier_apply(modifier=dec.name)
    # Meshy rig export carries split normals; remove faceted shading at cloth folds.
    if obj.data.has_custom_normals:
        bpy.ops.mesh.customdata_custom_splitnormals_clear()
    for face in obj.data.polygons:
        face.use_smooth = True
    obj.data.calc_loop_triangles()

boots = []
for side in ['Left', 'Right']:
    boot = body.copy()
    boot.data = body.data.copy()
    bpy.context.collection.objects.link(boot)
    boot.parent = None
    boot.matrix_world = body.matrix_world.copy()
    boot.modifiers.clear()
    boot.vertex_groups.clear()
    cut(boot, (0, 0, .19), (0, 0, 1), True)
    cut(boot, (0, 0, 0), (1, 0, 0), side == 'Right')
    foot = arm.matrix_world @ arm.data.bones[side+'Foot'].head_local
    for vertex in boot.data.vertices:
        vertex.co.x -= foot.x
        vertex.co.y -= foot.y
    boot.name = 'SkierV7Boot'+side
    reduce(boot, .6)
    boots.append(boot)
# Two centimetres of overlap conceal the cuff seam while boots remain rigid.
cut(body, (0, 0, .17), (0, 0, 1), False)
body.name = 'SkierV7Body'
# Anchor the hem to the rigid boot, fading back to generated calf weights.
# Otherwise deep knee flexion pulls the cut trouser edge off the boot cuff.
for vertex in body.data.vertices:
    z = (body.matrix_world @ vertex.co).z
    if z >= .36:
        continue
    mix = min(1.0, max(0.0, (.36-z)/.11))
    mix = mix*mix*(3.0-2.0*mix)
    foot_group = body.vertex_groups['LeftFoot' if vertex.co.x > 0 else 'RightFoot']
    weights = {g.group: g.weight*(1.0-mix) for g in vertex.groups}
    weights[foot_group.index] = weights.get(foot_group.index, 0.0)+mix
    for group in body.vertex_groups:
        group.remove([vertex.index])
    for index, weight in weights.items():
        if weight > .00001:
            body.vertex_groups[index].add([vertex.index], weight, 'REPLACE')
reduce(body, .70)
sys.path.insert(0,str(Path(__file__).resolve().parent))
from skier_details import finish_details
finish_details(body, arm, mat, cut)

def export(path, objects):
    bpy.ops.object.select_all(action='DESELECT')
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.export_scene.gltf(filepath=str(path), export_format='GLB', use_selection=True,
                             export_animations=False, export_apply=False)

stats = {'source_task': '01a073b6-b9b8-76f2-ac92-96e2960859cb',
         'rig_task': '01a073ba-ad56-70e1-9e35-1fa17fe1b2f2',
         'bones': len(arm.data.bones), 'body_triangles': len(body.data.loop_triangles),
         'boots_triangles': sum(len(b.data.loop_triangles) for b in boots),
         'bind_height_m': round(body.dimensions.z, 4), 'exports': []}
bpy.ops.file.pack_all()
for side, boot in zip(['Left', 'Right'], boots):
    foot = arm.matrix_world @ arm.data.bones[side+'Foot'].head_local
    boot.location = (foot.x, foot.y, 0)
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT / 'art_source/blender/skier_v7.blend'))
for boot in boots:
    boot.location = (0, 0, 0)
bpy.context.view_layer.update()
exports = [(OUT / 'skier_v7.glb', [arm, body])]
exports += [(OUT / ('skier_v7_boot_'+side.lower()+'.glb'), [boot])
            for side, boot in zip(['Left', 'Right'], boots)]
expected = []
for path, objects in exports:
    export(path, objects)
    expected.append((path, sum(len(o.data.loop_triangles) for o in objects if o.type == 'MESH'),
                     any(o.type == 'ARMATURE' for o in objects)))
for path, triangles, rigged in expected:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(path))
    objects = list(bpy.context.scene.objects)
    assert all(o.type in ['MESH', 'ARMATURE', 'EMPTY'] for o in objects)
    # Blender 5.2 adds an Icosphere for bone display during glTF import.
    # It is not part of the file's scene; exclude only referenced custom shapes.
    shapes = {b.custom_shape for o in objects if o.type == 'ARMATURE'
              for b in o.pose.bones if b.custom_shape}
    imported = [o for o in objects if o.type == 'MESH' and o not in shapes]
    assert len(imported) == 1
    imported[0].data.calc_loop_triangles()
    assert len(imported[0].data.loop_triangles) == triangles
    assert sum(o.type == 'ARMATURE' for o in objects) == int(rigged)
    if rigged:
        assert len(next(o for o in objects if o.type == 'ARMATURE').data.bones) == 24
        assert any(m.type == 'ARMATURE' for m in imported[0].modifiers)
    assert imported[0].data.uv_layers
    material = imported[0].data.materials[0]
    shader = material.node_tree.nodes.get('Principled BSDF')
    assert shader.inputs['Base Color'].is_linked
    if rigged:
        assert {'SkierV7Clothing','SkierV7Helmet','SkierV7Lens','SkierV7Gloves'}.issubset({m.name.split('.')[0] for m in imported[0].data.materials})
    stats['exports'].append({'path': str(path.relative_to(ROOT)), 'triangles': triangles,
                             'dimensions_m': list(imported[0].dimensions),
                             'roundtrip_verified': True, 'pbr_verified': True})
(SOURCE / 'runtime_qa.json').write_text(json.dumps(stats, indent=2)+'\n')
print('SKIER_V7_EXPORT', json.dumps(stats))

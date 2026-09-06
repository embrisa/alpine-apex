"""Clean the selected Meshy rig, preserve weights, restore PBR, export and verify."""
import bpy, bmesh, json
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(ROOT/'art_source/meshy/skier_rig.glb'))
arm=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE')
meshes=[o for o in bpy.context.scene.objects if o.type=='MESH' and any(m.type=='ARMATURE' for m in o.modifiers)]
assert meshes,'Missing skinned character'
for o in list(bpy.context.scene.objects):
    if o not in meshes and o!=arm:bpy.data.objects.remove(o,do_unlink=True)
for o in [arm]+meshes:
    bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)

# Meshy exports arbitrary display bone lengths. Reconstruct useful edit-bone tails.
bpy.context.view_layer.objects.active=arm
bpy.ops.object.mode_set(mode='EDIT')
next_bone={'Hips':'Spine02','Spine02':'Spine01','Spine01':'Spine','Spine':'neck','neck':'Head','Head':'head_end'}
for side in ['Left','Right']:
    for a,b in [('Shoulder','Arm'),('Arm','ForeArm'),('ForeArm','Hand'),('UpLeg','Leg'),('Leg','Foot'),('Foot','ToeBase')]:next_bone[side+a]=side+b
for bone in arm.data.edit_bones:
    if bone.name in next_bone:bone.tail=arm.data.edit_bones[next_bone[bone.name]].head
    else:bone.tail=bone.head+(bone.tail-bone.head).normalized()*.06
bpy.ops.object.mode_set(mode='OBJECT')
for obj in meshes:
    # Remove generated shoes below the trouser cuffs; separate boots fill this area.
    bm=bmesh.new();bm.from_mesh(obj.data)
    doomed=[v for v in bm.verts if (obj.matrix_world@v.co).z<.18]
    bmesh.ops.delete(bm,geom=doomed,context='VERTS');bm.to_mesh(obj.data);bm.free()
    bpy.context.view_layer.objects.active=obj
    dec=obj.modifiers.new('Runtime reduction','DECIMATE');dec.ratio=.80
    bpy.ops.object.modifier_apply(modifier=dec.name)
    mat=obj.data.materials[0];mat.name='SkierShell'
    p=mat.node_tree.nodes.get('Principled BSDF')
    # Rig output may omit source PBR maps. Restore the selected candidate's maps.
    for socket in ['Base Color','Metallic','Roughness','Normal']:
        for link in list(p.inputs[socket].links):mat.node_tree.links.remove(link)
    for filename,socket in [('base_color.png','Base Color'),('roughness.png','Roughness'),('metallic.png','Metallic'),('normal.png','Normal')]:
        image=bpy.data.images.load(str(ROOT/'art_source/meshy/skier_2_textures'/filename),check_existing=True)
        if socket!='Base Color':image.colorspace_settings.name='Non-Color'
        node=mat.node_tree.nodes.new('ShaderNodeTexImage');node.image=image
        if socket=='Normal':
            normal=mat.node_tree.nodes.new('ShaderNodeNormalMap');normal.inputs['Strength'].default_value=.5
            mat.node_tree.links.new(node.outputs['Color'],normal.inputs['Color']);mat.node_tree.links.new(normal.outputs['Normal'],p.inputs[socket])
        else:mat.node_tree.links.new(node.outputs['Color'],p.inputs[socket])
    mat.use_backface_culling=True
    # Keep cloth from inheriting metallic defaults when texture is absent downstream.
    p.inputs['Metallic'].default_value=0;p.inputs['Roughness'].default_value=.72
    obj.data.calc_loop_triangles()

stats=dict(meshes=len(meshes),triangles=sum(len(o.data.loop_triangles) for o in meshes),bones=len(arm.data.bones),source_task='01a072fc-d6ef-772e-b221-668afcb39bf5')
for o in [arm]+meshes:
    if o.animation_data:o.animation_data_clear()
bpy.ops.object.select_all(action='SELECT')
bpy.ops.file.pack_all()
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art_source/blender/skier.blend'))
path=ROOT/'assets/graphics/models/skier.glb'
bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,export_animations=False,export_apply=False)
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=str(path))
assert sum(o.type=='ARMATURE' for o in bpy.context.scene.objects)==1
assert all(o.type in ['MESH','ARMATURE','EMPTY'] for o in bpy.context.scene.objects)
result_mesh=[o for o in bpy.context.scene.objects if o.type=='MESH' and any(m.type=='ARMATURE' for m in o.modifiers)];count=0
assert len(result_mesh)==stats['meshes']
for o in result_mesh:o.data.calc_loop_triangles();count+=len(o.data.loop_triangles)
print('ROUNDTRIP_COUNTS',stats['triangles'],count)
assert count==stats['triangles']
stats['roundtrip_triangles']=count
stats['roundtrip_verified']=True
(ROOT/'art_source/blender/skier_qa.json').write_text(json.dumps(stats,indent=2))
print('SKIER_EXPORT',stats)

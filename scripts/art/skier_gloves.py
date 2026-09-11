"""Append the locally prepared Meshy glove pair to the existing wrist rig."""
from pathlib import Path
import bpy
import bmesh
from mathutils import Vector

ROOT=Path(__file__).resolve().parents[2]
TEMPLATE=ROOT/'art_source/blender/skier_glove_v1.blend'


def append_gloves(body,arm,remove_existing=False):
    if remove_existing:
        slots={i for i,m in enumerate(body.data.materials) if m and m.name.split('.')[0]=='SkierV7Gloves'}
        assert slots,'Expected the existing glove surface'
        bm=bmesh.new();bm.from_mesh(body.data)
        bmesh.ops.delete(bm,geom=[f for f in bm.faces if f.material_index in slots],context='FACES')
        bm.to_mesh(body.data);bm.free()
    with bpy.data.libraries.load(str(TEMPLATE),link=False) as (source,target):
        target.objects=['GloveTemplate']
    template=target.objects[0]
    assert template is not None
    parts=[]
    material=template.data.materials[0]
    uv_name=body.data.uv_layers.active.name if body.data.uv_layers.active else 'UVMap'
    for node in material.node_tree.nodes:
        if node.type in ['UVMAP','NORMAL_MAP']:node.uv_map=uv_name
    uv_node=material.node_tree.nodes.new('ShaderNodeUVMap');uv_node.uv_map=uv_name
    for node in material.node_tree.nodes:
        if node.type=='TEX_IMAGE':material.node_tree.links.new(uv_node.outputs['UV'],node.inputs['Vector'])
    # Replace the old slot, retaining its semantic name for Godot's converter.
    for i,mat in enumerate(body.data.materials):
        if mat and mat.name.split('.')[0]=='SkierV7Gloves':body.data.materials[i]=material
    for prefix,side in [('Left',1),('Right',-1)]:
        obj=bpy.data.objects.new(prefix+'Glove',template.data.copy())
        obj.data.uv_layers.active.name=uv_name
        bpy.context.scene.collection.objects.link(obj)
        hand=obj.vertex_groups.new(name=prefix+'Hand')
        forearm=obj.vertex_groups.new(name=prefix+'ForeArm')
        origin=arm.matrix_world@arm.data.bones[prefix+'Hand'].head_local
        for v in obj.data.vertices:
            along=v.co.x
            v.co=origin+Vector((side*v.co.x,v.co.y,v.co.z))
            blend=max(0,min(1,(along+.015)/.025));blend=blend*blend*(3-2*blend)
            if blend:hand.add([v.index],blend,'REPLACE')
            if blend<1:forearm.add([v.index],1-blend,'REPLACE')
        bm=bmesh.new();bm.from_mesh(obj.data)
        if side<0:bmesh.ops.reverse_faces(bm,faces=list(bm.faces))
        bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
        bm.to_mesh(obj.data);bm.free()
        for f in obj.data.polygons:f.use_smooth=True
        parts.append(obj)
    bpy.data.objects.remove(template,do_unlink=True)
    bpy.ops.object.select_all(action='DESELECT')
    for obj in parts+[body]:obj.select_set(True)
    bpy.context.view_layer.objects.active=body;bpy.ops.object.join()
    body.data.uv_layers.active=body.data.uv_layers[uv_name]
    body.data.uv_layers[uv_name].active_render=True
    return material

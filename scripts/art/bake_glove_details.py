"""Bake the retained Ultra surface onto the small, connected glove mesh."""
import hashlib
import json
from pathlib import Path
import bpy
import numpy as np
from mathutils import Vector


def soften_contact_normals(low,material,texture,output):
    """Bake a smooth contact lining where Ultra rays cross the tight grip.

    Leave the external knuckle/cuff stitching intact. The mask is baked away;
    it adds no runtime attributes, samplers, geometry or shader operations.
    """
    mask=low.data.color_attributes.new(name='GloveContactLining',type='FLOAT_COLOR',domain='CORNER')
    weights=[]
    palm_direction=Vector((.18,.30,-.12)).normalized()
    for loop in low.data.loops:
        vertex=low.data.vertices[loop.vertex_index]
        radial=Vector((vertex.co.x-.070,0,vertex.co.z))
        facing=-radial.normalized().dot(vertex.normal)
        inward=max(0,min(1,(facing-.02)/.40))
        distance=max(0,min(1,(.060-radial.length)/.015))
        contact=inward*inward*(3-2*inward)*distance
        # The folded palm also faces along the pole axis; a radial test alone
        # misses it. Keep the outward knuckles and sleeve end outside this mask.
        palm=max(0,min(1,(vertex.normal.dot(palm_direction)-.04)/.42))
        span=max(0,min(1,(vertex.co.x+.015)/.025))*max(0,min(1,(.106-vertex.co.x)/.015))
        weight=max(contact,palm*palm*(3-2*palm)*span)*.98
        mask.data[loop.index].color=(weight,weight,weight,1)
        weights.append(weight)
    nodes=material.node_tree.nodes;links=material.node_tree.links
    attribute=nodes.new('ShaderNodeAttribute');attribute.attribute_name=mask.name
    mix=nodes.new('ShaderNodeMixRGB');mix.blend_type='MIX'
    mix.inputs[2].default_value=(.5,.5,1,1)
    links.new(attribute.outputs['Fac'],mix.inputs[0]);links.new(texture.outputs['Color'],mix.inputs[1])
    emission=nodes.new('ShaderNodeEmission');links.new(mix.outputs[0],emission.inputs['Color'])
    surface=nodes.get('Material Output');links.new(emission.outputs[0],surface.inputs['Surface'])
    clean=bpy.data.images.new('GloveV1_normal_lining',width=2048,height=2048,alpha=False)
    clean.colorspace_settings.name='Non-Color'
    target=nodes.new('ShaderNodeTexImage');target.image=clean;nodes.active=target
    uv=next(n for n in nodes if n.type=='UVMAP');links.new(uv.outputs['UV'],target.inputs['Vector'])
    bpy.ops.object.select_all(action='DESELECT');low.select_set(True);bpy.context.view_layer.objects.active=low
    bpy.context.scene.render.bake.use_selected_to_active=False
    bpy.ops.object.bake(type='EMIT')
    clean.filepath_raw=str(output/'normal.png');clean.file_format='PNG';clean.save();clean.pack()
    links.new(nodes.get('Principled BSDF').outputs['BSDF'],surface.inputs['Surface'])
    for node in [texture,attribute,mix,emission]:nodes.remove(node)
    low.data.color_attributes.remove(mask)
    print('CONTACT_NORMAL_LINING',sum(w>.5 for w in weights),'corners',flush=True)
    return target


def bake_details(low,fit,source,raw_hash):
    coords=np.array([tuple(v.co) for v in low.data.vertices],dtype=np.float32)
    faces=np.array([i for f in low.data.polygons for i in f.vertices],dtype=np.int32)
    key=hashlib.sha256(coords.tobytes()+faces.tobytes()+raw_hash.encode()+json.dumps(fit,sort_keys=True).encode()+Path(__file__).read_bytes()+Path(__file__).with_name('glove_fit.py').read_bytes()).hexdigest()
    cache=source/'baked_glove.blend';record=source/'bake.json'
    if cache.exists() and record.exists() and json.loads(record.read_text())['fingerprint']==key:
        with bpy.data.libraries.load(str(cache),link=False) as (_,target):target.objects=['GloveTemplate']
        baked=target.objects[0];bpy.context.scene.collection.objects.link(baked)
        bpy.data.objects.remove(low,do_unlink=True);baked.name='GloveTemplate'
        bpy.context.view_layer.objects.active=baked;baked.select_set(True)
        return baked
    bpy.ops.object.select_all(action='DESELECT');low.select_set(True);bpy.context.view_layer.objects.active=low
    bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.smart_project(angle_limit=1.15,island_margin=.012)
    bpy.ops.object.mode_set(mode='OBJECT')
    low.data.uv_layers.active.name='UVMap';low.data.uv_layers.active.active_render=True
    old_objects=set(bpy.context.scene.objects)
    bpy.ops.import_scene.gltf(filepath=str(source/'candidate_01.glb'))
    high=next(o for o in bpy.context.scene.objects if o not in old_objects and o.type=='MESH')
    bpy.context.view_layer.objects.active=high
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    p=np.empty(len(high.data.vertices)*3,dtype=np.float32);high.data.vertices.foreach_get('co',p);p=p.reshape(-1,3)
    q=p-np.array(fit['grip_source']);x=.070+q@np.array(fit['outward'])*fit['scale'][0]
    y=-(q@np.array(fit['thumb_direction']))*fit['scale'][1]+fit['grip_across_offset'];z=q[:,1]*fit['scale'][2]
    radius=np.hypot(x-.070,z);ratio=np.sqrt(radius*radius+.017*.017)/np.maximum(radius,.000001)
    hand=np.stack([.070+(x-.070)*ratio,y,z*ratio],axis=1)
    length=p@np.array([-.7071067811865476,0,.7071067811865476]);across=p@np.array([.7071067811865476,0,.7071067811865476])
    cuff=np.stack([(length+.60)*.070,-(across-.11)*.090,(p[:,1]-.25)*.090+.005],axis=1)
    weight=np.clip((-.15-length)/.30,0,1);weight=weight*weight*(3-2*weight)
    posed=hand*(1-weight[:,None])+cuff*weight[:,None]
    high.data.vertices.foreach_set('co',posed.astype(np.float32).ravel())
    high.data.flip_normals();high.data.update()
    if high.data.has_custom_normals:bpy.ops.mesh.customdata_custom_splitnormals_clear()
    for face in high.data.polygons:face.use_smooth=True
    high_mat=high.data.materials[0];high_shader=high_mat.node_tree.nodes.get('Principled BSDF')
    mat=bpy.data.materials.new('SkierV7GlovesBaked');mat.use_nodes=True
    low.data.materials.clear();low.data.materials.append(mat)
    for face in low.data.polygons:face.material_index=0
    nodes=mat.node_tree.nodes;shader=nodes.get('Principled BSDF')
    shader.inputs['Metallic'].default_value=0
    uv=nodes.new('ShaderNodeUVMap');uv.uv_map='UVMap'
    scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.device='CPU';scene.cycles.samples=4
    scene.render.threads_mode='FIXED';scene.render.threads=8
    scene.render.bake.use_selected_to_active=True;scene.render.bake.cage_extrusion=.012
    scene.render.bake.max_ray_distance=.04;scene.render.bake.margin=12
    scene.render.bake.use_pass_direct=False;scene.render.bake.use_pass_indirect=False;scene.render.bake.use_pass_color=True
    textures=source/'baked_textures';textures.mkdir(exist_ok=True)
    images={}
    for channel,kind in [('albedo','DIFFUSE'),('normal','NORMAL'),('roughness','EMIT')]:
        img=bpy.data.images.new('GloveV1_'+channel,width=2048,height=2048,alpha=False)
        if channel!='albedo':img.colorspace_settings.name='Non-Color'
        tex=nodes.new('ShaderNodeTexImage');tex.image=img;nodes.active=tex
        mat.node_tree.links.new(uv.outputs['UV'],tex.inputs['Vector'])
        if channel=='roughness':
            emission=high_mat.node_tree.nodes.new('ShaderNodeEmission')
            roughness=high_shader.inputs['Roughness']
            if roughness.links:high_mat.node_tree.links.new(roughness.links[0].from_socket,emission.inputs['Color'])
            else:emission.inputs['Color'].default_value=(roughness.default_value,)*3+(1,)
            output=next(n for n in high_mat.node_tree.nodes if n.type=='OUTPUT_MATERIAL')
            high_mat.node_tree.links.new(emission.outputs['Emission'],output.inputs['Surface'])
        bpy.ops.object.select_all(action='DESELECT');low.select_set(True);high.select_set(True)
        bpy.context.view_layer.objects.active=low
        print('BAKING_GLOVE',channel,flush=True);bpy.ops.object.bake(type=kind)
        img.filepath_raw=str(textures/(channel+'.png'));img.file_format='PNG';img.save();img.pack()
        images[channel]=tex
    images['normal']=soften_contact_normals(low,mat,images['normal'],textures)
    mat.node_tree.links.new(images['albedo'].outputs['Color'],shader.inputs['Base Color'])
    mat.node_tree.links.new(images['roughness'].outputs['Color'],shader.inputs['Roughness'])
    normal=nodes.new('ShaderNodeNormalMap');normal.uv_map='UVMap';normal.inputs['Strength'].default_value=.85
    mat.node_tree.links.new(images['normal'].outputs['Color'],normal.inputs['Color'])
    mat.node_tree.links.new(normal.outputs['Normal'],shader.inputs['Normal'])
    mat.name='SkierV7Gloves';mat.use_backface_culling=True
    for obj in list(bpy.context.scene.objects):
        if obj not in old_objects:bpy.data.objects.remove(obj,do_unlink=True)
    low.name='GloveTemplate'
    bpy.ops.object.select_all(action='DESELECT');low.select_set(True);bpy.context.view_layer.objects.active=low
    bpy.data.libraries.write(str(cache),{low},fake_user=True,compress=True)
    record.write_text(json.dumps({'fingerprint':key,'source_sha256':raw_hash,'resolution':2048,'channels':list(images),'blender':bpy.app.version_string},indent=2)+'\n')
    return low

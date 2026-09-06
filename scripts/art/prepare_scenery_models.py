"""Fit Meshy scenery masters, author two variants/LODs, bake matching far cards.

Companion to build_round_boulders.py. Uses preserved local GLBs and textures;
never submits jobs. Independent export/reimport checks write a QA manifest.
"""
import bpy
import bmesh
import hashlib
import json
import math
import sys
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
RAW = ROOT/'art_source/meshy/scenery'
OUT = ROOT/'assets/graphics/models'
TEX = ROOT/'assets/graphics/textures'
SOURCE = ROOT/'art_source/blender'
stats = []
TREE_TARGETS = {
    'fir':[14000,4500], 'pine':[14000,4500], 'larch':[12000,5000], 'snag':[6000,1800],
    'birch':[12000,4500], 'rowan':[12000,4500], 'scots_pine':[14000,4500],
    'wind_pine':[14000,4500], 'split_snag':[6000,1800], 'hollow_snag':[6000,1800],
}
ROCK_FAMILIES = ['granite','slate','limestone','gneiss','split_rock','outcrop']


def export(obj, name, placeholder_name, family, lod):
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    materials = list(obj.data.materials)
    placeholder = bpy.data.materials.get(placeholder_name) or bpy.data.materials.new(placeholder_name)
    obj.data.materials.clear()
    obj.data.materials.append(placeholder)
    for poly in obj.data.polygons:
        poly.material_index = 0
    bpy.ops.export_scene.gltf(filepath=str(OUT/(name+'.glb')), export_format='GLB',
                             use_selection=True, export_animations=False)
    obj.data.materials.clear()
    for mat in materials:
        obj.data.materials.append(mat)
    obj.data.calc_loop_triangles()
    stats.append(dict(asset=name,family=family,lod=lod,triangles=len(obj.data.loop_triangles),
                      dimensions=list(obj.dimensions),material=placeholder_name))


def load_source(family, tree):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(RAW/(family+'.glb')))
    objects = [o for o in bpy.context.scene.objects if o.type=='MESH']
    bpy.ops.object.select_all(action='DESELECT')
    for obj in objects:obj.select_set(True)
    bpy.context.view_layer.objects.active=objects[0]
    if len(objects)>1:bpy.ops.object.join()
    obj=bpy.context.object
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    bm=bmesh.new();bm.from_mesh(obj.data)
    bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.00001)
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    bm.to_mesh(obj.data);bm.free()
    bottom=min(v.co.z for v in obj.data.vertices)
    height=max(v.co.z for v in obj.data.vertices)-bottom
    for v in obj.data.vertices:v.co=(v.co-Vector((0,0,bottom)))*(10.5/height if tree else 2.35/height)
    if tree:
        # Generated trees sometimes include a soil/snow disk despite the prompt.
        # Crop it from the master before trunk fitting; do not squeeze it into a cone.
        bm=bmesh.new();bm.from_mesh(obj.data)
        bmesh.ops.bisect_plane(bm,geom=list(bm.verts)+list(bm.edges)+list(bm.faces),
                              plane_co=(0,0,.38),plane_no=(0,0,1),clear_inner=True)
        bm.to_mesh(obj.data);bm.free()
        low=min(v.co.z for v in obj.data.vertices)
        high=max(v.co.z for v in obj.data.vertices)
        for v in obj.data.vertices:v.co.z=(v.co.z-low)*10.5/(high-low)
        base=[v.co for v in obj.data.vertices if v.co.z<.65]
        center=Vector(((min(v.x for v in base)+max(v.x for v in base))*.5,
                       (min(v.y for v in base)+max(v.y for v in base))*.5,0))
        for v in obj.data.vertices:v.co-=center
        radius=max(math.hypot(v.co.x,v.co.y) for v in obj.data.vertices if v.co.z<.5)
        # Preserve UVs while fitting the base to the existing 0.46 m trunk radius.
        for v in obj.data.vertices:
            weight=max(0,1-v.co.z/2.0)
            factor=1+(.44/radius-1)*weight
            v.co.x*=factor;v.co.y*=factor
        # A short buried skirt avoids root gaps on the sloping point anchor.
        for v in obj.data.vertices:
            if v.co.z<.15:v.co.z-=.22*(1-v.co.z/.15)
    else:
        center=Vector(((min(v.co.x for v in obj.data.vertices)+max(v.co.x for v in obj.data.vertices))*.5,
                       (min(v.co.y for v in obj.data.vertices)+max(v.co.y for v in obj.data.vertices))*.5,0))
        for v in obj.data.vertices:v.co-=center
        radius=max(math.hypot(v.co.x,v.co.y) for v in obj.data.vertices)
        for v in obj.data.vertices:v.co.x*=1.35/radius;v.co.y*=1.35/radius;v.co.z-=.35
    for polygon in obj.data.polygons:polygon.use_smooth=True
    obj.name=family+'_source'
    return obj


def runtime_textures(family):
    for channel, filename in [('albedo','base_color.png'),('normal','normal.png'),('roughness','roughness.png')]:
        for suffix,size in [('',2048),('_low',1024)]:
            img=bpy.data.images.load(str(RAW/(family+'_textures')/filename),check_existing=False)
            img.scale(size,size)
            img.file_format='JPEG';img.filepath_raw=str(TEX/(family+'_model_'+channel+suffix+'.jpg'))
            img.save();bpy.data.images.remove(img)


def bake_cards(family, near):
    # Unlit albedo with a dynamic runtime light response; no baked sun or shadow.
    for mat in near[0].data.materials:
        shader=mat.node_tree.nodes.get('Principled BSDF')
        output=next(n for n in mat.node_tree.nodes if n.type=='OUTPUT_MATERIAL')
        emit=mat.node_tree.nodes.new('ShaderNodeEmission')
        color=shader.inputs['Base Color']
        if color.links:mat.node_tree.links.new(color.links[0].from_socket,emit.inputs['Color'])
        else:emit.inputs['Color'].default_value=color.default_value
        mat.node_tree.links.new(emit.outputs[0],output.inputs['Surface'])
    camera_data=bpy.data.cameras.new('Albedo camera');camera=bpy.data.objects.new('Albedo camera',camera_data)
    bpy.context.collection.objects.link(camera)
    camera.location=(0,-30,5.25)
    camera.rotation_euler=(Vector((0,0,5.25))-camera.location).to_track_quat('-Z','Y').to_euler()
    camera_data.type='ORTHO'
    scene=bpy.context.scene;scene.camera=camera;scene.render.engine='BLENDER_EEVEE'
    scene.render.resolution_x=1024;scene.render.resolution_y=1024;scene.render.resolution_percentage=100
    scene.render.film_transparent=True;scene.render.image_settings.file_format='PNG'
    scene.render.image_settings.color_mode='RGBA';scene.view_settings.view_transform='Standard'
    for variant,obj in enumerate(near,1):
        obj.hide_render=False
        width=max(11.5,2*max(abs(v.co.x) for v in obj.data.vertices)+.4)
        camera_data.ortho_scale=width
        scene.render.filepath=str(TEX/f'impostor_{family}_{variant}.png')
        bpy.ops.render.render(write_still=True)
        img=bpy.data.images.load(scene.render.filepath,check_existing=False)
        img.scale(512,512);img.filepath_raw=str(TEX/f'impostor_{family}_{variant}_low.png');img.save()
        bpy.data.images.remove(img)
        obj.hide_render=True
        mesh=bpy.data.meshes.new('Far card')
        bottom=5.25-width/2;top=5.25+width/2
        mesh.from_pydata([(-width/2,0,bottom),(width/2,0,bottom),(width/2,0,top),(-width/2,0,top)],[],[(0,1,2),(0,2,3)])
        uv=mesh.uv_layers.new();coords=[(0,0),(1,0),(1,1),(0,1)]
        for p in mesh.polygons:
            for li in p.loop_indices:uv.data[li].uv=coords[mesh.loops[li].vertex_index]
        card=bpy.data.objects.new(f'{family}_{variant}_lod2',mesh);bpy.context.collection.objects.link(card)
        export(card,card.name,f'Impostor_{family}_{variant}.Runtime',family,2)
        card.hide_render=True


selected=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else list(TREE_TARGETS)+ROCK_FAMILIES
for family in selected:
    tree=family in TREE_TARGETS
    source=load_source(family,tree)
    if tree:runtime_textures(family)
    source.hide_render=True
    near=[]
    targets=TREE_TARGETS[family] if tree else [1100]
    reduced=[]
    for lod,target in enumerate(targets):
        obj=bpy.data.objects.new(f'{family}_reduction_{lod}',source.data.copy());bpy.context.collection.objects.link(obj)
        bpy.ops.object.select_all(action='DESELECT');obj.select_set(True);bpy.context.view_layer.objects.active=obj
        obj.data.calc_loop_triangles()
        decimate=obj.modifiers.new('Authored distance reduction','DECIMATE')
        decimate.ratio=min(1,target/len(obj.data.loop_triangles))
        bpy.ops.object.modifier_apply(modifier=decimate.name)
        # Decimation can leave isolated twig vertices that glTF omits. Remove
        # those before fitting bounds so authoring and exported heights agree.
        bm=bmesh.new();bm.from_mesh(obj.data)
        bmesh.ops.delete(bm,geom=[v for v in bm.verts if not v.link_faces],context='VERTS')
        bm.to_mesh(obj.data);bm.free()
        obj.hide_render=True
        reduced.append(obj)
    for variant in [1,2,3,4]:
        for lod,base in enumerate(reduced):
            name=f'{family}_{variant}_lod{lod}' if tree else f'rock_{family}_{variant}'
            obj=bpy.data.objects.new(name,base.data.copy());bpy.context.collection.objects.link(obj)
            for vertex in obj.data.vertices:
                p=vertex.co
                if tree:
                    t=max(0,min(1,p.z/10.5))
                    angle=(variant-1)*.85+math.sin(t*7+variant)*[.08,.18,.32,.12][variant-1]*t
                    spread=1+[0,.28,-.25,.14][variant-1]*t
                    x,y=p.x,p.y
                    p.x=(x*math.cos(angle)-y*math.sin(angle))*spread
                    p.y=(x*math.sin(angle)+y*math.cos(angle))/spread
                    # Independent broad/columnar/raised/wind-shaped crowns, with
                    # the lower collision trunk fixed and the same top height.
                    p.z += [0,-1.0,1.3,.4][variant-1]*math.sin(t*math.pi)*min(1,max(0,(p.z-1.8)/2))
                    if variant==4:p.x+=math.sin(t*math.pi)*.6*t
                elif variant>1:
                    p.x+=math.sin(p.z*2.8+variant)*.12*variant
                    p.y*=[1,.84,1.18,.72][variant-1]
                    p.z+=math.sin(p.x*2.5+variant)*.12
            # Re-establish the shared envelope after reduction.
            low=min(v.co.z for v in obj.data.vertices);high=max(v.co.z for v in obj.data.vertices)
            for v in obj.data.vertices:v.co.z=(v.co.z-low)*((10.72 if tree else 2.35)/(high-low))-(.22 if tree else .35)
            if not tree:
                radius=max(math.hypot(v.co.x,v.co.y) for v in obj.data.vertices)
                for v in obj.data.vertices:v.co.x*=1.35/radius;v.co.y*=1.35/radius
            obj.data.update()
            export(obj,name,f'Tree_{family}.Runtime' if tree else 'Rock.Runtime',family,lod if tree else None)
            obj.hide_render=True
            if lod==0:near.append(obj)
    bpy.ops.file.pack_all()
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/f'{family}_family.blend'))
    if tree:bake_cards(family,near)

for stat in stats:
    path=OUT/(stat['asset']+'.glb')
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(path))
    meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
    assert len(meshes)==1,stat
    obj=meshes[0];obj.data.calc_loop_triangles()
    assert len(obj.data.loop_triangles)==stat['triangles'],stat
    assert max(abs(obj.dimensions[i]-stat['dimensions'][i]) for i in range(3))<.01,stat
    assert obj.data.materials[0].name.startswith(stat['material']),stat
    assert all(math.isfinite(c) for v in obj.data.vertices for c in v.co),stat
    stat.update(roundtrip_verified=True,bytes=path.stat().st_size,sha256=hashlib.sha256(path.read_bytes()).hexdigest())
qa_path=SOURCE/'scenery_models_qa.json'
previous=json.loads(qa_path.read_text()) if qa_path.exists() else []
names={s['asset'] for s in stats}
qa_path.write_text(json.dumps([s for s in previous if s['asset'] not in names]+stats,indent=2)+'\n')
manifest_path=ROOT/'assets/graphics/manifest.json'
manifest=json.loads(manifest_path.read_text())
replacements={f"assets/graphics/models/{s['asset']}.glb" for s in stats}
manifest['assets']=[a for a in manifest['assets'] if a['path'] not in replacements]
manifest['assets'].extend(dict(path=f"assets/graphics/models/{s['asset']}.glb",triangles=s['triangles'],bytes=s['bytes'],sha256=s['sha256']) for s in stats)
manifest['assets'].sort(key=lambda a:a['path'])
manifest_path.write_text(json.dumps(manifest,indent=2)+'\n')
print('SCENERY_MODELS_COMPLETE',len(stats),'verified exports')

"""Build three game spruce derivatives from the purchased TreeDesigner preset.

Blender 5.2: --background --factory-startup --disable-autoexec --python-exit-code 1
--python scripts/art/build_treedesigner.py. Original library is read-only.
"""
import bpy
import bmesh
import hashlib
import json
import math
import os
import random
import struct
from pathlib import Path
from mathutils import Vector
import numpy as np

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'TreeDesigner + 400 trees/TreeDesigner.blend'
OUT = ROOT / 'art_source/blender/treedesigner'
MODELS = ROOT / 'assets/graphics/models'
TEX = ROOT / 'assets/graphics/textures'
QA = ROOT / 'artifacts/treedesigner'
for p in [OUT, MODELS, TEX, QA]: p.mkdir(parents=True, exist_ok=True)
source_hash = hashlib.sha256(SOURCE.read_bytes()).hexdigest()
bpy.ops.wm.read_factory_settings(use_empty=True)

def image_file(path, non_color=False):
    img = bpy.data.images.load(str(path), check_existing=True)
    if non_color: img.colorspace_settings.name='Non-Color'
    return img

# Reuse the project's authored fine spruce spray instead of the broad library frond.
needle_source = image_file(TEX/'spruce_needles.png')
needle_pixels = np.empty(needle_source.size[0]*needle_source.size[1]*4,dtype=np.float32)
needle_source.pixels.foreach_get(needle_pixels)
needle = bpy.data.images.new('Alpine spruce spray',width=needle_source.size[0],height=needle_source.size[1],alpha=True)
needle.pixels.foreach_set(needle_pixels)
needle.filepath_raw=str(TEX/'td_spruce_mask.png')
needle.file_format='PNG'
needle.save()
needle = bpy.data.images.load(str(TEX/'td_spruce_mask.png'),check_existing=False)
bark = image_file(TEX/'bark_albedo_high.jpg')
mat=bpy.data.materials.new('TD_Conifer')
mat.use_nodes=True
mat.surface_render_method='DITHERED'
nodes,links=mat.node_tree.nodes,mat.node_tree.links
nodes.clear()
output=nodes.new('ShaderNodeOutputMaterial')
bsdf=nodes.new('ShaderNodeBsdfPrincipled')
bsdf.inputs['Roughness'].default_value=.88
links.new(bsdf.outputs[0],output.inputs['Surface'])
color=nodes.new('ShaderNodeVertexColor'); color.layer_name='Color'
bark_node=nodes.new('ShaderNodeTexImage'); bark_node.image=bark
mask_node=nodes.new('ShaderNodeTexImage'); mask_node.image=needle
def calc(op,a,b):
    n=nodes.new('ShaderNodeMath'); n.operation=op
    for i,v in enumerate([a,b]):
        if isinstance(v,(int,float)): n.inputs[i].default_value=v
        else: links.new(v,n.inputs[i])
    return n.outputs[0]
wood=calc('LESS_THAN',color.outputs['Alpha'],.25)
leaf=calc('MULTIPLY',calc('GREATER_THAN',color.outputs['Alpha'],.4),calc('LESS_THAN',color.outputs['Alpha'],.8))
mask=calc('GREATER_THAN',mask_node.outputs['Alpha'],.35)
opacity=calc('SUBTRACT',1,calc('MULTIPLY',leaf,calc('SUBTRACT',1,mask)))
mix=nodes.new('ShaderNodeMixRGB')
links.new(wood,mix.inputs[0]); links.new(color.outputs['Color'],mix.inputs[1]); links.new(bark_node.outputs['Color'],mix.inputs[2])
links.new(mix.outputs[0],bsdf.inputs['Base Color']); links.new(opacity,bsdf.inputs['Alpha'])

def branch_id(p):
    band=max(0,min(2,int((p.z-.5)/3.4)))
    quadrant=int(((math.atan2(p.y,p.x)+math.pi)%(math.tau))/math.tau*4)
    return band*4+quadrant

def make_mesh(name, faces):
    vertices=[]; polygons=[]; colors=[]; uvs=[]; flex=[]
    for points,uv,color_value,bid in faces:
        offset=len(vertices); vertices.extend(points); polygons.append(tuple(range(offset,offset+len(points))))
        colors.extend([color_value]*len(points)); uvs.extend(uv)
        # glTF flips V. Runtime UV2.y * 12 gives the local pivot height.
        flex.extend([(bid/16.0,1.0-(.9+(bid//4)*3.4)/12.0)]*len(points))
    mesh=bpy.data.meshes.new(name)
    mesh.from_pydata(vertices,[],polygons); mesh.update()
    color_attr=mesh.color_attributes.new(name='Color',type='FLOAT_COLOR',domain='CORNER')
    uv0=mesh.uv_layers.new(name='UVMap'); uv1=mesh.uv_layers.new(name='BranchPivot')
    for p in mesh.polygons:
        p.use_smooth=colors[p.vertices[0]][3]<.25 or colors[p.vertices[0]][3]>.8
        for li in p.loop_indices:
            vi=mesh.loops[li].vertex_index
            color_attr.data[li].color=colors[vi]
            uv0.data[li].uv=uvs[vi]; uv1.data[li].uv=flex[vi]
    bm=bmesh.new(); bm.from_mesh(mesh)
    bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.000001)
    bm.to_mesh(mesh); bm.free(); mesh.update()
    mesh.materials.append(mat)
    obj=bpy.data.objects.new(name,mesh); bpy.context.scene.collection.objects.link(obj)
    return obj

records=[]; tree_objects=[]; branch_records={}
def export(obj,lod,variant):
    bpy.ops.object.select_all(action='DESELECT'); obj.select_set(True); bpy.context.view_layer.objects.active=obj
    path=MODELS/(obj.name+'.glb'); temp=OUT/(obj.name+'.glb')
    old=list(obj.data.materials)
    placeholder=bpy.data.materials.new(old[0].name.split('.')[0]+'.Runtime')
    placeholder.use_nodes=True
    vc=placeholder.node_tree.nodes.new('ShaderNodeVertexColor'); vc.layer_name='Color'
    p=placeholder.node_tree.nodes.get('Principled BSDF')
    placeholder.node_tree.links.new(vc.outputs['Color'],p.inputs['Base Color'])
    placeholder.node_tree.links.new(vc.outputs['Alpha'],p.inputs['Alpha'])
    placeholder.surface_render_method='DITHERED'
    obj.data.materials.clear(); obj.data.materials.append(placeholder)
    bpy.ops.export_scene.gltf(filepath=str(temp),export_format='GLB',use_selection=True,export_animations=False,export_extras=True)
    obj.data.materials.clear()
    for m in old: obj.data.materials.append(m)
    raw=temp.read_bytes(); size=struct.unpack_from('<I',raw,12)[0]; doc=json.loads(raw[20:20+size])
    for m in doc.get('materials',[]): m.pop('alphaMode',None); m.pop('alphaCutoff',None)
    enc=json.dumps(doc,separators=(',',':')).encode(); enc+=b' '*((-len(enc))%4); tail=raw[20+size:]
    temp.write_bytes(struct.pack('<III',0x46546c67,2,20+len(enc)+len(tail))+struct.pack('<II',len(enc),0x4e4f534a)+enc+tail)
    os.replace(temp,path)
    obj.data.calc_loop_triangles(); bpy.context.view_layer.update()
    records.append(dict(asset=obj.name,path=path.relative_to(ROOT).as_posix(),triangles=len(obj.data.loop_triangles),
                        dimensions_m=list(obj.dimensions),bytes=path.stat().st_size,sha256=hashlib.sha256(path.read_bytes()).hexdigest(),lod=lod,variant=variant,surfaces=1))
    print('TD_EXPORT',obj.name,records[-1]['triangles'],flush=True)

for variant,seed in enumerate([103,271,619],1):
    with bpy.data.libraries.load(str(SOURCE),link=False) as (src,dst): dst.objects=['SpruceTree_LowPoly.001']
    original=dst.objects[0]; bpy.context.scene.collection.objects.link(original)
    original.hide_set(False); original.hide_viewport=False; original.hide_render=False
    mod=next(m for m in original.modifiers if m.type=='NODES')
    settings={'Socket_47':seed,'Socket_40':seed+7,'Socket_174':True,'Socket_102':False,
              'Socket_25':10,'Socket_50':5,'Socket_57':5,'Socket_33':.64,
              'Socket_68':1.65,'Socket_65':.8,'Socket_106':.28}
    for key,value in settings.items(): getattr(mod.properties.inputs,key).value=value
    bpy.context.view_layer.update(); deps=bpy.context.evaluated_depsgraph_get()
    mesh=bpy.data.meshes.new_from_object(original.evaluated_get(deps),preserve_all_data_layers=True,depsgraph=deps)
    high=max(v.co.z for v in mesh.vertices)
    rmax=max(math.hypot(v.co.x,v.co.y) for v in mesh.vertices)
    scale_z=10.5/high; scale_xy=[3.0,2.6,3.25][variant-1]/rmax
    uvdata=mesh.attributes.get('New Uv')
    faces=[]; leaves=[]; rng=random.Random(seed)
    branch_points=[[] for _ in range(12)]
    for polygon in mesh.polygons:
        points=[Vector((mesh.vertices[v].co.x*scale_xy,mesh.vertices[v].co.y*scale_xy,mesh.vertices[v].co.z*scale_z)) for v in polygon.vertices]
        center=sum(points,Vector())/len(points)
        leaf_face=polygon.material_index==1
        if center.z<1.05 and leaf_face: continue
        uv=[tuple(uvdata.data[i].vector) for i in polygon.loop_indices] if uvdata else [(0,0)]*len(points)
        bid=branch_id(center)
        if leaf_face:
            shade=rng.uniform(.8,1.2)
            tint=(.055*shade,.135*shade,.073*shade,.6)
            leaves.append((points,uv,tint,bid)); branch_points[bid].append(center)
        else:
            faces.append((points,uv,(.21,.13,.075,0),bid))
    # Geometry snow pillows follow selected outer sprays; they share branch motion.
    caps=[]
    for points,uv,tint,bid in leaves[::max(1,len(leaves)//105)]:
        center=sum(points,Vector())/len(points)
        if math.hypot(center.x,center.y)<.55 or center.z<1.3: continue
        direction=Vector((center.x,center.y,0)).normalized(); side=Vector((-direction.y,direction.x,0))
        length=rng.uniform(.18,.34); width=rng.uniform(.10,.18)
        center.z+=.035
        depth=rng.uniform(.055,.10)
        rings=[]
        for radius,height in [(1,0),(.85,.65),(.45,.95)]:
            rings.append([center+direction*(math.cos(i*math.tau/10)*length*radius)+side*(math.sin(i*math.tau/10)*width*radius)+Vector((0,0,depth*height)) for i in range(10)])
        top=center+Vector((0,0,depth))
        for j in range(2):
            for i in range(10): caps.append(([rings[j][i],rings[j][(i+1)%10],rings[j+1][(i+1)%10],rings[j+1][i]],[(0,0),(1,0),(1,1),(0,1)],(.73,.81,.88,1),bid))
        for i in range(10): caps.append(([rings[-1][i],rings[-1][(i+1)%10],top],[(0,0),(1,0),(.5,1)],(.73,.81,.88,1),bid))
    for lod in [0,1]:
        lodfaces=faces+leaves+caps
        if lod==1:
            # Preserve foliage positions and silhouette. Simplify woody mesh only.
            wood_obj=make_mesh('WoodReduction',faces)
            bpy.context.view_layer.objects.active=wood_obj; wood_obj.select_set(True)
            dec=wood_obj.modifiers.new('Branch simplification','DECIMATE'); dec.ratio=.34
            bpy.ops.object.modifier_apply(modifier=dec.name)
            wood=wood_obj.data; reduced=[]
            for p in wood.polygons:
                pts=[wood.vertices[v].co.copy() for v in p.vertices]; center=sum(pts,Vector())/len(pts)
                reduced.append((pts,[tuple(wood.uv_layers[0].data[i].uv) for i in p.loop_indices],(.21,.13,.075,0),branch_id(center)))
            bpy.data.objects.remove(wood_obj,do_unlink=True)
            lodfaces=reduced+leaves+caps
        obj=make_mesh(f'td_spruce_{variant}_lod{lod}',lodfaces)
        export(obj,lod,variant); obj.hide_render=True
        if lod==0: tree_objects.append(obj)
    branches=[]
    for bid,pts in enumerate(branch_points):
        center=sum(pts,Vector())/len(pts) if pts else Vector((0,0,1+bid//4*3.4))
        radius=max((p-center).length for p in pts) if pts else .3
        branches.append({'center':[center.x,center.z,-center.y],'radius':min(2.2,radius), 'pivot_y':.9+bid//4*3.4})
    branch_records[str(variant)]={'seed':seed,'preset':'SpruceTree_LowPoly.001','settings':settings,'branches':branches}
    bpy.data.objects.remove(original,do_unlink=True)
    bpy.data.meshes.remove(mesh)

# Eight albedo-only directions: weather and illumination remain runtime effects.
emission=nodes.new('ShaderNodeEmission'); links.new(mix.outputs[0],emission.inputs['Color'])
transparent=nodes.new('ShaderNodeBsdfTransparent'); mixed=nodes.new('ShaderNodeMixShader')
links.new(opacity,mixed.inputs[0]); links.new(transparent.outputs[0],mixed.inputs[1]); links.new(emission.outputs[0],mixed.inputs[2]); links.new(mixed.outputs[0],output.inputs['Surface'])
camera_data=bpy.data.cameras.new('Atlas camera'); camera=bpy.data.objects.new('Atlas camera',camera_data)
bpy.context.scene.collection.objects.link(camera); camera_data.type='ORTHO'; camera_data.ortho_scale=11
scene=bpy.context.scene; scene.camera=camera; scene.render.engine='BLENDER_EEVEE'
scene.render.resolution_x=scene.render.resolution_y=512; scene.render.resolution_percentage=100
scene.render.film_transparent=True; scene.render.image_settings.file_format='PNG'; scene.render.image_settings.color_mode='RGBA'
scene.view_settings.view_transform='Standard'
for variant,obj in enumerate(tree_objects,1):
    atlas=np.zeros((512,4096,4),dtype=np.float32); obj.hide_render=False
    for view in range(8):
        angle=view*math.tau/8; camera.location=(math.sin(angle)*25,-math.cos(angle)*25,5.25)
        camera.rotation_euler=(Vector((0,0,5.25))-camera.location).to_track_quat('-Z','Y').to_euler()
        path=QA/f'bake_{variant}_{view}.png'; scene.render.filepath=str(path); bpy.ops.render.render(write_still=True)
        img=bpy.data.images.load(str(path),check_existing=False); pixels=np.empty(512*512*4,dtype=np.float32)
        img.pixels.foreach_get(pixels); atlas[:,view*512:(view+1)*512]=pixels.reshape(512,512,4); bpy.data.images.remove(img)
    obj.hide_render=True
    img=bpy.data.images.new(f'TD_Atlas_{variant}',width=4096,height=512,alpha=True)
    img.pixels.foreach_set(atlas.ravel()); img.file_format='PNG'; img.filepath_raw=str(TEX/f'td_spruce_{variant}_atlas.png'); img.save()
    img.scale(2048,256); img.filepath_raw=str(TEX/f'td_spruce_{variant}_atlas_low.png'); img.save()
    card=make_mesh(f'td_spruce_{variant}_lod2',[([(-5.5,0,-.25),(5.5,0,-.25),(5.5,0,10.75),(-5.5,0,10.75)],[(0,0),(1,0),(1,1),(0,1)],(1,1,1,1),0)])
    card.data.materials.clear(); card.data.materials.append(bpy.data.materials.new(f'TD_Impostor_spruce_{variant}'))
    export(card,2,variant); card.hide_render=True
links.new(bsdf.outputs[0],output.inputs['Surface'])
# Open the derivative file as a usable three-tree review scene.
for obj in list(scene.objects):
    if obj.type=='MESH':
        visible=obj in tree_objects
        obj.hide_render=not visible
        obj.hide_set(not visible)
for variant,obj in enumerate(tree_objects):
    obj.location.x=(variant-1)*8.0
camera.location=(17,-34,16)
camera.rotation_euler=(Vector((0,0,5.0))-camera.location).to_track_quat('-Z','Y').to_euler()
camera_data.ortho_scale=28
scene.render.resolution_x=1920; scene.render.resolution_y=1080
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=='VIEW_3D':
            area.spaces.active.region_3d.view_perspective='CAMERA'
# Editable derivatives contain evaluated meshes; the proprietary generator remains local.
for group in list(bpy.data.node_groups):
    if group.users==0: bpy.data.node_groups.remove(group)
bpy.data.orphans_purge(do_recursive=True)
bpy.ops.file.pack_all()
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'spruce_derivatives.blend'))
for record in records:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(ROOT/record['path']))
    objs=[o for o in bpy.context.scene.objects if o.type=='MESH']; assert len(objs)==1
    o=objs[0]; o.data.calc_loop_triangles()
    assert len(o.data.loop_triangles)==record['triangles']
    assert all(abs(a-b)<.01 for a,b in zip(o.dimensions,record['dimensions_m']))
    if record['lod']<2:
        assert len(o.data.uv_layers)==2 and len(o.data.materials)==1
        assert len(o.data.color_attributes)>0
    record['roundtrip_verified']=True
assert source_hash==hashlib.sha256(SOURCE.read_bytes()).hexdigest()
manifest={'generator':'TreeDesigner by Alexis Eginard; locally purchased library','source_sha256':source_hash,
          'source':str(SOURCE.relative_to(ROOT)),'blender':bpy.app.version_string,'assets':records,'variants':branch_records,
          'motion':'12 canopy clusters per tree; fixed-step angular springs; solid trunk collision unchanged'}
(ROOT/'art_source/treedesigner_manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
(ROOT/'assets/graphics/treedesigner_branches.json').write_text(json.dumps(branch_records,indent=2)+'\n')
print('TREEDESIGNER_COMPLETE',len(records),flush=True)

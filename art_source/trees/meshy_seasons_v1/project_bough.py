"""Bake twelve shallow, intersecting Meshy branch slices offline.

Blender under Exclusive guard: SOURCE.glb OUTPUT.glb. Each slice owns one
quarter of branch depth; it never projects the entire branch onto a flat card.
The same 96-triangle volume serves both LODs with original needle normals.
Also writes light_albedo.png using upward source normals, not slice normals.
Raw source remains unchanged. Runtime loads only the packaged resources.
"""
import bpy,sys,math,os,json,numpy as np
from pathlib import Path
from mathutils import Matrix,Vector
assert os.environ.get('ALPINE_VALIDATION_MODE') == 'Exclusive', 'Run under Exclusive validation admission'
source_path,out=[Path(v).resolve() for v in sys.argv[sys.argv.index('--')+1:]]
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=str(source_path))
source=next(o for o in bpy.context.scene.objects if o.type=='MESH')
source.data.transform(source.matrix_world);source.parent=None;source.matrix_world=Matrix.Identity(4)
coords=np.empty(len(source.data.vertices)*3,np.float32);source.data.vertices.foreach_get('co',coords);coords=coords.reshape(-1,3)
center=coords.mean(0);cov=np.cov(coords[:,:2].T);_,vectors=np.linalg.eigh(cov);axis=vectors[:,-1]
axis=axis if axis[0]>=0 else -axis
angle=math.atan2(axis[1],axis[0]);rotation=Matrix.Rotation(-angle,4,'Z');source.data.transform(rotation)
source.data.vertices.foreach_get('co',coords.ravel());lo=coords.min(0);hi=coords.max(0);center=(lo+hi)/2
length=float(hi[0]-lo[0]);radius=float(max(hi[1]-lo[1],hi[2]-lo[2]))*.55
verts=[];faces=[];uv=[]
for plane in range(12):
 a=(plane//4)*math.pi/3;across=np.array([0,math.cos(a),math.sin(a)]);normal=np.array([0,-math.sin(a),math.cos(a)])
 start=len(verts)
 for j in range(5):
  t=j/4;w=(t*2-1)*radius
  for side in range(2):
   p=center+across*w+normal*(radius*((plane%4+.5)/2-1)+(1-(t*2-1)**2)*radius*.04);p[0]=lo[0]+side*length
   verts.append(p.tolist());uv.append(((plane%4+side*.98+.01)/4,(plane//4+t*.98+.01)/3))
 for j in range(4):faces.append((start+j*2,start+j*2+1,start+j*2+3,start+j*2+2))
mesh=bpy.data.meshes.new('Curved Meshy projections');mesh.from_pydata(verts,[],faces);mesh.update()
target=bpy.data.objects.new('Needle projections',mesh);bpy.context.collection.objects.link(target)
layer=mesh.uv_layers.new(name='UVMap')
for loop in mesh.loops:layer.data[loop.index].uv=uv[loop.vertex_index]
mat=bpy.data.materials.new('Projected Meshy needles');mat.use_nodes=True;mesh.materials.append(mat)
nodes=mat.node_tree.nodes;principled=nodes.get('Principled BSDF');principled.inputs['Roughness'].default_value=.9
width,height=4096,3072
image=bpy.data.images.new('Projected needles',width=width,height=height,alpha=True);image.generated_color=(.025,.05,.015,0)
tex=nodes.new('ShaderNodeTexImage');tex.image=image;nodes.active=tex
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=1;scene.render.threads_mode='FIXED';scene.render.threads=4
bake=scene.render.bake;bake.use_selected_to_active=True;bake.use_clear=False;bake.use_pass_direct=False;bake.use_pass_indirect=False;bake.use_pass_color=True
bake.cage_extrusion=radius*.26;bake.max_ray_distance=radius*.52;bake.margin=4
bpy.ops.object.select_all(action='DESELECT');source.select_set(True);target.select_set(True);bpy.context.view_layer.objects.active=target
bpy.ops.object.bake(type='DIFFUSE');mat.node_tree.links.new(tex.outputs['Color'],principled.inputs['Base Color'])
normal_image=bpy.data.images.new('Projected normals',width=width,height=height,alpha=False);normal_image.colorspace_settings.name='Non-Color';normal_image.generated_color=(.5,.5,1,1)
nt=nodes.new('ShaderNodeTexImage');nt.image=normal_image;nodes.active=nt;bake.normal_space='TANGENT';bpy.ops.object.bake(type='NORMAL');normal_image.pack()
nn=nodes.new('ShaderNodeNormalMap');mat.node_tree.links.new(nt.outputs['Color'],nn.inputs['Color']);mat.node_tree.links.new(nn.outputs['Normal'],principled.inputs['Normal'])
# Bake lighter snow on the actual source needles. Tinting a proxy normal
# would reveal its supporting planes as broad white sheets.
light_image=bpy.data.images.new('Light snow needles',width=width,height=height,alpha=True)
light_image.generated_color=(.025,.05,.015,0)
lt=nodes.new('ShaderNodeTexImage');lt.image=light_image;nodes.active=lt
for sm in source.data.materials:
 sn=sm.node_tree.nodes;links=sm.node_tree.links;bsdf=next(n for n in sn if n.type=='BSDF_PRINCIPLED')
 mix=sn.new('ShaderNodeMixRGB');mix.blend_type='MIX';mix.inputs[2].default_value=(.86,.91,.96,1)
 if bsdf.inputs['Base Color'].is_linked:links.new(bsdf.inputs['Base Color'].links[0].from_socket,mix.inputs[1])
 else:mix.inputs[1].default_value=bsdf.inputs['Base Color'].default_value
 geometry=sn.new('ShaderNodeNewGeometry');separate=sn.new('ShaderNodeSeparateXYZ');links.new(geometry.outputs['Normal'],separate.inputs[0])
 ramp=sn.new('ShaderNodeMapRange');ramp.clamp=True;ramp.inputs['From Min'].default_value=.3;ramp.inputs['From Max'].default_value=.85;ramp.inputs['To Max'].default_value=.42
 links.new(separate.outputs['Z'],ramp.inputs['Value']);links.new(ramp.outputs['Result'],mix.inputs[0]);links.new(mix.outputs[0],bsdf.inputs['Base Color'])
bpy.ops.object.bake(type='DIFFUSE')
coverage=bpy.data.images.new('Projected coverage',width=width,height=height,alpha=False);coverage.colorspace_settings.name='Non-Color';coverage.generated_color=(0,0,0,1)
ct=nodes.new('ShaderNodeTexImage');ct.image=coverage;nodes.active=ct
for sm in source.data.materials:
 em=sm.node_tree.nodes.new('ShaderNodeEmission');em.inputs['Color'].default_value=(1,1,1,1);sm.node_tree.links.new(em.outputs[0],sm.node_tree.nodes.get('Material Output').inputs['Surface'])
bake.margin=0;bpy.ops.object.bake(type='EMIT')
pixels=np.empty(width*height*4,np.float32);mask=np.empty_like(pixels);image.pixels.foreach_get(pixels);coverage.pixels.foreach_get(mask)
pixels.reshape(-1,4)[:,3]=mask.reshape(-1,4)[:,0];image.pixels.foreach_set(pixels);image.pack()
light_pixels=np.empty_like(pixels);light_image.pixels.foreach_get(light_pixels);light_pixels.reshape(-1,4)[:,3]=mask.reshape(-1,4)[:,0];light_image.pixels.foreach_set(light_pixels)
out.parent.mkdir(parents=True,exist_ok=True);light_image.filepath_raw=str(out.parent/'light_albedo.png');light_image.file_format='PNG';light_image.save()
bpy.ops.object.select_all(action='DESELECT');target.select_set(True);bpy.context.view_layer.objects.active=target
out.parent.mkdir(parents=True,exist_ok=True);bpy.ops.export_scene.gltf(filepath=str(out),export_format='GLB',use_selection=True,export_normals=True,export_tangents=True,export_materials='EXPORT',export_animations=False)
report = {'source': str(source_path), 'output': str(out), 'triangles': len(faces)*2,
          'depth_slices': 12, 'atlas_size': [width,height],
          'covered_fraction': float(np.mean(mask.reshape(-1,4)[:,0]>.35)),
          'scope': 'Offline source preparation; rendered and measured game acceptance are separate.'}
(out.parent/'projection.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print('PROJECTED_BOUGH',json.dumps(report),flush=True)

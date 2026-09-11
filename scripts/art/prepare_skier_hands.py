"""Rebuild hand-only derivatives from the retained Meshy source; no paid calls.

Run in a separate background Blender via run_guarded.ps1. Produces a staged
skier GLB; installation is separate and verifies the original asset hash.
"""
import json
import hashlib
import sys
from pathlib import Path
import bpy
import bmesh
from mathutils import Vector

ROOT=Path(__file__).resolve().parents[2]
SOURCE=ROOT/'art_source/meshy/hands_v1'
OUT=ROOT/'artifacts/hands_v1'
OUT.mkdir(parents=True,exist_ok=True)
sys.path.insert(0,str(Path(__file__).resolve().parent))
from glove_graft import graft
from skier_gloves import append_gloves

cache=SOURCE/'candidate_01_reduced.blend'
raw_hash=hashlib.sha256((SOURCE/'candidate_01.glb').read_bytes()).hexdigest()
if cache.exists():
    bpy.ops.wm.open_mainfile(filepath=str(cache))
    glove=next(o for o in bpy.context.scene.objects if o.type=='MESH')
    assert glove.get('raw_sha256')==raw_hash, 'Reduced source cache is stale'
    source_triangles=glove['source_triangles']
else:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(SOURCE/'candidate_01.glb'))
    glove=next(o for o in bpy.context.scene.objects if o.type=='MESH')
    bpy.context.view_layer.objects.active=glove;glove.select_set(True)
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    source_triangles=len(glove.data.polygons)
    bm=bmesh.new();bm.from_mesh(glove.data)
    # Weld Ultra patch boundaries BEFORE simplifying their adjacent surfaces.
    bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.00002)
    bm.to_mesh(glove.data);bm.free()
    print('SOURCE_WELDED',len(glove.data.vertices),len(glove.data.polygons),flush=True)
    dec=glove.modifiers.new('Runtime glove reduction','DECIMATE');dec.ratio=2850/source_triangles
    bpy.ops.object.modifier_apply(modifier=dec.name)
    glove['raw_sha256']=raw_hash;glove['source_triangles']=source_triangles
    bpy.ops.file.pack_all();bpy.ops.wm.save_as_mainfile(filepath=str(cache))
bpy.context.view_layer.objects.active=glove;glove.select_set(True)
bm=bmesh.new();bm.from_mesh(glove.data)
bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.00001)
# Remove generated floating specks. Keep the main connected wearable shell.
remaining=set(bm.verts);components=[]
while remaining:
    pending=[remaining.pop()];group=set(pending)
    while pending:
        v=pending.pop()
        for e in v.link_edges:
            other=e.other_vert(v)
            if other in remaining:remaining.remove(other);group.add(other);pending.append(other)
    components.append(group)
largest=max(components,key=len)
assert len(largest)>.95*len(bm.verts), 'Reduction fragmented the glove; do not export a partial hand'
discard=[v for group in components if group is not largest for v in group]
if discard:bmesh.ops.delete(bm,geom=discard,context='VERTS')
bm.to_mesh(glove.data);bm.free()
fit=json.loads((SOURCE/'fit.json').read_text())
from glove_fit import fit_point
for v in glove.data.vertices:v.co=fit_point(v.co,fit)
bm=bmesh.new();bm.from_mesh(glove.data)
bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.00003)
bmesh.ops.dissolve_degenerate(bm,edges=list(bm.edges),dist=.000001)
tiny_bridges=[e for e in bm.edges if not e.is_manifold and e.calc_length()<.0002]
if tiny_bridges:bmesh.ops.collapse(bm,edges=tiny_bridges,uvs=True)
bmesh.ops.reverse_faces(bm,faces=list(bm.faces));bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
# Relax only the cuff; retain the generated knuckles and finger silhouettes.
cuff=[v for v in bm.verts if v.co.x<.035]
for _ in range(3):bmesh.ops.smooth_vert(bm,verts=cuff,factor=.35,use_axis_x=True,use_axis_y=True,use_axis_z=True)
bm.to_mesh(glove.data);bm.free()
if glove.data.has_custom_normals:bpy.ops.mesh.customdata_custom_splitnormals_clear()
for f in glove.data.polygons:f.use_smooth=True
glove.name='GloveTemplate';glove.data.name='ConnectedGloveV1'
mat=glove.data.materials[0];mat.name='SkierV7Gloves'
shader=mat.node_tree.nodes.get('Principled BSDF')
for key in ['Emission Color','Emission Strength']:
    for link in list(shader.inputs[key].links):mat.node_tree.links.remove(link)
shader.inputs['Emission Color'].default_value=(0,0,0,1);shader.inputs['Emission Strength'].default_value=0
shader.inputs['Metallic'].default_value=0
for link in list(shader.inputs['Metallic'].links):mat.node_tree.links.remove(link)
mat.use_backface_culling=True
for node in mat.node_tree.nodes:
    if node.type=='NORMAL_MAP':node.inputs['Strength'].default_value=.6
glove.data.calc_loop_triangles()
assert len(glove.data.loop_triangles)<=3000
assert len(glove.data.loop_triangles)>2000, 'Glove silhouette needs its full geometry budget'
bm=bmesh.new();bm.from_mesh(glove.data)
topology={'boundary_edges':sum(e.is_boundary for e in bm.edges),'nonmanifold_edges':sum(not e.is_manifold for e in bm.edges),'components_removed':len(components)-1}
bm.free()
template_bounds=[[min(v.co[i] for v in glove.data.vertices) for i in range(3)],
                 [max(v.co[i] for v in glove.data.vertices) for i in range(3)]]
print('GLOVE_TEMPLATE',json.dumps({'source_triangles':source_triangles,'triangles':len(glove.data.loop_triangles),'bounds':template_bounds,'topology':topology}),flush=True)
assert topology['boundary_edges']==0 and topology['nonmanifold_edges']==0
from bake_glove_details import bake_details
glove=bake_details(glove,fit,SOURCE,raw_hash)
bpy.ops.file.pack_all()
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art_source/blender/skier_glove_v1.blend'))

# Export only the new surface with the existing named skin. The GLB graft keeps
# the rest of the runtime asset byte-for-byte, including its inverse bind data.
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(SOURCE/'baseline/skier_v7.glb'))
arm=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE')
body=next(o for o in bpy.context.scene.objects if o.type=='MESH' and any(m.type=='ARMATURE' for m in o.modifiers))
body.data.clear_geometry();body.data.materials.clear();body.name='SkierGlovesV1'
append_gloves(body,arm)
bpy.ops.object.select_all(action='DESELECT');body.select_set(True);arm.select_set(True)
bpy.context.view_layer.objects.active=body
bpy.ops.export_scene.gltf(filepath=str(SOURCE/'fitted_gloves.glb'),export_format='GLB',use_selection=True,export_animations=False,export_apply=False)
stats=graft(SOURCE/'baseline/skier_v7.glb',SOURCE/'fitted_gloves.glb',SOURCE/'skier_staged.glb')
stats.update({'source_triangles':source_triangles,'template_bounds_m':template_bounds,'template_topology':topology,'fit':fit})

# Independently reimport the actual graft, rather than trusting the exporter.
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(SOURCE/'skier_staged.glb'))
arm=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE')
body=next(o for o in bpy.context.scene.objects if o.type=='MESH' and any(m.type=='ARMATURE' for m in o.modifiers))
assert len(arm.data.bones)==24 and body.data.uv_layers
slot=next(i for i,m in enumerate(body.data.materials) if m.name=='SkierV7Gloves')
ids={v for f in body.data.polygons if f.material_index==slot for v in f.vertices}
for i in ids:
    weights=body.data.vertices[i].groups
    assert abs(sum(g.weight for g in weights)-1)<.00001
    assert all(body.vertex_groups[g.group].name in ['LeftHand','RightHand','LeftForeArm','RightForeArm'] for g in weights if g.weight>0)
glove_mat=body.data.materials[slot]
images=[node.image for node in glove_mat.node_tree.nodes if node.type=='TEX_IMAGE' and node.image]
assert len(images)>=3 and all(max(im.size)<=2048 for im in images)
stats['roundtrip_verified']=True;stats['skin_weights_verified']=True
stats['texture_sizes']=[list(im.size) for im in images]
# Keep the editable assembly's separate boots and object layout intact too.
bpy.ops.wm.open_mainfile(filepath=str(SOURCE/'baseline/skier_v7.blend'))
arm=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE')
body=next(o for o in bpy.context.scene.objects if o.type=='MESH' and any(m.type=='ARMATURE' for m in o.modifiers))
append_gloves(body,arm,remove_existing=True)
bpy.ops.file.pack_all()
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/'skier_staged.blend'))
(SOURCE/'runtime_qa.json').write_text(json.dumps(stats,indent=2)+'\n')
print('HANDS_PREPARED',json.dumps(stats),flush=True)

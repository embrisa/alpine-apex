"""Build a tree from one Meshy bough; isolated authoring experiment only.

Blender 5.2, Exclusive guard. -- SOURCE OUTPUT_DIR [--flip]
Preserves the branch UVs. Each complete branch has one UV2 contact group/pivot.
Near and middle use identical branch placements, derived from one fixed seed.
"""
import argparse
import json
import math
import random
import sys
from pathlib import Path
import bpy
import bmesh
from mathutils import Matrix, Vector

parser=argparse.ArgumentParser()
parser.add_argument('source',type=Path)
parser.add_argument('output',type=Path)
parser.add_argument('--flip',action='store_true')
args=parser.parse_args(sys.argv[sys.argv.index('--')+1:])
args.output.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(args.source.resolve()))
objects=[o for o in bpy.context.scene.objects if o.type=='MESH']
assert len(objects)==1
source=objects[0]
bpy.context.view_layer.objects.active=source
source.data.transform(source.matrix_world)
source.parent=None
source.matrix_world=Matrix.Identity(4)
source.rotation_mode='XYZ'
assert len(source.data.materials)==1
material=source.data.materials[0]

# Align the longest horizontal direction with X, preserving world-up snow.
coords=[v.co.copy() for v in source.data.vertices]
mean=sum(coords,Vector())/len(coords)
xx=sum((v.x-mean.x)**2 for v in coords)
yy=sum((v.y-mean.y)**2 for v in coords)
xy=sum((v.x-mean.x)*(v.y-mean.y) for v in coords)
theta=.5*math.atan2(2*xy,xx-yy)
rotation=Matrix.Rotation(-theta+(math.pi if args.flip else 0),4,'Z')
source.data.transform(rotation)
coords=[v.co.copy() for v in source.data.vertices]
lo=min(v.x for v in coords); hi=max(v.x for v in coords)
ends=[]
for side in [False,True]:
    points=[v for v in coords if (v.x>hi-(hi-lo)*.05 if side else v.x<lo+(hi-lo)*.05)]
    center=sum(points,Vector())/len(points)
    ends.append((sum((v-center).length_squared for v in points)/len(points),center))
if not args.flip and ends[1][0]<ends[0][0]:
    source.data.transform(Matrix.Rotation(math.pi,4,'Z'))
coords=[v.co.copy() for v in source.data.vertices]
lo=min(v.x for v in coords); hi=max(v.x for v in coords)
root_points=[v for v in coords if v.x<lo+(hi-lo)*.035]
root=sum(root_points,Vector())/len(root_points)
root.x=lo
for v in source.data.vertices: v.co=(v.co-root)/(hi-lo)
source.data.update()
original_triangles=sum(len(p.vertices)-2 for p in source.data.polygons)

# Retain a bark sample at the attachment end for the small visible stem.
uv=source.data.uv_layers.active.data
bark_face=min(source.data.polygons,key=lambda p:(p.center-Vector((.06,0,0))).length_squared)
bark_uv=sum((uv[i].uv for i in bark_face.loop_indices),Vector((0,0)))/len(bark_face.loop_indices)
base=material.node_tree.nodes.get('Principled BSDF').inputs['Base Color']
if base.is_linked and base.links[0].from_node.type=='TEX_IMAGE':
    image=base.links[0].from_node.image
    pixels=list(image.pixels[:]); width,height=image.size
    best=-1
    for loop in source.data.loops:
        if source.data.vertices[loop.vertex_index].co.x>.20: continue
        point=uv[loop.index].uv
        px=min(width-1,max(0,int(point.x*width))); py=min(height-1,max(0,int(point.y*height)))
        r,g,b=pixels[(py*width+px)*4:(py*width+px)*4+3]
        score=r-g+g-b if r>g and g>b and .025<r<.35 else -1
        if score>best: best=score; bark_uv=point.copy()
    del pixels

rng=random.Random(18241)
placements=[]
for kind,count in [('outer',36),('inner',48)]:
    for index in range(count):
        t=index/(count-1)
        y=1.7+10.1*(1-(1-t)**1.4)
        length=3.1*max(.015,(12-y)/10.3)**.68
        placements.append(dict(height=y+rng.uniform(-.16,.16)*(1-t),
            length=length*rng.uniform(.90,1.09)*(1 if kind=='outer' else rng.uniform(.55,.78)),
            angle=index*2.399963+rng.uniform(-.24,.24)+(1.2 if kind=='inner' else 0),
            pitch=rng.uniform(-.13,.08),width=rng.uniform(1.15,1.55),group=index%12,kind=kind))

report={'source':str(args.source),'source_triangles':original_triangles,
        'branch_count':len(placements),'seed':18241,'placements':placements,'lods':[],
        'scope':'Source assembly only; visual, wind, game and FPS gates remain.'}
for lod in [0,1]:
    bpy.ops.object.select_all(action='DESELECT')
    templates={}; branch_triangles={}
    for kind,target in {'outer':800 if lod==0 else 160,'inner':240 if lod==0 else 48}.items():
        branch=source.copy(); branch.data=source.data.copy(); bpy.context.collection.objects.link(branch)
        bpy.context.view_layer.objects.active=branch; branch.select_set(True)
        bm=bmesh.new(); bm.from_mesh(branch.data)
        bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.000001)
        bmesh.ops.split_edges(bm,edges=[e for e in bm.edges if len(e.link_faces)>2])
        bm.to_mesh(branch.data); bm.free()
        branch.data.validate(clean_customdata=False)
        collapse=branch.modifiers.new('Per-bough triangle budget','DECIMATE')
        collapse.ratio=min(1,target/original_triangles); collapse.use_collapse_triangulate=True
        bpy.ops.object.modifier_apply(modifier=collapse.name)
        branch.data.validate(clean_customdata=False)
        for p in branch.data.polygons: p.use_smooth=True
        branch_triangles[kind]=sum(len(p.vertices)-2 for p in branch.data.polygons)
        templates[kind]=branch
        branch.select_set(False)
    parts=[]
    for item in placements:
        branch=templates[item['kind']]
        obj=branch.copy(); obj.data=branch.data.copy(); bpy.context.collection.objects.link(obj)
        obj.rotation_mode='XYZ'
        obj.location=(0,0,item['height'])
        obj.rotation_euler=(0,item['pitch'],item['angle'])
        obj.scale=(item['length'],item['length']*item['width'],item['length'])
        tags=obj.data.uv_layers.new(name='BranchPivot')
        # glTF flips Blender's V coordinate during export/import.
        for loop in tags.data: loop.uv=(item['group']/16,1-item['height']/32)
        parts.append(obj)
    for branch in templates.values(): bpy.data.objects.remove(branch,do_unlink=True)
    bpy.ops.mesh.primitive_cone_add(vertices=12,radius1=.18,radius2=.008,depth=12,location=(0,0,6))
    trunk=bpy.context.object; trunk.data.materials.append(material)
    trunk.data.uv_layers.active.name=source.data.uv_layers.active.name
    for loop in trunk.data.uv_layers.active.data: loop.uv=bark_uv
    tags=trunk.data.uv_layers.new(name='BranchPivot')
    for loop in tags.data: loop.uv=(0,1)
    for p in trunk.data.polygons: p.use_smooth=True
    parts.append(trunk)
    bpy.ops.object.select_all(action='DESELECT')
    for obj in parts: obj.select_set(True)
    bpy.context.view_layer.objects.active=trunk
    bpy.ops.object.join()
    tree=bpy.context.object; tree.name='SnowBoughTree_LOD'+str(lod)
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    triangulate=tree.modifiers.new('Export triangles','TRIANGULATE')
    bpy.ops.object.modifier_apply(modifier=triangulate.name)
    output=args.output/('tree_lod'+str(lod)+'.glb')
    bpy.ops.export_scene.gltf(filepath=str(output.resolve()),export_format='GLB',use_selection=True,
        export_normals=True,export_tangents=True,export_materials='EXPORT',export_animations=False)
    report['lods'].append(dict(lod=lod,branch_triangles=branch_triangles,
        triangles=sum(len(p.vertices)-2 for p in tree.data.polygons),path=str(output)))
    bpy.data.objects.remove(tree,do_unlink=True)
(args.output/'assembly.json').write_text(json.dumps(report,indent=2)+'\n')
print('BOUGH_ASSEMBLY',json.dumps(report),flush=True)

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
parser.add_argument('--keep-root',action='store_true',help='Keep the authored minimum-X root; use for symmetric projection bounds')
parser.add_argument('--species',choices=['spruce','fir','stone_pine'],default='spruce')
parser.add_argument('--seed',type=int,default=18241)
parser.add_argument('--near-outer',type=int,default=800)
parser.add_argument('--near-inner',type=int,default=240)
parser.add_argument('--relax-tips',type=float,default=0.0)
parser.add_argument('--mid-outer',type=int,default=320)
parser.add_argument('--mid-inner',type=int,default=96)
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
if not args.flip and not args.keep_root and ends[1][0]<ends[0][0]:
    source.data.transform(Matrix.Rotation(math.pi,4,'Z'))
coords=[v.co.copy() for v in source.data.vertices]
lo=min(v.x for v in coords); hi=max(v.x for v in coords)
root_points=[v for v in coords if v.x<lo+(hi-lo)*.035]
root=sum(root_points,Vector())/len(root_points)
root.x=lo
for v in source.data.vertices: v.co=(v.co-root)/(hi-lo)
source.data.update()
original_triangles=sum(len(p.vertices)-2 for p in source.data.polygons)

# Crown recipes share the repaired snowy bough, but retain distinct proportions
# and branch distributions. Both LODs use the exact same placement recipe.
recipes={
    'spruce':dict(outer=36,inner=48,base=1.7,radius=3.1,taper=.68,pitch=(-.13,.08),width=(1.15,1.55)),
    'fir':dict(outer=40,inner=42,base=1.15,radius=3.45,taper=.88,pitch=(-.02,.16),width=(1.3,1.7)),
    'stone_pine':dict(outer=30,inner=42,base=3.5,radius=3.9,taper=.40,pitch=(-.25,-.03),width=(1.2,1.65)),
}
recipe=recipes[args.species]
rng=random.Random(args.seed)
placements=[]
for kind,count in [('outer',recipe['outer']),('inner',recipe['inner'])]:
    for index in range(count):
        t=index/(count-1)
        y=recipe['base']+(11.8-recipe['base'])*(1-(1-t)**1.4)
        length=recipe['radius']*max(.015,(12-y)/(12-recipe['base']))**recipe['taper']
        placements.append(dict(height=y+rng.uniform(-.16,.16)*(1-t),
            length=length*rng.uniform(.90,1.09)*(1 if kind=='outer' else rng.uniform(.55,.78)),
            angle=index*2.399963+rng.uniform(-.24,.24)+(1.2 if kind=='inner' else 0),
            pitch=rng.uniform(*recipe['pitch']),width=rng.uniform(*recipe['width']),group=index%12,kind=kind,
            shade=rng.uniform(.92,1.0)))

report={'source':str(args.source),'source_triangles':original_triangles,
        'alignment':dict(flip=args.flip,keep_root=args.keep_root,ends=[{'variance':float(e[0]),'center':list(e[1])} for e in ends],root=list(root)),
        'branch_count':len(placements),'seed':args.seed,'species':args.species,'recipe':recipe,'placements':placements,'lods':[],
        'scope':'Source assembly only; visual, wind, game and FPS gates remain.'}
for lod in [0,1]:
    bpy.ops.object.select_all(action='DESELECT')
    templates={}; branch_triangles={}
    for kind,target in {'outer':args.near_outer if lod==0 else args.mid_outer,'inner':args.near_inner if lod==0 else args.mid_inner}.items():
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
        if args.relax_tips>0:
            # Collapse can leave sharp needle wedges even on a closed source.
            # Relax the final LOD, after its reduction rather than only before it.
            rounding=branch.modifiers.new('Round reduced bough tips','SMOOTH')
            rounding.factor=args.relax_tips;rounding.iterations=2
            bpy.ops.object.modifier_apply(modifier=rounding.name)
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
        colors=obj.data.color_attributes.new(name='Role',type='FLOAT_COLOR',domain='CORNER')
        for value in colors.data: value.color=(item['shade'],item['shade'],item['shade'],.55)
        parts.append(obj)
    for branch in templates.values(): bpy.data.objects.remove(branch,do_unlink=True)
    bpy.ops.mesh.primitive_cone_add(vertices=12,radius1=.18,radius2=.008,depth=12,location=(0,0,6))
    trunk=bpy.context.object; trunk.data.materials.append(material)
    trunk.data.uv_layers.active.name=source.data.uv_layers.active.name
    # Cylindrical meters: production bark repeats vertically without a seam
    # across triangles. The role alpha routes the same opaque material to bark.
    for poly in trunk.data.polygons:
        angles=[math.atan2(trunk.data.vertices[trunk.data.loops[i].vertex_index].co.y,
                           trunk.data.vertices[trunk.data.loops[i].vertex_index].co.x)/math.tau for i in poly.loop_indices]
        wraps=max(angles)-min(angles)>.5
        for i,u in zip(poly.loop_indices,angles):
            if wraps and u<0: u+=1
            v=trunk.data.vertices[trunk.data.loops[i].vertex_index].co
            trunk.data.uv_layers.active.data[i].uv=(u*2,(v.z+6)*.75)
    colors=trunk.data.color_attributes.new(name='Role',type='FLOAT_COLOR',domain='CORNER')
    for value in colors.data: value.color=(.85,.87,.89,0)
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
        export_normals=True,export_tangents=True,export_materials='EXPORT',export_animations=False,
        export_vertex_color='NAME',export_vertex_color_name='Role',export_all_vertex_colors=False)
    report['lods'].append(dict(lod=lod,branch_triangles=branch_triangles,
        triangles=sum(len(p.vertices)-2 for p in tree.data.polygons),path=str(output)))
    bpy.data.objects.remove(tree,do_unlink=True)
(args.output/'assembly.json').write_text(json.dumps(report,indent=2)+'\n')
print('BOUGH_ASSEMBLY',json.dumps({k:v for k,v in report.items() if k!='placements'}),flush=True)

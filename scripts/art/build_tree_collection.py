"""TreeDesigner-derived alpine collection, with textured curved needle clusters.

Blender 5.2 background: --python scripts/art/build_tree_collection.py -- --asset forest_spruce_01
Without --asset builds the collection. --resume skips verified completed exports.
"""
import argparse
import bpy
import bmesh
import hashlib
import json
import math
import os
import random
import struct
import sys
from pathlib import Path
from mathutils import Vector
from mathutils.kdtree import KDTree
import numpy as np
sys.path.insert(0, str(Path(__file__).resolve().parent))
import foliage_clusters

ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / 'assets/graphics/trees'
SOURCE = ROOT / 'TreeDesigner + 400 trees/TreeDesigner.blend'
EDIT = ROOT / 'art_source/blender/tree_collection'
QA = ROOT / 'artifacts/trees_v2'
for p in [BASE/'models', BASE/'textures', EDIT, QA]: p.mkdir(parents=True, exist_ok=True)
args = argparse.ArgumentParser()
args.add_argument('--asset'); args.add_argument('--resume', action='store_true')
args.add_argument('--skip-atlas', action='store_true')
args.add_argument('--bake-needles', action='store_true')
args.add_argument('--living-only', action='store_true')
opt = args.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
FAMILIES = {
    'spruce': {'label':'Alpine spruce', 'heights':[6,10.5,14,18], 'radius':.25, 'leaf':1.25},
    'fir': {'label':'Silver fir', 'heights':[7,11,15,20], 'radius':.22, 'leaf':1.10},
    'pine': {'label':'Mountain pine', 'heights':[6,10,13,16], 'radius':.34, 'leaf':1.0},
    'birch': {'label':'Winter birch', 'heights':[6,10,14,17], 'radius':.27, 'leaf':0},
    'dead': {'label':'Dead snags', 'heights':[5,8,12,16], 'radius':.22, 'leaf':0},
    'broken': {'label':'Broken crowns', 'heights':[4,7,10.5,14], 'radius':.24, 'leaf':0},
}
source_hash = hashlib.sha256(SOURCE.read_bytes()).hexdigest()
manifest_path = BASE/'manifest.json'
manifest = json.loads(manifest_path.read_text()) if manifest_path.exists() else {
    'version':2, 'source':str(SOURCE.relative_to(ROOT)), 'source_sha256':source_hash,
    'families':FAMILIES, 'assets':[], 'needle_geometry':'Opaque tapered V-section needles on radial shoots; no leaf cards',
}
manifest['families'] = FAMILIES
manifest['blender'] = bpy.app.version_string
for previous in manifest['assets']:
    if 'nominal_height_m' not in previous:
        previous['nominal_height_m']=previous['height_m']
        previous['height_m']=round(previous['models'][0]['dimensions_blender_xyz_m'][2],3)


def cluster(p, height):
    band = max(0, min(2, int(p.z/height*3)))
    return band*4 + int((math.atan2(p.y,p.x)+math.pi)%math.tau/math.tau*4)


def wood_components(mesh):
    """TreeDesigner's individual branch tubes, kept whole when pruning."""
    adjacent={}; by_vertex={}
    for poly in mesh.polygons:
        if poly.material_index==1: continue
        for a,b in poly.edge_keys:
            adjacent.setdefault(a,set()).add(b); adjacent.setdefault(b,set()).add(a)
        for v in poly.vertices: by_vertex.setdefault(v,[]).append(poly.index)
    seen=set(); result=[]
    for start in adjacent:
        if start in seen: continue
        stack=[start]; vertices=set()
        while stack:
            v=stack.pop()
            if v in vertices: continue
            vertices.add(v); stack.extend(adjacent[v]-vertices)
        seen.update(vertices)
        result.append((sorted(vertices),{p for v in vertices for p in by_vertex[v]}))
    return result


def clip_crown(points,uvs,height):
    """Clip a woody surface and interpolate its existing bark UVs."""
    out=[]; tex=[]; edge=[]
    for i,p in enumerate(points):
        q=points[(i+1)%len(points)]; a=Vector(uvs[i]); b=Vector(uvs[(i+1)%len(points)])
        if p.z<=height: out.append(p); tex.append(tuple(a))
        if (p.z<=height)!=(q.z<=height):
            t=(height-p.z)/(q.z-p.z); v=p.lerp(q,t)
            out.append(v); tex.append(tuple(a.lerp(b,t))); edge.append(v.copy())
    return out,tex,edge


class Geometry:
    def __init__(self, height):
        self.height=height; self.points=[]; self.faces=[]; self.colors=[]; self.uvs=[]; self.ids=[]

    def face(self, points, color, bid=None, uv=None):
        pts=[Vector(p) for p in points]; n=len(pts); start=len(self.points)
        self.points.extend(pts); self.faces.append(tuple(range(start,start+n)))
        self.colors.extend([color]*n)
        self.ids.extend([cluster(sum(pts,Vector())/n,self.height) if bid is None else bid]*n)
        self.uvs.extend(uv or [(0,0),(1,0),(1,1),(0,1)][:n])

    def tube(self, points, radii, color, sides=5, bid=None):
        rings=[]
        for j,p in enumerate(points):
            tangent=(points[min(j+1,len(points)-1)]-points[max(0,j-1)]).normalized()
            side=tangent.cross(Vector((0,0,1)))
            if side.length<.01: side=Vector((1,0,0))
            side.normalize(); up=tangent.cross(side).normalized()
            rings.append([p+(side*math.cos(i*math.tau/sides)+up*math.sin(i*math.tau/sides))*radii[j] for i in range(sides)])
        total=0.0
        for j in range(len(rings)-1):
            length=(points[j+1]-points[j]).length
            for i in range(sides):
                self.face([rings[j][i],rings[j][(i+1)%sides],rings[j+1][(i+1)%sides],rings[j+1][i]],color,bid,
                          [(i/sides,total),((i+1)/sides,total),((i+1)/sides,total+length),(i/sides,total+length)])
            total+=length

    def snow(self, start, end, width, bid, rng):
        along=(end-start).normalized(); side=along.cross(Vector((0,0,1))).normalized()
        rings=[]
        for t in [0,.22,.65,1]:
            scale=math.sin(math.pi*(.06+t*.88))
            c=start.lerp(end,t)+Vector((0,0,width*.24))
            rings.append([c+side*(u*width*scale)+Vector((0,0,(1-u*u)*width*.38)) for u in [-1,-.5,0,.5,1]])
        for j in range(3):
            for i in range(4): self.face([rings[j][i],rings[j][i+1],rings[j+1][i+1],rings[j+1][i]],(.78,.84,.88,1),bid)

    def object(self, name, material):
        mesh=bpy.data.meshes.new(name); mesh.from_pydata(self.points,[],self.faces); mesh.update()
        colors=mesh.color_attributes.new(name='Color',type='FLOAT_COLOR',domain='CORNER')
        uv=mesh.uv_layers.new(name='UVMap'); pivots=mesh.uv_layers.new(name='BranchPivot')
        for p in mesh.polygons:
            p.use_smooth=self.colors[p.vertices[0]][3]<.4 or self.colors[p.vertices[0]][3]>.9
            for li in p.loop_indices:
                vi=mesh.loops[li].vertex_index; bid=self.ids[vi]
                colors.data[li].color=self.colors[vi]; uv.data[li].uv=self.uvs[vi]
                pivots.data[li].uv=(bid/16,1-((bid//4+.08)*self.height/3)/32)
        bm=bmesh.new(); bm.from_mesh(mesh); bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.000001)
        bm.to_mesh(mesh); bm.free(); mesh.update()
        mesh.materials.append(material)
        obj=bpy.data.objects.new(name,mesh); bpy.context.scene.collection.objects.link(obj)
        return obj


def material():
    mat=bpy.data.materials.new('FC_Tree'); mat.use_nodes=True
    n=mat.node_tree.nodes; l=mat.node_tree.links
    bsdf=n.get('Principled BSDF'); bsdf.inputs['Roughness'].default_value=.85
    vc=n.new('ShaderNodeVertexColor'); vc.layer_name='Color'
    tex=n.new('ShaderNodeTexImage'); tex.image=bpy.data.images.load(str(ROOT/'assets/graphics/textures/bark_albedo_high.jpg'))
    wood=n.new('ShaderNodeMath'); wood.operation='LESS_THAN'; l.new(vc.outputs['Alpha'],wood.inputs[0]); wood.inputs[1].default_value=.4
    tint=n.new('ShaderNodeMixRGB'); tint.blend_type='MULTIPLY'; tint.inputs[0].default_value=1
    l.new(tex.outputs['Color'],tint.inputs[1]); l.new(vc.outputs['Color'],tint.inputs[2])
    mix=n.new('ShaderNodeMixRGB'); l.new(wood.outputs[0],mix.inputs[0]); l.new(vc.outputs['Color'],mix.inputs[1]); l.new(tint.outputs[0],mix.inputs[2])
    birch_low=n.new('ShaderNodeMath'); birch_low.operation='GREATER_THAN'; l.new(vc.outputs['Alpha'],birch_low.inputs[0]); birch_low.inputs[1].default_value=.16
    birch_high=n.new('ShaderNodeMath'); birch_high.operation='LESS_THAN'; l.new(vc.outputs['Alpha'],birch_high.inputs[0]); birch_high.inputs[1].default_value=.25
    birch_mask=n.new('ShaderNodeMath'); birch_mask.operation='MULTIPLY'; l.new(birch_low.outputs[0],birch_mask.inputs[0]); l.new(birch_high.outputs[0],birch_mask.inputs[1])
    final=n.new('ShaderNodeMixRGB'); l.new(birch_mask.outputs[0],final.inputs[0]); l.new(mix.outputs[0],final.inputs[1]); final.inputs[2].default_value=(.57,.56,.51,1)
    l.new(final.outputs[0],bsdf.inputs['Base Color'])
    return mat, final.outputs[0]


def export(obj, path):
    bpy.ops.object.select_all(action='DESELECT'); obj.hide_set(False); obj.select_set(True); bpy.context.view_layer.objects.active=obj
    old=obj.data.materials[0]
    placeholder=bpy.data.materials.new(old.name.split('.')[0]+'.Runtime'); placeholder.use_nodes=True
    vc=placeholder.node_tree.nodes.new('ShaderNodeVertexColor'); vc.layer_name='Color'
    p=placeholder.node_tree.nodes.get('Principled BSDF'); p.inputs['Roughness'].default_value=.86
    placeholder.node_tree.links.new(vc.outputs['Color'],p.inputs['Base Color']); placeholder.node_tree.links.new(vc.outputs['Alpha'],p.inputs['Alpha'])
    placeholder.surface_render_method='DITHERED'; obj.data.materials[0]=placeholder
    tmp=QA/path.name
    bpy.ops.export_scene.gltf(filepath=str(tmp),export_format='GLB',use_selection=True,export_animations=False)
    obj.data.materials[0]=old
    raw=tmp.read_bytes(); size=struct.unpack_from('<I',raw,12)[0]; doc=json.loads(raw[20:20+size])
    for m in doc.get('materials',[]): m.pop('alphaMode',None); m.pop('alphaCutoff',None)
    data=json.dumps(doc,separators=(',',':')).encode(); data+=b' '*((-len(data))%4); tail=raw[20+size:]
    tmp.write_bytes(struct.pack('<III',0x46546c67,2,20+len(data)+len(tail))+struct.pack('<II',len(data),0x4e4f534a)+data+tail)
    os.replace(tmp,path); obj.data.calc_loop_triangles(); bpy.context.view_layer.update()
    return {'path':path.relative_to(ROOT).as_posix(),'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),
            'triangles':len(obj.data.loop_triangles),'bytes':path.stat().st_size,'dimensions_blender_xyz_m':list(obj.dimensions)}


def bake(obj, mat, color_socket, name, height):
    scene=bpy.context.scene; n=mat.node_tree.nodes; l=mat.node_tree.links
    output=n.get('Material Output'); emission=n.new('ShaderNodeEmission'); l.new(color_socket,emission.inputs[0]); l.new(emission.outputs[0],output.inputs['Surface'])
    cam=bpy.data.objects.new('Atlas camera',bpy.data.cameras.new('Atlas camera')); scene.collection.objects.link(cam); scene.camera=cam
    cam.data.type='ORTHO'; cam.data.ortho_scale=height*1.12
    scene.render.engine='BLENDER_EEVEE'; scene.eevee.taa_render_samples=16
    scene.render.resolution_x=scene.render.resolution_y=512; scene.render.resolution_percentage=100
    scene.render.film_transparent=True; scene.render.image_settings.color_mode='RGBA'; scene.view_settings.view_transform='Standard'
    atlas=np.zeros((512,4096,4),dtype=np.float32)
    for view in range(8):
        a=view*math.tau/8; cam.location=(math.sin(a)*height*3,-math.cos(a)*height*3,height*.5)
        cam.rotation_euler=(Vector((0,0,height*.5))-cam.location).to_track_quat('-Z','Y').to_euler()
        p=QA/'bake.png'; scene.render.filepath=str(p); bpy.ops.render.render(write_still=True)
        img=bpy.data.images.load(str(p),check_existing=False); pixels=np.empty(512*512*4,dtype=np.float32)
        img.pixels.foreach_get(pixels); atlas[:,view*512:(view+1)*512]=pixels.reshape(512,512,4); bpy.data.images.remove(img)
    image=bpy.data.images.new(name+' atlas',width=4096,height=512,alpha=True)
    image.pixels.foreach_set(atlas.ravel()); image.file_format='PNG'; image.filepath_raw=str(BASE/'textures'/f'{name}_atlas.png'); image.save()
    image.scale(2048,256); image.filepath_raw=str(BASE/'textures'/f'{name}_atlas_low.png'); image.save()
    l.new(n.get('Principled BSDF').outputs[0],output.inputs['Surface']); bpy.data.objects.remove(cam,do_unlink=True)


def build(family, variant):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    recipe=FAMILIES[family]; height=recipe['heights'][variant-1]; seed=1307+list(FAMILIES).index(family)*311+variant*73
    name=f'forest_{family}_{variant:02}'; rng=random.Random(seed)
    # The first birch preset has a conifer-like fan of hundreds of twig tubes;
    # use a forked birch source with a distinct seed for the young variant.
    preset='BirchTree_LowPoly.%03d' % ([32,32,33,34][variant-1]) if family=='birch' else 'SpruceTree_LowPoly.%03d' % ([1,3,6,10][variant-1])
    with bpy.data.libraries.load(str(SOURCE),link=False) as (src,dst): dst.objects=[preset]
    original=dst.objects[0]; bpy.context.scene.collection.objects.link(original); original.hide_set(False); original.hide_viewport=False; original.hide_render=False
    mod=next(m for m in original.modifiers if m.type=='NODES')
    amount=float(getattr(mod.properties.inputs,'Socket_37').value)
    settings={'Socket_47':seed,'Socket_40':seed+11,'Socket_174':True,'Socket_102':False,'Socket_25':12,'Socket_50':6,'Socket_57':14,'Socket_24':22,'Socket_7':.7,'Socket_65':max(.2,recipe['leaf']),'Socket_68':.75,
              'Socket_37':amount*({'dead':.40,'broken':.32,'birch':.90}.get(family,.78)), 'Socket_107':.34,'Socket_46':.48}
    if family=='fir': settings.update({'Socket_39':-.12,'Socket_43':.45})
    if family=='pine': settings.update({'Socket_39':.15,'Socket_43':.6,'Socket_41':12.0})
    if family=='birch': settings.update({'Socket_107':float(getattr(mod.properties.inputs,'Socket_107').value)*.85,'Socket_46':float(getattr(mod.properties.inputs,'Socket_46').value)*.75})
    for key,value in settings.items(): getattr(mod.properties.inputs,key).value=value
    bpy.context.view_layer.update(); mesh=bpy.data.meshes.new_from_object(original.evaluated_get(bpy.context.evaluated_depsgraph_get()),preserve_all_data_layers=True,depsgraph=bpy.context.evaluated_depsgraph_get())
    wood_polys=[p for p in mesh.polygons if p.material_index!=1]
    high=max(mesh.vertices[v].co.z for p in wood_polys for v in p.vertices)
    radius=max(math.hypot(mesh.vertices[v].co.x,mesh.vertices[v].co.y) for p in wood_polys for v in p.vertices)
    zscale=height/high; xyscale=height*recipe['radius']/radius
    uvdata=mesh.attributes.get('New Uv')
    # Broken trees retain a splintered main stem instead of a full living crown.
    cut=.30+.04*variant if family=='broken' else 1.0
    def transform(v):
        p=Vector((v.x*xyscale,v.y*xyscale,v.z*zscale/cut))
        if family=='pine':
            p.x+=height*.055*math.sin(p.z/height*2.0)*(variant-2.5)
        if family=='dead': p.x+=height*.035*math.sin(p.z/height*2.4)
        return p
    wood=[]; shoots=[]; points_by_cluster=[[] for _ in range(12)]
    # Remove complete thin/dead branch tubes. Polygon-by-polygon deletion used
    # to leave floating wires; a cut trunk must retain its own surface boundary.
    keep=set(); trunk_polys=set(); component_count=0
    for indices,polygons in wood_components(mesh):
        pts=[transform(mesh.vertices[v].co) for v in indices]
        is_trunk=min(p.z for p in pts)<height*.08
        root=sum(pts[:12 if is_trunk else 6],Vector())/(12 if is_trunk else 6)
        radius_at_root=max((p-root).length for p in pts[:12 if is_trunk else 6])
        # Entire limbs that cross the break must fall with the lost crown.
        # Clipping such a drooping limb alone leaves its lower half floating.
        if family=='broken' and not is_trunk and max(p.z for p in pts)>height*.865: continue
        if family in ['dead','broken'] and not is_trunk and radius_at_root<height*.0017: continue
        keep.update(polygons); component_count+=1
        if is_trunk: trunk_polys.update(polygons)
    cut_boundary=[]
    vertices=sorted({v for p in wood_polys for v in p.vertices})
    wood_tree=KDTree(len(vertices))
    for i,v in enumerate(vertices): wood_tree.insert(transform(mesh.vertices[v].co),i)
    wood_tree.balance()
    for poly in mesh.polygons:
        pts=[transform(mesh.vertices[v].co) for v in poly.vertices]; c=sum(pts,Vector())/len(pts)
        bid=cluster(c,height)
        uv=[tuple(uvdata.data[i].vector) for i in poly.loop_indices] if uvdata else [(0,0)]*len(pts)
        if poly.material_index==1:
            if family in ['birch','dead','broken']: continue
            if c.z<height*.17: continue
            radial=Vector((c.x,c.y,0)).normalized()
            if len(pts)>=3:
                direction=(pts[1]-pts[0]).normalized()
                if abs(direction.dot(radial))<.35: direction=radial
                if direction.dot(radial)<0: direction=-direction
            else: direction=radial
            anchor,_,_=wood_tree.find(c)
            shoots.append((anchor,direction,bid))
        else:
            if poly.index not in keep: continue
            if family=='broken':
                pts,uv,edge=clip_crown(pts,uv,height*.91)
                if len(pts)<3: continue
                if poly.index in trunk_polys:
                    for p in pts:
                        if abs(p.z-height*.91)<.000001:
                            a=math.atan2(p.y,p.x)
                            p.z+=height*(.018+.040*math.sin(a*3+seed)+.017*math.sin(a*7+.7))
                    for p in pts:
                        if any((p.xy-q.xy).length<.000001 for q in edge): cut_boundary.append(p.copy())
            mask={'dead':.1,'birch':.2,'broken':.1}.get(family,0)
            if family=='birch' and math.hypot(c.x,c.y)>height*.065: mask=0
            tint=(.70,.72,.70,mask) if family in ['dead','broken'] else ((.80,.80,.76,mask) if family=='birch' else (.66,.58,.47,mask))
            wood.append((pts,tint,bid,uv)); points_by_cluster[bid].append(c)
    # Several source leaf faces can resolve to the same twig. Keep one site in
    # a small neighbourhood, rather than stacking identical featureless sprays.
    cells={}; unique=[]; spacing=height*.012
    for shoot in shoots:
        p=shoot[0]; key=tuple(math.floor(v/spacing) for v in p)
        neighbours=[q for x in [-1,0,1] for y in [-1,0,1] for z in [-1,0,1] for q in cells.get((key[0]+x,key[1]+y,key[2]+z),[])]
        if any((p-q).length<spacing for q in neighbours): continue
        cells.setdefault(key,[]).append(p); unique.append(shoot)
    shoots=unique
    if len(shoots)>350: shoots=[shoots[int(i*len(shoots)/350)] for i in range(350)]
    if family in foliage_clusters.LIVING:
        foliage_clusters.build(globals(),family,variant,wood,shoots,points_by_cluster,component_count)
        return
    mat,color_socket=material(); models=[]; near=None
    for lod in [0,1]:
        g=Geometry(height)
        for pts,tint,bid,uv in wood: g.face(pts,tint,bid,uv)
        wood_obj=g.object(name+'_wood',mat)
        bpy.context.view_layer.objects.active=wood_obj; wood_obj.select_set(True)
        wood_obj.data.calc_loop_triangles()
        dec=wood_obj.modifiers.new('Woody mesh budget','DECIMATE'); dec.ratio=min(1.0 if lod==0 else .33,(20000 if lod==0 else 8000)/max(1,len(wood_obj.data.loop_triangles)))
        bpy.ops.object.modifier_apply(modifier=dec.name)
        for v in wood_obj.data.vertices:
            radius=math.hypot(v.co.x,v.co.y)
            limit=.44*height/10.5
            if v.co.z<height*.065 and radius>limit:
                v.co.x*=limit/radius; v.co.y*=limit/radius
        geo=Geometry(height)
        wm=wood_obj.data
        for p in wm.polygons:
            pts=[wm.vertices[v].co.copy() for v in p.vertices]; c=sum(pts,Vector())/len(pts)
            geo.face(pts,tuple(wm.color_attributes['Color'].data[p.loop_start].color),cluster(c,height),[tuple(wm.uv_layers[0].data[i].uv) for i in p.loop_indices])
        bpy.data.objects.remove(wood_obj,do_unlink=True)
        rng=random.Random(seed+919)
        green={'spruce':(.043,.098,.059,.6),'fir':(.035,.082,.054,.6),'pine':(.055,.100,.053,.6)}.get(family,(0,0,0,.6))
        if family=='broken' and cut_boundary:
            # The exposed wood shares the actual cut trunk ring: no added stub,
            # collar, widened cylinder, or disconnected splinter geometry.
            ring=list({tuple(round(v,6) for v in p):p for p in cut_boundary}.values())
            center=sum(ring,Vector())/len(ring)
            ring.sort(key=lambda p: math.atan2(p.y-center.y,p.x-center.x))
            floor=center-Vector((0,0,height*.024))
            for i,p in enumerate(ring):
                q=ring[(i+1)%len(ring)]
                geo.face([p,q,floor],(.30,.21,.12,.3),cluster(center,height))
        obj=geo.object(name+f'_lod{lod}',mat); record=export(obj,BASE/'models'/f'{obj.name}.glb'); models.append(record)
        obj.hide_render=True; obj.hide_set(True)
        if lod==0: near=obj
    bpy.data.objects.remove(original,do_unlink=True)
    near.hide_render=False; near.hide_set(False)
    if not opt.skip_atlas: bake(near,mat,color_socket,name,height)
    card=Geometry(height); span=height*1.12
    card.face([(-span/2,0,-height*.06),(span/2,0,-height*.06),(span/2,0,height*1.06),(-span/2,0,height*1.06)],(1,1,1,1),0)
    far=card.object(name+'_lod2',bpy.data.materials.new('FC_Impostor_'+name.removeprefix('forest_')))
    models.append(export(far,BASE/'models'/f'{far.name}.glb')); far.hide_render=True; far.hide_set(True)
    for obj in list(bpy.context.scene.objects):
        if obj!=near: bpy.data.objects.remove(obj,do_unlink=True)
    near.asset_mark(); near.asset_data.description=recipe['label']+f' / variant {variant} / {height} metres'
    for tag in ['Alpine Apex','Trees',family,'TreeDesigner']: near.asset_data.tags.new(tag)
    bpy.data.orphans_purge(do_recursive=True); bpy.ops.file.pack_all()
    bpy.ops.wm.save_as_mainfile(filepath=str(EDIT/f'{name}.blend'))
    branches=[]
    for bid,pts in enumerate(points_by_cluster):
        c=sum(pts,Vector())/len(pts) if pts else Vector((0,0,height*(bid//4+.5)/3))
        branches.append({'center':[c.x,c.z,-c.y],'radius':min(height*.21,max([(p-c).length for p in pts] or [.1])), 'pivot_y':(bid//4+.08)*height/3})
    record={'id':name,'family':family,'variant':variant,'height_m':round(models[0]['dimensions_blender_xyz_m'][2],3),'nominal_height_m':height,'seed':seed,'preset':preset,'settings':settings,
            'models':models,'branches':branches,'shoot_count':len(shoots),'woody_components':component_count,'fracture_ring_vertices':len(cut_boundary),'source_blend':(EDIT/f'{name}.blend').relative_to(ROOT).as_posix(), 'atlas_complete':not opt.skip_atlas}
    manifest['assets']=[a for a in manifest['assets'] if a['id']!=name]+[record]
    manifest['assets'].sort(key=lambda a:(list(FAMILIES).index(a['family']),a['variant']))
    manifest_path.write_text(json.dumps(manifest,indent=2)+'\n')
    (BASE/'branches.json').write_text(json.dumps({a['id']:{'branches':a['branches']} for a in manifest['assets']},indent=2)+'\n')
    print('TREE_BUILT',name,'shoots',len(shoots),'triangles',[m['triangles'] for m in models],flush=True)


if opt.bake_needles:
    foliage_clusters.bake_needles(globals())
    sys.exit(0)

for family in FAMILIES:
    if opt.living_only and family not in foliage_clusters.LIVING: continue
    for variant in range(1,5):
        name=f'forest_{family}_{variant:02}'
        if opt.asset and opt.asset!=name: continue
        old=next((a for a in manifest['assets'] if a['id']==name),None)
        if opt.resume and old and old.get('build_identity')==foliage_clusters.build_identity(globals()) and old['atlas_complete'] and all((ROOT/m['path']).exists() and hashlib.sha256((ROOT/m['path']).read_bytes()).hexdigest()==m['sha256'] for m in old['models']+[old['shadow']]):
            print('TREE_VERIFIED_SKIP',name,flush=True); continue
        build(family,variant)
assert source_hash==hashlib.sha256(SOURCE.read_bytes()).hexdigest()
print('TREE_COLLECTION_COMPLETE',len(manifest['assets']),flush=True)

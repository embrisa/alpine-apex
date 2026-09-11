"""Build a portable, metre-scale prop collection in a separate Blender process.

No paid calls. CC0 and Meshy inputs stay immutable. All .blend images are packed;
each GLB is independently reimported. --base builds while custom jobs are running.
"""
import bpy
import bmesh
import json
import math
import hashlib
import uuid
import sys
from pathlib import Path
from mathutils import Vector, Matrix

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'art_source/flavor_v1'
OUT = ROOT / 'assets/graphics/flavor_v1'
BLENDS = ROOT / 'art_source/blender/flavor_v1'
QA = ROOT / 'artifacts/flavor_v1'
SPECS = [
    ('garden_gnome', 'Summit guardian', 'garden_gnome', .65, 12000, 'discoveries'),
    ('wet_floor_sign', 'Caution: mountain', 'WetFloorSign_01', .65, 1000, 'discoveries'),
    ('summit_armchair', 'The best seat', 'ArmChair_01', 1.1, 8000, 'discoveries'),
    ('picnic_table', 'Lookout picnic table', 'wooden_picnic_table', .8, 14000, 'camp'),
    ('stone_fire_pit', 'Expedition fire pit', 'stone_fire_pit', .45, 6000, 'camp'),
    ('expedition_radio', 'Lost expedition radio', 'vintage_radio_transceiver', .65, 16000, 'camp'),
    ('supply_crate', 'Buried supplies', 'wooden_crate_01', .75, 8000, 'camp'),
    ('giant_rubber_duck', 'The powder duck', 'rubber_duck_toy', 1.25, 7000, 'discoveries'),
    ('alpine_refuge', 'Little alpine refuge', None, 4.6, 24000, 'structures'),
    ('marmot_monument', 'Marmot of the summit', None, 1.6, 18000, 'discoveries'),
]

def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()

def reset(): bpy.ops.wm.read_factory_settings(use_empty=True)

def solid(name, color, roughness=.7, metallic=0):
    mat = bpy.data.materials.new(name); mat.use_nodes = True
    p = mat.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value = (*color, 1)
    p.inputs['Roughness'].default_value = roughness
    p.inputs['Metallic'].default_value = metallic
    return mat

def wood_material():
    mat = solid('Larch timber', (.32,.19,.10))
    tree = mat.node_tree; p = tree.nodes.get('Principled BSDF')
    for channel, socket in [('Diffuse','Base Color'), ('nor_gl','Normal'), ('arm','Roughness')]:
        node = tree.nodes.new('ShaderNodeTexImage')
        node.image = bpy.data.images.load(str(SOURCE/'raw/gate_wood'/ (channel+'.jpg')))
        if channel != 'Diffuse': node.image.colorspace_settings.name = 'Non-Color'
        if channel == 'nor_gl':
            normal = tree.nodes.new('ShaderNodeNormalMap'); normal.inputs['Strength'].default_value=.45
            tree.links.new(node.outputs['Color'],normal.inputs['Color']); tree.links.new(normal.outputs['Normal'],p.inputs[socket])
        elif channel == 'arm':
            split=tree.nodes.new('ShaderNodeSeparateColor'); tree.links.new(node.outputs['Color'],split.inputs[0]); tree.links.new(split.outputs['Green'],p.inputs[socket])
        else: tree.links.new(node.outputs['Color'],p.inputs[socket])
    return mat

def box(name, center, size, material, bevel=.025):
    bpy.ops.mesh.primitive_cube_add(size=1,location=center)
    obj=bpy.context.object; obj.name=name; obj.scale=size
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    if bevel:
        mod=obj.modifiers.new('Crafted edges','BEVEL'); mod.width=bevel; mod.segments=2
        bpy.ops.object.modifier_apply(modifier=mod.name)
        mod=obj.modifiers.new('Corner normals','WEIGHTED_NORMAL')
        bpy.ops.object.modifier_apply(modifier=mod.name)
    obj.data.materials.append(material)
    # World metre UVs retain plausible grain on beams of different lengths.
    for polygon in obj.data.polygons:
        axes=sorted(range(3),key=lambda i:abs(polygon.normal[i]))[:2]
        for li in polygon.loop_indices:
            v=obj.data.vertices[obj.data.loops[li].vertex_index].co
            obj.data.uv_layers.active.data[li].uv=(v[axes[0]]*.6,v[axes[1]]*.6)
    return obj

def text_mesh(text, location, size, material, reverse=False):
    curve=bpy.data.curves.new(text,'FONT'); curve.body=text; curve.align_x='CENTER'; curve.align_y='CENTER'
    curve.size=size; curve.extrude=.006; curve.bevel_depth=.002; curve.resolution_u=3
    obj=bpy.data.objects.new(text,curve); bpy.context.collection.objects.link(obj)
    obj.location=location; obj.rotation_euler=(math.pi/2,0,math.pi if reverse else 0)
    obj.data.materials.append(material)
    bpy.context.view_layer.objects.active=obj; obj.select_set(True); bpy.ops.object.convert(target='MESH'); obj.select_set(False)
    return obj

def gate(kind):
    reset()
    wood=wood_material(); snow=solid('Roof powder',(.88,.94,.99),.96)
    metal=solid('Forged fittings',(.032,.044,.053),.34,.8)
    stone=solid('Granite feet',(.15,.18,.20),.91)
    accent=solid('Start green' if kind=='start' else 'Finish vermilion',(.31,.54,.13) if kind=='start' else (.62,.07,.032),.6)
    cream=solid('Ivory lettering',(.96,.92,.79),.58)
    boxes=[]
    for x in [-5.6,5.6]:
        box('Granite footing',(x,0,.25),(1.2,1.8,.5),stone,.09)
        box('Structural timber',(x,0,2.5),(.72,.76,4.0),wood,.045)
        boxes += [{'center':[x,.25,0],'size':[1.2,.5,1.8]}, {'center':[x,2.5,0],'size':[.72,4.,.76]}]
        for z in [.72,3.82]:
            box('Forged collar',(x,0,z),(.78,.82,.18),metal,.012)
        box('Snow on foot',(x,0,.50),(1.19,1.75,.06),snow,.025)
        box('Painted post marker',(x,-.395,2.15),(.56,.035,1.3),accent,.025)
        for z in [1.68,2.64]:
            for xx in [-.20,.20]:
                bpy.ops.mesh.primitive_uv_sphere_add(segments=8,ring_count=4,radius=.035,location=(x+xx,-.43,z))
                bpy.context.object.data.materials.append(metal)
    box('Solid crossbeam',(0,0,4.875),(12.4,.9,.75),wood,.045)
    boxes.append({'center':[0,4.875,0],'size':[12.4,.75,.9]})
    for side in [-1,1]:
        box('Banner panel',(0,side*.48,4.88),(8.8,.065,.60),accent,.035)
        text_mesh(kind.upper(),(0,side*.53,4.88),.49,cream,side==1)
        for x in [-4.04,4.04]:
            for row in range(3):
                for col in range(2):
                    if (row+col)%2==0:
                        box('Checkered finish' if kind=='finish' else 'Start flashes',
                            (x+col*.13,side*.522,4.67+row*.14),(.12,.014,.125),cream,0)
    # A narrow gabled hood keeps all solid geometry above the advertised opening.
    for side in [-1,1]:
        obj=box('Snow hood',(0,side*.39,5.34),(12.8,.86,.11),wood,.025)
        obj.rotation_euler.x=side*-.28
        obj=box('Snow cornice',(0,side*.39,5.43),(12.87,.88,.10),snow,.035)
        obj.rotation_euler.x=side*-.28
    boxes.append({'center':[0,5.34,0],'size':[12.8,.40,1.7]})
    return boxes

def imported(path,height):
    reset(); bpy.ops.import_scene.gltf(filepath=str(path))
    objects=[o for o in bpy.context.scene.objects if o.type=='MESH']
    assert objects,path
    for o in objects:
        matrix=o.matrix_world.copy(); o.parent=None; o.matrix_world=Matrix.Identity(4); o.data.transform(matrix)
    bounds=[v.co for o in objects for v in o.data.vertices]
    lo=Vector(tuple(min(v[i] for v in bounds) for i in range(3)))
    hi=Vector(tuple(max(v[i] for v in bounds) for i in range(3)))
    scale=height/(hi.z-lo.z); center=Vector(((lo.x+hi.x)/2,(lo.y+hi.y)/2,lo.z))
    for o in objects:
        for v in o.data.vertices: v.co=(v.co-center)*scale
    for o in list(bpy.context.scene.objects):
        if o.type!='MESH': bpy.data.objects.remove(o,do_unlink=True)

def join_meshes(name):
    bpy.ops.object.select_all(action='DESELECT')
    objects=[o for o in bpy.context.scene.objects if o.type=='MESH']
    for obj in objects: obj.select_set(True)
    bpy.context.view_layer.objects.active=objects[0]
    bpy.ops.object.convert(target='MESH'); bpy.ops.object.join()
    obj=bpy.context.object; bpy.ops.object.transform_apply(location=True,rotation=True,scale=True); obj.name=name
    return obj

def count(obj): obj.data.calc_loop_triangles(); return len(obj.data.loop_triangles)

def simplify(obj,target):
    if count(obj)<=target: return
    bpy.context.view_layer.objects.active=obj
    # glTF splits vertices at UV/normal seams. Weld geometric duplicates before
    # collapsing; otherwise Meshy pieces shrink into disconnected triangles.
    # UVs remain per-face-corner data, so the authored texture atlas is retained.
    mesh=bmesh.new(); mesh.from_mesh(obj.data)
    bmesh.ops.remove_doubles(mesh,verts=list(mesh.verts),dist=.00001)
    mesh.to_mesh(obj.data); mesh.free(); obj.data.update()
    mod=obj.modifiers.new('Distance simplification','DECIMATE'); mod.ratio=target/count(obj); mod.use_collapse_triangulate=True
    bpy.ops.object.modifier_apply(modifier=mod.name)

def dimensions(obj):
    points=[v.co for v in obj.data.vertices]
    lo=[min(v[i] for v in points) for i in range(3)]; hi=[max(v[i] for v in points) for i in range(3)]
    return lo,hi

def export_asset(asset_id,label,family,source_url,source_license,target,colliders=None):
    obj=join_meshes(asset_id); simplify(obj,target)
    lo,hi=dimensions(obj); sizes=[hi[i]-lo[i] for i in range(3)]
    if colliders is None:
        # Conservative obstacle proxy; camp props and refuge are scenery, not interiors.
        colliders=[{'center':[0,sizes[2]*.5,0],'size':[sizes[0],sizes[2],sizes[1]]}]
    obj.asset_mark(); obj.asset_data.description=label+' | Alpine Apex | metres | '+source_license
    obj.asset_data.catalog_id=str(uuid.uuid5(uuid.NAMESPACE_URL,'alpine-apex/flavor/'+family))
    obj['source_url']=source_url; obj['license']=source_license
    bpy.ops.file.pack_all()
    source_path=BLENDS/(asset_id+'.blend'); bpy.ops.wm.save_as_mainfile(filepath=str(source_path))
    models=[]
    for lod,ratio in enumerate([1,.4,.12]):
        copy=obj.copy(); copy.data=obj.data.copy(); bpy.context.collection.objects.link(copy)
        simplify(copy,max(100,int(count(obj)*ratio)))
        bpy.ops.object.select_all(action='DESELECT'); copy.select_set(True); bpy.context.view_layer.objects.active=copy
        path=OUT/'models'/(asset_id+'_lod%d.glb'%lod)
        bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,
                                  export_yup=True,export_animations=False,export_materials='EXPORT',
                                  export_image_format='AUTO',export_texcoords=True,export_normals=True)
        models.append({'path':path.relative_to(ROOT).as_posix(),'triangles':count(copy),'sha256':sha(path),'bytes':path.stat().st_size})
        bpy.data.objects.remove(copy,do_unlink=True)
    record={'id':asset_id,'label':label,'family':family,'source_url':source_url,'license':source_license,
            'source_blend':source_path.relative_to(ROOT).as_posix(),'dimensions_m':[sizes[0],sizes[2],sizes[1]],
            'origin':'bottom_center','models':models,'colliders':colliders,
            'snow_amount':0 if asset_id in ['start_gate','finish_gate','alpine_refuge','marmot_monument'] else .7}
    if asset_id.endswith('_gate'): record['clearance_m']={'width':10.,'height':4.5}
    # Fresh import proves the portable exports don't depend on the source scene.
    for model in models:
        reset(); bpy.ops.import_scene.gltf(filepath=str(ROOT/model['path']))
        meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
        assert sum(count(o) for o in meshes)==model['triangles'],model
        assert all(im.packed_file is not None for im in bpy.data.images if im.type=='IMAGE'),asset_id
        model['roundtrip_verified']=True
    print('FLAVOR_ASSET',asset_id,[m['triangles'] for m in models],flush=True)
    return record

def package(records):
    reset(); catalogs=['# Blender Asset Catalog Definition File','VERSION 1','']
    for family in ['gates','structures','camp','discoveries']:
        uid=str(uuid.uuid5(uuid.NAMESPACE_URL,'alpine-apex/flavor/'+family))
        catalogs.append(uid+':Alpine flavor/'+family+':'+family)
    for i,record in enumerate(records):
        with bpy.data.libraries.load(str(ROOT/record['source_blend']),link=False) as (s,d): d.objects=[record['id']]
        obj=d.objects[0]; bpy.context.scene.collection.objects.link(obj); obj.location=(i%4*17,i//4*17,0)
    bpy.ops.file.pack_all(); bpy.ops.wm.save_as_mainfile(filepath=str(BLENDS/'flavor_collection.blend'))
    (BLENDS/'blender_assets.cats.txt').write_text('\n'.join(catalogs)+'\n')

def main():
    for folder in [OUT/'models',BLENDS,QA]: folder.mkdir(parents=True,exist_ok=True)
    records=[]
    for kind in ['start','finish']:
        boxes=gate(kind)
        records.append(export_asset(kind+'_gate',kind.capitalize()+' gate','gates','Blender-authored for Alpine Apex','Project-authored',16000,boxes))
    for asset_id,label,ph_id,height,target,family in SPECS:
        path=SOURCE/'raw'/ph_id/(ph_id+'.gltf') if ph_id else SOURCE/'raw'/(asset_id+'.glb')
        if not path.exists() and '--base' in sys.argv: continue
        assert path.exists(),path
        imported(path,height)
        url='https://polyhaven.com/a/'+ph_id if ph_id else 'Meshy 7 / see art_source/flavor_v1/credit_ledger.json'
        records.append(export_asset(asset_id,label,family,url,'CC0-1.0' if ph_id else 'Meshy-generated; account terms apply',target))
    manifest={'version':1,'units':'metres','purpose':'Reusable flavor library; no automatic mountain scattering or race-rule changes',
              'lod_distances_m':[45,120,450],'assets':records}
    (OUT/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    (QA/'blender_validation.json').write_text(json.dumps({'assets':len(records),'roundtrips':sum(len(r['models']) for r in records),'verified':True},indent=2)+'\n')
    package(records)

if __name__=='__main__': main()

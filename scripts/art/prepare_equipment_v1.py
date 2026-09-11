"""Prepare separate Meshy 7 equipment; local source-only rebuild, no paid calls.

Run with Blender --background --python scripts/art/prepare_equipment_v1.py.
Use -- --inspect for source inspection. Sources are never overwritten.
All runtime mesh transforms must be baked because AlpineAssets extracts Mesh data.
"""
import bpy
import bmesh
import json
import math
import sys
import hashlib
import numpy as np
from pathlib import Path
from mathutils import Vector, Matrix

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'art_source/meshy/equipment_v1'
OUT = ROOT / 'assets/graphics/models'
QA = ROOT / 'artifacts/equipment_v1'
IDS = ['ski', 'binding', 'pole']

def load_mesh(path):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(path))
    objects = [o for o in bpy.context.scene.objects if o.type == 'MESH']
    assert objects, path
    bpy.ops.object.select_all(action='DESELECT')
    for obj in objects:
        obj.select_set(True)
        obj.data.transform(obj.matrix_world)
        obj.parent = None
        obj.matrix_world = Matrix.Identity(4)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.join()
    obj = bpy.context.object
    for other in list(bpy.context.scene.objects):
        if other != obj: bpy.data.objects.remove(other, do_unlink=True)
    return obj

def points(obj):
    return np.array([v.co[:] for v in obj.data.vertices])

def info(obj):
    p = points(obj)
    obj.data.calc_loop_triangles()
    cov = np.cov(p.T)
    eigval, eigvec = np.linalg.eigh(cov)
    return {'triangles': len(obj.data.loop_triangles), 'vertices': len(p),
            'min': p.min(0).tolist(), 'max': p.max(0).tolist(),
            'dimensions': np.ptp(p,axis=0).tolist(),
            'principal_axes': eigvec.tolist(), 'variances': eigval.tolist(),
            'materials': [m.name for m in obj.data.materials if m],
            'textures': [{'name': im.name, 'size': list(im.size)} for im in bpy.data.images if im.size[0]>0]}

def render(obj, path, view=(1,-1.6,.85)):
    p = points(obj)
    center = Vector((p.min(0)+p.max(0))*.5)
    size = float(max(np.ptp(p,axis=0)))
    world = bpy.data.worlds.new('Equipment inspection studio')
    world.use_nodes = True
    world.node_tree.nodes['Background'].inputs['Color'].default_value = (.32,.37,.44,1)
    world.node_tree.nodes['Background'].inputs['Strength'].default_value = .65
    bpy.context.scene.world = world
    for name, offset, power in [('Key',(2,-3,4),600),('Fill',(-3,-1,2),400),('Rim',(1,3,2),500)]:
        data = bpy.data.lights.new(name,'AREA'); data.energy = power*size*size; data.shape='DISK'; data.size=2.5*size
        light = bpy.data.objects.new(name,data); bpy.context.collection.objects.link(light)
        light.location = center+Vector(offset)*size
        light.rotation_euler = (center-light.location).to_track_quat('-Z','Y').to_euler()
    data = bpy.data.cameras.new('Inspection camera')
    camera = bpy.data.objects.new('Inspection camera',data); bpy.context.collection.objects.link(camera)
    camera.location = center+Vector(view)*size
    camera.rotation_euler = (center-camera.location).to_track_quat('-Z','Y').to_euler()
    data.type = 'ORTHO'; data.ortho_scale = size*1.28
    scene = bpy.context.scene; scene.camera = camera
    scene.render.engine='BLENDER_EEVEE'
    scene.render.resolution_x=900; scene.render.resolution_y=900; scene.render.resolution_percentage=100
    scene.render.image_settings.file_format='PNG'; scene.render.filepath=str(path)
    scene.view_settings.view_transform='AgX'
    bpy.ops.render.render(write_still=True)
    for other in list(scene.objects):
        if other != obj: bpy.data.objects.remove(other,do_unlink=True)

def inspect():
    report = {}
    for id in IDS:
        obj = load_mesh(OUT / (id+'.glb'))
        report[id+'_original'] = info(obj)
        raw = SOURCE / 'raw' / (id+'.glb')
        if raw.exists():
            obj = load_mesh(raw)
            report[id+'_raw'] = info(obj)
            render(obj, QA / (id+'_raw.png'))
            render(obj, QA / (id+'_raw_reverse.png'),(-1,1.6,.7))
    (SOURCE/'source_inspection.json').write_text(json.dumps(report,indent=2)+'\n')
    print('EQUIPMENT_INSPECTION',json.dumps({id:{k:v for k,v in row.items() if k not in ['textures','materials']} for id,row in report.items()}))

def simplify(obj, target):
    obj.data.calc_loop_triangles()
    count = len(obj.data.loop_triangles)
    if count > target:
        bpy.context.view_layer.objects.active = obj
        modifier = obj.modifiers.new('Runtime triangle budget','DECIMATE')
        modifier.ratio = target/count
        modifier.use_collapse_triangulate = True
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    for face in obj.data.polygons: face.use_smooth = True

def fit_ski(obj):
    # Meshy source stands on +Z; front/top surface faces -Y.
    # Retain the old visual length and binding origin. The 1.8 m solver support
    # is unchanged; the raised visual shovel extends beyond that support.
    p = points(obj)
    longitudinal = p[:,2]
    knots = np.linspace(longitudinal.min(),longitudinal.max(),100)
    lo=[]; hi=[]; center=[]
    for k in knots:
        section=p[abs(longitudinal-k)<.027]
        lo.append(float(np.percentile(section[:,1],1)))
        hi.append(float(np.percentile(section[:,1],99)))
        center.append(float((section[:,0].min()+section[:,0].max())*.5))
    skin = np.clip((np.interp(longitudinal,knots,hi)-p[:,1])/np.maximum(.004,np.interp(longitudinal,knots,hi)-np.interp(longitudinal,knots,lo)),0,1)
    # Manufactured top/base planes must not inherit reconstruction ripples.
    # Keep the connecting sidewall band, flatten each broad face exactly.
    skin = np.clip((skin-.25)*2,0,1)
    forward = (longitudinal-longitudinal.min())/np.ptp(longitudinal)*2.17-1.02
    curve = np.maximum(0,(forward-.70)/.45)**2*.125 + np.maximum(0,(-forward-.84)/.18)**2*.015
    width = -(p[:,0]-np.interp(longitudinal,knots,center))*.80
    transformed = np.column_stack((width,-forward,-.016+skin*.016+curve))
    for v,co in zip(obj.data.vertices,transformed): v.co = co
    obj.data.update()

def solid_material(name,color,roughness=.4,metallic=0):
    mat=bpy.data.materials.new(name); mat.use_nodes=True
    node=mat.node_tree.nodes.get('Principled BSDF')
    node.inputs['Base Color'].default_value=(*color,1)
    node.inputs['Roughness'].default_value=roughness
    node.inputs['Metallic'].default_value=metallic
    return mat

def riser(obj):
    # Existing boot sole is 77 mm above the binding origin. A machined riser
    # supports it without moving either ankle or the hand-authored boot meshes.
    mat=solid_material('EquipmentV1Riser',(.018,.023,.028),.32,.45)
    pieces=[obj]
    shapes=[(0,-.038,.127,.33,.008,-.006),(0,-.038,.127,.31,.012,.069)]
    shapes += [(x,y,.019,.050,.074,.027) for x in [-.047,.047] for y in [-.155,-.040,.075]]
    for x,y,width,length,height,z in shapes:
        bpy.ops.mesh.primitive_cube_add(size=1,location=(x,y,z))
        block=bpy.context.object; block.scale=(width,length,height)
        bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
        bevel=block.modifiers.new('Machined riser bevel','BEVEL'); bevel.width=.008; bevel.segments=3
        bpy.ops.object.modifier_apply(modifier=bevel.name)
        block.data.materials.append(mat); pieces.append(block)
    bpy.ops.object.select_all(action='DESELECT')
    for part in pieces: part.select_set(True)
    bpy.context.view_layer.objects.active=obj
    bpy.ops.object.join()

def fit_binding(obj):
    p=points(obj)
    # Source +X is heel, -X toe. Blender -Y becomes Godot +Z / forward.
    transformed=np.column_stack((-p[:,1]*.25,p[:,0]*.25-.045,(p[:,2]+.174708)*.35+.032))
    for v,co in zip(obj.data.vertices,transformed): v.co=co
    obj.data.update()
    riser(obj)

def fit_pole(obj):
    p=points(obj)
    # Remove generated shaft lean while keeping grip, strap, basket and UVs.
    shaft=p[(p[:,2]>-.65)&(p[:,2]<.5)]
    design=np.column_stack((shaft[:,2],np.ones(len(shaft))))
    coefficients=np.linalg.lstsq(design,shaft[:,:2],rcond=None)[0]
    p[:,:2]-=np.column_stack((p[:,2],np.ones(len(p))))@coefficients
    scale=1.195/np.ptp(p[:,2])
    p[:,:2]*=scale
    p[:,2]=(p[:,2]-p[:,2].max())*scale+.015
    # Narrow just the molded grip to the existing closed glove's diameter.
    grip=np.clip((p[:,2]+.145)/.025,0,1)
    p[:,:2]*=(1-.20*grip[:,None])
    for v,co in zip(obj.data.vertices,p): v.co=co
    obj.data.update()

def prepare_materials(obj,id):
    for index,mat in enumerate(obj.data.materials):
        if not mat or mat.name.startswith('EquipmentV1Riser'): continue
        mat.name='EquipmentV1'+id.title()+str(index)
        node=mat.node_tree.nodes.get('Principled BSDF')
        if node:
            for socket in ['Emission Color','Emission Strength']:
                for link in list(node.inputs[socket].links): mat.node_tree.links.remove(link)
            node.inputs['Emission Strength'].default_value=0
    # Resample the source texture maps for the runtime derivative in Blender.
    # Original 4K maps and raw GLBs remain untouched in the Meshy source folder.
    for image in list(bpy.data.images):
        if image.size[0]>2048 or image.size[1]>2048: image.scale(2048,2048)
        if image.size[0]>0: image.pack()

def refresh_normals(obj):
    # Imported custom normals describe the upright Meshy source. Geometry
    # fitting changes its frame, so rebuild normals from the actual surface.
    if obj.data.has_custom_normals:
        obj.data.normals_split_custom_set([(0,0,0)]*len(obj.data.loops))
    bm=bmesh.new(); bm.from_mesh(obj.data)
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    bm.to_mesh(obj.data); bm.free(); obj.data.update()

def export(obj,path):
    bpy.ops.object.select_all(action='DESELECT'); obj.select_set(True)
    bpy.context.view_layer.objects.active=obj
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,
                              export_apply=True,export_animations=False,export_cameras=False,export_lights=False)

def mirror_ski(manifest):
    # Mirror the mesh and its artwork, never the ski/boot attachment transform.
    # UVs stay attached to their vertices, so the same textures form a real pair.
    obj=load_mesh(OUT/'ski_detailed_v1.glb')
    obj.data.transform(Matrix.Diagonal((-1.0,1.0,1.0,1.0)))
    bm=bmesh.new(); bm.from_mesh(obj.data)
    bmesh.ops.reverse_faces(bm,faces=list(bm.faces))
    bm.to_mesh(obj.data); bm.free()
    refresh_normals(obj)
    obj.name='EquipmentV1SkiLeft'
    path=OUT/'ski_detailed_v1_left.glb'
    export(obj,path)
    bpy.ops.file.pack_all()
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art_source/blender/equipment_v1_ski_left.blend'))
    obj=load_mesh(path)
    result=info(obj)
    original=next(a for a in manifest['assets'] if a['id']=='ski_detailed_v1')
    assert result['triangles']==original['triangles']
    assert obj.data.uv_layers
    record=dict(original)
    record.update(id='ski_detailed_v1_left',mirror_of='ski_detailed_v1',
                  handedness='left',instances=1,triangles=result['triangles'],
                  bounds_blender_min=result['min'],bounds_blender_max=result['max'],
                  path=str(path.relative_to(ROOT)),bytes=path.stat().st_size,
                  sha256=hashlib.sha256(path.read_bytes()).hexdigest())
    original.update(handedness='right',instances=1)
    manifest['assets']=[a for a in manifest['assets'] if a['id']!='ski_detailed_v1_left']+[record]
    manifest['paired_equipment_triangles']=sum(a['triangles']*(1 if a['id'].startswith('ski_') else 2) for a in manifest['assets'])
    manifest['ski_pair']='Baked X mirror; shared runtime materials/textures; independent transforms'
    (SOURCE/'runtime_qa.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print('EQUIPMENT_MIRRORED_SKI',json.dumps(record))

def build():
    manifest={'version':1,'source_model':'meshy-7','units':'metres','glb_up':'Y','glb_forward':'Z',
              'physics_changed':False,'source_textures':'4K','runtime_textures':'2K',
              'coordinate_contract':'One mesh, baked transforms; ski binding at (0,.018,-.15), boot at (0,.095,-.15); pole grip at origin, shaft -Y',
              'assets':[]}
    selected=next((a.split('=',1)[1] for a in sys.argv if a.startswith('--asset=')),None)
    if selected and (SOURCE/'runtime_qa.json').exists():
        previous=json.loads((SOURCE/'runtime_qa.json').read_text())
        manifest['assets']=[a for a in previous['assets'] if a['id']!=selected+'_detailed_v1']
    for id,budget,fit in [('ski',6000,fit_ski),('binding',12000,fit_binding),('pole',6000,fit_pole)]:
        if selected and id!=selected: continue
        obj=load_mesh(SOURCE/'raw'/(id+'.glb'))
        original=info(obj)
        simplify(obj,budget*2)
        fit(obj)
        simplify(obj,budget)
        refresh_normals(obj)
        obj.name='EquipmentV1'+id.title()
        prepare_materials(obj,id)
        path=OUT/(id+'_detailed_v1.glb')
        export(obj,path)
        blend=ROOT/'art_source/blender'/('equipment_v1_'+id+'.blend')
        bpy.ops.file.pack_all()
        bpy.ops.wm.save_as_mainfile(filepath=str(blend))
        render(obj,QA/(id+'_prepared.png'),(1,-1.7,1.7) if id!='pole' else (1,-1.6,.2))
        # Independent export reimport verifies actual portable artifact.
        obj=load_mesh(path)
        result=info(obj)
        assert result['triangles']<=budget+100, result
        assert obj.data.uv_layers, 'Lost UVs'
        assert all(abs(v)<1e-6 for v in obj.location), 'Unbaked origin'
        assert any(m.node_tree.nodes.get('Principled BSDF').inputs['Base Color'].is_linked for m in obj.data.materials if m), 'Lost albedo'
        assert any(m.node_tree.nodes.get('Principled BSDF').inputs['Normal'].is_linked for m in obj.data.materials if m), 'Lost normal map'
        manifest['assets'].append({'id':id+'_detailed_v1','source_triangles':original['triangles'],
                                  'triangles':result['triangles'],'bounds_blender_min':result['min'],'bounds_blender_max':result['max'],
                                  'textures':result['textures'],'materials':result['materials'],
                                  'roundtrip_verified':True,'path':str(path.relative_to(ROOT)),
                                  'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'bytes':path.stat().st_size})
    if selected in [None,'ski']: mirror_ski(manifest)
    manifest['paired_equipment_triangles']=sum(a['triangles']*(1 if a['id'].startswith('ski_') else 2) for a in manifest['assets'])
    (SOURCE/'runtime_qa.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print('EQUIPMENT_EXPORT',json.dumps(manifest))

if __name__ == '__main__':
    if '--inspect' in sys.argv: inspect()
    elif '--mirror-only' in sys.argv: mirror_ski(json.loads((SOURCE/'runtime_qa.json').read_text()))
    else: build()

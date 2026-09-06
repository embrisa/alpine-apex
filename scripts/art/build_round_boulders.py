"""Build the two rounded erratics that complement the fractured Meshy rocks."""
import bpy
import json
import math
import hashlib
from pathlib import Path
from mathutils import Vector, noise

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'assets/graphics/models'
SOURCE=ROOT/'art_source/blender'
bpy.ops.wm.read_factory_settings(use_empty=True)
mat=bpy.data.materials.new('Rock.Runtime')
mat.diffuse_color=(.3,.31,.34,1)
stats=[]
for variant in [1,2]:
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=3,radius=1)
    obj=bpy.context.object;obj.name=f'rock_boulder_{variant}'
    for v in obj.data.vertices:
        p=v.co.copy()
        n=noise.noise_vector(p*2.6+Vector((variant*9,4,3))).x
        v.co=p*(1+n*.16);v.co.z=v.co.z*.93+.87
    radius=max(math.hypot(v.co.x,v.co.y) for v in obj.data.vertices)
    low=min(v.co.z for v in obj.data.vertices);high=max(v.co.z for v in obj.data.vertices)
    for v in obj.data.vertices:
        v.co.x*=1.35/radius;v.co.y*=1.35/radius
        v.co.z=(v.co.z-low)*2.35/(high-low)-.35
    obj.data.materials.append(mat)
    for polygon in obj.data.polygons:polygon.use_smooth=True
    path=OUT/(obj.name+'.glb')
    bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,export_animations=False)
    obj.data.calc_loop_triangles()
    stats.append(dict(asset=obj.name,triangles=len(obj.data.loop_triangles),dimensions=list(obj.dimensions),
                      bytes=path.stat().st_size,sha256=hashlib.sha256(path.read_bytes()).hexdigest()))
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/'round_boulders.blend'))
for stat in stats:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(OUT/(stat['asset']+'.glb')))
    meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
    assert len(meshes)==1
    obj=meshes[0];obj.data.calc_loop_triangles()
    assert len(obj.data.loop_triangles)==stat['triangles']
    assert max(abs(obj.dimensions[i]-stat['dimensions'][i]) for i in range(3))<.01
    stat['roundtrip_verified']=True
(SOURCE/'round_boulders_qa.json').write_text(json.dumps(stats,indent=2)+'\n')
manifest_path=ROOT/'assets/graphics/manifest.json'
manifest=json.loads(manifest_path.read_text())
replacements={f"assets/graphics/models/{s['asset']}.glb" for s in stats}
manifest['assets']=[a for a in manifest['assets'] if a['path'] not in replacements]
manifest['assets'].extend(dict(path=f"assets/graphics/models/{s['asset']}.glb",triangles=s['triangles'],bytes=s['bytes'],sha256=s['sha256']) for s in stats)
manifest['assets'].sort(key=lambda a:a['path'])
manifest_path.write_text(json.dumps(manifest,indent=2)+'\n')
print('ROUND_BOULDERS_COMPLETE',json.dumps(stats))

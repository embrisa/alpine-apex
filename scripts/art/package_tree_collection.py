"""Independently reimport all exports and save six editable Asset Browser libraries."""
import bpy
import json
import uuid
from pathlib import Path
from mathutils import Vector, Quaternion
root=Path(__file__).resolve().parents[2]
manifest=json.loads((root/'assets/graphics/trees/manifest.json').read_text())
source=root/'art_source/blender/tree_collection'
report=[]; catalog=['# Blender Asset Catalog Definition File','VERSION 1','']
for family in manifest['families']:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    cid=str(uuid.uuid5(uuid.NAMESPACE_URL,'alpine-apex/trees/'+family))
    catalog.append(cid+':Trees/'+family+':'+family)
    for record in [r for r in manifest['assets'] if r['family']==family]:
        for lod,m in enumerate(record['models']+([record['shadow']] if 'shadow' in record else [])):
            before=set(bpy.data.objects)
            bpy.ops.import_scene.gltf(filepath=str(root/m['path']))
            added=set(bpy.data.objects)-before
            meshes=[o for o in added if o.type=='MESH']; assert len(meshes)==1
            o=meshes[0]; o.data.calc_loop_triangles()
            assert len(o.data.loop_triangles)==m['triangles']
            assert len(o.data.materials)==1
            assert all(abs(a-b)<.015 for a,b in zip(o.dimensions,m['dimensions_blender_xyz_m']))
            if lod!=2: assert len(o.data.uv_layers)==2 and len(o.data.color_attributes)>0
            report.append({'id':record['id'],'lod':lod,'triangles':m['triangles'],'roundtrip':True})
            for obj in added: bpy.data.objects.remove(obj,do_unlink=True)
        with bpy.data.libraries.load(str(root/record['source_blend']),link=False) as (s,d): d.objects=[record['id']+'_lod0']
        o=d.objects[0]; bpy.context.scene.collection.objects.link(o); o.hide_set(False); o.hide_render=False
        o.location.x=(record['variant']-2.5)*14
        o.asset_mark(); o.asset_data.catalog_id=cid
    for screen in bpy.data.screens:
        for area in screen.areas:
            if area.type=='VIEW_3D':
                region=area.spaces.active.region_3d; region.view_location=Vector((0,0,7)); region.view_distance=53
                region.view_rotation=Quaternion((1,0,0),1.28)
    bpy.data.orphans_purge(do_recursive=True); bpy.ops.file.pack_all()
    if family in ('spruce','fir','pine'):
        bpy.ops.wm.save_as_mainfile(filepath=str(source/(family+'_collection.blend')))
(source/'blender_assets.cats.txt').write_text('\n'.join(catalog)+'\n')
(root/'artifacts/trees_v2/blender_validation.json').write_text(json.dumps(report,indent=2)+'\n')
print('TREE_COLLECTION_ROUNDTRIP',len(report),flush=True)

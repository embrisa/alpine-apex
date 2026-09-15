"""Bind a portable first-direction cutout after the native directional bake."""
import json
import struct
import sys
from pathlib import Path
import bpy
import numpy as np

PACK=Path(__file__).resolve().parent
sys.path.insert(0,str(PACK))
from build import export, receipt, save_blend

path=PACK/'manifest.json'
manifest=json.loads(path.read_text())
baked={r['id'] for r in json.loads((PACK.parents[2]/'artifacts/premium_tree_review/native/bake_manifest.json').read_text())['assets']}
for record in manifest['assets']:
    if record['id'] not in baked:
        continue
    bpy.ops.wm.open_mainfile(filepath=str(PACK/record['source_blend']['path']),load_ui=False)
    bpy.context.preferences.filepaths.save_version=0
    card=bpy.data.objects[record['id']+'_lod2']
    source=bpy.data.images.load(str(PACK/record['impostor']['color']['path']),check_existing=False)
    w,h=source.size
    pixels=np.empty(w*h*4,dtype=np.float32)
    source.pixels.foreach_get(pixels)
    first=pixels.reshape(h,w,4)[:,:h].copy()
    # Atlas RGB is coverage-associated. Portable PBR textures use straight RGB.
    first[:,:,:3]/=np.maximum(first[:,:,3:4],1e-5)
    image=bpy.data.images.new(record['id']+'_portable_far',width=h,height=h,alpha=True)
    image.pixels.foreach_set(np.ascontiguousarray(first).ravel())
    image.file_format='PNG'
    image.pack()
    bpy.data.images.remove(source)
    mat=bpy.data.materials.new('PremiumTree_DirectionalPreview')
    mat.use_nodes=True
    mat.use_backface_culling=False
    mat.surface_render_method='DITHERED'
    nodes,links=mat.node_tree.nodes,mat.node_tree.links
    tex=nodes.new('ShaderNodeTexImage')
    tex.image=image
    bsdf=nodes.get('Principled BSDF')
    links.new(tex.outputs['Color'],bsdf.inputs['Base Color'])
    links.new(tex.outputs['Alpha'],bsdf.inputs['Alpha'])
    bsdf.inputs['Roughness'].default_value=.9
    card.data.materials.clear()
    card.data.materials.append(mat)
    for poly in card.data.polygons:
        poly.material_index=0
    result=export(card,2)
    target=PACK/result['path']
    raw=target.read_bytes()
    length=struct.unpack_from('<I',raw,12)[0]
    gltf=json.loads(raw[20:20+length])
    for material in gltf['materials']:
        material['alphaMode']='MASK'
        material['alphaCutoff']=.35
        material['doubleSided']=True
    text=json.dumps(gltf,separators=(',',':')).encode()
    text+=b' '*((-len(text))%4)
    binary=raw[20+length:]
    target.write_bytes(struct.pack('<4sII',b'glTF',2,20+len(text)+len(binary))+struct.pack('<I4s',len(text),b'JSON')+text+binary)
    record['models'][2]=dict(result,**receipt(target))
    card.hide_set(True)
    card.hide_render=True
    bpy.ops.file.pack_all()
    save_blend(PACK/record['source_blend']['path'])
    record['source_blend']=receipt(PACK/record['source_blend']['path'])
    record['impostor']['portable_preview']='The GLB embeds azimuth zero; far.gdshader previews all eight views with directional normals.'
    print('PREMIUM_BOUND_FAR',record['id'],flush=True)
path.write_text(json.dumps(manifest,indent=2)+'\n')

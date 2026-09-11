"""Create reusable scenes and configure only this collection's Godot imports.

Keep the standalone GLBs portable. Extract content-addressed texture copies for
Godot's material overrides so all three detail levels share the same textures.
"""
import hashlib
import json
import re
import struct
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'assets/graphics/flavor_v1'

def write_changed(path, value):
    if not path.exists() or path.read_text()!=value:
        path.write_text(value)

def texture_table(path):
    data=path.read_bytes(); length,kind=struct.unpack_from('<II',data,12)
    doc=json.loads(data[20:20+length]); offset=20+length
    binary=data[offset+8:]
    images={}
    for i,image in enumerate(doc.get('images',[])):
        if 'bufferView' not in image: continue
        view=doc['bufferViews'][image['bufferView']]
        chunk=binary[view.get('byteOffset',0):view.get('byteOffset',0)+view['byteLength']]
        suffix='.png' if image.get('mimeType')=='image/png' else '.jpg'
        name=hashlib.sha256(chunk).hexdigest()[:24]+suffix
        dest=OUT/'textures'/name
        if not dest.exists(): dest.write_bytes(chunk)
        images[i]='res://'+dest.relative_to(ROOT).as_posix()
    def tex(info):
        if not info: return None
        return images.get(doc['textures'][info['index']]['source'])
    result=[]
    for material in doc.get('materials',[]):
        pbr=material.get('pbrMetallicRoughness',{})
        result.append({'name':material.get('name',''), 'albedo':tex(pbr.get('baseColorTexture')),
            'normal':tex(material.get('normalTexture')),'orm':tex(pbr.get('metallicRoughnessTexture'))})
    return result

manifest=json.loads((OUT/'manifest.json').read_text())
for record in manifest['assets']:
    record['materials']=texture_table(ROOT/record['models'][0]['path'])
    scene='''[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/presentation/flavor_prop.gd" id="1"]

[node name="%s" type="Node3D"]
script = ExtResource("1")
asset_id = "%s"
snow_amount = %s
'''%(record['id'],record['id'],record['snow_amount'])
    write_changed(OUT/'scenes'/(record['id']+'.tscn'),scene)
write_changed(OUT/'manifest.json',json.dumps(manifest,indent=2)+'\n')
for path in (OUT/'models').glob('*.glb.import'):
    value=path.read_text()
    value=re.sub(r'meshes/generate_lods=.*','meshes/generate_lods=false',value)
    value=re.sub(r'import_script/path=.*','import_script/path="res://scripts/art/flavor_post_import.gd"',value)
    write_changed(path,value)
for path in (OUT/'textures').glob('*.import'):
    value=path.read_text()
    value=re.sub(r'mipmaps/generate=.*','mipmaps/generate=true',value)
    value=re.sub(r'compress/mode=.*','compress/mode=2',value)
    write_changed(path,value)
print('FLAVOR_SCENES',len(manifest['assets']))

"""Replace only the glove primitive of the prepared skier GLB, losslessly.

No Blender round-trip of the body: original accessors, bytes, materials and
bind transforms are retained. The staged glove GLB supplies its own PBR maps.
"""
import copy
import hashlib
import json
import struct
from pathlib import Path


def read_glb(path):
    raw = Path(path).read_bytes()
    assert struct.unpack_from('<II', raw) == (0x46546C67, 2)
    count, kind = struct.unpack_from('<II', raw, 12)
    assert kind == 0x4E4F534A
    doc = json.loads(raw[20:20+count])
    size, kind = struct.unpack_from('<II', raw, 20+count)
    assert kind == 0x004E4942 and len(doc['buffers']) == 1
    return doc, bytearray(raw[28+count:28+count+size])


def write_glb(path, doc, blob):
    doc['buffers'] = [{'byteLength': len(blob)}]
    payload = json.dumps(doc, separators=(',', ':')).encode()
    payload += b' ' * (-len(payload) % 4)
    blob = bytes(blob) + b'\0' * (-len(blob) % 4)
    raw = struct.pack('<III', 0x46546C67, 2, 28+len(payload)+len(blob))
    raw += struct.pack('<II', len(payload), 0x4E4F534A)+payload
    raw += struct.pack('<II', len(blob), 0x004E4942)+blob
    Path(path).write_bytes(raw)


def digest(blob):
    return hashlib.sha256(blob).hexdigest()


def graft(base_path, gloves_path, output_path):
    base, original = read_glb(base_path)
    source, extra = read_glb(gloves_path)
    result = copy.deepcopy(base)
    material_id = next(i for i,m in enumerate(base['materials']) if m['name']=='SkierV7Gloves')
    body = next(n for n in base['nodes'] if 'mesh' in n and 'skin' in n)
    hand_node = next(n for n in source['nodes'] if 'mesh' in n and 'skin' in n)
    assert all(k not in hand_node for k in ['matrix','translation','rotation','scale']), 'Bake glove object transforms before export'
    prims = source['meshes'][hand_node['mesh']]['primitives']
    assert len(prims)==1 and not prims[0].get('targets')
    original_skin = base['skins'][body['skin']]
    target_names = [base['nodes'][i]['name'] for i in original_skin['joints']]
    source_names = [source['nodes'][i]['name'] for i in source['skins'][hand_node['skin']]['joints']]
    assert set(source_names) == set(target_names) and len(target_names)==24
    mapping = [target_names.index(n) for n in source_names]
    for primitive in prims:
        accessor = source['accessors'][primitive['attributes']['JOINTS_0']]
        view = source['bufferViews'][accessor['bufferView']]
        fmt = {5121:'B',5123:'H'}[accessor['componentType']]
        width = struct.calcsize('<4'+fmt)
        stride = view.get('byteStride',width)
        offset = view.get('byteOffset',0)+accessor.get('byteOffset',0)
        for i in range(accessor['count']):
            address = offset+i*stride
            joints = struct.unpack_from('<4'+fmt,extra,address)
            struct.pack_into('<4'+fmt,extra,address,*(mapping[j] for j in joints))
    blob = original + b'\0' * (-len(original)%4)
    offset = len(blob)
    shifts = {key:len(result.get(key,[])) for key in ['bufferViews','accessors','images','textures','samplers']}
    for key in shifts: result.setdefault(key,[])
    for view in source.get('bufferViews',[]):
        value = copy.deepcopy(view); value['buffer']=0
        value['byteOffset']=value.get('byteOffset',0)+offset
        result['bufferViews'].append(value)
    for acc in source.get('accessors',[]):
        value=copy.deepcopy(acc); assert 'sparse' not in value
        value['bufferView']+=shifts['bufferViews'];result['accessors'].append(value)
    for img in source.get('images',[]):
        value=copy.deepcopy(img);assert 'uri' not in value
        value['bufferView']+=shifts['bufferViews'];result['images'].append(value)
    result['samplers'].extend(copy.deepcopy(source.get('samplers',[])))
    for tex in source.get('textures',[]):
        value=copy.deepcopy(tex);value['source']+=shifts['images']
        if 'sampler' in value:value['sampler']+=shifts['samplers']
        result['textures'].append(value)
    material=copy.deepcopy(source['materials'][prims[0]['material']])
    material['name']='SkierV7Gloves'
    def textures(value):
        for key,item in value.items():
            if isinstance(item,dict):
                if key.endswith('Texture'):
                    assert item.get('texCoord',0)>=0, 'Texture refers to a missing UV set'
                    item['index']+=shifts['textures']
                else:textures(item)
    textures(material)
    result['materials'][material_id]=material
    replacement=copy.deepcopy(prims[0]);replacement['material']=material_id
    replacement['indices']+=shifts['accessors']
    replacement['attributes']={k:v+shifts['accessors'] for k,v in replacement['attributes'].items()}
    for i,p in enumerate(result['meshes'][body['mesh']]['primitives']):
        if p.get('material')==material_id:
            result['meshes'][body['mesh']]['primitives'][i]=replacement
    for key in ['extensionsUsed','extensionsRequired']:
        values=sorted(set(base.get(key,[])+source.get(key,[])))
        if values:result[key]=values
    write_glb(output_path,result,blob+extra)
    updated, updated_blob=read_glb(output_path)
    assert updated_blob[:len(original)] == original
    assert updated['nodes']==base['nodes'] and updated['skins']==base['skins']
    assert updated['accessors'][:len(base['accessors'])]==base['accessors']
    assert updated['bufferViews'][:len(base['bufferViews'])]==base['bufferViews']
    for i,m in enumerate(base['materials']):
        if i!=material_id:assert updated['materials'][i]==m
    for old,new in zip(base['meshes'][body['mesh']]['primitives'],updated['meshes'][body['mesh']]['primitives']):
        if old['material']!=material_id:assert old==new
    triangles=updated['accessors'][replacement['indices']]['count']//3
    assert 0 < triangles <= 6000
    return {'non_glove_bytes_unchanged':True,'nodes_and_bind_transforms_unchanged':True,
            'non_glove_materials_unchanged':True,'bones':len(target_names),
            'paired_glove_triangles':triangles,'original_buffer_sha256':digest(original),
            'base_glb_sha256':digest(Path(base_path).read_bytes()),
            'output_glb_sha256':digest(Path(output_path).read_bytes())}

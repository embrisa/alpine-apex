"""Combine Meshy leaf crowns with the shared winter trunks, all offline.

Usage: SOURCE_WORKING.glb BARE_LOD_DIRECTORY OUTPUT_DIRECTORY.
Requires numpy, Pillow and meshoptimizer==0.2.30a0; Exclusive guard.
Inputs are normalized 12 m GLBs with identity node transforms. One padded atlas
and one surface per LOD avoid adding material submissions to the forest.
"""
import argparse
import io
import json
import struct
from pathlib import Path
import numpy as np
import meshoptimizer as meshopt
from PIL import Image

parser=argparse.ArgumentParser()
parser.add_argument('source',type=Path)
parser.add_argument('bare',type=Path)
parser.add_argument('output',type=Path)
args=parser.parse_args()
class Source:
    def __init__(self,path):
        raw=path.read_bytes();size=struct.unpack_from('<I',raw,12)[0]
        self.doc=json.loads(raw[20:20+size]);self.blob=raw[28+size:]
        assert len(self.doc['meshes'])==1 and len(self.doc['meshes'][0]['primitives'])==1
        assert all(not any(k in n for k in ['matrix','rotation','scale','translation']) for n in self.doc['nodes'])
        p=self.doc['meshes'][0]['primitives'][0]
        self.attributes={name:self.read(index) for name,index in p['attributes'].items()}
        self.indices=self.read(p['indices']).astype(np.uint32).ravel()
        material=self.doc['materials'][p['material']]
        texture=self.doc['textures'][material['pbrMetallicRoughness']['baseColorTexture']['index']]
        image=self.doc['images'][texture['source']];view=self.doc['bufferViews'][image['bufferView']]
        offset=view.get('byteOffset',0)
        self.image=Image.open(io.BytesIO(self.blob[offset:offset+view['byteLength']])).convert('RGB')
    def read(self,index):
        a=self.doc['accessors'][index];v=self.doc['bufferViews'][a['bufferView']]
        dtype=np.dtype({5126:'<f4',5125:'<u4',5123:'<u2',5121:'u1'}[a['componentType']])
        n={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4}[a['type']]
        return np.ndarray((a['count'],n),dtype=dtype,buffer=self.blob,
            offset=v.get('byteOffset',0)+a.get('byteOffset',0),
            strides=(v.get('byteStride',dtype.itemsize*n),dtype.itemsize)).copy()

crown=Source(args.source)
tri=crown.indices.reshape(-1,3);positions=crown.attributes['POSITION']
pixels=np.asarray(crown.image)/255.0
uv=crown.attributes['TEXCOORD_0']
xy=(np.clip(uv,0,1)*[pixels.shape[1]-1,pixels.shape[0]-1]).astype(int)
color=pixels[xy[:,1],xy[:,0]]
green=color[:,1]-np.maximum(color[:,0],color[:,2])
centers=positions[tri].mean(axis=1)
leaf=(green[tri].mean(axis=1)>.009)&(centers[:,1]>2.8)&(np.linalg.norm(centers[:,[0,2]],axis=1)>.18)
leaf_indices=np.ascontiguousarray(tri[leaf].ravel())
assert len(leaf_indices)>30000,'Missing leafy source crown'
# The generated maple crown is narrow and sparse. Two differently oriented
# source crowns fill the shared broad winter branch envelope; the final leaf
# budget is unchanged. This is authored geometry, never runtime duplication.
if 'maple' in args.bare.name:
    rotation=np.array([[0,0,-1],[0,1,0],[1,0,0]],dtype=np.float32)
    old_count=len(positions)
    for name,values in crown.attributes.items():
        extra=values.copy()
        if name in ['POSITION','NORMAL','TANGENT']:
            extra[:,:3]=extra[:,:3]@rotation
            if name=='POSITION':extra[:,[0,2]]*=1.12
        crown.attributes[name]=np.concatenate([values,extra])
    positions=crown.attributes['POSITION']
    leaf_indices=np.concatenate([leaf_indices,leaf_indices+old_count]).astype(np.uint32)
args.output.mkdir(parents=True,exist_ok=True)
report={'source':str(args.source),'shared_trunk':str(args.bare),'leaf_source_triangles':len(leaf_indices)//3,'lods':[]}
for lod,target in enumerate([45000,14000]):
    bare=Source(args.bare/('tree_lod%d.glb'%lod))
    destination=np.empty_like(leaf_indices);error=np.zeros(1,dtype=np.float32)
    count=meshopt.simplify_sloppy(destination,leaf_indices,positions,target_index_count=target*3,target_error=1.0,result_error=error)
    used,inverse=np.unique(destination[:count],return_inverse=True)
    attributes={}
    for name in ['POSITION','NORMAL','TANGENT','TEXCOORD_0']:
        wood=bare.attributes[name].copy();leaves=crown.attributes[name][used].copy()
        if name=='TEXCOORD_0':
            wood=(wood*2032+8)/np.array([4096,2048])
            leaves=(leaves*2032+[2056,8])/np.array([4096,2048])
        attributes[name]=np.concatenate([wood,leaves]).astype('<f4')
    indices=np.concatenate([bare.indices,inverse+len(bare.attributes['POSITION'])]).astype('<u4')
    atlas=Image.new('RGB',(4096,2048))
    for image,x in [(bare.image,0),(crown.image,2048)]:
        tile=image.resize((2032,2032),Image.Resampling.LANCZOS)
        atlas.paste(tile,(x+8,8))
        # Extend edge colours into the gutter, keeping mip sampling away from black.
        atlas.paste(tile.resize((2048,2048)),(x,0));atlas.paste(tile,(x+8,8))
    png=io.BytesIO();atlas.save(png,format='PNG')
    doc={'asset':{'version':'2.0','generator':'Alpine Apex Meshy seasonal crown preparation'},
         'scene':0,'scenes':[{'nodes':[0]}],'nodes':[{'mesh':0}],'meshes':[{'primitives':[{'attributes':{},'material':0}]}],
         'materials':[{'name':'Meshy seasonal tree','pbrMetallicRoughness':{'baseColorTexture':{'index':0},'roughnessFactor':.9,'metallicFactor':0}}],
         'textures':[{'source':0}],'images':[],'bufferViews':[],'accessors':[],'buffers':[]}
    blob=bytearray();p=doc['meshes'][0]['primitives'][0]
    def add_view(data):
        blob.extend(b'\0'*(-len(blob)%4));i=len(doc['bufferViews'])
        doc['bufferViews'].append({'buffer':0,'byteOffset':len(blob),'byteLength':len(data)});blob.extend(data);return i
    def add(data,component,kind):
        a={'bufferView':add_view(data.tobytes()),'componentType':component,'count':len(data),'type':kind}
        if kind=='VEC3':a.update(min=data.min(axis=0).tolist(),max=data.max(axis=0).tolist())
        i=len(doc['accessors']);doc['accessors'].append(a);return i
    for name,data in attributes.items():p['attributes'][name]=add(data,5126,'VEC%d'%data.shape[1])
    p['indices']=add(indices,5125,'SCALAR');doc['images'].append({'bufferView':add_view(png.getvalue()),'mimeType':'image/png'})
    blob.extend(b'\0'*(-len(blob)%4));doc['buffers'].append({'byteLength':len(blob)})
    encoded=json.dumps(doc,separators=(',',':')).encode();encoded+=b' '*(-len(encoded)%4)
    result=struct.pack('<4sII',b'glTF',2,28+len(encoded)+len(blob))
    result+=struct.pack('<I4s',len(encoded),b'JSON')+encoded+struct.pack('<I4s',len(blob),b'BIN\0')+blob
    (args.output/('tree_lod%d.glb'%lod)).write_bytes(result)
    report['lods'].append({'lod':lod,'triangles':len(indices)//3,'leaf_triangles':count//3,'vertices':len(attributes['POSITION']),'relative_leaf_error':float(error[0])})
(args.output/'compose.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report),flush=True)

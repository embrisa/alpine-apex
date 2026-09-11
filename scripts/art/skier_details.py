"""Local geometry/material finishing for the existing Meshy skier; no AI calls."""
import bpy
from mathutils import Vector


def finish_details(body, arm, atlas, cut):
    # Assign semantic surfaces before skinning export. The lens follows amber
    # texels on the actual curved goggle geometry, retaining its dark rim.
    materials = {}
    for name, roughness, metallic in [('Clothing', .78, 0), ('Helmet', .38, .08),
                                      ('Lens', .12, .80), ('Skin', .70, 0)]:
        mat = atlas.copy()
        mat.name = 'SkierV7'+name
        shader = mat.node_tree.nodes.get('Principled BSDF')
        for key, value in [('Roughness', roughness), ('Metallic', metallic)]:
            for link in list(shader.inputs[key].links): mat.node_tree.links.remove(link)
            shader.inputs[key].default_value = value
        if name == 'Lens':
            for link in list(shader.inputs['Normal'].links): mat.node_tree.links.remove(link)
        materials[name] = mat
    tex = next(n.image for n in atlas.node_tree.nodes if n.type=='TEX_IMAGE' and n.outputs['Color'].is_linked and any(l.to_socket.name=='Base Color' for l in n.outputs['Color'].links))
    pixels = list(tex.pixels)
    width, height = tex.size
    body.data.materials.clear()
    for mat in materials.values(): body.data.materials.append(mat)
    counts = dict.fromkeys(materials, 0)
    uv = body.data.uv_layers.active.data
    for face in body.data.polygons:
        center = sum((body.data.vertices[v].co for v in face.vertices), Vector()) / len(face.vertices)
        u, v = sum((uv[i].uv for i in face.loop_indices), Vector((0,0))) / len(face.loop_indices)
        pixel = ((int(v*height)%height)*width+int(u*width)%width)*4
        r,g,b = pixels[pixel:pixel+3]
        label = 'Clothing'
        if center.z > 1.64 or (center.z>1.59 and r+g+b<.22): label = 'Helmet'
        elif center.z>1.515 and center.y<-.045: label = 'Skin'
        if 1.59<center.z<1.693 and abs(center.x)<.108 and center.y<-.065 and r>g*1.15 and g>b*1.2:
            label = 'Lens'
        face.material_index = list(materials).index(label)
        counts[label] += 1
    assert counts['Lens']>50 and counts['Helmet']>100

    # Preserve the original body cuts; append the verified, connected glove
    # template using the existing wrist and cuff weights. No network calls.
    cut(body, (.682,0,0), (1,0,0), True)
    cut(body, (-.688,0,0), (1,0,0), False)
    from skier_gloves import append_gloves
    append_gloves(body, arm)
    body.data.calc_loop_triangles()
    print('SKIER_SEMANTIC_SURFACES', counts, 'gloves', 'connected_meshy_v1')

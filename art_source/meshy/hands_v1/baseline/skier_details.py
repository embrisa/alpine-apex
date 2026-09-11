"""Local geometry/material finishing for the existing Meshy skier; no AI calls."""
import bpy, bmesh, math
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

    # Replace the generated open fingers with authored insulated gloves. Four
    # curled finger tubes surround a real handle-sized opening; a crossing thumb
    # closes the grip. All vertices are rigidly bound to their Hand bone.
    cut(body, (.682,0,0), (1,0,0), True)
    cut(body, (-.688,0,0), (1,0,0), False)
    glove = bpy.data.materials.new('SkierV7Gloves')
    glove.use_nodes = True
    shader = glove.node_tree.nodes.get('Principled BSDF')
    shader.inputs['Base Color'].default_value = (.017,.021,.026,1)
    shader.inputs['Roughness'].default_value = .70
    parts = []
    def ellipsoid(point, size, origin, group):
        world = origin+Vector((point[0],-point[2],point[1]))
        bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=8, location=world)
        obj = bpy.context.object
        obj.scale = (size[0],size[2],size[1])
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        obj.data.materials.append(glove)
        obj.vertex_groups.new(name=group).add(list(range(len(obj.data.vertices))),1,'REPLACE')
        for face in obj.data.polygons: face.use_smooth = True
        parts.append(obj)
    def tube(points, radius, origin, group):
        verts, faces = [], []
        for i, point in enumerate(points):
            tangent = (Vector(points[min(i+1,len(points)-1)])-Vector(points[max(i-1,0)])).normalized()
            axis = tangent.cross(Vector((0,0,1))).normalized()
            second = tangent.cross(axis).normalized()
            for j in range(8):
                p = Vector(point)+radius*(axis*math.cos(j*math.tau/8)+second*math.sin(j*math.tau/8))
                verts.append(origin+Vector((p.x,-p.z,p.y)))
            if i:
                for j in range(8): faces.append(((i-1)*8+j,(i-1)*8+(j+1)%8,i*8+(j+1)%8,i*8+j))
        faces += [tuple(reversed(range(8))),tuple(range(len(verts)-8,len(verts)))]
        mesh=bpy.data.meshes.new('CurledFinger'); mesh.from_pydata(verts,[],faces); mesh.materials.append(glove)
        obj=bpy.data.objects.new('CurledFinger',mesh); bpy.context.collection.objects.link(obj)
        obj.vertex_groups.new(name=group).add(list(range(len(mesh.vertices))),1,'REPLACE')
        for face in mesh.polygons: face.use_smooth=True
        parts.append(obj)
    for side, prefix in [(1,'Left'),(-1,'Right')]:
        group=prefix+'Hand'; origin=arm.matrix_world@arm.data.bones[group].head_local
        ellipsoid((side*.030,.025,.005),(.045,.024,.041),origin,group)
        ellipsoid((side*.005,.005,.0),(.028,.035,.040),origin,group)
        ellipsoid((-side*.012,.005,0),(.026,.043,.043),origin,prefix+'ForeArm')
        for j in range(4):
            z=-.030+j*.019
            points=[(side*(.070+.026*math.cos(.05+k*4.4/16)),.026*math.sin(.05+k*4.4/16),z) for k in range(17)]
            tube(points,.010,origin,group)
        tube([(side*.012,.012,.042),(side*.035,-.007,.039),(side*.060,-.016,.028),(side*.082,-.014,.016)],.014,origin,group)
    bpy.ops.object.select_all(action='DESELECT')
    for obj in parts+[body]: obj.select_set(True)
    bpy.context.view_layer.objects.active=body
    bpy.ops.object.join()
    body.data.calc_loop_triangles()
    print('SKIER_SEMANTIC_SURFACES',counts,'glove_parts',len(parts))

"""Geometry and portable materials for the unintegrated colorful-tree collection."""
import math
import bpy
from mathutils import Vector

ROUND = [(0, 0), (.32, .06), (.49, .28), (.5, .53), (.37, .81),
         (0, 1.09), (-.37, .81), (-.5, .53), (-.49, .28), (-.32, .06)]
LOBED = [(0, 0), (.13, .23), (.46, .14), (.35, .38), (.69, .53),
         (.38, .59), (.48, .91), (.17, .76), (0, 1.2),
         (-.17, .76), (-.48, .91), (-.38, .59), (-.69, .53),
         (-.35, .38), (-.46, .14), (-.13, .23)]


def linear(rgb):
    return tuple(v / 12.92 if v <= .04045 else ((v + .055) / 1.055) ** 2.4 for v in rgb)


class Geometry:
    def __init__(self):
        self.vertices, self.faces, self.colors, self.uvs, self.tags = [], [], [], [], []

    def face(self, points, color, uv=None, tag=(0, 0)):
        start = len(self.vertices)
        self.vertices.extend(tuple(p) for p in points)
        self.faces.append(tuple(range(start, start + len(points))))
        self.colors.extend([(*color[:3], 1.0)] * len(points))
        self.uvs.extend(uv or [(0, 0)] * len(points))
        self.tags.extend([tag] * len(points))

    def leaf(self, origin, along, side, length, shape, color, detail=True, tag=(0, 0)):
        outline = ROUND if shape == 'rounded' else LOBED
        if not detail:
            # Preserve species contour; simplify the rounded leaf only.
            outline = ROUND[::2] if shape == 'rounded' else [LOBED[i] for i in (0, 2, 4, 7, 8, 9, 12, 14)]
        normal = side.cross(along).normalized()
        center = origin + along * length * .48 + normal * length * .045
        points = [origin + (side * x + along * y + normal * (abs(x) * -.055)) * length for x, y in outline]
        def leaf_uv(x, y):
            tile = 0 if shape == 'rounded' else .5
            spread = .85 if shape == 'rounded' else .65
            return (tile + (x * spread + .5) * .5, y / 1.2)
        for i, p in enumerate(points):
            j = (i + 1) % len(points)
            shade = 1.03 if outline[i][0] > 0 else .91
            self.face([center, p, points[j]], tuple(min(1, c * shade) for c in color),
                      [leaf_uv(0, .48), leaf_uv(*outline[i]), leaf_uv(*outline[j])], tag)

    def object(self, name, material, smooth=False):
        mesh = bpy.data.meshes.new(name)
        mesh.from_pydata(self.vertices, [], self.faces)
        mesh.update()
        colors = mesh.color_attributes.new(name='Color', type='FLOAT_COLOR', domain='CORNER')
        uv = mesh.uv_layers.new(name='UVMap')
        branch = mesh.uv_layers.new(name='BranchPivot')
        for poly in mesh.polygons:
            poly.use_smooth = smooth
            for li in poly.loop_indices:
                vi = mesh.loops[li].vertex_index
                colors.data[li].color = self.colors[vi]
                uv.data[li].uv = self.uvs[vi]
                branch.data[li].uv = self.tags[vi]
        mesh.materials.append(material)
        obj = bpy.data.objects.new(name, mesh)
        bpy.context.scene.collection.objects.link(obj)
        return obj


def material(name, bark=None, leaf_maps=None):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    mat.use_backface_culling = False
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    bsdf = nodes.get('Principled BSDF')
    bsdf.inputs['Roughness'].default_value = .78 if bark else .68
    vertex = nodes.new('ShaderNodeVertexColor')
    vertex.layer_name = 'Color'
    links.new(vertex.outputs['Color'], bsdf.inputs['Base Color'])
    uv = nodes.new('ShaderNodeUVMap')
    uv.uv_map = 'UVMap'
    if bark or leaf_maps:
        texture = nodes.new('ShaderNodeTexImage')
        texture.image = bpy.data.images.load(str(bark or leaf_maps / 'leaf_albedo.png'), check_existing=True)
        links.new(uv.outputs['UV'], texture.inputs['Vector'])
        mix = nodes.new('ShaderNodeMixRGB')
        mix.blend_type = 'MULTIPLY'
        mix.inputs[0].default_value = 1
        links.new(vertex.outputs['Color'], mix.inputs[1])
        links.new(texture.outputs['Color'], mix.inputs[2])
        links.new(mix.outputs[0], bsdf.inputs['Base Color'])
    if leaf_maps:
        roughness = nodes.new('ShaderNodeTexImage')
        roughness.image = bpy.data.images.load(str(leaf_maps / 'leaf_roughness.png'), check_existing=True)
        roughness.image.colorspace_settings.name = 'Non-Color'
        links.new(uv.outputs['UV'], roughness.inputs['Vector'])
        links.new(roughness.outputs['Color'], bsdf.inputs['Roughness'])
        texture = nodes.new('ShaderNodeTexImage')
        texture.image = bpy.data.images.load(str(leaf_maps / 'leaf_normal.png'), check_existing=True)
        texture.image.colorspace_settings.name = 'Non-Color'
        links.new(uv.outputs['UV'], texture.inputs['Vector'])
        bump = nodes.new('ShaderNodeNormalMap')
        bump.uv_map = 'UVMap'
        bump.inputs['Strength'].default_value = .35
        links.new(texture.outputs['Color'], bump.inputs['Color'])
        links.new(bump.outputs['Normal'], bsdf.inputs['Normal'])
    mat['role'] = name.rsplit('_', 1)[-1]
    return mat


def tag(point, height):
    band = max(0, min(2, int(point.z / height * 3)))
    sector = int((math.atan2(point.y, point.x) + math.pi) % math.tau / math.tau * 4)
    return ((band * 4 + sector) / 16, 1 - ((band + .08) * height / 3) / 32)


def join(objects, name):
    bpy.ops.object.select_all(action='DESELECT')
    for obj in objects:
        obj.hide_set(False)
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.join()
    result = objects[0]
    result.name = name
    return result


def simplify(obj, budget):
    import bmesh
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=.00001)
    bm.to_mesh(obj.data)
    bm.free()
    obj.data.calc_loop_triangles()
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    if len(obj.data.loop_triangles) > budget:
        modifier = obj.modifiers.new('Bounded wood detail', 'DECIMATE')
        modifier.ratio = budget / len(obj.data.loop_triangles)
        bpy.ops.object.modifier_apply(modifier=modifier.name)


def export_glb(obj, path):
    import hashlib
    bpy.ops.object.select_all(action='DESELECT')
    obj.hide_set(False)
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.export_scene.gltf(filepath=str(path), export_format='GLB', use_selection=True,
                             export_animations=False, export_yup=True,
                             export_vertex_color='NAME', export_vertex_color_name='Color',
                             export_all_vertex_colors=False)
    obj.data.calc_loop_triangles()
    bpy.context.view_layer.update()
    return {'file': path.name, 'sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
            'bytes': path.stat().st_size, 'triangles': len(obj.data.loop_triangles),
            'dimensions_blender_xyz_m': list(obj.dimensions),
            'surfaces': len(obj.data.materials)}

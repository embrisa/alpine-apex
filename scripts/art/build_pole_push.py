"""Editable original pole action via Blender -> Godot control resource.

Parent runs through run_guarded.ps1; this is an authoring workload. No paid calls.
First build: Blender --background --factory-startup --python-exit-code 1
    --python scripts/art/build_pole_push.py
After editing controls in the retained blend: same command, append -- --export-existing.
The weighted production skier is an explanatory source preview; Godot's final
tracker/anatomy/cuff/clearance composition remains the required visual acceptance.
"""
from pathlib import Path
import argparse
import hashlib
import json
import math
import re
import sys

import bpy
from mathutils import Matrix, Quaternion, Vector

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "art_source/animation/pole_push_v1/cycle.json"
BLEND = ROOT / "art_source/animation/pole_push_v1/pole_push.blend"
RESOURCE = ROOT / "assets/animation/pole_push_cycle.tres"
CONTROLS = ("hips_degrees", "spine_degrees", "wrists", "trails")
END = 120.0
CONVERT = Matrix(((1, 0, 0), (0, 0, -1), (0, 1, 0)))


def curves(action):
    for layer in action.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                yield from bag.fcurves


def smooth_keys(action):
    for curve in curves(action):
        keys = curve.keyframe_points
        for i, key in enumerate(keys):
            key.interpolation = "BEZIER"
            key.handle_left_type = key.handle_right_type = "FREE"
            before = key.co.x - keys[i - 1].co.x if i else 1
            after = keys[i + 1].co.x - key.co.x if i + 1 < len(keys) else 1
            key.handle_left = (key.co.x - before / 3, key.co.y)
            key.handle_right = (key.co.x + after / 3, key.co.y)


def create_controls(source):
    group = bpy.data.collections.new("EDIT THESE: pole action controls")
    bpy.context.scene.collection.children.link(group)
    for name in CONTROLS:
        obj = bpy.data.objects.new("PoleControl_" + name, None)
        group.objects.link(obj)
        obj.empty_display_type = "PLAIN_AXES"
        obj.empty_display_size = .08
        obj["contract"] = "Data channels in Godot axes; edit location F-curves. Scalars use X. No root motion."
        for phase, value in zip(source["phases"], source[name]):
            obj.location = value if isinstance(value, list) else (value, 0, 0)
            obj.keyframe_insert("location", frame=phase * END, group=name)
        obj.animation_data.action.name = "Apex_PolePush_" + name
        obj.animation_data.action.use_fake_user = True
        smooth_keys(obj.animation_data.action)
        obj.hide_render = True


def sample_controls(frame):
    bpy.context.scene.frame_set(int(frame), subframe=frame % 1)
    return {name: list(bpy.data.objects["PoleControl_" + name].location)
            if name in ("wrists", "trails") else bpy.data.objects["PoleControl_" + name].location.x
            for name in CONTROLS}


def export_resource():
    knots = {0.0, END}
    for name in CONTROLS:
        action = bpy.data.objects["PoleControl_" + name].animation_data.action
        smooth_keys(action)
        for curve in curves(action):
            knots.update(round(k.co.x, 6) for k in curve.keyframe_points if 0 <= k.co.x <= END)
    knots = sorted(knots)
    rows = [sample_controls(f) for f in knots]
    for name in CONTROLS:
        first = rows[0][name]; last = rows[-1][name]
        a = first if isinstance(first, list) else [first]
        b = last if isinstance(last, list) else [last]
        assert max(abs(x-y) for x, y in zip(a, b)) < 1e-5, f"{name}: loop endpoints differ"
    def values(sequence):
        return ", ".join(format(v, ".8g") for v in sequence)
    lines = ['[gd_resource type="Resource" load_steps=2 format=3]', '',
             '[ext_resource type="Script" path="res://scripts/presentation/pole_push_motion.gd" id="1"]', '',
             '[resource]', 'script = ExtResource("1")',
             'source = "art_source/animation/pole_push_v1/pole_push.blend"',
             'phases = PackedFloat32Array(' + values(f / END for f in knots) + ')']
    for name in CONTROLS:
        vector = name in ("wrists", "trails")
        data = [v for row in rows for v in row[name]] if vector else [row[name] for row in rows]
        lines.append(name + ' = ' + ('PackedVector3Array' if vector else 'PackedFloat32Array') + '(' + values(data) + ')')
    RESOURCE.write_text("\n".join(lines) + "\n", encoding="utf-8", newline="\n")


def joint(a, b, upper, lower, hint):
    delta = b-a; distance = max(.001, min(delta.length, upper+lower-.001))
    direction = delta.normalized()
    along = (upper*upper-lower*lower+distance*distance)/(2*distance)
    perpendicular = hint-direction*hint.dot(direction)
    return a+direction*along+perpendicular.normalized()*math.sqrt(max(0, upper*upper-along*along))


def build_preview():
    # Production skin/rest identity is retained; this action never reexports it.
    preview = bpy.data.collections.get("PolePush generated preview")
    if preview:
        for obj in list(preview.all_objects):
            bpy.data.objects.remove(obj, do_unlink=True)
    else:
        preview = bpy.data.collections.new("PolePush generated preview")
        bpy.context.scene.collection.children.link(preview)
    existing_objects = set(bpy.context.scene.objects)
    bpy.ops.import_scene.gltf(filepath=str(ROOT / "assets/graphics/models/skier_v7.glb"))
    imported = set(bpy.context.scene.objects) - existing_objects
    for obj in imported:
        for collection in list(obj.users_collection): collection.objects.unlink(obj)
        preview.objects.link(obj)
    arm = next(o for o in imported if o.type == "ARMATURE")
    arm.name = "PolePush_SourcePreview"
    arm.animation_data_clear()
    arm.show_in_front = True
    rest = {b.name: arm.matrix_world @ b.matrix_local for b in arm.data.bones}
    parent = {b.name: b.parent.name if b.parent else None for b in arm.data.bones}
    gd = (ROOT / "scripts/core/rider_body.gd").read_text(encoding="utf-8")
    points = {name: Vector(tuple(map(float, xyz.split(',')))) for name, xyz in
              re.findall(r'"([^"]+)":Vector3\(([^)]+)\)', gd.split('const SEGMENTS')[0])}
    pole_objects = []
    for side in (-1, 1):
        bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=.008, depth=1.18)
        pole_objects.append(bpy.context.object)
        for collection in list(pole_objects[-1].users_collection): collection.objects.unlink(pole_objects[-1])
        preview.objects.link(pole_objects[-1])
        pole_objects[-1].name = "SourcePole_Right" if side < 0 else "SourcePole_Left"
    for frame in range(121):
        controls = sample_controls(frame)
        posed = {}; rotations = {}
        for name in ("Hips", "Spine02", "Spine01", "Spine", "neck", "Head"):
            pitch = (controls["hips_degrees"] if name == "Hips" else controls["spine_degrees"]
                     if name in ("Spine02", "Spine01") else -4 if name == "Spine" else -10)
            local = Matrix.Rotation(math.radians(pitch), 3, 'X')
            if name == "Hips":
                posed[name] = Vector((0, .85, -.12)); rotations[name] = local
            else:
                p = parent[name]
                posed[name] = posed[p]+rotations[p] @ (points[name]-points[p])
                rotations[name] = rotations[p] @ local
        for side, prefix in ((-1, "Right"), (1, "Left")):
            shoulder, upper, elbow, hand = (prefix+s for s in ("Shoulder", "Arm", "ForeArm", "Hand"))
            for name in (shoulder, upper):
                p = parent[name]; rotations[name] = rotations[p].copy()
                posed[name] = posed[p]+rotations[p] @ (points[name]-points[p])
            wrist = controls["wrists"]
            target = Vector((side*wrist[0], posed[upper].y+wrist[1], posed[upper].z+wrist[2]))
            u = (points[upper]-points[elbow]).length; l = (points[elbow]-points[hand]).length
            reach = target-posed[upper]
            if reach.length > u+l-.012: target = posed[upper]+reach.normalized()*(u+l-.012)
            posed[hand] = target
            posed[elbow] = joint(posed[upper], target, u, l, Vector((side*.65, -1, -.15)))
            for name, child in ((upper, elbow), (elbow, hand)):
                rotations[name] = (points[child]-points[name]).rotation_difference(posed[child]-posed[name]).to_matrix()
            trail = Vector(controls["trails"]); trail.x *= side; trail.normalize()
            z = -trail; x = rotations[elbow].col[0]; x = (x-z*x.dot(z)).normalized()
            rotations[hand] = Matrix((x, z.cross(x), z)).transposed()
            pole = pole_objects[0 if side < 0 else 1]
            grip = target+rotations[hand] @ Vector((side*.070, 0, .018))
            pole.location = CONVERT @ (grip+trail*.59)
            pole.rotation_mode = 'QUATERNION'
            pole.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(CONVERT @ trail)
            pole.keyframe_insert('location', frame=frame)
            pole.keyframe_insert('rotation_quaternion', frame=frame)
        desired = {}
        for bone in arm.data.bones:
            name = bone.name; p = parent[name]
            if name in rotations:
                matrix = (CONVERT @ rotations[name] @ CONVERT.transposed()).to_4x4() @ rest[name]
                matrix.translation = CONVERT @ posed[name]
            else:
                matrix = desired[p] @ rest[p].inverted() @ rest[name] if p else rest[name].copy()
            desired[name] = matrix
            kwargs = {} if not p else {'parent_matrix': arm.matrix_world.inverted() @ desired[p],
                                       'parent_matrix_local': arm.data.bones[p].matrix_local}
            basis = bone.convert_local_to_pose(arm.matrix_world.inverted() @ matrix, bone.matrix_local, invert=True, **kwargs)
            pb = arm.pose.bones[name]; pb.rotation_mode = 'QUATERNION'
            pb.rotation_quaternion = basis.to_quaternion(); pb.location = basis.translation if not p else (0, 0, 0)
            pb.keyframe_insert('rotation_quaternion', frame=frame, group=name)
            if not p: pb.keyframe_insert('location', frame=frame, group=name)
    arm.animation_data.action.name = "Apex_PolePush_SourcePreview"
    arm.animation_data.action.use_fake_user = True
    for curve in curves(arm.animation_data.action):
        for key in curve.keyframe_points: key.interpolation = 'LINEAR'


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--export-existing', action='store_true')
    args = parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
    if args.export_existing:
        assert BLEND.exists(), "Build the editable source first"
        bpy.ops.wm.open_mainfile(filepath=str(BLEND))
        # Controls are the authoritative editable source; preserve artist edits.
    else:
        assert not BLEND.exists(), "Preserve existing source: edit it and use --export-existing"
        bpy.ops.wm.read_factory_settings(use_empty=True)
        create_controls(json.loads(SOURCE.read_text(encoding='utf-8')))
    build_preview()
    scene = bpy.context.scene
    scene.frame_start = 0; scene.frame_end = 120; scene.render.fps = 120
    scene['scope'] = "Original pole control action. Source preview only; validate final Godot fitting."
    export_resource()
    scene.frame_set(0)
    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND))
    sha = lambda path: hashlib.sha256(path.read_bytes()).hexdigest()
    receipt = {"blender": bpy.app.version_string, "source_sha256": sha(SOURCE), "blend_sha256": sha(BLEND),
               "resource_sha256": sha(RESOURCE), "script_sha256": sha(Path(__file__)),
               "runtime_pose_accepted": False, "notes": "Actual Blender export receipt, not a rendered/gameplay acceptance."}
    (BLEND.parent / 'export_provenance.json').write_text(json.dumps(receipt, indent=2)+'\n', encoding='utf-8')
    print(json.dumps(receipt))


if __name__ == '__main__':
    main()

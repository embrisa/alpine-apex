"""Retarget recovered research motion onto the current Apex mesh in Blender.

Run with Blender --background --factory-startup --python THIS_FILE --
  --source SOURCE.glb [--target TARGET.glb] [--out OUTPUT_DIRECTORY]

Writes only to the output directory (ignored artifacts by default). Never changes
the runtime model or the solver. Source motion must be the corrected 60 Hz export.
The comparison contains stored clips, not Steep's evaluated animation graph/IK.
"""
import argparse
import hashlib
import json
import math
import sys
from pathlib import Path

import bpy
import numpy as np
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parents[2]
parser = argparse.ArgumentParser()
parser.add_argument('--source', type=Path, required=True)
parser.add_argument('--target', type=Path, default=ROOT/'assets/graphics/models/skier_v7.glb')
parser.add_argument('--out', type=Path, default=ROOT/'artifacts/steep_motion_fidelity')
parser.add_argument('--skip-sheet', action='store_true', help='Export expanded motion without the eight-pose research sheet.')
args = parser.parse_args(sys.argv[sys.argv.index('--')+1:])
args.out.mkdir(parents=True, exist_ok=True)
assert args.source.resolve() != args.target.resolve()
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.render.fps = 60  # Must precede glTF import: seconds become Blender frames.


def imported(path):
    old = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(path))
    new = set(bpy.data.objects)-old
    arm = next(o for o in new if o.type == 'ARMATURE')
    meshes = [o for o in new if o.type == 'MESH'
              and any(m.type == 'ARMATURE' and m.object == arm for m in o.modifiers)]
    return arm, meshes


source, source_meshes = imported(args.source)
source_actions = list(bpy.data.actions)
target, target_meshes = imported(args.target)
assert len(target_meshes) == 1
assert len(target.data.bones) == 24, 'Re-audit mapping when the target rig changes.'
mapping = {'Hips': 'Hips', 'Spine02': 'Spine', 'Spine01': 'Spine1',
           'Spine': 'Spine2', 'neck': 'Neck', 'Head': 'Head'}
for side in ['Left', 'Right']:
    for role in ['Shoulder', 'Arm', 'ForeArm', 'Hand', 'UpLeg', 'Leg', 'Foot']:
        mapping[side+role] = side+role

# Aim directions use anatomical joint heads, never Blender display-bone tails
# on the source: Anvil's bone axes/tails do not point along the human limbs.
chains = {'Spine02': ('Spine01', 'Spine1'), 'Spine01': ('Spine', 'Spine2'),
          'Spine': ('neck', 'Neck'), 'neck': ('Head', 'Head')}
for side in ['Left', 'Right']:
    for a, b in [('Shoulder', 'Arm'), ('Arm', 'ForeArm'), ('ForeArm', 'Hand'),
                 ('UpLeg', 'Leg'), ('Leg', 'Foot')]:
        chains[side+a] = (side+b, side+b)
    # These two unnamed source endpoints are the children of the foot joints.
    # Treat them as directional landmarks, without claiming a decoded bone name.
    chains[side+'Foot'] = (side+'ToeBase',
                          'bone_b95094e1' if side == 'Left' else 'bone_42be0fcb')

source_rest = {b.name: source.matrix_world @ b.matrix_local for b in source.data.bones}
target_rest = {b.name: target.matrix_world @ b.matrix_local for b in target.data.bones}
target_inverse = target.matrix_world.inverted()
calibration = {}
for dst, src in mapping.items():
    sr = source_rest[src].to_quaternion()
    tr = target_rest[dst].to_quaternion()
    if dst in chains:
        dc, sc = chains[dst]
        dv = target_rest[dc].translation-target_rest[dst].translation
        sv = source_rest[sc].translation-source_rest[src].translation
        align = dv.rotation_difference(sv)
    elif dst.endswith('Hand'):
        # Palm axis uses source middle-finger base and target hand display tail.
        side = 'Left' if dst.startswith('Left') else 'Right'
        dv = target.matrix_world @ target.data.bones[dst].tail_local-target_rest[dst].translation
        sv = source_rest[side+'HandMiddle1'].translation-source_rest[src].translation
        align = dv.rotation_difference(sv)
    else:
        align = Matrix.Identity(3).to_quaternion()
    calibration[dst] = sr.inverted() @ align @ tr


def leg_length(rest):
    return sum((rest[a].translation-rest[b].translation).length
               for a, b in [('LeftUpLeg', 'LeftLeg'), ('LeftLeg', 'LeftFoot')])


scale = leg_length(target_rest)/leg_length(source_rest)
rest_delta = target_rest['Hips'].translation-source_rest['Hips'].translation*scale
clips = []
all_direction_errors = []
all_length_errors = []
contact_poses = []
previous_quats = {}
representatives = {'NAV_MED_FWD': .25, 'NAV_MED_LEFT': .5, 'NAV_MED_RIGHT': .5,
                   'OLLIE_BACKFLIP_TO_AIR': .5, 'AIR_BACKFLIP_LONG': .5,
                   'AIR_TO_LAND_BACKFLIP': .75, 'GRAB_SAFETY': .5,
                   'AIR_TO_LAND_BACKFLIP_SPINLEFT_PANIC': .75}


def activate(arm, action):
    arm.animation_data_create()
    arm.animation_data.action = action
    if action.slots:
        arm.animation_data.action_slot = action.slots[0]
    for track in arm.animation_data.nla_tracks:
        track.mute = True


for source_action in source_actions:
    short = source_action.name.removeprefix('ID01_PS00_female_')
    action = bpy.data.actions.new('Research_'+short)
    activate(source, source_action)
    activate(target, action)
    start, end = (round(v) for v in source_action.frame_range)
    chosen = start+round((end-start)*representatives.get(short, .5))
    previous_quats.clear()
    clip_angles = []
    clip_steps = []
    last_positions = None
    samples = []
    for frame in range(start, end+1):
        scene.frame_set(frame)
        bpy.context.view_layer.update()
        src_pose = {b.name: source.matrix_world @ b.matrix for b in source.pose.bones}
        dst_pose = {}
        for bone in target.data.bones:
            name = bone.name
            parent = bone.parent
            if parent:
                local_rest = parent.matrix_local.inverted() @ bone.matrix_local
                pos = dst_pose[parent.name] @ local_rest.translation
            else:
                pos = src_pose['Hips'].translation*scale+rest_delta
            if name in mapping:
                src = mapping[name]
                q = src_pose[src].to_quaternion() @ calibration[name]
                if name in chains:
                    dc, sc = chains[name]
                    local_direction = target_rest[name].to_quaternion().inverted() @ (
                        target_rest[dc].translation-target_rest[name].translation)
                    current_direction = src_pose[sc].translation-src_pose[src].translation
                    q = (q @ local_direction).rotation_difference(current_direction) @ q
            else:
                # Fixed boot toes and unweighted head markers inherit the parent.
                q = (dst_pose[parent.name] @ local_rest).to_quaternion()
            desired_world = q.to_matrix().to_4x4()
            desired_world.translation = pos
            dst_pose[name] = desired_world
            arm_pose = target_inverse @ desired_world
            kwargs = {}
            if parent:
                kwargs = {'parent_matrix': target_inverse @ dst_pose[parent.name],
                          'parent_matrix_local': parent.matrix_local}
            basis = bone.convert_local_to_pose(arm_pose, bone.matrix_local, invert=True, **kwargs)
            pb = target.pose.bones[name]
            pb.rotation_mode = 'QUATERNION'
            qlocal = basis.to_quaternion().normalized()
            if name in previous_quats:
                qlocal.make_compatible(previous_quats[name])
                clip_angles.append(math.degrees(previous_quats[name].rotation_difference(qlocal).angle))
            previous_quats[name] = qlocal.copy()
            pb.rotation_quaternion = qlocal
            pb.location = basis.translation if not parent else Vector((0, 0, 0))
            pb.scale = (1, 1, 1)
            pb.keyframe_insert('rotation_quaternion', frame=frame, group=name)
            if not parent:
                pb.keyframe_insert('location', frame=frame, group=name)
        bpy.context.view_layer.update()
        evaluated = {p.name: target.matrix_world @ p.matrix for p in target.pose.bones}
        for name, (dc, sc) in chains.items():
            a = evaluated[dc].translation-evaluated[name].translation
            b = src_pose[sc].translation-src_pose[mapping[name]].translation
            av, bv = np.asarray(a, dtype=float), np.asarray(b, dtype=float)
            all_direction_errors.append(math.degrees(math.atan2(
                float(np.linalg.norm(np.cross(av, bv))), float(np.dot(av, bv)))))
        for bone in target.data.bones:
            if bone.parent:
                length = (evaluated[bone.name].translation-evaluated[bone.parent.name].translation).length
                rest_length = (target_rest[bone.name].translation-target_rest[bone.parent.name].translation).length
                all_length_errors.append(abs(length-rest_length))
        positions = {n: list(m.translation) for n, m in evaluated.items()}
        if last_positions:
            clip_steps.extend((Vector(positions[n])-Vector(last_positions[n])).length for n in mapping)
        last_positions = positions
        if frame in {start, chosen, end}:
            samples.append({'frame': frame, 'seconds': (frame-start)/60, 'positions_blender_z_up': positions})
        if frame == chosen:
            deps = bpy.context.evaluated_depsgraph_get()
            body = target_meshes[0]
            mesh = bpy.data.meshes.new_from_object(body.evaluated_get(deps), depsgraph=deps)
            contact_poses.append((short, mesh, body.matrix_world.copy(),
                                  {n: m.translation.copy() for n, m in src_pose.items()},
                                  {n: m.translation.copy() for n, m in evaluated.items()},
                                  (frame-start)/60))
    # The input GLB was baked at 60 Hz. Avoid Blender's default Bezier overshoot.
    for layer in action.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                for curve in bag.fcurves:
                    for key in curve.keyframe_points:
                        key.interpolation = 'LINEAR'
    action.use_fake_user = True
    clips.append({'name': action.name, 'source_name': source_action.name,
                  'frames': end-start+1, 'duration_s': (end-start)/60,
                  'max_local_rotation_step_deg': max(clip_angles),
                  'max_joint_step_m_at_60hz': max(clip_steps), 'validation_samples': samples})
    print('RETARGETED', action.name, end-start+1, flush=True)

# Keep source and target actions independent in a usable authoring scene.
scene.frame_start = 0
scene.frame_end = round(max(c['duration_s'] for c in clips)*60)
target.name = 'Apex_24_Bone_Research'
for o in source_meshes:
    o.hide_render = True
    o.hide_set(True)
source.hide_set(True)
activate(target, bpy.data.actions['Research_NAV_MED_FWD'])
scene.frame_set(60)
for obj in bpy.context.selected_objects:
    obj.select_set(False)
target.hide_set(False)
target.select_set(True)
for body in target_meshes:
    body.select_set(True)
bpy.context.view_layer.objects.active = target
scene.render.fps = 60
bpy.ops.wm.save_as_mainfile(filepath=str(args.out/'Apex_Steep_Retarget_Research.blend'))
# The source actions share bone names with Apex. Blender's action compatibility
# filter otherwise exports them onto the wrong rig as eight additional clips.
# Preserve them in the authoring .blend above, exclude them from the target GLB.
source.animation_data_clear()
for action in source_actions:
    bpy.data.actions.remove(action)
bpy.ops.export_scene.gltf(filepath=str(args.out/'Apex_Steep_Retarget_Research.glb'),
                         export_format='GLB', use_selection=True,
                         export_animations=True, export_animation_mode='ACTIONS',
                         export_bake_animation=True, export_force_sampling=True,
                         export_frame_range=False, export_current_frame=False,
                         export_anim_slide_to_zero=True, export_skins=True,
                         export_all_influences=False)

report = {'source': str(args.source.resolve()), 'source_sha256': hashlib.sha256(args.source.read_bytes()).hexdigest(),
          'target': str(args.target.resolve()), 'target_sha256': hashlib.sha256(args.target.read_bytes()).hexdigest(),
          'source_bones': len(source.data.bones), 'target_bones': len(target.data.bones),
          'directly_mapped_bones': len(mapping), 'mapping_target_to_source': mapping,
          'preserved_target_leg_length_m': leg_length(target_rest), 'root_translation_scale': scale,
          'max_anatomical_direction_error_deg': max(all_direction_errors),
          'max_target_segment_length_error_m': max(all_length_errors),
          'algorithm': 'World-space rest-axis calibration, per-frame anatomical swing correction, source orientation for twist; target bind proportions preserved. Root motion scaled by leg-length ratio. Native extra neck compressed into Apex neck-head direction. Unmapped target toes/head markers inherit.',
          'limitations': ['Stored clips, not the evaluated Steep blend graph or post-physics IK.',
                         'No recovered full-body game-controlled flip/spin trajectory.',
                         'No target fingers; hand calibration is provisional and needs grip review.',
                         'No binding/pole/contact constraints or transitions in this offline proof.',
                         'Source 60 Hz is an export timebase, not a claim about Steep physics.',
                         'Small aim errors demonstrate the retarget math, not perceptual equivalence.'],
          'clips': clips}
(args.out/'retarget-validation.json').write_text(json.dumps(report, indent=2))
if args.skip_sheet:
    sys.exit(0)

# Contact sheet: each cell compares native skeletal pose (cyan) to the current
# Apex skinned mesh. Use a common three-quarter view and per-pair centering.
for obj in list(scene.objects):
    obj.hide_render = True
scene.render.engine = 'BLENDER_WORKBENCH'
scene.display.shading.light = 'STUDIO'
scene.display.shading.color_type = 'OBJECT'
scene.display.shading.show_shadows = True
scene.display.shading.show_cavity = True
scene.display.shading.background_type = 'WORLD'
scene.world = bpy.data.worlds.new('Comparison World')
scene.world.color = (.026, .033, .046)
scene.render.resolution_x = 2400
scene.render.resolution_y = 1300
scene.render.resolution_percentage = 100
turn = Matrix.Rotation(math.radians(-25), 4, 'Z')


def label(body, x, z, size=.14, color=(.85, .88, .94, 1)):
    font = bpy.data.curves.new('Label', 'FONT')
    font.body = body
    font.align_x = 'CENTER'
    font.size = size
    obj = bpy.data.objects.new('Label', font)
    scene.collection.objects.link(obj)
    obj.location = (x, -.6, z)
    obj.rotation_euler = (math.pi/2, 0, 0)
    obj.color = color


for i, (short, mesh, matrix, sp, tp, seconds) in enumerate(contact_poses):
    cx, z = (i % 4)*3.1, (1-i//4)*2.9
    ss = {n: turn @ (v*scale) for n, v in sp.items()}
    ts = {n: turn @ v for n, v in tp.items()}
    sh = ss['Hips']; th = ts['Hips']
    # Match ankle-origin height; difference in proportions remains visible.
    sz = min(ss[n].z for n in ['LeftFoot', 'RightFoot'])
    tz = min(ts[n].z for n in ['LeftFoot', 'RightFoot'])
    soff = Vector((cx-.64-sh.x, -sh.y, z-sz+.18))
    toff = Vector((cx+.64-th.x, -th.y, z-tz+.18))
    curve = bpy.data.curves.new('Native '+short, 'CURVE')
    curve.dimensions = '3D'
    curve.bevel_depth = .014
    curve.bevel_resolution = 2
    # Anatomical main chains, excluding finger/helper clutter.
    for n in set(mapping.values()) | {'Neck1'}:
        parent = source.data.bones[n].parent
        if parent and parent.name != 'Reference':
            spline = curve.splines.new('POLY')
            spline.points.add(1)
            spline.points[0].co = (*(ss[n]+soff), 1)
            spline.points[1].co = (*(ss[parent.name]+soff), 1)
    ob = bpy.data.objects.new('Native '+short, curve)
    scene.collection.objects.link(ob)
    ob.color = (.06, .65, 1, 1)
    ob = bpy.data.objects.new('Apex '+short, mesh)
    scene.collection.objects.link(ob)
    ob.matrix_world = Matrix.Translation(toff) @ turn @ matrix
    ob.color = (.83, .53, .16, 1)
    title = short.replace('AIR_TO_LAND_BACKFLIP_SPINLEFT_PANIC', 'PANIC LANDING').replace('_', ' ')
    label(title, cx, z-.16, .115)
    label(f'Native / Apex    t={seconds:.2f}s', cx, z-.36, .10, (.5, .63, .74, 1))

label('STEEP MOTION  /  APEX EXISTING 24-BONE MESH', 4.65, 5.40, .22)
label('Stored source poses retargeted at 60 Hz. Physics, ski bindings and graph transitions are not applied.', 4.65, 5.12, .12)
camdata = bpy.data.cameras.new('Comparison Camera')
cam = bpy.data.objects.new('Comparison Camera', camdata)
scene.collection.objects.link(cam)
cam.location = (4.65, -20, 2.55)
cam.rotation_euler = (math.pi/2, 0, 0)
camdata.type = 'ORTHO'
camdata.ortho_scale = 12.6
scene.camera = cam
scene.render.image_settings.file_format = 'PNG'
scene.render.filepath = str(args.out/'native-vs-apex-contact-sheet.png')
bpy.ops.render.render(write_still=True)
print(json.dumps({k: report[k] for k in ['target_bones', 'directly_mapped_bones', 'max_anatomical_direction_error_deg', 'max_target_segment_length_error_m']}))

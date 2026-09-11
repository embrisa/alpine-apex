"""Manually authored visual assessment, 9 September 2026.

The explicit scores below are reviewer judgments after inspecting the reference
sheets, final three-view renders, chronological motion sheets, and source/fitting
diagnostics. This is not a pose-scoring algorithm. Rerun only to reconstruct r1.
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
REV = ROOT / 'artifacts/pose_review/revisions/20260909-r1'
if (REV/'sealed.json').exists():
    raise SystemExit('r1 is sealed. Preserve its assessment and author a new review revision.')
U = None

def note(observation, adjustment, origin='Source motion / blending', confidence='Medium'):
    return dict(observation=observation, adjustment=adjustment, origin=origin, confidence=confidence)

neck = note('The neck is obscured by the reference collar and helmet; its separate articulation cannot be isolated.', 'Unjudgeable: establish the chest and visible gaze first; do not invent a neck angle from the collar.', 'Reference uncertainty', 'Low')
foot = note('The boot remains seated along the ski. The reference uses a different boot shape, so shell proportions are excluded.', 'Retain the binding lock. Refine Foot and ToeBase orientation only with the boot and ski together; solve any knee change upstream.', 'Equipment constraints / reference uncertainty')

templates = {}
templates['regular'] = {
 'pelvis':note('The hips sit behind the ankles; the silhouette is more folded forward than the reference ready stance.', 'Bring Hips modestly forward as a visual estimate, then redistribute the hip hinge through both UpLeg chains and Spine02. Keep boots fixed.', 'Source motion / fitting'),
 'lower_spine':note('The waist-to-chest line pitches forward more than the pictured relaxed posture.', 'Reduce the forward fold at Spine02 after settling Hips. Avoid compensating entirely through the chest.'),
 'middle_spine':note('The middle torso follows the forward fold, with less of the reference open ready posture.', 'Share a small estimated extension between Spine01 and Spine02; preserve a continuous back curve.'),
 'upper_spine':note('The chest points down while the reference opens it toward the direction of travel.', 'Open Spine slightly with the middle back; carry the shoulders forward without lifting them toward the ears.'),
 'neck':neck,
 'head':note('The helmet and gaze point more toward the near snow than in the reference.', 'After the trunk correction, lift Head toward the travel horizon; distribute any required compensation through neck. No exact angle is recoverable.', 'Source motion / trunk coupling'),
 'shoulder':note('The shoulder sits above an arm hanging near the hip rather than supporting the pictured forward carry.', 'Move Shoulder gently forward with the chest; most of the hand relocation should come from Arm and ForeArm.'),
 'upper_arm':note('The upper arm drops beside the torso; the reference brings the elbow forward.', 'Flex Arm forward, coordinated with Shoulder and ForeArm, to place the hand ahead of the waist.'),
 'forearm':note('The elbow is more open and the forearm points downward instead of forward.', 'Increase ForeArm flexion while Arm moves forward. Preserve a soft elbow rather than a locked target.'),
 'hand':note('The hand is low beside the thigh, substantially behind the reference hand position. Fine wrist twist is uncertain under the glove.', 'Move the hand through the shoulder–elbow chain first. Then orient Hand to the pole grip with a neutral wrist; do not translate the wrist alone.'),
 'thigh':note('The thigh has the recognizable shallow skiing bend, but the hip-to-knee relationship differs from the reference.', 'Tune UpLeg only after Hips; keep knee tracking toward the boot and preserve stance width.', 'Source motion / leg fitting'),
 'shin':note('The shin is comparatively upright; the reference knee advances farther over its boot.', 'Estimate a little more forward knee travel through UpLeg and Leg while preserving rigid boot attachment. Do not bend the boot to chase the image.', 'Leg fitting / equipment constraints'),
 'foot':foot,
}
templates['tuck'] = {
 'pelvis':note('The hips lower into a recognizable tuck, but remain farther back relative to the feet than the compact reference.', 'Test a modest forward Hips shift coupled to both UpLeg chains; preserve the visible compression progression.', 'Source motion / fitting'),
 'lower_spine':note('The waist hinge supplies a recognizable low aerodynamic silhouette.', 'Retain most of the hinge. Adjust only after the pelvis and forward hand target are established.'),
 'middle_spine':note('The middle back approaches the reference low line; the fold is not the main mismatch.', 'Keep the continuous low curve and avoid adding a sharp bend to reach the hands.'),
 'upper_spine':note('The chest folds low, but it is not supported by the reference narrow forward arm shape.', 'Keep the chest low while moving the arms forward. Use only small Spine compensation after the arm-chain edit.'),
 'neck':neck,
 'head':note('The helmet pitches down more than the reference forward-looking tuck.', 'Lift Head relative to the low chest, sharing the turn with neck without flattening the back.', 'Source motion / trunk coupling'),
 'shoulder':note('The shoulders feed a broad arm shape instead of the reference narrow aerodynamic carry.', 'Bring Shoulder forward and slightly inward with Arm. Avoid collapsing the collar or raising the shoulders.'),
 'upper_arm':note('The upper arm flares outward toward the knee instead of bringing the elbow in front of the chest.', 'Bring Arm inward and forward; preserve clearance from the thigh during maximum compression.'),
 'forearm':note('The forearm points down and outward instead of forming the pictured forward shelf.', 'Flex and rotate ForeArm in concert with Arm so the forearms point forward and nearly parallel.'),
 'hand':note('The hands remain separated near the outer knees rather than gathered ahead of the face/chest. Exact wrist twist is uncertain.', 'Converge both arm chains toward a shared forward carry. Then orient each Hand to its own pole; keep realistic hand separation.'),
 'thigh':note('The thighs fold substantially and communicate a tuck, though the knee/hip proportions do not exactly match.', 'Retain the basic bend; adjust UpLeg with pelvis repositioning before considering any extra compression.', 'Source motion / leg fitting'),
 'shin':note('The shins remain straighter over the boots than the deeply forward-angled reference lower legs.', 'Explore modest knee advancement within existing ankle and binding constraints; do not reproduce apparent AI boot flex literally.', 'Leg fitting / equipment constraints'),
 'foot':foot,
}
templates['preparation'] = {
 'pelvis':note('The hips compress, but the body remains higher and more seated than the very compact reference.', 'Estimate additional hip hinge and forward pelvis placement together, only within feasible leg reach. Review preparation separately from the jump impulse.', 'Blending/timing / fitting'),
 'lower_spine':note('The lower torso is noticeably more upright than the reference deep fold.', 'Fold Spine02 forward after setting Hips, sharing the curve with Spine01 rather than sharply bending the waist.', 'Blending/timing / fitting'),
 'middle_spine':note('The middle torso opens up while the reference remains tucked near horizontal.', 'Carry a deeper forward Spine01 fold through the hold, then release it smoothly during extension.', 'Blending/timing'),
 'upper_spine':note('The chest stays high and open relative to the pictured compact preparation.', 'Lower the chest through the whole spine chain while preserving space for the knees and hands.', 'Blending/timing'),
 'neck':neck,
 'head':note('The head follows the upright trunk yet looks downward; the reference keeps a forward gaze over the hands.', 'Set the folded trunk first, then maintain forward gaze through Head and neck.', 'Source motion / trunk coupling'),
 'shoulder':note('The shoulders are spread above wide arms rather than nested into a compact forward stance.', 'Bring Shoulder forward with the folded chest; couple the change to Arm instead of pinching the collar.'),
 'upper_arm':note('The upper arm angles outward; the reference elbows sit farther forward and inward.', 'Bring Arm forward and inward with enough room for the compressed knee.'),
 'forearm':note('The forearm is bent but carried sideways instead of closely forward over the knees.', 'Redirect ForeArm forward after Arm is placed; retain elbow softness through the hold.'),
 'hand':note('The hand sits at the outer hip/knee line rather than ahead of the crouched body. Fine wrist twist is uncertain.', 'Use the full arm chain to move Hand forward and inward; align the grip only after that target is reached.'),
 'thigh':note('The thigh bends into preparation but does not produce the reference tightly folded body shape.', 'Set Hips and trunk first; then increase UpLeg fold only as leg reach and boot fixation permit.', 'Blending/timing / leg fitting'),
 'shin':note('The lower leg is more vertical than the reference highly inclined shin.', 'Coordinate Leg with the hip hinge and knee-forward target; preserve the rigid boot rather than forcing the illustrated ankle shape.', 'Leg fitting / equipment constraints'),
 'foot':foot,
}
templates['carve'] = {
 'pelvis':note('The pelvis banks but sits low relative to a chest that remains quite upright; the reference has a more coherent inclined body line.', 'Reduce excess visual pelvis drop at strong bank and move Hips with the support plane. Refit both legs before compensating through the shoulders.', 'Fitting / physical support coupling'),
 'lower_spine':note('The lower spine curve is obscured by clothing and foreshortening in the front-oblique reference; a separate local angle is uncertain.', 'Unjudgeable locally. Establish Hips and the visible chest line before distributing a small correction through Spine02.', 'Reference uncertainty', 'Low'),
 'middle_spine':note('The separate middle spine curve is obscured by the jacket and front-oblique projection.', 'Unjudgeable locally. Use the side diagnostic to avoid a kink while redistributing the visible trunk adjustment.', 'Reference uncertainty', 'Low'),
 'upper_spine':note('The chest stays comparatively vertical above the legs instead of following the reference banked silhouette.', 'Couple Spine to the corrected pelvis while retaining plausible upper-body counterbalance. Do not rigidly roll the entire trunk onto the ski edge.', 'Fitting / blending'),
 'neck':neck,
 'head':note('The helmet points down; the reference looks forward through the turn.', 'After pelvis and chest are settled, raise Head toward the travel direction with gentle neck compensation.', 'Source motion / trunk coupling'),
 'shoulder':note('The shoulder line is recognizable but feeds lower, less forward arms than the reference.', 'Set the pelvis and chest first, then carry Shoulder forward without using shoulder height to disguise the body bank.'),
 'upper_arm':note('The upper arm hangs closer to the knee than the reference forward balancing arm.', 'Flex Arm forward and keep left/right balance appropriate to the actual turn, not screen-left labels.'),
 'forearm':note('The elbow is less distinctly in front of the body and the forearm hangs low.', 'Bend ForeArm toward a forward pole carry after Arm placement; preserve an open balancing shape.'),
 'hand':note('The hand is low near the outer thigh/knee rather than forward in the balancing stance. Wrist detail is uncertain.', 'Bring Hand forward through Arm and ForeArm; keep the grip neutral and inspect pole clearance through the bank.'),
 'thigh':note('The thigh flexion differs from the reference longer inclined leg line, especially near maximum bank.', 'Coordinate UpLeg with a less depressed Hips target. Differentiate outside-leg support from inside-leg flexion.', 'Fitting / equipment constraints'),
 'shin':note('The knee/shin relationship becomes more folded than the reference rather than extending along the bank.', 'Refit Leg after Hips and UpLeg; preserve knee hinge direction and boot edge alignment.', 'Leg fitting / equipment constraints'),
 'foot':note('The feet follow the edged skis, although the reference edge angle and stance projection are not metrically recoverable.', 'Retain the binding lock and correct physical turn direction. Any Foot/ToeBase refinement must follow the ski as a unit.', 'Equipment constraints / reference uncertainty'),
}
templates['takeoff'] = {
 'pelvis':note('The pelvis rises from compression, but the body remains folded forward relative to the reference extension.', 'Time the visual Hips rise and hip opening together, tied to the recorded takeoff event. Keep simulation ownership unchanged.', 'Blending/timing / fitting'),
 'lower_spine':note('The waist retains too much skiing fold while the reference opens toward an extended takeoff.', 'Release Spine02 flexion progressively with pelvis rise; avoid a separate chest snap.', 'Blending/timing'),
 'middle_spine':note('The middle back stays hunched through extension.', 'Share gradual extension through Spine01 and Spine02 during the takeoff window.', 'Blending/timing'),
 'upper_spine':note('The chest does not open as far as the reference rising torso.', 'Open Spine with the pelvis and middle back; coordinate the backward arm sweep.', 'Blending/timing'),
 'neck':neck,
 'head':note('The gaze remains down rather than ahead as the body extends.', 'Raise Head as the trunk opens, with modest neck compensation; keep the motion smooth.', 'Source motion / trunk coupling'),
 'shoulder':note('The shoulder does not lead the reference clear backward arm sweep.', 'After the trunk timing is settled, rotate Shoulder into a modest backward carry and let Arm supply the sweep.'),
 'upper_arm':note('The arm remains beside/outside the torso instead of sweeping behind it.', 'Extend Arm behind the rising torso, easing into the air carry at the end of this window.', 'Source motion / blending/timing'),
 'forearm':note('The elbow stays substantially bent; the reference arm is nearly straight behind the body.', 'Gradually reduce ForeArm flexion with the Arm sweep, retaining a soft elbow.', 'Source motion / blending/timing'),
 'hand':note('The hand remains beside the hip rather than trailing behind the extended torso. Wrist twist is uncertain.', 'Place Hand through the upstream arm sweep, then orient the grip and pole together; avoid an isolated wrist offset.'),
 'thigh':note('The thigh straightens through the jump, providing the clearest part of the reference takeoff progression.', 'Retain the extension direction. Retune UpLeg timing only after the pelvis/trunk phase has been agreed.', 'Blending/timing / leg fitting'),
 'shin':note('The lower leg straightens while the boot remains attached; its local angle is not an exact reference match.', 'Preserve the soft knee and binding lock; coordinate Leg with hip extension rather than locking the knee.', 'Leg fitting / equipment constraints'),
 'foot':foot,
}
templates['landing'] = {
 'pelvis':note('The pelvis lowers after contact, but the visible absorption becomes a seated posture rather than the reference forward compact fold.', 'For a comparable impact, combine Hips lowering with forward hip hinge and both leg chains. Check a stronger landing before changing all impact amplitudes.', 'Source motion / blending/timing'),
 'lower_spine':note('The waist opens during absorption instead of folding toward the reference knees.', 'Couple Spine02 forward hinge to pelvis compression; retain a continuous back curve.', 'Source motion / blending/timing'),
 'middle_spine':note('The middle torso stays too upright at absorption relative to the reference.', 'Bring Spine01 forward with Spine02 during compression, then release the fold smoothly.', 'Source motion / blending/timing'),
 'upper_spine':note('The chest opens while the pelvis drops, weakening the reference compact absorption silhouette.', 'Coordinate Spine with the hip hinge and forward hands. Avoid correcting only the chest after the pelvis has moved.', 'Source motion / blending/timing'),
 'neck':neck,
 'head':note('The helmet follows the changing chest and looks more down than the reference ready gaze.', 'Maintain a forward gaze through Head/neck while the torso absorbs and recovers.', 'Source motion / trunk coupling'),
 'shoulder':note('The shoulder carries the arm increasingly behind the body during absorption.', 'Retain a forward balancing Shoulder carry through compression and recovery.'),
 'upper_arm':note('The arm shifts toward the hip rather than staying forward to balance the absorbing body.', 'Flex Arm forward during absorption; ease into the ordinary ready carry during recovery.', 'Source motion / blending/timing'),
 'forearm':note('The elbow opens and the forearm drops instead of remaining forward of the body.', 'Retain a soft forward ForeArm bend through the impact episode and couple it to Arm.', 'Source motion / blending/timing'),
 'hand':note('The hand retreats toward the hip instead of remaining ahead in the reference recovery-ready position. Wrist detail is uncertain.', 'Keep Hand in front through the full arm chain. Reorient the pole grip only after shoulder/elbow placement.'),
 'thigh':note('The thigh absorbs the landing, but this moderate impact does not reach the reference very deep squat.', 'Preserve impact-dependent amplitude. Review a stronger event before adding UpLeg flexion globally; coordinate with Hips.', 'Source motion / impact timing'),
 'shin':note('The shin stays comparatively vertical and the knee advances less than the reference deep absorption.', 'Coordinate Leg with the forward hip hinge inside the binding constraints; do not force boot-shell deformation.', 'Leg fitting / equipment constraints'),
 'foot':foot,
}

specs = [
 ('regular','Regular downhill','regular','01_regular_downhill_sequence.png',['Relaxed stance','Athletic stance','Lower stance'],[20,80,150],[5,5.5,6],7,
  'The sequence becomes progressively lower, as pictured. Leg stance is recognizable; forward hand carry and gaze are the main missing features.',
  'The relaxed→athletic→lower reading is supported by the three silhouettes. The sheet has no speed or slope, so those are not accuracy targets.',
  'The inspected progression lowers gradually without a gross discontinuity. Boots stay coherent with skis. The near-static hip-level arm carry and downward gaze make the rider read less prepared. Motion judgment is moderate confidence; the 3-second fixture is not a full gameplay acceptance test.'),
 ('tuck','Tucking downhill','tuck','02_tucking_downhill_sequence.png',['Enter tuck','Deepest tuck','Partial release'],[50,106,127],[5,5.5,5.5],6.5,
  'The body reaches a low tuck and releases in the right order. The gathered forward hands that define the reference are absent.',
  'Entry→deep tuck→partial release is visibly plausible. Treat the very tight hand/pole arrangement as an artistic target with real grip clearance.',
  'Lowering and release read continuously in the inspected frames. The elbows spread as the body compresses, so torso and arms do not form a coordinated aerodynamic shape. Later pole changes deserve a full-speed eye check. The sheet cannot determine the correct duration.'),
 ('preparation','Deep tuck before jump','prepare_takeoff','03_deep_tuck_pre_jump_sequence.png',['Preparation','Maximum compression','Extension begins · partial match'],[28,46,66],[5,4.5,5],5.5,
  'A clear compression hold exists, but the maximum pose has a much more upright chest than the reference. The third pictured grounded phase has no exact counterpart.',
  'Panel 3 rises only slightly and still appears grounded. Our first visible release is already airborne. It is labeled partial evidence from the same jump, not an exact grounded phase match.',
  'The preparation is sustained and transitions into a readable rise, but the trunk opens early while the body is still compressed. Supported extension before launch is missing in this capture. Assess the pose timing and later air transition separately from jump force.'),
 ('carve_left','Left carving','carve_left','04_carving_left_sequence.png',['Initiation','Strongest bank','Release'],[60,106,148],[3.5,3,4],5,
  'The actual left turn is correctly selected. Literal resemblance is limited by opposite visible bank in the sheet and by excessive pelvis depression at peak bank.',
  'Both carving sheets lean in the same screen direction. The left sheet conflicts with this verified travel-left event. Keep correct turn semantics; discuss a mirrored/corrected artistic reference before enforcing its bank direction.',
  'The bank grows and releases in a readable order, with skis and boots coherent. The strong drop into a seated peak and upright chest weaken balance and continuity of the body line. This score is for movement, not the reference label conflict; sampled motion evidence gives moderate confidence.'),
 ('carve_right','Right carving','carve_right','05_carving_right_sequence.png',['Initiation','Strongest bank','Release'],[76,117,160],[5.5,4,5.5],5,
  'Initiation and release are recognizable. At strongest bank the pelvis drops into a deep squat instead of the reference longer inclined leg line.',
  'This sheet has the same screen-bank direction as the left sheet. Its visible bank matches this actual travel-right turn better. The illustration cannot specify exact edge angle, load or anatomical twist.',
  'The turn builds and releases, but the pelvis sinks much more than the upper body banks. Both legs become deeply folded at the peak. Improve that relationship before adding arm polish. Contact judgment is limited to the captured binding/support data and studio renders.'),
 ('takeoff','Jump takeoff','prepare_takeoff','06_jump_takeoff_sequence.png',['Compressed preparation','Extension','Airborne extension'],[65,71,78],[5.5,5.5,5],5.5,
  'The same jump supplies all three phases. Leg extension reads well, but the chest and bent arms retain the ordinary skiing shape instead of opening and sweeping back.',
  'Panel 2 looks supported in the drawing; our corresponding extension is already airborne. This phase offset is explicit. The images do not establish takeoff duration or a physically measurable launch angle.',
  'The legs extend in a clear rise, then the later air state returns to a crouch. The trunk/arm opening is weak and pole orientation changes across the air/recovery transition. Inspect the included surrounding frames at 1× and slow speed before choosing an easing adjustment.'),
 ('landing','Landing impact','landing','07_landing_impact_sequence.png',['Initial contact','Maximum absorption','Recovery'],[16,43,65],[6.5,4.5,5.5],5.5,
  'Initial contact is the strongest overall match. Maximum absorption becomes a seated, upright-chested pose; recovery returns the hands to the hips.',
  'This fixture starts 1.2 m above the v14 surface with 3 m/s downward velocity and about 18 m/s downhill motion. Reference impact severity is unknown; its deeper squat is not proof every landing needs more compression.',
  'Contact, compression and recovery occur in order. The chest opens as the pelvis drops, then folds forward again during recovery; this coordination reads less natural than a shared hip/trunk absorption. Poles swing with the changing arm carry. Moderate confidence, limited to this impact.'),
]

# Every value is an explicit visual judgment. Region order is fixed by build_review.py:
# core six, then left shoulder/arm/forearm/hand/thigh/shin/foot, then right seven.
scores = {
 'regular':[[6,5,5.5,5.5,U,4.5,6,4,3.5,3.5,7,6.5,8,6,4.5,4,4,7,6.5,8],
            [6.5,6,6,6,U,4.5,6,4,4,3.5,7,6.5,8,6,4.5,4,4,7,6.5,8],
            [6.5,7,7,6.5,U,5,6,4.5,4,3.5,6.5,6,8,6,4.5,4.5,4,6.5,6,8]],
 'tuck':[[6,6.5,6.5,6,U,4.5,5,3.5,3.5,2.5,6.5,6,8,5,4,3.5,3,6.5,6,8],
         [7,7.5,7.5,7,U,4,4.5,3,3,2.5,7,5.5,8,4.5,3,3.5,2.5,7,5.5,8],
         [6.5,7,7,6.5,U,4.5,5,3.5,3.5,2.5,6.5,6,8,5,3.5,3.5,3,6.5,6,8]],
 'preparation':[[5.5,5,5,5,U,4.5,5,4,4,3.5,6,5.5,8,5,4.5,4,4,6,5.5,8],
                [5,3.5,3.5,4,U,4.5,5,4,4,3.5,6,5,8,5,4.5,4,4,6,5,8],
                [5.5,4,4,4.5,U,4.5,5,4,4,3.5,6,5.5,7,5,4.5,4,4,6,5.5,7]],
 'carve_left':[[4,U,U,4,U,4,5,4.5,4,4,4,4,4.5,5,4,4,4,3.5,3.5,4.5],
               [2.5,U,U,3.5,U,4,4.5,4,4,3.5,3.5,3.5,4.5,4.5,3.5,3.5,3.5,2.5,3,4.5],
               [4,U,U,4.5,U,4.5,5,4.5,4,4,4.5,4.5,5,5,4.5,4,4,4,4,5]],
 'carve_right':[[6,U,U,6,U,4.5,6,5,4.5,4.5,6.5,6.5,7.5,6,5,4.5,4.5,6,6,7.5],
                [3,U,U,4.5,U,4,5,4,4,3.5,3,3.5,7,5,4,4,3.5,4,4,7],
                [6,U,U,6,U,4.5,6,5,4.5,4.5,6.5,6.5,7.5,6,5,4.5,4.5,6,6,7.5]],
 'takeoff':[[6.5,6,6,6,U,5,4.5,3.5,3,4,7,6.5,8,4.5,3,3,3.5,7,6.5,8],
            [6.5,5.5,5.5,5.5,U,5,4.5,3.5,3,4,7.5,7,8,4.5,3,3,3.5,7.5,7,8],
            [6,4.5,4.5,4.5,U,5,4.5,3.5,3,4,8,7.5,8,4.5,3,3,3.5,8,7.5,8]],
 'landing':[[7,7,7,6.5,U,5.5,6.5,6,5.5,5.5,7,6.5,8,6.5,6,6,6,7,6.5,8],
            [4.5,3.5,3.5,4,U,5,5,4,3.5,3.5,5.5,5,8,5,4.5,4,4,5.5,5,8],
            [6.5,6,6,6,U,5,5.5,4,4,3.5,7,6.5,8,5.5,4.5,4,4,7,6.5,8]],
}

reasons = {
 'regular':[
  'Recognizable skiing stance, but too much trunk fold for the relaxed reference. Hands beside the thighs and downward gaze substantially change the ready silhouette.',
  'The leg bend and forward trunk are closer to the athletic panel. Hands still sit too low/back and elbows do not project forward.',
  'The lower body and back line are the best match in this sheet. Forward forearms, hand placement and gaze remain clearly different.'],
 'tuck':[
  'Entry depth and torso lean are recognizable. The missing narrow forward arm carry prevents a close tuck match.',
  'The deepest torso fold is a strong local match. Wide elbows, separated low hands and downward gaze remain major silhouette differences; the holistic score reflects them.',
  'The partial rise follows the reference order. Hands remain at the knees rather than ahead of the chest, so releasing the tuck does not restore the intended arm shape.'],
 'preparation':[
  'The skier is preparing the same jump, but the stance is not yet as compact as the reference; arms are wide and the chest is higher.',
  'The hips and knees compress, but the chest becomes upright instead of folding close to the thighs. This is a substantial body-shape mismatch.',
  'The pose begins to rise with similar knee compression, but the chest and hands differ. This is only a conditional silhouette grade: the exact grounded phase is missing.'],
 'carve_left':[
  'A banked initiation is present, but it leans opposite the sheet at the matched front-oblique view. The low arms and downward gaze add genuine pose differences beyond that reference conflict.',
  'The deepest pelvis drop and heavily folded knees do not resemble the reference extended banked line. The opposite bank direction further lowers literal fit; do not interpret this as an input-sign defect.',
  'The body begins to rise out of the turn and is less distorted than the peak. Literal reference fit remains limited by direction ambiguity and low forward-arm reach.'],
 'carve_right':[
  'Bank direction and an athletic leg stance are recognizable. Chest-to-pelvis coordination and hands are less close than the general silhouette.',
  'At the correct strongest-bank event, the pelvis is much too low for the pictured long inclined legs. Both thighs fold into a seated shape while the chest stays upright.',
  'The rising pelvis restores a more recognizable release shape. The ready forward hand position and gaze still need attention.'],
 'takeoff':[
  'Compression and thigh fold are recognizable at the last supported frame. The reference arms are already swept back; ours remain bent beside the hips.',
  'The legs and pelvis extend in the correct part of the same jump. Chest opening and nearly straight trailing arms are missing; the game is already airborne while the illustration appears supported.',
  'Leg extension is one of the best local matches, but the chest stays hunched and elbows bent. The complete reference silhouette is therefore only moderately close.'],
 'landing':[
  'The same initial-contact event has a similar moderate leg bend, trunk lean and separated balancing arms. Hands and gaze are not exact, but this is the strongest overall match.',
  'The selected frame is the lowest pelvis in the post-contact window. It looks seated with an upright chest instead of the reference deep forward fold. Impact severity is an unresolved context difference.',
  'The body rises back into skiing with a reasonable leg stance. Hands retreat to the hips and the torso folds differently from the reference forward-ready recovery.'],
}

# The oblique camera sees the skier's RIGHT side nearest. Reconcile the initial
# near/far visual judgments with the rendered bone markers, not image-left/right.
# Carves were judged using explicitly identified anatomical inside/outside legs.
for key in ['regular','tuck','preparation','takeoff','landing']:
    scores[key] = [row[:6] + row[13:20] + row[6:13] for row in scores[key]]

diagnoses = {
 'regular':'The dominant source, blended request and final pose all carry the hands near the hips and fold the trunk forward. This points first to the source/arm carry, with smaller final fitting effects. The three diagnostic pictures are articulation comparisons; source equipment is not a gameplay contact test.',
 'tuck':'The source already lacks the reference gathered forward hands. The blended request spreads the elbow shape further; the final leg fit restores boot/skis coherently. Correct the arm carry before trying to compensate through the spine. Single dominant-clip images omit other contributors and pose history.',
 'preparation':'The dominant preparation clip is more folded than the final request. Blending/timing opens the chest and final support fitting affects the pelvis/legs. Inspect both layers before editing the source clip. Source/pre-fit equipment is illustrative, not the captured binding alignment.',
 'carve_left':'The source and pre-fit articulation are much less compressed than the final strong-bank pose. The final support/pelvis/leg fit is the leading explanation for the low seated shape. Actual negative steering is travel-left; the illustration direction conflict is reference uncertainty.',
 'carve_right':'At peak bank the source/pre-fit body is comparatively upright and extended; the final pose drops the pelvis and folds both legs substantially. Start diagnosis at the presentation support/pelvis/leg fitting rather than assuming the source clip alone causes this squat.',
 'takeoff':'The blended request and final legs show the extension. A dominant AIR sample can already be crouched; clip weight alone is not the complete pose because blends, history and fitting contribute. Review the takeoff/air transition and phase-specific arm carry together.',
 'landing':'The upright-chested seated absorption is already visible in the source and pre-fit request, so source motion and impact-phase blending are likely contributors. Final fitting changes the legs but is not the sole origin. Check severity-matched impacts before changing global absorption depth.',
}

data = dict(version=1, reviewer='codex',
 limitations='Visual judgments for frozen production animation on the actual default v14 support surface, under studio lighting. Physics 23, 120 Hz simulation and 60 FPS pose capture. No race session exists. The distant mountain and snow geometry are omitted from the studio pictures; contact is established by captured simulation/support data, not a visible floor. Source/pre-fit pictures are articulation diagnostics. Motion grades are moderate-confidence judgments from chronological rendered frames and surrounding sequence inspection, not user playtest or performance acceptance. Uniform camera framing preserves body bank and ski alignment; the AI camera and body proportions are unknown. Corrections are qualitative estimates; measured values describe the game only. Fine wrist twist, neck joints and obscured spine segments are not reconstructed from pixels.',
 priorities=[
  dict(title='Set a feasible pelvis and leg relationship at strong bank',reason='The largest structural mismatch is the seated peak carve. A better Hips/support fit should improve the entire silhouette before arm polish.',bones=['Hips','LeftUpLeg','LeftLeg','RightUpLeg','RightLeg','Spine02','Spine01','Spine'],dependency='Agree on the actual left/right turn and reference direction first. Preserve solver bank and binding constraints; retune presentation fitting, then recheck knees, torso and both directions.'),
  dict(title='Author phase-specific forward hand carry',reason='Low hands recur in ordinary skiing, tuck, preparation and recovery. Forward elbows and hands would make several sequences read closer at once.',bones=['LeftShoulder','LeftArm','LeftForeArm','LeftHand','RightShoulder','RightArm','RightForeArm','RightHand'],dependency='Use the agreed pelvis/chest as the frame of reference. Move the arm chains first, then wrists/poles; keep tuck clearance and avoid one universal hand target.'),
  dict(title='Coordinate takeoff trunk opening with the backward arm sweep',reason='Leg extension is already readable. Opening the trunk and softly straightening the trailing arms should complete the takeoff silhouette.',bones=['Hips','Spine02','Spine01','Spine','LeftArm','LeftForeArm','RightArm','RightForeArm'],dependency='Review the absent supported extension and transition into AIR before adjusting curves. Keep jump force and simulation timing unchanged in any presentation-only follow-up.'),
  dict(title='Keep gaze ahead through changing trunk angles',reason='Downward helmet orientation is a repeated mismatch and reduces the impression of an alert skier.',bones=['Spine','neck','Head'],dependency='Set the trunk first; then distribute the visible gaze correction without trying to infer a hidden exact neck angle.'),
  dict(title='Coordinate impact absorption, then restore ready arms',reason='The chest opening while the pelvis sinks makes this landing look seated. A shared hip/trunk fold and forward hands should improve recovery.',bones=['Hips','Spine02','Spine01','Spine','LeftUpLeg','RightUpLeg','LeftArm','RightArm'],dependency='Capture a stronger, severity-matched impact before deciding whether deeper compression is needed globally. Recheck contact and recovery at normal speed.'),
 ],sequences=[],partTemplates=templates,poses=[])

for sid,title,scenario,reference,titles,frames,overall,motion,summary,warning,motion_reason in specs:
    ids=[f'{sid}_{i+1:02}' for i in range(3)]
    data['sequences'].append(dict(id=sid,title=title,scenario=scenario,referenceFile=reference,poses=ids,summary=summary,referenceWarning=warning,motion=dict(score=motion,reason=motion_reason,confidence='Medium')))
    for i,frame in enumerate(frames):
        partial=(sid=='preparation' and i==2) or (sid=='takeoff' and i==1)
        ranges={'regular':[(0,50),(51,119),(120,179)],'tuck':[(20,74),(75,111),(112,155)],'preparation':[(24,35),(36,65),(66,73)],'carve_left':[(30,82),(83,127),(128,165)],'carve_right':[(40,92),(93,137),(138,179)],'takeoff':[(52,65),(66,74),(75,91)],'landing':[(12,23),(24,49),(50,85)]}
        a,b=ranges[sid][i]
        if sid=='takeoff' or sid=='preparation':
            event='Jump/support loss at tick 133 (1.108 s)'
            match='Same jump; frame selected inside the '+titles[i].lower()+' phase.'
        elif sid=='landing':
            event='First contact at tick 34 (0.283 s)'
            match='Same landing; '+('first supported frame' if i==0 else 'minimum pelvis height after contact' if i==1 else 'recovery after absorption')+'.'
        elif sid.startswith('carve'):
            event='Peak absolute physical bank at frame '+str(frames[1])
            match='Verified travel-'+('left' if sid=='carve_left' else 'right')+' event; '+('initiation on the rising bank' if i==0 else 'strongest bank in the captured turn' if i==1 else 'release after the peak')+'.'
        elif sid=='tuck':
            event='Full tuck command from 0.900 s; release begins 1.650 s'
            match=['Rising tuck input and lowering body before the minimum.','Lowest pelvis in the full-tuck/early-release window; visual response lags the input.','Pelvis rising after maximum compression while tuck input releases.'][i]
        else:
            event='Progressive stance command starts at 0.500 s'
            match='Chronological '+titles[i].lower()+' during one uninterrupted downhill segment; the reference has no timed event marker.'
        if partial:
            match+=' PARTIAL MATCH: this game frame is already airborne; the depicted supported extension has no exact captured counterpart.'
        equipment=dict(Skis='Captured skis retain their actual terrain/flight pitch, separation and bank. No equipment dimensions were scored against the differently proportioned AI skis.',Bindings='Boots remain attached in the final three-view evidence. Fine binding mechanisms are not comparable at this reference resolution.',Poles='The grips follow the hands, but the shafts trail more horizontally or rotate differently from the reference. Solve arm carry first, then inspect Hand rotation and the pole attachment through the whole window.')
        if sid=='takeoff':equipment['Poles']='The reference has a clear backward/downward sweep with nearly straight arms. Our poles trail from bent elbows near the hips and change pitch during the air transition. Correct Arm/ForeArm before the pole attachment.'
        if sid.startswith('carve'):equipment['Poles']='One pole rises or trails high during initiation and the peak carry is low/wide, unlike the reference downward balancing poles. Check both wrist-to-pole orientations after the pelvis/arm edit; no pole planting is established by the sheet.'
        p=dict(id=ids[i],sequence=sid,scenario=scenario,panel=i+1,frame=frame,title=titles[i],confidence='Low' if sid=='carve_left' or partial else 'Medium',matchStatus='partial' if partial else 'matched',matchNote=match,eventLabel=event,overall=dict(score=overall[i],reason=reasons[sid][i]),equipment=equipment,diagnosis=diagnoses[sid],scores=scores[sid][i],template='carve' if sid.startswith('carve') else sid,adjustmentRange=f'Frames {a}–{b} ({(a+1)/60:.3f}–{(b+1)/60:.3f} s); blend into adjacent frames',partOverrides={})
        # Phase-specific observations keep a good regional match distinct from the
        # common correction pattern. Equal bilateral grades are intentional where
        # the same visible defect is present; anatomical side is never screen side.
        ov=p['partOverrides']
        if sid=='regular' and i==2:
            for r in ['lower_spine','middle_spine']:
                ov[r]=dict(observation='The lower-stance forward back line is relatively close to this third reference panel.',adjustment='Retain most of this fold; make only small coupled changes after Hips and forward arms are established.')
        if sid=='tuck' and i==1:
            ov['pelvis']=dict(observation='The deepest hip position produces a convincing compact tuck; fore-aft balance is less close than overall depth.',adjustment='Retain most of the vertical compression. Test a small forward Hips adjustment only with both fixed-boot leg chains.')
        if sid=='preparation' and i==1:
            ov['pelvis']=dict(observation='This is the lowest pelvis in the supported preparation window, yet the upright chest prevents the reference compact fold.')
        if sid.startswith('carve'):
            outside='right' if sid=='carve_left' else 'left'
            inside='left' if sid=='carve_left' else 'right'
            ov[outside+'_thigh']=dict(observation=('The anatomical outside thigh is deeply folded at peak bank; the reference outside leg reads much longer.' if i==1 else 'The outside thigh begins to support the bank, but its extension and hip alignment differ from the sheet.'))
            ov[inside+'_thigh']=dict(observation=('The inside thigh folds nearly into a seated cross-body shape at the peak.' if i==1 else 'The inside thigh flexes into the turn; the reference leg relationship is only partly reproduced.'))
            if i==1:ov['pelvis']=dict(observation='At maximum physical bank the pelvis drops into a pronounced squat beneath a relatively upright chest. This is the main structural mismatch.')
            if sid=='carve_left':
                for r in ['pelvis','left_thigh','right_thigh','left_shin','right_shin','left_foot','right_foot']:
                    entry=ov.setdefault(r,{})
                    base=entry.get('observation',templates['carve'].get(r,templates['carve'].get(r.removeprefix('left_').removeprefix('right_'),{}))['observation'] if r not in ov or 'observation' not in ov[r] else ov[r]['observation'])
                    entry['observation']=base+' Literal fit also includes the opposite visible bank; the left-sheet direction is uncertain.'
                    entry['confidence']='Low'
                    entry['adjustment']=templates['carve'].get(r,templates['carve'].get(r.removeprefix('left_').removeprefix('right_'),{}))['adjustment']+' Do not reverse the verified travel-left turn to match this ambiguous sheet.'
        if sid=='takeoff':
            if i==0:
                for r in ['lower_spine','middle_spine','upper_spine']:
                    ov[r]=dict(observation='The compressed trunk is reasonably recognizable in this preparation panel; the large difference is the missing trailing arm silhouette.',adjustment='Retain most of the preparation fold, then open the spine progressively through frames 66–91.')
            if i==2:
                for side in ['left','right']:ov[side+'_thigh']=dict(observation='The almost extended thigh is a close local match to the airborne reference.',adjustment='Retain this extension direction and soft knee; only retime it if the agreed trunk/arm phase requires it.')
        if sid=='landing' and i==0:
            for r in ['pelvis','lower_spine','middle_spine','upper_spine']:
                ov[r]=dict(observation='The initial-contact hip/trunk shape is comparatively close to this moderate-flexion panel.',adjustment='Retain most of the contact pose; coordinate the following absorption rather than adding compression before contact.')
            for side in ['left','right']:
                ov[side+'_upper_arm']=dict(observation='The arm is separated for balance and carried more forward here than during later recovery.',adjustment='Retain the useful forward carry through absorption, then ease toward an agreed ready position.')
                ov[side+'_hand']=dict(observation='The hand is more forward at contact and reasonably close in broad placement; exact wrist twist is uncertain.',adjustment='Keep this general carry through the impact episode; refine the grip only after upstream elbow placement.')
        if sid=='landing' and i==2:
            ov['pelvis']=dict(observation='The pelvis has risen out of absorption into a recognizable skiing height.',adjustment='Retain the recovery rise; settle fore-aft placement with the forward arm carry.')
            for r in ['lower_spine','middle_spine','upper_spine']:ov[r]=dict(observation='The torso folds forward again during recovery, broadly recognizable but less open than the reference ready posture.',adjustment='Ease out of the agreed absorption fold into a shared ready curve; avoid an independent chest reversal.')
        data['poses'].append(p)

(REV/'assessment-source.json').write_text(json.dumps(data,indent=2,ensure_ascii=False),encoding='utf-8')
print('Authored assessment: 21 poses, 420 explicit regional judgments, 7 motion judgments')

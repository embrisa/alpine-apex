"""Manually authored R2 visual judgments; these are not computed pose scores.

Reviewed the nine three-view stills, chronological contact sheets, final-bone
reconstruction and source/requested/final diagnostics. The capture hash prevents
these judgments from silently being applied to different animation evidence.
"""
import hashlib, json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
REV=ROOT/'artifacts/pose_review/revisions/20260909-r2'
assert not (REV/'sealed.json').exists(), 'Preserve the sealed assessment.'
assert hashlib.sha256((REV/'capture/manifest.json').read_bytes()).hexdigest() == 'a7151a7dec563ae542daa2eec9cf368f277f71b9cca5a89413001a9fc9ac3ff8', 'New capture requires a new visual assessment.'
old=json.loads((REV.parent/'20260909-r1/assessment-source.json').read_text(encoding='utf-8-sig'))

def note(observation, adjustment, origin='Reviewed articulation / final fitting', confidence='Medium'):
    return dict(observation=observation,adjustment=adjustment,origin=origin,confidence=confidence)

neck=note('The neck is obscured by the collar and helmet. As the user clarified, the visible collar/model shape is not an animation defect.', 'Unjudgeable separately. Retain the visible chest-to-gaze relationship; do not grade collar proportions.', 'Reference uncertainty / user clarification', 'Low')
foot=note('The boot remains rigid and seated in its binding. Ski centers are closer together than the earlier review, and the knees track above them.', 'Retain the 0.38 m support spacing and rigid boot frame. Any further knee refinement belongs upstream of the boot.', 'Physical equipment / reviewed stance')
regular={
 'pelvis':note('The pelvis supports a soft, ready knee bend instead of leaving the chest folded over straighter legs. Fore-aft placement is closer to the requested stance.', 'Retain this support-aware height/fore-aft relationship; preserve the gradual lowering between the three panels.'),
 'lower_spine':note('The waist now has a restrained hinge and a continuous rise into the chest, removing the excessive forward fold.', 'Retain the modest hip hinge and small lower-spine contribution.'),
 'middle_spine':note('The middle back follows the opened trunk without a visible sharp kink.', 'Preserve the shared curve as the stance lowers; avoid concentrating the change at one link.'),
 'upper_spine':note('The chest opens toward travel and supports the forward arm carry. This addresses the user’s strongest regular-stance criticism.', 'Retain the open chest while allowing the lower stance to incline the trunk modestly.'),
 'neck':neck,
 'head':note('The helmet and face look ahead of the skier rather than into the near snow. The exact gaze angle remains approximate.', 'Retain the forward gaze across the changing trunk angle.'),
 'shoulder':note('The shoulders follow the raised chest and support both arms without an obvious shrug.', 'Keep the clavicles relaxed and let the elbow chain provide most of the forward reach.'),
 'upper_arm':note('The upper arm carries the elbow forward instead of hanging beside the hip.', 'Preserve this ready carry and its transition into compact preparation.'),
 'forearm':note('The bent elbow places the forearm and hand ahead of the waist. The left/right carry reads as one coordinated posture.', 'Keep a soft elbow; avoid independently moving the wrist to chase the reference.'),
 'hand':note('The glove stays connected to the forearm and grips its pole ahead of the body. Fine glove/finger shape is excluded; the visible wrist remains slightly more flexed than the drawn reference.', 'Keep the connected grip. Any further refinement should reduce visible wrist bend together with the elbow position.'),
 'thigh':note('The hip-to-knee bend now supports the progressively lower stance, with less lateral spread.', 'Retain the coupled pelvis/leg solve and the narrower support width.'),
 'shin':note('The knee advances over the boot while the boot shell stays rigid. The reference suggests slightly more advancement in some panels.', 'Keep the measured cuff envelope; do not reproduce apparent AI boot bending.'),
 'foot':foot,
}
tuck={
 'pelvis':note('The hips lower into a recognizable compact tuck and stay farther forward than the earlier rearward seated shape.', 'Retain the lowering/release curve and feasible relationship to both bindings.'),
 'lower_spine':note('The hip hinge and lower back now form a coherent forward curve into the tuck.', 'Preserve the distributed hinge instead of folding one short spinal link.'),
 'middle_spine':note('The middle back continues the low silhouette without a sudden angular break.', 'Keep this continuity through the deepest hold and partial release.'),
 'upper_spine':note('The upper chest stays open enough to support the raised gaze and gathered arms. It is somewhat higher than the most flattened drawing.', 'Retain the user-requested chest opening; any extra aerodynamic lowering should remain distributed through the trunk.'),
 'neck':neck,
 'head':note('The visible gaze remains ahead through the low tuck, with space above the hands.', 'Retain the head compensation as the torso inclines; exclude helmet proportions.'),
 'shoulder':note('The shoulder line supports the compact carry without collapsing into the collar.', 'Preserve the relaxed shoulder height and coordinate it with the upper arm.'),
 'upper_arm':note('The elbows are closer to the body and below the forward hands. The arm envelope remains a little wider than the illustration.', 'Keep thigh clearance; any further narrowing needs a simultaneous forearm/grip adjustment.'),
 'forearm':note('The flexed forearms now lead toward a shared forward carry instead of pointing down beside the knees.', 'Retain the connected elbow hinge and the smooth gathering/release.'),
 'hand':note('The hands gather ahead of the chest during the deep hold and remain connected to the wrists. Palm roll and the wider outward pole angle are the main remaining reference differences.', 'Retain the stable authored grip. Further pole narrowing should be judged together with visible wrist bend and actual clothing clearance.'),
 'thigh':note('The thigh folds into clear compression, with a tighter knee angle and a narrower stance than the rejected pose.', 'Preserve the feasible compression and let the pelvis lead the release.'),
 'shin':note('Both knees advance toward the toe line while the boots remain rigid. The forward travel is deliberately less extreme than the AI boot/shin silhouette.', 'Retain the cuff limit and refine only through the connected leg chain.'),
 'foot':foot,
}
preparation=dict(tuck)
preparation.update({
 'pelvis':note('The pelvis lowers further than the ordinary tuck, producing the requested tight pre-jump compression instead of the previous open leg angle.', 'Retain this deeper preparation height and the existing physical jump timing.'),
 'lower_spine':note('The waist and lumbar region now form a continuous arch above the compressed pelvis.', 'Keep the curve distributed across the hip hinge and lumbar links.'),
 'middle_spine':note('The middle spine follows the forward preparation curve instead of opening upright during the hold.', 'Retain the held curve until the real departure begins.'),
 'upper_spine':note('The chest remains folded into preparation while leaving room for the lifted face and forward hands.', 'Preserve this balance between compression and visible forward gaze.'),
 'thigh':note('The thighs fold much closer to the shins and the pelvis sits low, clearly expressing stored preparation.', 'Retain the narrower knee tracking and rigid boot attachments. Do not change launch force to match an untimed drawing.'),
})

scores={
 'regular_01':[8,8.5,8.5,8.5,None,8, 8,8,8,7.5,8,7.5,8.5, 8,8,8,7.5,8,7.5,8.5],
 'regular_02':[8,8,8,8.5,None,8, 8,8,8,7.5,8,8,8.5, 8,8,8,7.5,8,8,8.5],
 'regular_03':[8,8,8,8,None,8, 8,8,8,7.5,8,8,8.5, 8,8,8,7.5,8,8,8.5],
 'tuck_01':[8,8,8,8,None,8, 8,7.5,7,6.5,8,7.5,8.5, 8,7.5,7,6.5,8,7.5,8.5],
 'tuck_02':[8,8.5,8,8,None,8, 8,7.5,7.5,7,8.5,8,8.5, 8,7.5,7.5,7,8.5,8,8.5],
 'tuck_03':[8,8,8,8,None,8, 8,7.5,7.5,7,8,8,8.5, 8,7.5,7.5,7,8,8,8.5],
 'preparation_01':[8,8,8,8,None,8, 8,7.5,7.5,7,8,8,8.5, 8,7.5,7.5,7,8,8,8.5],
 'preparation_02':[8.5,8.5,8.5,8,None,8, 8,7.5,7.5,7,8.5,8,8.5, 8,7.5,7.5,7,8.5,8,8.5],
 'preparation_03':[8.5,8.5,8,8,None,7.5, 8,7.5,7.5,7,8.5,8,8.5, 8,7.5,7.5,7,8.5,8,8.5],
}
reasons={
 'regular_01':(8.5,'The open chest, forward gaze, bent elbows and narrower knee/boot alignment now form a convincing relaxed ready stance. Minor wrist and model-proportion differences remain.'),
 'regular_02':(8,'The athletic stance keeps the chest open while lowering through the legs. Both hands are carried ahead and remain connected. The drawing has slightly stronger compression and softer wrist presentation.'),
 'regular_03':(8,'The lower stance is coherent from pelvis through chest and gaze. Knee advancement and reduced width address the user’s leg critique; arm placement is substantially closer, with some wrist refinement still possible.'),
 'tuck_01':(8,'The entry has coordinated hip/knee flexion, an open chest and a forward-looking head. Hands are moving into the compact carry but are still more separated and the poles lower than the drawn entry; this is the lowest-scoring hand phase.'),
 'tuck_02':(8,'The low hip hinge, advanced knees, closer forward hands and raised gaze make the deep tuck convincing. The poles clear the body, though their outward spread and palm roll remain more pronounced than the reference.'),
 'tuck_03':(8,'The skier releases into a coherent intermediate crouch while maintaining forward hands and gaze. The wrists remain connected; pole roll/spread is still the most visible local difference from the drawing.'),
 'preparation_01':(8,'The entry now lowers through both legs and folds the trunk coherently while keeping the face forward. It is slightly less compressed than the untimed reference panel, with the deeper hold immediately following.'),
 'preparation_02':(8.5,'The low pelvis, tightly folded legs, continuous back curve and gathered forward hands communicate a clear deep preparation. Rigid boots and forward gaze are retained. The wider pole carry prevents a closer match.'),
 'preparation_03':(8,'Conditional visible-pose grade: compression, back curve, knee advancement and forward hand placement are much closer. This is the first airborne frame, so it does not prove a matching grounded extension. The last supported frame is retained separately.'),
}
summaries={
 'regular':'Opened chest and gaze, forward ready arms and a narrower knee/boot stance replace the earlier folded, low-hand silhouette.',
 'tuck':'The tuck now combines a forward hip hinge, modest knee advancement, gathered hands and stable pole clearance. Pole spread remains wider than the drawings.',
 'preparation':'The lower pelvis and tighter leg fold now support a continuous back curve and forward gaze. The hands gather and the shafts clear the body; the original support-loss timing caveat remains.',
}
motion={
 'regular':'The inspected chronological render lowers progressively with connected limbs and stable forward carry. The remaining motion is restrained; this short fixture is not a hardware or controller-feel acceptance test.',
 'tuck':'The rendered entry, deep hold and release form a continuous progression. Fixed grip anchors remove the abrupt roll-solution changes found in development. The wider pole sweep remains visible, especially during release.',
 'preparation':'Grade covers preparation through the first departure frame (0–66): compression is sustained and the gaze/arms follow the trunk without a gross snap. The remainder of the video is flight/recovery context, not a new grade for those animations. The reference cannot establish exact launch timing.',
}
sequences=[]
for s in old['sequences'][:3]:
    item={k:s[k] for k in ['id','title','scenario','referenceFile','poses','referenceWarning']}
    item.update(summary=summaries[s['id']],motion={'score':8,'reason':motion[s['id']],'confidence':'Medium'})
    sequences.append(item)
poses=[]
for source in old['poses'][:9]:
    p={k:source[k] for k in ['id','sequence','scenario','panel','frame','title','confidence','matchStatus','matchNote','eventLabel','template','adjustmentRange']}
    score,reason=reasons[p['id']]
    p.update(overall={'score':score,'reason':reason},scores=scores[p['id']],partOverrides={},
        equipment={'Skis':'Actual support spacing is 0.38 m; the rendered skis retain physical support and terrain pitch.',
                   'Bindings':'Rigid boots remain seated in their bindings. The review does not bend a boot to match a drawing.',
                   'Poles':'Handles remain in the glove grip frame. Compact shafts clear the hip/thigh envelopes; their outward spread remains wider than the AI reference.'},
        diagnosis='The original dominant clip is shown separately from the reviewed blended request and final constrained skeleton. Downhill posture targets act before the tick tracker; rigid support and the final writer retain their authority.')
    if p['id']=='tuck_01':
        for side in ['left','right']:
            p['partOverrides'][side+'_hand']={'observation':'The hand is forward and connected, but this early entry is still too separated and has not reached the reference’s gathered grip. The full hold is substantially closer.', 'adjustment':'If refining entry further, bring the grip phase forward while keeping the full arm chain, wrist envelope and clearance continuous.'}
    if p['id']=='preparation_03':
        p['lastSupportedFrame']=65
        p['matchNote']='Partial match: frame 66 is already airborne after the physical jump at tick 133. The visible compressed body can be compared, but grounded extension cannot. Frame 65 is retained in frames/prepare_takeoff/0065.jpg and diagnosis as the last supported pose.'
    poses.append(p)
data={
 'limitations':'These are the implementing Codex reviewer’s new visual judgments, not new user grades or an independent external certification. The three requested sequences have nine sampled poses. Overall grades are holistic; regional grades are separate. AI camera, proportions and timing are approximate. Hidden neck shape and fine glove/finger modeling are excluded. Wider pole spread is the main remaining visible mismatch. Preparation frame 66 is a conditional airborne match; frame 65 preserves the last support. Automated constraints, these visual grades, 4K performance and user skiing acceptance are separate.',
 'sourceMessage':'R2: corrected downhill posture, current rig and physics/model 25. Exact final bones, all chronological frames and 119 source inputs are frozen with this revision. R1 and its original scores remain available; your R2 scores start independently.',
 'partTemplates':{'regular':regular,'tuck':tuck,'preparation':preparation},
 'sequences':sequences,'poses':poses,
 'priorities':[
  {'title':'Keep the improved chest, gaze and compressed support relationship','reason':'These changes address the largest shared silhouette problems in the supplied critiques.','bones':['Hips','Spine02','Spine01','Spine','Head','LeftUpLeg','RightUpLeg'],'dependency':'Retain the coherent curve, forward knees and rigid boot attachment during further refinement.'},
  {'title':'Refine pole spread and early hand gathering','reason':'The hands are connected and the poles clear the body, but the drawn compact carry is narrower. Entry hands are the lowest-scoring region at 6.5.','bones':['LeftArm','LeftForeArm','LeftHand','RightArm','RightForeArm','RightHand'],'dependency':'Any further narrowing should be reviewed in all three cameras and through the full transition, preserving wrist limits and actual shaft clearance.'},
  {'title':'Keep user re-grading independent','reason':'The supplied user scores describe r1. They cannot certify the new poses automatically.','bones':[],'dependency':'Use the blank R2 feedback fields and the full-speed videos for the next user assessment. Neck model appearance remains unjudgeable.'},
 ]}
(REV/'assessment-source.json').write_text(json.dumps(data,indent=2,ensure_ascii=False),encoding='utf-8')
print('Authored R2: 9 overall judgments, 180 regional entries (9 unjudgeable necks), 3 motion judgments.')

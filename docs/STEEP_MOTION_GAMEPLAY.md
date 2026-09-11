# Full-curve skiing in gameplay

**Gameplay correction:** The user rejected the initial full-curve result as rubbery. [Connected articulation](SKIER_ANATOMY.md) supersedes its joint-fitting and visual acceptance claims, including forced grab contact.

Implemented on 2026-09-08; current articulation corrections are linked above.
The normal `main.tscn` character now uses recovered, retargeted skeletal curves.
F8 switches between full motion and the retained procedural presentation, with
a continuous blend. The Interface settings also contain the comparison switch
and Safety/Mute grab selection. These are presentation controls; the existing
grab input, release-to-jump input, racing and physics controls are unchanged.

## Runtime ownership

`skier_full_motion.gd` samples 33 clips at their verified 60 Hz timebase, blending
parent-relative quaternions in consistent Apex model axes. The compressed
`assets/animation/steep_ski_motion.res` contains 2,473,209 bytes of motion and
provenance-linked structure, with no duplicate mesh or textures. It is preloaded
as an ordinary Godot Resource, so exporting the game includes its dependency.
The unchanged body GLB still supplies its 24 weighted joints.

Offline decomposition removes the mean calibrated sole rotation and ankle
translation. Runtime uses support-relative pelvis placement and local body shape;
it never reapplies the source world bank, heading, root translation or a supposed
complete flip. The physical actor frame owns world motion and spin/flip rotation.
Both boot transforms come from the interpolated physical skis at exactly the
same render fraction as the body and fixed-tick motion snapshots.

Navigation weights use speed, steering, physical bank/slip, tuck and support.
Preparation follows held input; ordinary release and natural support loss use
ordinary takeoff/flight clips. Prediction controls opening before contact;
actual grouped landing episodes select and advance recovery. Switch navigation,
ordinary switch hops/landings, spin/flip shapes, skid, collision recovery and two
grabs have explicit mappings. These mappings are Apex gameplay choices, not a
claim to have recovered Steep's evaluated graph weights or timing.

Clips keep continuous curves. Repeated motion overlaps the end and beginning;
one-shot motion holds its endpoint. Grab release continues the current clip while
its weight decays instead of rewinding it. Hand-to-ski fitting ramps in over the
source's approach phase, avoiding an early pull from a still-raised source hand.
The style is latched for the current grab and through brief re-grab taps;
changing the selector takes effect on the next settled grab entry.
A fixed-tick second-order controller
retains posture angular velocity across changed targets, with 12 rad/s and
160 rad/s² limits on relative joint motion. These limits never apply to the
solver's actor rotation. Pausing collapses interpolation; restarting clears state.
Once the procedural comparison settles, the full sampler incurs no playback cost.
Lightweight event clocks continue so re-enabling motion selects the current
flight/landing phase rather than replaying an event that occurred while disabled.

## Contact and fitting

The production character remains the single skeleton writer. Its stages are:

1. Interpolate physical root/equipment and the sampled body shape.
2. Blend from the procedural comparison, then fit the shared pelvis to the two
   independent binding frames and existing reach/cuff envelope.
3. Close legs on their reach circles, retaining as much of each native knee plane
   as the cuff permits. Minimal-swing limb fitting retains source axial twist.
4. Preserve articulated shoulders/spine, softly bound extreme neck angles, and
   fit the grab hand to the ski with connected torso/shoulder accommodation.
5. Keep poles in the fixed glove grip, recheck clearance, then write the skeleton.

The corrected bank constraint measures lateral tilt without an `atan2` branch
at a horizontal chest. That branch previously produced a 42.6 cm fitted arm jump
in an initial integration test; it is not present in the final pose solve.
Diagnostics retain requested and fitted landmarks, pelvis displacement, knee
corrections, grab reach/shoulder corrections, clearance retention and stage cost.

The cross-ski Mute grab needs substantially more torso correction than Safety
because the physical skis cannot move to match the source pose. Its correction
is bounded at 80 degrees and blended through entry/release. Fixed glove fingers
still limit close-up grasp deformation; additional unweighted joints would not
fix that. No rig expansion was justified by the inspected ordinary skiing poses.

## Physics preservation and assistance

The only physical behavior change is an optional ground-assistance handover fix:
manual input immediately stops automatic targeting, while the previously applied
yaw rate decays at the existing 12 degrees/s² limit. Player steering remains
independently active. Air assistance retains the existing acceleration-limited
controller, manual ownership, prediction expiry behavior and absence of automatic
trick completion. Both assistance options remain off by default.

Physics identity is **v19** to separate changed optional-assistance behavior;
replay layout stays **v4**. The v18 slope-matched landing absorption, reserve
damage/recovery, steering improvements, jump impulse and release behavior remain.
The 120 Hz solver, terrain authority and all source/equipment assets are retained.
Saved entry hashes verify that only `landing_assist.gd` and the version constant
in `ski_simulation.gd` changed among core/config/replay/body-asset sources.

## Reproduction

The original eight-clip research proof and native resources remain unchanged.
Expanded decoding requires the existing local decoder and its native inventory:

```powershell
python scripts/art/recover_ski_motion.py --decoder 'C:\Users\hp\Documents\Codex\Reports\Steep-Animations-2026-09-08\decoder'
# Run engine work through scripts/run_guarded.ps1 to share validation slots.
./scripts/run_guarded.ps1 -FilePath 'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe' -Arguments @('--background','--factory-startup','--python','scripts/art/retarget_ski_research.py','--','--source','artifacts/steep_motion_gameplay/exports/Steep_ID01_Female_Core_Motion.glb','--out','artifacts/steep_motion_gameplay/retarget','--skip-sheet') -Label motion-retarget
./scripts/run_guarded.ps1 -FilePath "$PWD/godotw.ps1" -Arguments @('--headless','--script','scripts/art/export_ski_motion.gd') -Label motion-export
./scripts/run_guarded.ps1 -FilePath "$PWD/godotw.ps1" -Arguments @('--headless','--script','tests/steep_motion_suite.gd') -Label motion-suite
./scripts/run_guarded.ps1 -FilePath "$PWD/godotw.ps1" -Arguments @('--script','tests/steep_motion_gameplay.gd') -Label motion-gameplay -CollectGpuMemory
./scripts/run_guarded.ps1 -FilePath "$PWD/godotw.ps1" -Arguments @('--script','tests/steep_motion_gameplay.gd','--','--procedural') -Label motion-procedural -CollectGpuMemory
./scripts/run_guarded.ps1 -FilePath "$PWD/godotw.ps1" -Arguments @('--script','tests/steep_motion_gameplay.gd','--','--timing','--procedural') -Label motion-timing-procedural -CollectGpuMemory
./scripts/run_guarded.ps1 -FilePath "$PWD/godotw.ps1" -Arguments @('--script','tests/steep_motion_gameplay.gd','--','--timing') -Label motion-timing-full -CollectGpuMemory
python scripts/steep_motion_evidence.py --encode
```

`scripts/measure_steep_motion.ps1` runs the entire visual A/B pair; add `-Timing`
for the 4K pair. Invoke it through the same guard. It verifies runtime code,
shader, material and motion resource hashes throughout both variants and saves
the source manifest. `scripts/test_steep_motion_final.ps1` similarly runs the
repeat-export check and final focused regression batch under one guarded slot.
Optional fitting diagrams use `scripts/plot_steep_motion.py` with Matplotlib and
Pillow; this project has those dependencies isolated in `.tools/motion-plots`.

`--timing` runs a separate screenshot-free 3840×2160, High, 75% FSR2, 120 FPS
workload. `--case=NAME` selects a single native fixture in a separate output
folder. Flip inspection cameras follow the rotating physical actor so tight side
shots include the entire body. Every native fixture loads `main.tscn` and the current v13
mountain, advances actual skiing physics/animation and renders the production
character. The natural-departure fixture searches for a supported start that
leaves the actual mountain without a jump request or an airborne teleport.
All runs explicitly exclude personal-best eligibility.

## Acceptance

The first full-curve fit was rejected as rubbery despite numerical length and
attachment checks. [Connected articulation](SKIER_ANATOMY.md) supersedes its
visual acceptance and forced-grab fitting claims. Review continuous carve,
reversal, deep tuck, switch, flight, grab/release and crash motion after changes.

Old source snapshots, paired clips and timing reports have been deleted. Retained
runtime assets, authoring inputs and regression fixtures remain in source
folders; regenerate exploratory exports before running tools that consume them.

Headless motion tests, rendered inspection, hardware timing and human skiing
acceptance are separate. Shared-GPU measurements from the original integration
do not establish current full-mountain performance. Use [validation](VALIDATION.md)
for current identity, workload and acceptance boundaries.

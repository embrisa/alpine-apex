# Cascadeur R9: deeper carving support

The user requested **“i think we could do even 17 cm at deepest point”** after
authorizing **“Include soft-snow sinking and leg motion.”** R9 increases the
optional R8 pressure-support response. The strong-turn fixture now reaches
**16.94 cm between boot world-Y coordinates**, versus **13.17 cm with R8**.
R7's hand source is retained. This is a physical contact experiment with fitted
leg motion; it contains no new Cascadeur leg clip or AI result.

Double-click **Play Cascadeur Deep Carving.cmd** in the project folder for the
normal mountain. **F9** switches between R9 sinking and current contacts without
pressure sinking; both modes retain R7 hands. Enter/controller A drops in,
A/D/left stick carves, and C changes camera. Runs are unranked. For a smaller
fixture, run `pwsh -NoProfile -File "Play Cascadeur Deep Carving.ps1" -QuickSlope`.
Normal project startup does not enable this experiment.

[R8/R9 video comparison](http://127.0.0.1:8769/comparisons/cascadeur-20260911-r9/review.html)
compares the previous and deeper pressure profiles. Its left side is R8;
the live F9 off mode instead uses current contacts without either profile.

## Change and measured height

R9 inherits the R8 trial simulation, increasing its pressure-support depth cap
from 0.12 to **0.177 m** and its completed-penetration response multiplier from
1 to **1.4**. Sinking/release rates remain 0.30/0.22 m/s. Snow depth and material
still constrain support, and existing bank crushing spends the same available
loose-snow depth first. Firm/very thin snow does not receive a forced foot-height
offset. The 120 Hz solver owns contact; existing leg fitting and the single final
skeleton writer follow the physical ski transforms. Contact queries remain pure.

Both comparison sides use base model **28**, identical starting setup and inputs,
and the same R7 hand source. They are separate simulations whose physical motion
can differ. The fixture is a 14-degree plane with 22 cm snow, initially 18 m/s,
120 warmup ticks, and six four-second sequences sampled at 30 FPS.

| Right-turn measurement | R8 | R9 |
|---|---:|---:|
| Frame 54, absolute boot world-Y gap | 12.65 cm | 16.70 cm |
| Maximum during strong-turn frames 54–75 | 13.17 cm | **16.94 cm** |
| Maximum anywhere in this sequence | 15.70 cm | 19.12 cm |

Boot positions use each captured rendered ski transform multiplied by the real
`Equipment.BOOT_ORIGIN = (0, .017, -.15)`. World-Y difference includes slope,
fore/aft position and ski orientation. **17 cm is an approximate deep-carve
target, not a hard cap on world-Y separation.** Later in this fixture those
other contributions produce 19.12 cm. Contact sink depth is a separate measure.
The first R9 profile capped sinking at 0.17 m and reached about 16.3 cm during the
strong turn; revision 02 supplies the final 0.177 m calibration.

## Verification and acceptance

- Final checks passed: **28 R8 contact**, **28 R9 contact**, **56 standard physics**
  and **170 runtime** checks. Contact checks cover bounded depth/rate, repeatable
  turns, pure sampling, exact disabled equivalence, thin/firm snow, nonnegative
  load, jumps/landing/reset, F9 release and the shared bank/pressure depth budget.
- All six sequences retain 121 grounded frames per side, with no crashes.
  Final fitted geometry passes existing cuff, segment and attachment limits:
  maximum binding error below 0.020 mm, fixed-grip error below 0.005 mm.
- All 726 frames per side have full-character triptychs and detail triptychs.
  Author inspection covered every chronological front frame, matched right-turn
  frame 62 full/detail views (including overhead), tuck-transition frame 45,
  and the newly flagged left-turn 63 / reversal 27 full/detail views.
  The extra ski separation is visible; the strongest bank still reads as a long
  inclined stance. This is not a preferred-style or continuous-motion grade.
- **Both clothing audits fail.** R8 has the existing `tuck_turn` frames 44–45
  intersections, ten ray hits per frame across both poles. R9 retains these and
  adds two affected frames: `steering_left` 63 (side 1, one ray hit) and
  `carve_reversal` 27 (side 0, two ray hits), at 0.84–0.90 m from the grip.
  Full/detail images were inspected; occlusion and close pole/trouser proximity
  make the small added contacts hard to judge visually. The audit findings are
  retained, not dismissed. This trial meets the requested height target but
  is **not cleared for production visual acceptance**. A later adoption pass
  needs a bounded pole-clearance correction and a fresh frozen comparison.
- Rendered **laboratory** startup passed with manual input, R7 hands, pressure
  support, F9 off/on and restart checked. The smoke run exited intentionally.
  The launcher defaults to the normal mountain, but no R9 full-mountain descent,
  controller acceptance, independent review or rendered-FPS result is claimed.

The captures freeze 105 source files per variant. A concurrent change to
`skier_full_motion.gd` subsequently changed steering-clip direction selection.
It is preserved in the live project. The saved comparison uses the captured
presentation source; current gameplay can therefore differ in its upper-body
and transition details. The pressure-support profile and boot-coordinate
calibration are unchanged. Snapshot integrity and live-source drift are recorded
separately; do not describe the frozen pictures as identical to every later build.

## Evidence and continuation

Implementation: `tests/cascadeur_r9_playtest/`, using the shared R8 harness.
Recipes and source manifest: `art_source/animation/cascadeur_carving_20260911_r9/`.
Frozen final evidence: `cascadeur-20260911-r9-02-before` and `-after` beneath
`artifacts/pose_review/revisions/`; comparison beneath
`artifacts/pose_review/comparisons/cascadeur-20260911-r9/`.
Revision 01 is a superseded calibration attempt, not final visual acceptance.
R8's existing sealed evidence is preserved.

The next decision is whether the stronger separation and altered bank recovery
feel better while skiing. User preference, adopting pressure support in normal
gameplay, and adopting Cascadeur remain separate decisions.

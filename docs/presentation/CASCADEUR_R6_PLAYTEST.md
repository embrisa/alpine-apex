# Try Cascadeur R6 in game

Double-click **scripts/launchers/Play Cascadeur R6.cmd** in the project folder. This opens the normal
default v15 mountain with the R6 grounded sequence enabled in a separate playable
scene. Normal launch still uses the production animations. The scene remains a
playtest when restarted or when its mountain is reloaded, and its runs are unranked.

- **Enter / A** drops in from the summit. Ski normally with keyboard or controller.
  **W / Up / left stick forward** tucks
  and starts the two-second ready → compression → recovery sequence. Release and
  tuck again to replay it after it finishes.
- **F9** switches between R6 and production motion, with a short blend.
- **F10** replays the R6 sequence while grounded. At the summit it waits for skiing.
- **C / right shoulder button** switches the camera. Use chase view to see the rider;
  mouse or right stick looks around.
- **R / Y** restarts; **Esc / Start** pauses. The comparison buttons are also
  available with the mouse while paused or at the summit.

The overlay tells you which animation is active. F8 is the game's separate
full-skeleton/procedural comparison; leave it on for R6. Other movement controls
and physics are the normal game. Jumps, landings and turn-specific source clips
remain production motion. The reviewed R6 asset is a short grounded sequence,
not a complete replacement animation library.

For a faster small-slope launch:

```powershell
./'scripts/launchers/Play Cascadeur R6.ps1' -QuickSlope
```

The playtest uses the same source import convention and inherited fitting as the
[R6 evaluation](CASCADEUR_WORKFLOW_EVALUATION_R6.md). The live phase policy is new:
a tuck-entry edge or F10 starts the two-second clip; afterwards its ready endpoint
holds. Forward navigation source substitution fades over 0.25 seconds when toggled.
The existing posture corrections still apply, so the difference may be subtle
while travelling straight. This playtest does not implement the proposed source
posture-ownership experiment.

Implementation lives in `tests/cascadeur_r6_playtest/`. The normal `main.tscn`,
production presentation scripts, solver, library and sealed R6 assets are unchanged.
The source GLB is checked against its reviewed SHA-256 before import. The test-only
game subclass disables recording/eligibility after every restart; it inherits
the ordinary keyboard/controller and camera paths. The diagnostic stage-copying
code from R6 is not executed on every gameplay tick.

Validation: the rendered lab smoke ran 300 physics ticks, imported R6, exercised
F9/F10, verified unranked restart and saved `artifacts/cascadeur_r6_live_smoke/`.
The focused motion test passed 480 ticks of unchanged solver state and verified
playback, production-source restoration, replay, pause and reset. All 56 physics
and 170 runtime checks passed; logs are under
`artifacts/guarded/cascadeur-r6-live-regression/`.
The normal mountain reached the summit with manual input enabled, the pinned R6
asset loaded and the session unranked. Its rendered startup screenshot was inspected:
the comparison controls are readable and leave the skiing HUD/footer clear.
Startup evidence and the validation receipt are under
`artifacts/cascadeur_r6_live_playtest/`. These concurrent runs are not a performance
measurement. Controller feel and your visual judgment
remain the purpose of this playtest, not an automated acceptance claim.

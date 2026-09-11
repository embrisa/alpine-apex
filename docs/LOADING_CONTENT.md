# Loading content and interface feedback

Maintained for AA-20260911-163058-interface-overhaul. Content is drawn from the
current production code, inspected 2026-09-11. Recheck these facts when input
bindings or skiing behavior changes. No external ski history, attributed photo
locations, or unsupported trivia is included.

## Tips and provenance

[`loading_content.gd`](../scripts/ui/loading_content.gd) owns seven tips.
[`loading_overlay.gd`](../scripts/ui/loading_overlay.gd) reads the active family
from `get_tree().get_meta("interface_device", "keyboard")`. The parent menu
navigator owns that metadata. Recognized values are `keyboard`, `playstation`,
`xbox`, and `gamepad`; unknown values use keyboard wording. Changing devices
updates the current binding immediately, without starting another loading job or
waiting for the next tip. Generic gamepad wording names physical controls rather
than guessing printed button labels.

| Tip | Production evidence | Device wording and limits |
| --- | --- | --- |
| Release to hop while supported; holding longer does not add jump power | [`input_router.gd`](../scripts/core/input_router.gd), `_init` maps `jump`; `sample` sets `jump` on release. [`rider_input.gd`](../scripts/core/rider_input.gd), `jump_held` is presentation readiness only. [`ski_simulation.gd`](../scripts/core/ski_simulation.gd), supported takeoff adds `takeoff_frame.y * tuning.jump_impulse`. | Space / R2 / RT / right trigger. No charge-strength claim. The simulation also has a short input buffer; the tip describes ordinary supported use. |
| Hold to brake | Input router `_init`, `brake` maps S/Down and `JOY_AXIS_TRIGGER_LEFT`; simulation braking friction uses `intent.brake`. | S or Down Arrow / L2 / LT / left trigger. |
| Forward requests tuck; sustained steering opens the stance | Input router `_init`, `tuck` maps W/Up and negative left-stick Y. Simulation `effective_tuck`, `tuck_steering_time`, correction and grace windows control the response. | W or Up Arrow / left stick forward. Short small corrections are intentionally not described as cancelling tuck. |
| Forward/backward flips in the air | Input router `_init` maps I/K to flip pitch; `sample` requires airborne neutral stick before direct-stick pitch is armed. `cancel_air_input` clears that gate. | I / K on keyboard; center the left stick in the air, then forward/back on controllers. Optional left-shoulder trick modifier remains supported but is not required by this tip. |
| Tuck reduces drag; gravity supplies downhill acceleration | Simulation uses `effective_tuck` in aerodynamic drag; the downhill-acceleration block explicitly excludes a tuck-powered boost. | Same text for every device. |
| Air rotation changes landing orientation, not flight path | [`air_rotation.gd`](../scripts/core/air_rotation.gd) owns quaternion/angular state and never writes linear state. Simulation advances translation separately. | Same text for every device; this does not promise that landing outcomes are unchanged. |
| Change riding camera | Input router `_init`, `camera_mode` maps C and `JOY_BUTTON_RIGHT_SHOULDER`; [`main.gd`](../scripts/main.gd) routes `camera_mode`. | C / R1 / RB / right shoulder button. Explicitly says riding camera, since menu shoulders navigate categories. |

The old promotional tips, loading eyebrow and “Up next / your descent” copy are
removed. `alpine_art.gd` no longer stores slogan captions. Loading displays only a
photo index (“Photo 01 / 09”), without invented subjects or locations. Images,
photo framing and the separate existing wind ambience are retained. Other menu
copy belongs to the parent integration.

## Timing, motion and truthful state

- A tip lasts eight seconds; normal transitions crossfade for 250 ms. Stage
  changes do not restart that timer. There is no minimum loading delay.
- Known work counts determine stage percentage. Unknown work remains
  indeterminate. Elapsed and estimated remaining time retain their explicit
  labels; estimates are not a completion promise.
- Cancellation remains cooperative. The message says it is waiting for the
  current work to stop rather than promising an interruptible “tile” for every
  workload. The owner still decides when to finish or show cancelled-startup
  Retry/Quit controls.
- A real job error is displayed verbatim and hides the progress pulse. Finishing
  a previously completed job does not overwrite its recorded error. No retry is
  automatically started, and the loading overlay does not take over job ownership.
- Enabling reduced motion immediately settles an in-progress tip fade, hides
  outgoing text and snow, freezes photograph animation, and centers the unknown
  progress marker. Audio envelopes remain audio behavior, independent of motion.

## Feedback service contract

[`interface_feedback.gd`](../scripts/ui/interface_feedback.gd) synthesizes six
22,050 Hz, mono 16-bit streams once in `_ready`. Source PCM is bounded below
64 KiB in total. Three players are allocated once: navigation, adjustment, and
actions/results. There are no playback queues, loops or per-event synthesis.

| Canonical ID | Supported aliases | Sound intent | Repeat interval |
| --- | --- | --- | --- |
| `hover` | `navigation`, `focus` | Short high note | 90 ms |
| `press` | `activate` | Rising two-note action | 65 ms |
| `back` | — | Falling two-note action | 65 ms |
| `adjust` | — | Quiet short interval | 70 ms |
| `success` | `ready` | Rising three-note resolution | 180 ms |
| `error` | — | Two separated lower notes | 180 ms |

All cues use related sine/soft-harmonic timbre with smooth attacks and decays.
Soft events have at least 30 ms spacing from the previous accepted event; actions
have at least 30 ms spacing from the previous accepted action. An action may
immediately replace a same-frame focus cue. Actions clear obsolete voices and
suppress soft repeats for 100 ms. A rejected action inside the shared action
window also clears old voices. Duplicate events inside the same cue's repeat
interval are dropped. Accepted events replace their slot, so rapid changes never
build a backlog of sound. Unknown IDs return false and do not produce a fallback
activation sound.

`play(id)` returns whether the request was dispatched. Existing callers can
ignore the result. `cue_played(id, slot)` reports dispatch, not hardware delivery.
Headless runs execute the same admission/stream-selection path silently.
`cancel_sounds()` lets the integrating navigator clear feedback when a context
is discarded. Disabling the service, muting, or setting UI volume to zero stops
all players and releases their streams immediately. A nonzero volume change
updates existing player gains. The service does not alter a shared audio bus,
skiing volume or the wind player. Loading wind retains its own player and
`loading_ambience` preference, and continues to respect UI volume/mute.

`reveal(control)` retains the existing 160 ms opacity-only reveal. It does not
disable controls or change hit testing, geometry, visibility or focus. A new
reveal settles the previous reveal. Hiding/freeing its control, explicitly
calling `cancel_reveal(control)` or `cancel_transitions()`, and turning reduced
motion on all cancel obsolete tweens and restore immediate full opacity.
Signal hooks and weak references do not retain disposed controls. Parent-owned
spatial/background transitions must still consume the same reduced-motion
preference in their own code.

## Validation handoff

The parent must run the standalone suite through the normal validation guard:

```powershell
./godotw --headless --script tests/interface_feedback_suite.gd
```

The suite does not instantiate the main scene or generate a mountain. It checks
actual generated PCM for bounded duration, non-silence, headroom, endpoints,
sample discontinuities, DC offset, uniqueness and determinism; drives the
production feedback admission/dispatch path with rapid mixed and held inputs;
checks live mute/volume behavior and transition disposal; exercises immediate
device handoff, truthful stage progress, cancellation, failure preservation and
synchronous loading finish; and compares stated bindings with the production
router's InputMap events.

It exports the actual six production source streams to ignored
`artifacts/interface_feedback/{hover,press,back,adjust,success,error}.wav` plus
`report.json`. These WAVs precede per-cue gain and UI volume: auditioning them at
raw unity volume is not the runtime mix. No generated capture is checked in.

Implementation handoff status: source review and `git diff --check` only. No
Godot/Blender execution was performed by this subagent while the parent was
integrating concurrent files. The suite and WAV export have not yet run.
Synthetic PCM metrics do **not** establish actual listening, absence of audible
voice-stealing artifacts, device output, rendered layout, transition feel,
controller acceptance or gameplay performance. The parent should inspect
loading at the supported aspect ratios and listen to isolated and rapid cues
against loading wind and live game audio before recording those acceptances.

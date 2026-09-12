# Presentation comfort review

This is the bounded review/checklist for
[AA-20260911-153904](../backlog/tasks/AA-20260911-153904-presentation-comfort-review.md).
Preparation completed on 2026-09-12; player aesthetics, controller feel and
listening remain unaccepted. Camera/HUD behavior belongs to
[Presentation](PRESENTATION.md), posture/fitting to [Animation](ANIMATION.md),
snow/weather to [Rendering](RENDERING.md), and the mix to [Audio](AUDIO.md).

## Evidence and limits

The current production baseline is `d2d19b9da8aab79b3f74892dc1ae135ec00e9507`;
this work adds a capture harness and documentation only. Custom Godot
4.7.2 `ed1daf0bf`, Forward+/DX12 on RX 9070, model 28, laboratory seed 849205174,
High graphics, native 1280x720, Connected camera defaults, clear/day and HUD
backgrounds off. This is the explicit laboratory, **not the generator-15
Standard mountain**. No earlier missing capture is counted as current evidence.

The final run produced 690 consecutive frames at a fixed 30 Hz presentation
clock over the unchanged 120 Hz solver: 20 seconds/2,400 ticks of riding and
three seconds of paused UI. Setup was 22.219 seconds, including a 15-frame
settling wait. Each primary riding sample starts at the same 65 km/h Speed Lab
launch and stops after six seconds. Captures were inspected in complete ordered
contact sheets, with full-size checks of representative pose/UI/first-person frames. This is
frame-sequence author review, not a human real-time comfort assessment.

Local evidence: `artifacts/presentation_comfort_20260912/` contains `final/`
(all frames and `review.json`), `final_chronology/`, a silent 23-second
`review.mp4`, `summary.json`, engine hashes and source inventory. The final
receipt checks ten relevant source hashes before/after capture. The broader
inventory was collected alongside the initial run; its harness hash predates
the final fixture correction. Runtime sources/assets remained unchanged.
Guard receipts are in `artifacts/guarded/presentation-comfort-final-20260912/`.
Retain the final evidence for pending human review; captures are ignored, local
files, not dependencies shipped with the game.

| Coverage | Final frames / movie time | Observations and remaining gaps |
|---|---|---|
| Chase: upright, tuck, turn, return, release | 0–179 / 0–6 s | Body stays in frame; local snow/tracks remain visible. Entry compresses, then settles higher. Six seconds at 59–65 km/h does not cover steep/forest/high-speed framing. |
| Pause → settings → Back → resume | 180–239 / 6–8 s | Menu camera changes viewpoint; settings fit the scrolling 720p shell. Back returns to the paused Tools page; resume restores riding instruments. Actions invoke production methods, not a tested hardware navigation sequence. |
| Same menu cycle with reduced motion | 240–299 / 8–10 s | The real Reduce interface motion checkbox is on; pause camera holds one transform across all 15 pause frames, versus 15 transforms normally. Loading, low-reserve warning and lightning reduction are not exercised here. |
| Riding view switches | 300–329 / 10–11 s | Production camera-mode handler switches to first person and back without a black frame in this sequence. Each new view is observed for only half a second; held-look rearming and physical button feel remain open. |
| First-person riding, same input schedule | 330–509 / 11–17 s | Near snow passes continuously beneath the view; crest/horizon move through the turn without visible terrain penetration. A shallow lab section cannot establish route readability over real drops. |
| Chase with camera motion effects off | 510–689 / 17–23 s | Rest FoV stays 55°, versus 57.91–58.30° in the matched normal clip. All 180 sampled physical positions match. This is separate from interface reduced motion; the combined/first-person effects-off matrix is a gap. |

The 3,980 harness assertions passed, including repeated image size, isolation,
footer/instrument visibility and no-crash checks. All 600 riding frames have a
hidden controls footer and visible speed/reserve instruments. Paused settings
leave solver position/tick fixed. This establishes observable state, not rapid
HUD comprehension. Frames retain diagnostic lab/PB labels, but the session is
unranked and preference writes/hardware vibration are disabled throughout.
No listening was performed; audio is muted. The fixed capture clock, readback
and encoding provide **no FPS, latency or display-delivery result**.

## Observed issues to take into the playtest

- **HUD contrast:** white speed/time numerals and small pale labels compete with
  bright snow (frames 30, 59 and 420). They are visible, but a quick glance may
  be harder than the visibility assertions suggest. Test existing background,
  opacity and scale options before proposing a design change; preserve the
  adopted backgrounds-off default and rejection of heavy outlines.
- **Tuck/leg silhouette:** frame 30 shows a strongly asymmetric ski/leg shape
  during entry; by frame 59 the skis/legs read more evenly. Support-relative hip
  height changes from .411 to .494 m while effective tuck rises .845→.995.
  Settled initial/returned tuck is close: frames 59/149 are .494/.490 m and
  67.8°/67.9° chest pitch. This is an entry observation, not proof that the
  [fixed tuck defect](VALIDATION.md#tuck-consistency) returned. Close side/front
  knee/cuff review and swept pole/clothing clearance are not established.
  Existing animation clearance findings remain open.
- **Snow and transition preference:** bright flecks are conspicuous across the
  near snow, and pause/resume produces a distinct viewpoint/brightness change.
  Neither is a demonstrated structural failure. Assess visual distraction at
  ordinary playback speed on the actual display. The full-mountain snow-detail
  boundary, dense forest, storms/night, falls/landings and long-session comfort
  were not sampled.

## Controller and listening checklist

Use the existing [player/controller task](../backlog/tasks/AA-20260911-153906-player-and-controller-acceptance.md)
to record results. Start with 15–30-second unranked riding samples, ending after
the requested event/recovery. Extend only for a named repetition/fatigue question.
Record build/commit, mountain/face/seed, camera preset, display mode/resolution,
controller model/connection, output device, OS/game volume and changed settings.
Save short input clips before pausing via the
[recording workflow](VALIDATION.md#player-recordings-and-short-scenarios);
that recorder does not preserve menu interactions or audio.

1. In chase, enter/hold tuck, steer both ways, return to tuck and release. Repeat
   in first person on a slope with a crest. Report body continuity, knee/boot
   appearance, near-snow distraction and how early the route can be read.
2. Switch view while moving; look left/right/up/down, release and recenter.
   Compare camera motion effects on/off, then Reduce interface motion on/off
   separately. Note jolts, loss of orientation or preferred settings, rather
   than giving an undifferentiated comfort pass.
3. With the controller, pause → Settings → Camera/Interface & HUD → Back → resume.
   Check focus, shoulder-category changes, scroll visibility, held-stick
   neutralization and accidental steering/jumps on resume. Verify the footer
   disappears and glance-read speed/reserve against sunlit and shadowed snow.
4. Listen to upright/tucked wind at similar speeds. Compare Original/Procedural
   wind with F7, then riding modes separately. Check hiss/buffeting, stereo
   direction and whether tuck audibly reduces rush without hiding ski contact.
5. Sample carve/skid, one small hop/landing and one controlled impact. Check
   contact onset, metal/pole ticks, repetitive rattles, impact harshness,
   vibration onset/recovery and whether wind masks useful events. Avoid scoring
   an unheard or untriggered cue.
6. Check voice/breathing against wind/contact, UI focus/adjust/Back sounds, and
   mute (M), pause/resume and retry for clicks or stale sounds. In a separate
   storm sample, check delayed thunder with lightning Reduced/Off and after
   pausing. A longer listening session is needed to judge repetition/fatigue.

For each item record **accepted / issue / not tested**, the exact condition,
timestamp/clip, severity, and preferred setting. Do not infer listening from
waveforms or physical-controller acceptance from simulated events.

## Reproduce the bounded capture

Choose a fresh output and guard label. The harness refuses headless rendering
or an existing destination, invokes the ordinary solver with bounded inputs,
checks isolation, and exits at its frame limit. It does not author a race or
modify a personal camera profile.

```powershell
./scripts/run_guarded.ps1 -FilePath ./godotw.ps1 -Arguments @('--fixed-fps','30','--script','tests/presentation_comfort_review.gd','--','--output=artifacts/presentation_comfort/new-run') -Label comfort-new-run -TimeoutSeconds 300
```

No new worker idea was added: HUD readability, posture preference and listening
need the existing player checklist first; tuck and raised-ski track work already
have recorded owners. This review does not dispatch or implement those follow-ups.

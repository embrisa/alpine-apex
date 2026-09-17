---
id: "AA-20260911-232811-taller-distant-finish-beam"
title: "Raise the finish beam and improve long-distance visibility"
status: done
priority: P2
depends_on: []
created: "2026-09-11T23:28:11Z"
updated: "2026-09-17T02:29:27Z"
source_thread: "01a092cb-8276-7610-94d6-c817b99b24ed"
---

# Raise the finish beam and improve long-distance visibility


## Outcome

The user requests: "The beam at the finish line has to go higher up in the sky
and be visible from afar." Make the finish a conspicuous skyward landmark from
the race start and distant skiable approaches, including when a ridge hides the
gate but leaves the upper shaft exposed.

## Agreed decisions and scope

- Increase the finish beam's visible height substantially and tune distant
  readability. Exact height, width and opacity are implementation tuning choices
  judged in rendered views; a roughly 2 km height is a starting experiment, not
  an approved final measurement.
- Retain the current central amber translucent finish style, ground anchor and
  near-camera fade. Keep the start appearance stable when separating shared
  geometry/material parameters. No unrelated marker redesign or floating labels.
- Preserve natural terrain occlusion and weather integration. An exposed upper
  shaft should remain useful at distance; full terrain blockage or severe storm
  obscuration does not require an always-visible overlay or global fog changes.
- This is presentation work. Preserve gates/collision, crossing/timing, solver,
  input, shared terrain authority, race identities, records and replay behavior.

## Acceptance and completion

Completed in Dev84 with the remaining current near/far cost measurement. The
beam rendering and navigation model remain the implementation delivered in
`259b50b0`; this closure changes only a selective producer, guides and records.
The user-authorized backlog completion resumes the previously deferred timing.

- [x] Finish geometry is 2,000 m with 1,600–2,000 m fade; start stays 800 m.
  Independent resources/bounds/style checks pass in the current 20-check suite.
- [x] Distant/near/ridge/weather/quality and lifecycle review completed in the
  linked functional milestone. Its500 m amber pair used the fully gate-valid
  anchor at 499.493561 m, preserving ordinary Connected 60 km/h framing. Broader
  historical matrices are not repeated or relabelled as current captures.
- [x] Current 4K matched near and 2 km images reviewed. The tall shaft projects
  above the ridge where the old beam is hidden. Natural terrain occlusion remains;
  clear/day contrast is pale and ordinary subjective usefulness remains human review.
- [x] Capture-free near 800→2,000 m frame time4.0971→4.0906 ms,
  244.07→244.46FPS; GPU 3.6756→3.6740 ms. Far 4.8639→4.8570 ms,
  205.60→205.89FPS; GPU 4.4294→4.4296 ms. These tiny differences establish no
  measurable penalty in the samples, not a performance improvement.
- [x] Shared race/lifecycle behavior: current race68/competitive54 checks from
  Dev83 and current navigation 63 pass; unchanged beam ownership is preserved.
- [x] One 15-second sample per case after warmup: actual 4K High/Auto 75
  FSR 4.1.1,FG/GI off,clear/day, uncapped,RX9070/DX12. All89 timing checks pass,
  no focus loss or captures in measured intervals. Frame SD 0.23–0.26 ms and
  GPU SD about 0.04 ms; p95 and all per-case statistics are retained. Stationary
  scene FPS is not active skiing, dense-route or sustained full-descent FPS.
- [x] Validation guide/skill, concise task records, metadata capture, whitespace,
  backlog and scoped development-note checks accompany commit/push.

Detailed commands, individual values, camera limitations and rejected fixture
receipts: `artifacts/beacon_cost_20260917/REVIEW.md`. Final visual fixture93 checks,
ten images; compact regression 83 checks. No production code/assets were changed
or new optimization idea proposed. Human visual/navigation/controller acceptance
is unperformed and remains a separate follow-up, not a completion gate.

[Earlier functional acceptance](AA-20260912-132147-finish-beam-navigation-acceptance.md)
records the broader historical review. Dev84 delivery is the commit containing
`changes/297ea491da9d4ef3adb59cfd1bd2562b.json` and this completion record.

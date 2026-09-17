---
id: "AA-20260911-232936-session-navigation-beams"
title: "Place session-only navigation beams on the mountain map"
status: done
priority: P2
depends_on: ["AA-20260911-232811-taller-distant-finish-beam"]
created: "2026-09-11T23:29:36Z"
updated: "2026-09-17T02:29:27Z"
source_thread: "01a092cb-8276-7610-94d6-c817b99b24ed"
---

# Place session-only navigation beams on the mountain map


## Outcome

The user wants to "place marker beams on the map so it can help them navigate
down a line." Let the player survey the mountain, place several visual landmarks
along a chosen descent, and return to skiing with those beams visible in the
world. The user explicitly chose "Keep only for the current session" rather
than saving markers for each mountain.

## Agreed decisions and scope

- Personal markers are session-only and never written to saves, race definitions,
  share codes, recordings or records. Keep them while retrying, returning to the
  summit, switching races or free skiing on the same loaded mountain. Clear them
  when switching/replacing the mountain or ending the application session. A
  same-mountain scene rebuild for a retry must not accidentally clear the list.
- Support multiple markers, with add, select, move, remove, clear-all and a
  show/hide control. Use a bounded maximum of 32 as an implementation default;
  display the limit when reached and never silently discard older markers.
- Use the existing rendered overhead survey as the map, reachable through an
  explicit Map / Navigation entry from summit and pause menus without creating
  or saving a race. Markers appear in this map and in the skiing world.
- Make personal beams visually distinguishable from lime start and amber finish
  markers, with map selection/numbering so players can identify their points.
  Exact color and height are renderer tuning choices. Preserve natural occlusion,
  translucency, weather integration and close-range readability. Avoid adding
  floating world text as a substitute for visible beams.
- Markers are optional visual landmarks. Crossing them adds no splits or gates,
  triggers no teleport, changes no eligibility/timing and never steers the rider.
  Keep placed markers until edited/cleared; no automatic disappearance on passing.
  No route solver, drawn ground racing line, new minimap, sharing or persistence.
- Keyboard/mouse supports direct placement and map pan/zoom. Provide deliberate
  controller reticle placement in this navigation tool as well as controller menu
  actions. Keep race endpoint picking outside this change. Respect focus scopes
  so menu actions cannot place markers, pan the map or move the skier by accident.

## Acceptance and completion

Completed in Dev84 with the remaining current near/far cost measurement. The
beam rendering and navigation model remain the implementation delivered in
`259b50b0`; this closure changes only a selective producer, guides and records.
The user-authorized backlog completion resumes the previously deferred timing.

- [x] Session-only state, mouse/controller input ownership, limit 32, edits,
  toggle, retry/rebuild and mountain reset: current compact navigation 63 checks
  pass. Native reticle/menu/chronology/Reduced Motion coverage in the linked
  functional milestone passed 207 checks with 30 reviewed beam/navigation images.
- [x] Five ordered landmarks survived 1,800 ordinary-input ticks/15 s in that
  historical chronology; current stationary costs do not repeat that ride.
  No marker persistence, simulation, race timing or input ownership changed here.
- [x] Current 4K near and 2 km 0/5/32 captures reviewed. Purple shafts remain
  distinct from amber finish; near clusters overlap and distant shafts are pale.
  Exact placed counts are retained; ordinary frustum/terrain occlusion remains.
- [x] Capture-free near 0/5/32 frame time4.0674/4.0989/4.1939 ms,
  245.86/243.97/238.44FPS; GPU 3.6528/3.6788/3.7636 ms.
  Far 4.8644/4.8650/4.8874 ms,205.58/205.55/204.61FPS;
  GPU 4.4340/4.4345/4.4389 ms. Maximum near increment is 0.1265 ms frame and
  0.1109 ms GPU. The far 32-marker increment is 0.0230 ms frame. This bounded optional
  feature cost is accepted; noise-sized differences are not optimization gains.
- [x] The finish dependency is complete; current geometry 20 and shared race68/
  competitive54 checks pass. Human physical-controller comfort remains separate.
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

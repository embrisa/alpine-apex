# Future social play and competition

Decision date: 2026-09-09. Status: architectural direction and future options;
online features are not implemented or scheduled by this document.

## Direction

Give players reasons to return through skiing mastery, route discovery, friend
rivalry and shared challenges. Candidate hooks include mountain medals, cosmetic
recognition, friend ghosts, weekly cups and eventually skiing together. The core
skiing must remain rewarding on its own and available offline.

Movement remains local and immediately responsive. Dedicated servers that own
live movement are a distant option, to revisit if sales, player demand and an
ongoing operating budget justify them. Earlier social features may use Steam
services or a small results backend while movement continues to run locally.
Running a results service and running every player's live ski simulation are
separate decisions.

Apply the boundaries below during ordinary feature work. This direction does not
require a networking framework, placeholder services, a persistence rewrite or a
determinism project now. Physics quality and the existing PC performance target
continue to take priority.

## Boundaries to preserve during current work

| Area | Guidance for decisions made now |
|---|---|
| Movement | Preserve the Node-independent 120 Hz ski model, explicit rider intent and authoritative 4 m terrain/contact surface. Keep render time, camera look and service calls outside physical authority. |
| Player ownership | Keep control of the local camera, UI, audio and input distinguishable from the simulated rider. When extending rider presentation, avoid requiring every visible rider to own local controls; ghosts and eventual spectators benefit from the same separation. No multi-rider framework is required now. |
| Race identity | Version changes that affect comparability: physical mountain and obstacle data, start/finish and route rules, movement/equipment model, tuning, and gameplay-affecting assists or conditions. Keep cosmetic settings out of physical authority. Preserve open-route racing without mandatory checkpoints or a racing-line attractor. |
| Recordings | Keep tick inputs and snapshot playback explicitly separate. When adding gameplay inputs or state that affects reconstruction, review capture and compatibility. Record enough context to identify the rules and starting conditions; mark incomplete or oversized recordings as unsuitable for future verification. |
| Results and storage | Keep timing, finish detection and eligibility understandable independently of file or service operations. Future submissions should consume a completed result and recording; they must not block the ski tick, instant retry or local saves. Extract interfaces when an actual second consumer needs them. |
| Identity and platforms | Keep course/race identity independent of a Steam account or backend provider. If platform support is added, map external account IDs at the integration boundary and allow Steam initialization or connectivity to fail without breaking solo play. |
| Progress and trust | Keep personal bests, eventual local mastery/cosmetics, and future public ratings conceptually separate. Local eligibility is not proof of a legitimate online result. Test/lab and modified-rule runs remain excluded from the applicable standard records. |

These are review considerations when touching the relevant code, not a demand
to retrofit every existing subsystem immediately. A gameplay improvement can
justify a physics or replay version change; future competition does not freeze
development or create a legacy save-migration requirement.

## Current foundations and limits

- [The architecture](../development/ARCHITECTURE.md) keeps normal skiing independent of rendering.
  [Race definitions](RACES.md) already identify compatible terrain, rules and
  physics for local records and text-code sharing.
- [The local competitive loop](COMPETITIVE_LOOP.md) captures inputs at 120 Hz and
  snapshots at 30 Hz, with an exact finish sample. The current implementation is
  in [`run_replay.gd`](../../scripts/racing/run_replay.gd); replay layout is v4 at
  this decision date. A new eligible PB can retain its ghost; this is not an
  archive of every attempt.
- Ghost playback interpolates recorded states. It does not reconstruct a run
  through a trusted second simulation. Cross-platform deterministic input replay
  and complete authoritative validation have not been established.
- Records and eligibility are local and trust-based. Version IDs and checksums
  establish compatibility, not that an unmodified client or a human produced a
  result. Existing "ranked/unranked" wording refers to local record eligibility,
  not an implemented public MMR service.

## Candidate progression and decision gates

The following is an order to consider, not a committed feature list. Stages can
be skipped or reordered based on player feedback and maintenance cost.

| Candidate | Player purpose | Decision before implementation |
|---|---|---|
| Local mastery, medals and cosmetic recognition | Give exploration and repeated descents visible goals. | Confirm that goals reward enjoyable skiing and preserve fair race rules; avoid making online access necessary for solo progress. |
| Steam friends leaderboards and shared ghosts | Let friends challenge one another at different times. | Choose storage, version handling, upload limits and the level of result trust shown to players. Keep imports bounded and treat downloaded records as untrusted data. |
| Shared weekly cups and divisions | Bring players back to a common set of courses without requiring simultaneous attendance. | Define event/rules identity, attempts, scoring, physics-update policy and result acceptance. Plan curation and modest service operations. Seasonal points or medals do not require opponent-based MMR. |
| Private group skiing and casual races | Let a small group explore, spectate and race together. | Evaluate Steam lobbies and player hosting, synchronized course versions, late joining, restarts and host departure. Start by considering non-colliding skiers to limit synchronization cost. |
| Public rated events or live ranked races | Provide trusted competition against similarly skilled players. | Establish result validation and service-owned rating, attempt/disconnect rules, abuse review and enough participants. Dedicated live movement authority requires a separate funded decision. |

Prefer modes that still work with a small audience. Several ranked queues split
players by region, time and skill; simultaneous matchmaking needs evidence of
demand. Private host-reported results must not automatically become public MMR.

## Trust and operations when online work becomes concrete

A small backend could later authenticate players, distribute event definitions,
store accepted results and own public ratings. Keep publisher secrets on that
service. Steam is a candidate integration, not a substitute for defining game
rules or validating submissions. Recheck its current APIs, limits and costs when
choosing an implementation; this document commits to no provider or monthly fee.

For stronger time-trial validation, first investigate whether a separate headless
runner can reliably reproduce recorded inputs under canonical starting conditions,
terrain and rules. Measure correctness, drift and CPU cost before relying on it.
Treat mismatches as validation failures requiring investigation, not automatic
proof of cheating. Snapshot playback and plausible speed checks alone cannot
establish legitimacy.

Even a valid input replay can be copied, automated or constructed with slow motion.
It proves neither human control nor real-time execution. More serious competition
may need live input timing, server-controlled attempts, review tools and additional
anti-cheat measures. Keep that trust promise proportional to what is verified.
Official rating changes would need validated results, duplicate-submission handling
and policies for arranged wins, disconnections and disputed outcomes.

Before funding dedicated movement servers, measure headless simulation capacity,
concurrent demand, latency requirements, regions, bandwidth and operating cost.
Budget developer time for deployment, updates, backups, monitoring and moderation.
Future live multiplayer still requires synchronization, prediction/correction and
connection handling; preserving these boundaries does not make it a drop-in change.

## Evidence and scope

This decision changes documentation only. It establishes no online, anti-cheat,
determinism, cost, performance or multiplayer acceptance. Future features need
appropriate automated checks, rendered inspection, network testing and user
playtests, reported separately under the existing project guidance.

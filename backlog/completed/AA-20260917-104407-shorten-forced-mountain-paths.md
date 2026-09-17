---

id: "AA-20260917-104407-shorten-forced-mountain-paths"

title: "Shorten forced mountain paths and soften their definition"

status: completed

priority: P1

depends_on: []

created: "2026-09-17T10:44:07Z"

updated: "2026-09-17T11:53:27Z"

source_thread: "01a0a5df-19c3-7783-81dc-eca18c340e4a"

---



# Shorten forced mountain paths and soften their definition



## Outcome



The user finds the generated straight lines too forced and the mountain too

easily skiable. Keep paths, but make them shorter and less defined so the rider

chooses how to link local openings through natural terrain.



## Current state and evidence



Dev94's face generator creates roughly 400 m forest passages and extends

protected clearance by another 250 m at each end. A two-seed recipe survey

measured median straight clearance of 924 / 920 m and p95 of 1,060 / 1,004 m.

Channels join across successive 520 m elevation tiers and protect wide continuous

clearance even where their terrain cuts taper. Matched production views confirm

conspicuous stripes through woodland. Evidence: `artifacts/natural_openings_20260917/`.



## Agreed decisions and scope



Implement the requested shorter, less defined paths. Start with the observed

forced forest extensions and continuous channel clearance. Retain connected

downhill choices, the six-face mountain, 170,000 Standard trees, the sparse

approximately 4,200 m upper band, 120 Hz solver and shared 4 m terrain authority.

Keep tree assets, rendering quality, LOD distances and physical collision shapes.

Retain occasional large corridor boulders when alternate downhill routes exist.

Physical generator identity must advance; do not relabel previous worlds or runs.



User clarification: retain corridors between forests, particularly at lower
altitudes. They should bend, branch and connect rather than form isolated gaps
or kilometre-long straight lanes. Add fuller sheltered tree groups near 3,500 m,
with sparse groups higher up. Suggested counts are rough visual guidance; the
user delegated the natural placement and superseded the earlier 10% adjustment.

## Implementation approach



Remove straight woodland extensions. Keep finite bent glades with tapering,

variable-width edges, linked by continuous winding channel corridors and forks.

Keep channel cores clear through junctions; taper the broader terrain cuts.

Add coherent sheltered groves near 3,500 m, retaining the fixed total and a

sparse summit fade. Altitude count suggestions are rough visual guidance. Report actual altitude counts rather than claiming an exact quota.

Retain rare huge boulders as features to go around. Connect small/medium corridors
into other paths, with no isolated forest spurs.
Keep generation/runtime powder queries consistent. Update current producers and

cache identities, then prepare two seeds explicitly under Exclusive admission.



## Acceptance and verification



- [x] Recipe sightlines are substantially shorter; narrow powder queries agree

  exactly with the full generation query across two seeds.

- [x] Corridor clearance continues through bends/junctions with fork choices on

  every face; native views show useful paths between lower forest stands.

- [x] Both Standard worlds retain target population, high sparse trees, seated

  roots/minerals, valid shared support and connected downhill graphs on all faces.

- [x] Inspect matched native survey/chase views and a bounded ordinary-input

  route; distinguish automated reachability from human difficulty/feel.

- [x] Affected physical/runtime, ecology and cache checks pass. Update owning

  guides, record scoped metadata and a development note, then commit/push.



Human visual and skiing acceptance is separately pending, not a completion gate.

No new FPS baseline is required for this world-design request.



## Open questions



None. The user delegated natural placement and altitude-band tuning; inspect

actual results instead of imposing an exact altitude quota.



## Completion record

Implemented generator 17 with 192 short links per mountain (median 117-119 m,
maximum 375-376 m). Local straight sightline p95 is 272 m on both seeds; connected
descents remain longer. Both Standard seeds retain 170,000 trees and 16,022
minerals, six connected downhill graphs and no sampled corridor centres blocked
by trees. Four / three rock formations cross sampled paths intentionally.

Seeds 849205174 / 638201943 contain 3,068 / 2,723 trees at 3,400-3,500 m,
240 / 255 above 3,500 m and 24 / 23 above 4,000 m. Highest roots reach
4,234 / 4,150 m. Placement follows sheltered patches, slope and exposure.

Fourteen selected checks passed, with unchanged compact checks reused within
this milestone. Inspected eight matched native views and six feature views;
boulder assessment uses survey views because their chase views are occluded.
The fresh 1,800-tick lower route had no obstacle contact. Human skiing feel and
individual boulder approaches remain separate acceptance. No new FPS result.

Evidence: `docs/NATURAL_OPENINGS_RESULTS.json` and
`artifacts/natural_openings_20260917/REVIEW.md`.
Development note: `changes/4af0c825bfd24a9a958da5e1f7906715.json`.
Generator 16 physical worlds and associated competitive data are incompatible;
personal files were not modified. Model 35 and 120 Hz remain unchanged.

# Thick snow, ski control and physical formations

Current physics is **model 27**, with **generator 15, snow revision 2**. The
model 26 contact rules remain in place alongside [arcade air control](ARCADE_AIR_V27.md).
The Node-independent solver runs at 120 Hz. Replay v5 has eight input
fields. Physics identity and the final mountain height/obstacle fingerprints
reject incompatible results and recipes; no migration is provided. The source
and engine validated v15 recipe cache rebuilds when shaping sources change.
See [v15 generation and richness](GENERATION_V15.md) for the current packed tree
pipeline; dated v14 measurements below remain comparison evidence.

## Traction and contact

Most snowy terrain now has approximately 19–27 cm of loose snow, including open
faces and the terrain between trees. Sheltered deposits are deeper; wind varies
the depth without making ordinary snow shallow. Rock uses the shared material
mask. This depth is a physical input to contact, not a visual classification.

Model 23 multiplied edge grip but still capped the resulting force through the
rider's instantaneous balance width. Controlled turns in 20 cm snow therefore
slipped almost exactly like turns in 2 cm snow. Model 24 adds passive resistance
from the embedded ski sides. It builds continuously with depth and penetration,
is proportional to each ski's compressive load, and opposes sideways velocity.
It remains effective during weight transfer and with a flat ski base. The body
controller reacts to the resulting acceleration through its existing pressure
controller; it cannot veto passive snow resistance.

Ordinary edge force retains its balance limit. Combined lateral resistance is
bounded by each ski's available reaction and cannot overshoot zero sideways
speed within a tick. Flight, unloaded skis and rock receive no embedded-snow
force. No input assigns travel velocity and no racing line attracts the rider.
Workbench Edge grip and Carving response also scale thick-snow response;
**Deep snow hold** adjusts its load limit directly.

The depth-dependent normal spring, passive damping, progressive compression
stop and 28 cm suspension reach remain. Straight snow drag and planing remain
passive. Read-only telemetry exposes compression, normal dissipated work and
traction utilization. The final contact probe cannot integrate work twice.

[Small snowbank crushing](SNOW_CRUSHING.md) adds temporary, non-rebounding
compression beneath supported skis, blending from 80 to 120 km/h and capped by
30 cm of bank height and available loose depth. It precedes the existing leg
suspension and adds no forward resistance. The mountain remains immutable.

## Physical features

Every face receives continuous seeded low wind waves and rounded relief,
including snowy terrain between the localized features. A separate noise stream
preserves geology/ecology randomness. Broad features span approximately 15–50 m
so the authoritative 4 m triangles can represent them. Each face also retains
96 wave patches, 100 mounds and 32 sheltered banks. Their unfaded amplitudes are
10–25 cm, 20–45 cm and 30–85 cm respectively.

Relief fades near rock, the summit, shallow exits and protected drop approaches.
It no longer requires a strong downhill-facing normal that excluded many snowy
cross-slopes. Shaping commits from immutable input rows before final seating.
Contact, rendering, survey, tracks and crashes all use the same final surface.

All 200,000 tree anchors participate in the permanent snow pass. Most deposits
are small shoulders, with varied heights and a minority of larger wind piles.
Footprints remain approximately 9–16 m across; grid addition is limited to 1 m,
down from 2.5 m. Overlap takes the maximum instead of summing piles. Validation
measures trunk rise and local prominence relative to added snow six metres away;
a grid peak is not a visible mound height. Trees and mineral foundations are
reseated. Added snow cannot expose rock merely by changing the normal stencil.

## Spray and tracks

Spray reads load, penetration, edge work and slip from each ski. Embedded skis
leave a modest trail in clean low-slip turns; larger lateral work still produces
more spray. Emitters clear the actual terrain at the tail location, including
High's loose crowns. Particle counts remain bounded and unchanged.

High's 32 m local powder mesh retains filtered grooves. Track ribbons now sample
that same displacement texture and remain visible over the local snow surface,
instead of disappearing whenever the local patch is active. Low and Balanced
retain terrain-following ribbons. These effects never change contact or future
traction when crossing an earlier track.

The rendered skis sink only 15% of physical penetration, capped at 2 cm; this
cosmetic offset is suppressed while the skis physically crush snow. The
previous 10 cm allowance hid too much equipment beneath the loose layer. Boots
and bindings share the adjusted frame and the rendered legs close to it; body,
camera, solver depth and traction remain independent of this visual offset.

## Validation

Repair evidence is in `artifacts/snow_control_fix/`, with logs under
`artifacts/guarded/snow_fix_*`. Use the validated cached mountain for routine
checks, and run engine workloads serially through `scripts/run_snow_check.ps1`.

Relevant suites are physics, runtime, thick_snow_control, snow_response,
planted_snow, rock_terrain, jump, landing_absorption, tuck_contact,
tree_snow_v14, snow_coverage and alpine_v14 under `tests/`.
Coverage samples all six faces and three elevation bands, including separate
open-slope depth counts. Contact checks compare actual travel, slip and reversals
on otherwise identical shallow/thick slopes and verify workbench tuning effects.

Rendered inspection, performance and the user's skiing feel are separate from
numerical checks. Native timing uses actual 3840×2160 output, High, 75% FSR2,
120 FPS cap and SDFGI off, with screenshots outside the measurement interval.
Retained v22/v13 fixtures serve explicit comparisons only, not compatibility
loading or acceptance evidence for the current build.

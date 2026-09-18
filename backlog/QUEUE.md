# Current backlog

Focus: `tasks/`, `blocked/` and `ideas/`, as requested on 17 September 2026.
On18September the user authorized implementing the four prepared ideas while
the remaining forest and Mac tasks stay blocked. This is an index;
status, dependencies, evidence and acceptance live in each stable task record.

## Visual improvement queue

Authored on 18 September 2026 after a rendering review of the current build,
with deterministic macOS probe captures. All fifteen records in this group are
`ready`; the three product decisions in them were settled with the user on
18 September. Ordered by the reviewer's judgement of visible impact, not by
dependency. Later records came from second and third passes over dusk, night,
the precipitation presets and the first-person view, which the first pass had
not reviewed. Dawn and rain were reviewed and produced no new record.

- **[Distant forest card aliasing](tasks/AA-20260918-011200-resolve-distant-forest-card-aliasing.md)** (P1, ready): sub-pixel impostors scatter into crawling pepper noise across every wide shot. Appearance-scoped; read the blocked grouped-stands record first.
- **[Snow highlight headroom](tasks/AA-20260918-011201-restore-snow-highlight-headroom.md)** (P1, ready): sunlit snow sits where the filmic curve is flat, compressing away crystals, sheen, scanned normals and hollows that are already paid for. User chose readable form over dazzling glare on 18 September; one fixed look, no new saved setting. Do this first: it changes how every other snow term reads.
- **[Snow beyond the shadow map](tasks/AA-20260918-011202-shade-snow-beyond-the-shadow-map.md)** (P2, ready): nothing casts shadows between `shadow_distance_m` and the 3,900 m backdrop band, flattening the middle distance.
- **[Aerial perspective](tasks/AA-20260918-011203-add-aerial-perspective-to-distance.md)** (P2, ready): `fog_aerial_perspective` is never set, so depth planes share nearly one value.
- **[Backlit snow spray](tasks/AA-20260918-011204-light-backlit-snow-spray.md)** (P2, ready): the spray shader defines neither transmission macro, so plumes never glow against the sun.
- **[Affordable contact shading](tasks/AA-20260918-011205-seat-scenery-with-affordable-contact-shading.md)** (P2, ready): presets 1-7 run with no ambient occlusion at all, so scenery is not seated in the snow.
- **[Wind-packed and scoured snow](tasks/AA-20260918-011206-show-wind-packed-and-scoured-snow.md)** (P2, ready): the `wind_pack` signal already reaches every snow fragment and changes almost nothing visible.
- **[Wind-drift lee shading](tasks/AA-20260918-011207-shade-wind-drift-lee-sides.md)** (P2, ready): follow-up to the wind-drift relief, accepted by the user on 18 September at its authored strength ramp. Depends on the exposure work, because both terms must be tuned against the final tone curve.
- **[Ridge-crest spindrift](tasks/AA-20260918-011208-add-ridge-crest-spindrift-plumes.md)** (P3, ready): the spindrift field is rider-local only. Approved on 18 September for every weather including Clear as a first implementation; the one idea here that adds an effect rather than improving one.
- **[Distant ski tracks](tasks/AA-20260918-011209-keep-ski-tracks-visible-at-distance.md)** (P3, ready): ribbons discard at 380 m, so a finished descent looks untouched from above. Must not give back the Dev 75 saving.
- **[Sun shadow penumbra](tasks/AA-20260918-011210-soften-sun-shadow-edges-with-distance.md)** (P3, ready): no angular light size, so every shadow edge is uniformly hard.
- **[Visible falling snow](tasks/AA-20260918-092100-make-falling-snow-visible-in-weather.md)** (P1, ready): Snowfall and Snowstorm read as fog. 600 flakes fill a 32,384 cubic metre volume, one per 3.8 m cube, and storm intensity drives opacity rather than density.
- **[Sky-lit shaded snow](tasks/AA-20260918-092101-light-shaded-snow-from-the-actual-sky.md)** (P1, ready): shaded snow takes one flat ambient colour, so at dusk the peaks catch pink alpenglow while the slope under the skis stays neutral grey.
- **[First-person body](tasks/AA-20260918-093800-give-the-first-person-view-a-body.md)** (P1, ready): selecting the close view hides `body_pivot` outright, so a 140 km/h tuck shows two ski tips and nothing else. No hands, forearms or poles.
- **[Night sky stars](tasks/AA-20260918-092102-give-the-night-sky-stars.md)** (P3, ready): the 48-line sky shader has a moon disc and glow and no stars at all.

## Blocked work and resume conditions

- **[Grouped distant stands](blocked/AA-20260914-094136-render-distant-forest-stands.md):** timed quad prototypes gave no FPS gain. Corrected depth patches pass numeric calibration but still break canopy silhouettes; rejected before timing. Resume with a materially different representation and bounded residency.
- **[Metal frame floor](blocked/AA-20260916-181500-reduce-mac-metal-frame-floor.md):** MacBook unavailable, confirmed by the user on 17 September. Resume with machine access and Metal counters or a concrete alternate attribution method.

## Approved ideas

All four approved idea evaluations are complete. Three production improvements
are delivered; the fourth is a qualified frozen prototype.

## Latest completed improvements

[Requested ghost-count loading](completed/AA-20260917-222200-load-only-requested-ghost-count.md) avoids decoding unused automatic selections; qualified loading and retry gains, 611 regression checks passed.

[Solid replay skiers](completed/AA-20260917-222200-skip-unchanged-ghost-material-updates.md) now change only jacket colors, keep normal equipment and skip unchanged tint submissions.

[Scenery cache dependencies](completed/AA-20260917-222200-separate-scenery-bake-dependencies.md) retain prepared data across foliage-sight display edits while preserving bake and export integrity.

[Shared far-tree materials](completed/AA-20260917-222200-share-far-tree-material-submissions.md) preserve individual cards and save 0.0247 ms local render CPU. The frozen prototype is retained; it is not installed in the production forest and does not establish mountain FPS.

## Rules for the next task

Use the [current economical policy](../docs/VALIDATION.md#reusable-baselines-and-experiment-budget):
one hypothesis/candidate, visually reject before timing, reuse a matching saved
reference and add a control only for a specific ambiguity. Skip manual hash
audits and broad matrices. Retain verified small CPU/GPU/loading gains even when
the main FPS bottleneck does not move; report the distinction. Small visual and
physics tradeoffs are authorized, with the 120 Hz solver and 4 m authority intact.
Runtime replay/cache compatibility checks remain required. These current user
directions supersede older fresh-baseline/pixel-exact wording in historical records.

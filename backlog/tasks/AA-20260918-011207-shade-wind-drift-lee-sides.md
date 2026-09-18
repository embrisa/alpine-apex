---
id: "AA-20260918-011207-shade-wind-drift-lee-sides"
title: "Shade the lee sides of wind drifts so their shape survives bright sun"
status: in_progress
priority: P2
depends_on: ["AA-20260918-011201-restore-snow-highlight-headroom"]
created: "2026-09-18T01:12:07Z"
updated: "2026-09-18T14:15:00Z"
source_thread: null
---

# Shade the lee sides of wind drifts so their shape survives bright sun

## Outcome

Wind drifts should keep their shape on the brightest sunlit faces, where a
lighting-normal tilt alone is largely compressed away. Real drifts read partly
because their lee hollows are self-shadowed and sky-lit, not only because their
windward faces catch more sun. Adding that occlusion and cool tint would make the
drift relief hold up exactly where it currently fades out.

## Current state and evidence

Read-only inspection and bounded rendered macOS probes on 2026-09-18 at `main` `7c2d049`. Probe captures used `scripts/mac_frame_probe.sh` with the deterministic `--probe-hold`/`--probe-at-tick` options; the Standard fixture (seed 849205174) was rebaked because the local cache was `mountain_cache_v15` against current `mountain_cache_v17`. macOS frame times are not the performance target in [Rendering](../../docs/RENDERING.md#performance-policy); they indicate direction only.

- A three-band wind-drift relief was implemented and measured in the working tree
  on 2026-09-18 against `main` `7c2d049`, in
  [`alpine_surface_fragment.gdshaderinc`](../../assets/graphics/alpine_surface_fragment.gdshaderinc)
  and [`alpine_surface_uniforms.gdshaderinc`](../../assets/graphics/alpine_surface_uniforms.gdshaderinc),
  with a `snow_drift` preset control. It computes an analytic noise gradient from
  hashes the shader already samples, and fades each band by the pixel footprint.
  It is not committed and the user has not accepted it; this task depends on that.
- Matched deterministic captures are retained as
  `artifacts/snow_wind_drift/flank_before.png`, `flank_after.png`,
  `frame_before.png` and `frame_after.png`, taken at the same solver tick with
  identical peak speed.
- The measured limitation: on the isolated surface at a scene mean of 0.716 the
  relief was strong, while in game at a snowfield mean of 0.840 local contrast
  moved only about 4%. The relief is clearest on raking light at the flank and
  weakest in the bright centre.
- The shader already carries a suitable occlusion precedent: the existing wind
  ripple modulates `AO` by `1.0-close_snow*(.5+.5*cos(ripple_phase))*.03375`, and
  [`snow_readability.gd`](../../scripts/presentation/snow_readability.gd) already
  applies a cool tint, `mix(vec3(1.0),vec3(.804,.8698,.93),...)`, for real terrain
  hollows with a documented 13.98% linear-light reduction.
- The drift height is available for free: the same `value_noise_slope` call that
  produces the gradient also returns the field value, so a lee-side term needs no
  additional sampling.

## Agreed decisions and scope

- Settled with the user on 2026-09-18: the underlying wind-drift relief is
  accepted at its authored strength ramp (`snow_drift` 0.40 Low, 1.0 High, 1.20
  Ultra), and this lee-side shading is approved as its follow-up.
- The lee term follows the existing `snow_drift` control. Do not add a second
  control; one knob governs the drift's shape and its shading together.
- Tune after the exposure work lands. Recovering compressed highlights will make
  both the relief and this term read more strongly, so strengths chosen against
  today's tone curve would be wasted.
- The drift height field is already computed; a lee-side term must reuse it and
  must not add a noise tap or a texture.
- Compose with the readability hollows rather than competing with them. Real
  terrain concavity must stay the stronger and more legible cue; cosmetic drift
  shading is secondary and must not mask it.
- Keep the existing combination rules: material and screen AO combine by minimum,
  and the tint is a reduction only, with no brightening or emission.
- Must not read as dirt, a rock patch or a shadow of something that is not there,
  and must obey the same daylight and night gates the readability tint uses.
- Presentation only; no geometry, support surface or collision involvement, the
  same boundary the drift relief itself holds.

## Implementation approach

1. Start from the accepted relief and the delivered exposure. If either the band
   amplitudes or the tone curve move afterwards, re-tune against the final values
   rather than keeping numbers chosen earlier.
2. Derive a lee measure from the drift field the shader already has, so hollows
   darken slightly and crests do not brighten, matching the readability tint's
   reduction-only rule.
3. Apply through `AO` and a restrained cool tint, fading with the same pixel
   footprint the relief bands use so the term disappears exactly when its shape
   stops being resolvable.
4. Verify specifically on bright sunlit faces at midday, which is the case the
   relief alone fails, and confirm no change where the relief is already working.

## Acceptance and verification

- [ ] Matched deterministic captures at the same solver tick show drift shape
  holding on a bright sunlit face, with recorded local contrast before and after.
- [x] Readability hollows remain the dominant terrain cue; capture a location
  where both are active and confirm the real concavity still reads first.
- [ ] No dirt, rock or false-shadow reading at any distance, at chase and
  first-person views, under production upscaling.
- [x] Night, dusk and overcast behave correctly; the term fades exactly as the
  readability tint does.
- [x] Terrain, local powder patch, powder caps and tracks agree at their
  boundaries, since they share the snow material family.
- [x] Bounded warmed before/after frame comparison; expected to be arithmetic
  only, but confirmed with the noise floor stated.
- [x] Update [Rendering](../../docs/RENDERING.md#snow-presentation) and validate
  the backlog.

Human acceptance: a completion gate, since this is a further step in a look the
user has not yet accepted.

## Open questions

None.
## Completion record

Accepted relief from a94b93bd now reuses its heights for restrained lee tint/minimum AO, following snow_drift and existing gates.

Implemented and measured in the shared snow milestone. Evidence and limitations:
`artifacts/snow_appearance_20260918/REVIEW.md`. 242 focused headless checks and
25 native radiance checks pass. At matching 4K High Auto .75, the local mixed
fixture measured 192.05 FPS; mean frame +.033ms versus the control average,
within the observed .150ms control spread. This is not whole-mountain acceptance.

The record remains in progress for the user look gate. In particular, isolated
lee contrast improves in first person but is nearly unchanged in chase Auto;
soft-snow sheen is intentionally reduced, and the amount of visual variety needs
user judgement. Initial summit-framed riding stills are superseded by the
corrected supplement; motion pairs match physical ticks but have camera
interpolation differences. No human/controller acceptance is claimed.


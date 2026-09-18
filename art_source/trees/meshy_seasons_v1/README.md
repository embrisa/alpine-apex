# Meshy seasonal forest source pack

Presentation-only replacement of the 30 visible forest slots at three detail
levels. The physical catalogue, placements, race identity and 120 Hz solver stay
in their owning production systems. The seasonal runtime pack is generated under
`assets/graphics/trees/seasons`; it never reads this source directory or artifacts.

## Provenance and spend

All inputs are original prompts authored for Alpine Apex. Meshy GPT Image 2 made
reference images; Meshy 7 Ultra made textured GLB sources. Each source directory
retains its request, task ID, reference (or the path to its shared reference), and
unaltered downloaded GLB. `credits.json` is the per-job ledger against the user's
2,000-credit authorization. No community assets or third-party photographs were
used. Download route: the installed Meshy MCP, `meshy_download_model`.

Usage evidence: [Meshy terms](https://www.meshy.ai/terms-of-use) and the
[commercial-use explanation](https://intercom.help/meshy/en/articles/16102098-can-i-use-meshy-assets-commercially),
reviewed 2026-09-18. These generations used the credit-funded API account. Meshy's
paid-use terms assign generated assets to the customer, subject to ownership of
inputs and the service terms; free-plan public assets have separate attribution
terms. No third-party creator attribution is applicable to these original inputs.

## Preparation

Run `build_sources.ps1` inside one Exclusive `scripts/run_guarded.ps1` invocation.
It uses Blender 5.2, retains raw inputs, and writes only the task's ignored
`artifacts/meshy_seasons_20260918/prepared` directory. Whole trees share a single
12 m root/height frame across LODs. Leafy crowns use the full-topology birch/maple
sources; automatic Meshy remeshing removed their leaves. `compose_leaf_lods.py`
keeps green leaf surfaces, creates bounded clustered LODs, and combines them with
the same bare Meshy trunk used in winter. Its padded colour atlas keeps each tree
to one surface. The maple uses two differently oriented source crowns within the
same final budget to cover its broad branch envelope. The offline Python needs
NumPy, Pillow and `meshoptimizer==0.2.30a0` in `.tools/art-venv`.
`project_bough.py` samples each full-topology conifer branch into twelve shallow
depth slices: three radial bearings, each with four depth intervals. Colour,
coverage and tangent normals retain the original needles. Each 96-triangle
bough uses one 4096 × 3072 atlas; near and middle trees share its geometry and
normal map. Complete spruce/fir/pine trees use 8,108/7,916/6,956 triangles.
The light-snow texture is baked from upward-facing original needle normals;
tinting the supporting slice normals instead exposes broad white planes.
Both crown LODs use identical whole-bough placements/pivots. `--keep-root`
preserves the aligned source base despite the symmetric slice bounds. The
historical snowy bough's explicit `--flip` is specific to that old source.

Run `prepare.gd` under native Exclusive admission to review production materials
and bake eight-bearing albedo atlases. `--only=spruce,fir,pine --no-bake` is a
source-review-only iteration. Run `package.gd` with the stock editor binary,
headless under Exclusive admission, for offline BC7 compression and catalogue
sizing. Keep all three texture tiers. The summer/autumn mesh data and source
textures are shared; colour grading is baked into each season's distant atlas.
Card cropping retains the full crown at every bearing and removes empty sides.
An authored canopy mask follows leaf roles rather than seasonal colour, preserving
the visibility aid on autumn-red leaves. Near and middle evergreen materials
sample the baked normal map and discard uncovered needle texels from the existing
albedo sample. Middle detail omits close bark detail; distant cards omit normals.

The previous accepted heavy-snow conifers remain referenced from
`../meshy_snow_v1/README.md`. Odd conifer variants retain heavy snow; even variants
use the new evergreen crowns with lighter upward-facing snow. This preserves
winter variety without changing tree placement or reducing forest population.

## Review record

The first sparse summer birch/maple outputs and fine-needle conifer preparation
were rejected before timing. The second automatic broadleaf remesh also removed
most foliage. Full topology retained the leaves, but its bark was poor and its
disconnected leaves resisted ordinary collapse reduction. Voxel-merged whole
crowns became obvious blobs and were rejected. The adopted crown preparation
retains source leaf surfaces and combines them with the cleaner bare-tree bark.
Closed conifer volumes and automatic retopology produced folded sheets; finer
volumes retained that defect at excessive triangle counts. Whole-branch crossed
cards exposed broad wings. Depth slices preserve separated needle coverage.
Rejected sources are retained for provenance, not offered as runtime alternatives. The native
before views confirm the old birch trunk/branch material discontinuity. New bare
birch, maple, dead and broken sources retain their own coherent Meshy bark.

The integrated candidate passed 1,763 focused forest checks and 105,520 resident
binding checks in the native production review. On the retained 15-second
Standard route at 4K High, Auto .75, warmed winter measured 133.55 rendered FPS
(p95/p99 9.44/11.94 ms); summer measured 125.66 FPS (10.38/12.78 ms). Both matched
the recorded physical outcome with no focus loss or source drift. These bounded
samples do not establish stable 120 FPS everywhere. The prior winter control
was 118.16 FPS but predates wind-drift snow shading, so the difference cannot be
attributed solely to this forest. Detailed evidence and rejected candidates are
in `artifacts/meshy_seasons_20260918/REVIEW.md`.

The task still requires the user's appearance and controller review of summer,
autumn, heavy-snow winter and lighter-snow winter. Repeated branch structures
and occasional crossed twigs remain visible close up; distant card aliasing is
separate backlog work. Automated and rendered checks do not replace that gate.

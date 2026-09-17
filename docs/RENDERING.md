# Rendering

## Riding sun lens flare

`scripts/presentation/sun_lens_flare.gd` owns a single-view Forward+ compositor
on the active riding camera, after scene motion blur and before the HUD. Main
supplies completed camera state and the live weather sun, cloud offset/coverage
and layer height. The effect never queries physics or changes lighting, weather,
input, replay state or terrain. The compute source is
`assets/graphics/sun_lens_flare_compute.gd`.

A 49-tap weighted sun-disc depth sample estimates renderer-visible sky coverage.
It shares `cloud_field.gdshaderinc` and the sky's wisp calculation. Opaque terrain
and scenery, including foliage written into depth, block the source. Transparent
surfaces that do not write depth cannot occlude it. A tiny two-float GPU texture
holds smoothed and current visibility; complete blockage suppresses the flare
immediately and reappearance fades in. There are no gameplay CPU readbacks.
The explicit visibility sampling method is for rendered diagnostics only.

One bounded in-place HDR dispatch adds a warm core/halo and three visible optical
reflections inspired by the loading artwork: an amber/cyan ring, a smaller mint
ring and a warm spot. They move with the projected sun and camera, with no separate
pulsing animation. There is no full-screen color copy or persistent color history. Output alpha is
preserved. Projection fades near the viewport edge, and camera cuts, view/quality
changes and buffer reconfiguration reset visibility. Night/below-horizon sun,
off-screen sun, Low quality, Optional Motion Effects off, Reduced Motion and all
inactive/menu/preview/survey/crash/results/loading/transition states remove both
dispatch and compositor resolve requests. Balanced uses 65% intensity; High uses
full intensity. There is no additional saved setting. Unsupported/headless or
multi-view rendering disables the effect. Validation and cost scope:
[sun lens flare checks](VALIDATION.md#sun-lens-flare-checks).

## Performance policy

Target: Ryzen 5 5600X / RX 9070 / 16 GB, **3840×2160 output, 90–120 rendered
FPS**, frame p95 ≤11.1 ms and p99 ≤16.7 ms after warmup. Recommended preset 7
(High) uses Auto FSR at 75%, 120 rendered cap, frame generation and SDFGI
initially off. Explicit saved overrides remain authoritative. Generated frames
are separate from rendered FPS, physical display delivery and input latency.
There is no current MacBook performance requirement.

Follow [the performance method](VALIDATION.md#performance-method). Separate
physical generation, cache decoding, scenery preparation, scene/GPU submission
and steady skiing. Source/engine/settings identity, actual internal/output
pixels, p95/p99, CPU/GPU costs and memory accompany comparisons. Neither a
language change nor a short capped scene proves complete-descent performance.
Reuse the [saved baseline and small experiment budget](VALIDATION.md#reusable-baselines-and-experiment-budget).
Fresh original-control runs, broad experiment matrices and hash audits are not
default requirements for each candidate.

Small animation or physics differences may be accepted when a measured
performance benefit justifies their effect on appearance and control. Inspect
motion, transitions and skiing behavior and report any differences; pixel or
state equality is useful evidence, not a universal acceptance requirement.
Retain verified CPU savings even when a short rendered-FPS sample cannot resolve
their contribution, provided the combined implementation has no established
regression. Distinguish milliseconds per simulation tick from milliseconds per
rendered frame and GPU time. Reduced draw calls alone do not establish a gain.

## Graphics and display

[GraphicsPresets](../scripts/presentation/graphics_presets.gd) is the single
numbered budget table: 1/4/7 retain Low/Balanced/High resource anchors; 10 is
Ultra. Ten effective profiles map onto three installed asset tiers. Read `TABLE`,
`CONTROLS` and `values` for exact bounds/budgets instead of maintaining a second
table here. They cover material detail, tree ranges, shadows, GI, snow,
particles, weather budget and background detail.

Contact shading (SSAO) and screen-space indirect lighting (SSIL) are opt-in
through recommended High (presets 1-7), and enabled by default at 8-10. Either
effect requires Godot Forward+'s normal/roughness depth prepass, so their cost
includes that shared prerequisite as well as their named passes. SSR, SDFGI or
other normal-reading effects can also require it. Individual overrides remain
available. Material occlusion, direct shadows, snow relief and scenery budgets
remain active; the tradeoff is less contact darkening and indirect fill.

[PCGraphicsSettings](../scripts/presentation/pc_graphics_settings.gd) owns
`graphics_v2.cfg`. Preset selection replaces advanced overrides and resets
Auto/75% reconstruction, .825 sharpening strength, MSAA 2x, anisotropy 4x and
terrain GI off. It preserves explicit frame-generation and Display preferences.
Advanced edits mark Custom; group resets remove only that group's overrides.
Apply every effective consumer even when asset tier is unchanged, and initialize
late-created materials/scenery with the current profile. Coalesced slider changes
must flush their final value before leaving the page. No physical regeneration.

Sharpening strength increases from 0 Off to 1 Full; viewport sharpness is
`2 * (1 - strength)`, so .825 preserves .35. Temporal reconstruction disables
MSAA and owns antialiasing; TAA remains off. Native resolution plus supported
native FG also uses the temporal pass. Report actual backend availability rather
than silently labeling a fallback FSR4.

`display_settings.gd` separately owns `display_v1.cfg`: display mode, windowed
resolution, monitor, VSync and rendered cap. Fullscreen uses native selected-
monitor pixels; saved windowed dimensions survive. Automatic window size is 80%
of screen, capped at 1920×1080. Explicit benchmark pixels override ordinary size
selection. Refresh is reported, not a selectable enumerated display mode.

Display Apply previews for 15 seconds. Snapshot actual screen/position/client
size/mode/borderless state as well as preferences. Replacement previews retain
the original recovery target; saving mid-preview writes original preferences.
Keep accepts; Revert restores preferences and actual geometry on the next apply,
before normal monitor/resolution rules. Repeated Revert is harmless. Exiting
fullscreen clears borderless before restoring the old window.

## FidelityFX

[Native integration](../native/fidelityfx/) hooks the custom Godot DX12 renderer.
The pinned SDK provides FSR 4.1.1 upscaling, FSR 3.1.5 fallback and analytical
frame generation 3.1.6. Auto chooses a supported provider; stock Godot uses its
existing FSR2/native path. Query SDK provider/context results for the actual
device. Copying DLLs into stock Godot does not enable the integration. Build,
activation and distribution are in [Development](DEVELOPMENT.md#fidelityfx).

Runtime CLI after `'--'`: `--upscaler=auto|fsr4|fsr3|fsr2|native|bilinear` and
independent `--frame-generation=on|off`. `bilinear` is spatial scaling without a
temporal pass; MSAA stays available with it. Frame generation is inactive while
bilinear is selected because the DX12 integration requires the temporal pass;
the saved generation preference resumes with a compatible upscaler. Benchmark
wrappers accept the same bilinear option. `PCGraphicsSettings.resolve_upscaler`
owns what Auto means: the SDK provider on the custom DX12 engine, FSR 2 on other
stock renderers, and bilinear on Metal. Fable's same-code M4 comparison at
3600x2260 output and 0.75 internal scale measured 39.1 ms with FSR 2 versus
27.6 ms with bilinear and MSAA 2x. This is a reconstruction quality tradeoff,
not an isolated GPU pass cost; see [MAC_PERFORMANCE_BASELINE.json](MAC_PERFORMANCE_BASELINE.json).
Explicit choices stay authoritative. The internal resolution floor is 50 percent
(`MIN_RENDER_SCALE`); the default remains 75 percent. Supported scope is one primary SDR game window;
HDR output, XR/multiview and other GPUs require separate work/validation.

The SDK receives HDR color, reversed depth, motion vectors, pixel jitter, actual
sizes, milliseconds, vertical FoV radians, camera basis and history resets.
Copy Godot's alpha-swizzled reactive view into a real texture before exposing
the raw DX12 resource. Declare external resource usage to the render graph,
flush transitions and invalidate cached pipeline/root-signature/descriptor
bindings around SDK dispatch. API-version descriptor chains need persistent
storage. Triple-buffered HUD-free textures cross enhanced/legacy barriers in
**COMMON** on both sides; shader-read layout at that boundary is invalid.

FG consumes a tonemapped scene copy before canvas/HUD. It uses the game queue
with async compute disabled; SDK owns interpolation/pacing. Render frame IDs
gate callbacks: no complete prepared frame means no generation. Context changes
flush work; resize/shutdown disable generation and drain presentation before
release. Recreated views, explicit resets and abrupt camera changes reset history.

FG fullscreen uses an exact screen-sized borderless window. Ordinary Godot
Windows fullscreen can add two native pixels and break swapchain/HUD agreement.
Reapply display immediately when toggling FG; Windows may report the resulting
geometry as exclusive fullscreen. Test actual pixels and generation/present
counters, not the enum alone. The native validation envelope is in [Validation](VALIDATION.md#native-and-package-evidence).

## Scene motion blur

[`scene_motion_blur.gd`](../scripts/presentation/scene_motion_blur.gd) is a
single-view Forward+ `CompositorEffect` attached only to the riding camera.
Main submits active-view preferences and lifecycle state; the render thread
owns shader/pipeline/sampler resources and reads completed camera/buffer state.
The installed 4.7.2 renderer orders its post-transparent callback after MSAA
resolve, before FSR/Auto reconstruction, tone mapping, the native HUD-free FG
copy, and canvas. The effect writes HDR scene color only: depth, velocity and
per-pixel reactive alpha remain unchanged. HUD, menus and impact warning are
drawn afterward. No engine/native integration patch is required.

[`scene_motion_blur_compute.gd`](../assets/graphics/scene_motion_blur_compute.gd)
uses previous-minus-current UV velocity with jitter removed by Godot. Temporal
Forward+ marks static surfaces `(-1,-1)`; derive those and sky motion from depth
and successive unjittered camera projections, with Godot's Y/Z correction.
Thirteen bounded taps integrate one exposure, stopping at depth discontinuities.
Maximum exposure is 1/120 s, scaled by strength and divided by rendered-frame
delta; maximum full sample path is 24 pixels at 1080 internal height, also scaled
by strength. Subpixel motion stays sharp; no previous color is accumulated.

The blur pass writes one RGBA16F scratch texture, followed by a compute copy to
scene color. Scratch costs 8 bytes/internal pixel (2.22 MiB at 720x405 in the
capped probe; 35.60 MiB at 2880x1620 by allocation arithmetic). It is allocated
lazily, retained while Off, and owned/released by scene buffers on viewport
reconfiguration/destruction. Off/zero remove the compositor's velocity/resolve
requests and execute neither pass. FSR/FG keep their own motion-vector needs.
View/configuration changes, suspend/resume, resized buffers, large camera cuts
and >100 ms stalls restart a two-rendered-frame warm-up. No `RenderData` or
scene-buffer object escapes the callback. Shader/device/buffer failures disable
the effect with an explicit Camera-panel explanation; no radial substitute.

Transparent snow/weather has the opaque surface's depth/velocity because this
Godot hook does not supply independent transparent motion. Very thin edges and
disocclusions therefore still need full-resolution moving review. The provisional
range passed capped DX12 Native/Auto/FG and lab-skiing checks; **4K cost, p95/p99,
full-resolution comfort and complete visual-matrix qualification remain pending**.
Reproducible producers and deferred coverage are recorded in
[the motion-blur task](../backlog/blocked/AA-20260912-004402-scene-motion-blur.md).
Controls/defaults are owned by [Presentation](PRESENTATION.md#look-and-motion).

## Terrain, forests and lighting

The built-in mesh renderer is the sole terrain path. Prepared chunks and shared
LOD templates consume [World](WORLD.md)'s support surface; nearby cosmetic relief
does not become collision. Keep chunk bounds conservative and distinguish
prepared arrays from uploaded resources.
Terrain instances use LOD bias `0.25` in both direct and prepared publication.
The existing 16/32 m interior index buffers are selected sooner; every 4 m
chunk-border vertex and the full base mesh remain intact. Clipped chunks keep
their existing unsimplified indices. This changes rendered geometry selection,
not ski support, crash collision, scenery placement or stone-mesh quality.
The open-route comparison measured a small GPU saving; do not treat it as a
dense-forest or universal frame-rate improvement.

Explicit terrain occlusion remains disabled. The conservative 32 m native
occluder passed current-bound sampled forest/ridge visibility review, but its
warmed ordinary dense route and final user-requested 170 km/h off/on pair did
not improve mean frame time or GPU cost. See [the measured verdict](PERFORMANCE_HANDOFF.md#current-bound-terrain-occlusion--17-september-2026).

Forest/material consumers retain physical tree populations at every quality.
Near/mid geometry, far directional impostors, batched transforms, residency and
visibility are presentation budgets. Current authored living foliage uses small
curved branch sprays and baked needle textures; source/authoring contracts are
in [Assets](ASSETS.md#trees). Do not interpret all stored instance triangles as
visible-frame work. Camera forest visibility assistance must remain cosmetic.

Golden birch and maple use `FC_Broadleaf` near and `FC_Broadleaf_Mid` at LOD1,
with textured broad leaves and roughness. Conifers use `FC_Tree` and `FC_Tree_Mid`.
The middle shader keeps authored mesh normals, omits normal-map sampling and
tangent-frame bending, and uses restrained fixed foliage AO. Both variants share
`pc_forest_tree_common.gdshaderinc`; geometry, alpha coverage, vertex/normal wind
bending, color, snow and LOD fades stay shared. Each material participates in
the same wind, branch-contact and canopy-sight registries. Foliage cutouts
(tree needles, impostor cards, legacy foliage and cards, mineral grass) use one
explicit `discard` at their threshold immediately after the texture read and
never write `ALPHA`/`ALPHA_SCISSOR_THRESHOLD`; the wind trigonometry is
evaluated once per vertex and shared by position, normal and tangent frame.
Wood keeps the LOD cross-fade dither, so it cannot take the null-fragment depth
pre-pass without a design change to the LOD handover. Their far
cards use authored canopy masks, so warm colors do not evade assistance or fade
the trunk. Both geometry and cards derive restrained leaf tint variation from
the same tree anchor; wood and snow remain neutral. Keep their grading functions
identical when editing either shader. No color variation changes tree transforms
or physics. All quality tiers retain every physical tree and existing distance
bands; prepared source and conversion limits are in [Assets](ASSETS.md#trees).

`AlpineAssets._remember_material()` assigns render priorities -20 to near tree
materials, -10 to middle tree materials and -5 to far tree cards. The renderer
sorts priority before material and coarse depth layers, so nearby forest can
establish depth before distant crowns and default-priority terrain. Opaque depth
tests still determine visibility; meshes, alpha coverage, shadows and LOD fades
are unchanged. Keep registration as the owner so late-loaded materials inherit
the order. Scene-level timing is recorded in [the performance handoff](PERFORMANCE_HANDOFF.md).

`forest_placement.gd` owns the 384 m distant-card partition; the direct
`density_forest.gd` path reads the same constant. Residency and shadow proxies
retain 32 m regions, 128 m loading and 192 m retention. LOD0/1 draw groups split
once into fixed 16 m cells; there is no per-frame instance compaction. Regrouping changes
only immutable MultiMesh submissions: seated poses, asset choice, per-tree
shader distances/fades and the residency fallback remain identical. Keep bounds
as unions of each transformed authored wind/card envelope. Detail distance
culling can use the tighter support of all shader crown spheres around the batch
centre. Compute that support from the uploaded packed buffer: prepared production
groups have an empty `transforms` array. Far and shadow bounds retain their full
diagonal padding. Larger groups trade more
off-screen card vertices for fewer submissions; do not generalize this choice
to the much heavier near/mid meshes or to mineral geometry.

Grouped stand proxies are not installed. After the user approved prototype
timing, both the pictured patch and a complete far-cell comparison showed no
performance gain. The complete cell reduced submissions but increased GPU/frame
cost. Original individual cards remain active; see the [stand record](../backlog/blocked/AA-20260914-094136-render-distant-forest-stands.md).

`AlpineScenery.batches` is an unordered ownership list. Registration records a
node's `batch_slot`; `remove_batch()` swaps in the last member and updates its
slot before removing the tail. Use this owner method for streaming retirement.
Array order is not scene/render order or tree identity. This avoids repeatedly
searching every distant batch when retiring nearby geometry, while preserving
the existing queue, upload budget, residency publication and resource release.
Native regression and moving-camera producers are in [Validation](VALIDATION.md#forest-batch-submission).

Batch configuration computes the final culling ranges, margins and shadow mode
before assigning them to the node. Avoid assigning generic values and then
overwriting them for shader trees: those setters notify the renderer each time.
Prepared shader-tree bounds already include the complete envelope and use the
node's default zero extra margin. Ordinary rocks, scrub and non-shader cards
retain their existing margins and quality behavior.

`tree_motion.gd` owns each world's branch-contact shader state. Authored branch
bounds reject disjoint swept riders before per-branch contact tests; existing
120 Hz spring responses still integrate and contacts clear after separation.
No epsilon sleep or physical collision change is involved. Publish only changed
anchor/angle arrays, using independent packed-array snapshots; late or replaced
materials receive the complete current state. Keep preview/world registries
separate. `tests/tree_dynamics_suite.gd` checks contact, pause/reset and material
replacement behavior.

`foliage_sight.gd` owns canopy-aid activation and bounded depth; `alpine_assets.gd`
submits its state to resident geometry and late streamed/fallback conifer
materials. `foliage_sight.gdshaderinc` scales removal by activation, normalized
transparency strength and the existing outer depth fade. It has no screen mask.
The unchanged stationary pixel threshold is coherent through stacked foliage;
near/mid wood and shadow passes remain excluded, and impostors retain their
canopy mask. Texture-quality/LOD changes retain the selected aid state. Player
controls belong to [Presentation](PRESENTATION.md#forest-visibility).

Cloud lighting shares a per-world registry across terrain, skier, tracks, trees,
rocks, markers and sky. Its three inputs (`cloud_params`, `cloud_sun_direction`,
`cloud_layer_height_m`) are global shader parameters declared in
`project.godot` and written once per change by `cloud_lighting.gd`; receiver
materials declare them `global uniform` through `cloud_field.gdshaderinc` and
receive no per-material writes (174 receivers on the Standard mountain). The
paused clock still freezes the wind offset, so the globals hold. The headless
renderer does not read globals back; suites inspect the publisher state.
Sky/view and directional-receiver rays project onto the
same layer at `max(2400 m, summit + 1200 m)` with shared wind offset/coverage.
Transmission affects directional light only, retaining object shadows and
ambient fill. Surface cloud transmission is vertex sampled/interpolated; material
response and geometry shadows remain per pixel. Additional directional lights
would require their own projection contract. Sun/moon active shadow ranges do
not overlap. Distant decorative background casts no shadows or GI.

## Animated race ghosts

`ghost_assets.gd` shares immutable production meshes/textures while isolating
materials through `ghost_skier.gdshader`. Recoloring retains fabric/equipment
luminance, normal/roughness response, world lighting and depth occlusion. Stable
run IDs and the current player's outfit tint/atlas average choose the palette;
Records swatches share it. Textual identity supplements color. Ten-way contrast
in actual lighting and overlap remains a rendered review requirement.

Apparent opacity is clamped to .15–.72 for every body/equipment surface, smoothly
rising from overlap to 18 m separation. Below .30 opacity, a shared screen-pixel
pattern changes coverage from the requested opacity to full coverage; surviving
fragments use opacity divided by coverage. This preserves mean opacity while
preventing coincident near ghosts from stacking nearly opaque helmet interiors
over the first-person view. At .30 and above, the existing smooth alpha blend is
unchanged. Close ghosts can show a fine screen pattern; all-distance object-space
alpha hashing was rejected because it broke up normal-distance silhouettes.
Texture alpha and instance fading cannot multiply away the floor. Distance never
hides an active ghost, including past
750 m; ordinary camera clipping and terrain occlusion still apply. Instances
cast no shadows or GI. [Racing](RACING.md#recording-and-ghosts) owns lifecycle and
recording; independent marks use the shared snow path below.

## Snow presentation

`snow_response.gd`, `snow_tracks.gd`, `powder_surface.gd`, `powder_caps.gd` and
`speed_effects.gd` consume completed per-ski load/slip/edge/material state and
final rendered ski transforms. Supported clean carving can widen/deepen tracks
without large slip; skidding makes broader swept tracks. `supported` and
`snow_contact` keep physical eligibility for particles; `track_contact` and
`track_depth_m` independently permit bounded shallow marks. A completed grounded
snow ski can continue through low load, turn release and root/leg extension:
its physical centre must first pass the 12 cm reach / 4 cm extra-burial check.
Its physical and final rendered footprints then use a 24 cm reach envelope and
allow burial no deeper than local loose depth plus 24 cm. These are cosmetic
footprint bounds, not added suspension or support.

An unsupported ski retains the conservative near-surface carving path: the
opposite ski must carry >1 N on snow, with >=.08 rad edge and grip/load >=.05
at >=2 m/s. Completed clearance must be <=12 cm and upward separation <=1 m/s;
physical footprint reach is 12 cm, rendered reach 24 cm and extra burial 4 cm.
Both paths sample nine tail/centre/tip width points at each footprint, rejecting
rock, voids and absent loose snow. The cut is capped at 12 mm and the minimum
sampled loose depth, with the existing snow-condition multiplier. Neither path
creates physical support, load or spray. Rider air and crashes remain excluded;
rendered lift alone cannot revoke an already loaded snow contact.

Resolve eligibility after final rendered ski transforms. Each ski's lateral
position/orientation remains independent; retained stamp distance uses horizontal
XZ travel, so cosmetic height cannot consume the 70 cm interval. Rejection,
inactivity, landing, teleport and reset break history.
`SnowTracks` owns accepted live geometry and supplies the identical two packed
footprints through `live_gpu_strokes()`, with hidden slots zeroed. High must not
reconstruct a second eligibility decision from physical response fields.

Two live ribbon sections connect the last retained sample through the visible
tips, with a 12 cm soft leading margin, every render frame. They do not wait for
the 70 cm retained-history interval. The player's two live GPU footprints share
those endpoints; live ribbons also work on Low/Balanced. The lateral axis of compute
displacement must agree with ribbons and world-space snow throw. Rounded lips
and forward ejection are important under hard turns. High retains its 32 m
local patch; capacities come from the effective profile, not fixed old reports.

Recorded ghosts call `update_presentation(field, position, active, responses,
ski_length)` with their captured track data and separate histories. Each ghost
has at most 320 retained stamps plus two live sections. `ghost_track_stack.gd`
is the single GPU consumer: it composes player and up to ten ghost rings in the
same 32-byte stroke layout, retaining the player's final two live slots. Ghost
ribbon materials register with PowderSurface for the shared mapping and are
removed on roster teardown. No ghost trail becomes physical terrain, contact
support or a race effect. Ten articulated models and extra track history are
bounded costs, not evidence of an acceptable native frame time. Maximum storage
is 9,366 strokes / 299,712 bytes: 6,144 player retained stamps, two player live
fronts and ten times 322 ghost slots. This is the stroke buffer only. Compare
0/1/10 ghosts and ten without tracks, keeping capture CPU, GPU, resident memory
and archive loading costs separate.

The local powder storage stays on the terrain's 4 m grid, while the visual center
follows rendered rider XZ continuously. Relief is full within 8 m, fades to zero
at 13 m, and uses complementary opaque base/replacement ownership at 13.5 m.
The .5 m zero-relief collar remains inside the 32 m storage square at maximum
center offset. Terrain bounds and the retained v15 footprint clip ownership.
There is no transparent or dithered surface blend.

The mesh emits world coordinates from an identity transform, avoiding snapped
instance motion vectors; only its culling bounds move. A 9×9 RGBA32F support
texture stores base terrain vertex normals and loose depth at fixed 4 m knots.
The previous grid is a bounded 1,296-byte CPU cache: a one-cell recenter queries
only nine new knots (17 diagonally), with the same 1,296-byte upload. Reset,
world replacement, non-grid moves and non-overlap rebuild all 81 knots.
Replacement normals
and cloud transmission use the base triangle interpolation, keeping noise/depth
world-fixed. The 32 m mesh uses 256 subdivisions (12.5 cm spacing), 66,049
vertices and up to 131,072 triangles; quads entirely outside the 13.5 m handover
reach plus the storage offset are not generated, which is exact because their
fragments were always discarded. Metal uses 128 subdivisions (25 cm): Apple's
tile-based GPUs paid about 1.6 ms per frame for the extra micro-triangles on an
M4 (`PowderSurface.mesh_subdivisions`). The 1024 atlas and 256 filtered imprint map
retain their previous resolution. This grid still follows every authoritative
4 m diagonal. Mesh/atlas dimensions remain in PowderSurface's constants.

Impression reconstruction, support upload, storage/visual centers, bounds and
material ownership publish in one render-thread transaction. Register extra
receivers through `register_receiver`; never update their origins independently
of atlas contents. `reset()` hides ownership and invalidates storage/history;
quality changes and discontinuities reopen only after reconstruction.
SpeedEffects invokes reset at its lifecycle boundary. RenderingServer state and
`budget()` describe committed mapping; the ShaderMaterial CPU cache is not the
authority for render-thread submissions. `_render_update` remains a compute-only
test API. Production uses no readback.

Partial GPU uploads must match full uploads byte-for-byte. Native compilation
caught a varying-limit failure in the end-cap shader; keep packed varyings within
the engine's limit. Native GPU checks are required for compute/shader changes.
Retained ribbons keep one width/depth per 0.70 m rectangle; adjacent sections
do not share edge vertices or interpolate the prior style. Their raised banks
sit over High's reconstructed powder surface, whose signed impressions combine
by integer maximum with recess priority and area filtering. To avoid duplicate
stepped banks, `ski_track.gdshader` fades the overlay opacity for loaded depths
from 12 to 35 mm inside the local High relief area. The existing 8-13 m radial
fade restores the packed overlay toward the boundary. Marks at or below the
12 mm cosmetic cap retain full ribbon visibility. Outside that area and with
the local patch disabled, the original overlay remains; geometry, stamping,
snow eligibility and atomic support publication are unchanged.

Fixed-spacing, matched model-32 captures isolate the overlay's contribution to
pronounced loaded banks on both turn signs and reversal. Small scallops and
shallow/live segment shapes remain; no exhaustive art or performance acceptance
is implied. The historical XYZ-to-XZ retained-distance change may also affect
join prominence and was not independently varied. Boundary agreement alone
cannot establish that it had no effect. See the [loaded-ridge correction](../backlog/completed/AA-20260912-132147-review-loaded-track-ridge-shape.md)
and [original-scale evidence](../artifacts/loaded_track_ridge_20260913/RESUMED_REVIEW.md).
Headless geometry checks do not establish the visual result. Focused producers
and their baseline limits are in [Validation](VALIDATION.md#snow-contact-and-local-boundary-producers).

`snow_readability.gd` derives concavity from symmetric 4 m/12 m neighbors in the
immutable support heights. Opposing planar slopes cancel; missing pairs and
float noise contribute zero. Workers return disjoint rows and join deterministically.
One mipmapped R8 texture is built/uploaded per world and included in scenery
preparation; no terrain analysis runs while skiing. Terrain, tracks, replacement
powder and tree snow skirts share world-texel mapping. Rock excludes the effect.

Current hollow shading reaches about 14% linear-light reduction, with a cool
tint, 80–160 m fade and daylight fade to zero at night. Convex crowns receive no
bright outline. When enabled, direct-light SSAO uses .20 influence; the local
Forward+ path requires AO-channel affect 1.0 for that setting to work. Material
and screen AO combine by minimum, not multiplication. Preserve local shape cues
while tuning soft detail, sheen/glow and filtered crystals; current values live
in graphics profiles/material code, not the earlier readability snapshots.

Scanned snow normal detail is multiplied by .5 before snow/rock blending in
`alpine_surface_fragment.gdshaderinc`; geometric relief, procedural ripples,
rock detail and crystal settings retain their separate contributions. The user
accepted this modest softening after 13 matched still pairs, without reporting
a noticeable visual improvement. `tests/snow_bump_comparison.gd` reconstructs
the original strength for comparison; `--production-check` captures the adopted
shader directly. Receipts/captures live in `artifacts/snow_bump_comparison_20260911/`.
Motion/readability benefit and performance improvement are not established.

Ground crystals use the shared `snow_crystals.gdshaderinc` compact hexagonal
mask. Footprint widening is bounded by each grain's radius; the coarse layer
uses a smaller radius and restrained coverage so it reads as small facets
instead of white discs. Crystal placement, directional/shadow/cloud/night gates,
quality controls and broad sheen retain their separate ownership. Terrain,
local powder, caps and tracks consume the same sampler; no extra texture,
particle or draw pass is added. `tests/snow_crystal_shape_playtest.gd` compares
production against the explicitly retained round-mask test fixture, isolates
layers/night response and captures matched short rides. Run it through
`scripts/run_guarded.ps1`, with `--stills-only` for lighting/material controls or
`--timing --motion` for three uncapped 15-second pairs followed by four-second
chase/first-person captures. Evidence is under `artifacts/snow_crystal_shape/`;
bounded measurements and human visual acceptance remain separate.

## Weather

`weather_controller.gd`, `weather_state.gd`, `weather_effects.gd`,
`daylight_cycle.gd` and cloud/atmosphere owners form a presentation-only system.
The controller owns complete snapshots: seeded RNG state, front endpoints/phase,
active clocks, daylight, storm cooldown and double-precision integrated cloud
displacement. World only submits this state to the shared sky/shadow field.
Ordinary fronts hold 240–420 active seconds and blend over 45–75; rain and snow
branches pass through Cloudy. Bounded gusts modulate wind and precipitation.
Daylight wraps in **3,600 active-skiing seconds**. Menus, pause, survey, preview,
loading, summit staging and results hold free-ski progression. Authored weather
samples race time, including unpaused crash time under the recovery rules in
[Racing](RACING.md#crash-location-recovery). Menu ambience may animate
clouds/precipitation unless reduced motion is enabled. Pathological deltas are
capped at 86,400 active seconds, with phase-boundary integration and bounded event work.

`weather_preferences.gd` stores player choices/history in `weather_v1.cfg`, separate
from live fronts. Both cycles, random launch weather/time and Rare storms default
on; manual fallbacks are Clear/Day, FX High, lightning Full. Launch weather draws
from ordinary presets with base weights 30/30/30/10; hour draws cover all 24 hours.
A repeated weather/time-band pair rerolls only an enabled component (hour first
when both are enabled). The resulting joint distribution is constrained, not
independent exact weights. Disabled launch toggles use manual selections. Explicit
weather/time arguments hold their corresponding cycles unless an explicit cycle
override is present. Script/headless/autoplay launches use fixed seeds, Clear/Day
and disabled cycles without personal history reads/writes.

Automatic free-ski storms have a 5% decision at eligible front changes after
1,200 accumulated active seconds and a 1,200-second cooldown after recovery.
Snowstorm follows the snowy branch; Thunderstorm follows rain; Cloudy can approach
either. Peaks last 90–150 seconds and cannot nest. Manual storms can be held.
Counters persist every 30 active seconds and at lifecycle handoffs; time away
never counts. Launches do not restore a live front; replacing an exited storm
retains a full cooldown. Within an application, retries/reloads restore the whole
front without another launch draw. Authored attempts follow [race rules](RACING.md).
Disabling Rare storms also cancels a planned storm in a suspended free-ski front
when that front resumes; it does not abruptly cut an existing storm short.

Camera parallax uses the `cloud_camera_position` shader global, published by
`alpine_world.gd` for the active camera. It does not affect the sky's inexpensive
ambient/reflection approximation, so camera movement must not dirty that radiance
map through a local material write. The separate local `radiance_cloud_coverage`
uniform explicitly refreshes radiance when coverage changes; sky/cloud colours
also refresh it. Cloud displacement alone leaves ambient/reflection content
unchanged. This shares the existing single active weather-world ownership of
cloud globals; it does not provide independent weather for multiple viewports.

The main cloud silhouette and receiver attenuation share the same noise field.
Its three octaves stay independent; domain warping would serialize this cost
across lit surfaces. Broader low-frequency weighting supplies the main shape.
High adds a restrained non-shadow-casting wispy layer; the radiance branch stays
cheap. Pooled lightning illuminates the cloud shader through WeatherState without
another daylight owner or shadow pass. Reduced suppresses abrupt cloud flashes,
Off hides bolts/flashes, and reduced motion caps the effective choice at Reduced.
Transient lightning/thunder clears on mode, camera and lifecycle handoffs.

Precipitation uses translation-only local volumes, relative wind/fall minus
camera translation exactly once, wrapping and retained particle state. Reset
history on teleports, camera transitions and quality/lifecycle changes. Bounded
ground samples replace per-particle CPU collision. Apply budget then quality
at creation and live changes, capped at 1,700 High / 850 Low particles. Snow uses
varied flake sizes/fall/flutter and gust-driven drifts. Quality zero disables precipitation/drift without
erasing selected weather, wind, cloud lighting or weather audio.

There is no precipitation accumulation, wet-grip model, physical wind force,
wind shelter or precipitation collision. These would require explicit changes
to the physical/race contracts.

## Background

`assets/graphics/scenery/alpine_valleys_01.res` is authored once and reused by current
mountains. `scripts/authoring/bake_wilderness.gd` is an explicit authoring command,
never startup/cache-repair/quality-switch generation. Three baked tiers include
terrain, masks, props, triangle anchors and source receipts.

`wilderness_data.gd` loads it; only the connector adapts to the mountain. It
preserves an exact 192 m collar, blends the height difference away by 640 m,
and stitches every exposed support edge. The fixed ridges begin around 6.6 km,
with an 18 km horizon. Unsupported bounds/resources fail explicitly. Props
reseat through baked triangle indices/barycentric weights, with no runtime
random placement or BVH. Each tier uses its matching baked triangulation.

Near conifers use 256 m batches; distant cards/rocks use 1,024 m MultiMeshes.
Bounds cover all billboard orientations and add half the batch diagonal to
distance-culling allowances. Near geometry/impostors use complementary dither;
all background collision, shadow casting and GI contributions remain off. Own material
copies rather than modifying imported resources.

Distant snow is owned by `offmap_surface.gdshaderinc` for both ridges and
apron. The cheap path keeps filtered source textures, a restrained cool hollow
tint from authored mask alpha (`.5 + .35 * hollow`), and reduced directional
wrap fill. This broad baked mask is not the playable 4 m readability map.
`Distant snow deposits` (`offmap_snow_detail`) in the existing Scenery graphics
group adds world-locked broad deposits and small lighting-normal drift variation.
Projected footprint and distance fade unresolved detail; no new texture, mesh,
shadow pass, fog change or per-frame terrain analysis is introduced. The apron
blends color, lighting normal and diffuse response into the same distant owner;
its protected collar, silhouette and all physical data remain unchanged.

All ten presets, including recommended High, leave deposits **off**. Saved
independent overrides, same-tier live edits, Scenery reset and replacement
scenery apply to both materials. Playable snow quality and scenery coverage
are independent; diagnostics support `--offmap-snow-detail=on|off`.

The bounded current-world cost gate is complete. On the qualified open upper
route at 4K High / Auto 75%, cheap/enhanced averaged 148.71/148.24 FPS, with an observed
+0.0215 ms mean frame and +0.0147 ms mean GPU for enhancement. This single short
comparison cannot resolve such small differences from noise and does not cover
whole-descent or dense-forest performance. The restrained extra detail remains
opt-in; conservative defaults are unchanged. Shared-process allocation peaks
and startup do not isolate per-mode cold cost or physical VRAM occupancy.

Use the maintained [material comparison](VALIDATION.md#scenery-snow-material-comparison)
for warm current-fixture captures and separate capture-free timing. A tiny
expanded shader snapshot restores the original material while keeping independently
updated cloud includes current. Record revision, paths and sizes; no hash audit.
[The compact report](../artifacts/scenery_snow_cost/REPORT.md) retains exact
results, actual settings, visual coverage, startup/memory limits and commands.
### Distant mountain shadows

`Distant mountain shadows` (`offmap_shadow_quality`, Off/Low/High) is a saved
Scenery override, independent of gameplay shadow distance, GI and snow deposits.
All ten presets default Off; `--offmap-shadows=off|low|high` selects the same
consumer for diagnostics. Settings changes load a companion, never bake.

`wilderness_horizon.gd` owns one atlas matching the resident geometry tier.
Low is 128x128 with 16 azimuths (0.5 MiB); High is 256x256 with 32 (4 MiB).
CPU image bytes plus the GPU texture are resident while enabled; these are
payload sizes, not process/physical VRAM measurements. Off unbinds/releases both.
Two filtered angular samples compare precomputed obstruction with the active
sun or opposite moon direction. Only direct lighting is attenuated; ambient,
fog and cloud composition retain their owners. Ridges, apron and background
tree/rock materials share the lookup. No extra draw, shadow-map pass or runtime
terrain analysis occurs.

All occluders inside 3,900 m are omitted, and receiver strength fades between
3,900 and 4,300 m. This conservatively contains every seed's irregular footprint,
join and 640 m connector deformation. The variable central mountain's cast
shadows are deliberately absent; its reference-seed shadow is never stamped
onto other seeds. Physical heights, placement, base asset bytes and UIDs stay
unchanged. During staged replacement the atlas matches resident geometry;
publication selects the latest override, including a concurrent Off request.
Missing/incompatible companions report an explicit rebake error and disable
shadow evaluation. See [authoring](ASSETS.md#distant-shadow-companions) and
[verification](VALIDATION.md#distant-mountain-shadow-checks).

The bounded RX9070 4K High/Auto0.75 dusk check measured Off/Low/High at
146.19/144.72/144.82 average FPS. High added 0.065 ms mean frame time; Low had
worse tails in its single sample. Both remain opt-in. This open upper route
is separate from dense-forest acceptance; [the compact report](../artifacts/scenery_mountain_shadows/REPORT.md)
owns exact cost, memory/loading, visual coverage and limitations.

Additional valley haze starts beyond 1 km/outside the protected collar and
follows weather/time. A custom `FOG` output replaces automatic material fog,
so compose base distance extinction/sun scattering with valley haze there;
playable terrain retains the normal Environment/local volumetric path.
Stage replacement batches hidden, then swap atomically. Cancellation preserves
the active owner; newer requests supersede older builds. Reapply current weather
after replacement. Visual seams, seating, memory, loading and frame times need
separate checks.

## Terrain grass

`terrain_grass.gd` owns camera residency and shared opaque blade materials;
`grass_motion.gd` owns sixteen recent swept skier segments. Placement and the
coverage/coating/burial distinction belong to [World](WORLD.md#terrain-grass);
sealed art and runtime conversion belong to [Assets](ASSETS.md#prepared-ground-vegetation).

Grass consumes the existing weather wind registry and cloud-light field. UV0.y
anchors each blade root and carries its snow strips through deformation. Nearby
grass bends away from the skier's swept path, gated by horizontal distance and
height, then recovers over 1.25 active seconds. Sweeps join high-speed endpoints
without per-tuft state; short aligned segments coalesce without cutting corners.
Pause holds interaction and wind follows the existing presentation weather clock.
Retry, teleport (over 30 m), scene replacement and teardown clear old influence.
Camera movement only selects residency; it cannot flatten grass or feed physics.

The two authored blade LODs cross-dither over 18â€“26 m, with complementary coverage;
individual roots fade over the last 22% of the existing ground-foliage distance.
A separate residency clock fades new cells over .35 seconds even when wind is
paused. The same decorative density/distance controls govern independent mineral
overlays; zero density releases ground cells and hides mineral grass. Bounds add
.65 m for deformation; grass casts no shadow, has no collision and uses no GI
contribution. All physical trees/minerals and other scenery budgets remain intact.
Near-detail batches stop submission at 26 m plus their conservative AABB half
diagonal: this removes only geometry already fully rejected by the shader. The
18-26 m blend and authored meshes stay unchanged. `terrain_grass_lod_playtest.gd`
compares the old unlimited near submission with this bound in eight frozen native
views; each pair must have identical pixels. CPU preparation ownership is in
[World](WORLD.md#terrain-grass).

The functional producer `tests/terrain_grass_playtest.gd` uses the explicitly
selected 256 x 512 m `perf-mixed` map by default (384 trees, 48 minerals) and
accepts `--standard --seed=N` for required production habitat review. Captures
use 1280 x 720, a 60 FPS cap, isolated preferences and no performance statistics.
Production chase and first-person cameras are exercised at a stable 60 km/h pose.
The 15-second chronological influence sequence is synthetic visual stimulus,
advanced over 900 rendered steps with one saved sample every fifteen steps;
physics/runtime suites separately verify 120 Hz skiing and real scene lifecycle.
`--motion-only` skips repeat habitat stills; moving observer captures leave cell
submission to the normal three-cell process budget. This is functional evidence.
Source/export and local behavior checks are in `tests/test_runtime_grass_assets.py`
and `tests/terrain_grass_suite.gd`. Native MultiMesh readback is checked natively;
the headless dummy renderer is not geometry-submission evidence. The suite also
compares worker-packed transforms/custom data and both LOD bounds against the
per-instance reference at zero, half and full density. Asset hash audits are
skipped by default; only an explicit `--verify-asset-hashes` user argument enables
that provenance check. Structural asset and behavior checks remain enabled.

```powershell
python tests/test_runtime_grass_assets.py
./scripts/test_pc_environment.ps1 -Suites terrain_grass_suite,graphics_override_suite,scenery_loading_suite,physics_suite,runtime_suite -OutputDirectory artifacts/grass-checks
./scripts/run_guarded.ps1 -FilePath ./godotw.ps1 -Arguments @('--script','tests/terrain_grass_suite.gd') -Label grass-native-check -WorkloadMode Shared -TimeoutSeconds 180
./scripts/run_guarded.ps1 -FilePath ./godotw.ps1 -Arguments @('--script','tests/terrain_grass_playtest.gd','--','--graphics-quality=high','--upscaler=native','--frame-generation=off','--output=artifacts/grass-local') -Label grass-local -WorkloadMode Shared -TimeoutSeconds 300
./scripts/run_guarded.ps1 -FilePath ./godotw.ps1 -Arguments @('--headless','--script','tests/terrain_grass_survey.gd') -Label grass-standard-survey -WorkloadMode Shared -FullMountain -FullMountainReason 'Actual Standard grass habitats across six faces' -TimeoutSeconds 300
./scripts/run_guarded.ps1 -FilePath ./godotw.ps1 -Arguments @('--script','tests/terrain_grass_playtest.gd','--','--standard','--graphics-quality=high','--upscaler=native','--frame-generation=off','--output=artifacts/grass-standard') -Label grass-standard -WorkloadMode Exclusive -FullMountain -FullMountainReason 'Production grass habitats, forest, material transitions and bounded interaction; prepare current scenery if needed' -TimeoutSeconds 900
```

Standard/alternate surveys require current compatible physical caches; they never
cold-bake implicitly. Prepare the default with the maintained validation producer;
`tests/terrain_grass_prepare_second.gd` explicitly prepares Standard seed 638201943
under Exclusive/full-mountain admission. Pass `--seed=638201943` to its survey and
rendered review. Shared rendering is appropriate after scenery preparation is warm.

Functional evidence is retained under `artifacts/terrain_grass_20260913/`;
the performance follow-up retains its measurements, rejected diagnostics and
rendered comparisons under `artifacts/terrain_grass_performance_20260913/`.
[Validation](VALIDATION.md#terrain-grass-performance) owns the measured cost,
target assessment and exact grass-only benchmark commands. Human/controller
visual and skiing acceptance remain separate.

## Cosmetic rock gravel

`rock_gravel.gd` streams shared dense/sparse MultiMeshes in 8 m cells, capped at
49 resident cells and two private low-priority placement jobs. Workers place a
cell and pack its per-asset instance buffers and merged bounds
(`gravel_placement.pack`); main-thread publication assigns each buffer once,
blits the cell's 18-square mask into the shared texture and collects completed
jobs. Cells leaving the radius are freed eight batches per frame while they sit
beyond the fade distance. Candidate cells come from an offset list sorted once
per reach. Quality/reset/teardown joins outstanding work before releasing frozen
field inputs. New cells fade in over 0.4 seconds. There is no per-stone Node,
material, collision or shadow caster. Grass residency (`terrain_grass.gd`)
follows the same rules with a 300 us per-frame publication budget in addition
to its three-cell count, and cliff macro textures load through the resource
loader thread before their two-per-frame swap.

Two shared opaque PBR materials use authored normal detail at strength 0.22,
restrained slate colour grading, real lighting/shadow reception and the existing
cloud registry. Near and far meshes share each stone root and placement mask.
Complementary dither blends 80/16-triangle representations over 3.5-5.5 m. The
final 28 percent of the 8/12/16 m Low/Balanced/High range fades out. Batch culling
includes the entire root envelope. Existing scenery, grass and tree ranges are
preserved.

A 128-square R8 texture covers a repeating 64 m grass-exclusion window, larger
than the resident diameter. Worker-produced half-metre samples are published
before their corresponding geometry. Each 16-square cell includes a one-texel
halo and the complete grass-root search margin, so neighboring publications agree.
Smooth filtering avoids tile-shaped cuts
around grass. This scene-owned texture never changes terrain materials.

Geometry packing and dimensions belong to [Assets](ASSETS.md#runtime-gravel-assets);
placement and solver boundaries belong to [World](WORLD.md#cosmetic-rock-gravel).
Use [cosmetic gravel checks](VALIDATION.md#cosmetic-gravel-checks) for matched
off/dense/sparse/all measurements, separate local and mountain scopes, and the
current acceptance receipt.

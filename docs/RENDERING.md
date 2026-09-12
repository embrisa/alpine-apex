# Rendering

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

## Graphics and display

[GraphicsPresets](../scripts/presentation/graphics_presets.gd) is the single
numbered budget table: 1/4/7 retain Low/Balanced/High resource anchors; 10 is
Ultra. Ten effective profiles map onto three installed asset tiers. Read `TABLE`,
`CONTROLS` and `values` for exact bounds/budgets instead of maintaining a second
table here. They cover material detail, tree ranges, shadows, GI, snow,
particles, weather budget and background detail.

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

Runtime CLI after `'--'`: `--upscaler=auto|fsr4|fsr3|fsr2|native` and independent
`--frame-generation=on|off`. Supported scope is one primary SDR game window;
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

## Terrain, forests and lighting

The built-in mesh renderer is the sole terrain path. Prepared chunks and shared
LOD templates consume [World](WORLD.md)'s support surface; nearby cosmetic relief
does not become collision. Keep chunk bounds conservative and distinguish
prepared arrays from uploaded resources.

Forest/material consumers retain physical tree populations at every quality.
Near/mid geometry, far directional impostors, batched transforms, residency and
visibility are presentation budgets. Current authored living foliage uses small
curved branch sprays and baked needle textures; source/authoring contracts are
in [Assets](ASSETS.md#trees). Do not interpret all stored instance triangles as
visible-frame work. Camera forest visibility assistance must remain cosmetic.

Cloud lighting shares a per-world registry across terrain, skier, tracks, trees,
rocks, markers and sky. Sky/view and directional-receiver rays project onto the
same layer at `max(2400 m, summit + 1200 m)` with shared wind offset/coverage.
Transmission affects directional light only, retaining object shadows and
ambient fill. Surface cloud transmission is vertex sampled/interpolated; material
response and geometry shadows remain per pixel. Additional directional lights
would require their own projection contract. Sun/moon active shadow ranges do
not overlap. Distant decorative background casts no shadows or GI.

## Snow presentation

`snow_response.gd`, `snow_tracks.gd`, `powder_surface.gd`, `powder_caps.gd` and
`speed_effects.gd` consume completed per-ski load/slip/edge/material state and
final rendered ski transforms. Supported clean carving can widen/deepen tracks
without large slip; skidding makes broader swept tracks. Unsupported skis,
crashes and exposed rock do not emit live tracks. Landing/teleport/reset break
history. Cosmetic depth is bounded by loose snow, width and shader limits.

Two live ribbon sections connect the last retained sample through the visible
tips, with a 12 cm soft leading margin, every render frame. They do not wait for
the 70 cm retained-history interval. High's two GPU footprints share those
endpoints; live ribbons also work on Low/Balanced. The lateral axis of compute
displacement must agree with ribbons and world-space snow throw. Rounded lips
and forward ejection are important under hard turns. High retains its 32 m
local patch; capacities come from the effective profile, not fixed old reports.

Partial GPU uploads must match full uploads byte-for-byte. Native compilation
caught a varying-limit failure in the end-cap shader; keep packed varyings within
the engine's limit. Native GPU checks are required for compute/shader changes.
Close views still expose some ribbon/mesh faceting; headless geometry checks
do not establish the visual result.

`snow_readability.gd` derives concavity from symmetric 4 m/12 m neighbors in the
immutable support heights. Opposing planar slopes cancel; missing pairs and
float noise contribute zero. Workers return disjoint rows and join deterministically.
One mipmapped R8 texture is built/uploaded per world and included in scenery
preparation; no terrain analysis runs while skiing. Terrain, tracks, replacement
powder and tree snow skirts share world-texel mapping. Rock excludes the effect.

Current hollow shading reaches about 14% linear-light reduction, with a cool
tint, 80–160 m fade and daylight fade to zero at night. Convex crowns receive no
bright outline. Balanced/High direct-light SSAO uses .20 influence; the local
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

## Weather

`weather_controller.gd`, `weather_state.gd`, `weather_effects.gd`,
`daylight_cycle.gd` and cloud/atmosphere owners form a presentation-only system.
The controller owns complete snapshots: seeded RNG state, front endpoints/phase,
active clocks, daylight, storm cooldown and double-precision integrated cloud
displacement. World only submits this state to the shared sky/shadow field.
Ordinary fronts hold 240–420 active seconds and blend over 45–75; rain and snow
branches pass through Cloudy. Bounded gusts modulate wind and precipitation.
Daylight wraps in **3,600 active-skiing seconds**. Menus, pause, survey, preview,
loading, summit staging and results hold progression. Menu ambience may animate
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

`assets/graphics/scenery/alpine_valleys_01.res` is authored once and reused by v15
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
all background collision, shadow and GI contributions remain off. Own material
copies rather than modifying imported resources.

Additional valley haze starts beyond 1 km/outside the protected collar and
follows weather/time. A custom `FOG` output replaces automatic material fog,
so compose base distance extinction/sun scattering with valley haze there;
playable terrain retains the normal Environment/local volumetric path.
Stage replacement batches hidden, then swap atomically. Cancellation preserves
the active owner; newer requests supersede older builds. Reapply current weather
after replacement. Visual seams, seating, memory, loading and frame times need
separate checks.

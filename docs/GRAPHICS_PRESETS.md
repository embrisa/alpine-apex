# Graphics presets and output settings

The numbered graphics table is `scripts/presentation/graphics_presets.gd`.
Presets 1 / 4 / 7 retain the Low / Balanced / High resource anchors; 7 is
recommended and 10 is Ultra. The three asset tiers remain 0 / 1 / 2. All ten
presets have distinct effective budgets. This is presentation configuration:
terrain authority, mountain recipe, weather conditions and the 120 Hz solver
are not graphics settings.

## Preset behavior and persistence

`pc_graphics_settings.gd` owns `user://graphics_v2.cfg` (store schema 2).
Selecting a preset replaces its advanced overrides and resets Auto upscaling,
75% internal scale, sharpening strength .825, MSAA 2x and anisotropic filtering
4x; terrain GI defaults off. Explicit frame generation and every Display
preference survive preset selection. Advanced edits mark Custom against the
selected base preset. A named group reset removes that group's overrides;
Lighting & shadows also resets terrain GI. Graphics are applied through the
parent's `apply_graphics_configuration()` without physical regeneration, then
saved. Material/scenery/effect consumers must run even when the asset tier has
not changed; late-created materials and scenery receive the effective profile.

| Preset | Near / mid / far trees (m) | Track segments | Spray / grains / mist per ski |
| --- | --- | --- | --- |
| 1 Low | 40 / 135 / 700 | 800 | 96 / 64 / 0 |
| 2 | 50 / 160 / 800 | 1024 | 128 / 80 / 16 |
| 3 | 60 / 190 / 900 | 1280 | 160 / 96 / 32 |
| 4 Balanced | 70 / 220 / 1000 | 1600 | 192 / 128 / 48 |
| 5 | 78 / 240 / 1100 | 2304 | 256 / 160 / 64 |
| 6 | 86 / 260 / 1200 | 3072 | 320 / 208 / 96 |
| 7 High | 95 / 280 / 1300 | 4096 | 384 / 256 / 128 |
| 8 | 110 / 320 / 1500 | 4608 | 448 / 288 / 144 |
| 9 | 130 / 360 / 1750 | 5376 | 512 / 320 / 160 |
| 10 Ultra | 150 / 400 / 2000 | 6144 | 640 / 384 / 192 |

The table also scales shadow distance, material detail, sparkle, crystal
density, sheen, glow, decorative density/distance and mineral LOD bias. Ultra
is a bounded configuration; its rendered performance and visual acceptance
still require the integrated validation below.

## Controls and consumers

All rows below belong to Graphics and are persisted in the graphics store.
The advanced rows are preset-owned overrides with their exact bounds and steps
in `Presets.CONTROLS`; booleans are Off/On. They apply live through the effective
profile, including within the same numbered preset. UI dragging can coalesce
submissions, but its final value must be flushed before leaving the page.

| Group / keys | Supported values | Consumer / effect |
| --- | --- | --- |
| Rendering: `upscaler`, `render_scale` | Auto, FSR4, FSR3, FSR2, Native; 2/3 to 1 | Viewport reconstruction and internal dimensions; Native uses scale 1 |
| Rendering: `sharpness` | User strength 0 to 1; default .825 | `viewport_sharpness()` returns `2 * (1 - strength)`; .825 preserves viewport .35. Zero disables SDK sharpening, one is full strength |
| Rendering: `msaa`, `anisotropic` | MSAA Off/2x/4x/8x; filtering Off/2x/4x/8x/16x | Viewport; MSAA disabled with temporal reconstruction, TAA stays off |
| Rendering: `frame_generation` | Off/On; explicit choice outside preset resets | Native DX12 FidelityFX only; report actual backend/support, generated frames separately |
| Textures & detail: `texture_tier`, `mesh_lod_bias` | 0 to 2; .25 to 1.6 | Terrain, bark, foliage arrays, impostors and installed mineral textures; mineral geometry LOD |
| Scenery: `tree_near_m`, `tree_mid_m`, `tree_far_m` | 20 to 160; 80 to 420; 400 to 2000 m | Forest near/mid/far transitions; effective profile enforces mid >= near + 20 and far >= mid + 50 |
| Scenery: `scrub_distance_m`, `scrub_density` | 20 to 200 m; 0 to 1 | Decorative ground foliage distance/density |
| Scenery: `backdrop_tier`, `offmap_prop_density`, `offmap_tree_distance_m` | 0 to 2; 0 to 1; 1500 to 7500 m | Distant ridge/decorative scenery |
| Lighting & shadows: `shadow_quality`, `shadow_distance_m` | 0 to 5; 60 to 320 m | Directional soft-shadow filtering and terrain/mineral shadow range |
| Lighting & shadows: `contact_shading`, `contact_intensity` | Off/On; 0 to 1 (default .20) | SSAO enabled; **Contact shading in direct light** sets `Environment.ssao_light_affect`. Zero does not remove indirect-light occlusion; overall SSAO intensity remains 1.2 |
| Lighting & shadows: `indirect_lighting`, `indirect_intensity`, `terrain_gi` | Off/On; 0 to 2; Off/On | Screen-space indirect illumination and optional terrain SDFGI |
| Atmosphere: `volumetric_shafts`, `shaft_strength`, `fog_strength` | Off/On; 0 to 1.5; .5 to 1.5 | Sun shafts and atmospheric fog presentation |
| Atmosphere: `highlight_glow`, `highlight_glow_intensity` | Off/On; 0 to .6 | Highlight glow |
| Snow & particles: `normal_strength`, `snow_sparkle`, `snow_crystal_density`, `snow_sheen` | .1 to .6; 0 to 12; 0 to 2.5; 0 to .25 | Snow/rock detail and shared snow material sparkle/crystal/sheen parameters |
| Snow & particles: `snow_track_capacity`, `snow_track_relief`, `snow_local_deformation` | 400 to 6144; Off/On; Off/On | Bounded track history, ribbon relief and local GPU deformation |
| Snow & particles: `spray_budget`, `grain_budget`, `mist_budget` | 48 to 640; 32 to 384; 0 to 192 per ski | Ski snow emitters |
| Weather effects: `weather_quality`, `weather_budget` | 0 to 2; .25 to 1.5 | WeatherEffects precipitation/drift quality and particle allocation; no change to WeatherController conditions |

Installed foliage color and normal/AO arrays use `_low`, `_balanced`, and the
unsuffixed High resources according to `texture_tier`, independently of the
preset's asset anchor. `alpine_assets.apply_quality()` updates resident forest
materials; new forest materials use the same selection.

The maximum track history is shared as `Presets.MAX_TRACK_HISTORY = 6144`.
`powder_surface.gd` allocates 6146 strokes including two live slots, 32 bytes
each: **196,672 bytes**. Every submission validates dispatch count, byte-array
layout, alignment and all upload endpoints before any buffer update. Validation
runs before main-thread enqueue and again on the render thread. Invalid batches
are rejected together; main-thread rejection hides the patch and requests a
full history upload on retry. The shader and 4 m contact authority are unchanged.

Sharpening maps to the installed engine's `clamp(1 - viewport_value / 2, 0, 1)`
in `render_forward_clustered.cpp`; the native provider passes that strength to
FidelityFX and disables sharpening at zero. The `sharpness` preference means
user strength throughout the current implementation. No legacy-value migration
is provided.

## Display transaction and supported output

`display_settings.gd` owns `user://display_v1.cfg` (store schema 1). Its persisted
keys are only `display_mode`, `resolution`, `monitor`, `vsync`, and `fps_limit`.
Display values are never reset by a graphics preset.

| Preference | Supported values and application |
| --- | --- |
| `display_mode` | Fullscreen or Windowed; apply through a preview transaction |
| `resolution` | Windowed client pixels, validated within 640x480 to 7680x4320; picker lists installed bounded choices for the selected/current monitor. Zero means automatic window size (80% of the screen, capped at 1920x1080) in Windowed |
| Fullscreen resolution | Native selected-monitor pixels only; saved Windowed resolution is retained but ignored. `choices()` returns only zero/native in this mode |
| `monitor` | -1 uses current actual screen; otherwise an installed screen index |
| `vsync` | 0 Disabled, 1 Enabled, 2 Adaptive, 3 Mailbox; effective support depends on backend |
| `fps_limit` | 0 Unlimited, 60, 90, 120, 144, 165 or 240 rendered FPS |

`begin_preview(values, now_ms, window = null)` snapshots preferences and, when
provided, actual Window screen, position, client size, mode and borderless flag.
These geometry fields exist only in transaction state. A replacement preview
keeps the first recovery target and restarts the 15-second deadline. Saving
during a preview writes the original preferences. `keep()` accepts the preview;
`revert()` restores every original preference and queues the actual window for
one subsequent `apply()`. That apply restores actual state before any normal
resolution/monitor logic and then returns. Repeated Revert is harmless. A new
preview before rollback apply retains the original recovery target as well.
The optional null Window keeps pure preference fixtures available.

Native-sized Windowed remains `MODE_WINDOWED` and borderless, with exact client
size and display origin. Fullscreen normally enters `MODE_FULLSCREEN` at native
pixels. The existing native DX12 FG `exact_output` path instead stays borderless
`MODE_WINDOWED` to preserve exact swapchain/UI/output dimensions. Explicit
`requested_pixels` fixtures/benchmarks still override ordinary resolution rules
in both modes, including smaller centered borderless fullscreen-intent fixtures.
Rollback actual geometry has priority over even those explicit overrides.

## Parent main/UI integration requirements

1. In `main.preview_display()`, call
   `display_settings.display.begin_preview(values, Time.get_ticks_msec(), get_window())`
   **before** `display_settings.apply_display(get_window())`. Without the Window,
   preference rollback works but automatic-monitor/geometry recovery cannot.
2. Keep the existing `revert()` followed by `apply_display(get_window())` path for
   Revert, timeout and cancellation. Do not restore another settings snapshot,
   recenter, or call apply twice inside that recovery path. `keep()` then save
   persists accepted preferences. Graphics saves during preview are already safe.
3. Label resolution as Windowed resolution and disable its picker while the
   **draft** mode is Fullscreen; display native output there. Rebuild choices when
   draft mode or monitor changes, and again on Keep/Revert. Do not zero the saved
   Windowed resolution merely to show native fullscreen output. In Windowed,
   label zero as Automatic window size, not Native display. `choices(window)`
   uses the settings object's mode/monitor, so draft UI must resolve choices
   against its draft without committing/mutating live preferences first.
4. Label the sharpening slider Sharpening strength (0 Off / 1 Full). Use a step
   that can represent .825 exactly (for example .005), or display percentage with
   adequate precision. Disable it only when temporal reconstruction is inactive:
   `upscaler != "native" or (frame_generation and has_native_fsr())`. Native plus
   native FG still uses the temporal pass. Use the same effective condition for
   MSAA availability. Generic contact control rows now receive the accurate
   direct-light label from `Presets.CONTROLS` automatically.
5. Keep weather conditions in WeatherController. At WeatherEffects creation,
   immediately after `add_child`, call `set_budget_scale(graphics.weather_budget)`
   then `set_quality(graphics.weather_quality)`; do the same in the live graphics
   apply path. `update_weather` must receive `graphics.weather_quality`.
   Quality zero must disable precipitation/drift emission and visibility without
   clearing selected weather, wind, cloud lighting or weather audio. These edits
   belong to the parent; startup budget/quality and update routing were already
   present during this subagent's final source inspection.
6. Preserve `PCGraphicsSettings.apply_display()` passing
   `frame_generation and has_native_fsr()` as the exact-output flag. Continue
   applying the viewport/backend options when FG changes, then apply display so
   its actual window mode matches the selected backend's requirements.

## Exclusions and remaining opportunities

Snow-contact visibility, powder-cap distance, track tessellation, rock sparks,
and flavor-prop LOD retain bounded asset-tier choices. Tree-shadow distances
remain capped/tier-driven; the shadow-distance slider primarily affects
terrain/mineral directional shadows. These are not independent strength sliders.
Physical terrain/obstacle population and gameplay weather are outside Graphics.
No refresh-mode switch, HDR implementation, or unsupported upscaler is added.
Stock Godot reports its actual FSR2 fallback; native FSR3/4 and frame generation
require the custom DX12 engine.

Prepared scenery is tier-independent while its cache key still includes the
asset tier. Crossing anchors can trigger unnecessary cache replacement; this is
a separate loading-cost opportunity. No performance rewrite or cache identity
change is included in this correction.

## Validation

Guarded integrated checks pass: distinct presets and domain persistence, display
transactions, sharpening conversion, resident/new foliage resource selection,
maximum track capacity and wrapped producer uploads. Native PC graphics (16/16),
graphics (29/29), and FidelityFX settings regressions pass. Display validation
exercises real Keep, Revert, timeout, exact output and FG off/on/off. See
[interface evidence](INTERFACE_OVERHAUL.md) and
[native performance evidence](INTERFACE_PERFORMANCE.md) for final metrics,
GPU readbacks and remaining human review.

# Interface overhaul implementation and evidence

Task: AA-20260911-163058-interface-overhaul. Started on main at `6830997`.
Manual implementation; no scheduled worker or Animation Workshop is involved.

## Inventory and ownership

| Surface | Shared controls and retained owner |
|---|---|
| Title, pause, crash, results | Responsive shell; HUD dispatches existing session actions |
| Settings | Display, Graphics, Camera, Controls, Audio, Interface & HUD, Weather, Rider |
| Mountain create/saved/share | Shell, scrolling settings, large preview; MountainLibrary owns generation and files |
| Race saved/share | Shell, list, text entry; RaceWorkshop owns race data |
| In-world gates | Edge drawer; pointer terrain picking remains explicit, menu focus owns navigation |
| Records | Shell; CompetitivePanel retains overview, splits and history |
| Physics Workbench | Shell; explicit unranked handling/forces/feedback/speed lab |
| Loading | Existing honest job progress, cancel/failure and photographs |
| Dialogs | Focus scope, topmost Back, virtual text entry for core menu fields |
| HUD | Speed, time/PB, progress, split, riding state, reserve, location, performance, debug, notices, summit return |

Display and graphics store separate domains. Graphics presets never own output
mode, resolution, frame cap, synchronization, frame generation, camera or HUD.
The numbered preset is separate from the discrete asset tier. Low/Balanced/High
remain resource/testing anchors for numbered 1/4/7. Overrides update existing
materials, emitters and scenery; presentation changes never regenerate physics.

## Baseline

Native custom Godot 4.7.2, DX12, RX 9070, v15 Standard mountain. Existing
interface suite: 122/122, 30 captures. Archived in ignored
`artifacts/interface_overhaul/baseline/`, guard `interface-overhaul-baseline`.
4K settings over paused mountain, High/Auto FSR 4.1.1 at 75%, FG/GI off,
120 FPS cap, 120 warmup + 240 measured frames, screenshot work excluded:
mean 8.333 ms, p95 8.456 ms, p99 8.502 ms, render CPU mean 1.176 ms,
GPU mean 5.378 ms, engine video memory 3792261872 bytes, static 1147956849 bytes.
This is a short stationary menu sample, not sustained skiing performance.

## Verification record

Implementation and final acceptance matrix are in progress. Human controller
comfort, spaciousness and listening acceptance remain separate from automation.

## Graphics controls and apply contract

All profile controls below belong to Graphics, persist in graphics_v2.cfg, and
are preset members. Boolean controls use Off/On. Discrete texture/backdrop tiers
use Low/Balanced/High assets (0/1/2). UI changes apply to the live world; costly
changes will be coalesced during slider input. Distant ridge tier changes rebuild
presentation batches; density and distance changes reuse uploaded batches.

| Control | Range | Owner |
|---|---|---|
| Surface textures (`texture_tier`) | 0–2; step 1 | AlpineAssets / MineralScenery |
| Stone mesh detail (`mesh_lod_bias`) | .25–1.6; step .05 | AlpineAssets / MineralScenery |
| Near tree detail (m) (`tree_near_m`) | 20.0–160.0; step 5.0 | AlpineScenery / AlpineWilderness / WildernessProps |
| Mid tree detail (m) (`tree_mid_m`) | 80.0–420.0; step 10.0 | AlpineScenery / AlpineWilderness / WildernessProps |
| Tree draw distance (m) (`tree_far_m`) | 400.0–2000.0; step 50.0 | AlpineScenery / AlpineWilderness / WildernessProps |
| Ground foliage distance (m) (`scrub_distance_m`) | 20.0–200.0; step 5.0 | AlpineScenery / AlpineWilderness / WildernessProps |
| Decorative ground foliage (`scrub_density`) | 0.0–1.0; step .05 | AlpineScenery / AlpineWilderness / WildernessProps |
| Distant ridge detail (`backdrop_tier`) | 0–2; step 1 | AlpineScenery / AlpineWilderness / WildernessProps |
| Distant decorative density (`offmap_prop_density`) | 0.0–1.0; step .05 | AlpineScenery / AlpineWilderness / WildernessProps |
| Distant trees (m) (`offmap_tree_distance_m`) | 1500.0–7500.0; step 250.0 | AlpineScenery / AlpineWilderness / WildernessProps |
| Shadow filtering (`shadow_quality`) | 0–5; step 1 | AlpineWorld / RenderingServer |
| Shadow distance (m) (`shadow_distance_m`) | 60.0–320.0; step 10.0 | AlpineWorld / RenderingServer |
| Contact shading (`contact_shading`) | false–true; step 1 | AlpineWorld / RenderingServer |
| Contact shading strength (`contact_intensity`) | 0.0–1.0; step .05 | AlpineWorld / RenderingServer |
| Screen-space indirect light (`indirect_lighting`) | false–true; step 1 | AlpineWorld / RenderingServer |
| Indirect light strength (`indirect_intensity`) | 0.0–2.0; step .1 | AlpineWorld / RenderingServer |
| Terrain global illumination (`terrain_gi`) | false–true; step 1 | AlpineWorld / RenderingServer |
| Sun shafts (`volumetric_shafts`) | false–true; step 1 | AlpineAtmosphere / AlpineWorld |
| Sun shaft strength (`shaft_strength`) | 0.0–1.5; step .05 | AlpineAtmosphere / AlpineWorld |
| Atmospheric fog (`fog_strength`) | 0.5–1.5; step .05 | AlpineAtmosphere / AlpineWorld |
| Highlight glow (`highlight_glow`) | false–true; step 1 | AlpineAtmosphere / AlpineWorld |
| Glow strength (`highlight_glow_intensity`) | 0.0–.6; step .01 | AlpineAtmosphere / AlpineWorld |
| Snow and rock material detail (`normal_strength`) | .1–.6; step .01 | AlpineAssets / SnowTracks / PowderSurface / SpeedEffects |
| Crystal sparkle (`snow_sparkle`) | 0.0–12.0; step .5 | AlpineAssets / SnowTracks / PowderSurface / SpeedEffects |
| Crystal density (`snow_crystal_density`) | 0.0–2.5; step .05 | AlpineAssets / SnowTracks / PowderSurface / SpeedEffects |
| Snow sheen (`snow_sheen`) | 0.0–.25; step .01 | AlpineAssets / SnowTracks / PowderSurface / SpeedEffects |
| Track segments (`snow_track_capacity`) | 400–6144; step 128 | AlpineAssets / SnowTracks / PowderSurface / SpeedEffects |
| Track relief (`snow_track_relief`) | false–true; step 1 | AlpineAssets / SnowTracks / PowderSurface / SpeedEffects |
| Local snow deformation (`snow_local_deformation`) | false–true; step 1 | AlpineAssets / SnowTracks / PowderSurface / SpeedEffects |
| Spray per ski (`spray_budget`) | 48–640; step 16 | AlpineAssets / SnowTracks / PowderSurface / SpeedEffects |
| Snow grains per ski (`grain_budget`) | 32–384; step 16 | AlpineAssets / SnowTracks / PowderSurface / SpeedEffects |
| Snow mist per ski (`mist_budget`) | 0–192; step 16 | AlpineAssets / SnowTracks / PowderSurface / SpeedEffects |
| Precipitation quality (`weather_quality`) | 0–2; step 1 | WeatherEffects |
| Precipitation density (`weather_budget`) | .25–1.5; step .05 | WeatherEffects |

Reconstruction controls: Auto/FSR4/FSR3/FSR2/Native, internal scale 66.7–100%,
FSR sharpness 0–1, native MSAA Off/2x/4x/8x and anisotropic filtering 2x–16x.
Temporal reconstruction owns antialiasing while active. Frame generation is an
independent explicit preference with backend/capability gating. The viewport
receives the effective reconstruction settings at output size; UI stays native.

Output uses display_v1.cfg: screen, native/common fitting output sizes, fullscreen
or windowed, synchronization Off/On/Adaptive/Mailbox and rendered cap
Uncapped/60/90/120/144/165/240. Refresh rate is reported from the selected screen;
Godot does not expose an output-mode refresh enumerator here. Unsupported HDR,
unavailable texture variants, authored ridge topology beyond the three installed
tiers, shader correctness thresholds, physical populations and gameplay weather
are excluded. Imported shaders retain their appropriate mip/anisotropic sampler
hints; the filtering level only affects samplers requesting anisotropy.

The full ten-row budget table is `graphics_presets.gd::TABLE`; all remaining
preset memberships are defined by `values`. There is one table and named anchor
adapter, not a parallel three-preset implementation.

Graphics foundation checks: new settings suite passed (distinctness, clamps,
Custom/reset, separate atomic stores and display transactions); native PC graphics
16/16, graphics 29/29 and FidelityFX settings all passed. Guards:
`interface-overhaul-settings` and `interface-overhaul-graphics-native`.
These establish the settings foundation, not final UI or ten-preset performance.

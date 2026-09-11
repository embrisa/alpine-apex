# Menu and loading artwork

The title screen, settings and loading screens share the hand-drawn Alpine Apex
[vector logo](LOGO.md), ice-blue accents, cold whites and translucent navy panels.
All ordinary menus now show the live game world through the existing layout.
Photographs, drifting photographic light and photo captions are exclusive to
actual loading screens. See [live menu camera](../gameplay/CAMERA.md#live-menu-camera).

The historical menu-photo acceptance sections below document the superseded
photographic menu treatment. Their loading artwork and loading verification
remain relevant; they are not evidence for the new live camera backgrounds.
Original source photographs and the loading art implementation are retained.

## Art preparation

`scripts/art/prepare_interface_art.py` packages the nine originals into
`assets/images/prepared/`, including changing the three JPEG-in-JFIF filenames
to Godot-supported `.jpg` names. This is a byte-preserving copy, with source
paths, sizes and SHA-256 hashes in `prepared/manifest.json`. The original photo
files and original PNG logo are untouched. Runtime textures use matching lossless
Godot imports, mipmaps and linear filtering.

`assets/images/alpine_photo.gdshader` applies the shared treatment at native UI
output resolution: restrained saturation, lifted cool shadows, softened whites,
a very subtle static grain and a dark reading area. Individual exposure and
saturation trims live beside the composition choices in
`scripts/ui/alpine_art.gd`. No geometry, equipment or photographic detail is
generated, no sharpening halos are added, and no animated grain is used.

Wide photos p1, p6, p7 and p8 fill the screen with individual vertical framing.
The other five retain the entire photograph inside a fine-edged frame over a
very subdued enlargement. This preserves the ski tips, poles and athlete in the
portrait and nearly square sources. It also gives the monochrome p4 a deliberate
place in the set. The composition adapts to the viewport aspect ratio.

The game renders this treatment at 3840×2160 when output is 4K. It does **not**
claim the original images contain 4K detail or create artificial 4K source
masters. In particular, p2 starts at 1080×1441; its framed presentation limits
enlargement. Replacing a source with a higher-resolution original and rerunning
the packaging step preserves the art direction.

The active logo is `assets/images/branding/alpine_apex_ice.svg`; the header uses
`alpine_apex_compact.svg` with larger lettering and a simplified summit mark.
Their transparency comes directly from vector paths. Neither needs a shader.
The original PNG and `alpine_logo.gdshader` are preserved as historical sources.

Before the vector replacement, two built-in imagegen cleanup attempts were rejected because they returned RGB
images with painted checkerboards, not transparency. Neither generated result
is referenced or shipped. The final attempted prompt was:

> Clean and restore the edges of this exact game logo, without changing its
> position, proportions, lettering or design. Text exactly ALPINE APEX. Keep the
> original alpha transparency. Output must be RGBA PNG with alpha=0 outside the
> logo and in its holes. Do not draw a checkerboard: that is not transparency.
> No black or white backdrop, no backdrop of any sort. Remove colored cyan/blue
> speckles outside the logo only. Preserve the original mountain, chevrons and
> icy lettering and their exact shapes and exact original canvas dimensions.
> Transparent background, alpha channel.

## Runtime behavior

- One shared menu photograph covers every menu window. The photo and animation
  phase stay loaded when opening Settings. Skiing instruments are hidden over
  menu art, with their visibility preference restored on departure. Returning
  to skiing or placing race gates releases the photo and stops its clock.
- Menus randomly cycle through only the four fullscreen photographs (p1, p6,
  p7, p8). Each 24-second completed motion cycle chooses another picture from a
  private shuffle bag. Every eligible photo is used before the bag refills, with
  no immediate repeat. This randomness is independent of mountain generation.
- Loading chooses its initial image from wall-clock time and advances between
  jobs. The index survives scene replacement using tree metadata and never
  consumes simulation RNG; a new job also avoids repeating the previous image.
  Long loads additionally choose a new photo after each complete drift cycle,
  with all nine photos eligible. Photo changes update the light and caption
  without restarting progress, tips, elapsed time or audio.
- One image is retained per visible art surface. Stage updates keep the current
  photo, and completion releases the loading photo. No nine-image preload or
  full-screen shader runs during skiing.
- Progress remains tied to real stages. Unknown work uses the existing pulse;
  known completion uses its real percentage. Elapsed time, input blocking,
  keyboard-focus restoration and reduced-motion behavior are retained.

## Loading atmosphere — 2026-09-08

Menus and loading opt into an animated version of the existing photographic shader.
Wide photographs drift through
a 24-second cycle (2–5% zoom, at most 1% horizontal movement); source coordinates
are clamped to valid image bounds. Framed photographs keep the complete print
stationary while their subdued enlarged backdrops move.

Each photograph has its own source-space light position, tint, glow and ray
strength. Sunny views have warmer bloom, stronger rays, a large solar halo and
visible lens rings with warm outer rims and blue-green inner reflections;
overcast views have softer highlights and the monochrome photograph has neutral
light. Rays sway slowly by up to two degrees. The main lens ring glides along
and across the source-to-center axis; smaller colored reflections and the warm
lens ghost follow independent paths at offset phases. Halo and lens-ring radii
breathe, and light intensity changes gently through the same seamless 24-second
cycle. Light motion is independent of photo movement. This is a presentation
effect, not reconstructed photographic depth or a change to world sunlight.

Menu windows register with the HUD's shared background; full windows register
through `_window()`, while the race workshop registers only its library page.
The HUD drives one explicit animation clock while a menu is visible. Hidden
menus and reduced motion stop processing; reduced motion retains static light.
Reduced motion also holds the current photograph instead of automatically
switching it. Stalled frames do not fast-forward through photographs.
The title keeps its large brand and other windows use the compact header. Full
windows dim the photo to keep controls readable. Snow, tips, timers and wind
remain loading feedback.

Thirty-two soft 2D snow motes use local deterministic positions and fade before
wrapping around the artwork. A mask keeps the left reading rail and bottom
caption clear. Both artwork and snow receive explicit presentation time, with
advancement capped at 50 ms after a stall. Reduced motion removes motes and
photo movement, holds the glare/rays/flare steady, and switches tips without a
fade. Static grain remains static.

The original skiing tips rotate every eight seconds with a 250 ms crossfade.
Elapsed time appears after eight seconds and updates once per second in a
reserved row. Actual work still drives progress; stage changes and repeated
`begin` calls do not restart the photograph, clock, tip or audio. Completion
immediately restores controls, without a minimum display duration.

Settings → Interface includes **Loading wind ambience**, enabled by default.
It follows Interface sound volume and global mute. One overlay-owned player
uses a private loop of the user-supplied [Forest wind 01](../audio/WIND_AUDIO.md) recording
at its calibrated -12 dB trim plus interface volume, with an 800 ms fade-in and
a 150 ms fade-out. The fade-out does not
delay control restoration. Muting, zero volume, disabling ambience and teardown
stop/release playback; a new job cancels stale fade callbacks. The stereo Vorbis
stream uses its prepared 250 ms loop overlap. Its lossless source is preserved.

The shared preference reader works before the HUD exists. Later loaders follow
live feedback preferences; in-memory snapshots carry those preferences through
scene reloads, including isolated tests. `ui.loading_ambience` is stored beside
the existing interface preferences and defaults to true when absent. Script,
headless and autoplay runs do not access personal preferences; native art tests
only play sound with the explicit `--loading-audio-preview` flag.

The implementation retains one photograph per visible art surface, a single
photo shader pass, 32 small motes and one audio player. Completion releases the
photo and stops visual processing. The cooperative loader is unchanged: mesh,
material and shader uploads can still block a rendered frame. Clamped animation
time prevents a large visual jump after such a block; it cannot render during it.

### Atmospheric loading reproduction

```powershell
./godotw.ps1 --headless --script tests/interface_art_playtest.gd
./godotw.ps1 --script tests/interface_art_playtest.gd '--' --loading-audio-preview
./godotw.ps1 --script tests/interface_suite.gd '--' --ui-staged-loading --graphics-quality=high
./godotw.ps1 --script tests/loading_atmosphere_playtest.gd '--' --ui-staged-loading --graphics-quality=high --loading-world-sample
# Repeat with --loading-atmosphere-off for the paired world-startup sample.
./godotw.ps1 --script tests/loading_atmosphere_playtest.gd --resolution 1440x900 --write-movie artifacts/loading_atmosphere/motion.avi --fixed-fps 30 '--' --loading-audio-preview
```

Run native measurements alone using the project's guarded runner. The art
review captures all nine images at four animation phases, smaller layouts and
reduced motion; compares standalone 4K effects off/on after warmup; checks
independent light animation on a stationary print; and records the actual wind
loop/fades when audio preview is requested. Art artifacts are under
`artifacts/interface_art/`. Actual v11 startup timings and the three-photo motion
review are under `artifacts/loading_atmosphere/`. Screenshot readback is excluded
from measured performance. The movie is an isolated presentation fixture.

### Atmospheric loading acceptance — 2026-09-08

- Automated UI: 104 headless art checks and 119 native art/audio checks passed.
  The native pass includes independent animated light on a stationary print,
  identical reduced-motion pixels, live mute/volume/wind settings, repeated jobs,
  fade interruption, full compressed-stream loop duration and teardown.
- Rendered: 66 native captures include all nine photos at four animation phases,
  the existing menu/control review and loading layouts at 1280×720, 1440×900 and
  3840×2160. Portrait prints retain their full framing and reading areas stay clear.
- Standalone RX 9070 / D3D12 loading UI, actual 3840×2160 captures, 120 FPS cap:
  effects add **0.131 ms mean GPU** for both wide and framed compositions. Each
  sample excludes captures and uses 120 warmup plus 360 measurement frames.
  Wide off/on frame p95: **8.352/8.359 ms**, p99: **8.370/8.386 ms**; mean GPU:
  **0.337/0.468 ms**, CPU render: **0.110/0.190 ms**. Framed off/on frame p95:
  **8.379/8.408 ms**, p99: **8.415/8.490 ms**; mean GPU: **0.351/0.481 ms**,
  CPU render: **0.102/0.236 ms**. Engine video memory rises by about 18 MiB in
  each paired sample; static memory rises by about 26 KiB. These are isolated
  loading-interface measurements, not skiing performance or world loading time.
- Initial noise-loop audio baseline, before the user supplied Forest wind 01:
  the 7.179-second native bus recording includes fade-in, a complete wind
  loop and fade-out. Measured RMS is **−51.13 dBFS**, peak **−39.45 dBFS**, with
  zero clipped samples and silence after the fade. Level/cleanup checks do not
  establish subjective listening comfort on the user's speakers or headphones.
- The preserved visual/initial audio report is `artifacts/loading_atmosphere/art_native.json`;
  `wind_review.wav` and `audio_analysis.json` retain the initial noise-loop evidence.
  The Forest wind 01 review is recorded separately so these baselines remain identifiable.
- Final forest-audio review: **15/15** native checks passed, including master
  preservation, loop wrapping and playback lifecycle; see [wind evidence](../audio/WIND_AUDIO.md#validation--2026-09-08).
- Final headless art review: **104/104**; physics **56/56**; runtime **120/120**;
  native interface integration **54/54**, including actual generation, shared
  race imports, failed inputs, scene reload preference retention and cleanup.
  The integration report is `artifacts/loading_atmosphere/integration_native.json`.
  A further native run after concurrent wind-control integration also passed
  **54/54**; its report is `artifacts/loading_atmosphere/integration_combined_native.json`.
- Motion review: the corrected `artifacts/loading_atmosphere/loading_preview.mp4`
  shows three complete 24-second cycles at 1440×900 / 30 FPS, with Forest wind 01.
  Sampled frames retain the full interface, complete portrait prints and quiet
  reading areas. The separate 4K captures establish native-resolution framing.
  Final headless checks also cover progress-pulse bounds before initial layout.

### Actual staged startup performance

One guarded pair exercised seed 849205174 / v11 at actual 3840×2160 on the RX 9070,
including generation, cache reads, scenery uploads and rider/HUD creation.
Screenshot readback is excluded. Values are effects **off / on**:

| Measurement | Off | On |
| --- | ---: | ---: |
| Total loading | 32.777 s | 33.394 s |
| Frame p95 / p99 | 65.077 / 82.189 ms | 58.406 / 84.089 ms |
| Longest frame | 2865.936 ms | 2941.160 ms |
| Frames over 50 ms | 100 | 101 |
| Mean GPU | 0.162 ms | 0.314 ms |
| Mean CPU render | 0.050 ms | 0.118 ms |
| Peak engine static memory | 624,115,825 B | 624,774,506 B |
| Peak engine video memory | 5,743,550,464 B | 5,840,871,424 B |

The existing blocking stages dominate: rider/camera/interface creation takes
about 2.9 seconds in one frame, first tree placement about 2.25 seconds, distant
peaks about 1.37 seconds, and snow-contact setup about 0.42 seconds in both runs.
These are stage-level observations, not a separation of driver upload time from
CPU construction. Raw stages are in `artifacts/loading_atmosphere/world_off.json`
and `world_on.json`. A single pair is subject to cache and run-order variation;
it establishes neither a loading-time improvement nor uninterrupted rendering.
The isolated loader's added GPU time meets the under-1-ms target. Subjective
motion comfort and listening acceptance remain user review items.

## Menu animation and cycling acceptance — 2026-09-08

- Automated: **171/171** headless art checks cover menu visibility, fullscreen-only selection,
  exhaustion of both shuffle pools, no immediate repeats, complete-cycle timing,
  stalled-frame bounds, reduced motion and resource release. The native interface
  integration passed **112/112**, including all menu windows, failed imports,
  race placement/back navigation and a complete scene reload. Runtime regression
  passed **126/126**. The final headless result is archived separately in
  `artifacts/menu_atmosphere/art_headless.json`.
- Rendered: **73/73** native art checks passed. Four animation phases were
  inspected for title, pause and Settings at actual **3840×2160**, plus 1280×720
  and 1440×900 layouts. Pixel comparisons establish animated changes and exactly
  identical reduced-motion frames. The integration run saved 27 additional
  captures, including the live terrain exposed during race placement.
- Performance: standalone native 4K menu, RX 9070 / D3D12, 120 FPS cap, 120 warmup
  and 360 measured frames per state, with captures and texture loading excluded.
  Effects off/on frame p95: **8.348/8.349 ms**, p99: **8.367/8.370 ms**; mean GPU:
  **0.183/0.290 ms** (**+0.107 ms**), mean CPU render: **0.100/0.117 ms**.
  Engine video memory was unchanged at **293,355,520 bytes**; static memory
  rose **5,876 bytes**. This measures menu atmosphere, not skiing performance.
- Evidence: `artifacts/menu_atmosphere/art_native.json`, `integration_native.json`
  and `menu_motion_review.jpg`. Human acceptance of motion comfort and photo
  switching remains separate from the automated and rendered checks.

Reproduce the focused native review with:

```powershell
./godotw.ps1 --script tests/interface_art_playtest.gd '--' --menu-atmosphere-only
```

## Stronger solar flare acceptance — 2026-09-08

The solar treatment was strengthened after user feedback that the original flare
was too faint. It now includes a broad warm halo around the photo's light source,
a prominent gold/cyan lens ring, a smaller green reflection, a warm lens ghost,
brighter bloom and stronger rays. All remain in the existing photo shader pass,
behind the reading-area shading and menu panels. Per-photo ray strength suppresses
colored halos in overcast and monochrome images. No source photographs changed.

Native review saved 29 captures: old/new comparisons for all nine loading photos
and all four fullscreen menu photos at actual 3840×2160, plus Settings at 1280×720,
1440×900 and 3840×2160. Inspected captures retain readable controls and full framed
prints. Independent light animation, identical reduced-motion pixels and the
under-1-ms additional GPU bound all passed. Subjective strength/comfort remains
user review rather than an automated claim.

The isolated 4K menu sample on RX 9070 / D3D12 measured previous/new mean GPU
**0.288/0.363 ms** (**+0.075 ms**); frame p95 **8.347/8.347 ms**, p99
**8.368/8.360 ms**; CPU render mean **0.093/0.090 ms**. Each state used 120 warmup
and 360 measurement frames at a 120 FPS cap, excluding captures and texture loads.
Engine video memory stayed at **316,489,728 bytes**; static memory rose **5,940 bytes**.
These are shader-tuning measurements, not world-loading or skiing benchmarks.

Evidence is retained under `artifacts/solar_flare/`: `review.json`,
`solar_comparison.jpg`, `all_photos.jpg`, and the native captures.

## Lens flare motion acceptance — 2026-09-08

The lens reflections now travel visibly over each photograph, with separate
offset paths for the large ring, secondary ring and warm ghost. The source halo
also expands and contracts more visibly. Reduced motion freezes all of these
effects. This adjustment adds no rendering passes or resources.

- Automated: both native pixel checks passed: independent light movement over
  a stationary framed photograph, and identical reduced-motion pixels at
  different animation times.
- Rendered: 13 actual 3840×2160 captures cover four menu phases and all nine
  loading photographs. The silent 48-second 1440×900 / 30 FPS movie shows one
  complete menu cycle followed by a complete framed-loading cycle. Sampled
  movie frames retain the full interface and stationary portrait framing.
- Performance: paired timing samples exclude screenshots, but an existing
  interactive game remained open. These samples do not establish isolated
  shader cost or new performance acceptance. Earlier isolated measurements
  above remain historical baselines.
- Subjective: motion comfort and preferred flare strength remain user review.

Evidence is under `artifacts/flare_motion/`: `review.json`, native captures,
`movie_review.png` and `lens_flare_motion.mp4`.

## Original art reproduction

On Windows, from the project root:

```powershell
python scripts/art/prepare_interface_art.py
./godotw.ps1 --headless --editor --import
# On the very first import, rerun packaging to configure generated descriptors.
python scripts/art/prepare_interface_art.py
./godotw.ps1 --headless --editor --import
./godotw.ps1 --headless --script tests/interface_art_playtest.gd
./godotw.ps1 --script tests/interface_art_playtest.gd
./godotw.ps1 --script tests/interface_suite.gd '--' --ui-staged-loading --graphics-quality=high
```

The dedicated art review saves actual Godot viewport captures and measurements
under `artifacts/interface_art/`. It isolates UI work from mountain generation,
preferences and personal bests. The existing integration suite exercises actual
loading workers, race imports, settings and scene transitions, saving evidence
under `artifacts/ui_refresh/`.

## Acceptance — 2026-09-07

- Automated: physics suite 56/56; runtime suite 93/93; rendered interface
  integration suite 43/43, including generated-v10 loading and input blocking;
  final dedicated rendered art review 64/64, including resource release,
  full photo rotation, retained Settings texture and instrument preferences.
- Rendered: inspected title layouts at 1280×720, 1440×900 and 3840×2160,
  settings, and all nine loading compositions at 3840×2160. The logo has real
  transparency, subjects keep the intended framing, and controls stay readable.
- Performance: the rendered integration run measured High, FSR2 75%, native
  3840×2160 output over the paused generated mountain at 8.333 ms mean,
  8.423/8.587 ms p95/p99; GPU 6.635 ms mean and CPU render 1.177 ms mean.
  Engine-reported video memory was 3.89 GB and static memory 477 MB. This is
  paused-interface evidence, not a descent benchmark. The older harness's JSON
  scope string says "v4 summit"; its actual generated-version assertion is v10.
- Standalone loading UI: 3840×2160 on RX 9070 / D3D12, 360 measured frames after
  120 warmup frames, 8.333 ms mean and 8.341/8.368 ms p95/p99; GPU 0.341 ms mean,
  CPU render 0.083 ms mean. Engine video memory 288 MB; static memory 120 MB.
  No screenshot overhead, terrain generation or skiing is included in that sample.
- Manual skiing/subjective approval: not claimed. Source photography quality
  limits remain visible; this work does not invent higher-resolution detail.

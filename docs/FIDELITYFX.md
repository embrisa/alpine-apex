# FidelityFX renderer integration

Alpine Apex's FidelityFX work uses AMD FSR SDK **2.3.0**, pinned to
`60f4ea81909200d8542eca14dccb2628b763a9a3`, with Godot **4.7.2** source pinned to
`ed1daf0bf001b61586d9930840f2f1394092c079`. The Windows DirectX 12 renderer needs
a custom engine; copying SDK DLLs into a stock Godot project does not enable FSR.

## Hardware and options

| Option | SDK implementation | Hardware requirement |
|---|---|---|
| Auto | Highest supported 4.1 provider, then 3.1; stock-engine fallback is FSR2 | Provider and device detection |
| FSR 4.1 | ML upscaling 4.1.1 | Radeon RX 7000/9000 discrete GPUs, SM 6.6 |
| FSR 3.1 | Temporal upscaling 3.1.5 | RX 500 or equivalent from other vendors, SM 6.2 |
| Frame generation | Analytical frame generation 3.1.6 and SDK swapchain | RX 5000 or equivalent from other vendors, SM 6.2 |
| FSR2 / Native | Godot's existing renderer | Existing project requirements |

These are [AMD's requirements](https://gpuopen.com/amd-fsr-sdk/), not a claim that
every NVIDIA, Intel or older AMD GPU has been tested. The SDK's returned providers
and context-creation result determine availability. Unsupported GPUs retain the
existing renderer. Frame generation is independently selectable and initially off.
At native resolution with frame generation, the temporal path supplies motion
vectors and antialiasing at 100% scale. Generated frames do not run gameplay or
increase the independent 120 Hz simulation rate.

## Install and build

```powershell
./scripts/install_fidelityfx.ps1
./scripts/build_fidelityfx_probe.ps1 -Run
./scripts/build_fidelityfx_engine.ps1
./scripts/run_guarded.ps1 -FilePath pwsh -Arguments @('-NoProfile','-File','scripts/test_fidelityfx.ps1') -Label fidelityfx_native -TimeoutSeconds 600
./scripts/activate_fidelityfx.ps1
./godotw.ps1
```

After activation, `./godotw.ps1` selects the validated custom runtime for game and
test launches. The selection manifest records the exact engine and console hashes;
rebuilding requires revalidation and reactivation. Activation checks all six suites,
rendered evidence for that executable, and the signed SDK runtime hashes. An explicit
`GODOT_BIN` still takes precedence. Editor/import/export invocations use stock Godot.
Use `./godotw-fsr.ps1` for an explicit custom-runtime launch before activation.
Explicit game options
include `--upscaler=auto|fsr4|fsr3|fsr2|native` and `--frame-generation=on|off` after
the quoted `'--'` separator. This is a game runtime with `disable_path_overrides=no`
for source-project development; retain the stock Godot editor/importer for asset work.
In Visual Settings, choose **Auto**, **FSR 4.1**, or **FSR 3.1**, then independently
enable **FSR 3 frame generation**. Existing explicit graphics preferences are retained;
new defaults are Auto at 75%, 120 rendered FPS, and frame generation off.
The custom engine targets Windows DX12. The shell `godotw` wrapper on other platforms
continues to select their stock engine.

The SDK is installed under `.tools/FidelityFX-SDK`; the isolated engine checkout is
`.tools/godot-fsr`. The installer checks the source commit, tracked source changes,
and AMD Authenticode signatures on the loader, upscaler and frame-generation DLLs.
`artifacts/fidelityfx/sdk-install.json` records hashes. The build requires Python
with SCons, Visual Studio 2022 C++ tools, CMake, and the Windows SDK. The build script
downloads Godot's matching Mesa NIR and DirectX Agility dependencies locally.

`native/fidelityfx/godot_module` contains the engine module. The preparation script
applies narrow hooks in Godot's temporal-upscale path and DirectX 12 driver, then
records `native/fidelityfx/godot-4.7.2.patch`. Re-running it preserves unrelated
changes and rejects an unexpected engine revision or source layout.

## Rendering contract

The SDK receives the renderer's HDR color, reversed depth, motion vectors, pixel
jitter, actual render/output sizes, frame time in milliseconds, vertical FOV in
radians, camera basis, and history resets. Godot's alpha-swizzled reactive view is
copied into a real texture before exposing the raw DX12 resource to the SDK.
Native callbacks declare their resource usage to Godot's render graph. Driver
hooks flush resource transitions and invalidate cached pipeline/root-signature/
descriptor bindings around external SDK dispatches.
The triple-buffered HUD-free presentation textures cross from Godot's enhanced
barriers to AMD's legacy presentation barriers in `COMMON` state on both sides.
Leaving these textures in shader-read layout violates DirectX barrier interoperation.
SDK creation chains include the required API-version descriptors with persistent
storage for every context descriptor.

Context changes flush pending graphics work before releasing SDK allocations.
Viewport recreation, explicit history reset, large camera moves, and abrupt
camera rotations invalidate temporal history. The frame-generation path uses a
separate copy of the tonemapped scene before canvas/HUD rendering. SDK frame
generation stays on the game queue; asynchronous compute is initially disabled.
The SDK owns interpolation and presentation pacing. Its callback uses render
frame IDs, and stops generation when no complete frame was prepared. Resize and
shutdown disable generation and drain presentation work before releasing resources.

The integration targets one primary SDR game window. Multi-view/XR and HDR output
are outside this implementation's validation scope. Simulation, terrain, replays,
records, and input ownership are unchanged. The game graphics report includes
the active provider, SDK dispatch counts, generated-frame counts and, where DXGI
provides it, the presentation count. Rendered FPS and generated FPS must be reported
separately; a successful dispatch is not a full-mountain performance result.

With frame generation enabled, fullscreen uses a screen-sized borderless window.
Godot's Windows multiwindow fullscreen adds two native pixels beyond the reported
screen size; the resulting swapchain/HUD mismatch prevents generation. Keeping
the native window at the exact screen dimensions restores the existing SDK path
without changing resolution or saved display preferences. Toggling generation
while fullscreen reapplies the window configuration immediately. Godot may report
this exact borderless window as exclusive fullscreen after Windows detects its
screen coverage. The native transition test checks actual output pixels and
generation counters rather than relying on the window-mode enum alone.

## Validation

- `tests/fidelityfx_settings_suite.gd`: CLI, typed persistence and honest stock-engine fallback.
- `tests/pc_graphics_suite.gd`: existing graphics controls, assets and race/physics isolation.
- `tests/fidelityfx_playtest.gd`: actual DX12 provider dispatch, independent frame generation,
  mode changes, camera history reset, resize, HUD captures and shutdown.
- `tests/fidelityfx_game_playtest.gd`: actual game, skier, environment, HUD and Display
  settings in the explicit unranked laboratory, without writing user preferences.
- `tests/fullscreen_generation_suite.gd`: native fullscreen generation on/off,
  windowed generation, and return to fullscreen through the gameplay settings handler.
- `tests/physics_suite.gd` and `tests/runtime_suite.gd`: simulation/session regressions.
- The native probe separately queries and creates the actual GPU's SDK providers.

On 2026-09-09, the RX 9070 passed **272 checks** across the six suites (32 native
transitions, 7 game/HUD, 18 settings, 56 physics, 145 runtime, 14 PC graphics).
Both rendered suites ran with DirectX validation and logged **zero errors**.
Validation still reports clear-value and barrier-list optimization warnings
(820/821/1356); these are not evidence of meeting the performance target.
The SDK probe created all five providers it reported with zero context failures.
The game selected FSR **4.1.1** and analytical frame generation **3.1.6**; explicitly
selecting FSR3 dispatched **3.1.5**. During a 150-rendered-frame generation phase,
DXGI presentation count increased by about 299, confirming additional presents.
Resize, provider changes, native-resolution frame generation, disabling generation,
history reset and shutdown passed. Captures of the actual game and Display settings
were inspected at 1920x1080 output / 1440x810 internal.

Evidence lives under `artifacts/fidelityfx`: `validation.json`, `render-results.json`,
`game-results.json`, `device-probe.log`, per-suite logs and `captures/`. The render
report records the engine SHA-256. Check current logs and hashes after rebuilding.
GPU counters establish submitted generated frames and presents, not a measurement
of physical monitor refreshes or end-to-end latency. Full-mountain
4K p95/p99, continuous-motion/HUD quality, latency, controller feel, and testing on
RX 7000/NVIDIA/Intel hardware remain separate acceptance work.

## Distribution

Ship the matching custom game executable, Godot's matching `D3D12Core.dll`, and
the unmodified AMD-signed loader/upscaler/frame-generation DLLs together. The build
copies AMD and Godot license notices beside the engine. Retain those notices in
the distributed game documentation. The AMD binary redistribution license is in
the pinned SDK's `Kits/FidelityFX/docs/license.md`. SDK source and tools remain in
ignored `.tools`; distribute the required runtime files with the game export.

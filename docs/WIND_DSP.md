# Procedural skiing wind

The default skiing wind is generated continuously from noise in a native audio
callback. **F7** crossfades between Procedural and Original during a descent.
Settings / Audio contains Wind sound and Wind volume. M mutes both modes.
The default is natural airflow at the skier's ears, with modest stereo width
for both speakers and headphones. Loading wind, rain, and ski sounds are separate.

## Play and build

Run `./scripts/play_wind.ps1`, or launch the project normally. The included Windows
x64 DLL runs with the installed Godot 4.7.2. This is a playable project build;
the launcher uses the existing game assets rather than duplicating them.

Rebuild with `./scripts/build_wind.ps1 -Test`. CMake and Visual Studio 2022 C++
are required. The script downloads official godot-cpp **godot-4.5-stable** at
`e83fd0904c13356ed1d4c3d09f8bb9132bdc6b77` into ignored `.tools/wind`, verifies
the pin, builds a static-runtime x64 DLL, and copies it into the wind addon.
The bundled dependency's MIT notice accompanies the DLL. An engine with the DLL
loaded must release it before replacing the binary; the build never closes apps.

Missing native support uses Original and reports the unavailable mode. Wind
preferences live in `user://wind_v1.cfg`; scripted, headless, and autoplay runs
do not read or write personal wind preferences. Scene reloads carry the settings
in memory. `--wind-mode=original|procedural` overrides the mode for that launch;
`--wind-disable-native` exercises the fallback.

## Signal and integration

The presentation component computes `weather.wind_velocity - sim.velocity` in
metres per second, expressed in the skier's support/facing frame. Backward facing
reverses that frame. Turning the camera has no effect. Disabled weather supplies
zero ambient wind, while skiing and jumps continue producing relative airflow.
There is no wind force, occlusion/shelter model, or propagation simulation.

Three non-resonant filtered-noise layers provide air rush, low turbulence, and
light detail at the ears. Smooth random knots modulate the sound without a short
loop or sinusoidal gust cycle. Airspeed increases level and bandwidth with a soft
saturation curve. Tuck reduces buffeting and upper-frequency energy. The windward
ear receives a small emphasis; a strong shared component supports mono playback.
The original loop and procedural stream match RMS at upright 90 km/h in still air.

Each native playback owns its noise/filter history. Atomic scalar targets pass
airflow, tuck, gust, volume, and the gate to the callback. Reads are bounded;
adjacent-frame fields during a simultaneous update are tolerated by sample-rate
smoothing. The callback performs no allocation, locking, logging, or Node access.
Timing uses two monotonic clock reads per block and a fixed atomic history.
All allocations and percentile sorting happen outside the callback.

The DSP removes DC, smooths parameters, and bounds the output at **-6 dBFS** with
soft saturation. Its ceiling applies to wind alone, not the full mixed game audio.
Pause and mute gate the stream. Visible, unfrozen crashes now use ragdoll velocity
and head orientation through the [skiing audio controller](SKIING_AUDIO.md). Before scene replacement the playing node
is retained briefly at the root, allowing its fade to finish. Original mode pauses
the native player after the comparison crossfade, so its callback cost is excluded
from the original-mode baseline. Stop/free shuts down playback before cleanup.

The independent core is in `native/wind`; `AlpineWindStream` exposes
`set_controls(air_m_s, tuck, gust, gain, enabled)` and `diagnostics()`.
Audio generation uses the actual engine mix rate. Noise is neither serialized
into replays nor drawn from the simulation RNG. Physics and record identities
are unchanged.

## Reproduce validation

- `./scripts/build_wind.ps1 -Test`: standalone DSP tests at 44.1/48 kHz.
- `.tools/wind/build/Release/wind_dsp_test.exe artifacts/wind/offline`: measurements
  plus speed-ramp, tuck, crosswind, and speed-step WAV auditions.
- `./godotw.ps1 --headless --script tests/wind_audio_suite.gd`: native callback,
  airflow mapping, independence, fallback, and lifecycle checks.
- Add `'--' --wind-disable-native` to exercise unavailable-native startup.
- Run the physics, runtime, and interface suites with the normal headless wrapper.
- `./scripts/benchmark_wind.ps1 -Mode original` and `-Mode procedural`: identical
  unranked v11 face-zero descents at 3840x2160, High, 75% FSR2, 120 FPS cap, GI off.
  The shared runner records process telemetry and preserves other applications.
- `./scripts/benchmark_wind.ps1 -Mode procedural -Capture`: separate audio and
  rendered preview run. Capture overhead must not be used for performance acceptance.
- `tests/wind_ab_benchmark.gd` provides four same-session Original / Procedural /
  Procedural / Original passes with a fixed pose to isolate DSP cost under one
  background workload. It is a rendering probe, not a physics descent.

Machine-readable results live in `artifacts/wind`, `artifacts/pc_environment/wind_*`,
and `artifacts/guarded/wind_*`. Automated tests and signal measurements do not
establish perceived naturalness or long-session listening comfort. Those require
the user's listening and skiing review. Old local wind reports and comparison
media have been deleted; rerun the producers above for fresh evidence. See
[current validation gates](VALIDATION.md). The existing F2 Speed Lab also provides
unranked high-speed starts for manual listening.
